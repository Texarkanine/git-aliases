# Project Brief

## User Story

As a git-aliases user, I want `wt go` and `git wt go` to tab-complete existing git branch names in bash and zsh, so I can jump to an existing worktree by branch name.

## Use-Case(s)

### Use-Case 1

From a repository, type `git wt go` or `wt go` and press Tab. The shell offers branch names that already exist.

### Use-Case 2

Type a branch name that does not exist yet. Nothing is offered. The new name is typed in full, and `go` still creates the branch.

## Requirements

1. Bash completion for `git wt go <branch>` and `wt go <branch>` offers existing git branch names.
2. Zsh completion for `git wt go <branch>` and `wt go <branch>` offers existing git branch names.
3. The scripts are companion completion files for `git wt`, installed by the existing `make completions` target.

## Constraints

1. No new install target. `scripts/install-completions.bash` already copies `*-completion.bash` and `*-completion.zsh`.
2. A name that matches no existing branch has nothing to complete.
3. Scope is `go` only.

## Acceptance Criteria

1. In bash and zsh, `git wt go <Tab>` and `wt go <Tab>` list existing branch names.
2. A prefix that matches no branch completes nothing.
3. `make completions` installs the new scripts the same way it installs the `git-sync` and `git-identity` completers.

## Rework

Operator direction, 2026-11-07, after review of PR #20. Rework the branch completers. Do not archive first.

1. Bash completion must treat branch names as literal strings. `compgen -W` expands a valid name such as `feature/$USER`, and it evaluates command substitutions and backticks that git accepts in a branch name.
2. Candidates must stay the name under `refs/heads/` when a tag has the same name. `%(refname:short)` prints `heads/<name>` in that case, and `git wt go` then creates a new branch of that name.
3. An unmatched prefix after `git wt go` must not fall back to filenames. Git's completion binds `git` with `-o default`. Suppress that for the current completion attempt. Keep `wt` and `git-wt` on `complete -F`. Do not call `__git_complete`.
4. `git sync` bash completion has the same filename fallback. Suppress it there too.

The same `compgen -W` and `%(refname:short)` uses in the `git sync` completers were not part of this request. A missing trailing space after a matched `git wt go` name was not part of this request either.
