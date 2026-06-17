# Tasks: Fix BSD sed alias trim bug

## Checklist

- [x] Extract POSIX-safe trim helper
- [x] Add failing tests for BSD sed corruption cases
- [x] Update `install-aliases.sh` to use trim helper
- [x] Add `make test` target
- [x] Run full test suite
- [x] QA validation

## Build Summary

**Root cause:** `sed 's/[ \t]*$//'` treats `\t` as literal `t` on BSD sed, stripping trailing `t` from alias names/values.

**Fix:** Extracted `trim_whitespace()` to `scripts/lib/trim.sh` using POSIX `[[:space:]]` character class. Updated `install-aliases.sh` to source and use it.

**Files changed:**
- `scripts/lib/trim.sh` (new)
- `scripts/install-aliases.sh`
- `tests/test-trim.sh` (new)
- `Makefile` (added `test` target)

## QA Results

- PASS: Fix is minimal and targeted; no scope creep
- PASS: Tests reproduce documented BSD corruption cases
- PASS: `techContext.md` updated to reflect new test target
