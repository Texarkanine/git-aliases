---
task_id: git-wt-cleanup
date: 2026-09-24
complexity_level: 2
---

# Reflection: git wt cleanup

## Summary

Added `git wt cleanup [--all] [--list] [--yes] [--force]`, `git wt done --yes`, and `wt cleanup` wrapper support. Shipped after two QA rework loops, both in the `--all` scan's robustness rather than the core feature.

## Requirements vs Outcome

Every brief requirement is delivered. `--rm` was dropped by agreement: `git worktree remove` already deletes the directory, ignored files included. Additions beyond the literal ask: `done --yes` (needed for a prompt-free `cleanup --yes --force`), wrapper forwarding with cd-on-removal, and continue-on-failure with a non-zero exit. One interpretation to note: with `--force`, the single cleanup confirmation replaces `done`'s per-worktree discard prompt.

## Plan Accuracy

The sequence and file list held. Preflight added correct advisories: the wrapper must cd even when cleanup partly fails, and missing dirs must be skipped. The plan's cost mitigation for the `--all` scan ("stops at worktree roots") assumed every directory under `~/worktrees` is a worktree. Stray directories with symlink loops broke that assumption, and QA caught it.

## Build & QA Observations

Build was smooth and test-first throughout. One bug was caught by reasoning before any test ran: `set -e` is suspended inside `if ( ... )`, so a failing `git worktree remove` in the helper would have reported success. QA found the symlink-loop hang. The regression test for it then leaked processes through its `sleep` watchdog, and QA caught that on the second run. `zsh` is not installed on this machine. A `zsh` extracted from the .deb was enough for the wrapper tests but not for the `compinit`-based completion tests.

## Insights

### Technical

- A bash helper that is meant to fail must `return 1` explicitly on command failure whenever a caller might invoke it as an `if` condition, including inside `if ( ... )` subshells. `set -e` does not apply there.
- A bash recursive walk over `"${dir}"/*/` follows symlinks. Any directory scan needs `! -L` plus a depth cap, or a single stray loop hangs it.
- Timeout guards in POSIX sh tests: a backgrounded `( sleep N; kill PID ) &` holds the caller's stdout pipe and does not reach grandchildren such as process substitutions. `set -m` process groups do not work in non-interactive dash. A python3 `Popen(start_new_session=True)` plus `killpg` is portable and clean.

### Process

- Nothing notable.

### Million-Dollar Question

If "worktrees created by `go`" had been a first-class concept from the start, `go` would record provenance instead of cleanup inferring it from the path layout. For example, `go` would append the main checkout path to a small registry such as `~/.local/state/git-wt/repos`, deduped. `cleanup --all` would then be an exact lookup: no directory scan, no symlink or depth handling, no orphan warnings. It would also survive a repo's remote being renamed. Per-repo discovery would stay the same: porcelain paths matched against the layout. The cost is that worktrees created before the registry existed need a one-time scan fallback, which is why this task kept the scan. Preflight raised the same idea.
