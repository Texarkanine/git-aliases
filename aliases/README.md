# Git Aliases

This directory contains various Git aliases organized by category. These aliases provide shortcuts for common Git operations.

## Available Aliases

### Add, Reset, and Clean (`add`)

| Alias     | Command             | Description                                   |
|-----------|---------------------|-----------------------------------------------|
| `aa`      | `add --all`         | Add all changes to the staging area           |
| `ap`      | `add -p`            | Add changes interactively in patches          |
| `unstage` | `reset HEAD --`     | Remove changes from the staging area          |
| `discard` | `checkout --`       | Discard changes in the working directory      |
| `cleanall`| `clean -fdx`        | Remove all untracked files and directories    |

### Diff and Viewing Changes (`diff`)

| Alias      | Command             | Description                                  |
|------------|---------------------|----------------------------------------------|
| `d`        | `diff`              | Show changes between working dir and staging |
| `ds`       | `diff --staged`     | Show changes between staging and last commit |
| `dc`       | `diff --cached`     | Same as `ds`                                |
| `wdiff`    | `diff --word-diff`  | Show word-level differences                 |

### Miscellaneous Commands (`misc`)

| Alias      | Command                      | Description                                  |
|------------|------------------------------|----------------------------------------------|
| `who`      | `shortlog -sne`              | Show commit counts by author                 |
| `short`    | `rev-parse --short HEAD`     | Show abbreviated commit hash                 |
| `root`     | `rev-parse --show-toplevel`  | Show repository root directory               |
| `info`     | `remote show origin`         | Show information about origin remote         |
| `uncommit` | `reset --soft HEAD~1`        | Undo last commit but keep changes            |
| `wipe`     | `reset --hard`               | Discard all changes                          |
| `orphan`   | `checkout --orphan`          | Create a new orphan branch                   |
| `count`    | `rev-list --count HEAD`      | Count commits on current branch              |

### Push, Pull, and Fetch (`pushpullfetch`)

| Alias      | Command             | Description                                  |
|------------|---------------------|----------------------------------------------|
| `ps`       | `push`              | Push changes to remote                       |
| `pl`       | `pull`              | Pull changes from remote                     |

### Rebase and Merge (`rebasemerge`)

| Alias      | Command              | Description                                  |
|------------|----------------------|----------------------------------------------|
| `rb`       | `rebase`             | Rebase current branch                        |
| `rbi`      | `rebase -i`          | Interactive rebase                           |
| `rbc`      | `rebase --continue`  | Continue the current rebase                  |
| `rba`      | `rebase --abort`     | Abort the current rebase                     |
| `cp`       | `cherry-pick`        | Apply changes from another commit            |

### Search Commands (`search`)

| Alias      | Command                | Description                                  |
|------------|------------------------|----------------------------------------------|
| `g`        | `grep -n`              | Search with line numbers                     |
| `find`     | `!git ls-files | grep` | Search file names                            |

### Status, Log, and Branches (`status`)

| Alias      | Command                                                | Description                                  |
|------------|--------------------------------------------------------|----------------------------------------------|
| `st`       | `status`                                               | Show the working tree status                 |
| `co`       | `checkout`                                             | Switch branches or restore files             |
| `br`       | `branch`                                               | List, create, or delete branches             |
| `ci`       | `commit`                                               | Record changes to the repository             |
| `cm`       | `commit -m`                                            | Commit with a message                        |
| `ca`       | `commit --amend`                                       | Amend the last commit                        |
| `cia`      | `commit -a --amend`                                    | Add all changes and amend the last commit    |
| `s`        | `status -sb`                                           | Show status in short format with branch info |
| `last`     | `log -1 HEAD`                                          | Show the last commit                         |
| `lg`       | `log --oneline --graph --decorate --all`               | Pretty log graph of all branches             |
| `lga`      | `log --oneline --graph --decorate --all --abbrev-commit` | Abbreviated pretty log                     |
| `lol`      | `log --graph --decorate --pretty=oneline --abbrev-commit --all` | Another log format                  |
| `l`        | `log --oneline --decorate --color`                     | Colorized oneline log                        |
| `hist`     | `log --pretty=format:"%h %ad | %s%d [%an]" --graph --date=short` | Formatted log with dates           |
| `lgn`      | `log -n $1 --oneline`                                 | Show n commits in oneline format             | 