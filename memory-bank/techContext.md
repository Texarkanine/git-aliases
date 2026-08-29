# Tech Context

Shell-only project: Bash subcommands (`.bash`), POSIX tests/helpers (`.sh`), sourced zsh completers (`.zsh`), and a GNU Make façade. Filename chooses the dialect; the shebang must match. `scripts/install-aliases.sh` and `scripts/install-subcommands.sh` shebang bash, so they are misnamed (should be `.bash`). Completions install via `scripts/install-completions.bash`.

## Environment Setup

- `~/.local/bin` must be on `PATH`.
- `bash-completion` package must be installed for bash tab-completion after `make completions`. Zsh completions need `zsh` on PATH (the installer writes `~/.zshrc` only then).
- Run `make` (or individual targets) to install; `make clean` to uninstall.

## Build Tools

- **GNU Make** — orchestrates installation via `Makefile`. Targets: `aliases`, `subcommands`, `completions`, `shell` (opt-in; not a prerequisite of `all`), `test`, `shellcheck`, `clean`.
- **install scripts** — `scripts/install-*.sh`, `scripts/install-completions.bash`, and `scripts/install-shell-integration.bash` do the actual file placement; called by `make`.

## Testing Process

Run `make test` to execute POSIX shell tests under `tests/` (homemade suites plus a shunit2 smoke test). shunit2 is bundled at the repo root (`shunit2`, no extension). `make shellcheck` runs ShellCheck on tracked `*.sh` at error severity via `scripts/run-shellcheck.sh`. Pull requests run both (`.github/workflows/pr.yaml`). The trim helper in `scripts/lib/trim.sh` is covered by `tests/test-trim.sh`, which guards against BSD/GNU sed whitespace-trim differences in alias installation.
