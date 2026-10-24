#!/bin/sh
#
# test-git-identity.sh - Tests for the git-identity subcommand
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

# Write an identity file under the isolated HOME.
#
# Globals:
#   HOME - identities directory is created here
# Arguments:
#   $1 - identity name
#   stdin - file body
# Outputs:
#   None
# Returns:
#   0 on success
write_identity() {
	wi_name="$1"
	mkdir -p "${HOME}/.git-identities"
	cat > "${HOME}/.git-identities/${wi_name}"
}

# Create an empty git repository and enter it.
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   Does not return on failure
init_repo() {
	ir_dir=$(mktemp -d)
	if ! git init -q "${ir_dir}"; then
		fail "git init failed"
	fi
	cd "${ir_dir}" || fail "cd ${ir_dir} failed"
}

test_use_sets_github_account() {
	init_repo
	write_identity pinned <<'EOF'
user.email "person@example.com"
@gh-account example-login
EOF
	invoke git identity use pinned
	if [ "${last_rc}" -ne 0 ]; then
		fail "use with @gh-account should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	tusa_account=$(git config --local --get github.account 2>/dev/null) || tusa_account=""
	if [ "${tusa_account}" != "example-login" ]; then
		fail "github.account should be example-login (got ${tusa_account})"
	fi
}

test_use_without_gh_account_clears_pin() {
	init_repo
	write_identity pinned <<'EOF'
@gh-account example-login
EOF
	invoke git identity use pinned
	if [ "${last_rc}" -ne 0 ]; then
		fail "use that sets the pin should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	tuc_account=$(git config --local --get github.account 2>/dev/null) || tuc_account=""
	if [ "${tuc_account}" != "example-login" ]; then
		fail "github.account should be example-login before the clearing identity (got ${tuc_account})"
	fi
	write_identity plain <<'EOF'
user.email "person@example.com"
EOF
	invoke git identity use plain
	if [ "${last_rc}" -ne 0 ]; then
		fail "use without @gh-account should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	if git config --local --get github.account >/dev/null 2>&1; then
		fail "github.account should be unset after an identity with no @gh-account"
	fi
}

test_use_sets_github_host() {
	init_repo
	write_identity hosted <<'EOF'
@gh-host ghe.example
EOF
	invoke git identity use hosted
	if [ "${last_rc}" -ne 0 ]; then
		fail "use with @gh-host should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	tush_host=$(git config --local --get github.host 2>/dev/null) || tush_host=""
	if [ "${tush_host}" != "ghe.example" ]; then
		fail "github.host should be ghe.example (got ${tush_host})"
	fi
	write_identity plain <<'EOF'
user.email "person@example.com"
EOF
	invoke git identity use plain
	if [ "${last_rc}" -ne 0 ]; then
		fail "use without @gh-host should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	if git config --local --get github.host >/dev/null 2>&1; then
		fail "github.host should be unset after an identity with no @gh-host"
	fi
}

test_hostname_does_not_set_github_host() {
	init_repo
	if ! git remote add origin git@github.com:example/repo.git; then
		fail "git remote add failed"
	fi
	write_identity vanity <<'EOF'
@hostname vanity.example
EOF
	invoke git identity use vanity
	if [ "${last_rc}" -ne 0 ]; then
		fail "use with @hostname should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	thn_url=$(git remote get-url origin)
	if [ "${thn_url}" != "git@vanity.example:example/repo.git" ]; then
		fail "remote host should be vanity.example (got ${thn_url})"
	fi
	if git config --local --get github.host >/dev/null 2>&1; then
		fail "@hostname should leave github.host unset"
	fi
}

# Reject a pin directive and apply nothing from the file.
#
# Globals:
#   None
# Arguments:
#   $1 - identity body, including the bad directive
#   $2 - failure label
# Outputs:
#   None
# Returns:
#   Does not return on failure
assert_pin_directive_rejected() {
	ap_body="$1"
	ap_label="$2"
	init_repo
	if ! git config user.name "Keep Me"; then
		fail "git config user.name failed"
	fi
	printf '%s\n' "${ap_body}" | write_identity bad
	invoke git identity use bad
	if [ "${last_rc}" -eq 0 ]; then
		fail "${ap_label} should exit non-zero"
	fi
	if git config --local --get user.email >/dev/null 2>&1; then
		fail "${ap_label} should not apply user.email"
	fi
	ap_name=$(git config --local --get user.name)
	if [ "${ap_name}" != "Keep Me" ]; then
		fail "${ap_label} should leave user.name untouched (got ${ap_name})"
	fi
}

test_gh_account_empty_fails() {
	assert_pin_directive_rejected 'user.email "person@example.com"
@gh-account ""' '@gh-account ""'
}

test_bare_gh_account_fails() {
	assert_pin_directive_rejected 'user.email "person@example.com"
@gh-account' 'bare @gh-account'
}

test_gh_host_empty_fails() {
	assert_pin_directive_rejected 'user.email "person@example.com"
@gh-host ""' '@gh-host ""'
}

test_bare_gh_host_fails() {
	assert_pin_directive_rejected 'user.email "person@example.com"
@gh-host' 'bare @gh-host'
}

test_create_then_use_exits_zero() {
	init_repo
	invoke git identity create fresh
	if [ "${last_rc}" -ne 0 ]; then
		fail "create should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	invoke git identity use fresh
	if [ "${last_rc}" -ne 0 ]; then
		fail "use of a new identity should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
}

test_use_without_pin_exits_zero() {
	init_repo
	write_identity plain <<'EOF'
user.email "person@example.com"
EOF
	invoke git identity use plain
	if [ "${last_rc}" -ne 0 ]; then
		fail "use with no pin directive should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	if git config --local --get github.account >/dev/null 2>&1; then
		fail "use with no pin directive should leave github.account unset"
	fi
}

test_worktree_sees_github_account() {
	init_repo
	if ! git config user.name "Test Person"; then
		fail "git config user.name failed"
	fi
	if ! git config user.email "person@example.com"; then
		fail "git config user.email failed"
	fi
	if ! git commit -q --allow-empty -m init; then
		fail "git commit failed"
	fi
	tw_core=$(pwd)
	tw_linked="${tw_core}-linked"
	if ! git worktree add "${tw_linked}" HEAD >/dev/null; then
		fail "git worktree add failed"
	fi
	write_identity pinned <<'EOF'
@gh-account example-login
EOF
	invoke git identity use pinned
	if [ "${last_rc}" -ne 0 ]; then
		fail "use on the core checkout should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	tw_seen=$(git -C "${tw_linked}" config --local --get github.account 2>/dev/null) || tw_seen=""
	if [ "${tw_seen}" != "example-login" ]; then
		fail "linked worktree should see example-login (got ${tw_seen})"
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
	run_one test_use_sets_github_account
	run_one test_use_without_gh_account_clears_pin
	run_one test_use_sets_github_host
	run_one test_hostname_does_not_set_github_host
	run_one test_gh_account_empty_fails
	run_one test_bare_gh_account_fails
	run_one test_gh_host_empty_fails
	run_one test_bare_gh_host_fails
	run_one test_create_then_use_exits_zero
	run_one test_use_without_pin_exits_zero
	run_one test_worktree_sees_github_account

	rm -rf "${TEST_BIN}"

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All git-identity tests passed"
}

main "$@"
