#!/bin/sh
#
# test-bash-completion.sh - Bash completion tests for git-wt
#
# Invokes _git_wt via bash -c with COMP_WORDS set. Does not drive git <TAB>.
# Fails (does not skip) if bash is missing.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
WT_BASH="${REPO_DIR}/subcommands/git-wt/git-wt-completion.bash"

failures=0

if ! command -v bash >/dev/null 2>&1; then
	echo "ERROR: bash is required for test-bash-completion.sh but was not found on PATH" >&2
	exit 1
fi

# Fail the current check and count it.
#
# Globals:
#   failures - incremented
# Arguments:
#   $* - failure message
# Outputs:
#   Message to STDERR
# Returns:
#   Always returns 0 from this function; caller continues
fail() {
	echo "FAIL: $*" >&2
	failures=$((failures + 1))
}

# Create a throwaway git repo with one commit on main.
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Absolute repo path on STDOUT
# Returns:
#   0 on success
make_repo() {
	mr_dir=$(mktemp -d)
	git init -b main "${mr_dir}" >/dev/null
	git -C "${mr_dir}" config user.name test
	git -C "${mr_dir}" config user.email test@example.com
	printf 'x\n' > "${mr_dir}/file.txt"
	git -C "${mr_dir}" add file.txt
	git -C "${mr_dir}" commit -q --no-gpg-sign -m init
	printf '%s\n' "${mr_dir}"
}

