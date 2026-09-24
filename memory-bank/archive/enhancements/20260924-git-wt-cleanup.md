---
task_id: git-wt-cleanup
complexity_level: 2
date: 2026-09-24
status: completed
---

# TASK ARCHIVE: git-wt-cleanup

## SUMMARY

Added `git wt cleanup [--all] [--list] [--yes|-y] [--force]` to find and remove the worktrees `git wt go` created, plus `git wt done --yes|-y` and `wt cleanup` wrapper support. Shipped on [PR #12](https://github.com/Texarkanine/git-aliases/pull/12). The follow-up to include Cursor worktrees (`+cursor`) is [issue #11](https://github.com/Texarkanine/git-aliases/issues/11).

## REQUIREMENTS

1. `cleanup` lists the worktrees `go` created, asks once, then removes each as `done` would.
2. Scope is the current repo by default; `--all` covers every repo under `~/worktrees`.
3. `--yes` / `-y` skips the confirmation. `--force` removes dirty worktrees too. Without it, dirty ones are skipped.
4. `--list` prints paths only (for piping into tools that `cd` and inspect) and removes nothing.
5. `cleanup --yes --force` must run with no prompts at all.
6. Dropped: `--rm`. `git worktree remove` already deletes the directory, ignored files included (verified on a scratch repo).

## IMPLEMENTATION

In `subcommands/git-wt/git-wt.bash`:

- **Shared removal:** `wt_remove_worktree <main> <path> <force> <yes>` and `wt_cwd_inside` were extracted from `cmd_done`. Removal runs `git -C <main>`, so `done` no longer depends on cwd.
- **Discovery:** `wt_created_worktrees` matches porcelain entries (branch checked out, directory present) against a per-repo layout prefix from `wt_layout_prefix`, in both logical and physical forms (macOS `/private`). It prints the logical layout path, the same path `go` prints.
- **`--all`:** `wt_all_mains` globs `~/worktrees/<owner>/<repo>/<repo>-*` with `dotglob` on, so repos like `.github` are included. `wt_scan_worktree_roots` stops at worktree roots, skips symlinks and caps depth at 8. Each root is mapped to its main checkout, and duplicates are removed.
- **`cmd_cleanup`:**
    - Records dirty and inside-cwd state before removing anything.
    - Asks one `/dev/tty` confirmation; with no terminal, it tells you to use `--yes`.
    - Removes each worktree in its own subshell, so one failure doesn't stop the rest; any failure makes the exit status non-zero.
    - Prints the main checkout path on stdout if cwd was inside a removed worktree.

`shell/wt.bash` and `shell/wt.zsh` forward `cleanup`. The wrapper changes directory whenever a path is printed, even when cleanup fails, and passes `--list` through without capturing it. Docs are in `subcommands/git-wt/README.md`, including a cleanup flowchart and the stdout/stderr contract.

## TESTING

TDD throughout. `tests/test-git-wt.sh` gained 18 tests covering:

- `--list` for the current repo, other repos, `--all`, empty results, missing directories, symlink loops and dot-named repos
- `--yes` with only clean worktrees, and `--yes --force` with no prompt (the terminal answers `n`)
- answering the prompt yes and no, nothing to clean, running from inside a worktree, `--all --yes`, and carrying on after a locked worktree fails
- `done --yes`, with and without `--force`

`tests/test-wt-wrappers.sh` gained 6 tests: the wrapper changes directory, changes directory on partial failure, and passes `--list` through, each in bash and zsh.

- **Preflight:** PASS WITH ADVISORY. The advisories were folded into the build.
- **QA:** failed twice, then passed.
    - First failure: the `--all` scan hung on a stray folder with a symlink loop.
    - Second failure: the regression test's shell-based timeout leaked processes and held the output pipe open for about 20 s. It was replaced by a python3 helper, `run_with_timeout`, that kills the whole process group.
- **Bug found by the operator after reflect:** `--all` skipped dot-named repos. Fixed with a catching test, red then green.
- **Environment:** this machine has no zsh, so the wrapper tests ran with a zsh unpacked from the .deb. `test-install-completions` fails the same way on unmodified `main`, because that zsh can't load `compinit`. CI has a real zsh.

## LESSONS LEARNED

- `set -e` is suspended inside `if` conditions, including `if ( ... )`. A helper that callers may test must `return 1` explicitly.
- Bash's `"${dir}"/*/` follows symlinks and skips dot-directories. A scan needs `! -L`, a depth cap, and `dotglob` wherever names can start with a dot.
- Timeouts in POSIX sh tests: a background `( sleep; kill ) &` holds the output pipe open and never reaches grandchildren. `set -m` doesn't work in non-interactive dash. A python3 `Popen(start_new_session=True)` plus `killpg` works on Linux and macOS.
- In the persistent agent shell, run demos that change `HOME` in a subshell. An exported scratch `HOME` broke `gh` auth later in the session.

## PROCESS IMPROVEMENTS

Two rounds of independent QA caught real defects that self-verification missed: the symlink hang and the leaking test harness. The operator using the tool on their own machine caught a third, dot-named repos. The lesson: for filesystem-scanning code, test against realistic directory names. The org's own repos (`.github`, `.cursor-rules`) were the obvious case.

## TECHNICAL IMPROVEMENTS

- **Provenance registry:** if "created by `go`" had been a first-class concept, `go` would add the main checkout path to a small list, such as `~/.local/state/git-wt/repos`. `cleanup --all` would then read that list instead of scanning `~/worktrees`, which removes the symlink, depth, dot-directory and orphan handling. Worktrees made before the list existed would still need the scan once. This was deferred.
- **Duplicate confirmation code:** `done` and `cleanup` still each have their own `/dev/tty` confirmation code. A shared helper would give `done --force` the same "no terminal; use --yes" message.

## NEXT STEPS

- [Issue #11](https://github.com/Texarkanine/git-aliases/issues/11): `cleanup +cursor` to include `~/.cursor/worktrees`, including detached-HEAD worktrees.
- Re-run `make subcommands` and `make shell` locally after merge.
