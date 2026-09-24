#!/usr/bin/env bash
#
# git-wt - Create and tear down linked worktrees at a fixed path layout
#
# Worktrees live at ~/worktrees/<owner>/<repo>/<repo>-<branch>.
# go prints the absolute path on stdout; done and cleanup print the main
# checkout path only when cwd was inside a removed worktree.
#
# Usage: git wt <command>
#   go <name>           create a git worktree; print its path on stdout
#   done [name] [--force] [--yes]
#                       remove a worktree so the branch can be checked out
#                       in the main tree; omit name to use the current
#                       worktree; refuse if dirty unless --force; --yes
#                       skips the discard confirmation
#   cleanup [--all] [--list] [--yes] [--force] [+cursor]
#                       remove the worktrees go created in this repo (every
#                       repo with --all) after one confirmation; +cursor also
#                       includes linked worktrees under ~/.cursor/worktrees;
#                       --list prints their paths; dirty ones are skipped
#                       unless --force

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
  done [name] [--force] [--yes]
                      remove a worktree so the branch can be checked out
                      in the main tree; omit name to use the current
                      worktree; refuse if dirty unless --force; --yes
                      skips the discard confirmation
  cleanup [--all] [--list] [--yes] [--force] [+cursor]
                      remove the worktrees go created in this repo (every
                      repo with --all) after one confirmation; +cursor also
                      includes linked worktrees under ~/.cursor/worktrees;
                      --list prints their paths; dirty ones are skipped
                      unless --force
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

# Worktree path prefix for the current repository; append a branch name.
#
# Globals:
#   HOME - used as the worktrees root
# Arguments:
#   $1 - absolute path of the main checkout
# Outputs:
#   ~/worktrees/<owner>/<repo>/<repo>- on STDOUT
# Returns:
#   0
wt_layout_prefix() {
	local owner_repo owner repo
	owner_repo="$(wt_owner_repo "${1}")"
	owner="$(printf '%s\n' "${owner_repo}" | sed -n '1p')"
	repo="$(printf '%s\n' "${owner_repo}" | sed -n '2p')"
	printf '%s\n' "${HOME}/worktrees/${owner}/${repo}/${repo}-"
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
	printf '%s%s\n' "$(wt_layout_prefix "${main}")" "${name}"
}

