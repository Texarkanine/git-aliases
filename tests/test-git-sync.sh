#!/bin/sh
#
# test-git-sync.sh - Behavioral tests for the git-sync subcommand
#
# Runs real git sync operations under an isolated HOME and PATH so
# the operator's git config and installed git-sync cannot leak in.
# Confirm prompts are answered on stdin.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
GIT_SYNC_SRC="${REPO_DIR}/subcommands/git-sync/git-sync.bash"

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
	last_err="${HOME}/.git-sync-test-err"
	last_rc=0
	last_out=$("$@" 2>"${last_err}") || last_rc=$?
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
	git -C "${mr_dir}" commit -q -m init
	printf '%s\n' "${mr_dir}"
}

# Run a test body with HOME in a temp dir and git-sync first on PATH.
#
# Globals:
#   OPERATOR_HOME - real home; tests abort if isolation would not hold
#   TEST_BIN - directory containing the git-sync under test
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

# Attach a local bare origin, push main with upstream set.
#
# Globals:
#   None
# Arguments:
#   $1 - repo path
# Outputs:
#   Absolute bare-remote path on STDOUT
# Returns:
#   0 on success
attach_origin() {
	ao_repo="$1"
	ao_bare=$(mktemp -d)
	git clone --bare --quiet "${ao_repo}" "${ao_bare}"
	git -C "${ao_repo}" remote add origin "${ao_bare}"
	git -C "${ao_repo}" push -q -u origin main
	printf '%s\n' "${ao_bare}"
}

# Add a commit on origin/main through a throwaway clone.
#
# Globals:
#   None
# Arguments:
#   $1 - bare remote path
#   $2 - commit message (also appended to file.txt)
# Outputs:
#   New commit sha on STDOUT
# Returns:
#   0 on success
advance_origin_main() {
	aom_bare="$1"
	aom_msg="$2"
	aom_clone=$(mktemp -d)
	git clone --quiet "${aom_bare}" "${aom_clone}"
	git -C "${aom_clone}" config user.name test
	git -C "${aom_clone}" config user.email test@example.com
	printf '%s\n' "${aom_msg}" >> "${aom_clone}/file.txt"
	git -C "${aom_clone}" add file.txt
	git -C "${aom_clone}" commit -q -m "${aom_msg}"
	git -C "${aom_clone}" push -q origin main
	git -C "${aom_clone}" rev-parse HEAD
}

# Confirm-yes git sync from a repo path.
#
# Globals:
#   HOME, last_out, last_err, last_rc
# Arguments:
#   $1 - repo path
#   $@ after shift - extra git-sync args
# Outputs:
#   None
# Returns:
#   0 (status is in last_rc)
sync_yes() {
	sy_repo="$1"
	shift
	last_err="${HOME}/.git-sync-test-err"
	last_rc=0
	last_out=$(
		cd "${sy_repo}" && printf 'y\n' | git sync "$@" 2>"${last_err}"
	) || last_rc=$?
}

# Worktree + remote, source held in primary: sync must succeed and
# bring the remote commit onto the feature branch without checking
# out main.
test_worktree_remote_source_held() {
	twr_repo=$(make_repo)
	twr_bare=$(attach_origin "${twr_repo}")
	git -C "${twr_repo}" branch feature
	twr_wt="${twr_repo}-feature"
	git -C "${twr_repo}" worktree add -q "${twr_wt}" feature
	twr_sha=$(advance_origin_main "${twr_bare}" "remote-ahead")

	sync_yes "${twr_wt}"
	if [ "${last_rc}" -ne 0 ]; then
		fail "worktree sync failed (${last_rc}): ${last_out} $(cat "${last_err}")"
	fi
	if [ "$(git -C "${twr_wt}" branch --show-current)" != "feature" ]; then
		fail "worktree should stay on feature"
	fi
	if [ "$(git -C "${twr_repo}" branch --show-current)" != "main" ]; then
		fail "primary should still be on main"
	fi
	if ! git -C "${twr_wt}" merge-base --is-ancestor "${twr_sha}" HEAD; then
		fail "feature should contain remote commit ${twr_sha}"
	fi
}

# Same worktree setup, merge mode.
test_worktree_remote_merge() {
	twm_repo=$(make_repo)
	twm_bare=$(attach_origin "${twm_repo}")
	git -C "${twm_repo}" branch feature
	twm_wt="${twm_repo}-feature"
	git -C "${twm_repo}" worktree add -q "${twm_wt}" feature
	twm_sha=$(advance_origin_main "${twm_bare}" "remote-merge")

	sync_yes "${twm_wt}" --merge
	if [ "${last_rc}" -ne 0 ]; then
		fail "worktree merge sync failed (${last_rc}): ${last_out} $(cat "${last_err}")"
	fi
	if [ "$(git -C "${twm_wt}" branch --show-current)" != "feature" ]; then
		fail "worktree should stay on feature"
	fi
	if [ "$(git -C "${twm_repo}" branch --show-current)" != "main" ]; then
		fail "primary should still be on main"
	fi
	if ! git -C "${twm_wt}" merge-base --is-ancestor "${twm_sha}" HEAD; then
		fail "feature should contain remote commit ${twm_sha}"
	fi
}

# Primary checkout of a feature branch; origin/main is ahead.
test_primary_feature_remote() {
	tpf_repo=$(make_repo)
	tpf_bare=$(attach_origin "${tpf_repo}")
	git -C "${tpf_repo}" checkout -q -b feature
	tpf_sha=$(advance_origin_main "${tpf_bare}" "primary-ahead")

	sync_yes "${tpf_repo}"
	if [ "${last_rc}" -ne 0 ]; then
		fail "primary sync failed (${last_rc}): ${last_out} $(cat "${last_err}")"
	fi
	if [ "$(git -C "${tpf_repo}" branch --show-current)" != "feature" ]; then
		fail "primary should stay on feature"
	fi
	if ! git -C "${tpf_repo}" merge-base --is-ancestor "${tpf_sha}" HEAD; then
		fail "feature should contain remote commit ${tpf_sha}"
	fi
}

