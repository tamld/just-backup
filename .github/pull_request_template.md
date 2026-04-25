## Summary
<!-- Brief description of the changes -->

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor / Code quality
- [ ] Tests
- [ ] Documentation
- [ ] CI/CD

## Checklist
- [ ] Tests pass locally (`powershell -ExecutionPolicy Bypass -File test_harness.ps1`)
- [ ] All documentation updated (README, AGENTS.md, inline comments)
- [ ] Portable version synced with modular source (if code changes)
- [ ] No `%LIBS%` references in Portable file
- [ ] Version strings consistent across Dev and Portable
- [ ] No `::` comments inside `if`/`for` blocks (use `REM`)
- [ ] All `set` assignments are quoted (`set "VAR=value"`)
- [ ] All `set /p` have pre-clear within 5 lines above

## Testing
<!-- How was this tested? Which test sections are relevant? -->

## Related Issues
<!-- Link any related issues: Fixes #123, Relates to #456 -->
