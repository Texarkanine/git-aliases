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
		unset GITWT_ROOT
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

# Run a command in its own session; kill the whole session on timeout.
#
# Globals:
#   None
# Arguments:
#   $1 - timeout in seconds
#   $@ - command after shift
# Outputs:
#   Child stdout/stderr (inherited)
# Returns:
#   Child exit status, or 124 on timeout
run_with_timeout() {
	rwto_secs="$1"
	shift
	python3 -c '
import os, signal, subprocess, sys

p = subprocess.Popen(sys.argv[2:], start_new_session=True)
try:
	sys.exit(p.wait(timeout=float(sys.argv[1])))
except subprocess.TimeoutExpired:
	os.killpg(p.pid, signal.SIGKILL)
	p.wait()
	sys.exit(124)
' "${rwto_secs}" "$@"
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

# --yes skips the discard prompt. The PTY answers n, so a prompt would
# abort and leave the worktree.
test_done_force_yes_flag_no_prompt() {
	tdyf_repo=$(make_repo)
	cd "${tdyf_repo}"
	invoke git wt go dirty-yf
	if [ "${last_rc}" -ne 0 ]; then
		fail "go dirty-yf failed: $(cat "${last_err}")"
	fi
	tdyf_path="${last_out}"
	printf 'y\n' >> "${tdyf_path}/file.txt"
	tdyf_rc=0
	run_with_tty n git wt done dirty-yf --force --yes || tdyf_rc=$?
	if [ "${tdyf_rc}" -ne 0 ]; then
		fail "done --force --yes should not prompt (got ${tdyf_rc})"
	fi
	if [ -d "${tdyf_path}" ]; then
		fail "done --force --yes should remove ${tdyf_path}"
	fi
}

test_done_yes_without_force_dirty() {
	tdyw_repo=$(make_repo)
	cd "${tdyw_repo}"
	invoke git wt go dirty-yw
	if [ "${last_rc}" -ne 0 ]; then
		fail "go dirty-yw failed: $(cat "${last_err}")"
	fi
	tdyw_path="${last_out}"
	printf 'y\n' >> "${tdyw_path}/file.txt"
	invoke git wt done dirty-yw -y
	if [ "${last_rc}" -eq 0 ]; then
		fail "done -y on a dirty tree without --force should fail"
	fi
	if ! grep -q force "${last_err}"; then
		fail "done -y dirty refusal should mention --force"
	fi
	if [ ! -d "${tdyw_path}" ]; then
		fail "done -y without --force should leave ${tdyw_path}"
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

# Sorted lines of $1, for order-insensitive path-list comparison.
#
# Globals:
#   None
# Arguments:
#   $1 - newline-separated text
# Outputs:
#   Sorted non-empty lines on STDOUT
# Returns:
#   0
sorted_lines() {
	printf '%s\n' "$1" | sed '/^$/d' | LC_ALL=C sort
}

# --list prints exactly the go-created worktrees (including a slash
# branch), not main or a foreign worktree, and removes nothing.
test_cleanup_list_current_repo() {
	tclc_repo=$(make_repo)
	cd "${tclc_repo}"
	invoke git wt go list-a
	tclc_a="${last_out}"
	invoke git wt go feature/x
	tclc_x="${last_out}"
	tclc_foreign="$(mktemp -d)/foreign"
	git worktree add -q -b foreign-l "${tclc_foreign}" >/dev/null 2>&1
	invoke git wt cleanup --list
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --list failed (${last_rc}): $(cat "${last_err}")"
	fi
	tclc_want=$(sorted_lines "${tclc_a}
${tclc_x}")
	tclc_got=$(sorted_lines "${last_out}")
	if [ "${tclc_got}" != "${tclc_want}" ]; then
		fail "cleanup --list: expected [${tclc_want}], got [${tclc_got}]"
	fi
	for tclc_dir in "${tclc_a}" "${tclc_x}" "${tclc_foreign}"; do
		if [ ! -d "${tclc_dir}" ]; then
			fail "cleanup --list must not remove ${tclc_dir}"
		fi
	done
}

test_cleanup_list_excludes_other_repo() {
	tclo_one=$(make_repo)
	tclo_two=$(make_repo)
	cd "${tclo_two}"
	invoke git wt go other-b
	cd "${tclo_one}"
	invoke git wt go mine-a
	tclo_mine="${last_out}"
	invoke git wt cleanup --list
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --list failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tclo_mine}" ]; then
		fail "cleanup --list should print only ${tclo_mine}, got: ${last_out}"
	fi
}

# --all from outside any repo finds go worktrees in every repo, including
# a slash branch nested one directory deeper.
test_cleanup_list_all() {
	tcla_one=$(make_repo)
	tcla_two=$(make_repo)
	cd "${tcla_one}"
	invoke git wt go all-a
	tcla_a="${last_out}"
	invoke git wt go feat/y
	tcla_y="${last_out}"
	cd "${tcla_two}"
	invoke git wt go all-b
	tcla_b="${last_out}"
	cd "$(mktemp -d)"
	invoke git wt cleanup --all --list
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --all --list failed (${last_rc}): $(cat "${last_err}")"
	fi
	tcla_want=$(sorted_lines "${tcla_a}
${tcla_y}
${tcla_b}")
	tcla_got=$(sorted_lines "${last_out}")
	if [ "${tcla_got}" != "${tcla_want}" ]; then
		fail "cleanup --all --list: expected [${tcla_want}], got [${tcla_got}]"
	fi
}

# Repos whose name starts with a dot (e.g. .github) live in dot-named
# directories under ~/worktrees; --all must still find them.
test_cleanup_list_all_dot_repo() {
	tcld_repo=$(make_repo)
	git -C "${tcld_repo}" remote add origin \
		git@github.com:Texarkanine/.github.git
	cd "${tcld_repo}"
	invoke git wt go dot-br
	tcld_path="${last_out}"
	cd "$(mktemp -d)"
	invoke git wt cleanup --all --list
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --all --list failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tcld_path}" ]; then
		fail "cleanup --all --list should print ${tcld_path}, got: ${last_out}"
	fi
}

# A stray non-worktree directory with symlink loops must not hang the
# --all scan, and the real worktree beside it is still listed.
test_cleanup_list_all_symlink_loop() {
	tcsl_repo=$(make_repo)
	tcsl_base=$(basename "${tcsl_repo}")
	cd "${tcsl_repo}"
	invoke git wt go real
	tcsl_real="${last_out}"
	tcsl_stray="${HOME}/worktrees/local/${tcsl_base}/${tcsl_base}-stray"
	mkdir -p "${tcsl_stray}/sub"
	ln -s . "${tcsl_stray}/self"
	ln -s .. "${tcsl_stray}/sub/up"
	cd "$(mktemp -d)"
	tcsl_rc=0
	run_with_timeout 20 git wt cleanup --all --list \
		>"${HOME}/out" 2>"${HOME}/err" || tcsl_rc=$?
	if [ "${tcsl_rc}" -ne 0 ]; then
		fail "cleanup --all --list hung or failed (${tcsl_rc}): $(cat "${HOME}/err")"
	fi
	if [ "$(cat "${HOME}/out")" != "${tcsl_real}" ]; then
		fail "cleanup --all --list should print ${tcsl_real}, got: $(cat "${HOME}/out")"
	fi
}

test_cleanup_list_empty() {
	tcle_repo=$(make_repo)
	cd "${tcle_repo}"
	invoke git wt cleanup --list
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --list with none should exit 0 (got ${last_rc})"
	fi
	if [ -n "${last_out}" ]; then
		fail "cleanup --list with none should print nothing, got: ${last_out}"
	fi
}

# A worktree whose directory was deleted by hand is prunable, not listed.
test_cleanup_list_skips_missing() {
	tcls_repo=$(make_repo)
	cd "${tcls_repo}"
	invoke git wt go gone
	rm -rf "${last_out}"
	invoke git wt go kept
	tcls_kept="${last_out}"
	invoke git wt cleanup --list
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --list with a missing tree failed: $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tcls_kept}" ]; then
		fail "cleanup --list should print only ${tcls_kept}, got: ${last_out}"
	fi
}

# Without --force, dirty worktrees are skipped (not a failure); foreign
# worktrees and branches are untouched.
test_cleanup_yes_clean_only() {
	tcyc_repo=$(make_repo)
	cd "${tcyc_repo}"
	invoke git wt go yc-clean
	tcyc_clean="${last_out}"
	invoke git wt go yc-dirty
	tcyc_dirty="${last_out}"
	printf 'y\n' >> "${tcyc_dirty}/file.txt"
	tcyc_foreign="$(mktemp -d)/foreign"
	git worktree add -q -b yc-foreign "${tcyc_foreign}" >/dev/null 2>&1
	invoke git wt cleanup --yes
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --yes failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ -n "${last_out}" ]; then
		fail "cleanup --yes from main should print nothing, got: ${last_out}"
	fi
	if [ -d "${tcyc_clean}" ]; then
		fail "cleanup --yes should remove clean ${tcyc_clean}"
	fi
	if [ ! -d "${tcyc_dirty}" ]; then
		fail "cleanup --yes without --force should keep dirty ${tcyc_dirty}"
	fi
	if ! grep -q force "${last_err}"; then
		fail "cleanup --yes should say dirty trees need --force"
	fi
	if [ ! -d "${tcyc_foreign}" ]; then
		fail "cleanup --yes must not remove foreign ${tcyc_foreign}"
	fi
	if ! git show-ref --verify --quiet refs/heads/yc-clean; then
		fail "cleanup should leave branch yc-clean"
	fi
}

