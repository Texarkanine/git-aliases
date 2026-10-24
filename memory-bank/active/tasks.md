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
