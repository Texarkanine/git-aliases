---
task_id: git-wt-cleanup-cursor
complexity_level: 2
date: 2026-09-24
status: completed
---

# TASK ARCHIVE: git wt cleanup +cursor

## SUMMARY

`git wt cleanup` accepts a positional `+cursor` token. It adds linked worktrees under `~/.cursor/worktrees` to the set `git wt go` created, including a detached HEAD. `--all` discovers repositories by scanning that directory, then uses `git worktree list` for membership. An empty `~/.cursor/worktrees/<name>/` is removed after a successful removal. Any other `+source` is an error. `+claude` was filed as issue #13 and not built. The work is pull request #14.

## REQUIREMENTS

- Implement [issue #11](https://github.com/Texarkanine/git-aliases/issues/11) as written.
- If Claude Code's default worktree layout is deterministic, open a follow-up issue and do not implement it. The default is `<repo>/.claude/worktrees/<name>/` on branch `worktree-<name>`.

## IMPLEMENTATION

Membership for one repository comes from `git worktree list`. The filesystem scan exists only so `--all` can find repositories when you are not already inside one. Mains from `~/worktrees` and `~/.cursor/worktrees` are uniqued before removal, so a repository in both layouts is removed once. The first directory under `~/.cursor/worktrees` is globbed with `dotglob`, so a session named `.github` is found. The shared walker is unchanged.

Key files: `subcommands/git-wt/git-wt.bash`, `tests/test-git-wt.sh`, `subcommands/git-wt/README.md`, `shell/wt.bash`, `shell/wt.zsh`.

The readme explains the commands in prose. Flowcharts that restated that prose were removed.

## TESTING

Fourteen new cases in `tests/test-git-wt.sh`, each registered with `run_one`. They cover listing, token position, exclusions, an unknown source, running outside a repository, `--all`, an empty session, a symlink loop, a dot-named session, removal, a dirty skip, `--force`, a non-empty session, and one removal when a repository has both layouts. `sh tests/test-git-wt.sh` passed after the dot-session fix. QA passed before that fix. Zsh completion tests need a system zsh on this machine.

## LESSONS LEARNED

`git worktree list` is the membership list for one repository. A directory scan is only how `--all` discovers repositories. A new test in `tests/test-git-wt.sh` runs only when `main()` calls `run_one`. A page of flowcharts that restates the readme does not make the commands clearer.

## PROCESS IMPROVEMENTS

Preflight caught unique mains and missing `run_one` lines before build. That is the check to keep.

## TECHNICAL IMPROVEMENTS

If a second source such as `+claude` ships, `go` and `cursor` should be data for one porcelain filter and one root-to-mains scan. That was not worth building for one added source.

## NEXT STEPS

Issue #13 (`+claude`) is open and not started.
