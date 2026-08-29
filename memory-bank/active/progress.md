# Progress

Vendor shunit2 (ai-rizz-style) and add a pull-request GitHub Action that ShellChecks `*.sh` and runs the test suite so PRs that ship tests cannot merge when those tests fail. Existing homemade tests are not converted.

**Complexity:** Level 2

## 2026-08-28 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Confirmed intent: vendor shunit2, PR CI for `*.sh` ShellCheck and test run, no conversion of existing tests
    - Classified as Level 2
* Decisions made
    - Level 2: small self-contained enhancement (CI + test harness), not L3 architecture
* Insights
    - `make test` already runs four homemade POSIX suites; CI should invoke that, not replace it

## 2026-08-28 - PLAN - COMPLETE

* Work completed
    - Wrote Level 2 plan in `tasks.md` (smoke test, shellcheck target, PR workflow, docs)
    - Validated shunit2 PoC (1 test OK) and ShellCheck `--severity=error` on current `*.sh`
* Decisions made
    - Match ai-rizz error severity so existing warning-level findings do not block
    - CI calls `make shellcheck` / `make test` rather than scanning `*.bash` with ludeeus
    - Do not convert existing homemade tests
* Insights
    - `git wt done` in tests trips SC1010 if severity includes warnings; out of scope to rewrite

## 2026-08-28 - PREFLIGHT - COMPLETE

* Work completed
    - Ran Preflight against `tasks.md`/`projectbrief.md`/`systemPatterns.md`/`techContext.md`; no creative docs exist (none required at Level 2)
    - Cross-checked plan against `../ai-rizz` (shunit2 sourcing pattern, PR workflow, ShellCheck severity) and GitHub's `runner-images` ShellCheck version table
    - Wrote `.preflight-status`: first line `FAIL (fixable)`
* Decisions made
    - TDD Plan Encoding fails for Unit 2 (`make shellcheck`): Test Plan lists two concrete behaviors (`[ShellCheck]`, `[ShellCheck miss]`) but the Implementation Plan explicitly skips a test suite for them ("none as a suite") — not covered by the change-detector carve-out, since these assert runtime behavior, not document content
* Insights
    - `ubuntu-latest` (24.04) ships ShellCheck 0.9.0 preinstalled, so the plan's "install ShellCheck if needed" in the PR workflow job is a resolvable ambiguity, not a real gap — flagged advisory

## 2026-08-28 - PLAN - COMPLETE

* Work completed
    - Re-planned Unit 2: `tests/test-shellcheck.sh` (homemade) covers current-tree `make shellcheck` and PATH-miss; implementation is `scripts/run-shellcheck.sh` invoked by Makefile
    - Resolved Unit 3: no ShellCheck install step on `ubuntu-latest`
    - Left `make ci` out of scope
* Decisions made
    - PATH-miss test uses a temp `bin/` with only `make` linked, because Ubuntu ships `shellcheck` in the same directory as `make`
    - `run-shellcheck.sh` uses `/usr/bin/find` so find still works when `/usr/bin` is not on PATH
* Insights
    - Preflight FAIL (fixable) was a real TDD encoding gap, not a docs nit

## 2026-08-28 - PREFLIGHT - COMPLETE

* Work completed
    - Second Preflight run against the re-planned `tasks.md`; wrote `.preflight-status` with first line `FAIL (fixable)`
    - Confirmed the prior FAIL is resolved: Unit 2 now has test steps ordered before implementation, Unit 3's install conditional is gone
    - Re-verified toolchain facts independently: `../ai-rizz/shunit2` present, ShellCheck 0.11.0, the eight `*.sh` files exit 0 at `--severity=error` and 1 at default severity, baseline `make test` green
    - Reproduced the Unit 2 PATH-miss test in a scratch dir and confirmed it fails for the wrong reason
* Decisions made
    - FAIL (fixable) on Completeness, not TDD encoding: no planned test proves the gate catches a ShellCheck error, so a `run-shellcheck.sh` that never invokes shellcheck passes every planned assertion
    - Second fixable: the PATH-miss test's temp `bin/` carries only `make`, so the recipe dies on `chmod: No such file or directory` and stderr never contains `shellcheck`
    - No in-phase edits to `tasks.md` — there was no change-detector to strike and no test/code step order to swap
* Insights
    - Any error-severity fixture must live outside the repo tree, or the whole-tree scan in the current-tree test will find it and stay red
    - `/usr/bin/find` was hardcoded to survive a stripped `PATH`, but the script exits on the missing-tool branch before it ever reaches `find`
    - The `*.bash` tree already passes at `--severity=error`, so the `*.sh`-only scope leaves every shipped subcommand ungated for no present benefit

## 2026-08-28 - PLAN - COMPLETE

* Work completed
    - Added dirty-tree behavior: `run-shellcheck.sh <dir>` + `mktemp` fixture with unterminated `if`
    - PATH-miss now invokes the script directly; default scan is `git ls-files '*.sh'`
    - README Requirements will include `shellcheck`
* Decisions made
    - Declined `*.bash` expansion: operator confirmed `*.sh` only
    - Did not add `make ci`
* Insights
    - Completeness FAIL was right: pass+miss without a dirty fixture does not prove ShellCheck runs
