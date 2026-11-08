---
task_id: wt-go-branch-completions
complexity_level: 2
date: 2026-11-07
status: completed
---

# TASK ARCHIVE: wt-go-branch-completions

## SUMMARY

`wt go` and `git wt go` tab-complete local branch names in bash and zsh. A rework then kept those names literal, kept a branch named `main` as `main` when a tag shares it, and stopped an unmatched `git wt go` or `git sync` prefix from falling through to filenames.

## REQUIREMENTS

- Bash and zsh offer existing local branch names after `go` for `wt go` and `git wt go`. A name that is not a local branch is not offered. `make completions` installs the companion scripts. `done` stays out of scope.
- Bash must not expand or execute characters in a branch name. `compgen -W` did both.
- Both shells must offer the name under `refs/heads/` when a tag has the same name. `%(refname:short)` offered `heads/main`, and `git wt go` would create that as a new branch.
- An unmatched prefix after `git wt go` must not fall back to filenames. Git binds `git` with `-o default`. The same fallback on `git sync` is in scope.
- Left out on purpose: `git sync` still uses `compgen -W` and `%(refname:short)`. A matched `git wt go` name still has no trailing space under git's `-o nospace`.

## IMPLEMENTATION

`_git_wt` reads `for-each-ref` lines and matches them with `case`. It does not call `compgen -W`. Both `git wt` completers use `%(refname:strip=2)`. On the `go` path, `_git_wt` runs `compopt +o default` before it returns. `_git_sync` runs that same command first, including before its early return when `_get_comp_words_by_ref` fails. `wt` and `git-wt` stay on `complete -F`. `__git_complete` is not called. `compopt` is not used to clear `-o nospace`.

Key files: `subcommands/git-wt/git-wt-completion.bash`, `subcommands/git-wt/git-wt-completion.zsh`, `subcommands/git-sync/git-sync-completion.bash`, `tests/test-bash-completion.sh`, `tests/test-zsh-completion.sh`, `memory-bank/systemPatterns.md`.

## TESTING

`tests/test-bash-completion.sh` passed. Literal names, the tag collision, and Tab presses in an interactive bash (a pty, because `COMPREPLY` cannot see `-o default`) went red for the reviewed bugs and then green. `make shellcheck` passed. QA passed. `zsh` is not a usable command on the machine that built this, so `test-zsh-completion.sh` and the zsh half of `make test` did not run. The zsh edit is the same format string the bash tag test watched change from `heads/main` to `main`.

## LESSONS LEARNED

Skipping `__git_complete` does not stop filename fallback on `git <cmd>`. That binding already has `-o default`. `compopt +o default` on the attempt is the override. `__gitcomp_nl` only adds a trailing space. `compgen -W` evaluates `$`, quotes, and backticks in a branch name. `%(refname:short)` prints `heads/<name>` when a tag collides. `%(refname:strip=2)` does not. A test that only reads `COMPREPLY` cannot see the filename fallback. The test has to press Tab. Asserting that a helper was called is what locked `__git_complete` in the first time.

## PROCESS IMPROVEMENTS

Nothing beyond that test lesson. The four-step plan held, and QA did not send the work back.

## TECHNICAL IMPROVEMENTS

One tested listing of `refs/heads/` names, with each shell only filling `COMPREPLY` or `compadd` and calling `compopt`, would make the next collision-class bug a one-line fix. Preflight left that as an advisory. This task did not add that command.

## NEXT STEPS

Run the zsh completion suite on a machine where `zsh` runs. The `git sync` list bugs and the missing trailing space were left out on purpose.
