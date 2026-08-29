---
task_id: pr-ci-shunit2
date: 2026-08-28
complexity_level: 2
---

# Reflection: pr-ci-shunit2

## Summary

Vendored shunit2, added `make shellcheck` for tracked `*.sh`, and a PR workflow that runs ShellCheck and `make test`. That succeeded. Required GitHub merge checks were correctly left out after the operator called them overengineering.

## Requirements vs Outcome

Delivered: bundled shunit2, smoke test on `make test`, ShellCheck of `*.sh` at error severity, PR jobs that go red on failure, existing homemade tests unchanged. Dropped: documenting or configuring branch protection / required checks. No product subcommand changes.

## Plan Accuracy

The file list was right. Preflight was right to demand a dirty-tree fixture and a PATH-miss test that invokes the script, not `make`. It was wrong to treat "cannot merge" as a GitHub ruleset requirement; that cost a re-plan loop. The PATH-miss-via-make design failed for `chmod` before it could fail for `shellcheck`.

## Build & QA Observations

Build was straightforward once the plan settled. QA passed with no rework. Local `make shellcheck` and `make test` were green.

## Insights

### Technical
- A stub that always exits 1 cannot make a "must fail on bad input" test go red; that test only proves the scanner runs once the happy path can pass.
- Stripping PATH around `make` hides `chmod` first; test the script.

### Process
- "CI red on the PR" is not "required to merge." Do not schedule GitHub ruleset docs unless the operator asks for a merge lock.

### Million-Dollar Question

If PR CI had been assumed from day one, `make test` would already be the contract and shunit2 would have arrived with the first new suite. The extra surface (`run-shellcheck.sh`, smoke test, workflow wrapping those targets) is still the right shape for this repo: one local command pair, CI calls the same pair.
