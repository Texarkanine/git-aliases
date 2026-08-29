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
