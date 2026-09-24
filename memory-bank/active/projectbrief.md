# Project Brief

## User story

As a `git wt` user, I want `git wt cleanup` to also assess worktrees Cursor creates under `~/.cursor/worktrees`, opted in with a positional `+cursor` token, as specified in [issue #11](https://github.com/Texarkanine/git-aliases/issues/11).

## Requirements

- Implement [issue #11](https://github.com/Texarkanine/git-aliases/issues/11) as written. That issue is the requirements source.
- While implementing, check [Claude Code worktrees](https://code.claude.com/docs/en/worktrees). If that layout is deterministic, open a separate issue on this repo to add `+claude` to `git wt cleanup`. Do not implement `+claude` in this task.
