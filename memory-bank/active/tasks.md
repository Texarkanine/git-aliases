# Task: wt-go-branch-completions

* Task ID: wt-go-branch-completions
* Complexity: Level 2
* Type: simple enhancement

Add bash and zsh completion so `wt go`, `git wt go`, and `git-wt go` offer existing local branch names. A name that is not a local branch is not offered. `make completions` already installs `*-completion.bash` and `*-completion.zsh`; this adds those companions for `git wt`.


## Test Plan (TDD)

### Behaviors to Verify

- Zsh `git wt go`, `wt go`, and `git-wt go` with an empty current word, in a repo that has `main` and `other` → candidates include `main` and `other`.
- Zsh `_git-wt` (the `_git` dispatcher entry) with words `git wt go ""` → the same candidates.
- Zsh `git wt ""` and `git wt done ""` → no candidates.
- Zsh outside a repository, and in a repository whose only extra ref is a remote-tracking ref → no candidates from that ref; outside a repo, none at all.
- Zsh candidate list is the local branch names. A name that is not a local branch is absent.
- Sourcing `git-wt-completion.zsh` with `GIT_ALIASES_COMPLETION_TEST=1` → no stdout.
- Sourcing `git-wt-completion.zsh` with no prior `compinit` → `_comps[git-wt]` and `_comps[wt]` are set, and git `user-commands` includes `wt`.
- Bash `_git_wt` for `git wt go`, `wt go`, and `git-wt go` in that repo → `COMPREPLY` includes `main` and `other`.
- Bash current word `ma` after `go` → `main` only. Current word `zz` → empty `COMPREPLY`.
- Bash `git wt` and `git wt done` → empty `COMPREPLY`.
- Bash outside a repository → empty `COMPREPLY`. A remote-tracking ref is not a reply.
- Sourcing `git-wt-completion.bash` → no stdout, and `complete -p` binds both `git-wt` and `wt` to `_git_wt`.
- When `__git_complete` is defined, sourcing the bash script calls it for `wt` and `_git_wt`.
- `scripts/install-completions.bash` copies `git-wt-completion.bash` and `git-wt-completion.zsh`, and the zsh fence sources the zsh file.

### Test Infrastructure

- Framework: homemade POSIX suites under `tests/`. A `*.sh` driver invokes `zsh -c` or `bash -c`. Zsh stubs `compadd`. Bash sets `COMP_WORDS` / `COMP_CWORD` and reads `COMPREPLY`. Fail (do not skip) when the shell is missing. Same rule as `tests/test-zsh-completion.sh`.
- Test location: `tests/`
- Conventions: `test_<name>` functions, `fail` helper, `make_repo` for a throwaway repo, prefix locals with the test acronym, `main` calls each test. `make test` lists each suite explicitly in the `Makefile`.
- New test files: `tests/test-bash-completion.sh`

## Implementation Plan

### 1. [x] Zsh candidates after `go` — executable

- Files: `tests/test-zsh-completion.sh`, `tests/test-install-completions.sh`, `subcommands/git-wt/git-wt-completion.zsh`

1. Stub tests: In `tests/test-zsh-completion.sh`, add empty `test_wt_go_completes_local_branches`, `test_wt_go_dispatcher_matches`, `test_wt_without_go_completes_nothing`, `test_wt_ignores_remote_and_outside_repo`, `test_wt_source_is_silent`, `test_wt_registers_compdef_for_git_wt_and_wt`. Add a `_complete_wt` helper signature next to `_complete_sync`. In `test_install_copies_zsh_and_writes_fence`, add the two assertions for `git-wt-completion.zsh` (file copied, fence sources it) with the assertions written and expected to fail until the file exists. Register the new tests from `main`.
2. Stub interface: Create `subcommands/git-wt/git-wt-completion.zsh` with documented empty `_git_wt`, `_git-wt`, and `_git_wt_register`. `_git_wt_register` returns immediately when `GIT_ALIASES_COMPLETION_TEST` is set. No `compadd` yet.
3. Write tests and run red: Fill the assertions. `_complete_wt` sources the zsh file with `GIT_ALIASES_COMPLETION_TEST=1`, stubs `compadd` to print arguments after `--`, and calls `_git_wt` or `_git-wt`. Branch cases use `make_repo` plus `git branch other`. Remote case adds `refs/remotes/origin/main` via `git update-ref` and expects that name absent. Registration case uses `zsh -f` and checks `_comps[git-wt]`, `_comps[wt]`, and `zstyle` user-commands for `wt`. Run `tests/test-zsh-completion.sh` and `tests/test-install-completions.sh`. New wt cases fail.
4. Write code and run green: `_git_wt` reads `words[CURRENT-1]`. When that word is `go`, it runs `git --no-pager for-each-ref --format='%(refname:short)' refs/heads/` and `compadd`s the lines when non-empty. Any other previous word adds nothing. `_git-wt` calls `_git_wt`. `_git_wt_register` follows `_git_sync_register`: `compinit -C` only when `compdef` is missing, `compdef _git_wt git-wt`, `compdef _git_wt wt`, and append `wt:'create or enter a linked worktree'` to user-commands when absent. Re-run the two suites until the new cases pass.

