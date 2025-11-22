# Release Engineering

Documentation for maintaining and releasing Double Shot Latte plugin.

## Version Management

This plugin follows semantic versioning (semver):
- **MAJOR.MINOR.PATCH** (e.g., 1.2.3)
- **MAJOR**: Breaking changes to plugin API or behavior
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

## Release Process

### 1. Pre-Release Checklist

- [ ] Test plugin functionality locally
- [ ] Verify hook script works with current Claude Code version
- [ ] Check all JSON files are valid
- [ ] Ensure README is up to date
- [ ] Run local installation test

### 2. Version Bump

Update version in these files:
1. `.claude-plugin/plugin.json` - `"version"` field
2. `../superpowers-marketplace/.claude-plugin/marketplace.json` - plugin entry version
3. `CHANGELOG.md` - add new version section

### 3. Changelog Update

Add entry to `CHANGELOG.md`:
```markdown
## [1.X.X] - YYYY-MM-DD
### Added
- New features

### Changed
- Modified behavior

### Fixed
- Bug fixes
```

### 4. Commit and Tag

```bash
# Commit version changes
git add .
git commit -m "chore: Bump version to X.X.X"

# Create annotated tag
git tag -a vX.X.X -m "Release vX.X.X"

# Push commits and tags
git push origin main
git push origin vX.X.X
```

### 5. Update Marketplace

```bash
# Commit marketplace changes
cd ../superpowers-marketplace
git add .
git commit -m "chore: Update double-shot-latte to vX.X.X"
git push
```

## Testing

### Local Testing
```bash
# Test plugin installation
/plugin marketplace add /path/to/double-shot-latte
/plugin install double-shot-latte@double-shot-latte-dev

# Test hook functionality
# Try multi-step task and verify continuation behavior
```

### Hook Script Testing
```bash
# Test hook script directly
echo '{"session_id":"test","transcript_path":"/dev/null","stop_hook_active":false}' | \
  ./scripts/claude-judge-continuation.sh

# Test recursion prevention
echo '{"session_id":"test"}' | \
  CLAUDE_HOOK_JUDGE_MODE=true ./scripts/claude-judge-continuation.sh
```

## File Checklist

Before release, verify these files are correct:

### Core Plugin Files
- [ ] `.claude-plugin/plugin.json` - version, description, paths
- [ ] `hooks/hooks.json` - hook configuration
- [ ] `scripts/claude-judge-continuation.sh` - executable, correct logic
- [ ] `README.md` - installation instructions, current features
- [ ] `LICENSE` - correct license text
- [ ] `CHANGELOG.md` - updated with new version

### External Files
- [ ] `../superpowers-marketplace/.claude-plugin/marketplace.json` - version matches

## Emergency Fixes

For critical bugs requiring immediate release:

1. Fix the bug
2. Increment PATCH version (e.g., 1.0.1 → 1.0.2)
3. Update CHANGELOG with "### Fixed" section
4. Follow normal release process
5. Consider hotfix branch for complex fixes

## Rollback Procedure

If a release has issues:

1. **Marketplace rollback**: Revert marketplace version to previous working version
2. **Git revert**: `git revert vX.X.X` if needed
3. **New patch**: Fix issue and release new patch version
4. **Communication**: Update README with known issues if applicable

## Dependencies

- `jq` - Required for hook script JSON processing
- Claude Code - Plugin compatibility
- Bash - Hook script environment

