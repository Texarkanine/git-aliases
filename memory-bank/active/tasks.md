# Task: GITWT_ROOT envvar support

* Task ID: gitwt-root
* Complexity: Level 2
* Type: simple enhancement

If `GITWT_ROOT` is set to an absolute path, `git wt` uses it as the root where worktrees are created. If it is unset or empty, the root stays `${HOME}/worktrees`. `go`, `done`, and `cleanup` (including `--all`) all use that same root. Cursor worktrees stay under `~/.cursor/worktrees`.

As described in [issue #15](https://github.com/Texarkanine/git-aliases/issues/15).

## Test Plan (TDD)

### Behaviors to Verify

- `GITWT_ROOT` unset: `git wt go <branch>` prints and creates `${HOME}/worktrees/<owner>/<repo>/<repo>-<branch>`. Existing path tests already assert this once `run_isolated` clears `GITWT_ROOT`.
- `GITWT_ROOT` set to an absolute directory: `git wt go <branch>` prints and creates `${GITWT_ROOT}/<owner>/<repo>/<repo>-<branch>`, and does not create `${HOME}/worktrees/...`.
- Same setting: `git wt done <branch>` removes that worktree.
- Same setting, cwd outside any repo: `git wt cleanup --all --list` prints that worktree.
- Same setting: `git wt cleanup --list +cursor` still lists a Cursor worktree under `${HOME}/.cursor/worktrees` and the go worktree under `GITWT_ROOT`.
- `GITWT_ROOT` empty: `git wt go` uses `${HOME}/worktrees/...`.
- `GITWT_ROOT` relative: `git wt go` exits non-zero and creates no worktree.
- `GITWT_ROOT` absolute with a trailing slash: `git wt go` prints a path with a single slash after the root.
- `GITWT_ROOT` absolute containing a space: `git wt go` creates the worktree and `git wt done` removes it.

### Test Infrastructure

- Framework: homemade POSIX suite (`tests/test-git-wt.sh`), run with `make test`
- Test location: `tests/test-git-wt.sh`
- Conventions: one `test_*` function per case; `run_isolated` sets `HOME` and `PATH`; cases run only when `main` calls `run_one`
- New test files: none

## Implementation Plan

### 1. Worktree root — executable

- Files: `subcommands/git-wt/git-wt.bash`, `tests/test-git-wt.sh`

1. Stub tests: add empty `test_gitwt_root_go_done_cleanup`, `test_gitwt_root_empty`, `test_gitwt_root_relative`, `test_gitwt_root_trailing_slash`, and `test_gitwt_root_spaces`, and call each from `main` via `run_one`.
2. Stub interface: add `wt_worktrees_root` in `git-wt.bash` with the project comment header and an empty body. Point `wt_layout_prefix` and `wt_all_mains` at it without implementing the body yet.
3. Write tests and run red:
    - `run_isolated` unsets `GITWT_ROOT` before the test body.
    - `test_gitwt_root_go_done_cleanup`: export an absolute `GITWT_ROOT` under the temp home; `go` prints and creates the layout under it and not under `${HOME}/worktrees`; `done` removes it; from outside the repo, `cleanup --all --list` prints it; with `+cursor`, a worktree under `${HOME}/.cursor/worktrees` is still listed and the go path stays under `GITWT_ROOT`.
    - `test_gitwt_root_empty`: `GITWT_ROOT=` and `go` uses `${HOME}/worktrees/...`.
    - `test_gitwt_root_relative`: `GITWT_ROOT=relative/root` and `go` is non-zero and creates nothing at that relative path.
    - `test_gitwt_root_trailing_slash`: root ends with `/` and the printed path has one slash after the root directory.
    - `test_gitwt_root_spaces`: root path contains a space; `go` creates it and `done` removes it.
    - Run these cases and confirm they fail.
4. Write code and run green: `wt_worktrees_root` prints `${GITWT_ROOT}` when it is a non-empty absolute path, with one trailing slash removed unless the root is `/`; prints `${HOME}/worktrees` when `GITWT_ROOT` is unset or empty; `wt_die`s when it is set, non-empty, and not absolute. `wt_layout_prefix` and `wt_all_mains` use that value instead of `${HOME}/worktrees`. Update the file header comment. Run the new cases, then `make test`.

### 2. Document the root — prose/policy

- Files: `subcommands/git-wt/README.md`, `README.md`
- No tests: prose/policy artifact

1. In `subcommands/git-wt/README.md`, under Where Worktrees Go, state the default `~/worktrees/...` layout and that `GITWT_ROOT`, when set to an absolute path, replaces that root for every command. Say an empty value keeps the default, and a relative value is an error. Say `~` is expanded by the shell before `git wt` sees it.
2. In the root `README.md` git-wt bullet, keep the default layout and point at that section for `GITWT_ROOT`.

## Technology Validation

No new technology - validation not required

## Dependencies

- bash and git, already required
- `tests/test-git-wt.sh` and `make test`

## Challenges & Mitigations

- An exported `GITWT_ROOT` in the agent shell would retarget every existing path assertion: `run_isolated` unsets it, and the new cases set it themselves.
- `go` and `cleanup --all` read the root in different functions (`wt_layout_prefix`, `wt_all_mains`): both call `wt_worktrees_root`, and `test_gitwt_root_go_done_cleanup` runs `cleanup --all --list` from outside the repo.
- An empty `GITWT_ROOT` would build a relative path: treat empty like unset.
- A relative `GITWT_ROOT` would depend on cwd, so `go` and `cleanup --all` would disagree: `wt_die` on a non-absolute value.
- A trailing slash would print `root//owner`: strip one trailing slash, and leave `/` alone.
- A space in the root must stay quoted: cover it with `test_gitwt_root_spaces`.
- Cursor worktrees are a different root: do not send `wt_cursor_worktrees` or `wt_all_cursor_mains` through `wt_worktrees_root`; the combined test asserts they stay under `${HOME}/.cursor/worktrees`.
- Git may record a physical path when the root is a symlink: keep returning the configured path from `wt_worktrees_root` and leave the existing logical/physical match in `wt_created_worktrees` in place.

## Pre-Mortem

- The plan changes only the `go` path and `cleanup --all` still scans `~/worktrees`: already covered by the two-call-site challenge, and the combined test runs `cleanup --all --list`.
- The variable is read in the shell wrappers instead of `git-wt.bash`: the wrappers only `cd` to stdout. Read `GITWT_ROOT` inside `git-wt.bash` so `git wt` and the wrappers share one root.

## Status

- [x] Initialization complete
- [x] Test planning complete (TDD)
- [x] Implementation plan complete
- [x] Technology validation complete
- [x] Pre-Mortem complete
- [x] Preflight
- [x] Build
- [ ] QA
