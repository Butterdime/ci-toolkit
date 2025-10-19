#!/usr/bin/env bash
# Feedback Loop System for CI/CD Approval Dashboard
# Updates dashboard status and provides real-time feedback during rollout execution

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
error() { echo -e "${RED}❌ ERROR:${NC} $1" >&2; }

# Configuration
API_BASE_URL="${API_BASE_URL:-https://your-approval-api.vercel.app/api}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
STATUS_FILE="/tmp/rollout-status.json"

# Function to update rollout status
update_status() {
    local org="$1"
    local status="$2"
    local message="$3"
    local progress="${4:-0}"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$STATUS_FILE" << EOF
{
  "organization": "$org",
  "status": "$status",
  "message": "$message", 
  "progress": $progress,
  "timestamp": "$timestamp",
  "workflow_run": "$GITHUB_RUN_ID",
  "workflow_url": "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
}
EOF

    info "Status updated: $status - $message"
    
    # If API endpoint is configured, post update
    if [ -n "$API_BASE_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
        post_status_update "$org" || warning "Failed to post status update to API"
    fi
}

# Function to post status to API
post_status_update() {
    local org="$1"
    
    if ! command -v curl >/dev/null 2>&1; then
        warning "curl not available, skipping API status update"
        return 1
    fi
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -d @"$STATUS_FILE" \
        "$API_BASE_URL/status/$org" || true)
    
    if [ -n "$response" ]; then
        info "API response: $response"
    fi
}

# Function to track repository rollout progress
track_repo_progress() {
    local org="$1"
    local repo="$2"
    local status="$3"
    local details="$4"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    info "Repository progress: $org/$repo - $status"
    
    # Create detailed progress entry
    cat >> "/tmp/repo-progress-$org.json" << EOF
{
  "repository": "$repo",
  "status": "$status", 
  "details": "$details",
  "timestamp": "$timestamp"
},
EOF
}

# Function to generate final rollout report
generate_rollout_report() {
    local org="$1"
    local overall_status="$2"
    local start_time="$3"
    local end_time="$4"
    
    local report_file="/tmp/rollout-report-$org-$(date +%Y%m%d-%H%M%S).json"
    
    info "Generating rollout report for $org..."
    
    # Calculate duration
    local duration=""
    if [ -n "$start_time" ] && [ -n "$end_time" ]; then
        local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
        local end_epoch=$(date -d "$end_time" +%s 2>/dev/null || echo "0")
        if [ "$start_epoch" != "0" ] && [ "$end_epoch" != "0" ]; then
            local duration_seconds=$((end_epoch - start_epoch))
            duration="${duration_seconds}s"
        fi
    fi
    
    # Collect repository progress if available
    local repo_progress="[]"
    if [ -f "/tmp/repo-progress-$org.json" ]; then
        # Remove trailing comma and wrap in array
        sed '$ s/,$//' "/tmp/repo-progress-$org.json" | sed '1i[' | sed '$a]' > "/tmp/repo-progress-clean.json" || true
        repo_progress=$(cat "/tmp/repo-progress-clean.json" 2>/dev/null || echo "[]")
    fi
    
    cat > "$report_file" << EOF
{
  "organization": "$org",
  "overall_status": "$overall_status",
  "start_time": "$start_time",
  "end_time": "$end_time",
  "duration": "$duration",
  "workflow_run_id": "$GITHUB_RUN_ID",
  "workflow_url": "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID",
  "repository_progress": $repo_progress,
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    success "Rollout report generated: $report_file"
    
    # Post final report to API
    if [ -n "$API_BASE_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
        post_final_report "$org" "$report_file" || warning "Failed to post final report"
    fi
    
    echo "$report_file"
}

# Function to post final report to API
post_final_report() {
    local org="$1"
    local report_file="$2"
    
    if ! command -v curl >/dev/null 2>&1; then
        warning "curl not available, skipping final report upload"
        return 1
    fi
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -d @"$report_file" \
        "$API_BASE_URL/reports/$org" || true)
    
    if [ -n "$response" ]; then
        success "Final report posted to API"
    fi
}

# Function to notify dashboard of workflow completion
notify_completion() {
    local org="$1" 
    local status="$2"
    local report_file="$3"
    
    info "Notifying dashboard of completion: $org - $status"
    
    local notification_payload=""
    if [ -f "$report_file" ]; then
        notification_payload=$(cat "$report_file")
    else
        notification_payload='{
            "organization": "'$org'",
            "status": "'$status'", 
            "completed_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
        }'
    fi
    
    if [ -n "$API_BASE_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $GITHUB_TOKEN" \
            -d "$notification_payload" \
            "$API_BASE_URL/completion/$org" || warning "Failed to notify completion"
    fi
}

# Function to create GitHub issue comment for tracking
create_tracking_comment() {
    local org="$1"
    local status="$2" 
    local details="$3"
    
    # This would create a comment on a tracking issue
    # Implementation depends on your issue tracking setup
    info "Would create tracking comment: $org - $status"
}

# Main execution based on command line arguments
main() {
    local command="${1:-}"
    
    case "$command" in
        "start")
            local org="${2:-}"
            local message="${3:-Rollout started}"
            [ -z "$org" ] && { error "Organization required for start command"; exit 1; }
            update_status "$org" "started" "$message" 0
            ;;
            
        "progress")
            local org="${2:-}"
            local repo="${3:-}"
            local repo_status="${4:-}"
            local details="${5:-}"
            [ -z "$org" ] && { error "Organization required for progress command"; exit 1; }
            [ -z "$repo" ] && { error "Repository required for progress command"; exit 1; }
            [ -z "$repo_status" ] && { error "Status required for progress command"; exit 1; }
            track_repo_progress "$org" "$repo" "$repo_status" "$details"
            ;;
            
        "update")
            local org="${2:-}"
            local status="${3:-}"
            local message="${4:-}"
            local progress="${5:-50}"
            [ -z "$org" ] && { error "Organization required for update command"; exit 1; }
            [ -z "$status" ] && { error "Status required for update command"; exit 1; }
            [ -z "$message" ] && { error "Message required for update command"; exit 1; }
            update_status "$org" "$status" "$message" "$progress"
            ;;
            
        "complete")
            local org="${2:-}"
            local final_status="${3:-success}"
            local start_time="${4:-}"
            local end_time="${5:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
            [ -z "$org" ] && { error "Organization required for complete command"; exit 1; }
            
            update_status "$org" "completed" "Rollout completed with status: $final_status" 100
            local report_file=$(generate_rollout_report "$org" "$final_status" "$start_time" "$end_time")
            notify_completion "$org" "$final_status" "$report_file"
            ;;
            
        "test")
            info "Testing feedback loop system..."
            
            # Test all functions with dummy data
            update_status "test-org" "testing" "System test in progress" 25
            track_repo_progress "test-org" "test-repo" "success" "Test completion"
            
            local test_report=$(generate_rollout_report "test-org" "success" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")
            success "Test completed. Report: $test_report"
            ;;
            
        *)
            echo "Usage: $0 {start|progress|update|complete|test} [args...]"
            echo ""
            echo "Commands:"
            echo "  start <org> [message]                    - Start rollout tracking"
            echo "  progress <org> <repo> <status> [details] - Track repository progress"  
            echo "  update <org> <status> <message> [progress] - Update overall status"
            echo "  complete <org> [status] [start_time] [end_time] - Complete rollout"
            echo "  test                                     - Test all functions"
            echo ""
            echo "Environment variables:"
            echo "  API_BASE_URL    - Base URL for status API"
            echo "  GITHUB_TOKEN    - GitHub token for API calls"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"