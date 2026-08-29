---
task_id: git-wt-done-current
date: 2026-08-28
complexity_level: 2
---

# Reflection: git-wt-done-current

## Summary

Nameless `git wt done` now removes the linked worktree that contains cwd (including trees `git wt go` did not create) and still refuses the main checkout. Named `done` and the optional `wt()` wrapper are unchanged.

## Requirements vs Outcome

All six brief requirements shipped. Wrapper rename/`git` shim was asked about, then explicitly cut. No requirements were added in build.

## Plan Accuracy

The TDD sequence held. Preflight correctly demanded a *named* foreign-worktree test; nameless foreign and named foreign are different lookups. The porcelain cwd scan in the plan would have mis-identified a worktree nested inside main; build took preflight advisory 2 (`git rev-parse` git-dir vs common-dir) instead.

## Build & QA Observations

Nameless cases went red on "branch name required", then green. One test bug: `git show-ref` after `done` from inside the removed tree, because cwd no longer exists. QA passed with no rework.

## Insights

### Technical
- `git rev-parse --absolute-git-dir` vs `--git-common-dir` is the test for "linked worktree vs main." Porcelain first-match on path prefixes is wrong when a worktree lives inside the main checkout.
- After `worktree remove` of the tree you are in, cwd is gone; later `git` calls in that test need `git -C` on main.

### Process
- Preflight FAIL (fixable) for an untested stated requirement (named foreign `done`) was cheaper than discovering it in QA.

### Million-Dollar Question

`done` means "this worktree"; a name is the override for tearing down some other tree from elsewhere. That is what shipped. A `git()` shim so `git wt` itself could `cd` was considered and rejected: a subprocess cannot `cd` the parent, and wrapping `git` is worse than an opt-in `wt()`.
