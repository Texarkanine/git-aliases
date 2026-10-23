# Active Context

## Current Task: gh account pin
**Phase:** BUILD - IN PROGRESS

## What Was Done

- `git identity use` writes `github.account` and `github.host` from `@gh-account` and `@gh-host`, and unsets each key when that identity omits the directive.
- A bare or empty pin directive exits before any config write. Commented template lines are skipped.
- `tests/test-git-identity.sh` passes, including the worktree read and create-then-use.

## Next Step

- Build the `gh` shim (`tests/test-gh-shim.sh`, `shims/gh.sh`).
