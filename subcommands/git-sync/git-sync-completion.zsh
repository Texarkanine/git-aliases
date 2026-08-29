# git-sync-completion.zsh - Zsh completion for git-sync / git sync
#
# Source this file from zsh. It is not a git subcommand and must not be executed.
# Set GIT_ALIASES_COMPLETION_TEST=1 before sourcing to skip compdef registration.

# Complete git-sync and git sync: local branches, or flags when cur starts with a dash.
#
# Globals:
#   words, CURRENT - zsh completion state
# Arguments:
#   None
# Outputs:
#   Candidates via compadd
# Returns:
#   0
_git_sync() {
	local gs_prev="${words[CURRENT - 1]}"
	local gs_cur="${words[CURRENT]}"
	local gs_branches
	local gs_opts="-m --merge -h --help"

	gs_branches=$(git --no-pager for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)

	case "${gs_prev}" in
		git-sync|sync)
			if [[ "${gs_cur}" == -* ]]; then
				compadd -- ${=gs_opts}
			else
				[[ -n "${gs_branches}" ]] && compadd -- ${(f)gs_branches}
			fi
			return 0
			;;
		-m|--merge)
			[[ -n "${gs_branches}" ]] && compadd -- ${(f)gs_branches}
			return 0
			;;
		-h|--help)
			return 0
			;;
	esac

	if [[ "${gs_cur}" == -* ]]; then
		compadd -- ${=gs_opts}
	else
		[[ -n "${gs_branches}" ]] && compadd -- ${(f)gs_branches}
	fi
	return 0
}

# Zsh native _git dispatcher entry for `git sync`.
#
# Globals:
#   words, CURRENT - zsh completion state
# Arguments:
#   None
# Outputs:
#   Candidates via compadd
# Returns:
#   0
_git-sync() {
	_git_sync
}

# Register standalone git-sync completion and git user-commands.
#
# Globals:
#   GIT_ALIASES_COMPLETION_TEST - skip registration when set
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0
_git_sync_register() {
	local -a gs_uc
	local gs_entry
	local gs_found=0

	if [[ -n "${GIT_ALIASES_COMPLETION_TEST:-}" ]]; then
		return 0
	fi
	if (( ! $+functions[compdef] )); then
		autoload -Uz compinit compdef
		compinit -C
	fi
	compdef _git_sync git-sync
	zstyle -a ':completion:*:*:git:*' user-commands gs_uc
	for gs_entry in "${gs_uc[@]}"; do
		if [[ "${gs_entry%%:*}" == sync ]]; then
			gs_found=1
			break
		fi
	done
	if (( ! gs_found )); then
		gs_uc+=(sync:'synchronize current branch with another')
		zstyle ':completion:*:*:git:*' user-commands "${gs_uc[@]}"
	fi
}

_git_sync_register