# --yes --force removes dirty trees too. The PTY answers n, so any prompt
# would abort.
test_cleanup_yes_force_no_prompt() {
	tcyf_repo=$(make_repo)
	cd "${tcyf_repo}"
	invoke git wt go yf-clean
	tcyf_clean="${last_out}"
	invoke git wt go yf-dirty
	tcyf_dirty="${last_out}"
	printf 'y\n' >> "${tcyf_dirty}/file.txt"
	tcyf_foreign="$(mktemp -d)/foreign"
	git worktree add -q -b yf-foreign "${tcyf_foreign}" >/dev/null 2>&1
	tcyf_rc=0
	run_with_tty n git wt cleanup --yes --force || tcyf_rc=$?
	if [ "${tcyf_rc}" -ne 0 ]; then
		fail "cleanup --yes --force should not prompt (got ${tcyf_rc})"
	fi
	if [ -d "${tcyf_clean}" ] || [ -d "${tcyf_dirty}" ]; then
		fail "cleanup --yes --force should remove clean and dirty trees"
	fi
	if [ ! -d "${tcyf_foreign}" ]; then
		fail "cleanup --yes --force must not remove foreign ${tcyf_foreign}"
	fi
}

test_cleanup_prompt_yes() {
	tcpy_repo=$(make_repo)
	cd "${tcpy_repo}"
	invoke git wt go py-clean
	tcpy_path="${last_out}"
	tcpy_rc=0
	run_with_tty y git wt cleanup || tcpy_rc=$?
	if [ "${tcpy_rc}" -ne 0 ]; then
		fail "cleanup answered y should succeed (got ${tcpy_rc})"
	fi
	if [ -d "${tcpy_path}" ]; then
		fail "cleanup answered y should remove ${tcpy_path}"
	fi
}

