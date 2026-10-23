# Progress

Pin `gh` to the checkout's git identity. `git identity` records `github.account`, and a `gh` shim on `PATH` forces that login's token. Real logins and hosts stay out of this repository.

**Complexity:** Level 3

## 2026-10-23 - COMPLEXITY ANALYSIS - COMPLETE

* Work completed
    - Classified the accepted shim as a Level 3 feature
    - Wrote the brief, including the ban on real local identities
* Decisions made
    - Level 3, because the work adds a `git-identity` directive, a `PATH` shim, and installer behavior
    - The code belongs in this repository because the accepted design changes `git identity`
* Insights
    - The operator was unsure this repository was the code home. The design they accepted writes the pin through `git identity`

## 2026-10-23 - PLAN - COMPLETE

* Work completed
    - Mapped `git-identity`, `shims/gh.sh`, and the installer
    - Wrote the TDD cases, the install park/restore rules, and the doc edits
* Decisions made
    - No unresolved design questions. The creative shim decision stands, and the code lives in this repository
    - Tests never call the real `gh` or the operator's home
    - A GitHub Enterprise Server host is forced with `GH_ENTERPRISE_TOKEN`. github.com and `*.ghe.com` use `GH_TOKEN`
* Insights
    - `gh auth token --user` does not echo an ambient `GH_TOKEN`. The shim still clears the four token variables before the lookup

## 2026-10-23 - PREFLIGHT - FAIL (fixable)

* Work completed
    - Ran preflight on the Level 3 plan
* Decisions made
    - Re-plan the shim's config read. `git config --get` would honor a global `github.account` and pin a checkout that never set one
* Insights
    - The planned suites set `GIT_CONFIG_GLOBAL=/dev/null`, so that bug would have stayed green

## 2026-10-23 - PLAN - COMPLETE

* Work completed
    - Re-planned the shim read, the marker skip, the empty directive, and the install restore
* Decisions made
    - A pin is a local key only
    - Do not export `GH_HOST`. SSH alias remotes keep their translation
    - Skip shim-marked binaries instead of resolving the real `gh` only at install time
* Insights
    - The install-time symlink would hide a `gh` installed after `make subcommands`. The marker skip still finds the next real binary

## 2026-10-23 - PREFLIGHT - COMPLETE

* Work completed
    - Checked the Level 3 plan against `git-identity`, the installer, and the test layout
    - Wrote `memory-bank/active/.preflight-status` with first line `FAIL (fixable)`
* Decisions made
    - Build stays blocked. The shim must read `github.account` with `git config --local --get`, and a test must set a global key so `GIT_CONFIG_GLOBAL=/dev/null` cannot hide a cascade read
    - Advisories (PATH resolution, `GH_HOST`, empty directive syntax, unset exit status) do not by themselves require a redesign
* Insights
    - `git config --replace-all` inside a repository is local. `git config --get` is not. The planned suites null the global file, so they stay green either way

## 2026-10-23 - PREFLIGHT - COMPLETE

* Work completed
    - Re-checked the revised Level 3 plan against `git-identity`, the installer, the test layout, and `gh help environment`
    - Wrote `memory-bank/active/.preflight-status` with first line `FAIL (fixable)`
* Decisions made
    - Build stays blocked. A successful token lookup has to export the same token as both `GH_TOKEN` and `GH_ENTERPRISE_TOKEN`, with `GITHUB_TOKEN` and `GITHUB_ENTERPRISE_TOKEN` cleared
    - `--hostname` still comes only from local `github.host`, and `GH_HOST` stays ambient
* Insights
    - `GH_TOKEN` applies to `github.com` and `*.ghe.com`. A GitHub Enterprise Server host reads `GH_ENTERPRISE_TOKEN`. The other variable being empty is what makes gh use the active account
    - Choosing that variable from local `github.host` misses a command whose target host came from the remote or from ambient `GH_HOST`

## 2026-10-23 - PLAN - COMPLETE

* Work completed
    - Re-planned token export, the empty-directive scan, the silent repo probe, and the install mode check
* Decisions made
    - Export the looked-up token as both `GH_TOKEN` and `GH_ENTERPRISE_TOKEN`
    - Leave `GH_HOST` ambient
    - Reject a bare or empty `@gh-account` or `@gh-host` before any config write
* Insights
    - The command's host and the token lookup's host are not the same fact. Setting one variable from `github.host` cannot cover both

## 2026-10-23 - PREFLIGHT - COMPLETE

* Work completed
    - Re-checked the revised Level 3 plan against git-identity, the installer, the test layout, and gh 2.103.0 token selection
    - Wrote `memory-bank/active/.preflight-status` with first line `PASS WITH ADVISORY`
* Decisions made
    - Build may proceed. The plan reads the pin with `git config --local --get` and exports the looked-up token as both `GH_TOKEN` and `GH_ENTERPRISE_TOKEN`
    - Advisories do not block: the lookup inherits `GH_HOST`, gh 2.103 writes a refresh warning on the lookup's stderr, and the creative note still describes a single token variable
* Insights
    - `gh auth token` with no `--hostname` uses `DefaultHost()`: `GH_HOST`, else the sole host in `hosts.yml`, else `github.com`. The git remote is separate, and the command after exec reads that remote
    - A non-empty `GH_TOKEN` or `GH_ENTERPRISE_TOKEN` is the credential for that host class, so the dual export keeps the active account out of the request

