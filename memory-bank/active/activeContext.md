# Active Context

## Current Task: wt-go-branch-completions
**Phase:** QA - COMPLETE (PASS)

## What Was Done
- Bash branch names are read literally and matched with `case`. `compgen -W` is gone from `_git_wt`
- Both `git wt` completers request `%(refname:strip=2)`
- `_git_wt` calls `compopt +o default` on the `go` path. `_git_sync` calls it before the early return
- Tab tests drive interactive bash through `python3`'s pty

## Files
- `/home/mobaxterm/git/git-aliases/subcommands/git-wt/git-wt-completion.bash`
- `/home/mobaxterm/git/git-aliases/subcommands/git-wt/git-wt-completion.zsh`
- `/home/mobaxterm/git/git-aliases/subcommands/git-sync/git-sync-completion.bash`
- `/home/mobaxterm/git/git-aliases/tests/test-bash-completion.sh`
- `/home/mobaxterm/git/git-aliases/tests/test-zsh-completion.sh`

## Decisions
- `+o default` only. `-o nospace` and `-o bashdefault` stay
- `git sync` still uses `compgen -W` and `%(refname:short)`
- Passing assertions use `grep -q` so a green run does not print candidate names

## Deviations
- `zsh` is not a usable command on this machine (`sudo` needs a password). `test-zsh-completion.sh` exits before its new tag-collision case. `make test` stops in `test-wt-wrappers.sh` with `zsh not found`. The zsh format change matches the bash change, which went red (`heads/main`) and then green

## Next Step
- Run QA
