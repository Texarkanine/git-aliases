# Active Context

## Current Task: git-wt
**Phase:** BUILD - IN-PROGRESS

## What Was Done
- Unit 1 (git-wt CLI) implemented TDD: `tests/test-git-wt.sh` green; `subcommands/git-wt/git-wt.bash` ports local wt-* with HTTPS last-two-segments parse; `make test` runs it.
- Unit 2 (wrappers) implemented TDD: `shell/wt.bash` and `shell/wt.zsh` sourceable `wt()`; `tests/test-wt-wrappers.sh` uses mock git, Homebrew bash, `zsh -f`.
- Planned Level 3 implementation of [issue #5](https://github.com/Texarkanine/git-aliases/issues/5): `git wt` ported from local `wt-go`/`wt-done`/`wt-common.sh`, optional `make shell`, tests under fake `HOME`/`PATH`.
- No creative phase: spec + local reference + existing install/fence patterns are sufficient.
- First preflight FAIL (fixable): Unit 3 did not tell the implementer to wire `tests/test-install-shell-integration.sh` into `make test`. Patched Unit 3 step 4 to match Units 1–2.
- Re-run Preflight passed with advisories. Operator then clarified dialect: `*.bash`/bash shebang → bash; `*.sh`/`sh` shebang → POSIX. `choosing-shell-style.mdc` no longer excepts the installers: `.sh` + bash shebang is misnamed (rename to `.bash`), not a dialect exception. New installer is `install-shell-integration.bash`. `git wt list` stays out of scope.
- Operator invoked `/niko-build`. Preflight gate is `PASS WITH ADVISORY`. Entering Build; no creative docs to apply.

## Next Step
- Unit 3: shell-integration install (TDD). Unit 4 docs remaining.
