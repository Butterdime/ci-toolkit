#!/usr/bin/env bash
# rollout-deps.sh
# Automate rollout of standardized Node dependency workflows across repositories.
# Usage: ./rollout-deps.sh <DRY_RUN(true|false)> <ORG_NAME>

set -euo pipefail

DRY_RUN=$1
ORG=$2
REPOS_FILE="repos.txt"
LOG_FILE="rollout-log.txt"

# Helpers
error() { echo "Error: $1" >&2; exit 1; }
info() { echo -e "\e[1;34m[INFO]\e[0m $1"; }
success() { echo -e "\e[1;32m[SUCCESS]\e[0m $1"; }
warning() { echo -e "\e[1;33m[WARN]\e[0m $1"; }

# Ensure GH CLI auth
gh auth status &>/dev/null || error "GitHub CLI not authenticated."

# Fetch JS repos if no repos.txt
if [ ! -f "$REPOS_FILE" ]; then
  info "Discovering JavaScript repos in $ORG..."
  gh repo list "$ORG" --language JavaScript --json name \
    --jq '.[].name' > "$REPOS_FILE"
fi

TOTAL=$(wc -l < "$REPOS_FILE")
COUNT=0

info "Starting rollout for $TOTAL repositories (dry-run=$DRY_RUN)."
echo > "$LOG_FILE"

while read -r repo; do
  COUNT=$((COUNT+1))
  info "[$COUNT/$TOTAL] Processing $repo..."

  TMP_DIR=$(mktemp -d)
  if ! gh repo clone "$ORG/$repo" "$TMP_DIR" &>/dev/null; then
    warning "Clone failed for $repo, skipping."
    echo "$repo: clone-fail" >> "$LOG_FILE"
    rm -rf "$TMP_DIR"
    continue
  fi

  pushd "$TMP_DIR" &>/dev/null

  # Check for package.json
  if [ ! -f package.json ]; then
    warning "$repo has no package.json, skipping."
    echo "$repo: no-package-json" >> "../$LOG_FILE"
    popd &>/dev/null
    rm -rf "$TMP_DIR"
    continue
  fi

  # Prepare workflow path
  mkdir -p .github/workflows
  WORKFLOW_FILE=".github/workflows/deps-install.yml"

  # Generate workflow
  cat > "$WORKFLOW_FILE" << 'EOF'
name: Install Dependencies

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  setup-node-deps:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ./.github/actions/setup-node-deps
EOF

  # Create branch and commit
  BRANCH="add-deps-setup"
  git checkout -b "$BRANCH"
  git add "$WORKFLOW_FILE"
  git commit -m "ci: add standardized dependency installation workflow"

  if [ "$DRY_RUN" = "true" ]; then
    info "Dry run: would push branch $BRANCH for $repo"
    echo "$repo: dry-run" >> "../$LOG_FILE"
  else
    git push --set-upstream origin "$BRANCH"
    gh pr create \
      --repo "$ORG/$repo" \
      --title "ci: add standardized dependency installation workflow" \
      --body "This PR adds a composite action to cache and install Node dependencies consistently across the organization." \
      --base main
    success "PR created for $repo"
    echo "$repo: pr-created" >> "../$LOG_FILE"
  fi

  popd &>/dev/null
  rm -rf "$TMP_DIR"

done < "$REPOS_FILE"

info "Rollout complete. See $LOG_FILE for details."