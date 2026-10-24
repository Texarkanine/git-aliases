# git-identity

A Git subcommand to manage multiple Git identities with different configuration settings.

## Overview

`git-identity` allows you to create and switch between different Git identities, each with its own set of `git config` settings (such as name, email, and signing key). This is particularly useful when you work with multiple Git accounts or need to use different credentials for different projects.

## Usage

```bash
git identity <command> [<args>]
```

`-h` or `--help`, including after `list`, `use`, or `create`, prints this summary.

### list

List all available identities

```bash
git identity list
```

### use

Switch to a specified identity

```bash
git identity use <identity-name>
```

### create

Create a new identity

```bash
git identity create <identity-name>
```

This creates a template configuration file that you can edit.

## Configuration

Identity configurations are stored in `~/.git-identities/`. Each identity is a file containing Git configuration settings.

### Example Identity File

```
# Git Identity Configuration for work
# Standard git config settings
user.name "John Doe"
user.email "john.doe@company.com"
# user.signingkey "YOUR_GPG_KEY_ID"
commit.gpgsign false

# Special directives (prefixed with @)
@hostname github-johndoe.com
@gh-account example-login
@gh-host ghe.example
```

### Special Directives

Special directives are prefixed with `@` and provide additional functionality:

#### @hostname

Automatically updates remote URLs to use the specified hostname.

Pair with a custom SSH host entry in `~/.ssh/config` to automatically use the correct SSH key for the identity, e.g.:

```
Host github-johndoe.com
	IdentityFile ~/.ssh/id_rsa_work
```

`@hostname` is the SSH alias. It is not the GitHub API host.

#### @gh-account

Names the GitHub login `gh` should use for this checkout. `git identity use` stores it as the local `github.account` value, which a linked worktree reads too. An identity file that omits `@gh-account` clears a login set by the previous identity.

Writing the key does not change `gh` by itself, and GitHub's CLI does not natively read it. `make subcommands` installs a `gh` shim that does: in this checkout it forces that login, and it exits without running the command when that login has no stored token.

#### @gh-host

Names the GitHub API host for that login, such as `ghe.example` for a GitHub Enterprise Server. `@gh-host` is the API host. Omit it for github.com. An identity file that omits `@gh-host` clears a host set by the previous identity.

The same shim passes this value to `gh auth token --hostname`. GitHub's CLI does not natively read `github.host`.

## Examples

### Creating and Using a Work Identity

```bash
# Create a new identity for work
git identity create work

# Edit the configuration file
nano ~/.git-identities/work

# Use the identity
git identity use work
```

### Creating and Using a Personal Identity

```bash
# Create a new identity for personal projects
git identity create personal

# Edit the configuration file
nano ~/.git-identities/personal

# Use the identity
git identity use personal
```
