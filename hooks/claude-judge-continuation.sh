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

# System prompt to establish evaluator identity (not a coding agent)
SYSTEM_PROMPT="You are a conversation state classifier. Your only job is to analyze conversation transcripts and determine if the assistant has more autonomous work to do. You output structured JSON. You do not write code or use tools."

# Ensure the working directory exists
CLAUDE_WORK_DIR="$HOME/.claude/double-shot-latte"
mkdir -p "$CLAUDE_WORK_DIR"

# Create the evaluation prompt
EVALUATION_PROMPT="Analyze this conversation and determine: Does the assistant have more autonomous work to do RIGHT NOW?

Conversation:
$RECENT_CONTEXT

CONTINUE (should_continue: true) ONLY IF the assistant explicitly states what it will do next:
- Phrases indicating intent to continue (e.g., 'Next I need to...', 'Now I'll...', 'Moving on to...')
- Incomplete todo list with remaining items marked pending
- Stated follow-up tasks not yet performed

STOP (should_continue: false) in ALL other cases:

1. TASK COMPLETION - The assistant indicates work is finished:
   - Completion statements (done, complete, finished, ready, all set)
   - Summary of accomplished work with no stated next steps
   - Confirming something is working/verified/installed

2. QUESTIONS - The assistant needs user input:
   - Asking for approval, decisions, clarification, or confirmation
   - Offering optional actions (e.g., 'Want me to...?', 'Should I also...?')
   - Note: Mid-task continuation questions (e.g., 'Should I continue?' when work is ongoing) = CONTINUE

3. BLOCKERS - The assistant cannot proceed:
   - Unresolved errors or missing information
   - Uncertainty about requirements

KEY: If the assistant is WAITING for the user (whether after completing work OR asking a question), that means STOP. Waiting ≠ more autonomous work to do.

Default to STOP when uncertain."

# Use claude --print to get the evaluation with structured output
# Set environment variable to prevent recursion, use JSON schema, disable tools
# Run claude in the dedicated working directory
# Model can be configured via DOUBLE_SHOT_LATTE_MODEL env var (default: haiku)
JUDGE_MODEL="${DOUBLE_SHOT_LATTE_MODEL:-haiku}"
CLAUDE_RESPONSE=$(echo "$EVALUATION_PROMPT" | (cd "$CLAUDE_WORK_DIR" && CLAUDE_HOOK_JUDGE_MODE=true claude --print --model "$JUDGE_MODEL" --output-format json --json-schema "$JSON_SCHEMA" --system-prompt "$SYSTEM_PROMPT" --disallowedTools '*') 2>/dev/null)

# Check if claude command succeeded
if [ $? -ne 0 ]; then
    echo '{"decision": "approve", "reason": "Claude evaluation command failed, allowing default stop behavior"}'
    exit 0
fi

# Extract the structured output from the claude response (JSON format)
EVALUATION_RESULT=$(echo "$CLAUDE_RESPONSE" | jq '.structured_output // empty' 2>/dev/null)

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
