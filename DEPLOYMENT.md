# Environment Configuration for Approval Dashboard

## Required Environment Variables

### Backend API (.env)
```bash
# GitHub Integration
GITHUB_TOKEN=your_github_token_here
GH_TOKEN=your_github_token_here  # Fallback

# Dashboard Configuration  
DASHBOARD_ORIGIN=https://butterdime.github.io
TARGET_OWNER=Butterdime
TARGET_REPO=ci-toolkit

# Server Configuration
NODE_ENV=production
PORT=3001
```

### Vercel Deployment
```bash
# Set these in Vercel dashboard or via CLI:
vercel env add GITHUB_TOKEN
vercel env add DASHBOARD_ORIGIN
vercel env add TARGET_OWNER  
vercel env add TARGET_REPO
```

### GitHub Secrets (Repository Settings)
```bash
# Required secrets for GitHub Actions:
GITHUB_TOKEN  # Automatically available
GH_TOKEN      # Optional: Custom token with broader permissions
```

## GitHub Token Permissions

Your GitHub token needs these scopes:
- `repo` - Full repository access
- `workflow` - Workflow management
- `read:org` - Organization reading
- `read:user` - User information

## API Endpoints

### Production API
- Base URL: `https://your-approval-api.vercel.app/api`
- Health: `GET /api/health`
- Readiness: `GET /api/readiness/:org`
- Approve: `POST /api/approve/:org`
- Status: `GET /api/status/:org`

### Local Development
- Base URL: `http://localhost:3001/api`
- Start server: `cd api && npm run dev`

## Dashboard Configuration

### Update Dashboard URLs
In `dashboard/approval-dashboard.html`, update:
```javascript
const API_BASE_URL = 'https://your-approval-api.vercel.app/api';
const ORGANIZATIONS = ['Butterdime', 'YourOrg']; // Add your organizations
```

## Deployment Checklist

### 1. Deploy API Backend
```bash
# Deploy to Vercel
cd /path/to/ci-toolkit
vercel --prod

# Or deploy to other serverless platforms:
# - AWS Lambda
# - Google Cloud Functions  
# - Azure Functions
```

### 2. Configure GitHub Pages
```bash
# Enable GitHub Pages for dashboard hosting
# Point to dashboard/ directory or copy files to docs/
```

### 3. Set up Repository Dispatch
```bash
# Ensure the approved-rollout.yml workflow is in .github/workflows/
# Test with manual dispatch:
gh workflow run "🚀 Approved CI/CD Rollout" \
  --field organization=TestOrg \
  --field rollout_type=dry-run
```

### 4. Test End-to-End Flow
1. Open approval dashboard
2. Check organization readiness
3. Click "Approve & Execute" 
4. Verify workflow triggers
5. Monitor real-time feedback

## Security Considerations

### API Security
- Rate limiting: 100 requests per 15 minutes per IP
- CORS: Restricted to dashboard origin
- Input validation: All parameters validated
- Authentication: GitHub token required

### GitHub Permissions
- Use principle of least privilege
- Consider using GitHub App for better security
- Rotate tokens regularly
- Monitor token usage

### Approval Audit
- All approvals logged with timestamp
- Approver identity required
- Workflow run links maintained
- Full audit trail in GitHub Actions logs

## Monitoring & Observability

### Dashboard Metrics
- Organization readiness status
- Rollout success/failure rates
- Response time monitoring
- Error tracking and alerting

### GitHub Actions Monitoring
- Workflow execution metrics
- Step-level timing analysis
- Failure pattern analysis
- Resource usage tracking

### API Monitoring
- Endpoint response times
- Error rates and types
- Token usage patterns
- Rate limit violations

## Troubleshooting

### Common Issues

#### API Not Responding
```bash
# Check API health
curl https://your-approval-api.vercel.app/api/health

# Check environment variables
vercel env ls

# Check logs
vercel logs --limit=50
```

#### GitHub API Rate Limits
```bash
# Check rate limit status
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/rate_limit

# Use GitHub App for higher limits
# Implement retry logic with exponential backoff
```

#### Workflow Not Triggering
```bash
# Verify repository dispatch permissions
gh api repos/:owner/:repo/dispatches --method POST \
  --field event_type=test

# Check workflow file syntax
gh workflow list
gh workflow view "🚀 Approved CI/CD Rollout"
```

#### Dashboard Loading Issues
```bash
# Check CORS configuration
# Verify API endpoints are accessible
# Check browser console for JavaScript errors
# Validate organization names in configuration
```

### Debug Mode

Enable debug logging:
```bash
# API backend
DEBUG=approval-dashboard:* npm start

# Feedback loop script  
FEEDBACK_DEBUG=1 ./scripts/feedback-loop.sh test

# Rollout script
ROLLOUT_DEBUG=1 ./scripts/rollout-deps.sh true TestOrg
```

## Performance Optimization

### API Optimization
- Implement response caching
- Use database for persistent storage
- Add Redis for session management
- Implement pagination for large datasets

### Dashboard Optimization
- Add service worker for offline support  
- Implement real-time WebSocket updates
- Add progressive loading for large organizations
- Cache API responses locally

### GitHub Actions Optimization
- Use matrix strategies for parallel execution
- Implement smart repository filtering
- Add workflow caching for dependencies
- Use composite actions for reusability