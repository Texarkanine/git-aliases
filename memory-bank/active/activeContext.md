# Active Context

## Current Task: GITWT_ROOT envvar support
**Phase:** PLAN - COMPLETE

## What Was Done
- Confirmed intent against [issue #15](https://github.com/Texarkanine/git-aliases/issues/15).
- Classified the task as Level 2.
- Planned one helper, `wt_worktrees_root`, used by `wt_layout_prefix` and `wt_all_mains`. Unset or empty keeps `${HOME}/worktrees`. A non-absolute value is an error. Cursor worktrees stay under `~/.cursor/worktrees`.
- Mapped tests to new cases in `tests/test-git-wt.sh`, plus `run_isolated` clearing `GITWT_ROOT`. Docs: `subcommands/git-wt/README.md` and the root `README.md` bullet.

## Next Step
- Preflight validation
