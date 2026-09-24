---
task_id: git-wt-cleanup-cursor
date: 2026-09-24
complexity_level: 2
---

# Reflection: git wt cleanup +cursor

## Summary

`git wt cleanup` now accepts a positional `+cursor` token and assesses Cursor worktrees under `~/.cursor/worktrees` along with the `git wt go` set. QA passed. `+claude` was filed as issue #13 and not built.

## Requirements vs Outcome

Issue #11 is implemented as written. `+cursor` unions with the existing set, includes detached HEAD, ignores empty session directories, and rejects an unknown `+source`. The open question about an empty parent was decided in the plan: remove `~/.cursor/worktrees/<name>/` only when a successful removal left it empty. Wrapper help was added from a preflight advisory. The cleanup flowcharts were added the same way, then removed: they restated the Cleanup and Stdout sections and did not make a new fact easier to see. The source-descriptor redesign was left out.

## Plan Accuracy

The sequence held. Preflight's first pass caught two real gaps before any production code: `--all` had to resolve scanned roots to unique mains, and new tests had to be registered with `run_one`. The second preflight passed. The challenges that mattered were the ones named: porcelain membership versus a filesystem walk, and not removing the same repo twice.

## Build & QA Observations

Listing, discovery, and removal each went red for the missing behavior and then green. QA passed with two advisories that do not change behavior: `wt_cursor_worktrees` does not re-check that the directory exists, and the `cmd_cleanup` comment omits `+cursor`. The full suite passed here except zsh completion tests, which need a system zsh; the unpacked binary cannot load its modules.

## Insights

### Technical

- `git worktree list` is the membership list for one repository. A directory scan is only how `--all` discovers repositories when you are not already inside one.

### Process

- Registering a new `test_*` function without a `run_one` line in `main()` makes a green suite that never ran the test.

### Million-Dollar Question

If several sources had been the starting assumption, `go` and `cursor` would be data for one porcelain filter and one root-to-mains scan, and `+claude` would be a third record. That is the right shape once a second source ships. It was not worth building for one added source.
