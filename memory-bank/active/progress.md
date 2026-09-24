# Progress

Honor `GITWT_ROOT` as the root where `git wt` creates worktrees, falling back to `~/worktrees` when it is unset, so every invocation of the tool still works. As described in [issue #15](https://github.com/Texarkanine/git-aliases/issues/15).

**Complexity:** Level 2

## 2026-09-24 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Restated the issue and got operator approval
    - Classified the task as Level 2
    - Wrote the session brief, active context, task stub, and this progress file
* Decisions made
    - Level 2: a small enhancement inside the `git wt` subsystem, with a clear default and no architectural change
* Insights
    - The issue already states the contract: set means custom root, unset means `~/worktrees`, and every invocation must follow that

## 2026-09-24 - PLAN - COMPLETE

* Work completed
    - Located the two `${HOME}/worktrees` uses in `wt_layout_prefix` and `wt_all_mains`
    - Wrote the Level 2 plan in `tasks.md`: one `wt_worktrees_root` helper, five new cases in `tests/test-git-wt.sh`, and README updates
* Decisions made
    - Unset or empty `GITWT_ROOT` keeps `${HOME}/worktrees`
    - A non-absolute value is an error
    - Cursor worktrees stay under `~/.cursor/worktrees`
* Insights
    - Shell wrappers only `cd` to stdout, so the variable belongs in `git-wt.bash`
    - `run_isolated` must unset `GITWT_ROOT` or an exported value would retarget the existing path tests
