#!/bin/sh
#
# test-git-wt.sh - Integration tests for the git-wt subcommand
#
# Runs real git worktree operations under an isolated HOME and PATH so
# the operator's ~/worktrees, ~/.local/bin/wt-*, and zsh wt() cannot leak
# in. --force confirmation is driven by a python3 PTY helper.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
GIT_WT_SRC="${REPO_DIR}/subcommands/git-wt/git-wt.bash"

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
	last_err="${HOME}/.git-wt-test-err"
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

# First worktree path from porcelain (the main checkout).
#
# Globals:
#   None
# Arguments:
#   $1 - repo path
# Outputs:
#   Absolute main path on STDOUT
# Returns:
#   0
main_path() {
	git -C "$1" worktree list --porcelain \
		| awk '$1 == "worktree" { print substr($0, 10); exit }'
}

# Run a test body with HOME in a temp dir and git-wt first on PATH.
#
# Globals:
#   OPERATOR_HOME - real home; tests abort if isolation would not hold
#   TEST_BIN - directory containing the git-wt under test
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

# Run a command attached to a PTY, sending one reply line to /dev/tty.
#
# Globals:
#   None
# Arguments:
#   $1 - reply to send (e.g. y, n, yes)
#   $@ - command after shift
# Outputs:
#   Child PTY output on STDOUT
# Returns:
#   Child exit status
run_with_tty() {
	rwt_reply="$1"
	shift
	python3 -c '
import os, pty, sys

reply = (sys.argv[1] + "\n").encode()
cmd = sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
	os.execvp(cmd[0], cmd)
try:
	os.write(fd, reply)
except OSError:
	pass
while True:
	try:
		data = os.read(fd, 4096)
	except OSError:
		break
	if not data:
		break
	os.write(1, data)
_pid, status = os.waitpid(pid, 0)
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1)
' "${rwt_reply}" "$@"
}

test_help_flags() {
	# git intercepts `git <cmd> --help` before the subcommand runs, so
	# --help is invoked as git-wt directly. -h and help go through git.
	for thf_flag in -h help; do
		invoke git wt "${thf_flag}"
		if [ "${last_rc}" -ne 0 ]; then
			fail "git wt ${thf_flag} should exit 0 (got ${last_rc})"
		fi
		case "${last_out}" in
			*go*) ;;
			*) fail "git wt ${thf_flag} stdout should include go: ${last_out}" ;;
		esac
		case "${last_out}" in
			*done*) ;;
			*) fail "git wt ${thf_flag} stdout should include done: ${last_out}" ;;
		esac
	done
	invoke git-wt --help
	if [ "${last_rc}" -ne 0 ]; then
		fail "git-wt --help should exit 0 (got ${last_rc})"
	fi
	case "${last_out}" in
		*go*) ;;
		*) fail "git-wt --help stdout should include go: ${last_out}" ;;
	esac
	case "${last_out}" in
		*done*) ;;
		*) fail "git-wt --help stdout should include done: ${last_out}" ;;
	esac
}

test_no_args_usage() {
	invoke git wt
	if [ "${last_rc}" -eq 0 ]; then
		fail "git wt with no args should be non-zero"
	fi
	tna_text="${last_out}$(cat "${last_err}")"
	case "${tna_text}" in
		*go*|*usage*|*Usage*) ;;
		*) fail "git wt with no args should print usage, got: ${tna_text}" ;;
	esac
}

test_unknown_command() {
	invoke git wt foo
	if [ "${last_rc}" -eq 0 ]; then
		fail "git wt foo should be non-zero"
	fi
	if ! grep -q foo "${last_err}"; then
		fail "unknown command should mention foo on stderr"
	fi
}

test_not_a_repo() {
	tnr_dir=$(mktemp -d)
	cd "${tnr_dir}"
	invoke git wt go x
	if [ "${last_rc}" -eq 0 ]; then
		fail "git wt go outside a repo should be non-zero"
	fi
}

