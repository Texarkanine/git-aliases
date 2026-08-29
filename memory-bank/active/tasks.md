# Task: git-wt-done-current

* Task ID: git-wt-done-current
* Complexity: Level 2
* Type: simple enhancement

`git wt done` with no positional name removes the linked worktree that contains cwd (any linked worktree, not only `git wt go` paths). Named `done`, dirty/`--force`, and the optional `wt()` wrapper stay as they are.

## Test Plan (TDD)

### Behaviors to Verify

- Nameless `done` inside a `git wt go` worktree: `cd` into that worktree, `git wt done` → worktree removed, main path on stdout, branch left in place
- Nameless `done` from a subdirectory: `cd` into a nested dir of a linked worktree, `git wt done` → same as above
- Nameless `done` on a foreign worktree: `git worktree add` at a path outside `~/worktrees/...`, `cd` there, `git wt done` → that path is removed, main path on stdout
- Nameless `done` from main: `git wt done` in the main checkout → non-zero, main still present, error refuses the main checkout (not "branch name required")
- Nameless dirty without `--force`: dirty linked worktree, `git wt done` → non-zero, worktree remains, stderr mentions `--force`
- Nameless `--force` on dirty: dirty linked worktree, `git wt done --force` with tty `y` → worktree removed
- Named `done` still selects by branch: from main, `git wt done <name>` → still removes that branch's worktree even when cwd is not inside it
- Named `done` on a foreign worktree: `git worktree add` at a path outside `~/worktrees/...`, then from main `git wt done <name>` → that path is removed, stdout empty
- `go` still requires a name: `git wt go` with no args → non-zero (existing `test_missing_name` split or kept)

### Test Infrastructure

- Framework: POSIX `sh` integration tests (`set -eu`), isolated `HOME`/`PATH`, real `git worktree`
- Test location: `tests/test-git-wt.sh` (runner: `make test` / `tests/run.sh` as today)
- Conventions: `test_*` functions, `make_repo` / `invoke` / `run_isolated` / `run_with_tty`; `run_one` in `main`
- New test files: none

## Implementation Plan

### 1. Infer current worktree in `cmd_done` — executable

- Files: `tests/test-git-wt.sh`, `subcommands/git-wt/git-wt.bash`

1. Stub tests: add empty `test_done_no_name_inside`, `test_done_no_name_subdirectory`, `test_done_no_name_foreign_worktree`, `test_done_named_foreign_worktree`, `test_done_no_name_from_main`, `test_done_no_name_dirty_without_force`, `test_done_no_name_force_yes` in `tests/test-git-wt.sh`; register them in `main`; keep `test_missing_name` covering `git wt go` with no args (move the nameless-`done`-from-main assertion into `test_done_no_name_from_main` so the error contract is explicit)
2. Stub interface: add `wt_worktree_containing_cwd` in `git-wt.bash` (porcelain path of the listed worktree that contains physical cwd, or empty); leave `cmd_done` requiring a name until tests are red for the nameless cases
3. Write tests and run red: implement the stubbed cases (foreign trees via `git worktree add` at a temp path, not `git wt go`); run `tests/test-git-wt.sh`; nameless cases fail; `test_done_named_foreign_worktree` may already pass because named lookup is porcelain-by-branch — keep it as the regression net for requirement 4
4. Write code and run green: `cmd_done` treats a missing positional as "use `wt_worktree_containing_cwd`"; if that path is empty or equals `wt_main_worktree`, `wt_die` refusing the main checkout (or not in a linked worktree); reuse existing dirty/`--force`/stdout-if-`in_wt` logic on the resolved path. Compare paths with `pwd -P` (same as today's `in_wt` check). Run `tests/test-git-wt.sh` then `make test`

### 2. Usage and README — prose/policy

- Files: `subcommands/git-wt/git-wt.bash` (`usage` + file header), `subcommands/git-wt/README.md`, `shell/wt.bash`, `shell/wt.zsh`
- No tests: prose/policy artifact

1. Change usage to `done [name] [--force]` and document that omitting `name` means the worktree containing cwd
2. Add a nameless example (`git wt done` / `wt done`) and note that any linked worktree counts
3. Update the README flowchart so `done` can enter without a name

## Technology Validation

No new technology - validation not required

## Dependencies

- Existing `git worktree list --porcelain`, `git worktree remove`, `pwd -P`
- Existing test helpers in `tests/test-git-wt.sh`

## Challenges & Mitigations

- macOS `/var` vs `/private/var`: match cwd to a porcelain worktree using `pwd -P`, same as the current `in_wt` block; do not parse porcelain with `awk $2`
- Nameless `done` from main must keep failing: dedicated `test_done_no_name_from_main`; do not loosen `test_missing_name` into a false pass
- Named `done` from a different cwd must not start using cwd: only call `wt_worktree_containing_cwd` when the positional name is absent; `test_done_named_foreign_worktree` plus existing named tests stay the regression net

## Pre-Mortem

- Infer by current branch name instead of the worktree that contains cwd: would miss detached HEAD and any path `git wt go` did not create if lookup went through `wt_worktree_path`. Plan response: resolve a porcelain *path* from cwd, then `git worktree remove` that path (already covered by Challenge 1 and the foreign-worktree test)
- Treat wrapper `cd` as in-scope and retarget tests at `shell/wt.*`: operator cut that. Plan response: git-wt stdout-on-inside is the contract `wt()` already cds on; no wrapper mock changes
- Leave usage saying `done <name>` required: users still think a name is mandatory. Plan response: step 2 updates usage/README/wrapper help together

## Status

- [x] Initialization complete
- [x] Test planning complete (TDD)
- [x] Implementation plan complete
- [x] Technology validation complete
- [x] Pre-Mortem complete
- [ ] Preflight (re-run after named foreign-worktree test added)
- [ ] Build
- [ ] QA
