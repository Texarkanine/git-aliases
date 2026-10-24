---
task_id: gh-account-pin
date: 2026-10-23
complexity_level: 3
---

# Reflection: gh account pin

## Summary

`git identity use` now records the GitHub login for a checkout, and a `gh` shim on `PATH` forces that login's token. The build matches the numbered plan. QA passed with advisories and did not send the work back.

## Requirements vs Outcome

The brief's nine requirements and eight acceptance criteria are in the tree. A pin is local `github.account`. An identity that omits `@gh-account` or `@gh-host` clears that key. `@hostname` still rewrites the SSH remote and is not passed as `--hostname`. A missing token exits before the requested command. Install parks a foreign `~/.local/bin/gh` and uninstall puts those bytes back.

Two details are stronger than the original brief and match the replanned steps. The looked-up token is exported as both `GH_TOKEN` and `GH_ENTERPRISE_TOKEN`, with the `GITHUB_*` pair empty. The brief's requirement 4 names only `GH_TOKEN`. Every exec also sets `GIT_ALIASES_GH_SHIM` so a bad resolve cannot loop. The token variables themselves stay as the caller left them when there is no local pin.

Nothing in the plan was dropped. The build added `test_create_then_use_exits_zero` so a commented directive in the create template cannot fail `use`. The root README install section still does not mention the shim. The plan did not ask for that edit. QA recorded it as an advisory.

## Plan Accuracy

The four units, the file list, and the order were right. The challenges in the plan were the ones that mattered: a global `github.account` is not a pin, both token variables have to be set, a shim-marked file is never the real binary, and `git config --unset` of a missing key must not fail the command. No step had to be redesigned during build.

The surprises were in the tests, not the design. A clear-pin case passed while the pin was never written. An uninstall-restore case passed while the foreign file had never moved. A worktree path of `/tmp/linked-checkout` collided with the previous run. Each one was a test that could not go red for the behavior it named. The implementation steps themselves went green on the first real run.

`PATH` entries that contain spaces are walked with `IFS=:`, as the plan required. No test uses such an entry.

## Creative Phase Review

The PATH shim held. It reads the config file a linked worktree already shares, it does not call `gh auth switch`, and a pin with no token does not fall through to the active account. That was the decision, and the code does it.

The creative implementation note still says to set only `GH_TOKEN`. Preflight rejected that before build, because a GitHub Enterprise Server host reads `GH_ENTERPRISE_TOKEN` and an empty one falls through to the active account. Build followed the numbered steps. QA repeated the stale-note advisory and did not ask for a code change. The decision held. The note did not, because the replan never updated it.

## Build & QA Observations

The red runs were the useful part of the build. The identity suite, the shim suite, and the installer suite each failed for the new behavior before the code existed, and passed after it. Shellcheck at error severity was clean for the shim and the installer.

QA passed on the first review. It confirmed the pin is local, the lookup fails closed, and park/restore matches the plan. It did not find a behavior bug. The advisories are the inherited `GH_HOST` on the lookup, the uncaptured lookup stderr, the stale creative note, a "Switching to identity" line printed before a rejected directive, and the root README. None of those violate the numbered steps.

`make test` on this machine stops in `tests/test-wt-wrappers.sh` because `zsh` is not on PATH. The suites this change owns passed before that stop. The zsh failure is the same environment limit recorded on the earlier help-page work.

## Cross-Phase Analysis

Preflight's two fixable fails were the expensive bugs, and they were caught before any code. A `git config --get` without `--local` would have honored a global account, and the planned suites set `GIT_CONFIG_GLOBAL=/dev/null`, so the bug would have stayed green. Setting only `GH_TOKEN` would have let a GitHub Enterprise Server command use the active account. Both were replanned, preflight passed, and build did not rediscover them.

The comment-scan advisory was the one preflight item build had to act on without a numbered test. The create template gained commented directives. A scan that matched those comments would make `git identity use` of a new identity fail. The extra test locks that. QA did not have to catch it.

The stale creative note is the causal chain in the other direction. The replan changed the token export and left the design record alone. QA then reported the drift, correctly, as an advisory rather than a defect. Updating the note in the replan would have removed that finding.

## Insights

### Technical

- A test harness that points `GIT_CONFIG_GLOBAL` at `/dev/null` cannot see a config read that falls through to global. The case has to set a global key on purpose.
- `git config --unset` inside a repository removes the local key and leaves a global key of the same name in place. It exits 5 with empty stderr when the local key is already absent.
- The create template is an identity file. A scan for `@gh-account` has to skip comments, or `git identity create` then `git identity use` fails on the placeholder line.

### Process

- When a replan overrides a creative implementation note, update the note in that same replan. Otherwise QA will keep comparing the code to the old sentence.
- A new test that passes on the first run is not evidence the behavior exists. Assert the setup that the later assertion depends on, or the test stays green while the feature is still a stub.
