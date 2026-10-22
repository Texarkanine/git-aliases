#!/bin/sh
#
# test-git-identity.sh - Help-flag tests for the git-identity subcommand
#
# Runs under an isolated HOME and PATH. The tracked script is mode 644,
# so the test copies it and marks the copy executable.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
GIT_IDENTITY_SRC="${REPO_DIR}/subcommands/git-identity/git-identity.bash"

OPERATOR_HOME="${HOME}"
failures=0

# last_out / last_err / last_rc are set by invoke().

# Fail the current isolated test and abort the subshell.
#
# Globals:
#   None
# Arguments:
#   $* - failure message
# Outputs:
#   Message to STDERR
# Returns:
#   Does not return; exits 1 (safe: tests run in run_isolated subshells)
fail() {
	echo "FAIL: $*" >&2
	exit 1
}

# Run a command, capturing stdout, stderr, and exit status.
#
# Globals:
#   HOME - stderr capture file is written here
#   last_out, last_err, last_rc - set to captured results
# Arguments:
#   $@ - command to run
# Outputs:
#   None
# Returns:
#   0 (status is in last_rc)
invoke() {
	last_err="${HOME}/.git-identity-test-err"
	last_rc=0
	last_out=$("$@" 2>"${last_err}") || last_rc=$?
}

# Run a test body with HOME in a temp dir and git-identity first on PATH.
#
# Globals:
#   OPERATOR_HOME - real home; tests abort if isolation would not hold
#   TEST_BIN - directory containing the git-identity under test
# Arguments:
#   $1 - test body function name
# Outputs:
#   Test body stdout/stderr
# Returns:
#   Test body status, or 1 if HOME isolation cannot be established
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
		PATH="${TEST_BIN}:${PATH}"
		export PATH
		GIT_CONFIG_GLOBAL=/dev/null
		GIT_CONFIG_SYSTEM=/dev/null
		export GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
		"${ri_body}"
	) || ri_status=$?
	rm -rf "${ri_home}"
	return "${ri_status}"
}

test_help_flags() {
	thf_dir=$(mktemp -d)
	cd "${thf_dir}"
	invoke git-identity -h
	if [ "${last_rc}" -ne 0 ]; then
		fail "git-identity -h should exit 0 (got ${last_rc})"
	fi
	thf_usage="${last_out}"
	case "${thf_usage}" in
		*"Usage: git identity"*) ;;
		*) fail "git-identity -h should include Usage: git identity: ${thf_usage}" ;;
	esac
	invoke git-identity --help
	if [ "${last_rc}" -ne 0 ]; then
		fail "git-identity --help should exit 0 (got ${last_rc})"
	fi
	if [ "${last_out}" != "${thf_usage}" ]; then
		fail "git-identity --help should match -h: ${last_out}"
	fi
	invoke git identity -h
	if [ "${last_rc}" -ne 0 ]; then
		fail "git identity -h should exit 0 (got ${last_rc})"
	fi
	if [ "${last_out}" != "${thf_usage}" ]; then
		fail "git identity -h should match git-identity -h: ${last_out}"
	fi
}

test_nested_help_does_not_create() {
	tnh_dir=$(mktemp -d)
	cd "${tnh_dir}"
	invoke git-identity -h
	if [ "${last_rc}" -ne 0 ]; then
		fail "git-identity -h should exit 0 (got ${last_rc})"
	fi
	tnh_usage="${last_out}"
	for tnh_cmd in list use create; do
		for tnh_flag in -h --help; do
			invoke git identity "${tnh_cmd}" "${tnh_flag}"
			if [ "${last_rc}" -ne 0 ]; then
				fail "git identity ${tnh_cmd} ${tnh_flag} should exit 0 (got ${last_rc})"
			fi
			if [ "${last_out}" != "${tnh_usage}" ]; then
				fail "git identity ${tnh_cmd} ${tnh_flag} should match -h: ${last_out}"
			fi
		done
	done
	if [ -e "${HOME}/.git-identities" ]; then
		fail "create -h should not create ${HOME}/.git-identities"
	fi
}

test_list_outside_repo_fails() {
	tlr_dir=$(mktemp -d)
	cd "${tlr_dir}"
	invoke git identity list
	if [ "${last_rc}" -eq 0 ]; then
		fail "git identity list outside a repo should be non-zero"
	fi
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
	if [ ! -f "${GIT_IDENTITY_SRC}" ]; then
		echo "FAIL: missing ${GIT_IDENTITY_SRC}" >&2
		exit 1
	fi
	TEST_BIN=$(mktemp -d)
	cp "${GIT_IDENTITY_SRC}" "${TEST_BIN}/git-identity"
	chmod +x "${TEST_BIN}/git-identity"

	run_one test_help_flags
	run_one test_nested_help_does_not_create
	run_one test_list_outside_repo_fails

	rm -rf "${TEST_BIN}"

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All git-identity tests passed"
}

main "$@"
