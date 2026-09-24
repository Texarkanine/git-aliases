# Project Brief

## User Story

As a `git wt` user, I want `GITWT_ROOT` to be the root where worktrees are created so that I can choose where they live on my system and every invocation of the tool still works.

## Use-Case(s)

### Custom root

The environment variable `GITWT_ROOT` is set. Worktrees are created under that path instead of `~/worktrees`. Every invocation of the tool uses that same root.

### Default root

`GITWT_ROOT` is unset. Worktrees are created under `~/worktrees`, as they are today.

## Requirements

1. If `GITWT_ROOT` is set, take it as the root of where worktrees get created.
2. If `GITWT_ROOT` is unset, keep the default of `~/worktrees`.
3. All invocations of the tool still work properly when the variable is set.

As described in [issue #15](https://github.com/Texarkanine/git-aliases/issues/15).

## Constraints

1. Subcommands run in bash. No new runtime dependencies.

## Acceptance Criteria

1. With `GITWT_ROOT` set, worktrees are created under that root.
2. With `GITWT_ROOT` unset, worktrees are created under `~/worktrees`.
3. Every invocation of the tool uses the same root, so behavior stays consistent when the variable is set.