test_missing_name() {
	tmn_repo=$(make_repo)
	cd "${tmn_repo}"
	invoke git wt go
	if [ "${last_rc}" -eq 0 ]; then
		fail "git wt go without a name should be non-zero"
	fi
}

test_invalid_branch_name() {
	tib_repo=$(make_repo)
	cd "${tib_repo}"
	invoke git wt go ".."
	if [ "${last_rc}" -eq 0 ]; then
		fail "git wt go '..' should be non-zero"
	fi
}

test_path_ssh_remote() {
	tps_repo=$(make_repo)
	git -C "${tps_repo}" remote add origin \
		git@github.com:Texarkanine/ai-rizz.git
	cd "${tps_repo}"
	tps_want="${HOME}/worktrees/Texarkanine/ai-rizz/ai-rizz-feature-x"
	invoke git wt go feature-x
	if [ "${last_rc}" -ne 0 ]; then
		fail "ssh go failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tps_want}" ]; then
		fail "ssh path: expected ${tps_want}, got ${last_out}"
	fi
	if [ ! -d "${tps_want}" ]; then
		fail "ssh go did not create ${tps_want}"
	fi
}

test_path_https_remote() {
	tph_repo=$(make_repo)
	git -C "${tph_repo}" remote add origin \
		https://github.com/Texarkanine/ai-rizz.git
	cd "${tph_repo}"
	tph_want="${HOME}/worktrees/Texarkanine/ai-rizz/ai-rizz-feature-h"
	invoke git wt go feature-h
	if [ "${last_rc}" -ne 0 ]; then
		fail "https go failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tph_want}" ]; then
		fail "https path: expected ${tph_want}, got ${last_out}"
	fi
	case "${last_out}" in
		*github.com*) fail "https owner/repo parsed host as owner: ${last_out}" ;;
	esac
}

test_path_no_remote() {
	tpn_repo=$(make_repo)
	tpn_base=$(basename "${tpn_repo}")
	cd "${tpn_repo}"
	tpn_want="${HOME}/worktrees/local/${tpn_base}/${tpn_base}-bar"
	invoke git wt go bar
	if [ "${last_rc}" -ne 0 ]; then
		fail "no-remote go failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tpn_want}" ]; then
		fail "no-remote path: expected ${tpn_want}, got ${last_out}"
	fi
}

test_path_first_remote_without_origin() {
	tpf_repo=$(make_repo)
	git -C "${tpf_repo}" remote add upstream \
		git@github.com:OtherOrg/other-repo.git
	cd "${tpf_repo}"
	tpf_want="${HOME}/worktrees/OtherOrg/other-repo/other-repo-br"
	invoke git wt go br
	if [ "${last_rc}" -ne 0 ]; then
		fail "first-remote go failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tpf_want}" ]; then
		fail "first-remote path: expected ${tpf_want}, got ${last_out}"
	fi
}

test_go_new_branch() {
	tgn_repo=$(make_repo)
	cd "${tgn_repo}"
	invoke git wt go new-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "go new branch failed: $(cat "${last_err}")"
	fi
	if ! git show-ref --verify --quiet refs/heads/new-br; then
		fail "go should create branch new-br"
	fi
	tgn_head=$(git -C "${last_out}" rev-parse --abbrev-ref HEAD)
	if [ "${tgn_head}" != "new-br" ]; then
		fail "new worktree HEAD should be new-br, got ${tgn_head}"
	fi
}

test_go_existing_branch() {
	tge_repo=$(make_repo)
	cd "${tge_repo}"
	git branch existing-br
	invoke git wt go existing-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "go existing branch failed: $(cat "${last_err}")"
	fi
	tge_head=$(git -C "${last_out}" rev-parse --abbrev-ref HEAD)
	if [ "${tge_head}" != "existing-br" ]; then
		fail "existing worktree HEAD should be existing-br, got ${tge_head}"
	fi
}

