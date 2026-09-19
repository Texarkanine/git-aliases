# Project Brief

## User Story

As a Git user with linked worktrees, I want `git sync` to update my current branch from the source branch (usually `main`) without checking that source branch out, so sync works from a worktree or the primary checkout even when the source branch is already checked out elsewhere.

## Use-Case(s)

### Sync from a linked worktree

The primary checkout holds `main`. A feature worktree is on a branch created from `main`. Running `git sync` in the worktree updates the feature branch from the latest source without attempting `git checkout main`.

### Sync from the primary checkout

Same command, same outcome as today: stash if needed, refresh source, rebase or merge onto the current branch, restore stash. No worktree-specific invocation.

### Sync with no remote

When there is no remote, rebase or merge onto the local source branch without checking it out.

## Requirements

1. `git sync` must not check out the source branch.
2. The same command path must work from a linked worktree and from the primary checkout.
3. Existing stash, confirm, rebase, and merge behavior stays intact.
4. Code edits stay as small as possible (KISS). Process stays full Niko rigor — this is not hackathon work.

## Constraints

1. KISS to the max on code edits: change the update path, do not redesign the subcommand.
2. Normal Niko rigor: TDD, plan, preflight, QA, reflect. Not a hackathon shortcut.
3. Subcommand remains bash; tests remain POSIX homemade suites under `tests/`.
4. No new runtime dependencies.

## Acceptance Criteria

1. With `main` checked out in the primary worktree, `git sync` from a feature worktree succeeds (rebase default and `--merge`).
2. `git sync` from the primary checkout on a feature branch still succeeds.
3. `git sync` does not leave the caller on a different branch than they started on (except a failed rebase/merge, which already did that).
4. Existing stash-safety contract is unchanged: a pre-existing stash is never popped.
