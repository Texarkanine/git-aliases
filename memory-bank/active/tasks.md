# Current Task: Fix stripped and orphan classification

**Complexity:** Level 1

## Fix

- What broke: a scratch tree that matched `HEAD` was `stripped`, including a change `git add` does not record. `orphan` was returned before the dry run, so an unstaged edit on an orphaned HEAD was described as only commits on no branch.
- Why: matching `HEAD` did not require every status path to be in the pre-hook diff, and the orphan check ignored a non-empty status.
- What changed: `stripped` only when every status path is in that diff and the hook then matches `HEAD`. `orphan` only when the result would have been `clean` or `stripped`.
- Files: `subcommands/git-wt/git-wt.bash`, `subcommands/git-wt/README.md`, `tests/test-git-wt.sh`

## QA Result: PASS

- Full `git-wt` suite passed (`All git-wt tests passed`), including the 6 new tests.
- ShellCheck: no new warnings (only pre-existing SC1007 `CDPATH= cd` notices on untouched lines).
- No KISS/DRY/YAGNI/completeness/regression/integrity/documentation blockers. Advisories only: porcelain rename/quote edge cases fail safe to `dirty`; `after=""` init is redundant but harmless.
