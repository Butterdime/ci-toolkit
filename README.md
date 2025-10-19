# CI Standardization Toolkit

A comprehensive enterprise-grade toolkit for standardizing CI/CD workflows across multiple repositories in your organization. This toolkit provides automated rollout, monitoring, and management of consistent Node.js dependency workflows.

## 🎯 Overview

This toolkit helps organizations:
- **Standardize CI workflows** across all Node.js/TypeScript repositories
- **Automate rollout** of new CI standards via pull requests
- **Monitor adoption** with real-time dashboards
- **Maintain consistency** through reusable composite actions

## 📁 Repository Structure

```
ci-toolkit/
├── .github/
│   ├── actions/
│   │   └── setup-node-deps/         # Reusable composite action
│   │       └── action.yml
│   └── workflows/
│       └── deps-install.yml         # Template workflow file
├── scripts/
│   └── rollout-deps.sh             # Automated rollout script
├── monitor_adoption.py             # Adoption monitoring dashboard
└── README.md                       # This documentation
```

## 🚀 Quick Start

### 1. Prerequisites

- **GitHub CLI**: Install and authenticate with `gh auth login`
- **Python 3.x**: For running the monitoring dashboard
- **Bash**: For running the rollout script

```bash
# Install required Python packages
pip install requests

# Verify GitHub CLI authentication
gh auth status
```

### 2. Setup Your Organization

1. **Fork or use this template** to create your organization's CI toolkit repository
2. **Customize the composite action** in `.github/actions/setup-node-deps/action.yml` if needed
3. **Update organization references** in scripts to match your org name

### 3. Execute Rollout

```bash
# Run in dry-run mode first (recommended)
./scripts/rollout-deps.sh true YOUR_ORG_NAME

# Execute real rollout
./scripts/rollout-deps.sh false YOUR_ORG_NAME
```

### 4. Monitor Progress

```bash
# Set your GitHub token
export GITHUB_TOKEN=your_github_token

# Generate adoption dashboard
python3 monitor_adoption.py YOUR_ORG_NAME

# View dashboard in browser
open adoption_dashboard.html
```

## 🔧 Components

### Composite Action: `setup-node-deps`

**Location**: `.github/actions/setup-node-deps/action.yml`

Intelligent Node.js dependency setup with caching:
- ✅ **Smart Detection**: Automatically detects npm vs Yarn projects
- ⚡ **Optimized Caching**: Caches `~/.npm`, `~/.yarn/cache`, and `node_modules`
- 🔒 **Reproducible Builds**: Uses `npm ci` and `yarn --frozen-lockfile`
- 🛡️ **Fallback Support**: Falls back to `npm install` when no lock file exists

**Usage in your workflows**:
```yaml
- name: Setup Node Dependencies
  uses: YOUR_ORG/ci-toolkit/.github/actions/setup-node-deps@v1.0.0
```

### Rollout Script: `rollout-deps.sh`

**Location**: `scripts/rollout-deps.sh`

Automated bulk deployment across repositories:
- 🎯 **Repository Discovery**: Auto-finds JavaScript/TypeScript repos
- 🔍 **Smart Filtering**: Only processes repos with `package.json`
- 📋 **Dry-Run Mode**: Test before real deployment
- 🚀 **PR Automation**: Creates, commits, and opens pull requests
- 📊 **Progress Tracking**: Colored output and detailed logging

**Usage**:
```bash
# Dry run (test mode)
./scripts/rollout-deps.sh true YOUR_ORG_NAME

# Real deployment
./scripts/rollout-deps.sh false YOUR_ORG_NAME
```

### Monitoring Dashboard: `monitor_adoption.py`

**Location**: `monitor_adoption.py`

Real-time adoption tracking:
- 📈 **Adoption Metrics**: Shows percentage of repos with standardized workflows
- 🌐 **HTML Dashboard**: Generates shareable visual reports
- 🔍 **Multi-Account Support**: Works with both organizations and personal accounts
- ⚡ **Multi-Language**: Supports JavaScript and TypeScript repositories

