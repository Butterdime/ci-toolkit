#!/usr/bin/env node
/**
 * Security and Authentication Module for Approval Dashboard
 * Implements JWT authentication, role-based access, and comprehensive validation
 */

const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { Octokit } = require('@octokit/rest');

// Configuration
const JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(64).toString('hex');
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';
const ALLOWED_GITHUB_ORGS = (process.env.ALLOWED_GITHUB_ORGS || '').split(',').filter(Boolean);
const ADMIN_GITHUB_USERS = (process.env.ADMIN_GITHUB_USERS || '').split(',').filter(Boolean);

/**
 * Verify GitHub token and get user information
 */
async function verifyGitHubToken(token) {
    try {
        const octokit = new Octokit({ auth: token });
        const { data: user } = await octokit.rest.users.getAuthenticated();
        
        // Get user's organization memberships
        const { data: orgs } = await octokit.rest.orgs.listForAuthenticatedUser();
        const userOrgs = orgs.map(org => org.login);
        
        return {
            id: user.id,
            login: user.login,
            name: user.name,
            email: user.email,
            avatar_url: user.avatar_url,
            organizations: userOrgs,
            token: token
        };
    } catch (error) {
        throw new Error(`Invalid GitHub token: ${error.message}`);
    }
}

/**
 * Generate JWT token for authenticated user
 */
function generateJWT(user) {
    const payload = {
        id: user.id,
        login: user.login,
        name: user.name,
        email: user.email,
        organizations: user.organizations,
        isAdmin: ADMIN_GITHUB_USERS.includes(user.login),
        iat: Math.floor(Date.now() / 1000)
    };
    
    return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

/**
 * Verify and decode JWT token
 */
function verifyJWT(token) {
    try {
        return jwt.verify(token, JWT_SECRET);
    } catch (error) {
        throw new Error(`Invalid JWT token: ${error.message}`);
    }
}

/**
 * Check if user has permission to access organization
 */
function hasOrgPermission(user, org) {
    // Admins can access all organizations
    if (user.isAdmin) {
        return true;
    }
    
    // Check if user is member of the organization
    if (user.organizations && user.organizations.includes(org)) {
        return true;
    }
    
    // Check against allowed organizations list
    if (ALLOWED_GITHUB_ORGS.length > 0 && !ALLOWED_GITHUB_ORGS.includes(org)) {
        return false;
    }
    
    return true;
}

/**
 * Authentication middleware
 */
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN
    
    if (!token) {
        return res.status(401).json({
            success: false,
            error: 'Access token required',
            code: 'AUTH_REQUIRED'
        });
    }
    
    try {
        const user = verifyJWT(token);
        req.user = user;
        next();
    } catch (error) {
        return res.status(403).json({
            success: false,
            error: 'Invalid or expired token',
            code: 'AUTH_INVALID'
        });
    }
}

/**
 * Organization access middleware
 */
function requireOrgAccess(req, res, next) {
    const org = req.params.org || req.body.org;
    
    if (!org) {
        return res.status(400).json({
            success: false,
            error: 'Organization parameter required',
            code: 'ORG_REQUIRED'
        });
    }
    
    if (!hasOrgPermission(req.user, org)) {
        return res.status(403).json({
            success: false,
            error: `Access denied to organization: ${org}`,
            code: 'ORG_ACCESS_DENIED'
        });
    }
    
    req.organization = org;
    next();
}

/**
 * Admin access middleware
 */
function requireAdmin(req, res, next) {
    if (!req.user.isAdmin) {
        return res.status(403).json({
            success: false,
            error: 'Admin access required',
            code: 'ADMIN_REQUIRED'
        });
    }
    
    next();
}

/**
 * Input validation middleware
 */
