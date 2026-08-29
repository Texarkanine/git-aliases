# Project Brief

## User Story

As a developer sitting in a linked worktree, I want `git wt done` with no branch name to remove that worktree (and send me back to the main checkout) so I do not have to type the branch name.

## Use-Case(s)

### Use-Case 1

I ran `git wt go testit`, I am in that worktree, and I type `git wt done` or `wt done`. It removes the current worktree and (via the existing wrapper) `cd`s to main.

### Use-Case 2

I am in a linked worktree that `git worktree add` created at some other path. `git wt done` with no name still removes *this* worktree and returns me to main. The path layout `git wt go` uses does not matter.

### Use-Case 3

I still pass an explicit name (`git wt done testit`) when I am not in that worktree, same as today.

## Requirements

1. `git wt done` with no positional argument infers the worktree from the current working directory (the worktree root or a subdirectory).
2. Inference works for any linked worktree of the repo, not only ones created by `git wt go`.
3. An explicit branch name still selects that branch's worktree, as today.
4. `--force` remains valid with or without a name.
5. Omit-the-name from the main checkout still refuses to remove the main checkout.
6. The optional `wt()` wrapper is unchanged: still opt-in via `make shell`, still a thin `cd` wrapper around `git wt`.

## Constraints

1. Out of scope: renaming, hiding, or wrapping `git`; changing `go`; completion.
2. Existing dirty / `--force` / `/dev/tty` / stdout-path contracts stay as they are.
3. Dialect: `git-wt.bash` stays bash; tests stay POSIX.

## Acceptance Criteria

1. From inside a linked worktree, `git wt done` with no name removes that worktree and prints the main checkout path on stdout (so `wt done` can `cd` there).
2. The same command from a subdirectory of that worktree behaves the same.
3. From the main checkout, `git wt done` with no name fails and does not remove main.
4. `git wt done <name>` keeps current behavior, including worktrees `git wt go` did not create.
5. Wrapper tests and wrapper source are not part of this change except where `done` usage text is shared.
