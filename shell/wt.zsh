# wt.zsh - zsh wrapper: wt go/done auto-cd via git wt stdout
#
# Source this file from zsh. It defines wt(); it is not a git subcommand
# and must not be executed.

# Interactive wrapper around git wt that cds on a printed path.
#
# Globals:
#   None (uses git on PATH)
# Arguments:
#   $1 - command: go, done, help, -h, --help
#   $@ - remaining args forwarded to git wt
# Outputs:
#   Usage on STDOUT for help; git wt stderr is inherited
# Returns:
#   0 on success, git wt status on failure, 1 for unknown command
wt() {
	case "${1:-}" in
		go)
			local wt_path
			wt_path="$(git wt go "${@:2}")" || return $?
			cd "${wt_path}" || return $?
			;;
		done)
			local dest
			dest="$(git wt done "${@:2}")" || return $?
			if [[ -n "${dest}" ]]; then
				cd "${dest}" || return $?
			fi
			;;
		""|help|-h|--help)
			cat <<'EOF'
usage: wt <command>
  go <name>           create a git worktree and switch to it
  done [name] [--force]
                      remove a worktree so the branch can be checked out
                      in the main tree; omit name to use the current
                      worktree; refuse if dirty unless --force
EOF
			;;
		*)
			echo "wt: unknown command: ${1}" >&2
			return 1
			;;
	esac
}
