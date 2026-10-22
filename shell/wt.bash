# wt.bash - bash wrapper: wt go/done/cleanup auto-cd via git wt stdout
#
# Source this file from bash. It defines wt(); it is not a git subcommand
# and must not be executed.

# Return 0 when any argument asks for help.
#
# Globals:
#   None
# Arguments:
#   $@ - arguments to scan
# Outputs:
#   None
# Returns:
#   0 if an argument is -h or --help, 1 otherwise
wt_help_requested() {
	local arg
	for arg in "$@"; do
		case "${arg}" in
			-h|--help)
				return 0
				;;
		esac
	done
	return 1
}

# Interactive wrapper around git wt that cds on a printed path.
#
# Globals:
#   None (uses git on PATH)
# Arguments:
#   $1 - command: go, done, cleanup, help, -h, --help
#   $@ - remaining args forwarded to git wt
# Outputs:
#   Usage on STDOUT for help; git wt stderr is inherited
# Returns:
#   0 on success, git wt status on failure, 1 for unknown command
wt() {
	case "${1:-}" in
		go)
			if wt_help_requested "${@:2}"; then
				wt --help
				return $?
			fi
			local wt_path
			wt_path="$(git wt go "${@:2}")" || return $?
			cd "${wt_path}" || return $?
			;;
		done)
			if wt_help_requested "${@:2}"; then
				wt --help
				return $?
			fi
			local dest
			dest="$(git wt done "${@:2}")" || return $?
			if [[ -n "${dest}" ]]; then
				cd "${dest}" || return $?
			fi
			;;
		cleanup)
			if wt_help_requested "${@:2}"; then
				wt --help
				return $?
			fi
			local arg
			for arg in "${@:2}"; do
				if [[ "${arg}" == "--list" ]]; then
					git wt cleanup "${@:2}"
					return $?
				fi
			done
			# cd even when cleanup fails: a printed path means cwd was removed.
			local dest rc=0
			dest="$(git wt cleanup "${@:2}")" || rc=$?
			if [[ -n "${dest}" ]]; then
				cd "${dest}" || return $?
			fi
			return "${rc}"
			;;
		""|help|-h|--help)
			cat <<'EOF'
usage: wt <command>
  go <name>           create a git worktree and switch to it
  done [name] [--force] [--yes]
                      remove a worktree so the branch can be checked out
                      in the main tree; omit name to use the current
                      worktree; refuse if dirty unless --force; --yes
                      skips the discard confirmation
  cleanup [--all] [--list] [--yes] [--force] [+cursor]
                      remove worktrees git wt go created; +cursor also
                      includes ~/.cursor/worktrees; switch to main if the
                      current one was removed
EOF
			;;
		*)
			echo "wt: unknown command: ${1}" >&2
			return 1
			;;
	esac
}
