# Task: git wt cleanup +cursor

* Task ID: git-wt-cleanup-cursor
* Complexity: Level 2
* Type: simple enhancement

Add a positional `+cursor` token to `git wt cleanup`, as specified in [issue #11](https://github.com/Texarkanine/git-aliases/issues/11). `+cursor` adds Cursor worktrees to the set cleanup already assesses. It does not replace `git wt go` worktrees.

Plan decisions for the issue's open questions:

- Without `--all`, `+cursor` adds only linked worktrees of the current repo whose path is under `~/.cursor/worktrees`. With `--all`, it also discovers repos by scanning that directory, then asks each repo's `git worktree list`.
- After a successful removal, remove `~/.cursor/worktrees/<name>/` when that directory is empty. Do not remove `~/.cursor/worktrees` itself, and do not remove a session directory that still has entries.
- An unknown `+source` (anything other than `+cursor`) is an error.

## Test Plan (TDD)

### Behaviors to Verify

- `git wt cleanup --list +cursor` inside a repo → prints that repo's `git wt go` worktrees and its linked worktrees under `~/.cursor/worktrees`, including a detached HEAD, and removes nothing
- `git wt cleanup +cursor --list` → same paths as `--list +cursor` (token may appear anywhere)
- `git wt cleanup --list +cursor` → does not print another repo's Cursor worktree, a plain `git worktree add` outside both layouts, or the main checkout
- `git wt cleanup --list` without `+cursor` → does not print a Cursor worktree
- `git wt cleanup --list +foo` → non-zero, removes nothing
- `git wt cleanup +cursor --list` outside a repo → non-zero
- `git wt cleanup --all --list +cursor` outside a repo → prints `git wt go` worktrees and Cursor worktrees for every repo that has either, and ignores an empty `~/.cursor/worktrees/<name>/` that has no `.git`
- `git wt cleanup --all --list +cursor` with a symlink loop under `~/.cursor/worktrees` → finishes and still prints the real Cursor worktree
- `git wt cleanup +cursor --yes` → removes the clean Cursor worktree (detached) and the clean `go` worktree, leaves a foreign worktree, and removes the Cursor session directory when it is empty afterwards
- `git wt cleanup +cursor --yes` on a dirty Cursor worktree → leaves it, exit 0 (same skip-as-success rule as today)
- `git wt cleanup +cursor --yes --force` on a dirty Cursor worktree → removes it
- `git wt cleanup +cursor --yes` when the session directory still holds another entry → removes the worktree and leaves the session directory
- `git wt cleanup --all +cursor --yes` for a repo that has both a `go` worktree and a Cursor worktree → removes each path once, exits 0, and does not attempt a second removal

### Test Infrastructure

- Framework: POSIX shell tests under `tests/`, run with `make test` (shunit2 is bundled but `tests/test-git-wt.sh` is the homemade suite)
- Test location: `tests/test-git-wt.sh`
- Conventions: `test_*` functions, `make_repo`, `invoke`, `last_out` / `last_rc` / `last_err`, `sorted_lines` for unordered path lists, `HOME` overridden inside a test when the layout root must move
- New test files: none

## Implementation Plan

### 1. Current-repo +cursor listing — executable

- Files: `tests/test-git-wt.sh`, `subcommands/git-wt/git-wt.bash`

1. Stub tests: empty `test_cleanup_list_cursor_current_repo`, `test_cleanup_list_cursor_token_position`, `test_cleanup_list_without_cursor_excludes_cursor`, `test_cleanup_cursor_unknown_source`, `test_cleanup_cursor_outside_repo` in `tests/test-git-wt.sh`, and a `run_one` line for each in `main()`. A `test_*` function that is not passed to `run_one` never runs.
2. Stub interface: `wt_cursor_worktrees` in `git-wt.bash` (no args; prints qualifying paths of the current repo). Extend `cmd_cleanup`'s argument loop to accept a `+cursor` flag and reject any other `+*` token. Document both in the file's existing comment style.
3. Write tests and run red: assertions for the five behaviors above. Cursor fixtures are `git worktree add` (one detached, one branched) under `${HOME}/.cursor/worktrees/<name>/<repo-ish>`.
4. Write code and run green: `wt_cursor_worktrees` reads `git worktree list --porcelain` and prints linked worktrees whose path is under `${HOME}/.cursor/worktrees`, including records with no `branch` line. Print the HOME-logical path (the form under `${HOME}/.cursor/worktrees`), and match both the logical and physical porcelain path the way `wt_created_worktrees` does. `cmd_cleanup` unions those paths with `wt_created_worktrees` when `+cursor` is set. Listing and the existing remove path both use that union.

### 2. --all discovery — executable

- Files: `tests/test-git-wt.sh`, `subcommands/git-wt/git-wt.bash`

1. Stub tests: empty `test_cleanup_list_all_cursor`, `test_cleanup_list_all_cursor_ignores_empty`, `test_cleanup_list_all_cursor_symlink_loop`, each with a `run_one` line in `main()`.
2. Stub interface: `wt_all_cursor_mains` (no args; prints unique main checkout paths discovered under `${HOME}/.cursor/worktrees`).
3. Write tests and run red: `--all --list +cursor` from outside a repo; an empty session directory is absent from the output; a symlink loop under `~/.cursor/worktrees` returns within the existing `run_with_timeout` bound.
4. Write code and run green: scan with `wt_scan_worktree_roots` (stop at `.git`, do not follow symlinks, depth cap). Resolve each root with `wt_main_worktree`, skip unusable roots the way `wt_all_mains` does, and print unique mains. `cmd_cleanup --all` uniques the combined `wt_all_mains` and `wt_all_cursor_mains` list before the per-main walk. Each main contributes `wt_cursor_worktrees` only when `+cursor` is set. `git wt go` discovery stays `wt_all_mains`.

### 3. Removal and empty session directory — executable

- Files: `tests/test-git-wt.sh`, `subcommands/git-wt/git-wt.bash`

1. Stub tests: empty `test_cleanup_cursor_yes_removes_and_rmdir`, `test_cleanup_cursor_dirty_skipped`, `test_cleanup_cursor_dirty_force`, `test_cleanup_cursor_keeps_nonempty_session`, `test_cleanup_all_cursor_yes_once`, each with a `run_one` line in `main()`.
2. Stub interface: `wt_remove_empty_cursor_session` (`$1` worktree path; removes the session directory only when it is a direct child of `${HOME}/.cursor/worktrees` and is empty). Match the session directory on both the logical and physical path.
3. Write tests and run red: the four removal behaviors above.
4. Write code and run green: after each successful Cursor removal, call `wt_remove_empty_cursor_session`. Dirty skip and `--force` stay on the existing `wt_remove_worktree` path. A failed removal does not remove the session directory. Because mains were uniqued in step 2, `--all +cursor --yes` removes a path that is both a `go` worktree and under `~/.cursor/worktrees` only once. `test_cleanup_all_cursor_yes_once` is the assertion for that.

### 4. README — prose/policy

- Files: `subcommands/git-wt/README.md`, `subcommands/git-wt/git-wt.bash`
- No tests: prose/policy artifact

1. Document `+cursor`, where it may appear, detached HEAD, empty session directories, unknown `+source`, and that `--all` scans `~/.cursor/worktrees` without following symlinks.
2. Mention `+cursor` in `usage()` and the file-header usage block so `git wt help` matches the README.

### 5. +claude issue — prose/policy

- Files: none in this repo
- No tests: prose/policy artifact

1. Open a GitHub issue on Texarkanine/git-aliases proposing `+claude` for `git wt cleanup`. State the deterministic default from the Claude Code docs: worktrees are created at `<repo>/.claude/worktrees/<name>/` on a branch named `worktree-<name>`. Note that a `WorktreeCreate` hook can place them elsewhere, so `+claude` would cover the default location only. Note that `--all` cannot discover them by scanning one global directory, because they live inside each repository. Do not implement `+claude`.

## Technology Validation

No new technology - validation not required

## Dependencies

- Existing `git worktree list --porcelain` parsing in `wt_created_worktrees`
- Existing `wt_scan_worktree_roots` for `--all` discovery
- `gh` to open the `+claude` issue

## Challenges & Mitigations

- Porcelain paths may be physical (`pwd -P`) while `~/.cursor/worktrees` is logical: compare both forms, the same way `wt_created_worktrees` already does.
- A Cursor worktree contains `node_modules` and other trees: `wt_scan_worktree_roots` stops at the first `.git`, so the scan does not walk worktree contents.
- Symlink loops under `~/.cursor/worktrees`: do not follow symlinks, and keep the depth cap. The timeout test guards a hang.
- `rmdir` of a session directory could remove something the user still wants: only the direct child of `~/.cursor/worktrees`, only when empty, only after a successful removal.
- Detached porcelain records have no `branch` line: the Cursor filter must not require one. The `go` filter still requires a layout path for its branch.
- A repo discovered from both `~/worktrees` and `~/.cursor/worktrees` would be removed twice: unique the combined main list before the per-main walk, and cover it with `test_cleanup_all_cursor_yes_once`.

## Pre-Mortem

- Treating `+cursor` as a replacement for `go` worktrees would drop current cleanup behavior: the plan unions the two sets.
- Walking `~/.cursor/worktrees` to decide membership, instead of `git worktree list` once a repo is known, repeats the scan we already decided git should own: membership comes from `git worktree list`; the scan only discovers repos for `--all`.
- Cursor worktrees placed outside `~/.cursor/worktrees` would be missed: issue #11 scopes the feature to that directory.

## Status

- [x] Initialization complete
- [x] Test planning complete (TDD)
- [x] Implementation plan complete
- [x] Technology validation complete
- [x] Pre-Mortem complete
- [ ] Preflight
- [ ] Build
- [ ] QA