**Usage**:
```bash
export GITHUB_TOKEN=your_token_here
python3 monitor_adoption.py YOUR_ORG_NAME
```

## ⚙️ Configuration

### GitHub Token Requirements

Your GitHub token needs these scopes:
- `repo` - Repository access
- `read:org` - Organization repository listing (for org accounts)

### Repository Requirements

Target repositories should have:
- A `package.json` file (for Node.js projects)
- Either `package-lock.json` or `yarn.lock` (recommended for reproducible builds)

### Branch Protection Rules

For production use, configure branch protection on target repositories:
- ✅ Require pull request reviews
- ✅ Require status checks to pass
- ✅ Include administrators in restrictions

## 🎨 Customization

### Extending the Composite Action

Edit `.github/actions/setup-node-deps/action.yml` to:
- Add additional caching paths
- Include custom setup steps
- Support additional package managers (pnpm, etc.)

### Adding New Workflows

1. Create new workflow templates in `.github/workflows/`
2. Update `rollout-deps.sh` to handle multiple workflow files
3. Extend monitoring to track new workflow adoption

### Custom Monitoring Metrics

Enhance `monitor_adoption.py` to track:
- Build success rates
- Performance improvements from caching
- Security scan results
- Code quality metrics

## � GitHub & Vercel Integration

### Automated Deployment Pipeline Setup

Link GitHub repositories to Vercel for automated previews and production deployments:

```bash
# Export required tokens
export VERCEL_TOKEN=<your_vercel_token>
export GITHUB_TOKEN=<your_github_token>

# Link GitHub repo to Vercel with complete integration
./scripts/setup-vercel.sh <GITHUB_ORG> <REPO_NAME> <VERCEL_ORG> <VERCEL_PROJECT_ALIAS>

# Example: Connect automation-workflow-dashboard to Vercel
./scripts/setup-vercel.sh Butterdime automation-workflow-dashboard Butterdime vercel-automation
```

**Enhanced Features:**
- 🔐 **Secret Synchronization**: Automatically syncs GitHub secrets to Vercel environment
- 🎯 **Smart Integration**: Detects and configures common secrets (API_KEY, DATABASE_URL, etc.)
- ⚡ **One-Command Setup**: Complete GitHub → Vercel pipeline in a single script
- 🛡️ **Error Handling**: Graceful handling of missing secrets and configuration issues

**What this enables:**
- ✅ **Automated Production Deployments**: Every push to `main` branch
- 🔍 **Preview Deployments**: Every pull request gets its own preview URL
- 📊 **Deployment Dashboard**: Monitor all deployments in Vercel dashboard
- 🔄 **Git Integration**: Seamless GitHub → Vercel workflow

### Complete CI/CD Pipeline

Combine standardized dependencies + automated deployments:

```bash
# 1. Standardize CI across repositories
./scripts/rollout-deps.sh false your-org

# 2. Set up Vercel integration for each repo
echo "repo1\nrepo2\nrepo3" > repos.txt
while read repo; do
  ./scripts/setup-vercel.sh your-org "$repo" your-vercel-org "$repo"
done < repos.txt

# 3. Monitor overall adoption
python3 monitor_adoption.py your-org
```

## �📚 Usage Examples

### Example 1: Organization Rollout
```bash
# 1. Test with dry run
./scripts/rollout-deps.sh true acme-corp

# 2. Review proposed changes
cat rollout-log.txt

# 3. Execute real rollout
./scripts/rollout-deps.sh false acme-corp

# 4. Monitor progress
python3 monitor_adoption.py acme-corp
```

### Example 2: Personal Account Testing
```bash
# Test on your personal repositories
./scripts/rollout-deps.sh true your-username
python3 monitor_adoption.py your-username
```

