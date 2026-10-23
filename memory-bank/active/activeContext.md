# Active Context

## Current Task: gh account pin
**Phase:** PLAN - COMPLETE

## What Was Done

- Preflight failed fixable. The shim read is now `git config --local --get`, with a global-key test the null-global harness cannot hide.
- The resolver skips any `gh` file that contains the shim marker, so a bare `$0` cannot re-exec the shim.
- A bare `@gh-account` fails. Unset of a missing key still exits 0. Install creates the libexec directory and restores a parked file only when one exists.
- `GH_HOST` stays ambient. Exporting `github.host` would override SSH-alias translation.

## Next Step

- Preflight the revised plan. Build stays blocked until that passes.
