---
task_id: git-wt
date: 2026-08-28
complexity_level: 3
---

# Reflection: git-wt

## Summary

`git wt go` / `git wt done` shipped as a Bash Git subcommand with the fixed `~/worktrees/<owner>/<repo>/<repo>-<branch>` layout, plus opt-in `make shell` wrappers. The build matched the plan; QA passed with advisories only.

## Requirements vs Outcome

The issue-#5 contract is in place: idempotent `go`, dirty/`--force`/`/dev/tty` `done`, main-checkout refusal, stdout/stderr split, HTTPS and scp-style owner/repo, `make shell` not in `all`, uninstall via `make clean`. Bash completion stayed deferred (issue stretch, plan pre-mortem). Two documented deviations, both environmental rather than scope changes: `git wt --help` is intercepted by git (usage is `-h`/`help` through `git wt`, `--help` on `git-wt`); idempotent `go` keys off `${path}/.git` so macOS `/var` vs `/private/var` does not look like a collision.

## Plan Accuracy

The plan's file list, TDD order, and install split were right. The HTTPS `*:*/*` trap was named before code was written and did not recur. Surprises were outside the plan's challenges list: git's `--help` interceptor, and `$HOME` under `/var/folders` being a symlink to `/private/var/folders`. Both were recoverable in the test that first hit them. Preflight's completeness catch (wire the installer test into `make test`, not merely run it once) was the only plan edit, and it was the right one.

## Creative Phase Review

No creative phase. Spec + local `wt-*` + the completions fence pattern were enough. Skipping it did not leave a design hole; the only parser fork (HTTPS) was already a known bug in the reference, not an open question.

## Build & QA Observations

Build was linear TDD per unit. The `--help` and symlink-path tests failed for real reasons after the port, not because stubs were wrong. QA (Sonnet) passed: completeness and Makefile contracts held; advisories were KISS on `wt_worktree_path`'s two-line stdout and the intentional identical bash/zsh wrappers. QA also chmod'd unrelated `git-identity`/`git-sync` files and `shell/wt.bash`; those mode bits were reverted (wrappers are sourced, not executed).

## Cross-Phase Analysis

Preflight's first FAIL (installer test not wired into `make test`) would have been a silent process miss at archive time. The dialect advisory was a wording bug, not a prompt to POSIX-rewrite installers; operator clarification during plan saved a wrong rewrite. The HTTPS bug was a planning success: naming it in challenges meant the test existed before `wt_owner_repo` was filled in.

## Insights

### Technical
- `git <subcommand> --help` never reaches the subcommand. Tests that assert on that invocation are testing git. Drive `--help` at the `git-<name>` binary on PATH.
- Do not compare `git worktree list --porcelain` paths to `$HOME`-computed paths on macOS: `/var/folders` and `/private/var/folders` are the same directory. Existence of `${layout}/.git` is a more reliable "already a worktree" check.
- URL parsers that treat `*:*/*` as scp-style will eat `https://host/owner/repo` and set owner to `//host/owner`. Last two path segments after stripping scheme and `.git` is the portable rule.

### Process
- "Run `make test`" and "add this file to the `test` recipe" are different completeness claims. Preflight should keep asking for the latter when the plan introduces a new test file.
- A local implementation is a behavior reference, not a parser to paste. The one known bug in the reference was the one that would have shipped if we had copied `wt_owner_repo` verbatim.
