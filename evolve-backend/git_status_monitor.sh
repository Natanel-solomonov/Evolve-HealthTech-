#!/bin/bash

# Git Status Monitor (Bash Version)
# Runs git status every 30 seconds with progress tracking

set -e

# Configuration
INTERVAL=30
RUN_COUNT=0
START_TIME=$(date +%s)
ERRORS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print progress
print_progress() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    
    echo -e "\n${YELLOW}============================================================${NC}"
    echo -e "${YELLOW}Git Status Monitor - Run #$RUN_COUNT${NC}"
    echo -e "${YELLOW}Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${YELLOW}Elapsed: ${elapsed} seconds${NC}"
    echo -e "${YELLOW}Errors: $ERRORS${NC}"
    echo -e "${YELLOW}Interval: $INTERVAL seconds${NC}"
    echo -e "${YELLOW}============================================================${NC}"
}

# Function to run git status
run_git_status() {
    if git status > /tmp/git_status_output 2>&1; then
        echo -e "${GREEN}✅ Git Status:${NC}"
        cat /tmp/git_status_output
        rm -f /tmp/git_status_output
    else
        echo -e "${RED}❌ Error running git status:${NC}"
        cat /tmp/git_status_output
        rm -f /tmp/git_status_output
        ((ERRORS++))
    fi
}

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    echo "Please run this script from within a git repository"
    exit 1
fi

echo -e "${GREEN}Starting Git Status Monitor...${NC}"
echo -e "${GREEN}Monitoring every $INTERVAL seconds${NC}"
echo -e "${GREEN}Press Ctrl+C to stop${NC}"

# Trap to handle cleanup on exit
trap 'echo -e "\n\n${YELLOW}Monitoring stopped by user${NC}"; echo "Total runs: $RUN_COUNT"; echo "Total errors: $ERRORS"; echo "Total time: $(($(date +%s) - START_TIME)) seconds"; exit 0' INT

# Main monitoring loop
while true; do
    ((RUN_COUNT++))
    print_progress
    run_git_status
    sleep $INTERVAL
done 