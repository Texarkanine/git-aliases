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
