#!/bin/sh
#
# test-wt-wrappers.sh - Tests for bash/zsh wt() wrappers
#
# Sources shell/wt.bash under Homebrew/env bash and shell/wt.zsh under
# zsh -f. A mock git on PATH records `wt` invocations and prints fake
# paths so tests assert cd behavior without real worktrees.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
WRAPPER_BASH="${REPO_DIR}/shell/wt.bash"
WRAPPER_ZSH="${REPO_DIR}/shell/wt.zsh"

OPERATOR_HOME="${HOME}"
failures=0

# Prefer Homebrew bash when present so tests do not run on macOS 3.2.
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Absolute bash path on STDOUT
# Returns:
#   0 if bash is found
find_bash() {
	if [ -x /opt/homebrew/bin/bash ]; then
		printf '%s\n' /opt/homebrew/bin/bash
	elif [ -x /usr/local/bin/bash ]; then
		printf '%s\n' /usr/local/bin/bash
	else
		command -v bash
	fi
}

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

# Isolated HOME + mock git, then run a test body.
#
# Globals:
#   OPERATOR_HOME, WRAPPER_BASH, WRAPPER_ZSH, BASH_BIN
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
	ri_bin="${ri_home}/bin"
	ri_root="${ri_home}/mock-root"
	ri_start="${ri_home}/start"
	mkdir -p "${ri_bin}" "${ri_root}/wt-feature" "${ri_root}/main" "${ri_start}"
	cat > "${ri_bin}/git" <<'EOF'
#!/bin/sh
if [ "$1" != wt ]; then
	echo "mock git: unexpected: $*" >&2
	exit 1
fi
shift
sub=$1
shift
case ${sub} in
	go)
		printf '%s\n' "${MOCK_ROOT}/wt-${1}"
		;;
	done)
		if [ "$1" = inside ]; then
			printf '%s\n' "${MOCK_ROOT}/main"
		fi
		;;
	*)
		echo "mock git wt: unknown ${sub}" >&2
		exit 1
		;;
esac
EOF
	chmod +x "${ri_bin}/git"
	ri_status=0
	(
		HOME="${ri_home}"
		export HOME
		PATH="${ri_bin}:${PATH}"
		export PATH
		MOCK_ROOT="${ri_root}"
		export MOCK_ROOT
		START_DIR="${ri_start}"
		export START_DIR
		"${ri_body}"
	) || ri_status=$?
	rm -rf "${ri_home}"
	return "${ri_status}"
}

run_bash() {
	"${BASH_BIN}" -c "$1"
}

run_zsh() {
	zsh -f -c "$1"
}

