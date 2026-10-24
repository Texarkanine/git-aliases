#!/bin/sh
#
# test-gh-shim.sh - Tests for the gh account pin shim
#
# Runs under an isolated HOME. The stub gh is the only gh on PATH
# ahead of anything else. This suite does not call a real gh.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
SHIM_SRC="${REPO_DIR}/shims/gh.sh"
GIT_IDENTITY_SRC="${REPO_DIR}/subcommands/git-identity/git-identity.bash"

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
	last_err="${HOME}/gh-shim-test-err"
	last_rc=0
	last_out=$("$@" 2>"${last_err}") || last_rc=$?
}

# Run a test body with HOME in a temp dir.
#
# Globals:
#   OPERATOR_HOME - real home; tests abort if isolation would not hold
#   SHIM_BIN, STUB_BIN - directories prepared by main
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
		PATH="${SHIM_BIN}:${STUB_BIN}:${PATH}"
		export PATH
		GIT_CONFIG_GLOBAL=/dev/null
		GIT_CONFIG_SYSTEM=/dev/null
		export GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
		unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GH_HOST || true
		"${ri_body}"
	) || ri_status=$?
	rm -rf "${ri_home}"
	return "${ri_status}"
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

# Fail unless the stub recorded this many invocations.
#
# Globals:
#   HOME - counter file lives here
# Arguments:
#   $1 - expected count
# Outputs:
#   None
# Returns:
#   Does not return on failure
expect_count() {
	ec_want="$1"
	ec_got=0
	if [ -f "${HOME}/gh-count" ]; then
		ec_got=$(cat "${HOME}/gh-count")
	fi
	if [ "${ec_got}" != "${ec_want}" ]; then
		fail "gh should run ${ec_want} time(s), ran ${ec_got}"
	fi
}

# Fail unless one recorded field has the expected bytes.
#
# Globals:
#   HOME - invocation log lives here
# Arguments:
#   $1 - invocation number, starting at 1
#   $2 - field name
#   $3 - expected value
# Outputs:
#   None
# Returns:
#   Does not return on failure
expect_field() {
	ef_path="${HOME}/gh-log/${1}/${2}"
	ef_want="$3"
	if [ ! -f "${ef_path}" ]; then
		fail "missing ${ef_path}"
	fi
	ef_got=$(cat "${ef_path}")
	if [ "${ef_got}" != "${ef_want}" ]; then
		fail "invocation $1 $2 should be [${ef_want}] got [${ef_got}]"
	fi
}

# Passthrough leaves the ambient token and runs the command once.
#
# Globals:
#   last_out, last_rc, last_err - set by invoke
# Arguments:
#   $1 - expected GH_TOKEN
#   $@ - expected argv, after the token
# Outputs:
#   None
# Returns:
#   Does not return on failure
assert_passthrough() {
	ap_token="$1"
	shift
	ap_argv="$*"
	if [ "${last_rc}" -ne 0 ]; then
		fail "passthrough should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "stub-ok" ]; then
		fail "stdout should be only stub-ok (got [${last_out}])"
	fi
	case "${last_out}" in
		*true*) fail "stdout should not contain true: [${last_out}]" ;;
	esac
	expect_count 1
	expect_field 1 argv "${ap_argv}"
	expect_field 1 GH_TOKEN "${ap_token}"
}

# Fail unless reenter spawned a child gh without the loop guard.
#
# Globals:
#   last_rc, last_err, last_out - set by invoke
# Arguments:
#   $1 - yes when the checkout is pinned
# Outputs:
#   None
# Returns:
#   Does not return on failure
assert_reentry() {
	ar_pinned="$1"
	if [ "${last_rc}" -ne 0 ]; then
		fail "reenter should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	case "$(cat "${last_err}")" in
		*"gh shim invoked itself"*)
			fail "child gh was treated as a loop"
			;;
	esac
	if [ "${last_out}" != "stub-ok" ]; then
		fail "child gh should print stub-ok (got [${last_out}])"
	fi
	if [ "${ar_pinned}" = "yes" ]; then
		expect_count 4
		expect_field 1 argv "auth token --user example-login"
		expect_field 2 argv "reenter"
		expect_field 2 GIT_ALIASES_GH_SHIM ""
		expect_field 3 argv "auth token --user example-login"
		expect_field 4 argv "inner"
		expect_field 4 GIT_ALIASES_GH_SHIM ""
	else
		expect_count 2
		expect_field 1 argv "reenter"
		expect_field 1 GIT_ALIASES_GH_SHIM ""
		expect_field 2 argv "inner"
		expect_field 2 GIT_ALIASES_GH_SHIM ""
	fi
}

