# Progress

Add `git wt cleanup` to find and tear down worktrees that `git wt go` created (current repo, or all repos with `--all`), with `--yes`, `--force`, and `--list`; add `git wt done --yes` so forced cleanup can run without prompts.

**Complexity:** Level 2

## 2026-09-24 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Confirmed intent with operator; verified `git worktree remove` deletes ignored files, so no `--rm`.
* Decisions made
    - Level 2: single-subcommand enhancement.
    - Default scope current repo; `--all` for every repo under `~/worktrees`; `--list` prints paths.

## 2026-09-24 - PLAN - COMPLETE

* Work completed
    - Level 2 plan written to `tasks.md` (5 steps, 20 behaviors).
* Decisions made
    - Extract `wt_remove_worktree` shared by `done` and `cleanup`; `cleanup` runs it per row in a subshell.
    - Without `--force`, dirty rows are skipped (success). With `--force`, one cleanup confirmation replaces per-tree prompts.
    - `--all` discovers repos by scanning `~/worktrees` to worktree roots (slash-branch aware), deduped by main checkout.
    - `wt` wrappers forward `cleanup`; `--list` passes through uncaptured.

## 2026-09-24 - PREFLIGHT - COMPLETE

* Result: `PASS WITH ADVISORY`
* Work completed
    - Validated TDD ordering, conventions, dependency impact, conflicts, and completeness against `git-wt.bash`, both wrappers, and both test suites.
    - Struck the `test_help_flags` `cleanup` assertion (change-detector).
* Advisories
    - Wrapper `|| return` drops the cd path when cleanup partially fails; the discovery `cd` into a missing layout path aborts under `set -e` (also `prunable` entries); the parent cwd can vanish mid-loop; `done --yes` usage/header text; locked worktrees count as failures; scan bounds; compute the layout prefix once.
    - Radical: `go` records repos in a registry file so `cleanup --all` doesn't need to scan the filesystem.

## 2026-09-24 - BUILD - COMPLETE

* Work completed
    - `done --yes`; shared `wt_remove_worktree` / `wt_cwd_inside`; `cleanup` with `--all`, `--list`, `--yes`, `--force`; wrapper `cleanup` case; README and productContext.
    - 17 new git-wt tests, 6 new wrapper tests; all git-wt, git-sync, wrapper, zsh-completion, shunit2, shellcheck-runner suites pass.
* Decisions made
    - Layout-prefix matching for discovery; explicit `return 1` on remove failure because `set -e` is suspended in `if` conditions.
* Insights
    - `test-install-completions` needs a real zsh install (modules + compinit); an extracted .deb is not enough.

## 2026-09-24 - QA - COMPLETE

* Result: `FAIL (fixable)`; Build must rerun.
* Work completed
    - Semantic review of `f877ec5..HEAD` against the plan; git-wt, wrapper, and shellcheck suites re-run green.
* Findings
    - Blocking: `cleanup --all` walks stray non-worktree dirs under `~/worktrees` in full and follows symlinks; a symlink loop makes it hang (reproduced). Skip symlinks and bound the scan; add a test.
    - Advisory: duplicated `/dev/tty` confirm logic with divergent no-terminal handling; main entry not excluded explicitly in discovery; `done:` prefix in shared removal helper.

## 2026-09-24 - BUILD (QA rework) - COMPLETE

* Work completed
    - Fixed QA blocker: `wt_scan_worktree_roots` no longer follows symlinked dirs and caps depth at 8, so a stray dir with symlink loops cannot hang `cleanup --all`. Added `test_cleanup_list_all_symlink_loop` (reproduced the hang red at the 20s watchdog, then green).
    - Full suite rerun: all green except `test-install-completions`, which fails identically on unmodified HEAD with the extracted zsh (environmental).
* Decisions made
    - Declined QA advisories (shared prompt helper, explicit main-checkout skip, `done:` message prefix): untestable without environment tricks or unreachable; git already refuses to remove a main worktree.

## 2026-09-24 - QA (re-run) - COMPLETE

* Result: `FAIL (fixable)`; Build must rerun.
* Work completed
    - Reviewed the rework `f2e1bd2..HEAD` and re-checked `f877ec5..HEAD`. B1 is fixed correctly; declining the earlier advisories is accepted.
    - Ran all suites. Everything passes except the two zsh-completion suites, which fail because the extracted zsh cannot load its modules; no completion files changed.
* Findings
    - Blocking B2: the new test's watchdog leaks processes. The orphaned `sleep 20` holds suite stdout, so a piped run takes 24 s instead of 7 s, and CI pays that on every run. On the red path, `kill` misses the scan's bash subprocesses, which keep running (reproduced against the `f2e1bd2` scan).
    - Advisory: a symlinked top-level `<repo>-*` entry is still followed, though the depth cap bounds it; the depth cap (branches with 10 or more segments are missed) is not documented.

## 2026-09-24 - BUILD (QA rework 2) - COMPLETE

* Work completed
    - Replaced the leaking sh watchdog in `test_cleanup_list_all_symlink_loop` with `run_with_timeout` (python3, new session, `killpg` on timeout; python3 is already a suite dependency).
    - Verified in a scratch copy with pre-fix `git-wt.bash` (f2e1bd2): test fails with 124 at 20s, no leftover processes. Current code: whole file passes piped in 7s (was ~24s).
    - README notes the `--all` scan does not follow symlinks and covers branch names of up to nine `/`-separated parts.
* Decisions made
    - `set -m` process-group kill does not work in non-interactive dash; python session kill is portable to Linux and macOS.
    - Declined advisory: skipping a symlinked top-level `<repo>-*` entry (depth cap already bounds it).