# Source git-wt-completion.bash and print COMPREPLY, one name per line.
#
# Globals:
#   WT_BASH
# Arguments:
#   $1 - directory to cd into before completing
#   $@ - COMP_WORDS (the last word is the current word)
# Outputs:
#   Candidate names, one per line
# Returns:
#   Completer status
_complete_wt() {
	cw_dir=$1
	shift
	bash -c '
		cd "$2" || exit 1
		. "$1"
		shift 2
		COMP_WORDS=("$@")
		COMP_CWORD=$(($# - 1))
		COMPREPLY=()
		_git_wt
		if [ "${#COMPREPLY[@]}" -gt 0 ]; then
			printf "%s\n" "${COMPREPLY[@]}"
		fi
	' bash "${WT_BASH}" "${cw_dir}" "$@"
}

test_wt_go_completes_local_branches() {
	twg_repo=$(make_repo)
	git -C "${twg_repo}" branch other
	twg_out=$(_complete_wt "${twg_repo}" git wt go "")
	echo "${twg_out}" | grep -qx main || fail "git wt go should complete main: ${twg_out}"
	echo "${twg_out}" | grep -qx other || fail "git wt go should complete other: ${twg_out}"
	twg_out=$(_complete_wt "${twg_repo}" wt go "")
	echo "${twg_out}" | grep -qx main || fail "wt go should complete main: ${twg_out}"
	echo "${twg_out}" | grep -qx other || fail "wt go should complete other: ${twg_out}"
	twg_out=$(_complete_wt "${twg_repo}" git-wt go "")
	echo "${twg_out}" | grep -qx main || fail "git-wt go should complete main: ${twg_out}"
	echo "${twg_out}" | grep -qx other || fail "git-wt go should complete other: ${twg_out}"
	rm -rf "${twg_repo}"
}

test_wt_go_prefix_filters() {
	twp_repo=$(make_repo)
	git -C "${twp_repo}" branch other
	twp_out=$(_complete_wt "${twp_repo}" git wt go ma)
	echo "${twp_out}" | grep -qx main || fail "prefix ma should complete main: ${twp_out}"
	echo "${twp_out}" | grep -qx other && fail "prefix ma should not complete other: ${twp_out}"
	twp_out=$(_complete_wt "${twp_repo}" git wt go zz)
	if [ -n "${twp_out}" ]; then
		fail "prefix zz should complete nothing: ${twp_out}"
	fi
	rm -rf "${twp_repo}"
}

test_wt_without_go_completes_nothing() {
	twn_repo=$(make_repo)
	git -C "${twn_repo}" branch other
	twn_out=$(_complete_wt "${twn_repo}" git wt "")
	if [ -n "${twn_out}" ]; then
		fail "git wt should complete nothing: ${twn_out}"
	fi
	twn_out=$(_complete_wt "${twn_repo}" git wt done "")
	if [ -n "${twn_out}" ]; then
		fail "git wt done should complete nothing: ${twn_out}"
	fi
	rm -rf "${twn_repo}"
}

test_wt_ignores_remote_and_outside_repo() {
	twr_repo=$(make_repo)
	git -C "${twr_repo}" update-ref refs/remotes/origin/remote-only HEAD
	twr_out=$(_complete_wt "${twr_repo}" git wt go "")
	echo "${twr_out}" | grep -qx main || fail "local main should still complete: ${twr_out}"
	echo "${twr_out}" | grep -qx remote-only \
		&& fail "remote-only should not complete: ${twr_out}"
	echo "${twr_out}" | grep -qx origin/remote-only \
		&& fail "origin/remote-only should not complete: ${twr_out}"
	twr_dir=$(mktemp -d)
	twr_out=$(_complete_wt "${twr_dir}" git wt go "")
	if [ -n "${twr_out}" ]; then
		fail "outside a repo should complete nothing: ${twr_out}"
	fi
	rm -rf "${twr_repo}" "${twr_dir}"
}

test_wt_source_binds_git_wt_and_wt() {
	tws_out=$(bash -c '. "$1"' bash "${WT_BASH}")
	if [ -n "${tws_out}" ]; then
		fail "sourcing git-wt-completion.bash should print nothing: ${tws_out}"
	fi
	tws_bind=$(bash -c '. "$1"; complete -p git-wt; complete -p wt' bash "${WT_BASH}")
	echo "${tws_bind}" | grep -q 'git-wt' || fail "complete -p should bind git-wt: ${tws_bind}"
	echo "${tws_bind}" | grep -q ' _git_wt git-wt' \
		|| fail "git-wt should use _git_wt: ${tws_bind}"
	echo "${tws_bind}" | grep -q ' _git_wt wt' \
		|| fail "wt should use _git_wt: ${tws_bind}"
}

test_wt_does_not_call_git_complete() {
	twc_out=$(bash -c '
		__git_complete() { printf "called %s %s\n" "$1" "$2"; }
		. "$1"
		complete -p wt
	' bash "${WT_BASH}")
	echo "${twc_out}" | grep -q 'called ' \
		&& fail "should not call __git_complete: ${twc_out}"
	echo "${twc_out}" | grep -qx 'complete -F _git_wt wt' \
		|| fail "wt should stay bound to _git_wt: ${twc_out}"
}

test_bash_missing_fails() {
	tbm_bin=$(mktemp -d)
	ln -s "$(command -v dirname)" "${tbm_bin}/dirname"
	tbm_err=$(mktemp)
	tbm_rc=0
	PATH="${tbm_bin}" "${SCRIPT_DIR}/test-bash-completion.sh" >/dev/null 2>"${tbm_err}" || tbm_rc=$?
	rm -rf "${tbm_bin}"
	if [ "${tbm_rc}" -eq 0 ]; then
		rm -f "${tbm_err}"
		fail "suite should fail when bash is missing from PATH"
		return 0
	fi
	if ! grep -q bash "${tbm_err}"; then
		fail "missing-bash error should name bash: $(cat "${tbm_err}")"
	fi
	rm -f "${tbm_err}"
}

main() {
	if [ ! -f "${WT_BASH}" ]; then
		echo "FAIL: missing ${WT_BASH}" >&2
		exit 1
	fi

	test_wt_go_completes_local_branches
	test_wt_go_prefix_filters
	test_wt_without_go_completes_nothing
	test_wt_ignores_remote_and_outside_repo
	test_wt_source_binds_git_wt_and_wt
	test_wt_does_not_call_git_complete
	test_bash_missing_fails

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All bash completion tests passed"
}

main "$@"
