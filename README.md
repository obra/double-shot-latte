# Claude Auto-Continue

**Stop the "Would you like me to continue?" interruptions.**

A Claude Code plugin that automatically evaluates whether Claude should continue working instead of stopping to ask for permission when there are obvious next steps.

## The Problem

Claude Code frequently interrupts multi-step work to ask "Would you like me to continue?" even when:

- The work is clearly incomplete
- There are obvious next steps
- You just requested a multi-step implementation
- Claude mentioned what it plans to do next

This breaks flow and requires constant manual intervention.

## The Solution

Auto-Continue uses **Claude to judge Claude** - when Claude tries to stop, a separate Claude instance evaluates the conversation context and decides whether continuation makes sense.

**Key principle:** If you could type "continue" and Claude would know what to do next, the plugin automatically continues for you.

## How It Works

1. **Stop Hook Intercepts** - Catches when Claude tries to stop
2. **Context Analysis** - Extracts recent conversation history
3. **Judge Evaluation** - Separate Claude instance (with recursion prevention) evaluates:
   - Is work incomplete with clear next steps?
   - Did Claude explicitly ask for user decisions?
   - Can Claude continue autonomously?
4. **Smart Decision** - Blocks inappropriate stops, allows legitimate ones

## Installation

### Prerequisites
- Claude Code installed and configured
- `jq` command-line tool for JSON processing

### Install Plugin

```bash
# Clone the repository
git clone https://github.com/your-username/claude-auto-continue.git

# Add as plugin marketplace
/plugin marketplace add /path/to/claude-auto-continue

# Install the plugin
/plugin install auto-continue@auto-continue-dev

# Restart Claude Code to activate
```

## Features

### ✅ **Intelligent Decision Making**
Uses Claude's natural language reasoning instead of brittle heuristics.

### ✅ **Aggressive Continuation**
Default stance is to continue unless there's a clear explicit stop signal.

### ✅ **Smart Throttling**
Allows up to 3 continuations in 5 minutes, then forces a stop to prevent infinite loops.

### ✅ **Time-Based Reset**
Throttle counter resets after 5 minutes - acknowledges new multi-step work.

### ✅ **Recursion Prevention**
Judge Claude instance can't trigger its own hooks via `CLAUDE_HOOK_JUDGE_MODE=true`.

### ✅ **Graceful Fallback**
If evaluation fails, allows stopping (fail-safe behavior).

### ✅ **Zero Configuration**
Works automatically after installation - no setup required.

## When It Continues

The plugin **continues automatically** when:

- ✅ Work appears incomplete or partial
- ✅ There are obvious next steps (more files, functions, tests to create)
- ✅ Claude mentioned follow-up work ("Next I'll...", "I should also...")
- ✅ Implementation has TODOs, stubs, or placeholder content
- ✅ Multi-step process with clear remaining steps
- ✅ Claude is in the middle of a logical sequence

## When It Stops

The plugin **allows stopping** only when:

- ❌ Claude directly asks for user decisions ("Which approach would you prefer?")
- ❌ Claude requests specific clarification on ambiguous requirements
- ❌ Work is genuinely complete AND properly documented
- ❌ Claude explicitly states need for user input ("I need you to...")

## Perfect Use Cases

### 🎯 **Multi-File Projects**
```
"Refactor this codebase to use proper TypeScript with strict types,
move all functions into separate modules, and add comprehensive tests."
```
*Normally stops after each file - now continues through all files.*

### 🎯 **API Development**
```
"Create a REST API with authentication, CRUD operations, validation,
error handling, and comprehensive test coverage."
```
*Continues through all endpoints instead of stopping after each one.*

### 🎯 **Component Libraries**
```
"Build a React component library with Button, Input, Modal, and Table
components, including TypeScript definitions and Storybook docs."
```
*Implements all components without interruption.*

### 🎯 **Development Environment Setup**
```
"Set up complete dev environment with Docker, CI/CD, linting,
testing, and deployment configuration."
```
*Configures entire environment without asking permission for each step.*

## Technical Details

- **Evaluation Model:** Claude Haiku (fast, cost-effective)
- **Context Window:** Last 10 transcript entries
- **Throttling:** 3 continuations per 5-minute window
- **Decision Format:** JSON with detailed reasoning
- **Performance Impact:** Minimal latency on stop decisions only

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test with the development marketplace
5. Commit changes (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development

### Testing Locally

```bash
# Test the hook script directly
echo '{"session_id":"test","transcript_path":"/dev/null","stop_hook_active":false}' | \
  ./scripts/claude-judge-continuation.sh

# Test recursion prevention
echo '{"session_id":"test"}' | \
  CLAUDE_HOOK_JUDGE_MODE=true ./scripts/claude-judge-continuation.sh
```

### Plugin Structure

```
claude-auto-continue/
├── .claude-plugin/
│   ├── plugin.json           # Plugin metadata
│   └── marketplace.json      # Development marketplace
├── hooks/
│   └── hooks.json           # Stop hook configuration
├── scripts/
│   └── claude-judge-continuation.sh  # Main hook logic
├── README.md
└── LICENSE
```

## Troubleshooting

### Hook Not Triggering
- Ensure plugin is installed: `/plugin list`
- Restart Claude Code after installation
- Check hook appears in Claude Code hooks UI

### Unexpected Behavior
- Review hook decision reasoning in Claude Code's hook output logs
- Check throttle files in `/tmp/.claude-continue-throttle-*`
- Verify `jq` is installed and accessible

### Performance Issues
- Hook uses Haiku model for fast evaluation
- Only activates on stop events (minimal overhead)
- Consider adjusting throttling limits if needed

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Transform Claude Code from an interactive assistant into an autonomous coding partner.**

Stop the interruptions. Start the flow. 🚀