# No remote; local main is ahead of the feature branch.
test_no_remote_local_source_ahead() {
	tnr_repo=$(make_repo)
	git -C "${tnr_repo}" checkout -q -b feature
	git -C "${tnr_repo}" checkout -q main
	printf 'local\n' >> "${tnr_repo}/file.txt"
	git -C "${tnr_repo}" add file.txt
	git -C "${tnr_repo}" commit -q -m local-ahead
	tnr_sha=$(git -C "${tnr_repo}" rev-parse HEAD)
	git -C "${tnr_repo}" checkout -q feature

	sync_yes "${tnr_repo}"
	if [ "${last_rc}" -ne 0 ]; then
		fail "no-remote sync failed (${last_rc}): ${last_out} $(cat "${last_err}")"
	fi
	if ! git -C "${tnr_repo}" merge-base --is-ancestor "${tnr_sha}" HEAD; then
		fail "feature should contain local main commit ${tnr_sha}"
	fi
}

# User declines the confirm prompt; refs stay put.
test_cancel() {
	tc_repo=$(make_repo)
	git -C "${tc_repo}" checkout -q -b feature
	tc_before=$(git -C "${tc_repo}" rev-parse HEAD)
	last_err="${HOME}/.git-sync-test-err"
	last_rc=0
	last_out=$(
		cd "${tc_repo}" && printf 'n\n' | git sync 2>"${last_err}"
	) || last_rc=$?
	if [ "${last_rc}" -ne 0 ]; then
		fail "cancel should exit 0 (got ${last_rc}): ${last_out} $(cat "${last_err}")"
	fi
	tc_after=$(git -C "${tc_repo}" rev-parse HEAD)
	if [ "${tc_before}" != "${tc_after}" ]; then
		fail "cancel should not move HEAD"
	fi
}

# Already on the source branch; nothing to do.
test_already_on_source() {
	tas_repo=$(make_repo)
	invoke git -C "${tas_repo}" sync
	if [ "${last_rc}" -ne 0 ]; then
		fail "already-on-source should exit 0 (got ${last_rc}): ${last_out} $(cat "${last_err}")"
	fi
	case "${last_out}" in
		*"Nothing to synchronize"*) ;;
		*) fail "already-on-source stdout: ${last_out}" ;;
	esac
}

# Dirty worktree plus a pre-existing stash; sync must not pop the
# unrelated stash, and must restore the dirty file.
test_stash_safety() {
	tss_repo=$(make_repo)
	git -C "${tss_repo}" checkout -q -b feature
	printf 'stashed\n' >> "${tss_repo}/file.txt"
	git -C "${tss_repo}" stash push -q -m "pre-existing"
	printf 'dirty\n' >> "${tss_repo}/file.txt"

	sync_yes "${tss_repo}"
	if [ "${last_rc}" -ne 0 ]; then
		fail "stash-safety sync failed (${last_rc}): ${last_out} $(cat "${last_err}")"
	fi
	tss_stash=$(git -C "${tss_repo}" stash list)
	case "${tss_stash}" in
		*"pre-existing"*) ;;
		*) fail "pre-existing stash was lost: ${tss_stash}" ;;
	esac
	case "$(cat "${tss_repo}/file.txt")" in
		*dirty*) ;;
		*) fail "dirty file was not restored: $(cat "${tss_repo}/file.txt")" ;;
	esac
}

# Not a git repository.
test_not_a_repo() {
	tnar_dir=$(mktemp -d)
	last_err="${HOME}/.git-sync-test-err"
	last_rc=0
	last_out=$(
		cd "${tnar_dir}" && git-sync 2>"${last_err}"
	) || last_rc=$?
	if [ "${last_rc}" -eq 0 ]; then
		fail "not-a-repo should be non-zero"
	fi
	tnar_text="${last_out}$(cat "${last_err}")"
	case "${tnar_text}" in
		*"Not in a git repository"*) ;;
		*) fail "not-a-repo message: ${tnar_text}" ;;
	esac
}

# Detached HEAD is refused.
test_detached_head() {
	tdh_repo=$(make_repo)
	git -C "${tdh_repo}" checkout -q --detach
	invoke git -C "${tdh_repo}" sync
	if [ "${last_rc}" -eq 0 ]; then
		fail "detached HEAD should be non-zero"
	fi
	tdh_text="${last_out}$(cat "${last_err}")"
	case "${tdh_text}" in
		*"Not currently on a branch"*) ;;
		*) fail "detached HEAD message: ${tdh_text}" ;;
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
	if [ ! -f "${GIT_SYNC_SRC}" ]; then
		echo "FAIL: missing ${GIT_SYNC_SRC}" >&2
		exit 1
	fi
	TEST_BIN=$(mktemp -d)
	chmod +x "${GIT_SYNC_SRC}"
	ln -s "${GIT_SYNC_SRC}" "${TEST_BIN}/git-sync"

	run_one test_worktree_remote_source_held
	run_one test_worktree_remote_merge
	run_one test_primary_feature_remote
	run_one test_no_remote_local_source_ahead
	run_one test_cancel
	run_one test_already_on_source
	run_one test_stash_safety
	run_one test_not_a_repo
	run_one test_detached_head

	rm -rf "${TEST_BIN}"

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All git-sync tests passed"
}

main "$@"
