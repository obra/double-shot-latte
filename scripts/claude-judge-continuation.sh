#!/bin/bash

# Claude Auto-Continue Plugin - Stop Hook Script (Aggressive Version)
# Automatically evaluates whether Claude should continue working instead of stopping prematurely
# Uses another Claude instance to judge whether continuation is appropriate
# DEFAULT STANCE: Continue unless there's a CLEAR reason to stop

# Check if we're in a recursive call (judge Claude instance)
if [ "$CLAUDE_HOOK_JUDGE_MODE" = "true" ]; then
    echo '{"decision": "approve", "reason": "Running in judge mode, allowing stop"}'
    exit 0
fi

# Read the hook event data
EVENT=$(cat)

# Extract key information
STOP_HOOK_ACTIVE=$(echo "$EVENT" | jq -r '.stop_hook_active // false')
TRANSCRIPT_PATH=$(echo "$EVENT" | jq -r '.transcript_path // ""')

# Time-based throttling to prevent infinite loops
SESSION_ID=$(echo "$EVENT" | jq -r '.session_id // "unknown"')
THROTTLE_FILE="/tmp/.claude-continue-throttle-$(echo "$SESSION_ID" | tr '/' '_')"
CURRENT_TIME=$(date +%s)

# If this is already a continuation from a previous stop hook, check time throttling
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    # Allow up to 3 continuations in 5 minutes, then force stop
    CONTINUE_COUNT=0
    LAST_CONTINUE_TIME=0
    if [ -f "$THROTTLE_FILE" ]; then
        THROTTLE_DATA=$(cat "$THROTTLE_FILE")
        CONTINUE_COUNT=$(echo "$THROTTLE_DATA" | cut -d: -f1)
        LAST_CONTINUE_TIME=$(echo "$THROTTLE_DATA" | cut -d: -f2)
    fi

    TIME_SINCE_LAST=$((CURRENT_TIME - LAST_CONTINUE_TIME))

    # Reset counter if it's been more than 5 minutes
    if [ "$TIME_SINCE_LAST" -gt 300 ]; then
        CONTINUE_COUNT=0
    fi

    # If we've continued too many times recently, force stop
    if [ "$CONTINUE_COUNT" -ge 3 ] && [ "$TIME_SINCE_LAST" -lt 300 ]; then
        echo '{"decision": "approve", "reason": "Maximum continuation cycles reached in time window, forcing stop to prevent infinite loops"}'
        rm -f "$THROTTLE_FILE"
        exit 0
    fi
fi

# Check if we have a transcript path
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    echo '{"decision": "approve", "reason": "No transcript available for evaluation"}'
    exit 0
fi

# Extract the last few exchanges from the transcript (Claude's response + context)
# We want the most recent assistant message and some preceding context
RECENT_CONTEXT=$(tail -n 10 "$TRANSCRIPT_PATH" | jq -s '.')

# Create a JSON schema for the response
JSON_SCHEMA='{"type":"object","properties":{"should_continue":{"type":"boolean"},"reasoning":{"type":"string"}},"required":["should_continue","reasoning"]}'

# Create a prompt for Claude to evaluate whether continuation is appropriate
EVALUATION_PROMPT="You are evaluating whether a Claude Code session should continue working. Your default stance is to CONTINUE unless there's a CLEAR reason to stop.

Here is the recent conversation context:
$RECENT_CONTEXT

CONTINUE (return should_continue: true) unless the assistant has EXPLICITLY indicated one of these clear stop reasons:
1. Directly asking for user decisions (\"Which approach would you prefer?\", \"How should I handle...\")
2. Requesting specific clarification on ambiguous requirements
3. Work is genuinely complete AND properly documented
4. Explicitly stated need for user input (\"I need you to...\")

ALWAYS CONTINUE if:
- Work appears incomplete or partial
- There are obvious next steps (more files to create, more functions to implement, more tests to write)
- Assistant mentioned follow-up work (\"Next I'll...\", \"I should also...\")
- Implementation has TODOs, stubs, or placeholder content
- Multi-step process with remaining steps
- Assistant is in the middle of a logical sequence

The test: If a user could reasonably type 'continue' and Claude would know what to do next, return should_continue: true.

Return should_continue: false ONLY for clear, explicit stop signals requiring user input."

# Use claude --print to get the evaluation with structured output
# Set environment variable to prevent recursion and use JSON schema for reliable parsing
CLAUDE_RESPONSE=$(echo "$EVALUATION_PROMPT" | CLAUDE_HOOK_JUDGE_MODE=true claude --print --model haiku --output-format json --json-schema "$JSON_SCHEMA" 2>/dev/null)

# Check if claude command succeeded
if [ $? -ne 0 ]; then
    echo '{"decision": "approve", "reason": "Claude evaluation command failed, allowing default stop behavior"}'
    exit 0
fi

# Extract the structured output from the claude response (stream JSON format)
EVALUATION_RESULT=$(echo "$CLAUDE_RESPONSE" | jq '.[] | select(.type == "result") | .structured_output // empty' 2>/dev/null)

# If no structured output, fall back to allowing stop
if [ -z "$EVALUATION_RESULT" ] || [ "$EVALUATION_RESULT" = "null" ]; then
    echo '{"decision": "approve", "reason": "Could not parse Claude evaluation result, allowing default stop behavior"}'
    exit 0
fi

# Parse the evaluation result (should be JSON)
SHOULD_CONTINUE=$(echo "$EVALUATION_RESULT" | jq -r '.should_continue // false')
REASONING=$(echo "$EVALUATION_RESULT" | jq -r '.reasoning // "No reasoning provided"')

# Make the decision based on Claude's evaluation
if [ "$SHOULD_CONTINUE" = "true" ]; then
    # Update throttle tracking
    if [ -f "$THROTTLE_FILE" ]; then
        THROTTLE_DATA=$(cat "$THROTTLE_FILE")
        CONTINUE_COUNT=$(echo "$THROTTLE_DATA" | cut -d: -f1)
        CONTINUE_COUNT=$((CONTINUE_COUNT + 1))
    else
        CONTINUE_COUNT=1
    fi
    echo "$CONTINUE_COUNT:$CURRENT_TIME" > "$THROTTLE_FILE"

    # Block the stop - Claude thinks it can continue
    jq -n --arg reason "Claude evaluator determined continuation is appropriate: $REASONING" '{
        "decision": "block",
        "reason": $reason
    }'
else
    # Clear throttle file since we're allowing a legitimate stop
    rm -f "$THROTTLE_FILE"

    # Allow the stop - Claude thinks stopping is appropriate
    jq -n --arg reason "Claude evaluator determined stopping is appropriate: $REASONING" '{
        "decision": "approve",
        "reason": $reason
    }'
fi

exit 0