# Task: pr-ci-shunit2

* Task ID: pr-ci-shunit2
* Complexity: Level 2
* Type: simple enhancement

Vendor shunit2 at the repo root (same bundled file as `../ai-rizz`) and add a pull-request GitHub Action that ShellChecks `*.sh` at error severity and runs `make test`, so a PR that ships tests shows red CI if those tests fail. Existing homemade tests stay on their current harness. Required GitHub checks / branch rulesets are out of scope.

## Test Plan (TDD)

### Behaviors to Verify

- [Smoke] `tests/test-shunit2-smoke.sh` sources repo-root `shunit2` and a passing assertion → suite prints OK and exits 0
- [Runner] `make test` runs the smoke file in addition to the four existing homemade suites → a failing smoke assertion fails `make test`
- [ShellCheck] `make shellcheck` / `scripts/run-shellcheck.sh` with no args scans tracked `*.sh` in this repo at `--severity=error` (not `*.bash`, not extensionless `shunit2`) → current tree exits 0
- [ShellCheck dirty] `scripts/run-shellcheck.sh <dir>` on a temp directory containing a `*.sh` with an error-severity finding (unterminated `if`) → non-zero exit
- [ShellCheck miss] `scripts/run-shellcheck.sh` with `PATH` empty of `shellcheck` (script invoked directly, not via `make`) → non-zero exit and a message that names `shellcheck`
- [CI] a `pull_request` against `main` runs ShellCheck and tests → a failing job is a red check on the PR (whether that check is required to merge is operator choice, not this task)

Edge cases:

- [Dialect] `*.bash` files are not passed to ShellCheck → `git-wt.bash` and other bash subcommands are out of this gate
- [Severity] existing `*.sh` have warning/info findings (`SC1007`, `SC1010`, `SC2031`) → they must not fail the gate; do not rewrite those files to silence warnings
- [Regression] existing homemade suites still pass under `make test` unchanged (except the Makefile listing the new test files)

### Test Infrastructure

- Framework: homemade POSIX `assert_*` / `fail` suites today; **shunit2** only for the smoke file (ai-rizz pattern: source at end of file). `tests/test-shellcheck.sh` stays homemade so expected-failure PATH cases do not fight shunit2's last-command-as-status rule.
- Test location: `tests/`
- Conventions: `tests/test-<name>.sh`, shebang `#!/bin/sh`; `Makefile` `test` recipe chmod+x and lists files explicitly (no `find` runner)
- New test files: `tests/test-shunit2-smoke.sh`, `tests/test-shellcheck.sh`

## Implementation Plan

### 1. shunit2 smoke and `make test` — executable

- Files: `shunit2`, `tests/test-shunit2-smoke.sh`, `Makefile`

1. Stub tests: `tests/test-shunit2-smoke.sh` with empty `test_shunit2_equals`; resolve `SCRIPT_DIR`/`REPO_DIR` like `tests/test-trim.sh`; trailing source of `"${REPO_DIR}/shunit2"`
2. Stub interface: none (shunit2 is a vendored script, not an API we author)
3. Write tests and run red: `assertEquals` a known pair; run the file without `shunit2` present → fail
4. Write code and run green: copy `../ai-rizz/shunit2` to repo-root `shunit2` (keep the name extensionless); add `tests/test-shunit2-smoke.sh` to the Makefile `test` recipe (chmod + execute). Confirm `make test` still runs trim, git-wt, wrappers, and install-shell-integration.

### 2. `make shellcheck` — executable

- Files: `scripts/run-shellcheck.sh`, `tests/test-shellcheck.sh`, `Makefile`

1. Stub tests: `tests/test-shellcheck.sh` with empty `test_shellcheck_current_tree`, `test_shellcheck_dirty_tree`, and `test_shellcheck_missing_from_path` (homemade `fail` / exit-code checks, same style as `tests/test-trim.sh`)
2. Stub interface: `scripts/run-shellcheck.sh` with `#!/bin/sh` and an empty body (or `exit 1`); Makefile `.PHONY: shellcheck` recipe that chmod+x and runs that script with no args
3. Write tests and run red: (a) `make shellcheck` from the repo root exits 0; (b) `scripts/run-shellcheck.sh <tmpdir>` where `<tmpdir>` holds a `*.sh` with an unterminated `if` (error-severity) exits non-zero — fixture must be outside the repo so (a) stays green; (c) `env PATH=/usr/bin/false-dir ./scripts/run-shellcheck.sh` (empty dir only; invoke the script, not `make`) exits non-zero and stderr contains `shellcheck`. Do not assert on Makefile source text.
4. Write code and run green: `command -v shellcheck` first; on miss print that `shellcheck` is required and exit non-zero. With no args, scan `git ls-files '*.sh'` from the repo root (no `find`, no `/usr/bin/find`). With one directory argument, ShellCheck `*.sh` under that directory only (the dirty-fixture path). Always `--severity=error`, never `--shell=sh`. Makefile `shellcheck` invokes the script with no args. Add `tests/test-shellcheck.sh` to the `test` recipe. Do not add a `make ci` umbrella target. Do not scan `*.bash` (operator-confirmed scope).

