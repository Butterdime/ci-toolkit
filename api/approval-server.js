#!/usr/bin/env node
/**
 * Approval Dashboard Backend
 * Handles approval validation and GitHub repository dispatch events
 * Can run as serverless function (Vercel) or standalone Express server
 */

const express = require('express');
const cors = require('cors');
const { Octokit } = require('@octokit/rest');
const rateLimit = require('express-rate-limit');
const {
    verifyGitHubToken,
    generateJWT,
    authenticateToken,
    requireOrgAccess,
    requireAdmin,
    validateApprovalRequest,
    createUserRateLimit,
    auditLog,
    securityHeaders,
    errorHandler
} = require('./security');

const app = express();
const PORT = process.env.PORT || 3001;

// Security headers
app.use(securityHeaders);

// CORS configuration
app.use(cors({
    origin: process.env.DASHBOARD_ORIGIN || 'https://butterdime.github.io',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
}));

app.use(express.json({ limit: '10mb' }));

// Rate limiting (global)
const globalLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 200, // limit each IP to 200 requests per windowMs
    message: { success: false, error: 'Too many requests from this IP', code: 'RATE_LIMIT_GLOBAL' }
});
app.use('/api/', globalLimiter);

// User-specific rate limiting
const userRateLimit = createUserRateLimit();
app.use('/api/', userRateLimit);

// GitHub API setup
const octokit = new Octokit({
    auth: process.env.GITHUB_TOKEN || process.env.GH_TOKEN
});

// Validation functions
const validatePrerequisites = async (org, repos) => {
    const results = {
        org,
        total: repos.length,
        ready: 0,
        issues: [],
        readyRepos: []
    };

    for (const repo of repos) {
        const repoStatus = await checkRepoReadiness(org, repo);
        if (repoStatus.ready) {
            results.ready++;
            results.readyRepos.push(repo);
        } else {
            results.issues.push({
                repo,
                issues: repoStatus.issues
            });
        }
    }

    results.allReady = results.ready === results.total;
    return results;
};

const checkRepoReadiness = async (org, repo) => {
    const issues = [];
    let ready = true;

    try {
        // Check 1: Repository exists and is accessible
        const { data: repoData } = await octokit.rest.repos.get({
            owner: org,
            repo: repo
        });

        // Check 2: Has package.json (Node.js project)
        try {
            await octokit.rest.repos.getContent({
                owner: org,
                repo: repo,
                path: 'package.json'
            });
        } catch (error) {
            if (error.status === 404) {
                issues.push('Missing package.json - not a Node.js project');
                ready = false;
            }
        }

        // Check 3: No recent workflow failures
        try {
            const { data: workflows } = await octokit.rest.actions.listWorkflowRuns({
                owner: org,
                repo: repo,
                per_page: 5,
                status: 'completed'
            });

            const recentFailures = workflows.workflow_runs.filter(
                run => run.conclusion === 'failure' && 
                Date.now() - new Date(run.created_at).getTime() < 24 * 60 * 60 * 1000 // 24 hours
            );

            if (recentFailures.length > 0) {
                issues.push(`${recentFailures.length} workflow failure(s) in last 24h`);
                ready = false;
            }
        } catch (error) {
            // Workflows might not exist yet, which is fine
        }

        // Check 4: Default branch protection (optional warning)
        try {
            await octokit.rest.repos.getBranchProtection({
                owner: org,
                repo: repo,
                branch: repoData.default_branch
            });
        } catch (error) {
            if (error.status === 404) {
                issues.push('No branch protection rules (warning only)');
                // Don't mark as not ready for this
            }
        }

    } catch (error) {
        if (error.status === 404) {
            issues.push('Repository not found or no access');
            ready = false;
        } else {
            issues.push(`API error: ${error.message}`);
            ready = false;
        }
    }

    return { ready, issues };
};

// API Routes

// Authentication endpoint
app.post('/api/auth/github', async (req, res) => {
    try {
        const { github_token } = req.body;
        
        if (!github_token) {
            return res.status(400).json({
                success: false,
                error: 'GitHub token required',
                code: 'TOKEN_REQUIRED'
            });
        }
        
        // Verify GitHub token and get user info
        const user = await verifyGitHubToken(github_token);
        
        // Generate JWT token
        const jwt_token = generateJWT(user);
        
        res.json({
            success: true,
            data: {
                token: jwt_token,
                user: {
                    id: user.id,
                    login: user.login,
                    name: user.name,
                    email: user.email,
                    avatar_url: user.avatar_url,
                    organizations: user.organizations
                }
            },
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('GitHub authentication error:', error);
        res.status(401).json({
            success: false,
            error: error.message,
            code: 'AUTH_FAILED',
            timestamp: new Date().toISOString()
        });
    }
});

// Health check (public)
app.get('/api/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        version: '2.0.0',
        features: {
            authentication: true,
            authorization: true,
            rate_limiting: true,
            audit_logging: true
        }
    });
});

