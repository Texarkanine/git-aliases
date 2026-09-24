# Task: git wt cleanup

* Task ID: git-wt-cleanup
* Complexity: Level 2
* Type: simple enhancement

Add `git wt cleanup [--all] [--list] [--yes|-y] [--force]` to `subcommands/git-wt/git-wt.bash`. It finds the worktrees `git wt go` created (linked worktrees whose physical path equals `wt_worktree_path <branch>` for their checked-out branch) in the current repo, or in every repo with a worktree under `~/worktrees` with `--all`. `--list` prints their paths on stdout and exits 0. Otherwise it lists them on stderr (dirty ones marked), asks once on `/dev/tty` unless `--yes`, and removes each with the same logic as `git wt done`. Without `--force`, dirty worktrees are skipped with a stderr note (not a failure). With `--force`, dirty worktrees are removed; the single cleanup confirmation (which lists them as dirty) replaces `done`'s per-worktree prompt. Add `git wt done --yes|-y` to skip `done`'s discard prompt. Teach the `wt` wrappers to forward `cleanup` and `cd` to main when cleanup removed the worktree containing cwd.

## Test Plan (TDD)

### Behaviors to Verify

- done --yes: dirty worktree, `git wt done br --force --yes` under a PTY that would answer `n` → exit 0, worktree removed (proves no prompt).
- done --yes without --force: dirty worktree, `git wt done br --yes` → non-zero, mentions `--force`, worktree kept.
- list current repo: repo with `go a` and `go feature/x`, a foreign worktree (`git worktree add` elsewhere), and main → `cleanup --list` stdout is exactly the two go paths (one per line, any order), exit 0, nothing removed.
- list excludes other repos: second repo has a go worktree → not in first repo's `--list`.
- list --all: two repos with go worktrees (one a slash branch), run from outside any repo → `cleanup --all --list` prints all of them, exit 0.
- list empty: repo with no go worktrees → `--list` stdout empty, exit 0.
- not a repo: outside a repo, `cleanup --list` → non-zero.
- unknown option: `cleanup --bogus` → non-zero.
- --yes removes clean only: clean go worktree, dirty go worktree, foreign worktree → `cleanup --yes` exit 0; clean removed; dirty kept with stderr note mentioning `--force`; foreign kept; branches kept.
- --yes --force removes dirty, no prompt: under PTY answering `n` → exit 0, clean and dirty go worktrees removed, foreign kept.
- prompt yes: `cleanup` under PTY answering `y` → clean go worktree removed.
- prompt no: `cleanup` under PTY answering `n` → non-zero, nothing removed.
- nothing to clean: `cleanup --yes` in a repo with none → exit 0, stdout empty.
- inside removed worktree: cwd inside a go worktree, `cleanup --yes` → stdout is the main checkout path, worktree removed; cwd outside → stdout empty (covered by the --yes test).
- --all --yes removes across repos: two repos → both repos' go worktrees removed.
- ~~help lists cleanup: `git wt -h` stdout mentions `cleanup`.~~ (struck by preflight: change-detector)
- wrapper cleanup cds: bash and zsh `wt cleanup --yes` with mock git printing a main path → pwd is that path.
- wrapper cleanup --list passes through: bash and zsh `wt cleanup --list` → mock paths on stdout, pwd unchanged.

### Test Infrastructure

- Framework: homemade POSIX `sh` suites run by `make test`; `run_isolated` gives each test a temp `HOME`, `PATH`, and null git config; `run_with_tty` drives `/dev/tty` prompts through a python3 PTY.
- Test location: `tests/`
- Conventions: `test_<area>_<case>` functions with unique variable prefixes, `invoke` captures `last_out`/`last_err`/`last_rc`, `fail` exits the subshell, registered via `run_one` in `main`.
- New test files: none (extend `tests/test-git-wt.sh` and `tests/test-wt-wrappers.sh`).

## Implementation Plan

### 1. Shared removal helper and `done --yes` — executable

- Files: `subcommands/git-wt/git-wt.bash`, `tests/test-git-wt.sh`

1. Stub tests: `test_done_force_yes_flag_no_prompt`, `test_done_yes_without_force_dirty` (empty bodies), registered in `main`.
2. Stub interface: `wt_cwd_inside <wt_path>` (0 if cwd is the worktree or below) and `wt_remove_worktree <main> <wt_path> <force> <yes>` (dirty check, optional `/dev/tty` confirm, `git -C main worktree remove [--force]`, prune), with doc headers.
3. Write tests and run red: dirty worktree + `run_with_tty n git wt done br --force --yes` succeeds and removes; `git wt done br --yes` on dirty fails mentioning force and keeps the tree.
4. Write code and run green: parse `--yes|-y` in `cmd_done`; move the dirty/prompt/remove/prune block into `wt_remove_worktree`, the in-worktree check into `wt_cwd_inside`; `cmd_done` calls both. Existing `done` tests stay green.

### 2. Worktree discovery and `cleanup --list` — executable

- Files: `subcommands/git-wt/git-wt.bash`, `tests/test-git-wt.sh`

