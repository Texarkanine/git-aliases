# Task: gh shim reentry

* Task ID: gh-shim-reentry
* Complexity: Level 1
* Type: bugfix

## Fix

`exec_real` exported `GIT_ALIASES_GH_SHIM` into the real `gh`. A shell alias runs through `sh`, and the child `gh` on `PATH` is the shim, which exits with `Error: gh shim invoked itself`.

`exec_real` now unsets that variable before `exec`. `main` still exports it before resolving the binary and before the token lookup, so a resolve that returns this shim still stops. The marker check still skips a file that contains `git-aliases-gh-shim`.

## Files

- `shims/gh.sh`
- `tests/test-gh-shim.sh`

## Tests

- `test_reentry_outside_repo`
- `test_reentry_unpinned`
- `test_reentry_pinned`

The stub `gh` records `GIT_ALIASES_GH_SHIM`. For the argument `reenter`, it runs `gh inner`.

## QA

PASS. No build or plan rerun.

`exec_real` unsets `GIT_ALIASES_GH_SHIM` and leaves the export in place through resolve and the token lookup. The three reentry tests match the rework acceptance criteria. The shim suite passed.

Advisory: a passthrough exec clears the guard, so a marker miss on that path can start this shim again. A pinned lookup still runs while the guard is exported. The reentry tests do not assert that export.