test_cleanup_prompt_no() {
	tcpn_repo=$(make_repo)
	cd "${tcpn_repo}"
	invoke git wt go pn-clean
	tcpn_path="${last_out}"
	tcpn_rc=0
	run_with_tty n git wt cleanup || tcpn_rc=$?
	if [ "${tcpn_rc}" -eq 0 ]; then
		fail "cleanup answered n should be non-zero"
	fi
	if [ ! -d "${tcpn_path}" ]; then
		fail "cleanup answered n should keep ${tcpn_path}"
	fi
}

test_cleanup_nothing() {
	tcn_repo=$(make_repo)
	cd "${tcn_repo}"
	invoke git wt cleanup --yes
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup with nothing to do should exit 0 (got ${last_rc})"
	fi
	if [ -n "${last_out}" ]; then
		fail "cleanup with nothing to do should print nothing: ${last_out}"
	fi
}

# From inside a go worktree, cleanup removes it and prints main so the
# wt wrapper can cd there.
test_cleanup_inside_worktree() {
	tciw_repo=$(make_repo)
	tciw_main=$(main_path "${tciw_repo}")
	cd "${tciw_repo}"
	invoke git wt go iw-other
	tciw_other="${last_out}"
	invoke git wt go iw-here
	tciw_here="${last_out}"
	cd "${tciw_here}"
	invoke git wt cleanup --yes
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup from inside failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tciw_main}" ]; then
		fail "cleanup from inside should print ${tciw_main}, got: ${last_out}"
	fi
	if [ -d "${tciw_here}" ] || [ -d "${tciw_other}" ]; then
		fail "cleanup from inside should remove both worktrees"
	fi
}

