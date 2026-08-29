# System Patterns

## How This System Works

The repo is a collection of independently-installed Git extensions. There is no build step that produces a binary; the Makefile's job is to copy source files into `~/.local/bin` (subcommands), `~/.local/share/git-aliases/completions/` (bash and zsh completion), and — only if you run `make shell` — `~/.local/share/git-aliases/shell/` (interactive `wt()` wrappers). `shell` is not a prerequisite of `all`. Default `make` (via `completions`) writes `~/.bash_completion` and, when `zsh` is on PATH, a fenced completions block in `~/.zshrc`; it does not edit `~/.bashrc`. Opt-in `make shell` appends a separate fenced `wt()` block to `~/.bashrc` and `~/.zshrc`.

A Git subcommand is any executable on `PATH` named `git-<name>`; running `git <name>` dispatches to it. That's the entire extension mechanism. Each subcommand under `subcommands/<name>/` is a self-contained Bash script.

Bash completion scripts are sourced by `~/.bash_completion` (written by `install-completions.bash`); zsh completion scripts are sourced from a fenced `~/.zshrc` block when `zsh` is on PATH. They must not produce output and must not modify global state when sourced.

**Coupling to be aware of:** `git-sync` depends on the stash stack. If it detects changes and decides to stash, it must not pop an unrelated pre-existing stash entry on restore. Any logic that consults `git stash list` or `git stash pop` must guard against this.

## Subcommand ↔ Completion Script Pairing

Each subcommand in `subcommands/<name>/git-<name>.bash` has optional companions `git-<name>-completion.bash` and `git-<name>-completion.zsh`. The install scripts handle them together. Adding a new subcommand does not automatically gain completion — companion scripts must be created separately.

## Bash vs. POSIX Split

Dialect follows the filename; the shebang must match. `.bash` means bash (`#!/usr/bin/env bash`). `.sh` means POSIX (`#!/bin/sh`) because `sh` is not a specific shell. Makefile recipes and git aliases have no filename and stay POSIX.

Git subcommands are `.bash`. Tests and `scripts/lib/trim.sh` are `.sh`. `scripts/install-completions.bash` and `scripts/install-shell-integration.bash` are correctly named. `scripts/install-aliases.sh` and `scripts/install-subcommands.sh` currently shebang bash, so they are misnamed (they should be `.bash`), not POSIX.

## Install Script Idempotency

`install-subcommands.sh`, `install-completions.bash`, `install-aliases.sh`, and `install-shell-integration.bash` are designed to be re-run safely. They support an `--uninstall` flag for clean removal. `make clean` runs all four uninstallers.
