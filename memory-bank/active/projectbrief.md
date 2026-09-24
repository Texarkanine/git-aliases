# Project Brief: git wt cleanup

## User Story

As a `git wt` user, I forget to `git wt done` every worktree that `git wt go` created, and they eat disk. I want one command that finds them and tears them down.

## Requirements

- Add `git wt cleanup`: list the worktrees `git wt go` created (linked worktrees sitting at `~/worktrees/<owner>/<repo>/<repo>-<branch>` for their branch), ask once for confirmation, then `git wt done` each.
- Scope: current repo by default. `--all` covers every repo under `~/worktrees`.
- `--yes` / `-y` skips the confirmation.
- `--force` passes through to `git wt done`, so dirty worktrees are removed too. Without it, dirty worktrees are refused by `done` and only clean ones go.
- `--list` prints the worktree paths, one per line, and exits (equivalent to answering "no"). Paths are for piping into tools that `cd` into each one to inspect it.
- `git wt cleanup --yes --force` removes every `go`-created worktree with no prompts at all. `git wt cleanup --yes` removes the clean ones.

## Resolved Questions

- `git wt done` already deletes the worktree directory from disk (`git worktree remove` removes ignored files too; verified on a scratch repo). No `--rm` flag is needed. Leftovers are the branch and empty `~/worktrees/<owner>/<repo>/` parents.
- `done --force` prompts on `/dev/tty` before discarding a dirty tree. For `cleanup --yes --force` to be non-interactive, `done` gains a `--yes` flag that skips that prompt; `cleanup --yes` forwards it.
