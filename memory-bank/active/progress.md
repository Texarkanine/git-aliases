# Progress

Add bash and zsh completion of existing git branch names for `wt go` and `git wt go`, as companion scripts installed by the existing `make completions` target. A branch name that does not exist yet has nothing to complete.

**Complexity:** Level 2

## 2026-11-07 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Confirmed the feature rides on `make completions` / `scripts/install-completions.bash`
    - Wrote the project brief for `wt go` and `git wt go` branch completion in bash and zsh
* Decisions made
    - Level 2: self-contained enhancement on the existing completion install, not a new subsystem
    - Scope stays on `go`; a new branch name is typed, not completed
* Insights
    - `git-sync` and `git-identity` already ship `*-completion.bash` and `*-completion.zsh`; `git wt` has none yet

## 2026-11-07 - PLAN - COMPLETE

* Work completed
    - Wrote the Level 2 plan for local-branch completion after `go`
    - Mapped behaviors onto `tests/test-zsh-completion.sh`, a new `tests/test-bash-completion.sh`, and the existing install suite
* Decisions made
    - Candidates are `refs/heads/` short names, and only when the previous word is `go`
    - Register both the `git wt` hooks and the `wt` shell function name
    - Do not drive a real Tab through git's completer; test the functions and the dispatcher hooks
* Insights
    - `git wt go` creates a branch when the name is not already local, so remote-tracking names are the wrong list

## 2026-11-07 - PREFLIGHT - COMPLETE

* Work completed
    - Validated the plan against the codebase: TDD order, conventions, dependencies, conflicts, completeness
    - `.preflight-status` first line: `PASS WITH ADVISORY`
* Decisions made
    - Struck the planned `make -n test` assertion for `test-bash-completion.sh` (change-detector on developer tooling); the Makefile wiring stays
* Insights
    - Remote-ref test should plant a remote-only name; `origin/main` cannot catch a prefix-stripping regression because `main` is local
    - Advisory: a hidden `git wt __complete` would put candidate policy in one tested place and make the shell completers thin adapters

## 2026-11-07 - BUILD - COMPLETE

* Work completed
    - Added `git-wt-completion.zsh` and `git-wt-completion.bash`
    - Extended the zsh suite, added `tests/test-bash-completion.sh`, and asserted the installer copies both files
    - Documented `git wt go` and `wt go` branch completion
    - `make test` and `make shellcheck` passed
* Decisions made
    - Bash `COMPREPLY` is filled with a `read` loop because `bash` on `PATH` is 3.2 and has no `mapfile`
    - Kept candidate policy in the two completers. Did not add `git wt __complete`
* Insights
    - A real Tab press through git's completer is still untested, same as `git sync`. The suites call the completer functions and the registration hooks

## 2026-11-07 - QA - COMPLETE (FAIL)

* Work completed
    - Reviewed the diff against the plan and the brief. Re-ran `make test` and `make shellcheck`. Both passed
* Decisions made
    - FAIL: when git completion is loaded, `__git_complete wt _git_wt` re-binds `wt` with `-o default -o nospace`. A non-matching prefix then falls back to filenames, which breaks acceptance criterion 2. Build must rerun: remove that call and invert its test
* Insights
    - `__git_complete` gives a function that already reads `COMP_WORDS` nothing, and it adds `-o default -o nospace`. `git <cmd>` finds `_git_<cmd>` by name without it

## 2026-11-07 - BUILD - COMPLETE

* Work completed
    - Removed `__git_complete wt _git_wt` from `git-wt-completion.bash`
    - Replaced `test_wt_calls_git_complete_when_present` with `test_wt_does_not_call_git_complete`
    - `make test` and `make shellcheck` passed again
* Decisions made
    - `wt` stays on `complete -F _git_wt wt`. Do not hand that name to git's wrapper
* Insights
    - The plain binding is what keeps a non-matching prefix from falling through to filenames
