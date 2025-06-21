# git-identity

A Git subcommand to manage multiple Git identities with different configuration settings.

## Overview

`git-identity` allows you to create and switch between different Git identities, each with its own set of `git config` settings (such as name, email, and signing key). This is particularly useful when you work with multiple Git accounts or need to use different credentials for different projects.

## Usage

```bash
git identity <command> [<args>]
```

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
