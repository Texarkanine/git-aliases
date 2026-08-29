# Git Aliases and Subcommands

This repository contains a collection of useful Git aliases and custom Git subcommands to enhance your Git workflow.

## Overview

- **Git Aliases**: Shortcuts for common Git commands that can be added to your global git config
- **Git Subcommands**: Custom scripts that extend Git with new functionality
- **Bash Completion**: Tab completion for custom Git subcommands

## Installation

You can install the aliases and subcommands using the provided Makefile:

```bash
# Install everything (aliases, subcommands, and completions)
make

# Install only Git aliases
make aliases

# Install only Git subcommands
make subcommands

# Install only bash completions
make completions

# Optional: bash/zsh wt() wrappers that auto-cd (not part of default make)
make shell
```

### Requirements

- `git`
- `bash`
- `shellcheck` (for `make test` / `make shellcheck`)
- `~/.local/bin` directory in your PATH (for subcommands)
- [bash-completion](https://github.com/scop/bash-completion) package (for completions)

## Git Aliases

The aliases are organized into several categories:

- **add**: Commands for adding, unstaging, and cleaning
- **diff**: Commands for viewing changes
- **misc**: Miscellaneous Git commands
- **pushpullfetch**: Commands for interacting with remotes
- **rebasemerge**: Commands for rebasing and merging
- **search**: Commands for searching through Git history
- **status**: Commands for status, logs, and branches

For a full list of aliases, see the [aliases README](aliases/README.md).

## Git Subcommands

Custom Git extensions that can be called as `git <subcommand>`:

- **[git-identity](subcommands/git-identity/README.md)**: Manage multiple Git identities with different configuration settings
- **[git-sync](subcommands/git-sync/README.md)**: Synchronize your current branch with another branch using rebase or merge
- **[git-wt](subcommands/git-wt/README.md)**: Create and tear down linked worktrees at `~/worktrees/<owner>/<repo>/<repo>-<branch>`

`make shell` is a separate, opt-in install for bash and zsh `wt()` wrappers that `cd` for you. It is not included in default `make`. See the [git-wt README](subcommands/git-wt/README.md) for the path convention, stdout contract, and how to enable the wrappers. `wt` is a shell function, not a git subcommand.

For more information on each subcommand, check their individual README files in the corresponding directory.

## Bash Completion

Bash completion is included for some Git subcommands.

The installation process:
1. Copies completion scripts to `~/.local/share/git-aliases/completions/`
2. Adds references to these scripts in `~/.bash_completion`

After installation, you may need to source your bash completion file:
```bash
source ~/.bash_completion
```

## Testing

```bash
make test        # POSIX test suites under tests/ (includes a shunit2 smoke test)
make shellcheck  # ShellCheck tracked *.sh at error severity
```

Pull requests against `main` run both. A failing job shows as a red check on the PR.
