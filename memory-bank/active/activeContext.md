# Active Context

## Current Task: git-wt-done-current
**Phase:** PREFLIGHT - COMPLETE (PASS WITH ADVISORY)

## What Was Done
- Re-planned after preflight FAIL (fixable): added `test_done_named_foreign_worktree` so named `git wt done <name>` is asserted on a `git worktree add` path, not only `git wt go` trees.
- Nameless `cmd_done` still uses `wt_worktree_containing_cwd`; `wt()` unchanged.
- Preflight re-run: TDD encoding, conventions, dependency impact, conflicts, and completeness all pass. Two advisories recorded in `.preflight-status`: the cwd scan needs longest-match-wins (porcelain lists main first, and a worktree can nest inside main), and `git rev-parse --show-toplevel` plus `--git-dir` vs `--git-common-dir` could replace the porcelain scan entirely.

## Next Step
- Build (advisories are the operator's call; neither blocks)
