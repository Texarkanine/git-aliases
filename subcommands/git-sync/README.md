# git-sync

A Git subcommand to synchronize your current branch with another branch, via rebase or merge.

## Overview

`git-sync` makes it easy to keep your feature branches up to date with the default branch (typically `main`). It provides two synchronization methods:

1. **Rebase** (default): Rebases your current branch on top of the updated default branch
2. **Merge**: Merges the updated default branch into your current branch

The command handles stashing any uncommitted changes during the sync process and automatically restores them upon completion.

## Usage

```bash
git sync [options] [source-branch]
```

### Options

```
-m, --merge           Use merge instead of rebase
-h, --help            Show this help message
```

### Arguments

```
source-branch         Specify source branch to sync with (default: main)
```

## Examples

### Rebase Current Branch onto Updated Main

```bash
# Update main and rebase current branch on top of it
git sync
# or explicitly specify main
git sync main
```

### Merge Updated Main into Current Branch

```bash
# Update main and merge it into current branch
git sync --merge
```

### Use a Different Source Branch

```bash
# Rebase current branch onto updated develop branch
git sync develop
```

```bash
# Merge updated release branch into current branch
git sync --merge release
```

## Workflow

When you run `git sync`, the command will:

1. Prompt for confirmation
2. Stash any uncommitted changes
3. Switch to the source branch
4. Pull the latest changes from the remote
5. Switch back to your working branch
6. Perform the requested sync operation (rebase or merge)
7. Restore any stashed changes
