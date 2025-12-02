#!/bin/bash

# Test that the hook script switches to ~/.claude/double-shot-latte before running claude

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/../hooks/claude-judge-continuation.sh"
TEST_DIR="$HOME/.claude/double-shot-latte"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🧪 Testing Working Directory Switch"
echo "===================================="
echo ""

# Create a mock claude command that prints its working directory
TEMP_BIN="/tmp/test-claude-wd-$$"
mkdir -p "$TEMP_BIN"

cat > "$TEMP_BIN/claude" << 'EOF'
#!/bin/bash
# Mock claude that outputs the current working directory
echo "{\"type\": \"result\", \"structured_output\": {\"should_continue\": false, \"reasoning\": \"test\"}}"
# Write the PWD to a test file so we can verify it
echo "$PWD" > /tmp/claude-test-pwd
EOF

chmod +x "$TEMP_BIN/claude"

# Add temp bin to PATH
export PATH="$TEMP_BIN:$PATH"

# Create a minimal transcript
TEMP_TRANSCRIPT="/tmp/test-transcript-$$.json"
cat > "$TEMP_TRANSCRIPT" << 'EOF'
{"role":"user","content":"test"}
{"role":"assistant","content":"Work is complete."}
EOF

# Create mock hook event
hook_event=$(jq -n \
    --arg transcript_path "$TEMP_TRANSCRIPT" \
    '{
        "stop_hook_active": false,
        "transcript_path": $transcript_path,
        "session_id": "test-session"
    }')

# Run the hook script
echo "$hook_event" | "$HOOK_SCRIPT" > /dev/null 2>&1 || true

# Check if the working directory file was created
if [ ! -f /tmp/claude-test-pwd ]; then
    echo -e "${RED}✗ FAIL: claude command was not executed${NC}"
    rm -rf "$TEMP_BIN" "$TEMP_TRANSCRIPT"
    exit 1
fi

# Read the working directory that was used
ACTUAL_PWD=$(cat /tmp/claude-test-pwd)

# Clean up
rm -rf "$TEMP_BIN" "$TEMP_TRANSCRIPT" /tmp/claude-test-pwd

# Verify the working directory
if [ "$ACTUAL_PWD" = "$TEST_DIR" ]; then
    echo -e "${GREEN}✓ PASS: claude ran in $TEST_DIR${NC}"
    exit 0
else
    echo -e "${RED}✗ FAIL: claude ran in $ACTUAL_PWD, expected $TEST_DIR${NC}"
    exit 1
fi