test_cleanup_all_yes() {
	tcay_one=$(make_repo)
	tcay_two=$(make_repo)
	cd "${tcay_one}"
	invoke git wt go ay-a
	tcay_a="${last_out}"
	cd "${tcay_two}"
	invoke git wt go ay-b
	tcay_b="${last_out}"
	cd "$(mktemp -d)"
	invoke git wt cleanup --all --yes
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --all --yes failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ -d "${tcay_a}" ] || [ -d "${tcay_b}" ]; then
		fail "cleanup --all --yes should remove worktrees in both repos"
	fi
}

# A locked worktree cannot be removed; cleanup keeps going and exits
# non-zero.
test_cleanup_continues_after_failure() {
	tccf_repo=$(make_repo)
	cd "${tccf_repo}"
	invoke git wt go cf-locked
	tccf_locked="${last_out}"
	invoke git wt go cf-ok
	tccf_ok="${last_out}"
	git worktree lock "${tccf_locked}"
	invoke git wt cleanup --yes
	if [ "${last_rc}" -eq 0 ]; then
		fail "cleanup with a locked worktree should be non-zero"
	fi
	if [ ! -d "${tccf_locked}" ]; then
		fail "cleanup should leave locked ${tccf_locked}"
	fi
	if [ -d "${tccf_ok}" ]; then
		fail "cleanup should still remove ${tccf_ok}"
	fi
}

test_cleanup_not_a_repo() {
	cd "$(mktemp -d)"
	invoke git wt cleanup --list
	if [ "${last_rc}" -eq 0 ]; then
		fail "cleanup outside a repo without --all should be non-zero"
	fi
}

