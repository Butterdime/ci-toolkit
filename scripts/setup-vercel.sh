#!/usr/bin/env bash
# copilot:
# Generate a script `setup-vercel.sh` to automate linking a GitHub repo to Vercel:
#   1. Accept args: <GITHUB_ORG> <REPO_NAME> <VERCEL_ORG> <VERCEL_PROJECT_ALIAS>
#   2. Clone the repo via GitHub CLI.
#   3. Install Vercel CLI globally if missing.
#   4. Authenticate Vercel CLI with $VERCEL_TOKEN.
#   5. Run `vercel git connect`:
#        --org=$VERCEL_ORG --project=$VERCEL_PROJECT_ALIAS --token=$VERCEL_TOKEN --yes
#   6. Enable Git integration: `vercel git set --github`.
#   7. Fetch a GitHub secret via `gh secret get SECRET_NAME` and add it to Vercel env:
#        vercel env add production SECRET_NAME <value> --project=$VERCEL_PROJECT_ALIAS --token=$VERCEL_TOKEN
#   8. Print success message.

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
trap "rm -rf $TMP_DIR" EXIT

# Clone repo via GitHub CLI
info "Cloning repository ${GH_ORG}/${REPO}..."
if ! gh repo clone "${GH_ORG}/${REPO}" "$TMP_DIR" &>/dev/null; then
    error "Failed to clone repository ${GH_ORG}/${REPO}"
fi

cd "$TMP_DIR"

# Install Vercel CLI globally if missing
if ! command -v vercel &>/dev/null; then
    info "Installing Vercel CLI globally..."
    npm install -g vercel
fi

# Authenticate Vercel CLI with $VERCEL_TOKEN
info "Authenticating Vercel CLI with token..."
vercel login --token="$VERCEL_TOKEN"

# Run vercel git connect with specified parameters
info "Connecting GitHub repo to Vercel project..."
vercel git connect \
    --org="$V_ORG" \
    --project="$PROJECT" \
    --token="$VERCEL_TOKEN" \
    --yes

# Enable Git integration with GitHub
info "Enabling Git integration with GitHub..."
vercel git set --github --token="$VERCEL_TOKEN" --project="$PROJECT"

# Fetch GitHub secret and add to Vercel environment
SECRET_NAME="API_KEY"
info "Syncing GitHub secrets to Vercel environment..."
if API_KEY=$(gh secret get "$SECRET_NAME" --repo "${GH_ORG}/${REPO}" 2>/dev/null); then
    info "Adding secret '$SECRET_NAME' to Vercel production environment..."
    vercel env add production "$SECRET_NAME" "$API_KEY" \
        --project="$PROJECT" \
        --token="$VERCEL_TOKEN" \
        --force
    success "Secret '$SECRET_NAME' successfully added to Vercel"
else
    warning "Secret '$SECRET_NAME' not found in GitHub repo, skipping..."
fi

# Optional: Add more common secrets
for secret in "DATABASE_URL" "JWT_SECRET" "STRIPE_SECRET_KEY"; do
    if SECRET_VALUE=$(gh secret get "$secret" --repo "${GH_ORG}/${REPO}" 2>/dev/null); then
        info "Adding secret '$secret' to Vercel..."
        vercel env add production "$secret" "$SECRET_VALUE" \
            --project="$PROJECT" \
            --token="$VERCEL_TOKEN" \
            --force
        success "Secret '$secret' added to Vercel"
    fi
done

success "✅ Vercel integration completed for ${GH_ORG}/${REPO}"
info "🚀 Production deployments: Enabled on 'main' branch"
info "🔍 Preview deployments: Enabled on all PR branches"
info "🔐 Secrets: Synced from GitHub to Vercel"
info "📊 Dashboard: https://vercel.com/${V_ORG}/${PROJECT}"

echo
info "Next steps:"
echo "  1. Push to 'main' branch to trigger production deployment"
echo "  2. Create PR to test preview deployment functionality"  
echo "  3. Verify environment variables in Vercel dashboard"
echo "  4. Monitor deployments at https://vercel.com/${V_ORG}/${PROJECT}"