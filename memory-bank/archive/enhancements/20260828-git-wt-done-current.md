---
task_id: git-wt-done-current
complexity_level: 2
date: 2026-08-28
status: completed
---

# TASK ARCHIVE: git-wt-done-current

## SUMMARY

`git wt done` with no name removes the linked worktree that contains cwd, including worktrees `git wt go` did not create, and still refuses the main checkout. Named `done` and the optional `wt()` wrapper are unchanged. Shipped on [PR #8](https://github.com/Texarkanine/git-aliases/pull/8).

## REQUIREMENTS

1. Nameless `done` infers the worktree from cwd (root or subdirectory).
2. Any linked worktree counts, not only `git wt go` paths.
3. An explicit name still selects that branch's worktree.
4. `--force` works with or without a name.
5. Nameless `done` from main refuses and does not remove main.
6. `wt()` stays opt-in `cd` sugar. Out of scope: renaming the wrapper, wrapping `git`, changing `go`, completion.

## IMPLEMENTATION

`cmd_done` uses a name when given (`wt_worktree_for_branch`). With no name it calls `wt_worktree_containing_cwd`: if `--absolute-git-dir` equals `--git-common-dir`, cwd is main (empty, refuse); otherwise print `--show-toplevel` and remove that path. Dirty/`--force`/stdout-if-inside are unchanged.

A porcelain cwd scan would have matched main first when a worktree is nested inside the main checkout. `git rev-parse` avoids that.

Key files: `subcommands/git-wt/git-wt.bash`, `tests/test-git-wt.sh`, `subcommands/git-wt/README.md`, `shell/wt.bash`, `shell/wt.zsh` (usage text only).

## TESTING

TDD in `tests/test-git-wt.sh`: nameless inside, subdirectory, foreign nested under main, named foreign, nameless from main, nameless dirty/`--force`. Named foreign was already green (porcelain-by-branch). `make test` passed. `/niko-qa` PASS.

## LESSONS LEARNED

- Linked vs main is git-dir vs common-dir, not a path-prefix scan.
- After `worktree remove` of the tree you are in, cwd is gone; later `git` in that test needs `git -C` on main.
- `done` means this worktree; a name is the override for tearing down some other tree from elsewhere.
- A subprocess cannot `cd` the parent; wrapping `git` is worse than an opt-in `wt()`.

## PROCESS IMPROVEMENTS

Preflight FAIL (fixable) for an untested stated requirement (named foreign `done`) was cheaper than finding it in QA. Ephemeral memory-bank files, including `.preflight-status`, are committed task record; ephemeral means deleted at archive, not untracked.

## TECHNICAL IMPROVEMENTS

None beyond the helper choice above.

## NEXT STEPS

None. Reinstall with `make subcommands` (and `make shell` for updated wrapper help).