test_reentry_outside_repo() {
	tr_dir=$(mktemp -d)
	cd "${tr_dir}" || fail "cd ${tr_dir} failed"
	invoke "${SHIM_BIN}/gh" reenter
	assert_reentry no
}

test_reentry_unpinned() {
	init_repo
	invoke "${SHIM_BIN}/gh" reenter
	assert_reentry no
}

test_reentry_pinned() {
	init_repo
	git config --local github.account example-login
	invoke "${SHIM_BIN}/gh" reenter
	assert_reentry yes
}

test_no_pin_preserves_token() {
	init_repo
	invoke env GH_TOKEN=ambient-token "${SHIM_BIN}/gh" issue list
	assert_passthrough ambient-token issue list
}

test_global_account_is_not_a_pin() {
	init_repo
	git config --file "${HOME}/global.gitconfig" github.account example-login
	GIT_CONFIG_GLOBAL="${HOME}/global.gitconfig"
	export GIT_CONFIG_GLOBAL
	invoke env GH_TOKEN=ambient-token "${SHIM_BIN}/gh" issue list
	assert_passthrough ambient-token issue list
	tga_argv=$(cat "${HOME}/gh-log/1/argv")
	case "${tga_argv}" in
		*"auth token"*) fail "global github.account should not run auth token" ;;
	esac
}

test_outside_repo_preserves_token() {
	tor_dir=$(mktemp -d)
	cd "${tor_dir}" || fail "cd ${tor_dir} failed"
	git config --file "${HOME}/global.gitconfig" github.account example-login
	GIT_CONFIG_GLOBAL="${HOME}/global.gitconfig"
	export GIT_CONFIG_GLOBAL
	invoke env GH_TOKEN=ambient-token "${SHIM_BIN}/gh" status
	assert_passthrough ambient-token status
}

test_pin_forces_token() {
	init_repo
	git config --local github.account example-login
	invoke env GH_TOKEN=ambient-token GITHUB_TOKEN=ambient-github \
		"${SHIM_BIN}/gh" issue list
	if [ "${last_rc}" -ne 0 ]; then
		fail "pinned command should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "stub-ok" ]; then
		fail "pinned stdout should be stub-ok (got [${last_out}])"
	fi
	case "${last_out}" in
		*test-token*) fail "stdout should not contain the token" ;;
	esac
	expect_count 2
	expect_field 1 argv "auth token --user example-login"
	expect_field 1 GH_TOKEN ""
	expect_field 1 GITHUB_TOKEN ""
	expect_field 1 GH_ENTERPRISE_TOKEN ""
	expect_field 1 GITHUB_ENTERPRISE_TOKEN ""
	expect_field 2 argv "issue list"
	expect_field 2 GH_TOKEN "test-token"
	expect_field 2 GH_ENTERPRISE_TOKEN "test-token"
	expect_field 2 GITHUB_TOKEN ""
	expect_field 2 GITHUB_ENTERPRISE_TOKEN ""
}

test_global_host_is_not_a_hostname() {
	init_repo
	git config --local github.account example-login
	git config --file "${HOME}/global.gitconfig" github.host ghe.example
	GIT_CONFIG_GLOBAL="${HOME}/global.gitconfig"
	export GIT_CONFIG_GLOBAL
	invoke "${SHIM_BIN}/gh" issue list
	if [ "${last_rc}" -ne 0 ]; then
		fail "pinned command should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	expect_field 1 argv "auth token --user example-login"
}

