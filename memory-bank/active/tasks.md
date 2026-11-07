# Task: wt-go-branch-completions

* Task ID: wt-go-branch-completions
* Complexity: Level 2
* Type: rework

Rework the branch completers from the PR #20 review. Bash must offer branch names literally. Both `git wt` shells must offer the name under `refs/heads/` when a tag shares it. An unmatched `git wt go` prefix must not fall back to filenames, and `git sync` must not either.


## Test Plan (TDD)

### Behaviors to Verify

- Bash `git wt go` with empty current word, in a repo whose local branches are `main`, `feature/$USER`, `cmd$(true)`, and `has'quote` → the reply lines are those four literals. No reply line is `feature/` plus the expanded value of `$USER`. No reply line is `cmd`. No reply line is `hasquote`.
- Bash current word `feature/$U` after `go` → the only reply line is `feature/$USER`.
- Bash `git wt go` with empty current word, in a repo with local branches `main` and `feature/foo` and a tag `main` → the reply lines are `main` and `feature/foo`. `heads/main` is absent.
- Zsh `git wt go` with empty current word, in that same repo → the candidate lines are `main` and `feature/foo`. `heads/main` is absent.
- Bash Tab on `git wt go zz`, in a directory that contains a file `zz-unique-file`, with `git` bound the way git's own completion binds it (`-o bashdefault -o default -o nospace`) → the completed line does not contain `zz-unique-file`.
- Bash Tab on `git wt go ma`, in a repo whose local branch is `main`, under that same binding → the completed line contains `git wt go main`.
- Bash Tab on `git sync zz`, under that same binding, when `_get_comp_words_by_ref` returns non-zero → the completed line does not contain `zz-unique-file`.
- Bash Tab on `git sync zz`, under that same binding, when `_get_comp_words_by_ref` sets `cur` and `prev` and no local branch matches `zz` → the completed line does not contain `zz-unique-file`.
- Bash Tab on `git sync ma`, under that same binding, in a repo whose local branch is `main` → the completed line contains `git sync main`.

Existing cases stay: plain `main` / `other`, prefix `ma` and `zz`, `done` and bare `git wt` offer nothing, remote-tracking names stay out, sourcing does not call `__git_complete`, and `complete -p wt` stays `complete -F _git_wt wt`.

### Test Infrastructure

- Framework: homemade POSIX suites under `tests/`. `tests/test-bash-completion.sh` and `tests/test-zsh-completion.sh` are `#!/bin/sh`. Bash behavior runs through `bash -c`. Zsh behavior runs through `zsh -c`. Fail (do not skip) when the needed program is missing.
- Test location: `tests/`
- Conventions: `test_<name>` functions, `fail` helper, `make_repo`, locals prefixed with the test acronym, `main` calls each test. `make test` already runs both files. No new suite and no Makefile change.
- New test files: none
- Tab cases cannot see filename fallback by calling the function and reading `COMPREPLY`. They start an interactive bash on a pty, bind `complete -o bashdefault -o default -o nospace -F <fn> git`, send the words and one Tab, and read the transcript. The driver is `python3` (present on this machine and on the ubuntu-latest runner). The file name `zz-unique-file` is created before the session and is not printed by the setup commands, so it appears in the transcript only when completion inserts it.

## Implementation Plan

### 1. [x] Literal bash branch names — executable

- Files: `tests/test-bash-completion.sh`, `subcommands/git-wt/git-wt-completion.bash`

1. Stub tests: Add empty `test_wt_go_keeps_literal_branch_names` and `test_wt_go_literal_prefix`. Register both from `main`.
2. Stub interface: none. `_git_wt` already exists.
3. Write tests and run red: Create the branches with single-quoted names so the test shell does not expand them. Assert with `grep -Fx`. The prefix case expects exactly one line, `feature/$USER`. Run `tests/test-bash-completion.sh`. The new cases fail while the list still goes through `compgen -W`.
4. Write code and run green: Keep `%(refname:short)` for this step. Replace the `compgen -W` loop with `while IFS= read -r` over the for-each-ref lines. A non-empty line whose `case` pattern is `"${cur}"*` is appended to `COMPREPLY`. Do not word-split or eval the line. Re-run `tests/test-bash-completion.sh` until the new cases and the existing ones pass.

