# Progress

Add `git wt cleanup` to find and tear down worktrees that `git wt go` created (current repo, or all repos with `--all`), with `--yes`, `--force`, and `--list`; add `git wt done --yes` so forced cleanup can run without prompts.

**Complexity:** Level 2

## 2026-09-24 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Confirmed intent with operator; verified `git worktree remove` deletes ignored files, so no `--rm`.
* Decisions made
    - Level 2: single-subcommand enhancement.
    - Default scope current repo; `--all` for every repo under `~/worktrees`; `--list` prints paths.

## 2026-09-24 - PLAN - COMPLETE

* Work completed
    - Level 2 plan written to `tasks.md` (5 steps, 20 behaviors).
* Decisions made
    - Extract `wt_remove_worktree` shared by `done` and `cleanup`; `cleanup` runs it per row in a subshell.
    - Without `--force`, dirty rows are skipped (success). With `--force`, one cleanup confirmation replaces per-tree prompts.
    - `--all` discovers repos by scanning `~/worktrees` to worktree roots (slash-branch aware), deduped by main checkout.
    - `wt` wrappers forward `cleanup`; `--list` passes through uncaptured.

## 2026-09-24 - PREFLIGHT - COMPLETE

* Result: `PASS WITH ADVISORY`
* Work completed
    - Validated TDD ordering, conventions, dependency impact, conflicts, and completeness against `git-wt.bash`, both wrappers, and both test suites.
    - Struck the `test_help_flags` `cleanup` assertion (change-detector).
* Advisories
    - Wrapper `|| return` drops the cd path when cleanup partially fails; the discovery `cd` into a missing layout path aborts under `set -e` (also `prunable` entries); the parent cwd can vanish mid-loop; `done --yes` usage/header text; locked worktrees count as failures; scan bounds; compute the layout prefix once.
    - Radical: `go` records repos in a registry file so `cleanup --all` doesn't need to scan the filesystem.
