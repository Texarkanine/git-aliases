# Active Context

## Current Task: wt-go-branch-completions
**Phase:** QA - COMPLETE (FAIL)

## What Was Done
- Bash and zsh completers offer local `refs/heads/` names after the word `go` for `wt`, `git wt`, and `git-wt`
- `make test` and `make shellcheck` passed
- Files created or modified:
  - `/Users/tex/worktrees/Texarkanine/git-aliases/git-aliases-completions-for-wt/subcommands/git-wt/git-wt-completion.zsh`
  - `/Users/tex/worktrees/Texarkanine/git-aliases/git-aliases-completions-for-wt/subcommands/git-wt/git-wt-completion.bash`
  - `/Users/tex/worktrees/Texarkanine/git-aliases/git-aliases-completions-for-wt/tests/test-zsh-completion.sh`
  - `/Users/tex/worktrees/Texarkanine/git-aliases/git-aliases-completions-for-wt/tests/test-bash-completion.sh`
  - `/Users/tex/worktrees/Texarkanine/git-aliases/git-aliases-completions-for-wt/tests/test-install-completions.sh`
  - `/Users/tex/worktrees/Texarkanine/git-aliases/git-aliases-completions-for-wt/Makefile`
  - `/Users/tex/worktrees/Texarkanine/git-aliases/git-aliases-completions-for-wt/README.md`
  - `/Users/tex/worktrees/Texarkanine/git-aliases/git-aliases-completions-for-wt/subcommands/git-wt/README.md`

## Key Decisions
- Candidates are `refs/heads/` short names, only when the previous word is `go`
- Bash fills `COMPREPLY` with a `read` loop. `bash` on `PATH` is 3.2 and has no `mapfile`
- Did not add a hidden `git wt __complete` command

## Deviations from Plan
- Remote-ref test plants `refs/remotes/origin/remote-only` and rejects both `remote-only` and `origin/remote-only` (preflight advisory 1)
- Bash suite includes `test_bash_missing_fails`, matching the zsh suite (preflight advisory 2)
- Bash uses a `read` loop instead of `mapfile`

## Next Step
- QA failed. Rerun `/niko-build`: remove `__git_complete wt _git_wt` from `git-wt-completion.bash`, and change `test_wt_calls_git_complete_when_present` to assert that sourcing does not call it (see QA Results in `tasks.md`)