test_missing_token_stops() {
	init_repo
	git config --local github.account missing-login
	invoke "${SHIM_BIN}/gh" pr view
	if [ "${last_rc}" -eq 0 ]; then
		fail "missing token should exit non-zero"
	fi
	case "${last_out}" in
		*test-token*) fail "stdout should not contain a token: [${last_out}]" ;;
		*stub-ok*) fail "requested command should not run" ;;
	esac
	case "$(cat "${last_err}")" in
		*missing-login*) ;;
		*) fail "stderr should name the login: $(cat "${last_err}")" ;;
	esac
	expect_count 1
	expect_field 1 argv "auth token --user missing-login"
}

test_host_ghe_example() {
	init_repo
	git config --local github.account example-login
	git config --local github.host ghe.example
	invoke env GH_HOST=ambient.example "${SHIM_BIN}/gh" issue list
	if [ "${last_rc}" -ne 0 ]; then
		fail "enterprise pin should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	expect_count 2
	expect_field 1 argv "auth token --user example-login --hostname ghe.example"
	expect_field 2 GH_TOKEN "test-token"
	expect_field 2 GH_ENTERPRISE_TOKEN "test-token"
	expect_field 2 GH_HOST "ambient.example"
}

test_host_example_ghe_com() {
	init_repo
	git config --local github.account example-login
	git config --local github.host example.ghe.com
	invoke "${SHIM_BIN}/gh" issue list
	if [ "${last_rc}" -ne 0 ]; then
		fail "ghe.com pin should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	expect_count 2
	expect_field 1 argv "auth token --user example-login --hostname example.ghe.com"
	expect_field 2 GH_TOKEN "test-token"
	expect_field 2 GH_ENTERPRISE_TOKEN "test-token"
}

test_vanity_remote_has_no_hostname() {
	init_repo
	if ! git remote add origin git@vanity.example:example/repo.git; then
		fail "git remote add failed"
	fi
	git config --local github.account example-login
	invoke "${SHIM_BIN}/gh" issue list
	if [ "${last_rc}" -ne 0 ]; then
		fail "vanity remote pin should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	expect_field 1 argv "auth token --user example-login"
}

test_worktree_sees_pin() {
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
		fail "git identity use should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	cd "${tw_linked}" || fail "cd ${tw_linked} failed"
	invoke "${SHIM_BIN}/gh" issue list
	if [ "${last_rc}" -ne 0 ]; then
		fail "worktree shim should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	expect_field 1 argv "auth token --user example-login"
}

test_libexec_precedes_path() {
	init_repo
	mkdir -p "${HOME}/.local/libexec/git-aliases"
	cp "${STUB_BIN}/gh" "${HOME}/.local/libexec/git-aliases/gh"
	chmod +x "${HOME}/.local/libexec/git-aliases/gh"
	invoke "${SHIM_BIN}/gh" status
	if [ "${last_rc}" -ne 0 ]; then
		fail "libexec gh should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	expect_count 1
	expect_field 1 argv0 "${HOME}/.local/libexec/git-aliases/gh"
	expect_field 1 argv "status"
}

test_marker_skips_libexec_and_self() {
	init_repo
	mkdir -p "${HOME}/.local/libexec/git-aliases"
	cat > "${HOME}/.local/libexec/git-aliases/gh" <<'EOF'
#!/bin/sh
# git-aliases-gh-shim
echo marked-libexec
EOF
	chmod +x "${HOME}/.local/libexec/git-aliases/gh"
	invoke gh status
	if [ "${last_rc}" -ne 0 ]; then
		fail "bare gh should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "stub-ok" ]; then
		fail "marked libexec should be skipped (got [${last_out}])"
	fi
	expect_count 1
	expect_field 1 argv0 "${STUB_BIN}/gh"
	expect_field 1 argv "status"
}

