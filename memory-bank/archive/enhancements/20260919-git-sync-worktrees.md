---
task_id: git-sync-worktrees
complexity_level: 2
date: 2026-09-19
status: completed
---

# TASK ARCHIVE: git-sync-worktrees

## SUMMARY

`git sync` no longer checks out the source branch. It fetches `SOURCE@{upstream}` from that branch's remote and rebases or merges onto the remote-tracking ref (or the local source if there is no upstream). The same path works from a linked worktree and from the primary checkout. Shipped on [PR #10](https://github.com/Texarkanine/git-aliases/pull/10).

## REQUIREMENTS

1. Do not check out the source branch.
2. One command path for a worktree and for the primary checkout.
3. Keep stash, confirm, rebase, and merge behavior.
4. Keep the code change small. Full Niko rigor (not hackathon).

Accepted tradeoff: unpushed commits that exist only on a source branch checked out elsewhere are not included. Local source is not advanced.

## IMPLEMENTATION

Replaced checkout + pull + checkout-back in `subcommands/git-sync/git-sync.bash` with: resolve `SOURCE@{upstream}`, `git fetch` that remote, rebase or merge onto the upstream (else local source). Fetched the upstream's own remote (preflight advisory). Did not put the onto-ref in the confirm prompt (KISS).

Key files: `subcommands/git-sync/git-sync.bash`, `tests/test-git-sync.sh`, `Makefile`, `subcommands/git-sync/README.md`.

## TESTING

New homemade POSIX suite `tests/test-git-sync.sh` (9 cases): worktree+remote rebase and merge, primary feature+remote, no-remote local source, cancel, already on source, stash safety, not a repo, detached HEAD. Worktree cases went red on `fatal: 'main' is already used by worktree`, then green. `make test` and `make shellcheck` passed. `/niko-qa` PASS.

PR #10 review (CodeRabbit narrow-fetch, Llama local-source tradeoff, Llama untested fetch-fail): dismissed with acknowledgment. No code change.

## LESSONS LEARNED

- `git fetch origin main:main` fails for the same reason as `git checkout main` when another worktree holds `main`. Updating a local branch without checkout is not a worktree workaround.
- A first behavioral suite mixes red proofs with characterization. Name which cases must go red. The primary-refresh case passed on the old code because checkout was available there.
- The checkout-pull-checkout loop was never needed for rebase or merge. Checkout-free is the design you would have written from the start: stash, fetch the source upstream, rebase or merge onto that ref.

## PROCESS IMPROVEMENTS

When adding the first suite for a command, list the cases that must fail on current code. Do not treat "all new tests fail" as the bar.

## TECHNICAL IMPROVEMENTS

`make shellcheck` still scans only `*.sh`, so `git-sync.bash` is never linted. Pre-existing repo-wide gap. Not opened by this task.

## NEXT STEPS

None for this change. Reinstall with `make subcommands` (or default `make`) to pick up `git-sync`. Archive of `memory-bank/active/` is this file; the ephemeral bank was cleared.