### 2. Bash candidates after `go` — executable

- Files: `tests/test-bash-completion.sh`, `tests/test-install-completions.sh`, `Makefile`, `subcommands/git-wt/git-wt-completion.bash`

1. Stub tests: Add `tests/test-bash-completion.sh` with the suite header, `fail`, `make_repo`, and empty `test_wt_go_completes_local_branches`, `test_wt_go_prefix_filters`, `test_wt_without_go_completes_nothing`, `test_wt_ignores_remote_and_outside_repo`, `test_wt_source_binds_git_wt_and_wt`, `test_wt_calls_git_complete_when_present`. Wire it from `main`. In `test_bash_copy_and_fence_unregressed`, assert the copied bash file exists. Add the suite to the `Makefile` `test` recipe (chmod and run) so `make test` would execute it.
2. Stub interface: Create `subcommands/git-wt/git-wt-completion.bash` (`#!/usr/bin/env bash`) with documented empty `_git_wt` and the three registration lines (`complete -F _git_wt git-wt`, `complete -F _git_wt wt`, and `__git_complete wt _git_wt` only when that function exists). `_git_wt` returns 0 without setting `COMPREPLY`.
3. Write tests and run red: A helper runs `bash -c`, sources the file, sets `COMP_WORDS` and `COMP_CWORD`, calls `_git_wt`, and prints `COMPREPLY` one name per line. Prefix `ma` expects `main` and not `other`. Prefix `zz` expects no output. `__git_complete` case defines a stub that records its arguments, then sources the file. Run `tests/test-bash-completion.sh`. New cases fail. Do not load bash-completion; the function must work from `COMP_WORDS` alone.
4. Write code and run green: `_git_wt` sets `cur` and `prev` from `COMP_WORDS` / `COMP_CWORD`. Call `_get_comp_words_by_ref` only when `declare -F` finds it, and do not `return` when it is missing. When `prev` is `go` and `cur` does not start with `-`, `compgen -W` the same `refs/heads/` list. Otherwise `COMPREPLY` is empty. Re-run `tests/test-bash-completion.sh` and `tests/test-install-completions.sh` until the new cases pass.

### 3. Docs — prose/policy

- Files: `README.md`, `subcommands/git-wt/README.md`
- No tests: prose/policy artifact

1. In the root Completions section, say `git wt go` and `wt go` complete local branch names, in the same sentence that today says `git wt` has no completion.
2. In `subcommands/git-wt/README.md`, under `go`, state that bash and zsh offer local branch names after `go`, and that a new branch name is typed because it is not in that list.

## Technology Validation

No new technology - validation not required. Completers use `git for-each-ref`, bash `compgen`, and zsh `compadd` / `compdef`, which `git-sync` already uses. `make shellcheck` scans tracked `*.sh` only, so the new `*.bash` completer is outside that gate; the new `tests/test-bash-completion.sh` is inside it.

## Dependencies

- `git` on `PATH` (local `refs/heads/` list)
- `bash` and `zsh` on `PATH` for the behavior suites
- Existing `scripts/install-completions.bash` glob of `*-completion.bash` and `*-completion.zsh`
- bash-completion's `__git_complete` only at runtime, and only when that function already exists

## Challenges & Mitigations

- Sibling bash completers do `_get_comp_words_by_ref ... || return`, so a missing helper never reaches the `COMP_WORDS` fallback. The new function calls the helper only when it exists.
- `wt` is installed by opt-in `make shell`; completions are installed by default `make completions`. Register `complete` / `compdef` for the name `wt` even when the function is not defined yet.
- These suites call the completer functions. They do not press Tab through zsh `_git` or bash `git` completion. That is the same ceiling as `git-sync`. `_git-wt`, `__git_complete`, and `user-commands` are the hooks those dispatchers use.
- `git wt go` treats a name that is not under `refs/heads/` as a new branch. Offer only `refs/heads/` short names. A test plants `refs/remotes/origin/main` and expects it absent.
- `done` also takes a branch and is out of scope. Candidates are added only when the previous word is `go`. A test covers `done` and the bare command word.

## Pre-Mortem

- Completing only branches that already have a worktree would miss the approved behavior. `go` also checks out a local branch that has no worktree yet. The plan lists every local branch. Challenge 4 already keeps remote-tracking names out.
- A green suite that never calls `git`'s own completer can still leave `git wt <Tab>` dead in a real shell if `_git-wt` or `__git_complete` is wired wrong. The registration tests cover those hooks. End-to-end Tab stays an operator smoke, as it did for `git sync`.

## Status

- [x] Initialization complete
- [x] Test planning complete (TDD)
- [x] Implementation plan complete
- [x] Technology validation complete
- [x] Pre-Mortem complete
- [ ] Preflight
- [ ] Build
- [ ] QA
