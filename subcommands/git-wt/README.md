# git-wt

Work on several branches at the same time, each in its own folder.

`git wt` is a Git subcommand. It makes a Git worktree for a branch at a fixed, predictable path. When you are finished, it removes the worktree again.

## Overview

A normal repository folder has one branch checked out. To work on a different branch, you must commit or stash your changes, then switch. A worktree removes that step. It is an extra folder that shares the same repository, but has a different branch checked out. You can have many worktrees at the same time. Git supports worktrees itself; see the official [`git worktree` documentation](https://git-scm.com/docs/git-worktree).

Plain `git worktree add` needs you to type a folder path for each worktree, and to remove a worktree you must remember where you put it. `git wt` puts every worktree at a path it can calculate from the repository and the branch, so you only need to give the branch name:

- `git wt go <branch>` makes a worktree for a branch and prints its path. If the worktree already exists, it prints the path of that worktree.
- `git wt done` removes one worktree.
- `git wt cleanup` removes all the worktrees that `git wt go` made, after one confirmation.

Removing a worktree deletes only its folder. The branch and its commits stay in the repository.

In this document, the *main checkout* is the folder where you cloned the repository. The other folders are *linked worktrees*.

To install `git wt`, see the [root README](../../README.md#installation).

## Quick Start

We recommend the optional `wt` shell function. It does the same work as `git wt`, and also changes your directory for you. To install it, see [Shell Integration](#shell-integration).

With the `wt` shell function:

```bash
cd ~/projects/my-app
wt go fix-login   # make a worktree for branch fix-login, and cd into it
# edit, commit, and push as usual
wt done           # remove the worktree, and cd back to the main checkout
```

Without the `wt` shell function, do the `cd` yourself:

```bash
cd ~/projects/my-app
cd "$(git wt go fix-login)"
# edit, commit, and push as usual
cd "$(git wt done)"
```

`git wt` cannot change the directory of your shell. It prints a path, and then you (or the `wt` function) `cd` to that path.

After `done`, the branch `fix-login` still exists. To continue work on it, run `git wt go fix-login` again, or check it out in the main checkout.

## Where Worktrees Go

Each worktree goes to this path:

```
~/worktrees/<owner>/<repo>/<repo>-<branch>
```

Set `GITWT_ROOT` to an absolute path to use that directory instead of `~/worktrees`. `go`, `done`, and `cleanup` all use the same root. An empty `GITWT_ROOT` keeps `~/worktrees`. A relative `GITWT_ROOT` is an error. The shell expands `~` in the value before `git wt` sees it, so write `GITWT_ROOT=~/trees` without quotes if you want your home directory.

For example:

- Repository `git@github.com:Texarkanine/ai-rizz.git`, branch `feature-x`: `~/worktrees/Texarkanine/ai-rizz/ai-rizz-feature-x`
- Repository with no remote at `~/projects/foo`, branch `bar`: `~/worktrees/local/foo/foo-bar`

Because the path depends only on the repository and the branch, you always know where a worktree is. `git wt go` for the same branch always gives the same folder.

For how `git wt` finds `<owner>` and `<repo>`, see [Path Details](#path-details).

## Commands

Run `git wt help` for a short summary of the commands.

### go

```bash
git wt go <branch>
```

Makes a linked worktree for `<branch>`, and prints its absolute path.

- If the branch exists, the new worktree checks it out.
- If the branch does not exist, `go` creates it from the commit that you are on now (`HEAD`).
- If the worktree already exists, `go` prints its path and changes nothing.

You can run `go` from the main checkout or from any linked worktree of the repository.

To start a new branch from a different commit, create the branch first:

```bash
git fetch origin
git branch fix-login origin/main
git wt go fix-login
```

### done

```bash
git wt done [<branch>] [--force] [--yes]
```

Removes one linked worktree. The branch and its commits stay.

- With no `<branch>`, `done` removes the worktree that you are in now.
- With `<branch>`, `done` removes the worktree that has that branch checked out. You can run it from anywhere in the repository.

`done` works on all linked worktrees, including worktrees that `git wt go` did not make. It never removes the main checkout.

`done` does not remove a *dirty* worktree. A worktree is dirty when `git status` shows changes, including new untracked files. Commit or stash your changes first, or use these options to discard them:

- `--force` removes a dirty worktree. Before it discards the changes, it asks you to confirm on the terminal.
- `--yes` (or `-y`) skips that question.

Ignored files, such as `node_modules`, do not make a worktree dirty. `done` deletes them with the folder.

```bash
git wt done                          # remove the worktree you are in
git wt done feature-x                # remove the worktree for feature-x
git wt done feature-x --force        # discard changes, after you confirm
git wt done feature-x --force --yes  # discard changes, and do not ask
```

### cleanup

```bash
git wt cleanup [--all] [--list] [--yes] [--force] [+cursor]
```

Removes all the worktrees that `git wt go` made in this repository. First it shows the list, then it asks you one time. The branches stay.

- `--list` prints the paths, one on each line, and removes nothing. Use it to look before you remove.
- `--all` works on all repositories that have worktrees under `~/worktrees`, not only the current repository. You can run it from any folder.
- `--yes` (or `-y`) skips the question.
- `--force` also removes dirty worktrees, and discards their changes. Without `--force`, `cleanup` skips dirty worktrees and tells you. The one question covers all the worktrees in the list. There is no second question for each worktree.
- `+cursor` also includes the worktrees that the Cursor editor made. See [Cursor Worktrees](#cursor-worktrees).

`cleanup` removes only worktrees at the path in [Where Worktrees Go](#where-worktrees-go). It does not touch worktrees that you made with plain `git worktree add`, or that you moved. Use `git wt done` for those.

```bash
git wt cleanup --list                # what would it remove in this repository?
git wt cleanup --all --list          # what would it remove in all repositories?
git wt cleanup                       # remove the clean ones, after you confirm
git wt cleanup --yes                 # remove the clean ones, and do not ask
git wt cleanup --yes --force         # remove all of them, discard changes, and do not ask
git wt cleanup --all --yes --force   # the same, for all repositories

# Show the uncommitted changes in each worktree before you remove anything
git wt cleanup --list | while IFS= read -r d; do git -C "$d" status -s; done
```

If one removal fails, `cleanup` reports it, continues with the other worktrees, and exits with a non-zero status. For example, a removal fails when the worktree is locked with `git worktree lock`.

## Shell Integration

`git wt` runs as a separate process, so it cannot change the directory of the shell that started it. The optional `wt` shell function does that step for you. It accepts the same commands and options as `git wt`:

```bash
wt go <branch>      # cd into the worktree
wt done [<branch>]  # if you were in the removed worktree, cd to the main checkout
wt cleanup          # if you were in a removed worktree, cd to the main checkout
wt cleanup --list   # print the paths; do not cd
```

To install it for bash and zsh, run:

```bash
make shell
```

This copies the functions to `~/.local/share/git-aliases/shell/`. It also adds a marked block to `~/.bashrc` and `~/.zshrc` that loads them. Open a new shell, or `source` the file, before you use `wt`. You can run `make shell` again safely: it replaces the block, and does not add a second one.

The default `make` does not run `make shell`, and does not change your shell startup files.

To remove only the shell functions, run `scripts/install-shell-integration.bash --uninstall`. `make clean` also removes them, together with all the other things that this repository installs.

If you already have your own `wt` function in `~/.bashrc` or `~/.zshrc`, or `wt-go` or `wt-done` commands on your `PATH`, remove them or comment them out. Otherwise they can hide the installed `wt` function.

Use `wt` when you type commands yourself. Scripts and CI must call `git wt`, and `cd` themselves.

## Troubleshooting

### Branch Already Checked Out

Git lets you check out a branch in only one place at a time. If the main checkout or a different worktree has the branch checked out, `git wt go` fails with a message like `fatal: 'main' is already checked out at '...'`. Switch that checkout to a different branch, then try again.

The reverse is also true. To check out a branch in the main checkout, first remove its worktree with `git wt done <branch>`.

### Path Exists but Is Not a Worktree

`go` stops if the folder for the worktree already exists, but is not a Git worktree. Move or delete that folder, then run `go` again.

### No Terminal to Confirm

`cleanup`, and `done --force`, ask their question on the terminal (`/dev/tty`), not on standard input. Scripts and CI have no terminal, so the command fails. Add `--yes` to skip the question.

## Reference

### Path Details

- If the repository has a remote, `git wt` uses `origin`. If there is no `origin`, it uses the first remote. `<owner>` and `<repo>` are the last two parts of the remote URL, without a trailing `.git`. SSH-style URLs (`git@host:owner/repo.git`) and HTTPS URLs (`https://host/owner/repo.git`) both work.
- If the repository has no remote, `<owner>` is `local`, and `<repo>` is the name of the main checkout folder.
- A branch name with `/` makes nested folders. For example, branch `feature/login` in `ai-rizz` goes to `~/worktrees/Texarkanine/ai-rizz/ai-rizz-feature/login`.

`git wt` finds the main checkout from the first entry of `git worktree list --porcelain`. Because of this, each command gives the same result from the main checkout and from any linked worktree.

### Output for Scripts

`git wt` keeps standard output clean, so that scripts can capture it. Progress messages, lists, and errors go to standard error. Questions go to `/dev/tty`.

- `go` prints exactly one line on standard output: the absolute path of the worktree.
- `done` prints the path of the main checkout only if the current directory was in the removed worktree (at its root or in a subfolder). Otherwise it prints nothing.
- `cleanup --list` prints one worktree path on each line, and nothing else.
- `cleanup` prints the path of the main checkout only if the current directory was in a removed worktree. It prints this path even when a different removal failed.

Each command exits with status 0 when it succeeds. It exits with a non-zero status when it refuses, when you answer "no" to its question, or when a removal fails.

### How Cleanup Finds Worktrees

A worktree is on the `cleanup` list when it exists on disk, and its path is the [layout path](#where-worktrees-go) for the branch it has checked out. A worktree with a detached HEAD has no branch, so it is not on the list (except with `+cursor`, below).

With `--all`, `cleanup` searches the worktree root (`~/worktrees`, or `GITWT_ROOT` when that variable is set) to find repositories. It does not follow symbolic links. It finds branch names that have up to nine `/`-separated parts. If a folder there belongs to a repository that no longer exists, `cleanup` skips it and shows a warning.

### Cursor Worktrees

The Cursor editor can make its own worktrees under `~/.cursor/worktrees/<session>/`. `cleanup` does not touch them unless you add `+cursor`. You can put `+cursor` anywhere among the arguments.

With `+cursor`:

- `cleanup` also includes all linked worktrees of the repository whose path is under `~/.cursor/worktrees`, including worktrees with a detached HEAD.
- With `--all`, `cleanup` also searches `~/.cursor/worktrees` to find repositories that have no `git wt go` worktrees. It ignores empty session folders.
- After `cleanup` removes a Cursor worktree, it also removes the session folder `~/.cursor/worktrees/<session>/` if that folder is now empty.

Any other argument that starts with `+` is an error.
