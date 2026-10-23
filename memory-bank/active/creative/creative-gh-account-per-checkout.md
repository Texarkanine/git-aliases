# Decision: gh Account per Checkout

## Context

`git identity use` writes the checkout's git identity into local git config. A linked worktree reads that same file (`$GIT_COMMON_DIR/config`), so push, pull, and commit identity set up on the core checkout show up in a worktree with no second setup.

`gh` does not. Through GitHub CLI 2.103.0 (2026-10-21) one active account per host is stored in `~/.config/gh` and changed with `gh auth switch`. Every terminal, agent, and checkout on the machine shares that active account. A `gh pr create`, `gh issue`, or comment from one session can go out as whichever account was switched last.

What has to be decided: how a checkout names the GitHub account `gh` must use, in a way a worktree inherits, and in a way that holds for an interactive shell, a fresh `bash -c` / `sh -c`, Cursor's tool shell, and Claude Code, on Linux and macOS. Windows is a nice-to-have.

Constraints:

- The pin lives with the checkout, in the git config worktrees already share. A second setup step per worktree fails the requirement.
- Concurrent sessions must not change each other's account. `gh auth switch` writes one global active user.
- A pin that cannot be honored must fail the command. Falling through to the global active account is the bug.
- No new runtime dependency. The project installs bash and git, into `~/.local/bin`.
- `git identity` already rewrites SSH remotes to a vanity host (`@hostname`) for key selection. That host is an SSH alias. `gh` selects accounts by GitHub user on an API host, and it translates SSH aliases back to the real host. The vanity host does not choose the `gh` user.
- Official multi-account support (v2.40.0) left automatic switching by directory or git remote out of scope on purpose. The extension point they documented is `GH_TOKEN=$(gh auth token --user <login>)`. Issue [#12459](https://github.com/cli/cli/issues/12459) (open, labeled `core`, last comment 2026-10-15) asks for a native `git config github.account` pin. Pull request [#14269](https://github.com/cli/cli/pull/14269) implemented it and was closed unmerged on 2026-08-27 (`mergedAt` null, label `unmet-requirements`). It is not in 2.103.0. That PR also fell back to the active account when the pin had no token, and it left `gh auth status` showing the global user.

Verified on git 2.34.1, in a temporary repo:

- `git config github.account` in the core checkout is `file:<main>/.git/config`. A linked worktree reads and writes that same file.
- `includeIf gitdir:<main-checkout>/` matches a linked worktree too, because the worktree's git dir is `<main>/.git/worktrees/<name>`.
- `includeIf gitdir:<worktree-checkout>/` matches nothing. The worktree's working tree is not the path git uses for `gitdir:`.
- `git config --worktree` writes `config.worktree` for that one worktree. Plain `git config` does not. The pin has to be a plain local key.
- This Cursor tool shell is noninteractive and still has the `wt` function, because it is a long-lived shell that already sourced `~/.bashrc`. A fresh `bash -c` and a fresh `sh -c` do not have `wt`. Both find `gh` at `~/.local/bin/gh` via `PATH`.

## Options Evaluated

- **Directory hook (rvm / chruby style, or direnv):** on entering a directory, export `GH_TOKEN` or `GH_CONFIG_DIR`. direnv is the version people actually publish ([knpw.rs](https://knpw.rs/blg/multiple-gh-users/), [cli/cli discussion #12237](https://github.com/cli/cli/discussions/12237)). `gh-profile` is the older whole-config-dir switcher the official doc points at.
- **Shell function that calls `gh auth switch`:** the snippet in [#12459](https://github.com/cli/cli/issues/12459) and [#13529](https://github.com/cli/cli/issues/13529). If `git config github.account` differs from the active user, switch, then run `gh`.
- **PATH shim that sets `GH_TOKEN` for one command:** an executable named `gh`, earlier on `PATH` than the real binary. It reads the account from git config, runs `gh auth token --user`, and execs the real `gh` with that `GH_TOKEN`. [ghx](https://github.com/barnuri/ghx) does this with a folder map or a `.ghx` file. The official doc's own one-liner is the same token handoff, without the shim.
- **Wait for native `github.account`:** do nothing in this repo until `gh` reads the key itself.

## Analysis

| Criterion | Directory hook | `auth switch` function | `GH_TOKEN` shim | Wait for upstream |
|---|---|---|---|---|
| Pin stored once, in the config a worktree already reads | Only if the hook reads local git config. direnv and ghx key off the working-tree path, so `~/worktrees/...` does not see a file or folder rule set on the core checkout | Yes, if it reads local git config | Yes | Yes, once it ships. It has not shipped |
| A fresh `bash -c` / `sh -c` honors it | The hook never runs. direnv's hook is installed in an interactive rc file | The function is not defined. Measured: fresh `bash -c` and `sh -c` have no `wt` | Yes. Both find `gh` on `PATH` | Yes, inside `gh` |
| Cursor tool shell and Claude Code | Only when that process sourced the hook. A shell that starts already in the repo never `cd`s | Same, and only for bash | Yes, wherever `command -v gh` is the shim | Yes |
| Concurrent sessions stay on their own account | Yes, if each process has its own env and nobody calls `auth switch` | No. Switch writes the one active user. People on #12459 have had one session flip the account under another | Yes. The active user in `~/.config/gh` is left alone | Yes, in the closed PR's design |
| Missing pin fails the command | A missing `.envrc` leaves the global account in place | The published snippets switch when they can, and otherwise run as whoever is active | The shim can exit before exec | The closed PR fell back to the active account on purpose |
| Linux and macOS, no new dependency | A hand-rolled hook is bash. direnv is a new dependency, weak on Windows | bash function, so macOS and Linux interactive bash/zsh only | One `#!/bin/sh` script. Git Bash can use it. `cmd` and PowerShell will not run a shebang script named `gh` | `gh` itself, all platforms |
| Fits `git identity` | A second config file, outside the identity | Can read a key `git identity` wrote, and then mutates global `gh` state | Reads a key `git identity` wrote. Identity files gain one directive | Would read the same key, with no shim |

Key insights:

- The world has converged on two workarounds, and both miss this layout. direnv / `GH_CONFIG_DIR` / ghx attach the account to a directory string. `auth switch` wrappers attach it to process-global mutable state. The checkout's own git config is the place worktrees already share, and `gh` will not read it until upstream ships #12459.
- `includeIf gitdir:<core-checkout>/` does follow a linked worktree, because matching uses the git dir under the core checkout, not the worktree's working tree. That makes `includeIf` a viable store. It is the wrong scope for this tool. `git identity use` is per checkout, not per parent folder. The pin belongs in the local config that command already writes.
- `@hostname` stays an SSH concern. Passing that alias to `gh auth token --hostname` looks up credentials for a host `gh` does not have.
- Upstream's sanctioned building block is `gh auth token --user`. `GH_TOKEN` outranks stored credentials ([`gh help environment`](https://cli.github.com/manual/gh_help_environment)). A shim that exports it is doing what the `gh` maintainers described, per process, without `auth switch`.
- Using the key name `github.account` matches the open proposal. The day `gh` honors it, identities written now still mean the same thing. Until that `gh` fails closed, the shim still has a job: an ambient `GH_TOKEN` / `GITHUB_TOKEN` outranks a native pin, and the closed PR's fallback would reintroduce the cross-wire.

## Decision

**Selected**: PATH shim that forces `GH_TOKEN` from a local `github.account` pin, written by `git identity`.

**Rationale**: It is the only option that is visible to every `exec` of `gh`, reads the config file linked worktrees already share, leaves the global active account alone, and can refuse to run when that account has no stored token. Linux and macOS share one POSIX script. No direnv, no `cd` hook, no `gh auth switch`.

**Tradeoff**: Every `gh` pays for one extra `gh auth token` process. The shim has to be the `gh` that `PATH` finds; an absolute path to the real binary skips it. When a real `gh` binary is already installed at `~/.local/bin/gh`, the installer parks that binary aside, and a later upgrade that writes a new binary back to that path removes the shim until install is re-run. Homebrew and apt are unaffected, because they put `gh` elsewhere and `~/.local/bin` already precedes them. `cmd` and PowerShell are out of this pass. A checkout with no pin still uses the global account.

## Implementation Notes

- Add an identity directive `@gh-account <login>`. `git identity use` runs `git config --replace-all github.account <login>`. Plain `git config`, never `--worktree`. When the identity file has no `@gh-account`, unset `github.account` in that repo so the previous identity's pin does not stick. A raw `github.account "..."` line in the identity file would set the key and would not clear it on a later identity that omits it.
- Do not reuse `@hostname`. Optional `@gh-host` only for a real API host (GitHub Enterprise). Omitted means `gh auth token --user` with no `--hostname`, which is github.com unless `GH_HOST` is already set.
- Shim, `#!/bin/sh`, installed as `~/.local/bin/gh` on the default install path (it is a no-op when the key is unset, so it has to be present for agents without a second opt-in). Resolve the real binary from `~/.local/libexec/git-aliases/gh` if the installer parked one there, otherwise the next `gh` on `PATH` that is not the shim.
- Inside a repo, read `github.account`. Unset or not a repo: exec the real `gh` with the environment unchanged. Set: `token=$(real gh auth token --user "$account" ...)`. Non-zero exit or empty token: print that this checkout is pinned to that login and `gh` has no token for it, then exit. Do not run the requested command. On success, unset `GITHUB_TOKEN`, set `GH_TOKEN`, exec the real `gh`. Never print the token. Never call `gh auth switch`.
- A deliberate `gh auth switch` still changes the global active user for checkouts that have no pin. The shim does not stop that command. It stops the result from affecting a pinned checkout.
- `git push` over SSH stays on `@hostname`. `git push` over HTTPS uses `gh` as a credential helper only when that helper is invoked as `gh` on `PATH`; the shim then supplies the pinned token. A helper configured as an absolute path to the real binary skips the shim.
- Tests, when this is built: worktree sees the pin set on the core checkout; missing token exits and does not exec the command; unset key execs the real `gh` with `GH_TOKEN` untouched; two pins in two repos in two processes do not change `gh auth status`'s active account; `@hostname` is not passed as `--hostname`.
- When a future `gh` documents that `github.account` fails closed, delete the shim and keep the directive.
