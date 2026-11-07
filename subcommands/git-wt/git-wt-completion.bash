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
	if [[ "${prev}" != go ]]; then
		return 0
	fi
	# git's own completion binds `git` with -o default. Without this,
	# an unmatched prefix falls through to filenames.
	compopt +o default 2>/dev/null || true
	if [[ "${cur}" == -* ]]; then
		return 0
	fi

	local branch_name
	while IFS= read -r branch_name; do
		[[ -n "${branch_name}" ]] || continue
		case "${branch_name}" in
			"${cur}"*) COMPREPLY+=("${branch_name}") ;;
		esac
	done < <(git --no-pager for-each-ref \
		--format='%(refname:strip=2)' refs/heads/ 2>/dev/null || true)
	return 0
}

complete -F _git_wt git-wt
complete -F _git_wt wt
