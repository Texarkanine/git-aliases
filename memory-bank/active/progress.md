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