// Get readiness status for organization
app.get('/api/readiness/:org', async (req, res) => {
    try {
        const { org } = req.params;
        
        // Get list of repositories for the org
        const { data: repos } = await octokit.rest.repos.listForOrg({
            org,
            type: 'all',
            per_page: 100,
            sort: 'updated'
        });

        // Filter to Node.js repositories (those with package.json)
        const nodeRepos = [];
        for (const repo of repos) {
            try {
                await octokit.rest.repos.getContent({
                    owner: org,
                    repo: repo.name,
                    path: 'package.json'
                });
                nodeRepos.push(repo.name);
            } catch (error) {
                // Skip non-Node.js repositories
            }
        }

        const validation = await validatePrerequisites(org, nodeRepos);
        
        res.json({
            success: true,
            data: validation,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('Error checking readiness:', error);
        res.status(500).json({
            success: false,
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Approve and execute rollout
app.post('/api/approve/:org', async (req, res) => {
    try {
        const { org } = req.params;
        const { repos, rolloutType = 'full', approvedBy } = req.body;

        // Validate input
        if (!repos || !Array.isArray(repos) || repos.length === 0) {
            return res.status(400).json({
                success: false,
                error: 'repos array is required and must not be empty'
            });
        }

        if (!approvedBy) {
            return res.status(400).json({
                success: false,
                error: 'approvedBy field is required for audit trail'
            });
        }

        // Re-validate prerequisites before approval
        const validation = await validatePrerequisites(org, repos);
        
        if (!validation.allReady) {
            return res.status(400).json({
                success: false,
                error: 'Prerequisites not met',
                validation,
                timestamp: new Date().toISOString()
            });
        }

        // Send repository dispatch event
        const dispatchPayload = {
            event_type: 'start-rollout',
            client_payload: {
                org,
                repos: validation.readyRepos,
                rollout_type: rolloutType,
                approved_by: approvedBy,
                approved_at: new Date().toISOString(),
                prerequisites_validated: true
            }
        };

        // Dispatch to the ci-toolkit repository (or specified target repo)
        const targetOwner = process.env.TARGET_OWNER || 'Butterdime';
        const targetRepo = process.env.TARGET_REPO || 'ci-toolkit';

        await octokit.rest.repos.createDispatchEvent({
            owner: targetOwner,
            repo: targetRepo,
            ...dispatchPayload
        });

        console.log(`✅ Rollout approved and dispatched for ${org}:`, {
            repos: validation.readyRepos,
            approvedBy,
            timestamp: new Date().toISOString()
        });

        res.json({
            success: true,
            message: 'Rollout approved and dispatched successfully',
            data: {
                org,
                repos: validation.readyRepos,
                rolloutType,
                approvedBy,
                dispatchTarget: `${targetOwner}/${targetRepo}`,
                timestamp: new Date().toISOString()
            }
        });

    } catch (error) {
        console.error('Error processing approval:', error);
        res.status(500).json({
            success: false,
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Get rollout status (for feedback loop)
app.get('/api/status/:org', async (req, res) => {
    try {
        const { org } = req.params;
        
        // Check for recent rollout workflow runs
        const targetOwner = process.env.TARGET_OWNER || 'Butterdime';
        const targetRepo = process.env.TARGET_REPO || 'ci-toolkit';
        
        const { data: workflows } = await octokit.rest.actions.listWorkflowRuns({
            owner: targetOwner,
            repo: targetRepo,
            per_page: 10,
            event: 'repository_dispatch'
        });

        // Filter for rollout workflows for this org
        const orgRollouts = workflows.workflow_runs.filter(run => {
            // This would need to be enhanced based on how we store org info in workflow runs
            return run.display_title && run.display_title.includes(org);
        });

        const latestRollout = orgRollouts[0];
        
        res.json({
            success: true,
            data: {
                org,
                hasActiveRollout: latestRollout && ['in_progress', 'queued'].includes(latestRollout.status),
                latestRollout: latestRollout ? {
                    id: latestRollout.id,
                    status: latestRollout.status,
                    conclusion: latestRollout.conclusion,
                    created_at: latestRollout.created_at,
                    updated_at: latestRollout.updated_at,
                    html_url: latestRollout.html_url
                } : null,
                timestamp: new Date().toISOString()
            }
        });

    } catch (error) {
        console.error('Error getting rollout status:', error);
        res.status(500).json({
            success: false,
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Unhandled error:', error);
    res.status(500).json({
        success: false,
        error: 'Internal server error',
        timestamp: new Date().toISOString()
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        error: 'Endpoint not found',
        timestamp: new Date().toISOString()
    });
});

// Start server (for local development)
if (require.main === module) {
    app.listen(PORT, () => {
        console.log(`🚀 Approval Dashboard Backend running on port ${PORT}`);
        console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
    });
}

// Export for serverless environments (Vercel, AWS Lambda, etc.)
module.exports = app;