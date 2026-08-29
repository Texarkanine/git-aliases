# Project Brief

## User Story

As a Git power user, I want a `git wt` subcommand that creates and tears down linked worktrees on a predictable path layout, with optional shell wrappers that `cd` for me, so parallel-branch work is repeatable across machines without verbose `git worktree` commands.

## Use-Case(s)

### Use-Case 1

From any worktree of a repo, run `git wt go <name>` to create (or reuse) a linked worktree at `~/worktrees/<owner>/<repo>/<repo>-<branch>` and print that absolute path on stdout. If the branch does not exist, create it.

### Use-Case 2

Run `git wt done <name>` to remove that worktree so the branch can be checked out in the main tree. Refuse if dirty unless `--force`, which prompts on `/dev/tty` before discarding. If cwd was inside the removed worktree, print the main checkout path so a wrapper can `cd` there.

### Use-Case 3

Opt in to shell integration (`make shell`) so interactive `wt go` / `wt done` auto-`cd`. Default `make` does not touch RC files. Scripts and CI keep using `git wt`.

## Requirements

Authoritative spec: [issue #5](https://github.com/Texarkanine/git-aliases/issues/5).

1. `git wt go <name>` and `git wt done <name> [--force]` as specified in the issue (idempotent `go`; dirty/`--force`/confirm `done`; main-checkout refusal; stdout/stderr contract).
2. Path convention `~/worktrees/<owner>/<repo>/<repo>-<branch>` with remote parsing (prefer `origin`) and `owner=local` fallback.
3. Consolidate logic in `subcommands/git-wt/git-wt.bash` (not separate `wt-go` / `wt-done` binaries).
4. Default `make` / `make subcommands` installs `git-wt` only; no RC changes.
5. `make shell` is a separate target (not part of `all`) that installs bash + zsh wrappers via `install-shell-integration.bash` using the completions fenced-block pattern; `make clean` / `--uninstall` removes fences and snippets.
6. `subcommands/git-wt/README.md` documents usage, path/stdout contract, and a prominent optional shell-integration section.
7. Bash completion for `git wt` is stretch (same PR if cheap; otherwise follow-up).

## Constraints

1. Dialect follows the filename: `.bash` is bash, `.sh` is POSIX. Makefile-embedded shell stays POSIX. The new installer is bash, so it is `install-shell-integration.bash`. Do not copy the misnamed `scripts/install-*.sh` (bash shebang, `.sh` extension).
2. No external runtime dependencies beyond `git` and `bash`.
3. Existing local implementation is the reference: `~/.local/bin/wt-go`, `wt-done`, `wt-common.sh`, plus a `wt()` function in `~/.zshrc`. Port that behavior; do not invent a parallel design. Those PATH scripts and the zsh function will need to be disabled or removed before local testing so they do not shadow the repo install. Operator has approved that.
4. Operator's login shell is zsh. Homebrew bash is installed and must be used to test bash wrappers as well as zsh.

## Acceptance Criteria

1. `git wt go` / `git wt done` work from any worktree of a repo.
2. Path layout matches the issue convention.
3. `go` is idempotent; `done` enforces dirty / `--force` / confirm behavior.
4. Default `make` installs the subcommand only; no RC file changes.
5. `make shell` installs bash + zsh wrappers idempotently; uninstall is clean.
6. README documents the extra shell step.
7. `wt` is a convenience wrapper, not a git subcommand.
