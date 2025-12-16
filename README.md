# Double Shot Latte

**Stops "Would you like me to continue?" interruptions.**

Claude Code plugin that uses Claude to judge whether Claude should continue working.

## The Problem

Claude Code interrupts multi-step work to ask permission even when next steps are obvious:

- Work is incomplete
- Clear next steps exist
- You requested multi-step implementation
- Claude stated what it will do next

This breaks flow.

## The Solution

When Claude tries to stop, a separate Claude instance evaluates the context and decides whether continuation makes sense.

**Key principle:** If you can type "continue" and Claude knows what to do, the plugin continues automatically.

## Installation

```bash
/plugin install double-shot-latte@superpowers-marketplace
```

**Prerequisites:** Claude Code and `jq` command-line tool.

## How It Works

1. **Stop Hook Intercepts** - Catches stop attempts
2. **Context Analysis** - Extracts recent conversation
3. **Judge Evaluation** - Separate Claude instance evaluates continuation
4. **Smart Decision** - Blocks inappropriate stops, allows legitimate ones

## When It Continues

- Work is incomplete
- Obvious next steps exist (more files, functions, tests)
- Claude mentioned follow-up work
- Implementation has TODOs or placeholders
- Multi-step process with remaining steps

## When It Stops

- Claude asks for user decisions
- Claude requests clarification on requirements
- Work is complete and documented
- Claude explicitly needs user input

## Use Cases

**Multi-File Projects**
```
"Refactor codebase to TypeScript with strict types and comprehensive tests"
```

**API Development**
```
"Create REST API with authentication, CRUD operations, and test coverage"
```

**Component Libraries**
```
"Build React components: Button, Input, Modal, Table with TypeScript and Storybook"
```

**Development Environment**
```
"Set up complete dev environment: Docker, CI/CD, linting, testing, deployment"
```

## Features

- **Intelligent decisions** using Claude's reasoning
- **Aggressive continuation** - continues unless clear stop signal
- **Smart throttling** - max 3 continuations per 5 minutes
- **Recursion prevention** - judge Claude can't trigger own hooks
- **Graceful fallback** - allows stopping if evaluation fails
- **Zero configuration** - works after installation

## Configuration

### Model Selection

By default, the plugin uses Claude Haiku for fast, cost-effective judgments. You can configure a different model via environment variable:

**Configuration** (`~/.claude/settings.json`):
```json
{
  "env": {
    "DOUBLE_SHOT_LATTE_MODEL": "sonnet"
  }
}
```

**Available models:**
- `haiku` (default) - Fast and cost-effective
- `sonnet` - More capable reasoning
- `opus` - Highest capability

**Note:** The judge model runs on every stop attempt. Using more expensive models will increase costs proportionally.

## Technical Details

- **Default Model:** Claude Haiku (fast, cost-effective)
- **Context:** Last 10 transcript entries
- **Throttling:** 3 continuations per 5-minute window
- **Performance:** Minimal latency on stop decisions only

## Troubleshooting

**Hook not triggering:**
- Check installation: `/plugin list`
- Restart Claude Code
- Verify hook appears in Claude Code hooks UI

**Unexpected behavior:**
- Review hook reasoning in Claude Code logs
- Check throttle files: `/tmp/.claude-continue-throttle-*`
- Verify `jq` is installed

## Contributing

1. Fork repository
2. Create feature branch
3. Test changes
4. Submit pull request

## License

MIT License - see [LICENSE](LICENSE)