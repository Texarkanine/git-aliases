# Active Context

## Current Task: git-sync-worktrees
**Phase:** PREFLIGHT - COMPLETE (PASS WITH ADVISORY)

## What Was Done
- Planned a checkout-free `git sync`: fetch `SOURCE@{upstream}` when it exists and rebase/merge onto that ref; otherwise rebase/merge onto local source. No second worktree, no `fetch src:src`.
- Test plan: new `tests/test-git-sync.sh` (homemade POSIX, isolated HOME) covering worktree+remote, worktree+merge, primary feature checkout, no-remote, cancel, already-on-source, stash safety, not-a-repo, detached HEAD.
- Code touchpoints: `subcommands/git-sync/git-sync.bash`, `Makefile` `test` target, `subcommands/git-sync/README.md`.
- Operator constraints held: KISS-max code edits; full Niko rigor.

## Next Step
- Build: TDD the checkout-free sync path. Apply fetch-the-upstream-remote advisory; skip the confirm-prompt innovation (KISS).
