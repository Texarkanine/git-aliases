---
task_id: gitwt-root
complexity_level: 2
date: 2026-09-24
status: completed
---

# TASK ARCHIVE: GITWT_ROOT envvar support

## SUMMARY

`git wt` uses `GITWT_ROOT` as the worktree root when that variable is an absolute path, and `~/worktrees` when it is unset or empty. `go`, `done`, and `cleanup` (including `--all`) share that root. Cursor worktrees stay under `~/.cursor/worktrees`. QA passed. Draft pull request: https://github.com/Texarkanine/git-aliases/pull/16. Closes [issue #15](https://github.com/Texarkanine/git-aliases/issues/15).

## REQUIREMENTS

- If `GITWT_ROOT` is set, use it as the root where worktrees are created.
- If it is unset, keep `~/worktrees`.
- Every invocation of the tool uses the same root.

Empty is treated as unset. A relative value is an error. Those two rules were not in the issue text. They are what "still work properly" required, so a bad setting cannot create a cwd-relative tree.

## IMPLEMENTATION

`wt_worktrees_root` in `subcommands/git-wt/git-wt.bash` is the only root. `wt_layout_prefix` and `wt_all_mains` call it. `dotglob` around the `--all` scan is unchanged. The helper returns the configured path, not a physical path. One trailing slash is stripped, except when the root is `/`.

`main` calls `wt_worktrees_root` before `go`, `done`, and `cleanup`. `wt_die` inside a command substitution would only exit that subshell, and a relative value would otherwise continue into `mkdir`.

Docs: `subcommands/git-wt/README.md` (Where Worktrees Go, and the `--all` search sentence) and the git-wt bullet in `README.md`.

## TESTING

Five cases in `tests/test-git-wt.sh`: custom root for `go`, `done`, `cleanup --all`, and `+cursor`; empty; relative; trailing slash; a root path with a space. `run_isolated` unsets `GITWT_ROOT` so an exported value cannot move the existing path assertions. The relative case also requires that stderr name the absolute-path rule and that `mkdir` does not run.

`sh tests/test-git-wt.sh` passed. A manual run showed unset → `$HOME/worktrees/...`, a set absolute root → that directory, and `GITWT_ROOT=relative/root` → `wt: GITWT_ROOT must be an absolute path: relative/root` and exit 1.

`/niko-qa` passed. It noted that `GITWT_ROOT=/` still prints a doubled slash, which the plan accepted, and that the relative-path error shows the path after the trailing slash is stripped.

## LESSONS LEARNED

`run_isolated` has to unset `GITWT_ROOT`. An exported value in the agent shell would move every existing path assertion off `${HOME}/worktrees`.

`exit` inside `$(...)` does not stop the caller. A bad root has to be rejected in the main shell before any path is built.

## PROCESS IMPROVEMENTS

Nothing notable. The plan named the two call sites and the existing test file, and that sequence held.

## TECHNICAL IMPROVEMENTS

Nothing further. `wt_layout_prefix` and `wt_all_mains` were already the only readers of `${HOME}/worktrees`, so the helper did not need a wider redesign.

## NEXT STEPS

None in the product. Review and merge draft pull request #16.
