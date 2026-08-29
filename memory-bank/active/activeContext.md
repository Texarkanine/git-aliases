# Active Context

## Current Task: git-wt
**Phase:** BUILD - COMPLETE

## What Was Done
- Unit 1: `git-wt.bash` ports local wt-* with HTTPS last-two-segments parse; `tests/test-git-wt.sh` green. `git wt --help` is intercepted by git; `--help` is covered via `git-wt --help`. Idempotent `go` matches `.git` at the layout path so macOS `/var` vs `/private/var` does not false-collide.
- Unit 2: `shell/wt.bash` and `shell/wt.zsh` sourceable `wt()`; wrapper tests use mock git, Homebrew bash, `zsh -f`.
- Unit 3: `install-shell-integration.bash` fence-installs snippets; `make shell` is not in `all`; `make clean` uninstalls; installer tests use fake `HOME` and `make -n`.
- Unit 4: `subcommands/git-wt/README.md` and root README document `make shell` as optional.
- Persistent memory-bank: `make shell` is not in `all`; shell snippet dir is an opt-in install path.
- `make test` green (trim, git-wt, wrappers, installer). shellcheck not installed on this machine.

## Files created or modified
- Created: `subcommands/git-wt/git-wt.bash`, `subcommands/git-wt/README.md`, `shell/wt.bash`, `shell/wt.zsh`, `scripts/install-shell-integration.bash`, `tests/test-git-wt.sh`, `tests/test-wt-wrappers.sh`, `tests/test-install-shell-integration.sh`
- Modified: `Makefile`, `README.md`, `memory-bank/systemPatterns.md`, `memory-bank/techContext.md`, `memory-bank/productContext.md`

## Deviations from Plan
- `git wt --help` cannot be handled when dispatched through `git` (git intercepts `--help` before the subcommand). Tests cover it via `git-wt --help`. `-h` and `help` still go through `git wt`.
- Idempotent `go` detects an existing worktree via `${path}/.git` rather than porcelain path equality, so a logical `$HOME` under `/var/folders` still matches Git's `/private/var/folders` checkout.

## Next Step
- QA review (spawned automatically after Build PASS).