test_go_idempotent() {
	tgi_repo=$(make_repo)
	cd "${tgi_repo}"
	invoke git wt go idemp
	if [ "${last_rc}" -ne 0 ]; then
		fail "first idempotent go failed: $(cat "${last_err}")"
	fi
	tgi_first="${last_out}"
	invoke git wt go idemp
	if [ "${last_rc}" -ne 0 ]; then
		fail "second idempotent go should exit 0: $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tgi_first}" ]; then
		fail "idempotent go path changed: ${tgi_first} vs ${last_out}"
	fi
}

test_go_path_exists_not_worktree() {
	tgp_repo=$(make_repo)
	git -C "${tgp_repo}" remote add origin \
		git@github.com:Texarkanine/ai-rizz.git
	cd "${tgp_repo}"
	tgp_path="${HOME}/worktrees/Texarkanine/ai-rizz/ai-rizz-collide"
	mkdir -p "${tgp_path}"
	invoke git wt go collide
	if [ "${last_rc}" -eq 0 ]; then
		fail "go should fail when path exists but is not a worktree"
	fi
}

test_go_from_linked_worktree() {
	tgl_repo=$(make_repo)
	cd "${tgl_repo}"
	invoke git wt go link-a
	if [ "${last_rc}" -ne 0 ]; then
		fail "go link-a failed: $(cat "${last_err}")"
	fi
	cd "${last_out}"
	invoke git wt go link-b
	if [ "${last_rc}" -ne 0 ]; then
		fail "go from linked worktree failed: $(cat "${last_err}")"
	fi
	if [ ! -d "${last_out}" ]; then
		fail "go from linked worktree did not create ${last_out}"
	fi
}

test_done_no_name_inside() {
	tdni_repo=$(make_repo)
	tdni_main=$(main_path "${tdni_repo}")
	cd "${tdni_repo}"
	invoke git wt go inside-nn
	if [ "${last_rc}" -ne 0 ]; then
		fail "go inside-nn failed: $(cat "${last_err}")"
	fi
	tdni_path="${last_out}"
	cd "${tdni_path}"
	invoke git wt done
	if [ "${last_rc}" -ne 0 ]; then
		fail "nameless done inside failed: $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tdni_main}" ]; then
		fail "nameless done inside should print ${tdni_main}, got ${last_out}"
	fi
	if [ -d "${tdni_path}" ]; then
		fail "nameless done should remove ${tdni_path}"
	fi
	if ! git -C "${tdni_main}" show-ref --verify --quiet refs/heads/inside-nn; then
		fail "nameless done should leave branch inside-nn"
	fi
}

test_done_no_name_subdirectory() {
	tdns_repo=$(make_repo)
	tdns_main=$(main_path "${tdns_repo}")
	cd "${tdns_repo}"
	invoke git wt go sub-nn
	if [ "${last_rc}" -ne 0 ]; then
		fail "go sub-nn failed: $(cat "${last_err}")"
	fi
	tdns_path="${last_out}"
	mkdir "${tdns_path}/nested"
	cd "${tdns_path}/nested"
	invoke git wt done
	if [ "${last_rc}" -ne 0 ]; then
		fail "nameless done from subdirectory failed: $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tdns_main}" ]; then
		fail "nameless done from subdir should print ${tdns_main}, got ${last_out}"
	fi
	if [ -d "${tdns_path}" ]; then
		fail "nameless done from subdir should remove ${tdns_path}"
	fi
}

test_done_no_name_foreign_worktree() {
	tdnf_repo=$(make_repo)
	tdnf_main=$(main_path "${tdnf_repo}")
	tdnf_path="${tdnf_repo}/nested-wt"
	git -C "${tdnf_repo}" worktree add -b foreign-nn "${tdnf_path}" \
		>/dev/null 2>&1
	cd "${tdnf_path}"
	invoke git wt done
	if [ "${last_rc}" -ne 0 ]; then
		fail "nameless done foreign failed: $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tdnf_main}" ]; then
		fail "nameless done foreign should print ${tdnf_main}, got ${last_out}"
	fi
	if [ -d "${tdnf_path}" ]; then
		fail "nameless done should remove foreign ${tdnf_path}"
	fi
}