test_pinned_command_does_not_call_auth_switch() {
	init_repo
	git config --local github.account example-login
	invoke "${SHIM_BIN}/gh" auth status
	if [ "${last_rc}" -ne 0 ]; then
		fail "pinned command should exit 0 (got ${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "stub-ok" ]; then
		fail "pinned command should run (got [${last_out}])"
	fi
	expect_count 2
	expect_field 1 argv "auth token --user example-login"
	tps_n=1
	while [ -f "${HOME}/gh-log/${tps_n}/argv" ]; do
		tps_argv=$(cat "${HOME}/gh-log/${tps_n}/argv")
		case "${tps_argv}" in
			*"auth switch"*) fail "shim should not call auth switch" ;;
		esac
		tps_n=$(expr "${tps_n}" + 1)
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
	if [ ! -f "${SHIM_SRC}" ]; then
		echo "FAIL: missing ${SHIM_SRC}" >&2
		exit 1
	fi
	if [ ! -f "${GIT_IDENTITY_SRC}" ]; then
		echo "FAIL: missing ${GIT_IDENTITY_SRC}" >&2
		exit 1
	fi
	SHIM_BIN=$(mktemp -d)
	STUB_BIN=$(mktemp -d)
	cp "${SHIM_SRC}" "${SHIM_BIN}/gh"
	chmod +x "${SHIM_BIN}/gh"
	cp "${GIT_IDENTITY_SRC}" "${SHIM_BIN}/git-identity"
	chmod +x "${SHIM_BIN}/git-identity"
	cat > "${STUB_BIN}/gh" <<'EOF'
#!/bin/sh
set -eu
log_root="${HOME}/gh-log"
count_file="${HOME}/gh-count"
count=0
if [ -f "${count_file}" ]; then
	count=$(cat "${count_file}")
fi
count=$(expr "${count}" + 1)
printf '%s\n' "${count}" > "${count_file}"
entry="${log_root}/${count}"
mkdir -p "${entry}"
printf '%s\n' "$0" > "${entry}/argv0"
printf '%s\n' "$*" > "${entry}/argv"
printf '%s\n' "${GH_TOKEN-}" > "${entry}/GH_TOKEN"
printf '%s\n' "${GITHUB_TOKEN-}" > "${entry}/GITHUB_TOKEN"
printf '%s\n' "${GH_ENTERPRISE_TOKEN-}" > "${entry}/GH_ENTERPRISE_TOKEN"
printf '%s\n' "${GITHUB_ENTERPRISE_TOKEN-}" > "${entry}/GITHUB_ENTERPRISE_TOKEN"
printf '%s\n' "${GH_HOST-}" > "${entry}/GH_HOST"
printf '%s\n' "${GIT_ALIASES_GH_SHIM-}" > "${entry}/GIT_ALIASES_GH_SHIM"

if [ "${1-}" = "auth" ] && [ "${2-}" = "switch" ]; then
	echo "auth switch invoked" >&2
	exit 1
fi

if [ "${1-}" = "auth" ] && [ "${2-}" = "token" ]; then
	st_user=""
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--user)
				shift
				st_user=${1-}
				;;
			--hostname)
				shift
				;;
		esac
		if [ "$#" -gt 0 ]; then
			shift
		fi
	done
	case "${st_user}" in
		example-login)
			printf '%s\n' "test-token"
			exit 0
			;;
		missing-login)
			printf '%s\n' "test-token"
			exit 1
			;;
		*)
			echo "unexpected user ${st_user}" >&2
			exit 1
			;;
	esac
fi

if [ "${1-}" = "reenter" ]; then
	gh inner
	exit $?
fi

printf '%s\n' "stub-ok"
exit 0
EOF
	chmod +x "${STUB_BIN}/gh"

	run_one test_no_pin_preserves_token
	run_one test_global_account_is_not_a_pin
	run_one test_outside_repo_preserves_token
	run_one test_pin_forces_token
	run_one test_global_host_is_not_a_hostname
	run_one test_missing_token_stops
	run_one test_host_ghe_example
	run_one test_host_example_ghe_com
	run_one test_vanity_remote_has_no_hostname
	run_one test_worktree_sees_pin
	run_one test_libexec_precedes_path
	run_one test_marker_skips_libexec_and_self
	run_one test_pinned_command_does_not_call_auth_switch
	run_one test_reentry_outside_repo
	run_one test_reentry_unpinned
	run_one test_reentry_pinned

	rm -rf "${SHIM_BIN}" "${STUB_BIN}"

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All gh shim tests passed"
}

main "$@"