### 2. [x] Unambiguous head names — executable

- Files: `tests/test-bash-completion.sh`, `tests/test-zsh-completion.sh`, `subcommands/git-wt/git-wt-completion.bash`, `subcommands/git-wt/git-wt-completion.zsh`

1. Stub tests: Add empty `test_wt_go_tag_collision_keeps_head_name` to the bash suite and `test_wt_go_tag_collision_keeps_head_name` to the zsh suite. Register each from its `main`.
2. Stub interface: none.
3. Write tests and run red: `make_repo`, `git branch feature/foo`, `git tag main`. Bash and zsh empty-word `git wt go` must list `main` and `feature/foo` and must not list `heads/main`. Run both suites. The new cases fail while the format is `%(refname:short)`.
4. Write code and run green: Change both for-each-ref formats from `%(refname:short)` to `%(refname:strip=2)`. Re-run both suites until the new cases and the existing ones pass.

### 3. [x] No filename fallback for git wt go — executable

- Files: `tests/test-bash-completion.sh`, `subcommands/git-wt/git-wt-completion.bash`

1. Stub tests: Add empty `test_wt_go_tab_skips_filenames` and `test_wt_go_tab_still_completes_branch`. Register both from `main`. Add the pty helper signature next to `_complete_wt`: it takes the completer path, the working directory, and the command words, and prints the interactive transcript.
2. Stub interface: none.
3. Write tests and run red: The helper runs `python3`, which allocates a pty, execs `bash --noprofile --norc -i`, sources the completer, then runs `complete -o bashdefault -o default -o nospace -F _git_wt git`, then sends the words and one Tab. `test_wt_go_tab_skips_filenames` uses a directory that contains `zz-unique-file` and the words `git wt go zz`. Fail if the transcript contains `zz-unique-file`. `test_wt_go_tab_still_completes_branch` uses `make_repo` and the words `git wt go ma`. Fail if the transcript does not contain `git wt go main`. If `python3` is missing, fail. Run `tests/test-bash-completion.sh`. The filename case fails.
4. Write code and run green: After `prev` is known, return when it is not `go`. On the `go` path, run `compopt +o default 2>/dev/null || true` before the `cur == -*` return and before filling `COMPREPLY`. Do not pass `+o nospace`. Do not call `__git_complete`. Re-run `tests/test-bash-completion.sh` until the new cases and the existing ones pass.

### 4. [x] No filename fallback for git sync — executable

- Files: `tests/test-bash-completion.sh`, `subcommands/git-sync/git-sync-completion.bash`

1. Stub tests: Add empty `test_sync_tab_skips_filenames_when_helper_fails`, `test_sync_tab_skips_filenames_when_nothing_matches`, and `test_sync_tab_still_completes_branch`. Register them from `main`. Extend the pty helper so a test can define `_get_comp_words_by_ref` before the completer runs, and so it can source the sync completer and bind `_git_sync`.
2. Stub interface: none. `_git_sync` already exists.
3. Write tests and run red: All three bind `complete -o bashdefault -o default -o nospace -F _git_sync git` and use a directory that contains `zz-unique-file`. The helper-fails case defines `_get_comp_words_by_ref` to return 1. The nothing-matches case defines it to set `cur` and `prev` from `COMP_WORDS` and return 0, in a `make_repo` whose only branch is `main`, with words `git sync zz`. The match case uses words `git sync ma` in that repo. Fail when a `zz` transcript contains `zz-unique-file`. Fail when the match transcript does not contain `git sync main`. Run `tests/test-bash-completion.sh`. The `zz` cases fail.
4. Write code and run green: The first command in `_git_sync` is `compopt +o default 2>/dev/null || true`, before `_get_comp_words_by_ref`. Do not change the `%(refname:short)` format, the `compgen -W` lines, or the `__git_complete` block. Re-run `tests/test-bash-completion.sh` until the new cases and the existing ones pass.

