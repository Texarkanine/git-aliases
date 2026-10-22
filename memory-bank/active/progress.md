# Progress

Make `-h` and `--help` print the same help for `git wt`, `git sync`, and `git identity`, including nested commands, using `make` only if that path is reliable.

**Complexity:** Level 2

## 2026-10-22 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Restated the request and got operator confirmation, including the correction that every subcommand is in scope
    - Classified the task as Level 2
* Decisions made
    - Level 2: help is broken or missing across more than one subcommand, and the work stays inside that behavior
    - The question of whether `make` can make `git <command> --help` reliable is decided in planning
* Insights
    - `git <command> --help` never reaches the subcommand. Git looks up a man page named `git-<command>`
    - `git wt -h` already prints usage because Git does not intercept `-h`
    - `git-sync` and `git-identity` exit 1 on `--help` when the script itself is invoked, and do not print help

## 2026-10-22 - PLAN - COMPLETE

* Work completed
    - Wrote the Level 2 plan for subcommand-help
    - Spiked Git's `--help` path on this machine
* Decisions made
    - `make subcommands` writes the script's `-h` stdout to `~/.local/man/cat1/git-<name>.1` and `~/.local/share/man/cat1/git-<name>.1`
    - Nested `-h` and `--help` are recognized in `git-wt`, `git-sync`, and `git-identity` before any repository work
    - The bash and zsh `wt` wrappers treat those flags as help and do not change directory
* Insights
    - A roff `man1` page gained a manual header. The `cat1` page was printed unchanged by `git <command> --help`
    - `git wt go --help` already reaches the script

## 2026-10-22 - PREFLIGHT - FAIL

* Work completed
    - Ran preflight on the subcommand-help plan
* Decisions made
    - Revise the plan and preflight again. The failure is fixable
* Insights
    - `git-identity.bash` is mode 644, so a test symlink exits 126
    - Outside-repository tests have to `cd` away from this checkout
    - The installer's `find | while` loop is a subshell

## 2026-10-22 - PLAN - COMPLETE

* Work completed
    - Folded the preflight findings into the plan
* Decisions made
    - Identity tests copy the script and `chmod +x` the copy
    - Outside-repository cases `cd` to a fresh directory
    - The install loop runs in the current shell and captures `-h` from an empty directory with stdin from `/dev/null`

## 2026-10-22 - PREFLIGHT - COMPLETE

* Work completed
    - Validated the Level 2 subcommand-help plan against the scripts, tests, installer, and a fresh cat-page lookup
    - Wrote `memory-bank/active/.preflight-status` with first line `FAIL (fixable)`
* Decisions made
    - The plan goes back to planning before build
    - Unit 4's identity test has to execute a copy in `TEST_BIN`, because `git-identity.bash` is mode 644 and a symlink to it exits 126
* Insights
    - On this machine, a plain `cat1` page is what `git <command> --help` prints unchanged; a plain `man1` file gains a trailing blank line
    - `run_isolated` swaps `HOME` and leaves the working directory inside this repository

## 2026-10-22 - PREFLIGHT - COMPLETE

* Work completed
    - Re-validated the revised Level 2 subcommand-help plan against the scripts, the test harness, the installer, and a fresh isolated cat-page lookup
    - Wrote `memory-bank/active/.preflight-status` with first line `PASS WITH ADVISORY`
* Decisions made
    - The plan is acceptable to build as written
    - Advisories stay out of the plan
* Insights
    - With `PATH` starting at an isolated `$HOME/.local/bin` and `MANPATH` unset, `man` searches both `$HOME/.local/man` and `$HOME/.local/share/man`, and `git <command> --help` prints a `cat1` page from either directory, or from both at once, byte-for-byte equal to the page body
    - Outside a repository, nested `git wt` flags still fail in three different ways (`go` as not a repository, `done` and `cleanup` as unknown options), which is the red state unit 1 describes

## 2026-10-22 - BUILD - COMPLETE

* Work completed
    - Nested and top-level `-h` / `--help` for `git wt`, `git sync`, and `git identity`
    - Cat pages installed and removed by the subcommand installer
    - Wrapper help does not change directory
    - README and memory-bank install notes
* Decisions made
    - Usage lines name both `-h` and `--help`
    - Left `scripts/install-subcommands.sh` on its current name
* Insights
    - `git <command> --help` matched `-h` byte for byte in the installer test
    - zsh is not installed here, so the zsh wrapper suite did not run

## 2026-10-22 - QA - COMPLETE

* Work completed
    - Reviewed the subcommand-help build against the Level 2 plan
    - Wrote `memory-bank/active/.qa-validation-status` with first line `PASS`
* Decisions made
    - PASS. The advisories do not require a build rerun
* Insights
    - The new `git-sync` help scan exits before the old `HELP` arm, so that arm cannot run
    - `shell/wt.zsh` matches `shell/wt.bash` except the header comment

## 2026-10-22 - REFLECT - COMPLETE

* Work completed
    - Wrote `memory-bank/active/reflection/reflection-subcommand-help.md`
    - Reconciled persistent memory-bank files and left them as the build updated them
* Decisions made
    - The cat-page install contract already in `systemPatterns.md` is the standing record
* Insights
    - `git <command> --help` never runs the script. A cat page is the text `-h` prints
    - Outside-repository tests have to leave this checkout or they pass for the wrong reason
