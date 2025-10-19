#!/usr/bin/env bash
# setup-vercel.sh
# Automate linking a GitHub repo to Vercel and enabling preview + production deployments.
# Usage: ./setup-vercel.sh <GITHUB_ORG> <REPO_NAME> <VERCEL_ORG> <VERCEL_PROJECT_ALIAS>
# Requires: VERCEL_TOKEN, GITHUB_TOKEN exported.

set -euo pipefail

GH_ORG=$1
REPO=$2
V_ORG=$3
PROJECT=$4

# Helpers
info() { echo -e "\e[1;34m[INFO]\e[0m $1"; }
success() { echo -e "\e[1;32m[SUCCESS]\e[0m $1"; }
warning() { echo -e "\e[1;33m[WARN]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

# Validate required environment variables
[ -n "${VERCEL_TOKEN:-}" ] || error "VERCEL_TOKEN environment variable is required"
[ -n "${GITHUB_TOKEN:-}" ] || error "GITHUB_TOKEN environment variable is required"

info "Setting up Vercel integration for ${GH_ORG}/${REPO}..."

# Create temporary directory for repo clone
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Clone repo
info "Cloning repository ${GH_ORG}/${REPO}..."
if ! gh repo clone "${GH_ORG}/${REPO}" . &>/dev/null; then
    error "Failed to clone repository ${GH_ORG}/${REPO}"
fi

# Install Vercel CLI if missing
if ! command -v vercel &>/dev/null; then
    info "Installing Vercel CLI..."
    npm install -g vercel
fi

# Authenticate Vercel CLI
info "Authenticating with Vercel..."
echo "$VERCEL_TOKEN" | vercel login --stdin

# Connect Git repo to Vercel project
info "Connecting GitHub repo to Vercel project..."
vercel link --project="$PROJECT" --scope="$V_ORG" --yes

# Enable Git integration for previews & production
info "Enabling Git integration for automated deployments..."
vercel git connect --yes

# Set production branch
info "Configuring production branch..."
vercel git set production-branch main

success "✅ Vercel integration completed for ${GH_ORG}/${REPO}"
info "🚀 Production deployments: Enabled on 'main' branch"
info "🔍 Preview deployments: Enabled on all PR branches"
info "📊 Dashboard: https://vercel.com/${V_ORG}/${PROJECT}"

# Cleanup
cd /
rm -rf "$TMP_DIR"

echo
info "Next steps:"
echo "  1. Push to 'main' branch to trigger production deployment"
echo "  2. Create PR to test preview deployment functionality"
echo "  3. Configure environment variables in Vercel dashboard if needed"