# --list +cursor prints go worktrees and this repo's Cursor worktrees,
# including a detached HEAD, and not a foreign worktree, another
# repo's Cursor worktree, or the main checkout. It removes nothing.
test_cleanup_list_cursor_current_repo() {
	tcc_repo=$(make_repo)
	cd "${tcc_repo}"
	invoke git wt go go-a
	tcc_go="${last_out}"
	tcc_detached="${HOME}/.cursor/worktrees/sess/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/sess"
	git worktree add --detach "${tcc_detached}" >/dev/null 2>&1
	tcc_branched="${HOME}/.cursor/worktrees/sess/repoish-b"
	git worktree add -q -b cursor-b "${tcc_branched}" >/dev/null 2>&1
	tcc_foreign="$(mktemp -d)/foreign"
	git worktree add -q -b foreign-c "${tcc_foreign}" >/dev/null 2>&1
	tcc_other=$(make_repo)
	tcc_other_wt="${HOME}/.cursor/worktrees/other-sess/other"
	mkdir -p "${HOME}/.cursor/worktrees/other-sess"
	git -C "${tcc_other}" worktree add --detach "${tcc_other_wt}" >/dev/null 2>&1
	cd "${tcc_repo}"
	invoke git wt cleanup --list +cursor
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --list +cursor failed (${last_rc}): $(cat "${last_err}")"
	fi
	tcc_want=$(sorted_lines "${tcc_go}
${tcc_detached}
${tcc_branched}")
	tcc_got=$(sorted_lines "${last_out}")
	if [ "${tcc_got}" != "${tcc_want}" ]; then
		fail "cleanup --list +cursor: expected [${tcc_want}], got [${tcc_got}]"
	fi
	for tcc_dir in "${tcc_go}" "${tcc_detached}" "${tcc_branched}" \
		"${tcc_foreign}" "${tcc_other_wt}"; do
		if [ ! -d "${tcc_dir}" ]; then
			fail "cleanup --list +cursor must not remove ${tcc_dir}"
		fi
	done
}

# +cursor may appear before the flags.
test_cleanup_list_cursor_token_position() {
	tcp_repo=$(make_repo)
	cd "${tcp_repo}"
	invoke git wt go pos-a
	tcp_go="${last_out}"
	tcp_wt="${HOME}/.cursor/worktrees/pos/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/pos"
	git worktree add --detach "${tcp_wt}" >/dev/null 2>&1
	invoke git wt cleanup +cursor --list
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup +cursor --list failed (${last_rc}): $(cat "${last_err}")"
	fi
	tcp_want=$(sorted_lines "${tcp_go}
${tcp_wt}")
	tcp_got=$(sorted_lines "${last_out}")
	if [ "${tcp_got}" != "${tcp_want}" ]; then
		fail "cleanup +cursor --list: expected [${tcp_want}], got [${tcp_got}]"
	fi
}

# Without +cursor, a Cursor worktree is not listed.
test_cleanup_list_without_cursor_excludes_cursor() {
	tcw_repo=$(make_repo)
	cd "${tcw_repo}"
	invoke git wt go plain-a
	tcw_go="${last_out}"
	tcw_wt="${HOME}/.cursor/worktrees/plain/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/plain"
	git worktree add --detach "${tcw_wt}" >/dev/null 2>&1
	invoke git wt cleanup --list
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --list failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tcw_go}" ]; then
		fail "cleanup --list should print only ${tcw_go}, got: ${last_out}"
	fi
}

test_cleanup_cursor_unknown_source() {
	tcu_repo=$(make_repo)
	cd "${tcu_repo}"
	invoke git wt go keep-a
	tcu_go="${last_out}"
	invoke git wt cleanup --list +foo
	if [ "${last_rc}" -eq 0 ]; then
		fail "cleanup +foo should be non-zero"
	fi
	if [ ! -d "${tcu_go}" ]; then
		fail "cleanup +foo must not remove ${tcu_go}"
	fi
}

test_cleanup_cursor_outside_repo() {
	cd "$(mktemp -d)"
	invoke git wt cleanup +cursor --list
	if [ "${last_rc}" -eq 0 ]; then
		fail "cleanup +cursor outside a repo should be non-zero"
	fi
}

# --all +cursor from outside a repo lists go worktrees and Cursor
# worktrees for every repo that has either.
test_cleanup_list_all_cursor() {
	tcal_one=$(make_repo)
	tcal_two=$(make_repo)
	cd "${tcal_one}"
	invoke git wt go all-c
	tcal_go="${last_out}"
	tcal_c1="${HOME}/.cursor/worktrees/all-one/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/all-one"
	git worktree add --detach "${tcal_c1}" >/dev/null 2>&1
	tcal_c2="${HOME}/.cursor/worktrees/all-two/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/all-two"
	git -C "${tcal_two}" worktree add --detach "${tcal_c2}" >/dev/null 2>&1
	cd "$(mktemp -d)"
	invoke git wt cleanup --all --list +cursor
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --all --list +cursor failed (${last_rc}): $(cat "${last_err}")"
	fi
	tcal_want=$(sorted_lines "${tcal_go}
${tcal_c1}
${tcal_c2}")
	tcal_got=$(sorted_lines "${last_out}")
	if [ "${tcal_got}" != "${tcal_want}" ]; then
		fail "cleanup --all --list +cursor: expected [${tcal_want}], got [${tcal_got}]"
	fi
}

# --all +cursor finds a session directory whose name starts with a dot.
test_cleanup_list_all_cursor_dot_session() {
	tcad_repo=$(make_repo)
	cd "${tcad_repo}"
	tcad_wt="${HOME}/.cursor/worktrees/.github/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/.github"
	git worktree add --detach "${tcad_wt}" >/dev/null 2>&1
	cd "$(mktemp -d)"
	invoke git wt cleanup --all --list +cursor
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --all --list +cursor failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tcad_wt}" ]; then
		fail "dot session should be listed, got: ${last_out}"
	fi
}

# An empty session directory is not a worktree and is not listed.
test_cleanup_list_all_cursor_ignores_empty() {
	tcie_repo=$(make_repo)
	cd "${tcie_repo}"
	tcie_wt="${HOME}/.cursor/worktrees/keep/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/keep"
	git worktree add --detach "${tcie_wt}" >/dev/null 2>&1
	mkdir -p "${HOME}/.cursor/worktrees/empty-sess"
	cd "$(mktemp -d)"
	invoke git wt cleanup --all --list +cursor
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --all --list +cursor failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tcie_wt}" ]; then
		fail "empty session should be ignored, got: ${last_out}"
	fi
}

