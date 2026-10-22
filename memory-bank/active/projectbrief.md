# Project Brief

## User Story

As a user of these git subcommands, I want `-h` and `--help` to print the same help for every subcommand and for each nested command, so that asking for help never returns a missing man page or treats the flag as an argument.

## Use-Case(s)

### Top-level help

`git wt -h` already prints usage. `git wt --help` does not: Git looks up a man page and reports that none exists. The same gap applies to `git sync` and `git identity`. Both flags should print that command's help.

### Nested help

`git wt go -h` and `git wt go --help` are treated as branch names. Nested commands should print help instead. The same applies to the other nested commands (`wt done`, `wt cleanup`, and `identity`'s `list`, `use`, and `create`). `git sync` has no nested commands.

## Requirements

1. Both `-h` and `--help` print the same help text for `git wt`, `git sync`, and `git identity`.
2. Both `-h` and `--help` on a nested command print help and exit successfully, instead of being parsed as an operand.
3. Prefer doing the `git <command> --help` path as part of `make`, and do that only if it is reliable.

## Constraints

1. `git <command> --help` is handled by Git before the subcommand runs. The script never sees that flag on this path.
2. Subcommands are bash. Install remains a `make` step with no new runtime dependencies.
3. This project is used on Linux and macOS. A mechanism that works on only one of them is not reliable.

## Acceptance Criteria

1. After install, `git wt -h`, `git wt --help`, `git sync -h`, `git sync --help`, `git identity -h`, and `git identity --help` each print that command's help and exit 0.
2. `git wt go`, `git wt done`, `git wt cleanup`, `git identity list`, `git identity use`, and `git identity create`, each with `-h` and with `--help`, print help and exit 0.
3. Existing non-help behavior of these commands is unchanged.