test_done_named_foreign_worktree() {
	tdxf_repo=$(make_repo)
	tdxf_parent=$(mktemp -d)
	tdxf_path="${tdxf_parent}/foreign"
	git -C "${tdxf_repo}" worktree add -b named-foreign "${tdxf_path}" \
		>/dev/null 2>&1
	cd "${tdxf_repo}"
	invoke git wt done named-foreign
	if [ "${last_rc}" -ne 0 ]; then
		fail "named done foreign failed: $(cat "${last_err}")"
	fi
	if [ -n "${last_out}" ]; then
		fail "named done from main should print no path, got: ${last_out}"
	fi
	if [ -d "${tdxf_path}" ]; then
		fail "named done should remove foreign ${tdxf_path}"
	fi
	if ! git show-ref --verify --quiet refs/heads/named-foreign; then
		fail "named done should leave branch named-foreign"
	fi
}

test_done_no_name_from_main() {
	tdnm_repo=$(make_repo)
	cd "${tdnm_repo}"
	invoke git wt done
	if [ "${last_rc}" -eq 0 ]; then
		fail "nameless done from main should be non-zero"
	fi
	if ! grep -q "main checkout" "${last_err}"; then
		fail "nameless done from main should refuse main, got: $(cat "${last_err}")"
	fi
	if [ ! -d "${tdnm_repo}" ]; then
		fail "nameless done must not remove the main checkout"
	fi
}

test_done_no_name_dirty_without_force() {
	tdnd_repo=$(make_repo)
	cd "${tdnd_repo}"
	invoke git wt go dirty-nn
	if [ "${last_rc}" -ne 0 ]; then
		fail "go dirty-nn failed: $(cat "${last_err}")"
	fi
	tdnd_path="${last_out}"
	printf 'y\n' >> "${tdnd_path}/file.txt"
	cd "${tdnd_path}"
	invoke git wt done
	if [ "${last_rc}" -eq 0 ]; then
		fail "nameless dirty done without --force should fail"
	fi
	if ! grep -q force "${last_err}"; then
		fail "nameless dirty refusal should mention --force"
	fi
	if [ ! -d "${tdnd_path}" ]; then
		fail "nameless dirty done without --force should leave the worktree"
	fi
}

test_done_no_name_force_yes() {
	tdny_repo=$(make_repo)
	cd "${tdny_repo}"
	invoke git wt go dirty-nny
	if [ "${last_rc}" -ne 0 ]; then
		fail "go dirty-nny failed: $(cat "${last_err}")"
	fi
	tdny_path="${last_out}"
	printf 'y\n' >> "${tdny_path}/file.txt"
	cd "${tdny_path}"
	tdny_rc=0
	run_with_tty y git wt done --force || tdny_rc=$?
	if [ "${tdny_rc}" -ne 0 ]; then
		fail "nameless done --force with y should succeed (got ${tdny_rc})"
	fi
	if [ -d "${tdny_path}" ]; then
		fail "nameless done --force with y should remove ${tdny_path}"
	fi
}

test_done_missing_worktree() {
	tdm_repo=$(make_repo)
	cd "${tdm_repo}"
	invoke git wt done nosuch
	if [ "${last_rc}" -eq 0 ]; then
		fail "done missing worktree should be non-zero"
	fi
}

test_done_refuses_main() {
	tdr_repo=$(make_repo)
	cd "${tdr_repo}"
	invoke git wt done main
	if [ "${last_rc}" -eq 0 ]; then
		fail "done should refuse the main checkout"
	fi
	if [ ! -d "${tdr_repo}" ]; then
		fail "done must not remove the main checkout"
	fi
}

