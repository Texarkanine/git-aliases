# Active Context

## Current Task: subcommand-help
**Phase:** BUILD - COMPLETE

## What Was Done
- `git wt go`, `done`, and `cleanup` treat `-h` and `--help` as help before any repository work. The word `help` is still a branch name.
- `git-sync` and `git-identity` do the same, including nested identity commands. Their usage lines name `-h, --help`.
- The bash and zsh `wt` wrappers print wrapper help for those flags and do not change directory.
- `scripts/install-subcommands.sh` writes that `-h` text to `~/.local/man/cat1` and `~/.local/share/man/cat1`, and uninstall removes the pages. The install loop runs in the current shell.
- Docs: git-wt and git-identity READMEs, `memory-bank/techContext.md`, `memory-bank/systemPatterns.md`.

## Files
- `/home/mobaxterm/git/git-aliases/subcommands/git-wt/git-wt.bash`
- `/home/mobaxterm/git/git-aliases/subcommands/git-sync/git-sync.bash`
- `/home/mobaxterm/git/git-aliases/subcommands/git-identity/git-identity.bash`
- `/home/mobaxterm/git/git-aliases/shell/wt.bash`
- `/home/mobaxterm/git/git-aliases/shell/wt.zsh`
- `/home/mobaxterm/git/git-aliases/scripts/install-subcommands.sh`
- `/home/mobaxterm/git/git-aliases/tests/test-git-wt.sh`
- `/home/mobaxterm/git/git-aliases/tests/test-git-sync.sh`
- `/home/mobaxterm/git/git-aliases/tests/test-git-identity.sh`
- `/home/mobaxterm/git/git-aliases/tests/test-install-subcommands.sh`
- `/home/mobaxterm/git/git-aliases/tests/test-wt-wrappers.sh`
- `/home/mobaxterm/git/git-aliases/Makefile`
- `/home/mobaxterm/git/git-aliases/subcommands/git-wt/README.md`
- `/home/mobaxterm/git/git-aliases/subcommands/git-identity/README.md`
- `/home/mobaxterm/git/git-aliases/memory-bank/techContext.md`
- `/home/mobaxterm/git/git-aliases/memory-bank/systemPatterns.md`

## Deviations
- Usage text for `git sync` and `git identity` now lists `--help` next to `-h`. The sync README already did.
- zsh is not installed on this machine, so `tests/test-wt-wrappers.sh` and `tests/test-zsh-completion.sh` did not run. Bash wrapper help was checked with the suite's mock `git`. `make shellcheck` passed. The other suites passed. Completion install tests fail here because they call `zsh`.

## Next Step
- QA review.
