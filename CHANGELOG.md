# Changelog

All notable changes to Double Shot Latte will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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