# Active Context

## Current Task: pr-ci-shunit2
**Phase:** PLAN - COMPLETE

## What Was Done
- Re-planned after Preflight FAIL (fixable): Unit 2 now has homemade `tests/test-shellcheck.sh` (current-tree pass + PATH-miss) before `scripts/run-shellcheck.sh` / Makefile recipe. Unit 3 no longer "installs ShellCheck if needed" (`ubuntu-latest` already has it). No `make ci` target.

## Next Step
- Preflight validation
