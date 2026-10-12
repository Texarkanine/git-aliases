# Project Brief

## User Story

As a person using `git wt done` and `git wt cleanup`, I want a worktree removed without `--force` only when a commit would truly keep nothing, so that uncommitted work is not discarded under a `stripped` or `orphan` label.

## Use-Case(s)

### Use-Case 1

A worktree whose `git status` shows a change that `git add -A` does not record — a dirty submodule (` M sub`), or a CRLF-only file under `core.autocrlf=input` or `* text=auto` — stays dirty. It is not removed without `--force`.

### Use-Case 2

A worktree with a hook-stripped untracked file and a status path the pre-hook diff never contains (a dirty submodule beside `?? local/`) stays dirty. `stripped` applies only when every status path is in the pre-hook diff against `HEAD` and the hook then makes that tree match `HEAD`.

### Use-Case 3

An orphaned detached HEAD is `orphan` only when the worktree would otherwise be `clean` or `stripped`. Any other change stays `dirty`, so `git wt done --force` does not describe an unstaged edit as only "commits on no branch".

## Requirements

1. Classify `stripped` only when every `git status` path is in the pre-hook diff against `HEAD` and the hook then makes that tree match `HEAD`.
2. If the scratch `git add -A` tree already matches `HEAD`, keep the worktree dirty.
3. Return `orphan` only for a result that would have been `clean` or `stripped`.
4. Push the branch when the fix is done, then leave a handoff.

## Constraints

1. The change stays inside `git wt` classification for `done` and `cleanup`.
2. Hook-stripped files that the hook actually removes from the commit remain safe to discard.
3. Subcommands stay bash. Tests stay the existing `git wt` suite.

## Acceptance Criteria

1. A dirty submodule, alone or beside a hook-stripped untracked file, is not removed without `--force`.
2. A CRLF-only file under `core.autocrlf=input` or `* text=auto` is not removed without `--force`.
3. An orphaned detached HEAD with an unstaged edit is `dirty`. Without `--force` it is kept. With `--force` the confirmation names uncommitted changes.
4. An orphaned detached HEAD with an empty status, or with only hook-stripped files, stays `orphan`.
5. Existing hook-stripped removal, partial-staging, and clean-orphan behavior still hold.

## Rework

A hook-stripped path that `git status` quotes is still classified dirty, so `git wt cleanup` keeps the worktree. Porcelain prints `?? "my rule.md"` and `?? "local rules/"`. `git diff-tree --name-only` prints those paths without quotes. The trailing slash sits inside the quotes, so stripping a final `/` does nothing. The tests only plant `local/rule.md`, which is not quoted.

Operator asked to fix this and push the branch.

### Requirements

1. Compare `git status -z` paths with `git diff-tree -z --name-only`.
2. Treat a trailing slash as a directory. `local rules/` is covered when a diff path is inside it.
3. A worktree whose only changes are hook-stripped paths that contain a space (`my rule.md`, `local rules/rule.md`) is `stripped` and removed without `--force`.
4. The classifications already required above still hold.
5. Push the branch when the fix is done.
