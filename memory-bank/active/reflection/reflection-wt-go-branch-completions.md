---
task_id: wt-go-branch-completions
date: 2026-11-07
complexity_level: 2
---

# Reflection: wt-go-branch-completions

## Summary

Bash and zsh offer local branch names after `go`. A rework then stopped bash from rewriting those names, stopped a same-named tag from turning `main` into `heads/main`, and stopped an unmatched `git wt go` or `git sync` prefix from falling through to filenames.

## Requirements vs Outcome

The brief's completion behavior shipped, then the rework covered the three review findings plus the same filename fallback on `git sync`. `git sync` still passes branch names through `compgen -W` and `%(refname:short)`. A matched `git wt go` name still has no trailing space under git's `-o nospace`. Both were left out on purpose. `git wt` words other than `go` can still fall through to filenames, because `compopt` runs only on the `go` path.

## Plan Accuracy

The four steps and the file list held. The Tab tests had to drive a real bash, because `COMPREPLY` cannot see `-o default`. `compopt +o default` alone stopped the file. `zsh` is not usable on this machine, so the zsh tag test was written and the one-line format change was not executed here.

## Build & QA Observations

The literal-name and tag tests went red for the reason the review named: `feature/$USER` became the expanded value, and `main` plus a tag `main` was offered as `heads/main`. QA passed and did not change code. It flagged a stale header comment, since corrected, and the unverified zsh suite.

## Insights

### Technical

- `__git_complete` is the wrong binder for `wt`, and skipping it does not fix `git wt`. Git's own `git` binding still has `-o default`. `compopt +o default` on that attempt is the override. `__gitcomp_nl` only adds a trailing space.
- `compgen -W` evaluates `$`, quotes, and backticks in a branch name. `%(refname:short)` prints `heads/<name>` when a tag collides. `%(refname:strip=2)` does not.

### Process

- A direct call of the completion function cannot prove a readline fallback. The test has to press Tab.
- Asserting that a helper was called locked in `__git_complete` the first time. The rework asserts the transcript instead.

### Million-Dollar Question

One tested listing of `refs/heads/` names, literal and prefix-stripped, with each shell only doing `COMPREPLY` or `compadd` and `compopt`, would have made the tag bug and the `compgen` bug a single fix. Preflight left that as an advisory. This rework did not add that command. The change worth having was the one the review forced: literal names, `strip=2`, and `compopt` on the attempt that has `-o default`.
