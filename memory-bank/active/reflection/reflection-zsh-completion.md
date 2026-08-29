---
task_id: zsh-completion
date: 2026-08-28
complexity_level: 2
---

# Reflection: zsh-completion

## Summary

Shipped native zsh tab completion for `git sync` and `git identity`, installed through `make completions` via `scripts/install-completions.bash`. QA passed; `git wt` stayed out of scope.

## Requirements vs Outcome

Delivered as briefed: same coverage as the bash completers, install/uninstall on the existing completions path, no bash rewrite, no `git wt` completion. Added the filename rename and the documented RC-file split because preflight required them; both were implied by existing rules, not new product scope.

## Plan Accuracy

The locked approach (source-from-zshrc, one installer, `_git_<name>` plus `_git-<name>` plus `compdef`) survived build. The plan was wrong twice before it was right: it kept a misnamed `.sh` installer, and it hid `zsh` by dropping a `PATH` directory. Preflight caught both. `GIT_ALIASES_ZSH` and moving `git mv` into the stub-interface step were the fixes that made the red run mean something.

## Build & QA Observations

Build followed TDD without a plan deficiency. QA was clean: `make test`, `make shellcheck`, and an installed-fence smoke test that actually loaded `compdef` and the `_git-*` wrappers. End-to-end `git sync <TAB>` through zsh’s `_git` remains an operator smoke, as planned.

## Insights

### Technical
- `zsh` shares `/bin` (macOS) and `/usr/bin` (Ubuntu CI) with the installer’s utilities. A “PATH without zsh” test either crashes the installer or false-passes. An overridable `GIT_ALIASES_ZSH` (empty means no zsh) is the mechanism that can assert exit 0 and bash artifacts.
- zsh’s `_git` calls `_git-sync`; git’s `git-completion.zsh` wrapper looks up `_git_sync` under `emulate ksh`. Defining both names is cheap; driving `_git` in unit tests is not.

### Process
- When this repo modifies a Bash installer, rename it to `.bash` in the same unit. Leaving the misname “for later” fails preflight.
- Put the `git mv` in the stub-interface step so the red run fails on behavior, not a missing file.

### Million-Dollar Question

If zsh completions had been assumed from the start, this is the shape: one `.bash` installer, dual companion files, `~/.bash_completion` plus a `~/.zshrc` fence, RC invariant written that way. A shared `--complete` protocol on the subcommands would kill lockstep drift, but it would be a new public interface on `git-sync` / `git-identity`. Not justified for this enhancement.
