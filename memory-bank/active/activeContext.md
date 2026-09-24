# Active Context

**Current Task:** git wt cleanup +cursor

**Phase:** BUILD - COMPLETE

**What Was Done:** `git wt cleanup` accepts `+cursor` anywhere in its arguments. Current-repo membership comes from `git worktree list`. `--all` scans `~/.cursor/worktrees` only to discover mains, then uniques them with the `git wt go` mains. An empty Cursor session directory is removed after a successful removal. Unknown `+source` is an error. Opened [issue #13](https://github.com/Texarkanine/git-aliases/issues/13) for `+claude` and did not implement it.

**Files modified:**
- `/home/mobaxterm/Documents/git/git-aliases/subcommands/git-wt/git-wt.bash`
- `/home/mobaxterm/Documents/git/git-aliases/subcommands/git-wt/README.md`
- `/home/mobaxterm/Documents/git/git-aliases/tests/test-git-wt.sh`
- `/home/mobaxterm/Documents/git/git-aliases/shell/wt.bash`
- `/home/mobaxterm/Documents/git/git-aliases/shell/wt.zsh`

**Decisions:** Adopted the preflight advisories for exclusion assertions (already on the current-repo list test), wrapper help, and the cleanup diagram. Left the source-descriptor redesign out.

**Next Step:** QA.
