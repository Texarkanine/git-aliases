# Terminal issue investigation
_Exported on 6/16/2026 at 21:15:08 CDT from Cursor (3.7.42)_

---

**User**

@/Users/aerokita/.cursor/projects/Users-aerokita-git-git-aliases/terminals/1.txt:7-68 @/Users/aerokita/.cursor/projects/Users-aerokita-git-git-aliases/terminals/1.txt:69-115 and yet in a new terminal window... @/Users/aerokita/.cursor/projects/Users-aerokita-git-git-aliases/terminals/2.txt:7-18 what went wrong? Is this a zsh issue? or git? or something else?

make no changes to the system - only investigate and reason.

---

**Cursor**

Investigating how aliases are installed and why they appear truncated in `~/.gitconfig`.


Verifying the sed hypothesis — BSD sed may treat `\t` in character classes differently:


This is not a zsh issue, and not really a git issue either. The aliases were written into `~/.gitconfig` already corrupted during `make` — a new terminal reads the same broken config as the old one.

## Root cause: BSD `sed` on macOS

The install script trims whitespace with this pattern:

```43:44:scripts/install-aliases.sh
    				name=$(echo "$line" | cut -d'=' -f1 | sed 's/^[ \t]*//;s/[ \t]*$//')
    				value=$(echo "$line" | cut -d'=' -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')
```

On macOS `/usr/bin/sed` (BSD), `\t` inside `[ \t]` is **not** a tab — it matches a literal **`t`**. So `s/[ \t]*$//` strips trailing spaces **and trailing `t` characters**.

Verified locally:

| Input | After `sed 's/[ \t]*$//'` |
|-------|--------------------------|
| `checkout` | `checkou` |
| `commit` | `commi` |
| `short` | `shor` |
| `last` | `las` |
| `hist` | `his` |
| `status` | `status` (unchanged — ends in `s`) |

On Linux with GNU `sed`, `\t` in a bracket class is a tab, so this bug does not show up there.

## Why `make` looked “successful” but aliases are wrong

The install output already showed the corruption — easy to miss:

```
co -> checkou
ci -> commi
rba -> rebase --abor
his -> ... --date=shor
```

Those values were what `git config --global` actually stored. Your `~/.gitconfig` matches that output exactly.

## Why `git st` fails

Source file defines:

```1:8:aliases/status
st = status
co = checkout
...
s = status -sb
```

Parsing `st = status`:

1. Name `st ` → trim with broken sed → **`s`** (space + trailing `t` removed)
2. Value `status` → unchanged (ends in `s`)
3. That sets `alias.s = status`

Then `s = status -sb` runs and **overwrites** `alias.s` with `status -sb`.

So **`st` is never installed** — it collapses into `s` and gets replaced. Only `git s` works, not `git st`.

## Why `git ci` fails

`ci = commit` is stored as `ci = commi`. Git expands the alias and tries to run `commi`, which is not a command — hence:

> expansion of alias 'ci' failed; 'commi' is not a git command

(`agit` in the message is likely terminal line-wrap.)

## Not zsh, not “new terminal”

Git aliases live in `~/.gitconfig` and are expanded by git itself. Bash vs zsh vs a new window does not matter — every shell reads the same global config.

## Summary

| Symptom | Explanation |
|---------|-------------|
| `git st` unknown | `st` mangled to `s`, then overwritten by `s = status -sb` |
| `git ci` → `commi` | `commit` lost trailing `t` during install |
| `co`, `rba`, `short`, etc. broken | Same trailing-`t` stripping |
| Install “succeeded” | Script ran; it wrote bad values via `git config` |

**Fix direction** (for when you want to change things): replace `[ \t]` with a POSIX-safe trim — e.g. `$'s/[ \t]*$//'` with a real tab, or trim without `sed` character classes that differ between BSD and GNU sed. Re-run `make` after that to rewrite the aliases.

