#!/bin/bash
# SPDX-License-Identifier: MIT

# Comprehensive test runner for Shasta Inbox tests
# Supports running tests across all inbox implementations

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configurations
INBOX_TYPES=("base" "opt1" "opt2" "opt3")
DEFAULT_VERBOSITY="vv"
TEST_PATH="test/layer1/shasta/inbox"

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to print test header
print_header() {
    print_color "$BLUE" "============================================================"
    print_color "$BLUE" "$1"
    print_color "$BLUE" "============================================================"
}

# Function to run tests for a specific inbox implementation
run_inbox_tests() {
    local inbox_type=$1
    local test_filter=${2:-""}
    local verbosity=${3:-$DEFAULT_VERBOSITY}
    
    print_header "Running tests for INBOX=$inbox_type"
    
    local cmd="INBOX=$inbox_type FOUNDRY_PROFILE=layer1 forge test"
    
    if [ -n "$test_filter" ]; then
        cmd="$cmd --match-path \"$TEST_PATH/$test_filter\""
    else
        cmd="$cmd --match-path \"$TEST_PATH/*.t.sol\""
    fi
    
    cmd="$cmd -$verbosity"
    
    print_color "$YELLOW" "Command: $cmd"
    
    if eval "$cmd"; then
        print_color "$GREEN" "✓ Tests passed for $inbox_type"
    else
        print_color "$RED" "✗ Tests failed for $inbox_type"
        return 1
    fi
}

# Function to run tests for all implementations
run_all_implementations() {
    local test_filter=${1:-""}
    local verbosity=${2:-$DEFAULT_VERBOSITY}
    local failed_implementations=()
    
    for inbox_type in "${INBOX_TYPES[@]}"; do
        if ! run_inbox_tests "$inbox_type" "$test_filter" "$verbosity"; then
            failed_implementations+=("$inbox_type")
        fi
        echo
    done
    
    # Summary
    print_header "Test Summary"
    
    if [ ${#failed_implementations[@]} -eq 0 ]; then
        print_color "$GREEN" "✓ All implementations passed!"
    else
        print_color "$RED" "✗ Failed implementations: ${failed_implementations[*]}"
        return 1
    fi
}

# Function to run a specific test across all implementations
run_specific_test() {
    local test_name=$1
    local verbosity=${2:-$DEFAULT_VERBOSITY}
    
    print_header "Running test: $test_name"
    
    for inbox_type in "${INBOX_TYPES[@]}"; do
        print_color "$YELLOW" "Testing $inbox_type..."
        
        local cmd="INBOX=$inbox_type FOUNDRY_PROFILE=layer1 forge test --match-test \"$test_name\" -$verbosity"
        
        if eval "$cmd"; then
            print_color "$GREEN" "✓ $inbox_type passed"
        else
            print_color "$RED" "✗ $inbox_type failed"
        fi
    done
}

# Function to run gas comparison across implementations
run_gas_comparison() {
    local test_filter=${1:-""}
    
    print_header "Gas Usage Comparison"
    
    for inbox_type in "${INBOX_TYPES[@]}"; do
        print_color "$YELLOW" "Gas report for $inbox_type:"
        
        local cmd="INBOX=$inbox_type FOUNDRY_PROFILE=layer1 forge test"
        
        if [ -n "$test_filter" ]; then
            cmd="$cmd --match-path \"$TEST_PATH/$test_filter\""
        else
            cmd="$cmd --match-path \"$TEST_PATH/*.t.sol\""
        fi
        
        cmd="$cmd --gas-report"
        
        eval "$cmd" | grep -E "^│|Function" || true
        echo
    done
}

# Function to run tests with coverage
run_with_coverage() {
    local inbox_type=${1:-"base"}
    
    print_header "Running coverage for INBOX=$inbox_type"
    
    INBOX="$inbox_type" FOUNDRY_PROFILE=layer1 forge coverage --match-path "$TEST_PATH/*.t.sol"
}

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Commands:
    all [test_file] [verbosity]  Run tests for all implementations (default)
    single <inbox_type> [test_file] [verbosity]  Run tests for a specific implementation
    test <test_name> [verbosity]  Run a specific test across all implementations
    gas [test_file]  Compare gas usage across implementations
    coverage [inbox_type]  Run tests with coverage
    summary  Run tests and generate summary report
    help  Show this help message

Options:
    inbox_type: base, opt1, opt2, opt3
    test_file: Name of test file (e.g., InboxBasicTest.t.sol)
    test_name: Name of specific test function
    verbosity: v, vv, vvv, vvvv (default: vv)

Examples:
    $0 all                          # Run all tests for all implementations
    $0 all InboxBasicTest.t.sol    # Run specific file for all implementations
    $0 single opt3                  # Run all tests for opt3 implementation
    $0 single base InboxInit.t.sol vvv  # Run specific file for base with high verbosity
    $0 test test_propose_single_valid  # Run specific test across all implementations
    $0 gas                          # Compare gas usage across all implementations
    $0 coverage opt2                # Run coverage for opt2 implementation

Environment Variables:
    INBOX: Override inbox type (base, opt1, opt2, opt3)
    FOUNDRY_PROFILE: Override Foundry profile (default: layer1)
EOF
}

# Function to generate summary report
generate_summary() {
    print_header "Generating Test Summary Report"
    
    local report_file="inbox-test-summary-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Shasta Inbox Test Summary Report"
        echo "Generated: $(date)"
        echo "============================================================"
        echo
        
        for inbox_type in "${INBOX_TYPES[@]}"; do
            echo "Implementation: $inbox_type"
            echo "------------------------------------------------------------"
            
            INBOX="$inbox_type" FOUNDRY_PROFILE=layer1 forge test --match-path "$TEST_PATH/*.t.sol" --summary 2>&1 | tail -20
            
            echo
        done
    } > "$report_file"
    
    print_color "$GREEN" "Summary report saved to: $report_file"
}

# Main script logic
main() {
    local command=${1:-all}
    
    case "$command" in
        all)
            run_all_implementations "${2:-}" "${3:-$DEFAULT_VERBOSITY}"
            ;;
        single)
            if [ $# -lt 2 ]; then
                print_color "$RED" "Error: inbox_type required for 'single' command"
                show_help
                exit 1
            fi
            run_inbox_tests "$2" "${3:-}" "${4:-$DEFAULT_VERBOSITY}"
            ;;
        test)
            if [ $# -lt 2 ]; then
                print_color "$RED" "Error: test_name required for 'test' command"
                show_help
                exit 1
            fi
            run_specific_test "$2" "${3:-$DEFAULT_VERBOSITY}"
            ;;
        gas)
            run_gas_comparison "${2:-}"
            ;;
        coverage)
            run_with_coverage "${2:-base}"
            ;;
        summary)
            generate_summary
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_color "$RED" "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"