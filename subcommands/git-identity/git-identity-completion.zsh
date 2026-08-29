# git-identity-completion.zsh - Zsh completion for git-identity / git identity
#
# Source this file from zsh. It is not a git subcommand and must not be executed.
# Set GIT_ALIASES_COMPLETION_TEST=1 before sourcing to skip compdef registration.

# Complete git-identity and git identity: commands, or identity names after use.
#
# Globals:
#   words, CURRENT - zsh completion state
#   HOME - identity files live under ~/.git-identities
# Arguments:
#   None
# Outputs:
#   Candidates via compadd
# Returns:
#   0
_git_identity() {
	local gi_prev="${words[CURRENT - 1]}"
	local gi_commands="list use create"
	local gi_dir="${HOME}/.git-identities"
	local gi_names

	case "${gi_prev}" in
		identity|git-identity)
			compadd -- ${=gi_commands}
			return 0
			;;
		use)
			if [[ -d "${gi_dir}" ]]; then
				gi_names=$(find "${gi_dir}" -type f -exec basename {} \; 2>/dev/null)
				[[ -n "${gi_names}" ]] && compadd -- ${(f)gi_names}
			fi
			return 0
			;;
		create|list)
			return 0
			;;
	esac

	compadd -- ${=gi_commands}
	return 0
}

# Zsh native _git dispatcher entry for `git identity`.
#
# Globals:
#   words, CURRENT - zsh completion state
# Arguments:
#   None
# Outputs:
#   Candidates via compadd
# Returns:
#   0
_git-identity() {
	_git_identity
}

# Register standalone git-identity completion and git user-commands.
#
# Globals:
#   GIT_ALIASES_COMPLETION_TEST - skip registration when set
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0
_git_identity_register() {
	local -a gi_uc
	local gi_entry
	local gi_found=0

	if [[ -n "${GIT_ALIASES_COMPLETION_TEST:-}" ]]; then
		return 0
	fi
	if (( ! $+functions[compdef] )); then
		autoload -Uz compinit compdef
		compinit -C
	fi
	compdef _git_identity git-identity
	zstyle -a ':completion:*:*:git:*' user-commands gi_uc
	for gi_entry in "${gi_uc[@]}"; do
		if [[ "${gi_entry%%:*}" == identity ]]; then
			gi_found=1
			break
		fi
	done
	if (( ! gi_found )); then
		gi_uc+=(identity:'manage git identities')
		zstyle ':completion:*:*:git:*' user-commands "${gi_uc[@]}"
	fi
}

_git_identity_register