function validateApprovalRequest(req, res, next) {
    const { repos, rolloutType, approvedBy } = req.body;
    const errors = [];
    
    // Validate repositories
    if (!repos || !Array.isArray(repos) || repos.length === 0) {
        errors.push('repos must be a non-empty array');
    } else if (repos.some(repo => typeof repo !== 'string' || repo.trim() === '')) {
        errors.push('all repository names must be non-empty strings');
    }
    
    // Validate rollout type
    const validRolloutTypes = ['full', 'deps-only', 'actions-only', 'dry-run'];
    if (rolloutType && !validRolloutTypes.includes(rolloutType)) {
        errors.push(`rolloutType must be one of: ${validRolloutTypes.join(', ')}`);
    }
    
    // Validate approver
    if (!approvedBy || typeof approvedBy !== 'string' || approvedBy.trim() === '') {
        errors.push('approvedBy is required and must be a non-empty string');
    }
    
    // Additional validation
    if (repos && repos.length > 50) {
        errors.push('maximum 50 repositories allowed per rollout');
    }
    
    if (errors.length > 0) {
        return res.status(400).json({
            success: false,
            error: 'Validation failed',
            details: errors,
            code: 'VALIDATION_ERROR'
        });
    }
    
    next();
}

/**
 * Rate limiting by user
 */
function createUserRateLimit() {
    const userRequests = new Map();
    const WINDOW_SIZE = 15 * 60 * 1000; // 15 minutes
    const MAX_REQUESTS = 50; // per user per window
    
    return (req, res, next) => {
        const userId = req.user ? req.user.id : req.ip;
        const now = Date.now();
        
        // Clean old entries
        for (const [user, data] of userRequests.entries()) {
            if (now - data.windowStart > WINDOW_SIZE) {
                userRequests.delete(user);
            }
        }
        
        // Get or create user entry
        let userEntry = userRequests.get(userId);
        if (!userEntry || now - userEntry.windowStart > WINDOW_SIZE) {
            userEntry = { count: 0, windowStart: now };
            userRequests.set(userId, userEntry);
        }
        
        // Check rate limit
        if (userEntry.count >= MAX_REQUESTS) {
            return res.status(429).json({
                success: false,
                error: 'Rate limit exceeded',
                resetTime: new Date(userEntry.windowStart + WINDOW_SIZE).toISOString(),
                code: 'RATE_LIMIT_EXCEEDED'
            });
        }
        
        userEntry.count++;
        next();
    };
}

/**
 * Audit logging middleware
 */
function auditLog(action) {
    return (req, res, next) => {
        const originalSend = res.send;
        
        res.send = function(data) {
            // Log the action
            const logEntry = {
                timestamp: new Date().toISOString(),
                action,
                user: req.user ? {
                    id: req.user.id,
                    login: req.user.login,
                    name: req.user.name
                } : null,
                organization: req.organization,
                ip: req.ip,
                userAgent: req.get('User-Agent'),
                statusCode: res.statusCode,
                requestBody: action === 'approval' ? {
                    repos: req.body.repos,
                    rolloutType: req.body.rolloutType,
                    approvedBy: req.body.approvedBy
                } : undefined
            };
            
            console.log('AUDIT:', JSON.stringify(logEntry));
            
            // Call original send
            originalSend.call(this, data);
        };
        
        next();
    };
}

/**
 * Security headers middleware
 */
function securityHeaders(req, res, next) {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
    
    if (process.env.NODE_ENV === 'production') {
        res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    }
    
    next();
}

/**
 * Error handling middleware
 */
function errorHandler(error, req, res, next) {
    console.error('Unhandled error:', error);
    
    // Don't leak error details in production
    const isDevelopment = process.env.NODE_ENV !== 'production';
    
    res.status(500).json({
        success: false,
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        details: isDevelopment ? error.message : undefined,
        stack: isDevelopment ? error.stack : undefined,
        timestamp: new Date().toISOString()
    });
}

module.exports = {
    verifyGitHubToken,
    generateJWT,
    verifyJWT,
    hasOrgPermission,
    authenticateToken,
    requireOrgAccess,
    requireAdmin,
    validateApprovalRequest,
    createUserRateLimit,
    auditLog,
    securityHeaders,
    errorHandler
};