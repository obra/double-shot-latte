#!/usr/bin/env node

// Claude Auto-Continue Plugin - Stop Hook Script (Aggressive Version)
// Cross-platform Node.js implementation
// Automatically evaluates whether Claude should continue working instead of stopping prematurely

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync, spawnSync } = require('child_process');

// Check if we're in a recursive call (judge Claude instance)
if (process.env.CLAUDE_HOOK_JUDGE_MODE === 'true') {
    console.log(JSON.stringify({ decision: 'approve', reason: 'Running in judge mode, allowing stop' }));
    process.exit(0);
}

// Read the hook event data from stdin
let eventData = '';
const stdin = fs.readFileSync(0, 'utf8');
let event;
try {
    event = JSON.parse(stdin);
} catch (e) {
    console.log(JSON.stringify({ decision: 'approve', reason: 'Could not parse event data' }));
    process.exit(0);
}

// Extract key information
const stopHookActive = event.stop_hook_active || false;
const transcriptPath = event.transcript_path || '';
const sessionId = event.session_id || 'unknown';

// Time-based throttling to prevent infinite loops
const throttleFile = path.join(os.tmpdir(), `.claude-continue-throttle-${sessionId.replace(/\//g, '_')}`);
const currentTime = Math.floor(Date.now() / 1000);

// If this is already a continuation from a previous stop hook, check time throttling
if (stopHookActive) {
    let continueCount = 0;
    let lastContinueTime = 0;

    if (fs.existsSync(throttleFile)) {
        try {
            const throttleData = fs.readFileSync(throttleFile, 'utf8').trim();
            const parts = throttleData.split(':');
            continueCount = parseInt(parts[0], 10) || 0;
            lastContinueTime = parseInt(parts[1], 10) || 0;
        } catch (e) {
            // Ignore read errors
        }
    }

    const timeSinceLast = currentTime - lastContinueTime;

    // Reset counter if it's been more than 5 minutes
    if (timeSinceLast > 300) {
        continueCount = 0;
    }

    // If we've continued too many times recently, force stop
    if (continueCount >= 3 && timeSinceLast < 300) {
        console.log(JSON.stringify({
            decision: 'approve',
            reason: 'Maximum continuation cycles reached in time window, forcing stop to prevent infinite loops'
        }));
        try { fs.unlinkSync(throttleFile); } catch (e) {}
        process.exit(0);
    }
}

// Check if we have a transcript path
if (!transcriptPath || !fs.existsSync(transcriptPath)) {
    console.log(JSON.stringify({ decision: 'approve', reason: 'No transcript available for evaluation' }));
    process.exit(0);
}

// Extract the last few exchanges from the transcript
let recentContext;
try {
    const transcriptContent = fs.readFileSync(transcriptPath, 'utf8');
    const lines = transcriptContent.trim().split('\n').slice(-10);
    recentContext = JSON.stringify(lines.map(line => {
        try { return JSON.parse(line); } catch (e) { return line; }
    }));
} catch (e) {
    console.log(JSON.stringify({ decision: 'approve', reason: 'Could not read transcript file' }));
    process.exit(0);
}

// Create a JSON schema for the response
const jsonSchema = JSON.stringify({
    type: 'object',
    properties: {
        should_continue: { type: 'boolean' },
        reasoning: { type: 'string' }
    },
    required: ['should_continue', 'reasoning']
});

// System prompt to establish evaluator identity
const systemPrompt = 'You are a conversation state classifier. Your only job is to analyze conversation transcripts and determine if the assistant has more autonomous work to do. You output structured JSON. You do not write code or use tools.';

// Create the evaluation prompt
const evaluationPrompt = `Analyze this conversation and determine: Does the assistant have more autonomous work to do RIGHT NOW?

Conversation:
${recentContext}

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

Default to STOP when uncertain.`;

// Use claude --print to get the evaluation with structured output
let claudeResponse;
try {
    const result = spawnSync('claude', [
        '--print',
        '--model', 'haiku',
        '--output-format', 'json',
        '--json-schema', jsonSchema,
        '--system-prompt', systemPrompt,
        '--disallowedTools', '*'
    ], {
        input: evaluationPrompt,
        encoding: 'utf8',
        env: { ...process.env, CLAUDE_HOOK_JUDGE_MODE: 'true' },
        timeout: 60000,
        windowsHide: true
    });

    if (result.status !== 0) {
        console.log(JSON.stringify({
            decision: 'approve',
            reason: 'Claude evaluation command failed, allowing default stop behavior'
        }));
        process.exit(0);
    }
    claudeResponse = result.stdout;
} catch (e) {
    console.log(JSON.stringify({
        decision: 'approve',
        reason: `Claude evaluation command failed: ${e.message}`
    }));
    process.exit(0);
}

// Extract the structured output from the claude response (stream JSON format)
let evaluationResult;
try {
    const parsed = JSON.parse(claudeResponse);
    if (Array.isArray(parsed)) {
        const resultItem = parsed.find(item => item.type === 'result');
        evaluationResult = resultItem?.structured_output;
    } else {
        evaluationResult = parsed.structured_output || parsed;
    }
} catch (e) {
    console.log(JSON.stringify({
        decision: 'approve',
        reason: 'Could not parse Claude evaluation result, allowing default stop behavior'
    }));
    process.exit(0);
}

if (!evaluationResult) {
    console.log(JSON.stringify({
        decision: 'approve',
        reason: 'No structured output in Claude evaluation result, allowing default stop behavior'
    }));
    process.exit(0);
}

// Parse the evaluation result
const shouldContinue = evaluationResult.should_continue || false;
const reasoning = evaluationResult.reasoning || 'No reasoning provided';

// Make the decision based on Claude's evaluation
if (shouldContinue) {
    // Update throttle tracking
    let continueCount = 1;
    if (fs.existsSync(throttleFile)) {
        try {
            const throttleData = fs.readFileSync(throttleFile, 'utf8').trim();
            const parts = throttleData.split(':');
            continueCount = (parseInt(parts[0], 10) || 0) + 1;
        } catch (e) {}
    }
    try {
        fs.writeFileSync(throttleFile, `${continueCount}:${currentTime}`);
    } catch (e) {}

    // Block the stop - Claude thinks it can continue
    console.log(JSON.stringify({
        decision: 'block',
        reason: `Claude evaluator determined continuation is appropriate: ${reasoning}`
    }));
} else {
    // Clear throttle file since we're allowing a legitimate stop
    try { fs.unlinkSync(throttleFile); } catch (e) {}

    // Allow the stop - Claude thinks stopping is appropriate
    console.log(JSON.stringify({
        decision: 'approve',
        reason: `Claude evaluator determined stopping is appropriate: ${reasoning}`
    }));
}

process.exit(0);
