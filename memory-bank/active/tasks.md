# Task: subcommand-help

* Task ID: subcommand-help
* Complexity: Level 2
* Type: simple enhancement

`git wt -h` already prints usage. `git wt --help` does not: Git looks up a manual page and never runs `git-wt`. The same gap exists for `git sync` and `git identity`. Nested flags such as `git wt go --help` do reach the script, and today they are parsed as arguments.

`make` (the existing `subcommands` target) will publish that usage as a preformatted manual page so `git <command> --help` prints the same text as `-h`. The scripts will treat `-h` and `--help` as help on every subcommand and on every nested command. The `wt` shell wrappers will print help and stay in the current directory.


## Test Plan (TDD)

### Behaviors to Verify

- `git-wt -h` and `git-wt --help` print the same usage on stdout and exit 0
- `git wt go -h`, `git wt go --help`, and the same two flags for `done` and `cleanup`, print that usage, exit 0, and do this outside a repository
- `git wt go help` inside a repository still creates the branch `help` (stdout is a worktree path, and the usage text is absent)
- bash and zsh `wt go`, `wt done`, and `wt cleanup`, each with `-h` and with `--help`, print help, exit 0, and leave the working directory unchanged
- `git-sync -h` and `git-sync --help`, outside a repository, print the same usage and exit 0
- `git sync -h` outside a repository does the same
- `git-identity -h` and `git-identity --help` print usage and exit 0 outside a repository
- `git identity list`, `use`, and `create`, each with `-h` and with `--help`, print that usage and exit 0 outside a repository
- `git identity create -h` does not create an identity file
- `git identity list` with no help flag, outside a repository, still exits non-zero because it is not in a repository
- After `scripts/install-subcommands.sh` under an isolated `HOME`, with `MANPATH` unset and `PAGER=cat`, `git wt --help`, `git sync --help`, and `git identity --help` each exit 0 and their stdout equals that command's `-h` stdout
- After `--uninstall`, those cat-page files are gone
- A second install still produces that same `--help` stdout

### Test Infrastructure

- Framework: the homemade POSIX runner used by `tests/test-git-wt.sh`, `tests/test-git-sync.sh`, `tests/test-wt-wrappers.sh`, and `tests/test-install-completions.sh` (`fail`, `invoke` or an installer runner, `run_isolated`, `run_one`). shunit2 stays the smoke test only.
- Test location: `tests/`
- Conventions: `#!/bin/sh`, `set -eu`, isolated `HOME`, the command under test first on `PATH`, assertions through `fail` and `case` or string compare. Register each test with `run_one` from `main`. `run_isolated` does not change the working directory, and this checkout is a repository. Any case that must run outside a repository `cd`s into a fresh temp directory first, as `test_not_a_repo` does in `tests/test-git-sync.sh`.
- New test files: `tests/test-git-identity.sh`, `tests/test-install-subcommands.sh`

## Implementation Plan

### 1. git-wt nested help — executable

- Files: `tests/test-git-wt.sh`, `subcommands/git-wt/git-wt.bash`

1. Stub tests: add `test_nested_help` and `test_go_help_is_branch_name` with empty bodies, and `run_one` lines in `main`.
2. Stub interface: no new function. `main` in `git-wt.bash` keeps its signature.
3. Write tests and run red: `test_nested_help` `cd`s to a fresh temp directory, then invokes `git wt go`, `git wt done`, and `git wt cleanup` with `-h` and with `--help`. Each exits 0, stdout equals `git-wt -h`, and stderr is empty. `test_go_help_is_branch_name` uses `make_repo`, invokes `git wt go help`, and requires a worktree path on stdout and no `usage:` line. Run `tests/test-git-wt.sh`. `test_nested_help` fails. `test_go_help_is_branch_name` already passes; it stays so the word `help` remains a branch name.
4. Write code and run green: at the start of `main`, after the no-argument check and before `wt_worktrees_root`, scan every argument. On `-h` or `--help`, call `usage` and return 0. Leave the bare word `help` on the existing command branch. Run `tests/test-git-wt.sh` until it passes.

### 2. wt wrappers — executable

- Files: `tests/test-wt-wrappers.sh`, `shell/wt.bash`, `shell/wt.zsh`