### 3. PR workflow — prose/policy

- Files: `.github/workflows/pr.yaml`
- No tests: prose/policy artifact (purpose-built CI gate; do not write a change-detector on YAML)

1. Add `on: pull_request` for branch `main`
2. Job `shellcheck`: checkout, then `make shellcheck`. Do **not** apt-install ShellCheck: `ubuntu-latest` (24.04) already ships ShellCheck 0.9.0
3. Job `tests`: checkout, `make test`
4. Do not add docs jobs, push-to-main jobs, or ShellCheck of `*.bash`

### 4. Contributor docs and tech context — prose/policy

- Files: `README.md`, `memory-bank/techContext.md`
- No tests: prose/policy artifact

1. README: short Testing section — `make test`, `make shellcheck`, note that PRs run those jobs
2. README Requirements: add `shellcheck` because `make test` will run `test-shellcheck.sh`
3. `techContext.md` Testing Process: shunit2 is bundled at repo root; `make test` / `make shellcheck`; PR workflow path

## Technology Validation

- **shunit2**: copied from `../ai-rizz/shunit2` (header: Kate Ward, Apache-2.0, `SHUNIT_VERSION='2.1.9pre'`). PoC in a temp dir: one `assertEquals 1 1` test sourced the file → `Ran 1 test. / OK`, exit 0.
- **ShellCheck**: Homebrew 0.11.0 on this machine. Current `*.sh` tree is **fail** at default severity (warnings) and **pass** at `--severity=error` (same setting as ai-rizz `ludeeus/action-shellcheck` `severity: error`).
- **CI**: new GitHub Actions workflow. `ubuntu-latest` already includes ShellCheck; jobs run `make shellcheck` and `make test` so `*.bash` is not scanned.

## Dependencies

- Vendored `shunit2` (no package manager)
- `shellcheck` on the CI runner (and locally for `make shellcheck`)
- Existing `make test` prerequisites: `git`, `bash`, `python3` (git-wt PTY helper)

## Challenges & Mitigations

- **Existing `*.sh` fail default ShellCheck**: use `--severity=error`; do not "fix" git-wt tests for `SC1010` (`git wt done`) or `CDPATH=` spacing as part of this task
- **New test file omitted from Makefile**: put each new `tests/test-*.sh` on the `test` recipe in the same unit that adds the file (git-wt preflight lesson)
- **A no-op script would pass pass/miss tests**: dirty-tree test against a temp dir is required so the gate must actually invoke ShellCheck
- **`make` + stripped PATH dies on `chmod`**: missing-tool test runs `scripts/run-shellcheck.sh` directly
- **Dirty fixture inside the repo**: would fail the current-tree scan forever; fixture is `mktemp -d` only
- **`*.bash` advisory**: declined — projectbrief constraint 1 is `*.sh` only (operator confirmed)
- **GitHub "required" checks**: out of scope; red CI on the PR is enough (operator 2026-08-28)
- **git-wt tests in Ubuntu CI**: they isolate `HOME`/`PATH`; if they fail on Actions, fix the environment in the workflow (git identity, etc.) — do not skip the suite
- **Naming `shunit2.sh`**: would pull the vendor file into ShellCheck; keep the ai-rizz name `shunit2`

## Pre-Mortem

- **Gate is so strict the first PR is red on warnings**: already covered by Challenge 1 (`--severity=error`)
- **shunit2 is in the tree but CI never runs a shunit2 test**: already covered by Challenge 2 (Makefile wiring + smoke file)
- **Operator thinks merge is blocked by YAML**: declined — red checks only; do not document rulesets
- **CI ShellChecks `*.bash` because we copied ai-rizz's action verbatim**: plan uses `make shellcheck` (`*.sh` only), not `ludeeus` with `scandir: '.'`
- **Gate never calls ShellCheck but still looks green**: already covered by dirty-tree behavior
- **PATH-miss test stays red because `make` cannot find `chmod`**: already covered (invoke the script directly)

## Status

- [x] Initialization complete
- [x] Test planning complete (TDD)
- [x] Implementation plan complete
- [x] Technology validation complete
- [x] Pre-Mortem complete
- [x] Preflight
- [x] Build
- [ ] QA
