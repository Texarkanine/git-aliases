# Active Context

## Current Task: zsh-completion
**Phase:** PLAN - COMPLETE

## What Was Done
- Replanned after preflight `FAIL (fixable)`.
- Native zsh completers for `git-sync` and `git-identity`; one installer owns both dialects; source from a fenced `~/.zshrc` when `zsh` is on PATH.
- Unit 3 now `git mv`s `scripts/install-completions.sh` to `scripts/install-completions.bash` and updates Makefile callers.
- Unit 5 records the RC-file invariant: default `make` may write `~/.bash_completion` and `~/.zshrc`; it does not edit `~/.bashrc`; `make shell` remains the `wt()` fences.

## Next Step
- Re-run preflight on the revised plan.
