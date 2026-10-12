# Current Task: Quote-safe status path coverage

**Complexity:** Level 1

## Fix

- What broke: a hook-stripped path with a space stayed dirty, so cleanup kept the worktree.
- Why: `git status --porcelain` quotes those paths and leaves a directory slash inside the quotes. `git diff-tree --name-only` does not quote them. The tests only planted `local/rule.md`.
- What changed: `wt_status_covered` compares `git status -z` with `git diff-tree -z --name-only`, and treats a trailing slash as a directory.
- Files: `subcommands/git-wt/git-wt.bash`, `tests/test-git-wt.sh`

## QA

- Result: PASS
- Blocking findings: None.
- Verified the implementation against the rework requirements and acceptance criteria.
- `./tests/test-git-wt.sh` passed. The full suite reached the unchanged environment blocker: zsh is not installed.
