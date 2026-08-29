# Project Brief

## User Story

As a maintainer, I want shunit2 in the repo and a PR check that ShellChecks `*.sh` and runs the test suite so a pull request that ships tests and code cannot merge if those tests fail.

## Use-Case(s)

### Use-Case 1

A contributor opens a PR that adds or changes POSIX `*.sh` scripts. CI ShellChecks those files and fails the PR on ShellCheck errors.

### Use-Case 2

A contributor opens a PR that includes tests and implementation. CI runs the test suite; a failing test blocks merge.

## Requirements

1. Vendor shunit2 in this repo, following the bundled approach used in `../ai-rizz`.
2. Add a GitHub Actions workflow that runs on pull requests.
3. PR CI ShellChecks `*.sh` scripts.
4. PR CI runs the test suite so shipped tests must pass before merge.
5. Do not convert existing homemade tests under `tests/` to shunit2.

## Constraints

1. ShellCheck scope is `*.sh` only, not `*.bash`.
2. Existing `make test` tests continue to run; they stay on their current harness.
3. This is a merge gate, not a change to product subcommand behavior.

## Acceptance Criteria

1. shunit2 is present in the repository and can be sourced by new tests the way ai-rizz does.
2. Opening a PR against the default branch runs ShellCheck on `*.sh` and runs tests.
3. A failing test job prevents merge of that PR (required check / job failure).
4. Existing tests still pass locally via `make test`.