1. Stub tests: add `test_bash_nested_help` and `test_zsh_nested_help` with empty bodies, and `run_one` lines next to the existing help tests.
2. Stub interface: add `wt_help_requested` to both wrappers, with the file's existing comment style, and an empty body.
3. Write tests and run red: for each shell, for `go`, `done`, and `cleanup`, and for `-h` and `--help`, source the wrapper, `cd` to `START_DIR`, run `wt <command> <flag>`, and require exit 0, help text that mentions `go`, and `pwd` still `START_DIR`. Run `tests/test-wt-wrappers.sh` and confirm the new tests fail.
4. Write code and run green: `wt_help_requested` returns 0 when any argument is `-h` or `--help`. In the `go`, `done`, and `cleanup` branches, call it on the remaining arguments first; when it matches, run `wt --help` and return. Run `tests/test-wt-wrappers.sh` until it passes.

### 3. git-sync help flags — executable

- Files: `tests/test-git-sync.sh`, `subcommands/git-sync/git-sync.bash`

1. Stub tests: add `test_help_flags` with an empty body and a `run_one` line in `main`.
2. Stub interface: no new function. `show_usage` stays the help text.
3. Write tests and run red: `cd` to a fresh temp directory first. From this checkout, `git-sync -h` already exits 0. Outside a repository, `git-sync -h`, `git-sync --help`, and `git sync -h` each exit 0 with identical stdout containing `Usage: git sync`. Run `tests/test-git-sync.sh` and confirm `test_help_flags` fails.
4. Write code and run green: before the repository check, scan every argument and on `-h` or `--help` call `show_usage` and exit 0. Remove the `--help` branch that exits 1. Run `tests/test-git-sync.sh` until it passes.

### 4. git-identity help flags — executable

- Files: `tests/test-git-identity.sh`, `Makefile`, `subcommands/git-identity/git-identity.bash`

1. Stub tests: create `tests/test-git-identity.sh` on the `test-git-sync.sh` isolation pattern (`OPERATOR_HOME`, `fail`, `invoke`, `run_isolated`). Copy `git-identity.bash` into `TEST_BIN/git-identity` and `chmod +x` that copy. The tracked file is mode 644; leave it 644. A symlink would exit 126. Empty bodies for `test_help_flags`, `test_nested_help_does_not_create`, and `test_list_outside_repo_fails`. Register them from `main`. Add the file to the `test` target's `chmod` line and run list in `Makefile`.
2. Stub interface: no new function.
3. Write tests and run red: `cd` to a fresh temp directory before each outside-repository command. Once the copy is executable, top-level `-h` already prints usage. `git-identity --help` still exits 1 with no usage, and `list`, `use`, and `create` with `-h` or `--help` do not print usage. Require all of those to exit 0 with stdout equal to top-level `-h`. `create -h` leaves `${HOME}/.git-identities` absent. `test_list_outside_repo_fails` (`git identity list` exits non-zero outside a repository) already passes once it has `cd`ed out; keep it as a regression lock. Run the new file and confirm the help comparisons fail.
4. Write code and run green: replace the `$1` checks for `-h` and `--help` with one scan of every argument, before the repository check. On a match, `show_usage` and exit 0. Keep the no-argument usage and the repository check for real commands. Run `tests/test-git-identity.sh` until it passes.

### 5. Help pages installed by make — executable

- Files: `tests/test-install-subcommands.sh`, `Makefile`, `scripts/install-subcommands.sh`

1. Stub tests: create `tests/test-install-subcommands.sh` on the `test-install-completions.sh` pattern (isolated `HOME`, run `scripts/install-subcommands.sh`). Empty bodies for `test_help_pages_match_dash_h` and `test_uninstall_removes_help_pages`. Add the file to the `Makefile` `test` target.
2. Stub interface: no new function. The existing install and uninstall loops keep their structure.
3. Write tests and run red: under the isolated home, run the installer, put `${HOME}/.local/bin` first on `PATH`, unset `MANPATH`, and set `PAGER`, `MANPAGER`, and `GIT_PAGER` to `cat`. For `wt`, `sync`, and `identity`, `git <name> --help` exits 0 and stdout equals `"${HOME}/.local/bin/git-<name>" -h`. The cat pages exist at both `${HOME}/.local/man/cat1/git-<name>.1` and `${HOME}/.local/share/man/cat1/git-<name>.1`. Run the installer again and require the same stdout. `--uninstall` removes those six files. Run the new file and confirm it fails.
4. Write code and run green: the install loop is `find | while`, so its body runs in a subshell. Replace it with a `while` loop in the current shell, fed by process substitution (`done < <(find ...)`). This script is bash. After each executable is copied, run `"$target" -h` with stdin from `/dev/null` and the working directory an empty temp directory, and write that one stdout to both cat-page paths (create the directories). Do the same current-shell loop for uninstall, and `rm -f` those two files for each command. A help handler that still needs a repository, or still waits on a prompt, then fails `make` in the parent shell. Run `tests/test-install-subcommands.sh` until it passes, then `make test`.

