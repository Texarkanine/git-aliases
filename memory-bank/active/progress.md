# Progress

Add a positional `+cursor` token to `git wt cleanup` so it can also assess Cursor worktrees under `~/.cursor/worktrees`, as specified in issue #11. If Claude Code's worktree layout is deterministic, open a follow-up issue for `+claude` and do not implement it here.

**Complexity:** Level 2

## 2026-09-24 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Classified the approved intent as Level 2
* Decisions made
    - Level 2: a self-contained enhancement to one subcommand, not a new subsystem
* Insights
    - Issue #11 is the requirements source; `+claude` is research plus an issue, not implementation

## 2026-09-24 - PLAN - COMPLETE

* Work completed
    - Wrote the Level 2 plan in `memory-bank/active/tasks.md`
    - Confirmed Claude Code's default worktree path is `<repo>/.claude/worktrees/<name>/` on branch `worktree-<name>` ([docs](https://code.claude.com/docs/en/worktrees))
* Decisions made
    - `+cursor` unions with `git wt go` worktrees; it does not replace them
    - Per-repo membership comes from `git worktree list`; the filesystem scan discovers repos only for `--all`
    - Unknown `+source` is an error
    - After a successful removal, remove an empty `~/.cursor/worktrees/<name>/` and leave a non-empty one
    - Open a `+claude` issue and do not implement it; a `WorktreeCreate` hook can place worktrees elsewhere, and `--all` cannot scan one global directory for them
* Insights
    - On this machine Cursor's layout is `~/.cursor/worktrees/<name>/<repo-ish>/.git`
