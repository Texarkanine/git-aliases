#!/usr/bin/env bash
#
# Bash completion for git-identity
# This script provides tab completion for git-identity commands and identity names

# Define completion function using Git's own naming convention
_git_identity() {
	local cur prev
	_get_comp_words_by_ref -n : cur prev 2>/dev/null || return

	# If _get_comp_words_by_ref failed, try manual approach
	if [ -z "$cur" ]; then
		cur="${COMP_WORDS[COMP_CWORD]}"
		prev="${COMP_WORDS[COMP_CWORD-1]}"
	fi

	# Main git-identity commands
	local commands="list use create"
	
	# Handle different completion contexts
	case "$prev" in
		identity|git-identity)
			# Complete with available commands
			mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$cur")
			return 0
			;;
		use)
			# Complete with available identities for the use command
			local identities_dir="${HOME}/.git-identities"
			
			if [[ -d "${identities_dir}" ]]; then
				if identities=$(find "${identities_dir}" -type f -exec basename {} \; 2>/dev/null) && [[ -n $identities ]]; then
					mapfile -t COMPREPLY < <(compgen -W "$identities" -- "$cur")
				else
					# No identities found or find command failed
					COMPREPLY=()
				fi
			else
				# Directory doesn't exist
				COMPREPLY=()
			fi
			return 0
			;;
		create|list)
			# For these commands, we don't suggest anything specific
			return 0
			;;
	esac

	# Default to command names if no context is recognized
	mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$cur")
	return 0
}

# For standalone command git-identity
complete -F _git_identity git-identity

# For git's built-in completion system
if declare -F __git_complete >/dev/null; then
	# This allows git identity to use our custom completion
	# The _git_ prefix is important for Git's completion system
	__git_complete identity _git_identity
fi
