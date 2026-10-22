# Progress

Make `-h` and `--help` print the same help for `git wt`, `git sync`, and `git identity`, including nested commands, using `make` only if that path is reliable.

**Complexity:** Level 2

## 2026-10-22 - COMPLEXITY-ANALYSIS - COMPLETE

* Work completed
    - Restated the request and got operator confirmation, including the correction that every subcommand is in scope
    - Classified the task as Level 2
* Decisions made
    - Level 2: help is broken or missing across more than one subcommand, and the work stays inside that behavior
    - The question of whether `make` can make `git <command> --help` reliable is decided in planning
* Insights
    - `git <command> --help` never reaches the subcommand. Git looks up a man page named `git-<command>`
    - `git wt -h` already prints usage because Git does not intercept `-h`
    - `git-sync` and `git-identity` exit 1 on `--help` when the script itself is invoked, and do not print help
