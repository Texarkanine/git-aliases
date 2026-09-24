---
task_id: gitwt-root
date: 2026-09-24
complexity_level: 2
---

# Reflection: GITWT_ROOT envvar support

## Summary

`git wt` now takes `GITWT_ROOT` as the worktree root when that variable is an absolute path, and keeps `~/worktrees` when it is unset or empty. QA passed.

## Requirements vs Outcome

The issue asked for a custom root and for every invocation to keep working. `go`, `done`, and `cleanup` (including `--all`) share `wt_worktrees_root`. Cursor worktrees stay under `~/.cursor/worktrees`. Empty is treated as unset, and a relative value is an error, so a bad setting cannot create a cwd-relative tree. Those two rules were not in the issue text; they are what "still work properly" required.

## Plan Accuracy

The plan named the two real call sites and the existing test file. The sequence held. The surprise was outside the plan: this machine has no system zsh, and a unpacked zsh cannot load `zsh/parameter`, so one completion test failed. It does not call `git wt`.

## Build & QA Observations

The new cases went red on the empty helper, then green after `wt_worktrees_root` was filled in. The git-wt suite passed. QA found no blocking issues. It noted that `GITWT_ROOT=/` still prints a doubled slash, which the plan accepted, and that the relative-path error shows the path after the trailing slash is stripped.

## Insights

### Technical
- `run_isolated` has to unset `GITWT_ROOT`. An exported value in the agent shell would move every existing path assertion off `${HOME}/worktrees`.

### Process
- Nothing notable

### Million-Dollar Question

A root function from the start is what shipped. `wt_layout_prefix` and `wt_all_mains` were already the only readers of `${HOME}/worktrees`, so the helper did not need a wider redesign.
