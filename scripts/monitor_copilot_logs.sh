#!/usr/bin/env bash
# scripts/monitor_copilot_logs.sh
# Scan Copilot logs for errors or summary metrics.

set -euo pipefail

LOG_DIR="logs/copilot"
ERROR_PATTERN="ERROR|Exception|Traceback|FATAL|WARN"
SUMMARY_FILE="copilot_log_summary.txt"

# Helpers
info() { echo -e "\e[1;34m[INFO]\e[0m $1"; }
success() { echo -e "\e[1;32m[SUCCESS]\e[0m $1"; }
warning() { echo -e "\e[1;33m[WARN]\e[0m $1"; }

info "Scanning Copilot logs in $LOG_DIR..."

# Initialize summary report
cat > "$SUMMARY_FILE" << EOF
# Copilot Log Monitoring Report
Generated: $(date -u '+%Y-%m-%d %H:%M UTC')
Repository: $(git config --get remote.origin.url 2>/dev/null || echo "Unknown")
Branch: $(git branch --show-current 2>/dev/null || echo "Unknown")

## Summary Statistics
EOF

# Check if log directory exists and has files
if [ ! -d "$LOG_DIR" ] || [ -z "$(find "$LOG_DIR" -name "*.log" -o -name "*.txt" 2>/dev/null)" ]; then
    warning "No Copilot log files found in $LOG_DIR"
    echo "Status: No log files found" >> "$SUMMARY_FILE"
    echo "Note: Place Copilot log files in $LOG_DIR for monitoring" >> "$SUMMARY_FILE"
    success "Summary written to $SUMMARY_FILE"
    exit 0
fi

# Count total log entries
TOTAL_ENTRIES=$(find "$LOG_DIR" -type f \( -name "*.log" -o -name "*.txt" \) -exec grep -H "" {} \; 2>/dev/null | wc -l)
echo "- Total log entries: $TOTAL_ENTRIES" >> "$SUMMARY_FILE"

# Count error occurrences
ERROR_COUNT=$(find "$LOG_DIR" -type f \( -name "*.log" -o -name "*.txt" \) -exec grep -E "$ERROR_PATTERN" {} \; 2>/dev/null | wc -l)
echo "- Error/Exception occurrences: $ERROR_COUNT" >> "$SUMMARY_FILE"

# Count completions generated (common Copilot log pattern)
COMPLETE_COUNT=$(find "$LOG_DIR" -type f \( -name "*.log" -o -name "*.txt" \) -exec grep -i "completion" {} \; 2>/dev/null | wc -l)
echo "- Completions generated: $COMPLETE_COUNT" >> "$SUMMARY_FILE"

# Count suggestions accepted
ACCEPTED_COUNT=$(find "$LOG_DIR" -type f \( -name "*.log" -o -name "*.txt" \) -exec grep -i "accepted\|applied" {} \; 2>/dev/null | wc -l)
echo "- Suggestions accepted: $ACCEPTED_COUNT" >> "$SUMMARY_FILE"

# Calculate acceptance rate if data available
if [ "$COMPLETE_COUNT" -gt 0 ]; then
    ACCEPTANCE_RATE=$((ACCEPTED_COUNT * 100 / COMPLETE_COUNT))
    echo "- Acceptance rate: ${ACCEPTANCE_RATE}%" >> "$SUMMARY_FILE"
fi

# Add detailed sections
cat >> "$SUMMARY_FILE" << EOF

## Recent Errors (Last 5)
EOF

if [ "$ERROR_COUNT" -gt 0 ]; then
    find "$LOG_DIR" -type f \( -name "*.log" -o -name "*.txt" \) -exec grep -H -E "$ERROR_PATTERN" {} \; 2>/dev/null | tail -n 5 >> "$SUMMARY_FILE"
else
    echo "No errors found in recent logs ✅" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << EOF

## Log Files Analyzed
EOF

find "$LOG_DIR" -type f \( -name "*.log" -o -name "*.txt" \) -exec ls -lh {} \; 2>/dev/null | awk '{print "- " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}' >> "$SUMMARY_FILE"

# Health status
cat >> "$SUMMARY_FILE" << EOF

## Health Status
EOF

if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "🟢 **Healthy** - No errors detected" >> "$SUMMARY_FILE"
elif [ "$ERROR_COUNT" -lt 5 ]; then
    echo "🟡 **Warning** - Few errors detected ($ERROR_COUNT)" >> "$SUMMARY_FILE"
else
    echo "🔴 **Alert** - Multiple errors detected ($ERROR_COUNT)" >> "$SUMMARY_FILE"
fi

# Performance insights
if [ "$COMPLETE_COUNT" -gt 0 ] && [ "$ACCEPTED_COUNT" -gt 0 ]; then
    echo "" >> "$SUMMARY_FILE"
    echo "## Performance Insights" >> "$SUMMARY_FILE"
    
    if [ "$ACCEPTANCE_RATE" -gt 70 ]; then
        echo "🚀 **Excellent** - High acceptance rate (${ACCEPTANCE_RATE}%)" >> "$SUMMARY_FILE"
    elif [ "$ACCEPTANCE_RATE" -gt 50 ]; then
        echo "✅ **Good** - Moderate acceptance rate (${ACCEPTANCE_RATE}%)" >> "$SUMMARY_FILE"
    else
        echo "⚠️  **Review Needed** - Low acceptance rate (${ACCEPTANCE_RATE}%)" >> "$SUMMARY_FILE"
    fi
fi

info "Analysis complete:"
info "  - Total entries: $TOTAL_ENTRIES"
info "  - Errors found: $ERROR_COUNT"
info "  - Completions: $COMPLETE_COUNT"

success "Summary written to $SUMMARY_FILE"

# Display key metrics
if [ "$ERROR_COUNT" -eq 0 ]; then
    success "🟢 Copilot logs are healthy - no errors detected"
elif [ "$ERROR_COUNT" -lt 5 ]; then
    warning "🟡 Minor issues detected - $ERROR_COUNT errors found"
else
    echo -e "\e[1;31m[ALERT]\e[0m 🔴 Multiple errors detected - $ERROR_COUNT errors found"
fi