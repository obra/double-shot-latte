#!/bin/bash

# Hook Evaluation Test Suite
# Runs contrived conversation scenarios through the hook and validates decisions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"
HOOK_SCRIPT="$SCRIPT_DIR/../../scripts/claude-judge-continuation.sh"
TEMP_DIR="/tmp/hook-evals-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TEMP_DIR"

echo "🧪 Running Hook Evaluation Suite"
echo "================================="
echo ""

total_scenarios=0
total_passed=0
total_failed=0

# Process each scenario file
for scenario_file in "$SCENARIOS_DIR"/*.json; do
    if [ ! -f "$scenario_file" ]; then
        continue
    fi

    total_scenarios=$((total_scenarios + 1))
    scenario_name=$(jq -r '.name' "$scenario_file")
    description=$(jq -r '.description' "$scenario_file")
    expected_decision=$(jq -r '.expected_decision' "$scenario_file")

    echo "📝 Scenario: $scenario_name"
    echo "   Description: $description"
    echo "   Expected: should_continue = $expected_decision"
    echo ""

    # Run the scenario 5 times
    passes=0
    fails=0

    for run in {1..5}; do
        # Create transcript file from scenario (NDJSON format - one message per line)
        transcript_file="$TEMP_DIR/transcript-$total_scenarios-$run.json"
        jq -c '.transcript[]' "$scenario_file" > "$transcript_file"

        # Create mock hook event
        hook_event=$(jq -n \
            --arg transcript_path "$transcript_file" \
            '{
                "stop_hook_active": false,
                "transcript_path": $transcript_path,
                "session_id": "eval-test-session"
            }')

        # Run the hook script
        hook_output=$(echo "$hook_event" | "$HOOK_SCRIPT" 2>/dev/null || echo '{"decision": "error"}')

        # Parse the hook decision
        decision=$(echo "$hook_output" | jq -r '.decision')
        reason=$(echo "$hook_output" | jq -r '.reason // "No reason provided"')

        # Determine if hook would continue (block = continue, approve = stop)
        hook_should_continue=false
        if [ "$decision" = "block" ]; then
            hook_should_continue=true
        fi

        # Check if it matches expected
        if [ "$hook_should_continue" = "$expected_decision" ]; then
            passes=$((passes + 1))
            echo -e "   ${GREEN}✓${NC} Run $run: PASS (decision: $decision)"
        else
            fails=$((fails + 1))
            echo -e "   ${RED}✗${NC} Run $run: FAIL (decision: $decision, expected should_continue: $expected_decision)"
            echo "      Reason: $reason"
        fi
    done

    echo ""

    # Report scenario results
    if [ $fails -eq 0 ]; then
        echo -e "   ${GREEN}✓ Scenario PASSED${NC} (5/5 runs correct)"
        total_passed=$((total_passed + 1))
    else
        echo -e "   ${RED}✗ Scenario FAILED${NC} ($passes/5 runs correct)"
        total_failed=$((total_failed + 1))
    fi

    echo ""
    echo "---"
    echo ""
done

# Final summary
echo "================================="
echo "📊 Final Results"
echo "================================="
echo "Total scenarios: $total_scenarios"
echo -e "Passed: ${GREEN}$total_passed${NC}"
echo -e "Failed: ${RED}$total_failed${NC}"

if [ $total_failed -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All scenarios passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some scenarios failed${NC}"
    exit 1
fi
