# Project Brief

## User Story

As a person with more than one GitHub account, I want `gh` in a checkout to use the account that checkout's git identity names, so a pull request, issue, or comment cannot go out as the machine's global active account. A worktree of that checkout uses the same account without a second setup.

## Use-Case(s)

### Pinned checkout

`git identity use` records a GitHub login for this checkout. Later, `gh` commands run from that checkout, or from a linked worktree, authenticate as that login.

### Missing token

The checkout names a login that `gh` has no stored token for. The `gh` command exits with an error and does not run as the global active account.

### Unpinned checkout

The checkout has no GitHub login recorded. `gh` behaves as it does today and uses the active account.

## Requirements

1. `git identity use` writes `github.account` from an `@gh-account` directive, using plain local git config so linked worktrees read the same value.
2. An identity file with no `@gh-account` clears `github.account` in that checkout.
3. `@gh-host` is optional and names a real API host. `@hostname` stays the SSH alias and is not passed to `gh` as a host.
4. A `gh` executable earlier on `PATH` than the real binary reads the pin, obtains that login's token with `gh auth token --user`, and execs the real `gh` with `GH_TOKEN` set and `GITHUB_TOKEN` unset.
5. When the pin is missing, or the current directory is not a repository, the shim execs the real `gh` with the environment unchanged.
6. When the pin is set and no token is available, the shim exits and does not run the requested command.
7. The shim never calls `gh auth switch` and never prints a token.
8. The shim installs and uninstalls with the default install path (`make` / `make subcommands` / `make clean`).
9. When `~/.local/bin/gh` is some other program, install parks it and uninstall restores it. A later install does not destroy the parked program.

## Constraints

1. Linux and macOS. `cmd` and PowerShell are out of this pass.
2. No new runtime dependency beyond git and the real `gh`.
3. No real GitHub logins, SSH hosts, account names, or tokens in this repository: not in code, tests, docs, or the memory bank. Examples and tests use obvious placeholders.
4. Tests must not invoke the operator's real `gh`, read `~/.config/gh`, or install into the operator's real home.
5. The design record is `memory-bank/active/creative/creative-gh-account-per-checkout.md`.

## Acceptance Criteria

1. A linked worktree sees `github.account` set by `git identity use` on the core checkout.
2. Switching to an identity with no `@gh-account` removes a pin left by the previous identity.
3. A pinned command receives that login's token even when `GH_TOKEN` or `GITHUB_TOKEN` was already set.
4. A pinned login with no token exits non-zero and the requested `gh` command does not run.
5. An unpinned repository and a directory that is not a repository leave an existing `GH_TOKEN` untouched.
6. The shim does not pass `@hostname` to `gh auth token --hostname`.
7. Two checkouts with different pins do not call `gh auth switch`.
8. Install under a fake home parks a foreign `~/.local/bin/gh` and uninstall puts it back. Reinstall while the shim is already installed does not destroy the parked binary.