### 6. Docs — prose/policy

- Files: `subcommands/git-wt/README.md`, `subcommands/git-identity/README.md`, `memory-bank/techContext.md`, `memory-bank/systemPatterns.md`
- No tests: prose/policy artifact

1. In the git-wt README command section, say that `git wt help`, `git wt -h`, and `git wt --help` show the same summary, and that `-h` or `--help` after `go`, `done`, or `cleanup` shows it too.
2. In the git-identity README usage section, say that `-h` or `--help`, including after `list`, `use`, or `create`, shows the usage summary.
3. In `memory-bank/techContext.md` and `memory-bank/systemPatterns.md`, add that `make` / `make subcommands` also writes those cat pages under `~/.local/man/cat1` and `~/.local/share/man/cat1`, and that `make clean` removes them. Leave the git-sync README as it is: its `-h, --help` line already matches the behavior.

## Technology Validation

No new dependency. `make` already installs executables into `~/.local/bin`, which is required to be on `PATH`.

Goal: `git wt --help`, `git sync --help`, and `git identity --help` print the same help as `-h`.

Evidence, on this machine (git 2.34.1, man 2.10.2, `MANPATH` unset): Git turns `git <command> --help` into a manual lookup and does not run the executable. A roff page in `man1` rendered with a `GIT-WTSPIKE(1)` header. A preformatted page in `cat1` was printed unchanged, exit 0, for both `~/.local/man/cat1` and `~/.local/share/man/cat1`, via `git help wtspike` and `git wtspike --help`, once `git-wtspike` was on `PATH`. `git wt go --help` reached the script (`wt: go: invalid branch name: --help`).

macOS manual lookup uses the same idea: an empty `MANPATH` entry, which Git appends, restores the default search. Apple's `man.sh` (man-46) adds both `<bindir>/../share/man` and `<bindir>/../man` when a `PATH` entry ends in `/bin`, and displays an uncompressed cat page through `zcat -f`. The installer writes both copies.

Other approaches that were checked: handling `--help` only inside the script (Git never gets there for the top-level flag); a `git` wrapper ahead of the real `git` on `PATH` (it would wrap every Git command); exporting `MANPATH` from a shell rc file (misses any Git that did not source that file); installing into `/usr/local/share/man` (needs privileges `make` does not have).

## Dependencies

- git
- bash
- man (already what `git --help` runs)
- The existing `make subcommands` installer

## Challenges & Mitigations

- A `MANPATH` value with no empty entry makes `man` skip the default search, so our pages are missed. Git's own pages have that same limit. `make` will not export `MANPATH`.
- macOS was not executed here. Both cat-page directories are installed so either the `~/.local/man` or the `~/.local/share/man` search hits the same bytes. Apple's `man` displays `catN` as preformatted text.
- `git wt --help go` is Git's lookup for `wt`. The page is the top-level usage, which already documents `go`.
- On a terminal, `man` may page. The bytes are the `-h` text. Tests set `PAGER=cat`.
- The word `help` remains a legal branch name for `git wt go`.
- `git-identity.bash` is mode 644. Tests copy it and `chmod +x` the copy. The installer already marks the installed file executable.
- The install `find | while` loop runs in a subshell, so a failing `-h` would not fail `make`. The loop moves into the current shell before it runs any subcommand.

## Pre-Mortem

- The pages are invisible to `git --help` because they were installed in a directory `man` does not search: the Linux spike covered both directories through Git's own `MANPATH` rewrite, and the installer test asserts byte equality for all three commands. Already covered by Technology Validation.
- Install-time `command -h` runs real Git work and fails, so the page is empty or `make` aborts: help handling lands before any repository check, and those tests are steps 1, 3, and 4, before the installer step.
- `wt go -h` changes directory because help is printed on stdout: step 2 tests that `pwd` stays put.
- A Mac shows a roff header or "No manual entry" for a cat page: both directories and Apple's preformatted `catN` rule are the response. A later roff page would change the bytes, so it is a follow-up rather than part of this plan.

## Status

- [x] Initialization complete
- [x] Test planning complete (TDD)
- [x] Implementation plan complete
- [x] Technology validation complete
- [x] Pre-Mortem complete
- [x] Preflight
- [ ] Build
- [ ] QA