## Technology Validation

No new product dependency. Completion still uses git for-each-ref, bash `case`, zsh `compadd`, and bash `compopt` (bash 4+, already required by `mapfile` in `git-sync-completion.bash`).

The Tab tests need `python3` on `PATH`. Verified here: a pty bash with `compopt +o default` and an empty `COMPREPLY` left `mygit zz` unchanged in a directory that contained `zz-unique-file`. The same probe without `compopt` rewrote the line to `zz-unique-file`. The GitHub ubuntu-latest runner already provides Python, so `.github/workflows/pr.yaml` does not install it.

## Dependencies

- `git` on `PATH`, with `%(refname:strip=2)` (git 2.7 and later; this machine is 2.34.1)
- `bash` on `PATH` for the completers and the pty session
- `zsh` on `PATH` for the existing zsh suite
- `python3` on `PATH` for the Tab transcripts
- `compopt` during a real completion attempt. A direct `_git_wt` / `_git_sync` call is not a completion attempt; the `2>/dev/null || true` guard keeps that call quiet

## Challenges & Mitigations

- An unquoted heredoc or `compgen -W` re-expands `$`, quotes, and backticks in the git output. The read loop takes for-each-ref's stdout as data. The test quotes branch names at creation.
- `%(refname:strip=2)` on a nested name must stay `feature/foo`. The tag-collision test includes that branch.
- `compopt` changes the current attempt only. The Tab tests bind `git` themselves with `-o default`. Asserting that the function called `compopt` is not the test. The transcript is.
- Calling `compopt` from the existing direct-call tests prints "not currently executing completion function" unless stderr is discarded and the status is ignored.
- `_git_sync` returns immediately when `_get_comp_words_by_ref` fails. `compopt` has to run before that return or the helper-fails Tab still offers the file.
- `+o default` does not clear `-o bashdefault` or `-o nospace`. A prefix that matches a command can still be offered, and a matched branch still gets no trailing space. Both are outside this request.
- `git sync` keeps `compgen -W` and `%(refname:short)`. Those are the same class of bug and are not this rework. Step 4 does not touch those lines, and no new sync test uses a `$` or a tag collision.
- The pty transcript includes bracketed-paste markers. Assertions look for the file name and the completed words, not for a clean screen.
- macOS system bash 3.2 has no `compopt`. The sync completer already needs `mapfile`. The pty session uses `bash` on `PATH`. Homebrew bash is what this repo already prefers for shell tests.

## Pre-Mortem

- The filename tests pass by never inserting a Tab, or the setup text contains `zz-unique-file`, so the assertion is blind. The helper sends one `\t` keystroke. The file is created outside the session, and the setup commands do not print its name. A control that completion still rewrites `ma` to `main` is a separate test, so a dead Tab fails that one.
- `compopt` is placed after a return, or only on the direct-call path, and the interactive `git` binding still has `-o default`. Step 3 puts it on every `go` return. Step 4 puts it on the first line of `_git_sync`. The tests bind `git` with `-o default` rather than calling the function.
- The tag fix uses `%(refname:short)` with a different ref filter and still prints `heads/main`. The test's expected name is `main`, and the nested branch `feature/foo` has to stay intact, which `strip=2` does and a "drop the first component" trim does not.
- Step 4 "cleans up" sync's `compgen -W` or format while fixing the fallback, and the rework grows past the request. The step forbids those edits. The new sync tests use `main` and a file name only.

## Status

- [x] Initialization complete
- [x] Test planning complete (TDD)
- [x] Implementation plan complete
- [x] Technology validation complete
- [x] Pre-Mortem complete
- [x] Preflight
- [x] Build
- [ ] QA
