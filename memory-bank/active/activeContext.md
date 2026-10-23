# Active Context

## Current Task: gh account pin
**Phase:** QA - COMPLETE (PASS)

## What Was Done

- `git identity use` writes local `github.account` and `github.host` from `@gh-account` and `@gh-host`, and unsets each key when the identity omits it. A bare or empty directive exits before any config write. Commented template lines are skipped.
- `shims/gh.sh` is the PATH shim. A local pin looks up `gh auth token --user`, exports that token as both `GH_TOKEN` and `GH_ENTERPRISE_TOKEN`, and execs the real `gh`. No pin, or not a repository, execs the real `gh` with the token environment unchanged. `--hostname` comes only from local `github.host`.
- `scripts/install-subcommands.sh` installs the shim at `~/.local/bin/gh`, parks a foreign file under `~/.local/libexec/git-aliases/gh`, and restores it on uninstall.
- Docs: identity README, `memory-bank/productContext.md`, `memory-bank/systemPatterns.md`.

Files created: `shims/gh.sh`, `tests/test-gh-shim.sh`.

Files modified: `subcommands/git-identity/git-identity.bash`, `subcommands/git-identity/README.md`, `tests/test-git-identity.sh`, `tests/test-install-subcommands.sh`, `scripts/install-subcommands.sh`, `Makefile`, `memory-bank/productContext.md`, `memory-bank/systemPatterns.md`.

Decisions during build: uninstall moves a parked `gh` back only when `~/.local/bin/gh` is already gone, so a foreign file is not overwritten. The token lookup inherits ambient `GH_HOST`, matching the numbered steps.

Deviations: `test_create_then_use_exits_zero` covers the preflight note that a comment in the create template must not fail `use`. The creative note still describes a single `GH_TOKEN`; the code follows the numbered steps and exports both token variables.

Tests: `tests/test-git-identity.sh`, `tests/test-gh-shim.sh`, and `tests/test-install-subcommands.sh` pass. `make test` then stops in `tests/test-wt-wrappers.sh` because `zsh` is not on PATH here. That failure is outside this change. Shellcheck at error severity is clean for the shim, the new suite, and the installer.

## Next Step

- QA review.
