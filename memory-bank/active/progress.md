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

## 2026-09-24 - PREFLIGHT - FAIL (fixable)

* Work completed
    - Preflight reviewed the plan and returned FAIL (fixable)
* Decisions made
    - Re-plan the two blocking findings before build
* Insights
    - `--all` must resolve scanned roots to unique real mains, or a repo with both layouts is removed twice
    - New `test_*` functions run only when `main()` calls `run_one`

## 2026-09-24 - PLAN - COMPLETE

* Work completed
    - Revised the plan for unique mains, `run_one` registration, a once-only `--all +cursor --yes` test, HOME-logical Cursor paths, and `usage()`
* Decisions made
    - Adopted the two FAIL findings and the usage / logical-path advisories
    - Left the source-descriptor redesign as an advisory; it is not in this plan
* Insights
    - None beyond the preflight findings

## 2026-09-24 - PREFLIGHT - COMPLETE

* Work completed
    - Validated the Level 2 plan against `git-wt.bash`, `tests/test-git-wt.sh`, wrappers, and issue #11
    - Wrote `memory-bank/active/.preflight-status` with first line `FAIL (fixable)`
* Decisions made
    - Do not edit the plan in this phase; planner must re-plan the two fixable findings
* Insights
    - `--all` concatenating `wt_all_mains` and cursor-discovered roots without resolving to unique mains would double-remove on a mixed repo
    - New `test_*` functions in `tests/test-git-wt.sh` never run unless `main()` gets `run_one` lines
