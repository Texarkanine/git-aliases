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
