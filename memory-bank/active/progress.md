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
