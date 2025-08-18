#!/bin/bash

# Test all Inbox implementations
# This script runs the test suite against each Inbox implementation

set -e

echo "========================================="
echo "Testing All Inbox Implementations"
echo "========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
declare -a IMPLEMENTATIONS=("base" "opt1" "opt2" "opt3")
declare -a RESULTS=()

# Function to run tests for an implementation
run_tests() {
    local impl=$1
    local display_name=""
    
    # Map implementation codes to display names
    case $impl in
        "base")
            display_name="Inbox.sol"
            ;;
        "opt1")
            display_name="InboxOptimized1.sol"
            ;;
        "opt2")
            display_name="InboxOptimized2.sol"
            ;;
        "opt3")
            display_name="InboxOptimized3.sol"
            ;;
        *)
            display_name=$impl
            ;;
    esac
    
    echo ""
    echo -e "${YELLOW}Testing Inbox Implementation: ${display_name}${NC}"
    echo "----------------------------------------"
    
    if INBOX=$impl FOUNDRY_PROFILE=layer1 forge test --match-path "test/layer1/shasta/inbox/*.t.sol"; then
        echo -e "${GREEN}✓ ${display_name} tests passed${NC}"
        RESULTS+=("${display_name}: PASSED")
        return 0
    else
        echo -e "${RED}✗ ${display_name} tests failed${NC}"
        RESULTS+=("${display_name}: FAILED")
        return 1
    fi
}

# Run tests for each implementation
FAILED=0
for impl in "${IMPLEMENTATIONS[@]}"; do
    if ! run_tests "$impl"; then
        FAILED=$((FAILED + 1))
    fi
done

# Print summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
for result in "${RESULTS[@]}"; do
    if [[ $result == *"PASSED"* ]]; then
        echo -e "${GREEN}$result${NC}"
    else
        echo -e "${RED}$result${NC}"
    fi
done

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All implementations passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}$FAILED implementation(s) failed${NC}"
    exit 1
fi