# Worktrees of the current repository that git wt go created.
#
# A worktree counts when it exists on disk and its path is the layout
# path for the branch it has checked out. Git may record the physical
# path (macOS /private), so both logical and physical forms match.
#
# Globals:
#   HOME - used as the worktrees root
# Arguments:
#   None
# Outputs:
#   Layout paths on STDOUT, one per line
# Returns:
#   0
wt_created_worktrees() {
	local main prefix root_phys base
	main="$(wt_main_worktree)"
	prefix="$(wt_layout_prefix "${main}")"
	root_phys="$(CDPATH= cd "${prefix%/*}" 2>/dev/null && pwd -P)" || return 0
	base="${prefix##*/}"

	local wt_path branch
	while IFS=$'\t' read -r wt_path branch; do
		[[ -d "${wt_path}" ]] || continue
		if [[ "${wt_path}" == "${prefix}${branch}" \
			|| "${wt_path}" == "${root_phys}/${base}${branch}" ]]; then
			printf '%s\n' "${prefix}${branch}"
		fi
	done < <(git worktree list --porcelain | awk '
		$1 == "worktree" { path = substr($0, 10) }
		$1 == "branch" && index($2, "refs/heads/") == 1 {
			print path "\t" substr($2, 12)
		}
	')
}

# Linked worktrees of the current repository under ~/.cursor/worktrees.
#
# Includes a detached HEAD. Prints the HOME-logical path. The main
# checkout is not included.
#
# Globals:
#   HOME - cursor worktrees root
# Arguments:
#   None
# Outputs:
#   Paths on STDOUT, one per line
# Returns:
#   0
wt_cursor_worktrees() {
	local prefix="${HOME}/.cursor/worktrees"
	local prefix_phys main
	prefix_phys="$(CDPATH= cd "${prefix}" 2>/dev/null && pwd -P)" || prefix_phys=""
	main="$(wt_main_worktree)"
	git worktree list --porcelain | awk \
		-v logical="${prefix}" \
		-v physical="${prefix_phys}" \
		-v main="${main}" '
		function under(path, root) {
			return root != "" && index(path, root "/") == 1
		}
		function emit() {
			if (path == "" || path == main) {
				return
			}
			if (under(path, physical)) {
				path = logical "/" substr(path, length(physical) + 2)
			}
			if (under(path, logical)) {
				print path
			}
		}
		$1 == "worktree" {
			if (path != "") {
				emit()
			}
			path = substr($0, 10)
		}
		NF == 0 {
			emit()
			path = ""
		}
		END {
			if (path != "") {
				emit()
			}
		}
	'
}

# Worktree roots at or below a directory.
#
# Stops at the first directory holding .git, so it never walks worktree
# contents. Recursion covers branch names with slashes. Symlinks are not
# followed and depth is capped, so a stray non-worktree directory (loops,
# leftover node_modules) cannot hang the scan.
#
# Globals:
#   None
# Arguments:
#   $1 - directory to scan
#   $2 - remaining depth (optional, default 8)
# Outputs:
#   Worktree root paths on STDOUT, one per line
# Returns:
#   0
wt_scan_worktree_roots() {
	local dir="${1}"
	local depth="${2:-8}"
	if [[ -e "${dir}/.git" ]]; then
		printf '%s\n' "${dir}"
		return 0
	fi
	(( depth > 0 )) || return 0
	local sub
	for sub in "${dir}"/*/; do
		sub="${sub%/}"
		[[ -d "${sub}" && ! -L "${sub}" ]] || continue
		wt_scan_worktree_roots "${sub}" $(( depth - 1 ))
	done
}

# Main checkouts of every repository with a worktree under ~/worktrees.
#
# Only ~/worktrees/<owner>/<repo>/<repo>-* entries are scanned. Roots
# git cannot open (repository deleted) are skipped with a warning.
#
# Globals:
#   HOME - used as the worktrees root
# Arguments:
#   None
# Outputs:
#   Unique main checkout paths on STDOUT; warnings on STDERR
# Returns:
#   0
wt_all_mains() {
	local repo_dir name entry root main
	# Owners and repos may start with a dot (e.g. .github).
	local -a repo_dirs
	shopt -s dotglob
	repo_dirs=( "${HOME}/worktrees"/*/*/ )
	shopt -u dotglob
	for repo_dir in "${repo_dirs[@]}"; do
		[[ -d "${repo_dir}" ]] || continue
		name="$(basename "${repo_dir}")"
		for entry in "${repo_dir}${name}"-*/; do
			[[ -d "${entry}" ]] || continue
			while IFS= read -r root; do
				main="$(cd "${root}" 2>/dev/null && wt_main_worktree 2>/dev/null)" \
					|| main=""
				if [[ -z "${main}" ]]; then
					echo "wt: cleanup: skipping ${root}: not a usable worktree" >&2
					continue
				fi
				printf '%s\n' "${main}"
			done < <(wt_scan_worktree_roots "${entry%/}")
		done
	done | awk '!seen[$0]++'
}

