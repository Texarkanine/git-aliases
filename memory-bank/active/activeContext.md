# Active Context

## Current Task: subcommand-help
**Phase:** PLAN - COMPLETE

## What Was Done
- Classified the task as Level 2.
- Operator decision: solve `-h` and `--help` for every subcommand (`wt`, `sync`, `identity`), including nested commands.
- Decided the means. `git <command> --help` never runs the script; Git asks `man` for `git-<command>`. A roff page renders with a manual header. A preformatted cat page printed the `-h` bytes unchanged on this machine (git 2.34.1, man 2.10.2) from both `~/.local/man/cat1` and `~/.local/share/man/cat1`. `make subcommands` will write both. Nested `-h` and `--help` are handled in the scripts, because those arguments reach them. The `wt` wrappers print help and do not `cd`.

## Next Step
- Preflight validation.