# A symlink loop under ~/.cursor/worktrees must not hang --all +cursor.
test_cleanup_list_all_cursor_symlink_loop() {
	tcss_repo=$(make_repo)
	cd "${tcss_repo}"
	tcss_wt="${HOME}/.cursor/worktrees/real/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/real"
	git worktree add --detach "${tcss_wt}" >/dev/null 2>&1
	tcss_stray="${HOME}/.cursor/worktrees/stray"
	mkdir -p "${tcss_stray}/sub"
	ln -s . "${tcss_stray}/self"
	ln -s .. "${tcss_stray}/sub/up"
	cd "$(mktemp -d)"
	tcss_rc=0
	run_with_timeout 20 git wt cleanup --all --list +cursor \
		>"${HOME}/out" 2>"${HOME}/err" || tcss_rc=$?
	if [ "${tcss_rc}" -ne 0 ]; then
		fail "cleanup --all --list +cursor hung or failed (${tcss_rc}): $(cat "${HOME}/err")"
	fi
	if [ "$(cat "${HOME}/out")" != "${tcss_wt}" ]; then
		fail "cleanup --all --list +cursor should print ${tcss_wt}, got: $(cat "${HOME}/out")"
	fi
}

# +cursor --yes removes a clean Cursor worktree and its go worktree,
# leaves a foreign worktree, and removes the empty session directory.
test_cleanup_cursor_yes_removes_and_rmdir() {
	tcyr_repo=$(make_repo)
	cd "${tcyr_repo}"
	invoke git wt go yr-go
	tcyr_go="${last_out}"
	tcyr_session="${HOME}/.cursor/worktrees/yr"
	tcyr_wt="${tcyr_session}/repoish"
	mkdir -p "${tcyr_session}"
	git worktree add --detach "${tcyr_wt}" >/dev/null 2>&1
	tcyr_foreign="$(mktemp -d)/foreign"
	git worktree add -q -b yr-foreign "${tcyr_foreign}" >/dev/null 2>&1
	invoke git wt cleanup +cursor --yes
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup +cursor --yes failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ -d "${tcyr_go}" ] || [ -d "${tcyr_wt}" ]; then
		fail "cleanup +cursor --yes should remove go and cursor worktrees"
	fi
	if [ -d "${tcyr_session}" ]; then
		fail "cleanup +cursor --yes should remove empty session ${tcyr_session}"
	fi
	if [ ! -d "${tcyr_foreign}" ]; then
		fail "cleanup +cursor --yes must leave ${tcyr_foreign}"
	fi
}

# A dirty Cursor worktree is skipped without --force, and that is not
# an error.
test_cleanup_cursor_dirty_skipped() {
	tcds_repo=$(make_repo)
	cd "${tcds_repo}"
	tcds_wt="${HOME}/.cursor/worktrees/dirty/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/dirty"
	git worktree add --detach "${tcds_wt}" >/dev/null 2>&1
	printf 'y\n' >> "${tcds_wt}/file.txt"
	invoke git wt cleanup +cursor --yes
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup +cursor --yes on dirty should exit 0 (got ${last_rc})"
	fi
	if [ ! -d "${tcds_wt}" ]; then
		fail "dirty cursor worktree should be left without --force"
	fi
}

# --force removes a dirty Cursor worktree.
test_cleanup_cursor_dirty_force() {
	tcdf_repo=$(make_repo)
	cd "${tcdf_repo}"
	tcdf_wt="${HOME}/.cursor/worktrees/force/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/force"
	git worktree add --detach "${tcdf_wt}" >/dev/null 2>&1
	printf 'y\n' >> "${tcdf_wt}/file.txt"
	invoke git wt cleanup +cursor --yes --force
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup +cursor --yes --force failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ -d "${tcdf_wt}" ]; then
		fail "cleanup +cursor --yes --force should remove ${tcdf_wt}"
	fi
}

# A session directory that still has another entry is left in place.
test_cleanup_cursor_keeps_nonempty_session() {
	tckn_repo=$(make_repo)
	cd "${tckn_repo}"
	tckn_session="${HOME}/.cursor/worktrees/keep"
	tckn_wt="${tckn_session}/repoish"
	mkdir -p "${tckn_session}/other"
	git worktree add --detach "${tckn_wt}" >/dev/null 2>&1
	invoke git wt cleanup +cursor --yes
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup +cursor --yes failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ -d "${tckn_wt}" ]; then
		fail "cleanup +cursor --yes should remove ${tckn_wt}"
	fi
	if [ ! -d "${tckn_session}/other" ]; then
		fail "non-empty session directory should remain"
	fi
}