test_done_clean() {
	tdc_repo=$(make_repo)
	cd "${tdc_repo}"
	invoke git wt go clean-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "go clean-br failed: $(cat "${last_err}")"
	fi
	tdc_path="${last_out}"
	invoke git wt done clean-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "done clean failed: $(cat "${last_err}")"
	fi
	if [ -n "${last_out}" ]; then
		fail "done from outside should print no path, got: ${last_out}"
	fi
	if [ -d "${tdc_path}" ]; then
		fail "done should remove ${tdc_path}"
	fi
	if ! git show-ref --verify --quiet refs/heads/clean-br; then
		fail "done should leave branch clean-br"
	fi
}

test_done_inside_worktree() {
	tdi_repo=$(make_repo)
	tdi_main=$(main_path "${tdi_repo}")
	cd "${tdi_repo}"
	invoke git wt go inside-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "go inside-br failed: $(cat "${last_err}")"
	fi
	cd "${last_out}"
	invoke git wt done inside-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "done inside failed: $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tdi_main}" ]; then
		fail "done inside should print ${tdi_main}, got ${last_out}"
	fi
}

test_done_inside_subdirectory() {
	tds_repo=$(make_repo)
	tds_main=$(main_path "${tds_repo}")
	cd "${tds_repo}"
	invoke git wt go sub-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "go sub-br failed: $(cat "${last_err}")"
	fi
	mkdir "${last_out}/nested"
	cd "${last_out}/nested"
	invoke git wt done sub-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "done from subdirectory failed: $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tds_main}" ]; then
		fail "done from subdir should print ${tds_main}, got ${last_out}"
	fi
}

test_done_dirty_without_force() {
	tdw_repo=$(make_repo)
	cd "${tdw_repo}"
	invoke git wt go dirty-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "go dirty-br failed: $(cat "${last_err}")"
	fi
	tdw_path="${last_out}"
	printf 'y\n' >> "${tdw_path}/file.txt"
	invoke git wt done dirty-br
	if [ "${last_rc}" -eq 0 ]; then
		fail "done dirty without --force should fail"
	fi
	if ! grep -q force "${last_err}"; then
		fail "dirty refusal should mention --force"
	fi
	if [ ! -d "${tdw_path}" ]; then
		fail "dirty done without --force should leave the worktree"
	fi
}

test_done_dirty_force_yes() {
	tdy_repo=$(make_repo)
	cd "${tdy_repo}"
	invoke git wt go dirty-fy
	if [ "${last_rc}" -ne 0 ]; then
		fail "go dirty-fy failed: $(cat "${last_err}")"
	fi
	tdy_path="${last_out}"
	printf 'y\n' >> "${tdy_path}/file.txt"
	tdy_rc=0
	run_with_tty y git wt done dirty-fy --force || tdy_rc=$?
	if [ "${tdy_rc}" -ne 0 ]; then
		fail "done --force with y should succeed (got ${tdy_rc})"
	fi
	if [ -d "${tdy_path}" ]; then
		fail "done --force with y should remove ${tdy_path}"
	fi
}

test_done_dirty_force_no() {
	tdn_repo=$(make_repo)
	cd "${tdn_repo}"
	invoke git wt go dirty-fn
	if [ "${last_rc}" -ne 0 ]; then
		fail "go dirty-fn failed: $(cat "${last_err}")"
	fi
	tdn_path="${last_out}"
	printf 'y\n' >> "${tdn_path}/file.txt"
	tdn_rc=0
	run_with_tty n git wt done dirty-fn --force || tdn_rc=$?
	if [ "${tdn_rc}" -eq 0 ]; then
		fail "done --force with n should abort"
	fi
	if [ ! -d "${tdn_path}" ]; then
		fail "done --force with n should leave ${tdn_path}"
	fi
}

test_done_dirty_force_yes_word() {
	tdk_repo=$(make_repo)
	cd "${tdk_repo}"
	invoke git wt go dirty-yes
	if [ "${last_rc}" -ne 0 ]; then
		fail "go dirty-yes failed: $(cat "${last_err}")"
	fi
	tdk_path="${last_out}"
	printf 'y\n' >> "${tdk_path}/file.txt"
	tdk_rc=0
	run_with_tty yes git wt done dirty-yes --force || tdk_rc=$?
	if [ "${tdk_rc}" -ne 0 ]; then
		fail "done --force with yes should succeed (got ${tdk_rc})"
	fi
	if [ -d "${tdk_path}" ]; then
		fail "done --force with yes should remove ${tdk_path}"
	fi
}

