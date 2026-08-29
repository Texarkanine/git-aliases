# Progress

Make `git wt done` with no branch name infer the linked worktree from cwd, including worktrees `git wt go` did not create. Leave the optional `wt()` wrapper alone.

**Complexity:** Level 2

## 2026-08-28 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Restated intent; operator confirmed nameless `done` plus "any linked worktree," then narrowed wrapper work out of scope
* Decisions made
    - Level 2: self-contained enhancement to `cmd_done`
    - `wt()` stays optional opt-in `cd` sugar; no `__git_wt` rename; no wrapping `git`
* Insights
    - A subprocess cannot `cd` the parent shell; auto-cd still requires a shell function the user types
