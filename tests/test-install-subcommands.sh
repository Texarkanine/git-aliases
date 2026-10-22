#!/bin/sh
#
# test-install-subcommands.sh - Tests for subcommand install help pages
#
# Runs the installer under a fake HOME so cat pages and binaries stay
# out of the operator's ~/.local.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
INSTALLER="${REPO_DIR}/scripts/install-subcommands.sh"

OPERATOR_HOME="${HOME}"
failures=0

# Fail the current isolated test and abort the subshell.
#
# Globals:
#   None
# Arguments:
#   $* - failure message
# Outputs:
#   Message to STDERR
# Returns:
#   Does not return; exits 1
fail() {
	echo "FAIL: $*" >&2
	exit 1
}

# Run an installer test with HOME in a temp dir.
#
# Globals:
#   OPERATOR_HOME, INSTALLER
# Arguments:
#   $1 - test body function name
# Outputs:
#   Test body stdout/stderr
# Returns:
#   Test body status
run_isolated() {
	ri_body="$1"
	ri_home=$(mktemp -d)
	if [ -z "${ri_home}" ] || [ "${ri_home}" = "${OPERATOR_HOME}" ]; then
		echo "FAIL: refused to run without isolated HOME" >&2
		return 1
	fi
	ri_status=0
	(
		HOME="${ri_home}"
		export HOME
		"${ri_body}"
	) || ri_status=$?
	rm -rf "${ri_home}"
	return "${ri_status}"
}

test_help_pages_match_dash_h() {
	if ! "${INSTALLER}"; then
		fail "install should succeed"
	fi
	if ! "${INSTALLER}"; then
		fail "second install should succeed"
	fi
	for thp_name in wt sync identity; do
		for thp_dir in "${HOME}/.local/man/cat1" "${HOME}/.local/share/man/cat1"; do
			if [ ! -f "${thp_dir}/git-${thp_name}.1" ]; then
				fail "missing ${thp_dir}/git-${thp_name}.1"
			fi
		done
		thp_want=$("${HOME}/.local/bin/git-${thp_name}" -h)
		thp_got=$(
			env -u MANPATH \
				PAGER=cat MANPAGER=cat GIT_PAGER=cat \
				PATH="${HOME}/.local/bin:${PATH}" \
				git "${thp_name}" --help
		) || fail "git ${thp_name} --help should exit 0"
		if [ "${thp_got}" != "${thp_want}" ]; then
			fail "git ${thp_name} --help should match -h: got [${thp_got}] want [${thp_want}]"
		fi
	done
}

test_uninstall_removes_help_pages() {
	if ! "${INSTALLER}"; then
		fail "install before uninstall should succeed"
	fi
	if ! "${INSTALLER}" --uninstall; then
		fail "uninstall should succeed"
	fi
	for tuh_name in wt sync identity; do
		for tuh_dir in "${HOME}/.local/man/cat1" "${HOME}/.local/share/man/cat1"; do
			if [ -e "${tuh_dir}/git-${tuh_name}.1" ]; then
				fail "uninstall should remove ${tuh_dir}/git-${tuh_name}.1"
			fi
		done
	done
}

run_one() {
	ro_name="$1"
	if run_isolated "${ro_name}"; then
		:
	else
		echo "FAIL: ${ro_name}" >&2
		failures=$((failures + 1))
	fi
}

main() {
	if [ ! -f "${INSTALLER}" ]; then
		echo "FAIL: missing ${INSTALLER}" >&2
		exit 1
	fi
	chmod +x "${INSTALLER}"

	run_one test_help_pages_match_dash_h
	run_one test_uninstall_removes_help_pages

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All install-subcommands tests passed"
}

main "$@"
