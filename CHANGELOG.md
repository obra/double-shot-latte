# Changelog

All notable changes to Double Shot Latte will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.4] - 2025-11-25

### Fixed
- Task completion statements now correctly trigger STOP instead of CONTINUE
- Reframed evaluator from "question detection" to "work state detection"
- Offering optional actions (e.g., "Want me to run X?") now correctly triggers STOP

### Changed
- Evaluator now uses --system-prompt to establish classifier identity (not a coding agent)
- Disabled all tools for evaluator instance with --disallowedTools
- Simplified prompt to use pattern descriptions instead of exact quote matching

### Added
- 5 new test scenarios for task completion edge cases (61-65)

## [1.1.3] - 2025-11-24

### Fixed
- Simplified stop hook logic to prevent rationalization loopholes
- Previous complex rules allowed Haiku to classify decision questions as "clarification" based on context (e.g., "it's brainstorming, not plan presentation")
- New rule is absolute: any question to user = STOP, except "should I continue working?" = CONTINUE

## [1.1.2] - 2025-11-22

### Fixed
- Stop conditions now take precedence over continue conditions when both apply
- Hook correctly stops when presenting plans/designs for user approval
- Fixed issue where hook would push Claude to continue when asking questions like "Does this approach look good?"

### Added
- Comprehensive eval test suite with 60 scenarios (30 STOP, 30 CONTINUE)
- Test runner executing 5 runs per scenario for reliability validation
- Explicit plan presentation detection patterns in evaluation prompt

## [1.1.1] - 2025-11-22

### Fixed
- Removed redundant hooks reference from plugin manifest that caused duplicate hooks file error

## [1.1.0] - 2025-11-22

### Changed
- Improved continuation decision logic with clearer stop conditions
- Reframed evaluation prompt from "CONTINUE unless..." to "STOP only if..." for better clarity
- Simplified incomplete work detection language

### Added
- New stop reason: Detects when a design or plan is being presented to the user for the first time
- Better differentiation between presenting plans vs. implementing them

## [1.0.1] - 2024-11-20

### Fixed
- Fixed plugin manifest validation error requiring hooks paths to start with "./"
- Plugin now installs correctly from superpowers-marketplace

### Changed
- Simplified installation to single command from superpowers-marketplace
- Cleaned up README using Strunk's writing principles for clarity and conciseness

## [1.0.0] - 2024-11-20

### Added
- Initial release of Double Shot Latte plugin
- Claude-judged Stop hook that automatically evaluates continuation decisions
- Aggressive continuation logic with time-based throttling (3 continuations per 5 minutes)
- Recursion prevention via CLAUDE_HOOK_JUDGE_MODE environment variable
- Smart decision making using separate Claude Haiku instance for fast evaluation
- Zero configuration setup - works automatically after installation

### Features
- Automatically continues when work is incomplete with obvious next steps
- Stops appropriately when Claude explicitly asks for user decisions or clarification
- Graceful fallback if evaluation fails
- Comprehensive logging and reasoning for debugging
- Support for complex multi-step workflows (API development, refactoring, component libraries)

### Technical Details
- Uses Claude Haiku model for cost-effective and fast evaluation
- Analyzes last 10 transcript entries for context
- JSON-based hook communication with proper error handling
- Throttle files for loop prevention with automatic cleanup