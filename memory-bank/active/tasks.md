# Current Task: Fix stripped and orphan classification

**Complexity:** Level 1

## Fix

- What broke: a scratch tree that matched `HEAD` was `stripped`, including a change `git add` does not record. `orphan` was returned before the dry run, so an unstaged edit on an orphaned HEAD was described as only commits on no branch.
- Why: matching `HEAD` did not require every status path to be in the pre-hook diff, and the orphan check ignored a non-empty status.
- What changed: `stripped` only when every status path is in that diff and the hook then matches `HEAD`. `orphan` only when the result would have been `clean` or `stripped`.
- Files: `subcommands/git-wt/git-wt.bash`, `subcommands/git-wt/README.md`, `tests/test-git-wt.sh`
