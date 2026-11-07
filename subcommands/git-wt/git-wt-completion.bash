#!/usr/bin/env bash
#
# git-wt-completion.bash - Bash completion for git-wt / git wt / wt
#
# Source this file from bash. It is not a git subcommand and must not
# be executed.

# Complete local branch names after go.
#
# Globals:
#   COMP_WORDS, COMP_CWORD - bash completion state (read)
#   COMPREPLY - candidates (set)
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0
_git_wt() {
	local cur=""
	local prev=""

	if declare -F _get_comp_words_by_ref >/dev/null; then
		_get_comp_words_by_ref -n : cur prev
	else
		cur="${COMP_WORDS[COMP_CWORD]}"
		if (( COMP_CWORD > 0 )); then
			prev="${COMP_WORDS[COMP_CWORD - 1]}"
		fi
	fi

	COMPREPLY=()
	if [[ "${prev}" != go || "${cur}" == -* ]]; then
		return 0
	fi

	local branches branch_name
	branches="$(git --no-pager for-each-ref \
		--format='%(refname:short)' refs/heads/ 2>/dev/null || true)"
	while IFS= read -r branch_name; do
		[[ -n "${branch_name}" ]] || continue
		COMPREPLY+=("${branch_name}")
	done < <(compgen -W "${branches}" -- "${cur}")
	return 0
}

complete -F _git_wt git-wt
complete -F _git_wt wt

if declare -F __git_complete >/dev/null; then
	__git_complete wt _git_wt
fi
