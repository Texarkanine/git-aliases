# git-wt-completion.zsh - Zsh completion for git-wt / git wt / wt
#
# Source this file from zsh. It is not a git subcommand and must not be executed.
# Set GIT_ALIASES_COMPLETION_TEST=1 before sourcing to skip compdef registration.

# Complete local branch names after go.
#
# Globals:
#   words, CURRENT - zsh completion state
# Arguments:
#   None
# Outputs:
#   Candidates via compadd
# Returns:
#   0
_git_wt() {
	local gw_prev="${words[CURRENT - 1]}"
	local gw_branches

	if [[ "${gw_prev}" != go ]]; then
		return 0
	fi

	gw_branches=$(git --no-pager for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)
	[[ -n "${gw_branches}" ]] && compadd -- ${(f)gw_branches}
	return 0
}

# Zsh native _git dispatcher entry for `git wt`.
#
# Globals:
#   words, CURRENT - zsh completion state
# Arguments:
#   None
# Outputs:
#   Candidates via compadd
# Returns:
#   0
_git-wt() {
	_git_wt
}

# Register standalone git-wt and wt completion, and git user-commands.
#
# Globals:
#   GIT_ALIASES_COMPLETION_TEST - skip registration when set
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0
_git_wt_register() {
	local -a gw_uc
	local gw_entry
	local gw_found=0

	if [[ -n "${GIT_ALIASES_COMPLETION_TEST:-}" ]]; then
		return 0
	fi
	if (( ! $+functions[compdef] )); then
		autoload -Uz compinit compdef
		compinit -C
	fi
	compdef _git_wt git-wt
	compdef _git_wt wt
	zstyle -a ':completion:*:*:git:*' user-commands gw_uc
	for gw_entry in "${gw_uc[@]}"; do
		if [[ "${gw_entry%%:*}" == wt ]]; then
			gw_found=1
			break
		fi
	done
	if (( ! gw_found )); then
		gw_uc+=(wt:'create or enter a linked worktree')
		zstyle ':completion:*:*:git:*' user-commands "${gw_uc[@]}"
	fi
}

_git_wt_register
