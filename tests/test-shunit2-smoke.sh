#!/bin/sh
#
# test-shunit2-smoke.sh - Prove bundled shunit2 can run a passing assertion.

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")

test_shunit2_equals() {
	assertEquals 1 1
}

# shellcheck disable=SC1091
. "${REPO_DIR}/shunit2"
