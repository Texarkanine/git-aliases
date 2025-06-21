# git-identity

A Git subcommand to manage multiple Git identities with different configuration settings.

## Overview

`git-identity` allows you to create and switch between different Git identities, each with its own configuration settings such as name, email, and signing key. This is particularly useful when you work with multiple Git accounts or need to use different credentials for different projects.

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

### current

Show the currently active identity

```bash
git identity current
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

## Bash Completion

The project includes bash completion for git-identity commands and identity names. After installation, you can use tab completion to:

- Auto-complete git-identity commands (`list`, `use`, `current`, `create`)
- Auto-complete identity names when using the `use` command

### Installation

Bash completion is automatically installed when you run `make` or `make completions`. The installation:

1. Copies completion scripts to `~/.local/share/git-aliases/completions/`
2. Adds references to these scripts in `~/.bash_completion`

This ensures completions continue to work even if the original repository is moved or deleted.

If completions don't work immediately after installation:

1. Make sure the bash-completion package is installed on your system:
   ```bash
   sudo apt-get install bash-completion  # For Debian/Ubuntu
   ```

2. Source your bash completion file:
   ```bash
   source ~/.bash_completion
   ```

3. Or simply restart your shell session

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
