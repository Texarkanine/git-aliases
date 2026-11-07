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

## 2026-11-07 - QA - COMPLETE (PASS)

* Work completed
    - Re-reviewed the diff after the `__git_complete` fix. `make test` and `make shellcheck` passed
    - Simulated `git wt go` through Homebrew git-completion: correct candidates, none for `zz`
* Decisions made
    - PASS. The prior blocker is resolved
* Insights
    - Under git's own `git` binding (`-o default -o nospace`), `git wt go` gets no trailing space and falls back to filenames when nothing matches. That binding belongs to git-completion and affects `git sync` too. Advisory only

## 2026-11-07 - REFLECT - COMPLETE

* Work completed
    - Wrote `memory-bank/active/reflection/reflection-wt-go-branch-completions.md`
    - Noted in `systemPatterns.md` that a shell function is bound with `complete -F`, not `__git_complete`
* Decisions made
    - Left `productContext.md` and `techContext.md` unchanged
* Insights
    - A test that requires a helper to be called can lock in the harmful call. Assert `complete -p` instead

## 2026-11-07 - REWORK - INITIATED

* Work completed
    - Recorded the operator's rework request from the PR #20 review
* Decisions made
    - Rework, not archive
    - Fix literal branch names, fixed `refs/heads/` names, and filename fallback for `git wt go`
    - Fix the same filename fallback for `git sync`
    - Leave `git sync`'s `compgen -W` and `%(refname:short)` uses, and the missing trailing space on a matched `git wt go` name, out of this request
* Insights
    - `__gitcomp_nl` adds a trailing space and leaves `-o default` set. `compopt +o default` is the per-attempt override git itself uses