test_done_force_on_clean() {
	tdf_repo=$(make_repo)
	cd "${tdf_repo}"
	invoke git wt go clean-f
	if [ "${last_rc}" -ne 0 ]; then
		fail "go clean-f failed: $(cat "${last_err}")"
	fi
	tdf_path="${last_out}"
	invoke git wt done clean-f --force
	if [ "${last_rc}" -ne 0 ]; then
		fail "done --force on clean should not prompt/fail: $(cat "${last_err}")"
	fi
	if [ -d "${tdf_path}" ]; then
		fail "done --force on clean should remove ${tdf_path}"
	fi
}

test_done_unknown_option() {
	tdu_repo=$(make_repo)
	cd "${tdu_repo}"
	invoke git wt done br --bogus
	if [ "${last_rc}" -eq 0 ]; then
		fail "done unknown option should be non-zero"
	fi
}

# HOME (and therefore ~/worktrees/...) contains a space. Porcelain paths
# must not be split on awk $2, or done cannot cd to the worktree.
test_done_home_with_spaces() {
	tdh_spaced="${HOME}/user space home"
	mkdir -p "${tdh_spaced}"
	HOME="${tdh_spaced}"
	export HOME
	tdh_repo=$(make_repo)
	git -C "${tdh_repo}" remote add origin \
		git@github.com:Texarkanine/ai-rizz.git
	cd "${tdh_repo}"
	tdh_want="${HOME}/worktrees/Texarkanine/ai-rizz/ai-rizz-space-br"
	invoke git wt go space-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "go with spaced HOME failed: $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tdh_want}" ]; then
		fail "spaced go path: expected ${tdh_want}, got ${last_out}"
	fi
	invoke git wt done space-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "done with spaced HOME failed: $(cat "${last_err}")"
	fi
	if [ -d "${tdh_want}" ]; then
		fail "done should remove ${tdh_want}"
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
	if [ ! -f "${GIT_WT_SRC}" ]; then
		echo "FAIL: missing ${GIT_WT_SRC}" >&2
		exit 1
	fi
	TEST_BIN=$(mktemp -d)
	chmod +x "${GIT_WT_SRC}"
	ln -s "${GIT_WT_SRC}" "${TEST_BIN}/git-wt"

	run_one test_help_flags
	run_one test_no_args_usage
	run_one test_unknown_command
	run_one test_not_a_repo
	run_one test_missing_name
	run_one test_invalid_branch_name
	run_one test_path_ssh_remote
	run_one test_path_https_remote
	run_one test_path_no_remote
	run_one test_path_first_remote_without_origin
	run_one test_go_new_branch
	run_one test_go_existing_branch
	run_one test_go_idempotent
	run_one test_go_path_exists_not_worktree
	run_one test_go_from_linked_worktree
	run_one test_done_no_name_inside
	run_one test_done_no_name_subdirectory
	run_one test_done_no_name_foreign_worktree
	run_one test_done_named_foreign_worktree
	run_one test_done_no_name_from_main
	run_one test_done_no_name_dirty_without_force
	run_one test_done_no_name_force_yes
	run_one test_done_missing_worktree
	run_one test_done_refuses_main
	run_one test_done_clean
	run_one test_done_inside_worktree
	run_one test_done_inside_subdirectory
	run_one test_done_dirty_without_force
	run_one test_done_dirty_force_yes
	run_one test_done_dirty_force_no
	run_one test_done_dirty_force_yes_word
	run_one test_done_force_on_clean
	run_one test_done_unknown_option
	run_one test_done_home_with_spaces

	rm -rf "${TEST_BIN}"

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All git-wt tests passed"
}

main "$@"
