#!/bin/sh
#
# test-trim.sh - Tests for POSIX whitespace trim used by install-aliases.sh
#
# Reproduces BSD sed corruption cases from memory-bank/active/bsd-sed.md.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
. "${REPO_DIR}/scripts/lib/trim.sh"

failures=0

assert_trim() {
	input="${1}"
	expected="${2}"
	label="${3}"

	actual=$(trim_whitespace "${input}")

	if [ "${actual}" != "${expected}" ]; then
		echo "FAIL: ${label}" >&2
		echo "  input:    '${input}'" >&2
		echo "  expected: '${expected}'" >&2
		echo "  actual:   '${actual}'" >&2
		failures=$((failures + 1))
	fi
}

main() {
	# BSD sed stripped trailing 't' from these values
	assert_trim "checkout" "checkout" "checkout unchanged"
	assert_trim "commit" "commit" "commit unchanged"
	assert_trim "short" "short" "short unchanged"
	assert_trim "last" "last" "last unchanged"
	assert_trim "hist" "hist" "hist unchanged"
	assert_trim "status" "status" "status unchanged"

	# st = status: name "st " must trim to "st", not "s"
	assert_trim "st " "st" "st with trailing space"
	assert_trim " status" "status" "status with leading space"
	assert_trim "  ci  " "ci" "ci with surrounding spaces"

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi

	echo "All trim tests passed"
}

main "$@"
