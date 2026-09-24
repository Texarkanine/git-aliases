# Progress

Add `git wt cleanup` to find and tear down worktrees that `git wt go` created (current repo, or all repos with `--all`), with `--yes`, `--force`, and `--list`; add `git wt done --yes` so forced cleanup can run without prompts.

**Complexity:** Level 2

## 2026-09-24 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Confirmed intent with operator; verified `git worktree remove` deletes ignored files, so no `--rm`.
* Decisions made
    - Level 2: single-subcommand enhancement.
    - Default scope current repo; `--all` for every repo under `~/worktrees`; `--list` prints paths.