### Example 3: Complete Pipeline Setup
```bash
# Full enterprise deployment with Vercel integration
./scripts/rollout-deps.sh false acme-corp
./scripts/setup-vercel.sh acme-corp next-app acme-corp next-production
python3 monitor_adoption.py acme-corp
```

### Example 4: Scheduled Monitoring
```bash
# Add to cron for regular monitoring
0 9 * * * cd /path/to/ci-toolkit && python3 monitor_adoption.py acme-corp
```

## 🛠️ Troubleshooting

### Common Issues

**"GitHub CLI not authenticated"**
```bash
gh auth login
gh auth status
```

**"No JavaScript repositories found"**
- Verify organization name is correct
- Check if repositories are private (requires appropriate token permissions)
- Consider adding TypeScript to the language filter

**"Package.json not found"**
- This is expected for non-Node.js repositories
- The script correctly skips these repositories

**"PR creation failed"**
- Check if branch protection rules require specific status checks
- Verify token has `repo` scope permissions
- Ensure no conflicting branch names exist

### Debug Mode

Enable verbose output in scripts:
```bash
# Add debugging to rollout script
bash -x ./scripts/rollout-deps.sh true YOUR_ORG
```

## 🏗️ Advanced Deployment

### Enterprise Setup

1. **Create organization template repository**:
   ```bash
   gh repo create YOUR_ORG/ci-toolkit --template --public
   ```

2. **Set up as organization standard**:
   - Add to organization documentation
   - Include in onboarding checklists
   - Configure organization-wide policies

3. **Automate with GitHub Actions**:
   ```yaml
   # .github/workflows/monitor.yml
   name: Monitor CI Adoption
   on:
     schedule:
       - cron: '0 9 * * 1'  # Weekly Monday 9 AM
   jobs:
     monitor:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - run: python3 monitor_adoption.py ${{ github.repository_owner }}
   ```

### Multi-Organization Management

For managing multiple organizations:
```bash
# Create organization list
echo "org1\norg2\norg3" > organizations.txt

# Batch processing
while read org; do
  echo "Processing $org..."
  ./scripts/rollout-deps.sh false "$org"
  python3 monitor_adoption.py "$org"
done < organizations.txt
```

## 📊 Metrics and Success Criteria

### Key Performance Indicators

- **Adoption Rate**: Percentage of eligible repositories using standardized workflows
- **Rollout Speed**: Time from script execution to PR merge
- **Build Performance**: CI execution time improvements from caching
- **Error Reduction**: Decrease in dependency-related build failures

### Success Benchmarks

- 🎯 **Target**: 90%+ adoption rate within 30 days
- ⚡ **Performance**: 30%+ reduction in dependency installation time
- 🔒 **Reliability**: 50%+ reduction in dependency-related failures
- 📈 **Developer Satisfaction**: Positive feedback on standardized workflows

## 🤝 Contributing

### Adding New Features

1. Fork this repository
2. Create feature branch: `git checkout -b feature/new-workflow`
3. Add your changes
4. Test thoroughly with dry-run mode
5. Submit pull request with documentation updates

### Reporting Issues

Please include:
- Script output/error messages
- Organization/repository context
- Steps to reproduce
- Expected vs actual behavior

## 📝 License

This toolkit is released under the MIT License. See [LICENSE](LICENSE) for details.

## 🏷️ Version History

- **v1.0.0** - Initial release with Node.js dependency standardization
  - Composite action for dependency setup with caching
  - Automated rollout script with dry-run support
  - HTML monitoring dashboard
  - Support for JavaScript and TypeScript repositories

---

## 🎉 Get Started

Ready to standardize your organization's CI/CD workflows? 

1. **Use this template** to create your organization's toolkit
2. **Customize** the workflows for your needs  
3. **Test** with dry-run mode
4. **Deploy** across your repositories
5. **Monitor** adoption and celebrate success! 🚀

For questions or support, please [open an issue](https://github.com/YOUR_ORG/ci-toolkit/issues) or reach out to your DevOps team.