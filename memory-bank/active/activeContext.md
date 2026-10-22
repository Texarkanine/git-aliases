# Active Context

## Current Task: subcommand-help
**Phase:** BUILD - IN-PROGRESS

## What Was Done
- Classified the task as Level 2.
- Operator decision: solve `-h` and `--help` for every subcommand (`wt`, `sync`, `identity`), including nested commands.
- Decided the means. `git <command> --help` never runs the script; Git asks `man` for `git-<command>`. A preformatted cat page printed the `-h` bytes unchanged on this machine from both `~/.local/man/cat1` and `~/.local/share/man/cat1`. `make subcommands` will write both.
- Preflight returned `FAIL (fixable)`. The plan now copies `git-identity.bash` and chmods the copy (the tracked file is mode 644), `cd`s outside this repository before outside-repository cases, and runs the install loop in the current shell.

## Next Step
- Build the plan in order, starting with git-wt nested help.
