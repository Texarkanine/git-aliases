#!/bin/sh
#
# test-shellcheck.sh - Tests for scripts/run-shellcheck.sh and make shellcheck.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
RUNNER="${REPO_DIR}/scripts/run-shellcheck.sh"

failures=0

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

test_shellcheck_current_tree() {
	if ! make -C "${REPO_DIR}" shellcheck >/dev/null 2>&1; then
		fail "make shellcheck should pass on the current tree"
	fi
}

test_shellcheck_dirty_tree() {
	tdt_dir=$(mktemp -d)
	printf 'if\n' > "${tdt_dir}/bad.sh"
	tdt_rc=0
	"${RUNNER}" "${tdt_dir}" >/dev/null 2>&1 || tdt_rc=$?
	rm -rf "${tdt_dir}"
	if [ "${tdt_rc}" -eq 0 ]; then
		fail "run-shellcheck.sh should fail on a *.sh with an error-severity finding"
	fi
}

test_shellcheck_missing_from_path() {
	tmp_bin=$(mktemp -d)
	tmp_err=$(mktemp)
	tmp_rc=0
	PATH="${tmp_bin}" "${RUNNER}" >/dev/null 2>"${tmp_err}" || tmp_rc=$?
	if [ "${tmp_rc}" -eq 0 ]; then
		fail "run-shellcheck.sh should fail when shellcheck is not on PATH"
	fi
	if ! grep -q shellcheck "${tmp_err}"; then
		fail "missing-tool error should name shellcheck"
	fi
	rm -rf "${tmp_bin}"
	rm -f "${tmp_err}"
}

main() {
	test_shellcheck_current_tree
	test_shellcheck_dirty_tree
	test_shellcheck_missing_from_path

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi

	echo "All shellcheck runner tests passed"
}

main "$@"
