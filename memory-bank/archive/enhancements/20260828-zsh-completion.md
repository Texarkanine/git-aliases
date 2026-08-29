---
task_id: zsh-completion
complexity_level: 2
date: 2026-08-28
status: completed
---

# TASK ARCHIVE: zsh-completion

## SUMMARY

Added native zsh tab completion for `git sync` and `git identity`, installed through the existing `make completions` path. `scripts/install-completions.sh` was renamed to `.bash` and now copies `*-completion.zsh` and writes a fenced `~/.zshrc` block when `zsh` is on PATH (`GIT_ALIASES_ZSH` can force a skip). Default `make` may write `~/.bash_completion` and `~/.zshrc`; `make shell` remains the opt-in `wt()` fences. `git wt` stayed out of scope.

PR #9 review found the fence always ran `compinit -C`, which reloads `~/.zcompdump` and drops later `compdef`s (oh-my-zsh / prezto). A Level 1 rework added the same `compdef` guard the completers already used. Shipped on [PR #9](https://github.com/Texarkanine/git-aliases/pull/9).

## REQUIREMENTS

1. Zsh tab-completes `git sync` / `git-sync` and `git identity` / `git-identity` with the same coverage as bash (branches and dash-flags for sync; `list` / `use` / `create` and identity names after `use`).
2. Install and uninstall through `make completions` / `make clean`; idempotent; no RC corruption.
3. Do not rewrite bash completers except as needed to keep install working. Do not add `git wt` completion.
4. Completers must be source-able without output or unexpected global side effects, including not running a second `compinit` when `compdef` already exists.
5. Tests fail if `zsh` is missing rather than skipping.

## IMPLEMENTATION

Native zsh completers live next to the bash scripts as `git-<name>-completion.zsh`. Each file defines `_git_<name>`, a `_git-<name>` wrapper for zsh's `_git`, and `compdef` for the standalone command. `user-commands` is appended, not replaced. Registration is skipped when `GIT_ALIASES_COMPLETION_TEST` is set.

One installer owns both dialects. Empty `GIT_ALIASES_ZSH` skips the zsh copy and fence; uninstall always strips the fence. The fence and each register function run `compinit -C` only when `compdef` is missing.

Key files: `subcommands/git-sync/git-sync-completion.zsh`, `subcommands/git-identity/git-identity-completion.zsh`, `scripts/install-completions.bash`, `tests/test-zsh-completion.sh`, `tests/test-install-completions.sh`, `Makefile`, `README.md`, persistent memory-bank RC-split notes.

## TESTING

Homemade POSIX suites. Zsh cases invoke `_git_sync` / `_git_identity` with stubbed `compadd` (branch, flag, command, identity, `compdef` without prior `compinit`). Installer cases use isolated `HOME`, including empty `GIT_ALIASES_ZSH`. Rework added `test_install_fence_preserves_prior_compdefs` (dummy `compdef` must survive sourcing the installed fence). `make test` and `make shellcheck` passed for both the original build and the rework. `/niko-qa` PASS twice. Original QA also smoke-tested the installed fence loading wrappers and standalone `compdef`s. End-to-end `git sync <TAB>` through zsh's `_git` remains an operator smoke.

## LESSONS LEARNED

- `zsh` shares `/bin` (macOS) and `/usr/bin` (Ubuntu CI) with the installer's utilities. A "PATH without zsh" test either crashes or false-passes. Empty `GIT_ALIASES_ZSH` is the without-zsh hook.
- zsh's `_git` calls `_git-sync`; git's `git-completion.zsh` wrapper looks up `_git_sync` under `emulate ksh`. Define both names; do not drive `_git` in unit tests.
- A second `compinit -C` reloads `~/.zcompdump` and wipes post-dump `compdef`s. Guard (or omit) `compinit` when `compdef` already exists. `grep -q 'compinit -C'` still matches a guarded fence; a behavioral `_comps` check is what locks the bug.
- Nested helpers in a sourced zsh completer leak as global functions; inline them.

## PROCESS IMPROVEMENTS

- When this repo modifies a Bash installer, rename it to `.bash` in the same unit. Leaving the misname "for later" fails preflight.
- Put the `git mv` in the stub-interface step so the red run fails on behavior, not a missing file.
- Preflight FAIL (fixable) twice (misnamed installer; hiding `zsh` via `PATH`) was cheaper than finding either in QA.

## TECHNICAL IMPROVEMENTS

A shared `--complete` protocol on `git-sync` / `git-identity` would kill lockstep drift between bash and zsh completers. It would be a new public interface. Not justified for this enhancement.

## NEXT STEPS

None. Reinstall with `make completions` (or default `make`) and `source ~/.zshrc`. `git wt` completion is still out of scope.
