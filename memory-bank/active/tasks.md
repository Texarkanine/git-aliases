# Current Task: zsh-completion

**Complexity:** Level 1

* Task ID: zsh-completion
* Type: bug fix

## What broke

The installed `~/.zshrc` fence always ran `autoload -Uz compinit compdef` and `compinit -C`. A second `compinit -C` reloads `~/.zcompdump` and drops `compdef` registrations that ran after the user's first `compinit` (oh-my-zsh, prezto).

## Why

`_git_sync_register` and `_git_identity_register` already skip `compinit` when `compdef` exists. The fence did not.

## What changed

- `scripts/install-completions.bash` writes the same `compdef` guard around `compinit -C` that the completers use.
- `tests/test-install-completions.sh`: `test_install_copies_zsh_and_writes_fence` requires the guard; new `test_install_fence_preserves_prior_compdefs` sources the installed fence after a dummy `compdef` and asserts `_comps` still has it.

## Files affected

- `scripts/install-completions.bash`
- `tests/test-install-completions.sh`

## Status

- [x] Build
- [x] QA — PASS

## QA Findings

- PASS — The installed zsh fence guards `compinit -C` with the existing `compdef` function check, so it bootstraps a vanilla shell once without reloading a user's completion dump after prior registrations.
- PASS — `test_install_fence_preserves_prior_compdefs` exercises the reported regression by registering a dummy completion before sourcing the fence and confirms that registration remains.
- PASS — The full test suite and ShellCheck pass; no implementation, documentation, or integrity issues require rework.