# A repo with both a go worktree and a Cursor worktree is removed once
# under --all +cursor --yes.
test_cleanup_all_cursor_yes_once() {
	tcao_repo=$(make_repo)
	cd "${tcao_repo}"
	invoke git wt go once-go
	tcao_go="${last_out}"
	tcao_wt="${HOME}/.cursor/worktrees/once/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/once"
	git worktree add --detach "${tcao_wt}" >/dev/null 2>&1
	cd "$(mktemp -d)"
	invoke git wt cleanup --all +cursor --yes
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --all +cursor --yes failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ -d "${tcao_go}" ] || [ -d "${tcao_wt}" ]; then
		fail "cleanup --all +cursor --yes should remove both worktrees once"
	fi
}

test_cleanup_unknown_option() {
	tcuo_repo=$(make_repo)
	cd "${tcuo_repo}"
	invoke git wt cleanup --bogus
	if [ "${last_rc}" -eq 0 ]; then
		fail "cleanup unknown option should be non-zero"
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

test_gitwt_root_go_done_cleanup() {
	tgr_repo=$(make_repo)
	git -C "${tgr_repo}" remote add origin \
		git@github.com:Texarkanine/ai-rizz.git
	GITWT_ROOT="${HOME}/custom-root"
	export GITWT_ROOT
	cd "${tgr_repo}"
	tgr_want="${GITWT_ROOT}/Texarkanine/ai-rizz/ai-rizz-feature-x"
	tgr_default="${HOME}/worktrees/Texarkanine/ai-rizz/ai-rizz-feature-x"
	invoke git wt go feature-x
	if [ "${last_rc}" -ne 0 ]; then
		fail "go with GITWT_ROOT failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tgr_want}" ]; then
		fail "GITWT_ROOT path: expected ${tgr_want}, got ${last_out}"
	fi
	if [ ! -d "${tgr_want}" ]; then
		fail "go did not create ${tgr_want}"
	fi
	if [ -d "${tgr_default}" ]; then
		fail "go created the default path ${tgr_default}"
	fi
	cd "$(mktemp -d)"
	invoke git wt cleanup --all --list
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --all --list with GITWT_ROOT failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tgr_want}" ]; then
		fail "cleanup --all --list: expected ${tgr_want}, got ${last_out}"
	fi
	cd "${tgr_repo}"
	tgr_cursor="${HOME}/.cursor/worktrees/sess/repoish"
	mkdir -p "${HOME}/.cursor/worktrees/sess"
	git worktree add --detach "${tgr_cursor}" >/dev/null 2>&1
	invoke git wt cleanup --list +cursor
	if [ "${last_rc}" -ne 0 ]; then
		fail "cleanup --list +cursor with GITWT_ROOT failed (${last_rc}): $(cat "${last_err}")"
	fi
	tgr_cwant=$(sorted_lines "${tgr_want}
${tgr_cursor}")
	tgr_cgot=$(sorted_lines "${last_out}")
	if [ "${tgr_cgot}" != "${tgr_cwant}" ]; then
		fail "cleanup --list +cursor: expected [${tgr_cwant}], got [${tgr_cgot}]"
	fi
	invoke git wt done feature-x
	if [ "${last_rc}" -ne 0 ]; then
		fail "done with GITWT_ROOT failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ -d "${tgr_want}" ]; then
		fail "done should remove ${tgr_want}"
	fi
}

test_gitwt_root_empty() {
	tge_repo=$(make_repo)
	git -C "${tge_repo}" remote add origin \
		git@github.com:Texarkanine/ai-rizz.git
	GITWT_ROOT=
	export GITWT_ROOT
	cd "${tge_repo}"
	tge_want="${HOME}/worktrees/Texarkanine/ai-rizz/ai-rizz-empty"
	invoke git wt go empty
	if [ "${last_rc}" -ne 0 ]; then
		fail "go with empty GITWT_ROOT failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tge_want}" ]; then
		fail "empty GITWT_ROOT path: expected ${tge_want}, got ${last_out}"
	fi
}

test_gitwt_root_relative() {
	trel_repo=$(make_repo)
	git -C "${trel_repo}" remote add origin \
		git@github.com:Texarkanine/ai-rizz.git
	GITWT_ROOT=relative/root
	export GITWT_ROOT
	cd "${trel_repo}"
	invoke git wt go feature-x
	if [ "${last_rc}" -eq 0 ]; then
		fail "relative GITWT_ROOT should be non-zero"
	fi
	if [ -e "${trel_repo}/relative/root" ]; then
		fail "relative GITWT_ROOT created ${trel_repo}/relative/root"
	fi
	case "$(cat "${last_err}")" in
		*"must be an absolute path"*) ;;
		*) fail "relative GITWT_ROOT stderr: $(cat "${last_err}")" ;;
	esac
	case "$(cat "${last_err}")" in
		*mkdir*) fail "relative GITWT_ROOT continued after the error: $(cat "${last_err}")" ;;
	esac
}

