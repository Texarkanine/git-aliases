---
task_id: subcommand-help
complexity_level: 2
date: 2026-10-22
status: completed
---

# TASK ARCHIVE: subcommand-help

## SUMMARY

`-h` and `--help` print the same help for `git wt`, `git sync`, and `git identity`, including nested commands. `make subcommands` publishes that text as cat pages so Git's `--help` lookup shows it. `make clean` removes the pages. Draft PR: https://github.com/Texarkanine/git-aliases/pull/18

## REQUIREMENTS

- Both flags print the same help for `git wt`, `git sync`, and `git identity`.
- Both flags on a nested command print help and exit 0, instead of being parsed as an operand.
- Do the top-level `git <command> --help` path in `make`, and only if that path is reliable.
- The word `help` stays a legal branch name for `git wt go`.
- Non-help behavior stays as it was.

## IMPLEMENTATION

`git <command> --help` never runs the executable. A roff `man1` page gains a header. A preformatted page in `cat1` is printed unchanged.

Each script scans every argument for `-h` or `--help` before any repository work, then prints usage and exits 0. The bash and zsh `wt` wrappers do the same and stay in the current directory.

`scripts/install-subcommands.sh` runs its install and uninstall loops in the current shell. After copying each executable it runs that copy's `-h` from an empty directory, with stdin from `/dev/null`, and writes that stdout to `~/.local/man/cat1/git-<name>.1` and `~/.local/share/man/cat1/git-<name>.1`. Uninstall deletes both files. Both directories are written because Linux `man` and Apple's `man` search different neighbors of a `bin` directory on `PATH`.

Usage lines for sync and identity name `--help` as well as `-h`. READMEs for `git-wt` and `git-identity` say so. `memory-bank/systemPatterns.md` records that `make clean` removes the pages.

## TESTING

New cases in `tests/test-git-wt.sh`, `tests/test-wt-wrappers.sh`, `tests/test-git-sync.sh`, `tests/test-git-identity.sh`, and `tests/test-install-subcommands.sh`. Identity tests copy the mode-644 script and chmod the copy. Outside-repository cases `cd` to a fresh directory first. The installer test unsets `MANPATH`, sets pagers to `cat`, and compares `git <name> --help` to that command's `-h`. A second install still matches. Uninstall removes the six cat pages.

`make shellcheck` passed. Suites that do not need zsh passed. zsh is not installed on this machine, so the zsh wrapper suite did not run. QA passed. An older `-h` arm in `git-sync` is unreachable because the new scan exits first.

## LESSONS LEARNED

- `git <command> --help` never runs the script. A `cat1` page is the text `-h` prints, from both `~/.local/man` and `~/.local/share/man`, when `~/.local/bin` is on `PATH` and `MANPATH` is unset.
- An outside-repository assertion that stays in this checkout can pass for the wrong reason. The fresh directory belongs in the test.
- A symlink to mode-644 `git-identity.bash` exits 126. Tests execute a chmod'd copy.
- `find | while` hides a failing `-h` from `make`. The install loop has to run in the current shell.
- Each script's first act is the help scan. A shared helper would have been a second copy of three short loops.

## PROCESS IMPROVEMENTS

Preflight caught the mode-644 copy, the checkout-as-repository trap, and the subshell install loop before any production edit. Keep those checks on the next installer or outside-repository test.

## TECHNICAL IMPROVEMENTS

On a terminal, `man` may page the cat-page text. That is how Git's `--help` already behaves. macOS was not executed here. A later roff page would change the bytes, so it is a follow-up.

## NEXT STEPS

None for this task. The draft pull request is https://github.com/Texarkanine/git-aliases/pull/18
