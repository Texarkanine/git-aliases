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
