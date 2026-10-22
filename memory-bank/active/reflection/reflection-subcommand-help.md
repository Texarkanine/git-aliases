---
task_id: subcommand-help
date: 2026-10-22
complexity_level: 2
---

# Reflection: subcommand-help

## Summary

`-h` and `--help` now print the same help for `git wt`, `git sync`, and `git identity`, including nested commands. `make` publishes that text as cat pages so Git's own `--help` lookup shows it. The work succeeded.

## Requirements vs Outcome

The brief asked for both flags on every subcommand and every nested command, and for `make` to do the top-level `--help` path only if that was reliable. That is what shipped. `git <command> --help` prints the `-h` bytes after install. Nested flags print usage and exit 0 instead of being parsed as arguments. The word `help` is still a branch name for `git wt go`. Usage lines for sync and identity now name `--help` as well as `-h`. On a terminal, `man` may page that text, which is how Git's `--help` already behaves. The zsh wrapper suite did not run on this machine.

## Plan Accuracy

The sequence and file list held. Preflight added three corrections before any production edit: copy `git-identity.bash` and chmod the copy, because the tracked file is mode 644 and a symlink exits 126; `cd` out of this checkout before an outside-repository case, because `run_isolated` leaves the working directory here; and run the install loop in the current shell, because `find | while` would hide a failing `-h`. Those were the surprises. The cat-page spike matched the installer test.

## Build & QA Observations

The new tests went red for the reasons the plan named, then passed. `make shellcheck` passed. Suites that do not need zsh passed. QA passed and left an unreachable `-h` arm in `git-sync`, which the new scan exits before. That arm does not run.

## Insights

### Technical

- `git <command> --help` never runs the executable. A `man1` page gains a header. A `cat1` page is printed unchanged from both `~/.local/man` and `~/.local/share/man` when `~/.local/bin` is on `PATH` and `MANPATH` is unset.

### Process

- An outside-repository assertion that stays in this checkout can pass for the wrong reason. The fresh directory belongs in the test, not in a comment.

### Million-Dollar Question

What we built is the shape this would have had from the start. Each script's first act is the help scan, and the installer is the only place that publishes top-level `--help`. A shared helper would have been a second copy of three short loops.
