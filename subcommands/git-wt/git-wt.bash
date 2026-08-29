#!/usr/bin/env bash
#
# git-wt - Create and tear down linked worktrees at a fixed path layout
#
# Worktrees live at ~/worktrees/<owner>/<repo>/<repo>-<branch>.
# go prints the absolute path on stdout; done prints the main checkout
# path only when cwd was inside the removed worktree.
#
# Usage: git wt <command>
#   go <name>           create a git worktree; print its path on stdout
#   done [name] [--force]
#                       remove a worktree so the branch can be checked out
#                       in the main tree; omit name to use the current
#                       worktree; refuse if dirty unless --force

set -euo pipefail

# Print usage text.
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Usage on STDOUT
# Returns:
#   0
usage() {
	cat <<'EOF'
usage: git wt <command>
  go <name>           create a git worktree; print its path on stdout
  done [name] [--force]
                      remove a worktree so the branch can be checked out
                      in the main tree; omit name to use the current
                      worktree; refuse if dirty unless --force
EOF
}

# Print an error and abort.
#
# Globals:
#   None
# Arguments:
#   $* - error message
# Outputs:
#   Message prefixed with "wt: " on STDERR
# Returns:
#   Does not return; exits 1
wt_die() {
	echo "wt: $*" >&2
	exit 1
}

# Absolute path of the main checkout (first worktree list entry).
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Absolute path on STDOUT
# Returns:
#   0 on success, non-zero if not inside a git repository
wt_main_worktree() {
	git worktree list --porcelain \
		| awk '$1 == "worktree" { print substr($0, 10); exit }'
}

