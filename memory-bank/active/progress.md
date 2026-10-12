# Progress

Compare status and the pre-hook diff as NUL-separated paths, so a hook-stripped file or directory whose path contains a space is `stripped`. Keep the classifications already in the brief.

**Complexity:** Level 1

## 2026-10-11 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Classified the approved review fixes as a Level 1 bug fix in `git wt`
* Decisions made
    - Level 1: one component, and the review already states the classification rule
* Insights
    - Findings 1 and 2 are one predicate. Finding 3 is the orphan check running before the dry run.

## 2026-10-11 - BUILD - COMPLETE

* Work completed
    - `stripped` requires every status path to be in the pre-hook diff, and the hook's tree to match `HEAD`
    - `orphan` is returned only for a result that would have been `clean` or `stripped`
    - Tests cover a dirty submodule, that case beside a hook-stripped file, CRLF under `autocrlf=input` and `text=auto`, an edited orphaned HEAD, and hook-stripped files on an orphaned HEAD
* Decisions made
    - An untracked directory in status is covered when a diff path is inside it, so `?? local/` still counts as hook-stripped
* Insights
    - `protocol.file.allow` is ignored in local config; the submodule fixture passes `-c protocol.file.allow=always`
    - `make test` stops at `test-wt-wrappers.sh` on this machine because `zsh` is not installed. That failure is unchanged. `git wt` tests passed.

## 2026-10-11 - QA - COMPLETE (PASS)

* Work completed
    - Reviewed the 079f569..HEAD diff against projectbrief.md requirements and acceptance criteria
    - Ran the full `git-wt` suite: all tests passed, including the 6 new classification tests
    - Ran ShellCheck and `bash -n` on `git-wt.bash`: syntax OK, only pre-existing SC1007 warnings on untouched lines
* Decisions made
    - PASS: no blocking findings; advisories only (porcelain rename/quote paths fail safe to `dirty`, `after=""` init redundant but harmless)
* Insights
    - `wt_status_covered` errs toward `dirty` on anything it cannot match, which is the safe direction for a removal gate

## 2026-10-12 - REWORK - INITIATED

* Work completed
    - Operator chose rework over archive
* Decisions made
    - Fix the quoted-path hole in `wt_status_covered`, then push the branch
* Insights
    - [PR review](https://github.com/Texarkanine/git-aliases/pull/17#discussion_r4243891806): porcelain quotes `?? "my rule.md"` and `?? "local rules/"`, `git diff-tree --name-only` does not, and a slash inside the quotes is never stripped. Tests only plant `local/rule.md`. The worktree stays dirty.

## 2026-10-12 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Classified the quoted-path rework as a Level 1 bug fix in `git wt`
* Decisions made
    - Level 1: one function, and the review already states the comparison
* Insights
    - Keeping the worktree is the bug. Hook-stripped paths with a space are never removed.

## 2026-10-12 - BUILD - COMPLETE

* Work completed
    - `wt_status_covered` reads `git status -z` and `git diff-tree -z --name-only`
    - A trailing slash marks a directory, including `local rules/`
    - A new test plants `my rule.md` and `local rules/rule.md` and expects cleanup to remove the worktree
* Decisions made
    - A rename or copy is not covered, so the NUL parser cannot treat the second path as a new status record
* Insights
    - Bash variables cannot hold NUL, so the two streams are temp files
    - `make test` still stops at `test-wt-wrappers.sh` because `zsh` is not installed. `git wt` tests passed. ShellCheck on `git-wt.bash` reports only the pre-existing SC1007 warnings
