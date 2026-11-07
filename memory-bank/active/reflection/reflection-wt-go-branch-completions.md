---
task_id: wt-go-branch-completions
date: 2026-11-07
complexity_level: 2
---

# Reflection: wt-go-branch-completions

## Summary

Bash and zsh now offer local branch names after `go` for `wt`, `git wt`, and `git-wt`, installed by the existing `make completions` target. The work succeeded after one QA fix.

## Requirements vs Outcome

The brief asked for existing branch names on `wt go` and `git wt go` in both shells, with nothing offered for a name that does not exist, on the current installer. That is what shipped. `git-wt go` is the same function. `done` stayed out of scope. The planned `__git_complete wt` call was removed: with git's bash completion loaded it rebinds `wt` so a prefix that matches nothing offers filenames.

## Plan Accuracy

The file list and the test-first order held. Two surprises were outside the challenge list. `bash` on `PATH` is 3.2, so `mapfile` does not exist and the bash completer fills `COMPREPLY` with a `read` loop. `__git_complete`, copied from `git-sync`, was the wrong binder for the `wt` function. Preflight's remote-only ref advice was used. The suggested hidden `git wt __complete` command was not built.

## Build & QA Observations

The zsh completer followed `git-sync-completion.zsh` and went green on the first real implementation. QA failed once. The suite stubbed `__git_complete` and required that it be called, so it could not see `-o default`. The rerun passed. QA also drove `git wt go` through Homebrew's git completion: `ma` gave `main`, `zz` gave nothing.

## Insights

### Technical

- `__git_complete` is the wrong way to bind a shell function. It sets `-o default` and `-o nospace`. `complete -F` is the binding. `git <name>` still finds `_git_<name>` without the helper.
- `bash` on this machine's `PATH` is 3.2. A new bash completer cannot use `mapfile`.

### Process

- Assert the binding you want (`complete -p`), not that a helper was invoked. A test that requires the helper call will lock the bug in.

### Million-Dollar Question

The candidate list stays in the two shell files. Each shell's completion API is the surface, and one `for-each-ref` does not justify a hidden `git wt` command. The change worth having from the start is the one QA forced: never call `__git_complete` for these bindings. `git-sync` still has that call, and that is a follow-up, not a redesign of `git wt`.
