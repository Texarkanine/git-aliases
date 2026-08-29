# Project Brief

## User Story

As a zsh user, I want tab completion for `git sync` and `git identity` so that I get the same tab-complete UX the bash completions already provide.

## Use-Case(s)

### Tab-complete git sync

In zsh, after the completions are installed, `git sync` and `git-sync` offer the same completions as bash: local branch names, and `-m` / `--merge` / `-h` / `--help` when the user has started a dash.

### Tab-complete git identity

In zsh, `git identity` and `git-identity` offer the same completions as bash: `list` / `use` / `create`, and identity names after `use`.

### Install and uninstall with existing completions targets

`make completions` (including default `make`) installs zsh completions. `make clean` uninstalls them. Install and uninstall are idempotent and do not corrupt shell RC files.

## Requirements

1. Zsh tab completion for `git sync` and `git identity` with the same coverage as the existing bash completions.
2. Install and uninstall through the existing completions path (`make completions` / `make clean`).
3. Use ai-rizz’s recent zsh completion work (`zsh-tabs` / issue 54) as a reference, not a line-for-line copy.
4. Do not regress bash completions.

## Constraints

1. `git wt` is out of scope. It has no bash completion and does not need zsh completion.
2. Do not rewrite the existing bash completions except as needed to keep install working.
3. Filename chooses dialect; the shebang must match (`.bash` → bash, `.sh` → POSIX). Zsh completion scripts are zsh.
4. Completion scripts must be source-able without output or unexpected global side effects.

## Acceptance Criteria

1. After `make completions`, zsh tab-completes `git sync` / `git-sync` and `git identity` / `git-identity` equivalently to bash.
2. `make clean` removes zsh completion install artifacts without corrupting RC files.
3. Existing bash completions still work after install and uninstall.
4. Tests cover zsh completion behavior and install/uninstall; they fail if `zsh` is missing rather than skipping.
