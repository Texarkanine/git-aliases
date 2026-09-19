---
task_id: git-sync-worktrees
date: 2026-09-19
complexity_level: 2
---

# Reflection: git-sync-worktrees

## Summary

`git sync` no longer checks out the source branch. It fetches `SOURCE@{upstream}` when one exists and rebases or merges onto that ref. Worktree and primary checkout share one path. Succeeded: QA PASS, nine new behavioral tests green.

## Requirements vs Outcome

All four brief requirements landed. No flags, no second-worktree helper, no `fetch src:src`. Preflight advisory 1 (fetch the upstream's remote) was applied; advisory 2 (onto-ref in the confirm prompt) was skipped for KISS. Unpushed local-only commits on a source branch held elsewhere remain excluded, as planned.

## Plan Accuracy

Sequence and file list were right. The worktree cases went red on the exact failure the operator described (`main` already used by another worktree). The primary-refresh case passed on the old code — checkout was available there — so it was a characterization test, not a red proof. That was a plan slip, not a build problem.

## Build & QA Observations

Build was one substitution and a new homemade suite. QA found no blocking issues. One advisory: `make shellcheck` still ignores `*.bash`; pre-existing, out of scope.

## Insights

### Technical
- `git fetch origin main:main` fails for the same reason as `git checkout main` when another worktree holds `main`. Updating a local branch without checkout is not a worktree workaround.

### Process
- A first behavioral suite will mix red proofs with characterization. "All new tests must fail" is the wrong bar; name which cases must go red.

### Million-Dollar Question

This is the design you would have written if checkout-free had been the assumption: stash, fetch the source upstream, rebase or merge onto that ref. The old checkout-pull-checkout loop was never needed for the rebase or merge.
