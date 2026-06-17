# Project Brief

## User Story

As a git-aliases user on macOS (BSD sed), I want alias installation to preserve alias names and values exactly so that shortcuts like `git st` and `git ci` work the same as on Linux.

## Use-Case(s)

### Use-Case 1: Install aliases on macOS

Running `make aliases` on macOS must install `st = status`, `ci = commit`, `co = checkout`, etc. without stripping trailing `t` characters from names or values.

### Use-Case 2: Install aliases on Linux

Existing Linux behavior must remain correct after the fix.

## Requirements

1. Replace the non-portable `[ \t]` sed character class in `scripts/install-aliases.sh` with a POSIX-safe whitespace trim.
2. Add automated tests that reproduce the BSD sed corruption cases documented in `memory-bank/active/bsd-sed.md`.
3. Ensure trim behavior works for alias names with trailing spaces (e.g. `st ` must become `st`, not `s`).

## Constraints

1. Whitespace trimming must use POSIX-defined character classes or shell constructs that behave identically on BSD and GNU sed.
2. Follow existing project shell style conventions.

## Acceptance Criteria

1. Trimming `checkout`, `commit`, `short`, `last`, and `hist` leaves them unchanged.
2. Trimming `st ` (trailing space) yields `st`, not `s`.
3. Trimming ` status` (leading space) yields `status`.
4. All new tests pass on the current platform.
5. `make test` runs the trim tests.
