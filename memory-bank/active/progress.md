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