# Owner and repo names for the path layout.
#
# Prefers origin, else the first remote. Parses owner/repo as the last two
# path segments after stripping a trailing .git (scp-style and HTTPS).
# With no remote: owner=local, repo=basename of the main checkout.
#
# Globals:
#   None
# Arguments:
#   $1 - absolute path of the main checkout
# Outputs:
#   Two lines on STDOUT: owner, then repo
# Returns:
#   0
wt_owner_repo() {
	local main="${1}"
	local owner="local"
	local repo
	repo="$(basename "${main}")"
	local url=""

	if git remote get-url origin >/dev/null 2>&1; then
		url="$(git remote get-url origin)"
	else
		url="$(git remote -v 2>/dev/null | awk 'NF >= 2 { print $2; exit }')" \
			|| true
	fi

	if [[ -n "${url}" ]]; then
		url="${url%/}"
		url="${url%.git}"
		url="${url%/}"
		if [[ "${url}" == *://* ]]; then
			url="${url#*://}"
		fi
		url="${url/:/\/}"
		repo="${url##*/}"
		local tmp="${url%/*}"
		owner="${tmp##*/}"
	fi

	printf '%s\n' "${owner}" "${repo}"
}

# Computed worktree path for a branch name.
#
# Globals:
#   HOME - used as the worktrees root
# Arguments:
#   $1 - branch name
# Outputs:
#   Absolute path on STDOUT
# Returns:
#   0 on success
wt_worktree_path() {
	local name="${1}"
	local main
	main="$(wt_main_worktree)" || wt_die "not inside a git repository"
	local owner_repo owner repo
	owner_repo="$(wt_owner_repo "${main}")"
	owner="$(printf '%s\n' "${owner_repo}" | sed -n '1p')"
	repo="$(printf '%s\n' "${owner_repo}" | sed -n '2p')"
	printf '%s\n' "${HOME}/worktrees/${owner}/${repo}/${repo}-${name}"
}

# Path of the linked worktree that contains cwd, or empty.
#
# Uses git-dir vs git-common-dir so a worktree nested inside the main
# checkout is not mistaken for main. Empty in the main checkout.
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Absolute worktree path on STDOUT, or empty
# Returns:
#   0
wt_worktree_containing_cwd() {
	local git_dir common
	git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null)" || return 0
	common="$(git rev-parse --git-common-dir 2>/dev/null)" || return 0
	git_dir="$(CDPATH= cd "${git_dir}" && pwd -P)"
	common="$(CDPATH= cd "${common}" && pwd -P)"
	if [[ "${git_dir}" == "${common}" ]]; then
		return 0
	fi
	git rev-parse --show-toplevel
}

# Path of the worktree that currently has the given branch checked out.
#
# Globals:
#   None
# Arguments:
#   $1 - branch name
# Outputs:
#   Absolute path on STDOUT, or empty if none
# Returns:
#   0
wt_worktree_for_branch() {
	local branch="${1}"
	git worktree list --porcelain | awk -v branch="refs/heads/${branch}" '
		$1 == "worktree" { path = substr($0, 10) }
		$1 == "branch" && $2 == branch { print path; exit }
	'
}

# Whether a worktree has uncommitted changes.
#
# Globals:
#   None
# Arguments:
#   $1 - worktree path
# Outputs:
#   None
# Returns:
#   0 if dirty, 1 if clean
wt_is_dirty() {
	local wt_path="${1}"
	[[ -n "$(git -C "${wt_path}" status --porcelain)" ]]
}

# Create or reuse a linked worktree; print its path.
#
# Globals:
#   HOME - used as the worktrees root
# Arguments:
#   $1 - branch name
# Outputs:
#   Absolute worktree path on STDOUT; progress on STDERR
# Returns:
#   0 on success, non-zero on error
cmd_go() {
	local name="${1:-}"
	[[ -n "${name}" ]] || wt_die "go: branch name required"

	git rev-parse --git-dir >/dev/null 2>&1 \
		|| wt_die "go: not inside a git repository"
	git check-ref-format --branch "${name}" >/dev/null 2>&1 \
		|| wt_die "go: invalid branch name: ${name}"

	local wt_path
	wt_path="$(wt_worktree_path "${name}")"
	mkdir -p "$(dirname "${wt_path}")"

	# -e .git (file or directory) so a logical HOME path matches a
	# worktree git created via a physical /private path on macOS.
	if [[ -e "${wt_path}/.git" ]]; then
		printf '%s\n' "${wt_path}"
		return 0
	fi

	if [[ -e "${wt_path}" ]]; then
		wt_die "go: path exists but is not a worktree: ${wt_path}"
	fi

	if git show-ref --verify --quiet "refs/heads/${name}"; then
		echo "Creating worktree at ${wt_path} (existing branch ${name})" >&2
		git worktree add "${wt_path}" "${name}" >&2
	else
		echo "Creating worktree at ${wt_path} (new branch ${name})" >&2
		git worktree add -b "${name}" "${wt_path}" >&2
	fi

	printf '%s\n' "${wt_path}"
}

# Remove a linked worktree so its branch can be checked out in main.
#
# Globals:
#   None
# Arguments:
#   optional positional branch name and optional --force
# Outputs:
#   Main checkout path on STDOUT only if cwd was inside the worktree;
#   progress on STDERR
# Returns:
#   0 on success, non-zero on error
cmd_done() {
	local name=""
	local force=0
	local arg
	for arg in "$@"; do
		case "${arg}" in
			--force)
				force=1
				;;
			-*)
				wt_die "done: unknown option: ${arg}"
				;;
			*)
				if [[ -n "${name}" ]]; then
					wt_die "done: unexpected argument: ${arg}"
				fi
				name="${arg}"
				;;
		esac
	done

	git rev-parse --git-dir >/dev/null 2>&1 \
		|| wt_die "done: not inside a git repository"

	local main wt_path
	main="$(wt_main_worktree)"
	if [[ -n "${name}" ]]; then
		wt_path="$(wt_worktree_for_branch "${name}")"
		[[ -n "${wt_path}" ]] \
			|| wt_die "done: no worktree for branch ${name}"
	else
		wt_path="$(wt_worktree_containing_cwd)"
		[[ -n "${wt_path}" ]] \
			|| wt_die "done: refusing to remove the main checkout"
	fi

	if [[ "${wt_path}" == "${main}" ]]; then
		wt_die "done: refusing to remove the main checkout"
	fi

	local cwd_phys wt_phys in_wt=0
	cwd_phys="$(pwd -P)"
	wt_phys="$(CDPATH= cd "${wt_path}" && pwd -P)"
	case "${cwd_phys}" in
		"${wt_phys}"|"${wt_phys}"/*)
			in_wt=1
			;;
	esac

	if wt_is_dirty "${wt_path}"; then
		if (( force == 0 )); then
			wt_die "done: worktree is dirty; commit, stash, or use --force"
		fi

		printf 'Discard uncommitted changes in %s? [y/N] ' \
			"${wt_path}" >/dev/tty
		local reply
		IFS= read -r reply </dev/tty
		case "${reply}" in
			[yY]|[yY][eE][sS]) ;;
			*) wt_die "done: aborted" ;;
		esac

		echo "Removing worktree (discarding changes): ${wt_path}" >&2
		git worktree remove --force "${wt_path}"
	else
		echo "Removing worktree: ${wt_path}" >&2
		git worktree remove "${wt_path}"
	fi

	git worktree prune >/dev/null 2>&1 || true

	if (( in_wt == 1 )); then
		printf '%s\n' "${main}"
	fi
}

# Dispatch git wt subcommands.
#
# Globals:
#   None
# Arguments:
#   $@ - command line
# Outputs:
#   Command-dependent
# Returns:
#   Command exit status
main() {
	if (( $# == 0 )); then
		usage >&2
		exit 1
	fi

	local cmd="$1"
	shift
	case "${cmd}" in
		go)
			cmd_go "$@"
			;;
		done)
			cmd_done "$@"
			;;
		help|-h|--help)
			usage
			;;
		*)
			wt_die "unknown command: ${cmd}"
			;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
