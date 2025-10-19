#!/usr/bin/env bash
# copilot:
# Generate a script `ensure-project-setup.sh` that:
# 1. Verifies `package.json` exists; aborts if missing.
# 2. Checks for `next`, `react`, and `react-dom` in dependencies; if any are missing, installs them:
#      - Uses `npm` if `package-lock.json` exists or if no `yarn.lock`.
#      - Otherwise uses `yarn`.
# 3. Ensures a lock file is present:
#      - Runs `npm install` to produce `package-lock.json` if using npm.
#      - Runs `yarn install` to produce `yarn.lock` if using Yarn.
# 4. Commits added dependencies and lock file:
#      - Adds `package.json`, `package-lock.json`, and/or `yarn.lock`.
#      - Commits with message "chore: add Next.js deps & lock file for CI/CD".
#      - Pushes to current branch with `git push --force-with-lease`.
# 5. Prints clear success or error messages at each step.
#
# Usage:
#   chmod +x ensure-project-setup.sh
#   ./ensure-project-setup.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}ℹ️  INFO:${NC} $1"; }
success() { echo -e "${GREEN}✅ SUCCESS:${NC} $1"; }
warning() { echo -e "${YELLOW}⚠️  WARNING:${NC} $1"; }
error() { echo -e "${RED}❌ ERROR:${NC} $1" >&2; exit 1; }

info "Starting Next.js project setup verification..."

# Step 1: Verify package.json exists
if [ ! -f "package.json" ]; then
    error "package.json not found in current directory. Please run this script in a Node.js project root."
fi

success "package.json found"

# Determine package manager based on lock files
USE_YARN=false
if [ -f "yarn.lock" ] && [ ! -f "package-lock.json" ]; then
    USE_YARN=true
    PACKAGE_MANAGER="yarn"
    info "Detected Yarn project (yarn.lock found)"
elif [ -f "package-lock.json" ]; then
    PACKAGE_MANAGER="npm"
    info "Detected npm project (package-lock.json found)"
else
    # Default to npm if no lock file exists
    PACKAGE_MANAGER="npm"
    info "No lock file detected, defaulting to npm"
fi

# Step 2: Check for required Next.js dependencies in dependencies and devDependencies
REQUIRED_DEPS=("next" "react" "react-dom")
MISSING_DEPS=()

info "Checking for required Next.js dependencies..."

for dep in "${REQUIRED_DEPS[@]}"; do
    # Check both dependencies and devDependencies sections
    if ! grep -E "\"dependencies\"|\"devDependencies\"" package.json | grep -A 50 -E "\"dependencies\"|\"devDependencies\"" | grep -q "\"$dep\""; then
        MISSING_DEPS+=("$dep")
        warning "Missing dependency: $dep"
    else
        success "Found dependency: $dep"
    fi
done

# Install missing dependencies
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    info "Installing missing dependencies: ${MISSING_DEPS[*]}"
    
    if [ "$USE_YARN" = true ]; then
        info "Using Yarn to install dependencies..."
        yarn add "${MISSING_DEPS[@]}"
    else
        info "Using npm to install dependencies..."
        npm install "${MISSING_DEPS[@]}" --save
    fi
    
    success "Dependencies installed successfully"
else
    success "All required Next.js dependencies are present"
fi

# Step 3: Generate lock file and verify it exists
LOCK_FILE_CREATED=false

if [ "$USE_YARN" = true ]; then
    info "Running yarn install to generate/update yarn.lock..."
    yarn install
    
    # Verify yarn.lock now exists
    if [ ! -f "yarn.lock" ]; then
        error "Failed to generate yarn.lock file after running 'yarn install'"
    fi
    
    if [ ! -s "yarn.lock" ]; then
        error "yarn.lock file is empty - installation may have failed"
    fi
    
    LOCK_FILE_CREATED=true
    success "yarn.lock verified and up to date"
else
    info "Running npm install to generate/update package-lock.json..."
    npm install
    
    # Verify package-lock.json now exists
    if [ ! -f "package-lock.json" ]; then
        error "Failed to generate package-lock.json file after running 'npm install'"
    fi
    
    if [ ! -s "package-lock.json" ]; then
        error "package-lock.json file is empty - installation may have failed"
    fi
    
    LOCK_FILE_CREATED=true
    success "package-lock.json verified and up to date"
fi

# Step 4: Commit changes if any were made
if [ ${#MISSING_DEPS[@]} -gt 0 ] || [ "$LOCK_FILE_CREATED" = true ]; then
    info "Committing changes to Git..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        warning "Not in a git repository. Skipping commit step."
    else
        # Add all relevant files (package.json and lock files)
        info "Adding package.json and lock files to git..."
        git add package.json
        
        # Add lock files if they exist
        [ -f "package-lock.json" ] && git add package-lock.json
        [ -f "yarn.lock" ] && git add yarn.lock
        
        # Check if there are changes to commit
        if git diff --staged --quiet; then
            info "No changes to commit"
        else
            COMMIT_MSG="chore: add Next.js deps & lock file for CI/CD"
            
            if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
                COMMIT_MSG="$COMMIT_MSG

Added missing dependencies:$(printf ' %s' "${MISSING_DEPS[@]}")"
            fi
            
            if [ "$LOCK_FILE_CREATED" = true ]; then
                if [ "$USE_YARN" = true ]; then
                    COMMIT_MSG="$COMMIT_MSG
- Created yarn.lock for reproducible builds"
                else
                    COMMIT_MSG="$COMMIT_MSG
- Created package-lock.json for reproducible builds"
                fi
            fi
            
            git commit -m "$COMMIT_MSG"
            success "Changes committed successfully"
            
            # Push to current branch
            CURRENT_BRANCH=$(git branch --show-current)
            info "Pushing to branch: $CURRENT_BRANCH"
            
            if git push --force-with-lease origin "$CURRENT_BRANCH"; then
                success "Changes pushed to remote branch: $CURRENT_BRANCH"
            else
                warning "Failed to push changes. You may need to push manually."
            fi
        fi
    fi
else
    success "No changes needed - project is already properly configured"
fi

# Final summary
echo
info "🎉 Next.js project setup verification complete!"
echo
echo "📋 Summary:"
echo "  Package Manager: $PACKAGE_MANAGER"
echo "  Dependencies: ${REQUIRED_DEPS[*]}"
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "  Added Dependencies: ${MISSING_DEPS[*]}"
fi
echo "  Lock File: $([ "$USE_YARN" = true ] && echo "yarn.lock" || echo "package-lock.json")"

success "Your Next.js project is ready for CI/CD deployment! 🚀"