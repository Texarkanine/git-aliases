# Product Context

## Target Audience

Git power users on Linux/macOS who work with multiple branches, identities, or teams and want a more ergonomic Git workflow than raw aliases can provide.

## Use Cases

- **Branch synchronization** (`git sync`): Keep a feature branch up to date with `main` (or another source branch) via rebase or merge, with automatic stash/restore handling.
- **Identity management** (`git-identity`): Switch between multiple Git identities (e.g., personal vs. work) without manually editing `.gitconfig`.
- **Alias shortcuts**: Reduce keystrokes for everyday operations (staging, diffing, status, log, remote interaction, rebase/merge).
- **Bash completion**: Tab-completion for the custom subcommands to reduce friction.
- **Linked worktrees** (`git wt`): Create and tear down linked worktrees at a predictable `~/worktrees/...` layout; optional shell wrappers auto-`cd`.

## Key Benefits

- Reduces error-prone manual steps (stash → checkout → pull → checkout → rebase → unstash).
- Keeps Git's native UX intact — subcommands are invoked as `git <name>`, consistent with Git's own vocabulary.
- Installable with a single `make` invocation; uninstallable cleanly.

## Success Criteria

- Subcommands handle edge cases (no remote, merge conflicts, stash failures) gracefully and provide actionable error messages.
- Aliases and completions install/uninstall idempotently without corrupting global Git config or shell RC files. Default `make` does not edit RC files; opt-in `make shell` appends a fenced `wt()` block to `~/.bashrc` / `~/.zshrc`.
- Bash completion scripts are correct and source-able without side effects.

## Key Constraints

- Subcommands must run in `bash` (not `/bin/sh`); aliases and Makefile-embedded shell must remain POSIX-compatible.
- Installation targets `~/.local/bin` for subcommands, `~/.local/share/git-aliases/completions/` for completion scripts, and (opt-in `make shell`) `~/.local/share/git-aliases/shell/` for wrappers.
- No external runtime dependencies beyond `git` and `bash`.
