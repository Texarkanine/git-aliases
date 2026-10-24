---
task_id: gh-account-pin
complexity_level: 3
date: 2026-10-24
status: completed
---

# TASK ARCHIVE: gh account pin

## SUMMARY

`git identity use` records a GitHub login and an optional API host on the checkout as local `github.account` and `github.host`. A linked worktree reads that same config. `make subcommands` installs a `gh` shim at `~/.local/bin/gh`. In a pinned checkout the shim runs the real `gh` with that login's token, and a login with no stored token exits before the requested command. A foreign `~/.local/bin/gh` is parked and restored on uninstall.

A later review found that the shim left `GIT_ALIASES_GH_SHIM` set on the real `gh`, so a shell alias that runs `gh` again exited with `Error: gh shim invoked itself`. `exec_real` now unsets that variable. The rework was a Level 1 bug fix on this feature. Draft pull request: https://github.com/Texarkanine/git-aliases/pull/19

## REQUIREMENTS

- `git identity use` writes `github.account` from `@gh-account` into local git config, so a linked worktree sees it. An identity with no `@gh-account` clears that key. `@gh-host` is the optional API host. `@hostname` stays the SSH alias and is not passed to `gh`.
- A `gh` earlier on `PATH` than the real binary reads the local pin, obtains that login's token with `gh auth token --user`, and execs the real `gh` with `GH_TOKEN` and `GH_ENTERPRISE_TOKEN` set to that token. `GITHUB_TOKEN` and `GITHUB_ENTERPRISE_TOKEN` are empty. The shim never calls `gh auth switch` and never prints a token.
- No local pin, or a directory that is not a repository, leaves the environment unchanged. A global `github.account` is not a pin. A pin with no token exits and does not run the command.
- The shim installs and uninstalls with `make` / `make subcommands` / `make clean`. A foreign `~/.local/bin/gh` is parked under `~/.local/libexec/git-aliases/` and restored. A second foreign file beside an existing parked file is refused.
- Linux and macOS. No new runtime dependency beyond git and the real `gh`. No real GitHub logins, hosts, or tokens in this repository. Tests stub `gh` under a fake `HOME`.
- Rework: outside a repository, in an unpinned checkout, and in a pinned checkout, the real `gh` does not inherit `GIT_ALIASES_GH_SHIM`. A child `gh` from that process runs.

## IMPLEMENTATION

The accepted design is a `PATH` shim. A directory hook does not run in a fresh `sh -c`. `gh auth switch` writes one global active user. Waiting for upstream `github.account` was not available in GitHub CLI 2.103.0: issue 12459 was open, and pull request 14269 was closed unmerged. The shim reads the config file a linked worktree already shares, leaves the global active account alone, and can refuse to run when the pin has no token.

`subcommands/git-identity/git-identity.bash` accepts `@gh-account` and `@gh-host`. A bare or empty directive fails before any key from that file is written. After a valid file, a missing directive unsets that local key. `@hostname` still rewrites SSH remotes and does not set `github.host`.

`shims/gh.sh` is POSIX. It confirms a repository with `git rev-parse --git-dir` and reads the pin with `git config --local --get`. The real binary is `~/.local/libexec/git-aliases/gh` when that file is executable and does not contain `git-aliases-gh-shim`. Otherwise it is the next executable `gh` on `PATH` whose file does not contain that marker. `main` exports `GIT_ALIASES_GH_SHIM` before resolve and before the token lookup, so a resolve that returns this shim stops. `exec_real` unsets the variable and then execs. `--hostname` comes only from local `github.host`. `GH_HOST` stays ambient. The looked-up token is exported as both `GH_TOKEN` and `GH_ENTERPRISE_TOKEN`.

`scripts/install-subcommands.sh` copies the shim to `~/.local/bin/gh`, parks a foreign file, refuses a second foreign file when a parked file exists, and restores the parked bytes on uninstall. The shim does not go through the subcommand cat-page loop.

The identity README, `memory-bank/productContext.md`, and `memory-bank/systemPatterns.md` name the directives and the shim. The creative note still describes a single `GH_TOKEN`. The code exports both token variables. That drift stayed an advisory.

## TESTING

`tests/test-git-identity.sh` covers the directives, the empty forms, the clear-on-omit behavior, `@hostname`, and a linked worktree. `tests/test-gh-shim.sh` stubs `gh` under an isolated `HOME` and covers passthrough, a global key that is not a pin, both host forms, a missing token, the worktree, libexec precedence, the marker skip, and no `auth switch`. `tests/test-install-subcommands.sh` covers park, restore, reinstall, and the refusal of a second foreign file.

The rework adds `test_reentry_outside_repo`, `test_reentry_unpinned`, and `test_reentry_pinned`. The stub records `GIT_ALIASES_GH_SHIM` and, for the argument `reenter`, runs `gh inner`. Those three failed with `Error: gh shim invoked itself` before the unset, and the shim suite passed after it.

QA on the feature passed with advisories and no rework. QA on the reentry fix passed with two advisories and no rework. `shellcheck --severity=error` was clean for the shim. `make test` on this machine stops in `tests/test-wt-wrappers.sh` because `zsh` is not on `PATH`. The suites this work owns passed. Later suites were run directly. Their zsh cases fail for that same missing `zsh`.

## LESSONS LEARNED

- A harness that points `GIT_CONFIG_GLOBAL` at `/dev/null` cannot see a config read that falls through to global. The case has to set a global key on purpose.
- `git config --unset` inside a repository removes the local key and leaves a global key of the same name. It exits 5 when the local key is already absent.
- The create template is an identity file. A scan for `@gh-account` has to skip comments, or `git identity create` then `git identity use` fails on the placeholder line.
- `GH_TOKEN` applies to github.com and `*.ghe.com`. A GitHub Enterprise Server host reads `GH_ENTERPRISE_TOKEN`. An empty one of those falls through to the active account, so the lookup exports the same token as both.
- Exporting the loop guard into the real `gh` makes a shell alias's child `gh` look like a resolve loop. The marker check is what skips this file. The guard stays exported only until `exec_real`.

## PROCESS IMPROVEMENTS

When a replan overrides a creative implementation note, update the note in that same replan. A test that passes on the first run is not evidence the behavior exists. Assert the setup the later assertion depends on.

## TECHNICAL IMPROVEMENTS

Two pull-request comments stay accepted behavior. `gh auth token` refresh warnings stay on the lookup's stderr. A lookup with no local `github.host` still inherits `GH_HOST`. Clearing `GH_HOST` only for the lookup would fetch the default-host token while the command still follows ambient `GH_HOST`.

QA on the rework noted a remaining edge: if the marker check misses on a passthrough exec, clearing the guard before `exec` can start this shim again. A pinned checkout still stops, because the token lookup runs while the guard is exported. The reentry tests do not lock that export in `main`. The code still exports it before resolve and before the token lookup.

## NEXT STEPS

None in the memory bank. The draft pull request is https://github.com/Texarkanine/git-aliases/pull/19