# Main checkouts of every repository with a worktree under
# ~/.cursor/worktrees.
#
# Scanned roots are resolved to the main checkout. Roots git cannot
# open are skipped with a warning. Each main is printed once.
#
# Globals:
#   HOME - cursor worktrees root
# Arguments:
#   None
# Outputs:
#   Unique main checkout paths on STDOUT; warnings on STDERR
# Returns:
#   0
wt_all_cursor_mains() {
	local root main
	[[ -d "${HOME}/.cursor/worktrees" ]] || return 0
	while IFS= read -r root; do
		[[ -n "${root}" ]] || continue
		main="$(cd "${root}" 2>/dev/null && wt_main_worktree 2>/dev/null)" \
			|| main=""
		if [[ -z "${main}" ]]; then
			echo "wt: cleanup: skipping ${root}: not a usable worktree" >&2
			continue
		fi
		printf '%s\n' "${main}"
	done < <(wt_scan_worktree_roots "${HOME}/.cursor/worktrees") \
		| awk '!seen[$0]++'
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

# Whether cwd is a worktree or one of its subdirectories.
#
# Globals:
#   None
# Arguments:
#   $1 - worktree path
# Outputs:
#   None
# Returns:
#   0 if cwd is inside the worktree, 1 otherwise
wt_cwd_inside() {
	local wt_phys cwd_phys
	wt_phys="$(CDPATH= cd "${1}" 2>/dev/null && pwd -P)" || return 1
	cwd_phys="$(pwd -P 2>/dev/null)" || return 1
	[[ "${cwd_phys}" == "${wt_phys}" || "${cwd_phys}" == "${wt_phys}"/* ]]
}

# Remove ~/.cursor/worktrees/<name> when a removal left it empty.
#
# The session directory must be a direct child of ~/.cursor/worktrees.
# Logical and physical paths both match. A non-empty directory is left
# alone, as is anything outside that layout.
#
# Globals:
#   HOME - cursor worktrees root
# Arguments:
#   $1 - worktree path that was removed
# Outputs:
#   None
# Returns:
#   0
wt_remove_empty_cursor_session() {
	local wt_path="${1}"
	local session root logical physical
	session="$(dirname "${wt_path}")"
	root="$(dirname "${session}")"
	logical="${HOME}/.cursor/worktrees"
	physical="$(CDPATH= cd "${logical}" 2>/dev/null && pwd -P)" || physical=""
	if [[ "${root}" != "${logical}" && "${root}" != "${physical}" ]]; then
		return 0
	fi
	rmdir "${session}" 2>/dev/null || return 0
}

# Remove one linked worktree, then prune.
#
# A dirty worktree is refused unless force is 1. With force, the discard
# is confirmed on /dev/tty unless yes is 1.
#
# Globals:
#   None
# Arguments:
#   $1 - main checkout path of the worktree's repository
#   $2 - worktree path
#   $3 - force: 1 to remove a dirty worktree
#   $4 - yes: 1 to skip the discard confirmation
# Outputs:
#   Progress and prompt on STDERR / /dev/tty
# Returns:
#   0 on success, 1 if git cannot remove the worktree; exits 1 via
#   wt_die on refusal or a declined confirmation
wt_remove_worktree() {
	local main="${1}"
	local wt_path="${2}"
	local force="${3}"
	local yes="${4}"

	if wt_is_dirty "${wt_path}"; then
		if (( force == 0 )); then
			wt_die "done: worktree is dirty; commit, stash, or use --force"
		fi

		if (( yes == 0 )); then
			printf 'Discard uncommitted changes in %s? [y/N] ' \
				"${wt_path}" >/dev/tty
			local reply
			IFS= read -r reply </dev/tty
			case "${reply}" in
				[yY]|[yY][eE][sS]) ;;
				*) wt_die "done: aborted" ;;
			esac
		fi

		echo "Removing worktree (discarding changes): ${wt_path}" >&2
		git -C "${main}" worktree remove --force "${wt_path}" || return 1
	else
		echo "Removing worktree: ${wt_path}" >&2
		git -C "${main}" worktree remove "${wt_path}" || return 1
	fi

	git -C "${main}" worktree prune >/dev/null 2>&1 || true
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
#   optional positional branch name, optional --force, optional --yes|-y
# Outputs:
#   Main checkout path on STDOUT only if cwd was inside the worktree;
#   progress on STDERR
# Returns:
#   0 on success, non-zero on error
cmd_done() {
	local name=""
	local force=0
	local yes=0
	local arg
	for arg in "$@"; do
		case "${arg}" in
			--force)
				force=1
				;;
			--yes|-y)
				yes=1
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

	local in_wt=0
	if wt_cwd_inside "${wt_path}"; then
		in_wt=1
	fi

	wt_remove_worktree "${main}" "${wt_path}" "${force}" "${yes}"

	if (( in_wt == 1 )); then
		printf '%s\n' "${main}"
	fi
}

# List or remove the worktrees git wt go created.
#
# Globals:
#   HOME - used as the worktrees root
# Arguments:
#   optional --all, --list, --yes|-y, --force
# Outputs:
#   --list: worktree paths on STDOUT, one per line.
#   Otherwise: the main checkout path on STDOUT only if cwd was inside a
#   removed worktree; the worktree list and progress on STDERR
# Returns:
#   0 on success, non-zero on error or if any removal failed
cmd_cleanup() {
	local all=0
	local list=0
	local yes=0
	local force=0
	local cursor=0
	local arg
	for arg in "$@"; do
		case "${arg}" in
			--all)
				all=1
				;;
			--list)
				list=1
				;;
			--yes|-y)
				yes=1
				;;
			--force)
				force=1
				;;
			+cursor)
				cursor=1
				;;
			+*)
				wt_die "cleanup: unknown source: ${arg}"
				;;
			*)
				wt_die "cleanup: unknown option: ${arg}"
				;;
		esac
	done

	local -a mains=()
	local main
	if (( all == 1 )); then
		while IFS= read -r main; do
			[[ -n "${main}" ]] || continue
			mains+=( "${main}" )
		done < <(
			{
				wt_all_mains
				if (( cursor == 1 )); then
					wt_all_cursor_mains
				fi
			} | awk 'NF && !seen[$0]++'
		)
	else
		git rev-parse --git-dir >/dev/null 2>&1 \
			|| wt_die "cleanup: not inside a git repository"
		mains=( "$(wt_main_worktree)" )
	fi

	local -a row_mains=()
	local -a row_paths=()
	local i wt_path
	for (( i = 0; i < ${#mains[@]}; i++ )); do
		main="${mains[i]}"
		while IFS= read -r wt_path; do
			row_mains+=( "${main}" )
			row_paths+=( "${wt_path}" )
		done < <(cd "${main}" && wt_created_worktrees)
		if (( cursor == 1 )); then
			while IFS= read -r wt_path; do
				row_mains+=( "${main}" )
				row_paths+=( "${wt_path}" )
			done < <(cd "${main}" && wt_cursor_worktrees)
		fi
	done

	if (( list == 1 )); then
		for (( i = 0; i < ${#row_paths[@]}; i++ )); do
			printf '%s\n' "${row_paths[i]}"
		done
		return 0
	fi

	if (( ${#row_paths[@]} == 0 )); then
		echo "wt: cleanup: no worktrees to clean up" >&2
		return 0
	fi

	# Dirty and cwd state are taken before any removal: removing the
	# worktree that holds cwd would break later checks.
	local -a row_dirty=()
	local -a row_inside=()
	local note
	for (( i = 0; i < ${#row_paths[@]}; i++ )); do
		wt_path="${row_paths[i]}"
		note=""
		if wt_is_dirty "${wt_path}"; then
			row_dirty+=( 1 )
			if (( force == 1 )); then
				note=" (dirty; changes will be discarded)"
			else
				note=" (dirty; skipped without --force)"
			fi
		else
			row_dirty+=( 0 )
		fi
		if wt_cwd_inside "${wt_path}"; then
			row_inside+=( 1 )
		else
			row_inside+=( 0 )
		fi
		printf '  %s%s\n' "${wt_path}" "${note}" >&2
	done

	if (( yes == 0 )); then
		{ printf 'Remove these worktrees? [y/N] ' >/dev/tty; } 2>/dev/null \
			|| wt_die "cleanup: no terminal to confirm; use --yes"
		local reply
		IFS= read -r reply </dev/tty || reply=""
		case "${reply}" in
			[yY]|[yY][eE][sS]) ;;
			*) wt_die "cleanup: aborted" ;;
		esac
	fi

	local failures=0
	local cwd_main=""
	for (( i = 0; i < ${#row_paths[@]}; i++ )); do
		main="${row_mains[i]}"
		wt_path="${row_paths[i]}"
		if (( row_dirty[i] == 1 && force == 0 )); then
			echo "Skipping dirty worktree (use --force): ${wt_path}" >&2
			continue
		fi
		if ( cd "${main}" && wt_remove_worktree "${main}" "${wt_path}" "${force}" 1 ); then
			wt_remove_empty_cursor_session "${wt_path}"
			if (( row_inside[i] == 1 )); then
				cwd_main="${main}"
			fi
		else
			(( failures += 1 ))
		fi
	done

	if [[ -n "${cwd_main}" ]]; then
		printf '%s\n' "${cwd_main}"
	fi
	if (( failures > 0 )); then
		wt_die "cleanup: ${failures} worktree(s) could not be removed"
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
		cleanup)
			cmd_cleanup "$@"
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