1. Stub tests: `test_cleanup_list_current_repo`, `test_cleanup_list_excludes_other_repo`, `test_cleanup_list_all`, `test_cleanup_list_empty`, `test_cleanup_not_a_repo`, `test_cleanup_unknown_option`. ~~`test_help_flags` gains a `cleanup` assertion.~~ (struck by preflight: change-detector)
2. Stub interface: `wt_created_worktrees` (current repo: parse porcelain, for each non-main `branch refs/heads/X` entry compare `pwd -P` of its path with `pwd -P` of `wt_worktree_path X`; print matches), `wt_scan_worktree_roots <dir>` (recursive: print `dir` if `dir/.git` exists, else recurse into subdirs; stops at worktree roots so it never walks worktree contents; handles slash branches), `wt_all_mains` (scan `~/worktrees/*/*/*`, map each root to its main via `git -C root worktree list --porcelain`, dedupe; warn and skip roots git rejects), `cmd_cleanup` flag parsing and dispatch in `main`, `usage` text.
3. Write tests and run red: as in the Behaviors list.
4. Write code and run green: implement the functions; `--list` prints paths (per main, via a subshell `cd main && wt_created_worktrees` for `--all`), exit 0. Non-`--all` outside a repo dies.

### 3. `cleanup` removal — executable

- Files: `subcommands/git-wt/git-wt.bash`, `tests/test-git-wt.sh`

1. Stub tests: `test_cleanup_yes_clean_only`, `test_cleanup_yes_force_no_prompt`, `test_cleanup_prompt_yes`, `test_cleanup_prompt_no`, `test_cleanup_nothing`, `test_cleanup_inside_worktree`, `test_cleanup_all_yes`.
2. Stub interface: removal branch of `cmd_cleanup`.
3. Write tests and run red: as in the Behaviors list.
4. Write code and run green: collect `(main, path, dirty)` rows; empty → stderr note, exit 0. Print the list to stderr, dirty rows marked (`dirty, skipped` or `dirty, changes discarded` with `--force`). Unless `--yes`, prompt `Remove N worktree(s)? [y/N]` on `/dev/tty`; anything but y/yes → `wt_die "cleanup: aborted"`. For each row: record whether cwd is inside (before removal); dirty without `--force` → stderr skip note; else `( cd main && wt_remove_worktree main path force 1 )` in a subshell so a `wt_die` fails only that row; count failures. Before removing, `cd` to that row's main so a vanished cwd cannot break later git calls. Print the main path of a removed cwd-containing worktree on stdout. Exit 1 if any row failed.

### 4. `wt` wrapper forwards `cleanup` — executable

- Files: `shell/wt.bash`, `shell/wt.zsh`, `tests/test-wt-wrappers.sh`

1. Stub tests: `test_bash_cleanup_cds`, `test_zsh_cleanup_cds`, `test_bash_cleanup_list_stays`, `test_zsh_cleanup_list_stays`; mock git gains a `cleanup` case (`--list` prints two mock paths; otherwise prints `${MOCK_ROOT}/main`).
2. Stub interface: `cleanup)` case in both wrappers.
3. Write tests and run red.
4. Write code and run green: if any arg is `--list`, run `git wt cleanup "${@:2}"` uncaptured; else capture stdout and `cd` if non-empty, like `done`. Update wrapper help text.

### 5. Documentation — prose/policy

- Files: `subcommands/git-wt/README.md`, `memory-bank/productContext.md`
- No tests: prose/policy artifact

1. README: usage block, examples (`cleanup --list`, `--yes`, `--yes --force`, `--all`, piping `--list`), discovery rule, dirty/skip semantics, `done --yes`, stdout/stderr contract for `cleanup`, flow diagram node for cleanup, wrapper section mentions `wt cleanup`.
2. productContext: `git wt` use case mentions cleanup.

## Technology Validation

No new technology - validation not required.

## Dependencies

- `git`, `bash`, and (tests only) `python3` and `zsh`, all already required.

## Challenges & Mitigations

- `/dev/tty` prompts in tests: `run_with_tty` with a reply of `n` proves `--yes` paths never prompt (a prompt would abort).
- macOS logical vs physical HOME: compare `pwd -P` of both the porcelain path and the computed layout path.
- `wt_die` exits the whole script: `cleanup` runs each removal in a subshell and counts failures.
- Removing the worktree that contains cwd: `cd` to the row's main before removing; record in-worktree status first.
- `set -e` and failing subshells: use `if ( ... ); then` so failure is handled, not fatal.
- `--all` scanning cost: the scan stops at worktree roots and never enters worktree contents (e.g. `node_modules`).
- Orphaned dirs under `~/worktrees` (repo deleted): git rejects them; warn on stderr and skip rather than fail.

## Pre-Mortem

- Operator expected `--force` to keep `done`'s per-worktree prompt: the single cleanup confirmation lists dirty trees as discarded; call this out in the build summary for operator review.
- Operator expected `cleanup --yes` to exit non-zero when dirty trees remain: the brief frames `--yes` as "delete all clean worktrees", so skips are success; call out in summary.
- Worktrees from an older layout or a different HOME are not found: by definition only layout-matching worktrees are "created by go"; document the rule in the README.
- Slash branches missed by `--all`: covered by `wt_scan_worktree_roots` recursion and a slash-branch test.

## Status

- [x] Initialization complete
- [x] Test planning complete (TDD)
- [x] Implementation plan complete
- [x] Technology validation complete
- [x] Pre-Mortem complete
- [ ] Preflight
- [ ] Build
- [ ] QA
