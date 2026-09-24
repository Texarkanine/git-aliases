# Active Context

**Current Task:** git wt cleanup +cursor

**Phase:** PLAN - COMPLETE

**What Was Done:** Level 2 plan for `+cursor` on `git wt cleanup`. Membership comes from `git worktree list`; `~/.cursor/worktrees` is scanned only for `--all` repo discovery. Unknown `+source` is an error. An empty Cursor session directory is removed after a successful removal. `+claude` is an issue, not an implementation: Claude Code's default path is `<repo>/.claude/worktrees/<name>/`.

**Next Step:** Preflight.
