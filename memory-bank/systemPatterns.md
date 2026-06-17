# System Patterns

## How This System Works

The repo is a collection of independently-installed Git extensions. There is no build step that produces a binary; the Makefile's job is to copy/symlink source files into `~/.local/bin` and `~/.local/share/git-aliases/completions/` so Git can discover them.

A Git subcommand is any executable on `PATH` named `git-<name>`; running `git <name>` dispatches to it. That's the entire extension mechanism. Each subcommand under `subcommands/<name>/` is a self-contained Bash script.

Bash completion scripts are sourced by `~/.bash_completion` (written by `install-completions.sh`); they must not produce output and must not modify global state when sourced.

**Coupling to be aware of:** `git-sync` depends on the stash stack. If it detects changes and decides to stash, it must not pop an unrelated pre-existing stash entry on restore. Any logic that consults `git stash list` or `git stash pop` must guard against this.

## Subcommand ↔ Completion Script Pairing

Each subcommand in `subcommands/<name>/git-<name>.bash` has an optional companion `git-<name>-completion.bash`. The install scripts handle both together. Adding a new subcommand does not automatically gain completion — a companion script must be created separately.

## Bash vs. POSIX Split

- `.bash` files (subcommand scripts): full Bash, `#!/usr/bin/env bash`, may use `[[`, `(( ))`, arrays, etc.
- Shell code in `Makefile` and install scripts: POSIX `/bin/sh` only — no bashisms.

See `.cursor/rules/shared/bash-style.mdc` and `.cursor/rules/shared/shell-posix-style.mdc` for the enforced style rules.

## Install Script Idempotency

`install-subcommands.sh`, `install-completions.sh`, and `install-aliases.sh` are designed to be re-run safely. They support an `--uninstall` flag for clean removal.