test_bash_go_cds() {
	tbg_pwd=$(run_bash "
		. \"${WRAPPER_BASH}\"
		cd \"${START_DIR}\"
		wt go feature
		pwd
	")
	tbg_want="${MOCK_ROOT}/wt-feature"
	if [ "${tbg_pwd}" != "${tbg_want}" ]; then
		fail "bash wt go: expected ${tbg_want}, got ${tbg_pwd}"
	fi
}

test_zsh_go_cds() {
	tzg_pwd=$(run_zsh "
		. \"${WRAPPER_ZSH}\"
		cd \"${START_DIR}\"
		wt go feature
		pwd
	")
	tzg_want="${MOCK_ROOT}/wt-feature"
	if [ "${tzg_pwd}" != "${tzg_want}" ]; then
		fail "zsh wt go: expected ${tzg_want}, got ${tzg_pwd}"
	fi
}

test_bash_done_with_path_cds() {
	tbd_pwd=$(run_bash "
		. \"${WRAPPER_BASH}\"
		cd \"${START_DIR}\"
		wt done inside
		pwd
	")
	tbd_want="${MOCK_ROOT}/main"
	if [ "${tbd_pwd}" != "${tbd_want}" ]; then
		fail "bash wt done inside: expected ${tbd_want}, got ${tbd_pwd}"
	fi
}

test_zsh_done_with_path_cds() {
	tzd_pwd=$(run_zsh "
		. \"${WRAPPER_ZSH}\"
		cd \"${START_DIR}\"
		wt done inside
		pwd
	")
	tzd_want="${MOCK_ROOT}/main"
	if [ "${tzd_pwd}" != "${tzd_want}" ]; then
		fail "zsh wt done inside: expected ${tzd_want}, got ${tzd_pwd}"
	fi
}

test_bash_done_empty_stays() {
	tbe_pwd=$(run_bash "
		. \"${WRAPPER_BASH}\"
		cd \"${START_DIR}\"
		wt done outside
		pwd
	")
	if [ "${tbe_pwd}" != "${START_DIR}" ]; then
		fail "bash wt done outside should stay, got ${tbe_pwd}"
	fi
}

test_zsh_done_empty_stays() {
	tze_pwd=$(run_zsh "
		. \"${WRAPPER_ZSH}\"
		cd \"${START_DIR}\"
		wt done outside
		pwd
	")
	if [ "${tze_pwd}" != "${START_DIR}" ]; then
		fail "zsh wt done outside should stay, got ${tze_pwd}"
	fi
}

test_bash_help() {
	tbh_out=$(run_bash "
		. \"${WRAPPER_BASH}\"
		wt -h
	")
	tbh_rc=0
	run_bash "
		. \"${WRAPPER_BASH}\"
		wt -h
	" >/dev/null || tbh_rc=$?
	if [ "${tbh_rc}" -ne 0 ]; then
		fail "bash wt -h should return 0 (got ${tbh_rc})"
	fi
	case "${tbh_out}" in
		*go*) ;;
		*) fail "bash wt -h should mention go: ${tbh_out}" ;;
	esac
}

test_zsh_help() {
	tzh_out=$(run_zsh "
		. \"${WRAPPER_ZSH}\"
		wt -h
	")
	tzh_rc=0
	run_zsh "
		. \"${WRAPPER_ZSH}\"
		wt -h
	" >/dev/null || tzh_rc=$?
	if [ "${tzh_rc}" -ne 0 ]; then
		fail "zsh wt -h should return 0 (got ${tzh_rc})"
	fi
	case "${tzh_out}" in
		*go*) ;;
		*) fail "zsh wt -h should mention go: ${tzh_out}" ;;
	esac
}

test_bash_unknown() {
	tbu_out=$(run_bash "
		. \"${WRAPPER_BASH}\"
		cd \"${START_DIR}\"
		set +e
		wt foo 2>/dev/null
		echo RC:\$?
		pwd
	")
	case "${tbu_out}" in
		*RC:0*) fail "bash wt foo should be non-zero: ${tbu_out}" ;;
	esac
	case "${tbu_out}" in
		*"${START_DIR}"*) ;;
		*) fail "bash wt foo should not cd: ${tbu_out}" ;;
	esac
}

test_zsh_unknown() {
	tzu_out=$(run_zsh "
		. \"${WRAPPER_ZSH}\"
		cd \"${START_DIR}\"
		set +e
		wt foo 2>/dev/null
		echo RC:\$?
		pwd
	")
	case "${tzu_out}" in
		*RC:0*) fail "zsh wt foo should be non-zero: ${tzu_out}" ;;
	esac
	case "${tzu_out}" in
		*"${START_DIR}"*) ;;
		*) fail "zsh wt foo should not cd: ${tzu_out}" ;;
	esac
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
	if [ ! -f "${WRAPPER_BASH}" ] || [ ! -f "${WRAPPER_ZSH}" ]; then
		echo "FAIL: missing wrapper files" >&2
		exit 1
	fi
	BASH_BIN=$(find_bash)
	if [ -z "${BASH_BIN}" ]; then
		echo "FAIL: bash not found" >&2
		exit 1
	fi
	if ! command -v zsh >/dev/null; then
		echo "FAIL: zsh not found" >&2
		exit 1
	fi

	run_one test_bash_go_cds
	run_one test_zsh_go_cds
	run_one test_bash_done_with_path_cds
	run_one test_zsh_done_with_path_cds
	run_one test_bash_done_empty_stays
	run_one test_zsh_done_empty_stays
	run_one test_bash_help
	run_one test_zsh_help
	run_one test_bash_unknown
	run_one test_zsh_unknown

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All wt wrapper tests passed"
}

main "$@"
