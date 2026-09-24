# Active Context

## Current Task: GITWT_ROOT envvar support
**Phase:** QA - COMPLETE (PASS)

## What Was Done
- `wt_worktrees_root` in `subcommands/git-wt/git-wt.bash` is the single root. Unset or empty keeps `${HOME}/worktrees`. A non-absolute value calls `wt_die` with a message that the path must be absolute. One trailing slash is stripped, except for `/`.
- `wt_layout_prefix` and `wt_all_mains` use that helper. `wt_all_mains` still enables `dotglob` around the glob. Cursor helpers still use `${HOME}/.cursor/worktrees`.
- `tests/test-git-wt.sh` unsets `GITWT_ROOT` in `run_isolated` and adds five cases: go/done/cleanup --all/+cursor, empty, relative, trailing slash, and a root path with a space.
- Docs: `subcommands/git-wt/README.md` (Where Worktrees Go, and the `--all` search sentence) and the git-wt bullet in `README.md`.

## Key Decisions
- Did not canonicalize `GITWT_ROOT` to a physical path. The helper returns the configured path, and the existing logical/physical match in `wt_created_worktrees` stays as it was.
- The relative-path error text names the absolute-path requirement, from the preflight advisory.

## Deviations
- The `--all` sentence in the git-wt README now names `GITWT_ROOT`, so that section does not keep saying cleanup only searches `~/worktrees`.

## Files
- `/home/mobaxterm/Documents/git/git-aliases/subcommands/git-wt/git-wt.bash`
- `/home/mobaxterm/Documents/git/git-aliases/tests/test-git-wt.sh`
- `/home/mobaxterm/Documents/git/git-aliases/subcommands/git-wt/README.md`
- `/home/mobaxterm/Documents/git/git-aliases/README.md`

## Next Step
- QA review
