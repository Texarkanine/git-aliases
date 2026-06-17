# Tech Context

Shell-only project: Bash subcommands, POSIX-compatible install scripts, and a GNU Make build façade.

## Environment Setup

- `~/.local/bin` must be on `PATH`.
- `bash-completion` package must be installed for tab-completion to work after `make completions`.
- Run `make` (or individual targets) to install; `make clean` to uninstall.

## Build Tools

- **GNU Make** — orchestrates installation via `Makefile`. Three targets: `aliases`, `subcommands`, `completions`.
- **install scripts** — `scripts/install-*.sh` do the actual file placement; called by `make`.

## Testing Process

No test framework is currently present in the repository. The bash-style guide (`.cursor/rules/shared/bash-style.mdc`) references **bats** (Bash Automated Testing System) as the preferred framework for shell script tests, but it is not yet installed or configured.
