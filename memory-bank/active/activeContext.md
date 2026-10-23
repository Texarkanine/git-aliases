# Active Context

## Current Task: gh account pin
**Phase:** PREFLIGHT - COMPLETE (PASS WITH ADVISORY)

## What Was Done

- Second preflight failed fixable. A pin with no `@gh-host` stored the token only in `GH_TOKEN`, and a GitHub Enterprise Server command would ignore that and use the active account.
- A successful lookup now exports the same token as both `GH_TOKEN` and `GH_ENTERPRISE_TOKEN`. `GH_HOST` stays ambient.
- A bare or empty `@gh-account` or `@gh-host` exits before any config write. The repo probe discards `git rev-parse` output. Install asserts the executable bit.
- Preflight passed with advisories. The status file is `memory-bank/active/.preflight-status`.

## Next Step

- Operator runs `/niko-build`. Advisories stay in the status file and do not change the numbered steps.
