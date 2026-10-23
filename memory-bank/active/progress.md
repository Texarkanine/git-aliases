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
