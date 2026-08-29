# Active Context

## Current Task: pr-ci-shunit2
**Phase:** PLAN - COMPLETE

## What Was Done
- Second re-plan after Preflight FAIL (fixable): added dirty-tree fixture test (`run-shellcheck.sh <dir>`), PATH-miss invokes the script not `make`, default scan is `git ls-files '*.sh'`. Kept `*.bash` out of scope. README will list `shellcheck` as a `make test` requirement.

## Next Step
- Preflight validation
