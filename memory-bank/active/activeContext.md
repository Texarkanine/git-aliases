# Active Context

## Current Task: gh shim reentry
**Phase:** BUILD - COMPLETE

## What Was Done

- `exec_real` unsets `GIT_ALIASES_GH_SHIM` before it replaces itself with the real `gh`.
- Three shim tests cover a child `gh` outside a repository, in an unpinned checkout, and in a pinned checkout.

## Next Step

- Level 1 QA.
