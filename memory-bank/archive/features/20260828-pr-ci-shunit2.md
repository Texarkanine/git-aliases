---
task_id: pr-ci-shunit2
complexity_level: 2
date: 2026-08-28
status: completed
---

# TASK ARCHIVE: pr-ci-shunit2

## SUMMARY

Added bundled shunit2, `make shellcheck` for tracked `*.sh` (error severity), and a pull-request GitHub Action that runs ShellCheck and `make test` so failing tests show as red checks. Existing homemade tests were not converted. Required GitHub status checks / branch rulesets were out of scope. Shipped on [PR #7](https://github.com/Texarkanine/git-aliases/pull/7).

## REQUIREMENTS

1. Vendor shunit2 (ai-rizz-style, extensionless repo-root file).
2. PR workflow on `main`: ShellCheck `*.sh`, run the test suite.
3. Red CI on failure; do not convert homemade `tests/` suites; do not scan `*.bash`.
4. Do not document or configure GitHub required checks (operator: overengineering).

## IMPLEMENTATION

- `shunit2` copied from `../ai-rizz`; `tests/test-shunit2-smoke.sh` sources it; listed in the Makefile `test` recipe.
- `scripts/run-shellcheck.sh`: `command -v shellcheck` then `git ls-files '*.sh'` (or `*.sh` under an optional directory). Makefile `shellcheck` wraps that. `tests/test-shellcheck.sh` covers clean tree, dirty temp fixture, and missing-tool PATH.
- `.github/workflows/pr.yaml`: `make shellcheck` and `make test`. First Tests run failed on `ubuntu-latest` (`FAIL: zsh not found` from `test-wt-wrappers.sh`); the job now installs zsh. README lists `shellcheck` and `zsh` as `make test` needs.

## TESTING

Local `make shellcheck` and full `make test` were green at QA. `/niko-qa` PASS. First PR Tests job failed without zsh; fix pushed as `2de791d`.

## LESSONS LEARNED

- A stub that always exits 1 cannot turn a “must fail on bad input” test red; that assertion only proves the scanner runs after the happy path can pass.
- Strip PATH around the script, not `make` (`chmod` disappears first).
- “CI red on the PR” is not “required to merge.” Do not schedule GitHub ruleset docs unless asked.

## PROCESS IMPROVEMENTS

Preflight completeness should not invent merge-protection from a request for red checks. Dirty-tree and PATH-miss encodings were worth the re-plans.

## TECHNICAL IMPROVEMENTS

`*.bash` product scripts are still outside this ShellCheck gate (operator-confirmed `*.sh` only). `ubuntu-latest` does not include zsh.

## NEXT STEPS

None required. Optional: bump `actions/checkout@v4` (Node 20 deprecation warning), or mark the two jobs required on `main` if a merge lock is wanted later.
