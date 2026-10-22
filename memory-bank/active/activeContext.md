# Active Context

## Current Task: subcommand-help
**Phase:** COMPLEXITY-ANALYSIS - COMPLETE

## What Was Done
- Confirmed intent: `-h` and `--help` should print the same help for every subcommand, not only `wt`, and nested commands should print help instead of treating the flag as an argument.
- Operator decision: solve this for all subcommands (`wt`, `sync`, `identity`).
- Classified as Level 2. The decision tree treats this as an error correction that touches more than one component (each subcommand, and possibly install). It stays inside help behavior. Whether `make` can publish `git <command> --help` reliably is a planning question, not an architectural change.

## Next Step
- Load the Level 2 workflow and run the plan phase.
