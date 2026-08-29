# Tech Context

Shell-only project: Bash subcommands (`.bash`), POSIX tests/helpers (`.sh`), and a GNU Make façade. Filename chooses the dialect; the shebang must match. `scripts/install-*.sh` shebang bash, so they are misnamed (should be `.bash`).

## Environment Setup

- `~/.local/bin` must be on `PATH`.
- `bash-completion` package must be installed for tab-completion to work after `make completions`.
- Run `make` (or individual targets) to install; `make clean` to uninstall.

## Build Tools

- **GNU Make** — orchestrates installation via `Makefile`. Targets: `aliases`, `subcommands`, `completions`, `test`, `clean`.
- **install scripts** — `scripts/install-*.sh` do the actual file placement; called by `make`.

## Testing Process

Run `make test` to execute POSIX shell tests under `tests/`. The trim helper in `scripts/lib/trim.sh` is covered by `tests/test-trim.sh`, which guards against BSD/GNU sed whitespace-trim differences in alias installation.