test_gitwt_root_trailing_slash() {
	tgts_repo=$(make_repo)
	git -C "${tgts_repo}" remote add origin \
		git@github.com:Texarkanine/ai-rizz.git
	GITWT_ROOT="${HOME}/custom-root/"
	export GITWT_ROOT
	cd "${tgts_repo}"
	tgts_want="${HOME}/custom-root/Texarkanine/ai-rizz/ai-rizz-feature-x"
	invoke git wt go feature-x
	if [ "${last_rc}" -ne 0 ]; then
		fail "go with trailing slash failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tgts_want}" ]; then
		fail "trailing slash path: expected ${tgts_want}, got ${last_out}"
	fi
	case "${last_out}" in
		*//*) fail "trailing slash path contains //: ${last_out}" ;;
	esac
}

test_gitwt_root_spaces() {
	tgs_repo=$(make_repo)
	git -C "${tgs_repo}" remote add origin \
		git@github.com:Texarkanine/ai-rizz.git
	GITWT_ROOT="${HOME}/custom root"
	export GITWT_ROOT
	cd "${tgs_repo}"
	tgs_want="${GITWT_ROOT}/Texarkanine/ai-rizz/ai-rizz-space-br"
	invoke git wt go space-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "go with spaced GITWT_ROOT failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ "${last_out}" != "${tgs_want}" ]; then
		fail "spaced GITWT_ROOT path: expected ${tgs_want}, got ${last_out}"
	fi
	if [ ! -d "${tgs_want}" ]; then
		fail "go did not create ${tgs_want}"
	fi
	invoke git wt done space-br
	if [ "${last_rc}" -ne 0 ]; then
		fail "done with spaced GITWT_ROOT failed (${last_rc}): $(cat "${last_err}")"
	fi
	if [ -d "${tgs_want}" ]; then
		fail "done should remove ${tgs_want}"
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
	run_one test_done_force_yes_flag_no_prompt
	run_one test_done_yes_without_force_dirty
	run_one test_done_unknown_option
	run_one test_done_home_with_spaces
	run_one test_cleanup_list_current_repo
	run_one test_cleanup_list_excludes_other_repo
	run_one test_cleanup_list_all
	run_one test_cleanup_list_all_symlink_loop
	run_one test_cleanup_list_all_dot_repo
	run_one test_cleanup_list_empty
	run_one test_cleanup_list_skips_missing
	run_one test_cleanup_yes_clean_only
	run_one test_cleanup_yes_force_no_prompt
	run_one test_cleanup_prompt_yes
	run_one test_cleanup_prompt_no
	run_one test_cleanup_nothing
	run_one test_cleanup_inside_worktree
	run_one test_cleanup_all_yes
	run_one test_cleanup_continues_after_failure
	run_one test_cleanup_not_a_repo
	run_one test_cleanup_unknown_option
	run_one test_cleanup_list_cursor_current_repo
	run_one test_cleanup_list_cursor_token_position
	run_one test_cleanup_list_without_cursor_excludes_cursor
	run_one test_cleanup_cursor_unknown_source
	run_one test_cleanup_cursor_outside_repo
	run_one test_cleanup_list_all_cursor
	run_one test_cleanup_list_all_cursor_dot_session
	run_one test_cleanup_list_all_cursor_ignores_empty
	run_one test_cleanup_list_all_cursor_symlink_loop
	run_one test_cleanup_cursor_yes_removes_and_rmdir
	run_one test_cleanup_cursor_dirty_skipped
	run_one test_cleanup_cursor_dirty_force
	run_one test_cleanup_cursor_keeps_nonempty_session
	run_one test_cleanup_all_cursor_yes_once
	run_one test_gitwt_root_go_done_cleanup
	run_one test_gitwt_root_empty
	run_one test_gitwt_root_relative
	run_one test_gitwt_root_trailing_slash
	run_one test_gitwt_root_spaces

	rm -rf "${TEST_BIN}"

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All git-wt tests passed"
}

main "$@"
