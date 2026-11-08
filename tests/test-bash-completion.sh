#!/bin/sh
#
# test-bash-completion.sh - Bash completion tests for git-wt and git-sync
#
# Direct cases set COMP_WORDS and read COMPREPLY. Tab cases drive one Tab
# in an interactive bash. Fails (does not skip) if bash is missing, or if
# python3 is missing when a Tab case runs.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
WT_BASH="${REPO_DIR}/subcommands/git-wt/git-wt-completion.bash"
SYNC_BASH="${REPO_DIR}/subcommands/git-sync/git-sync-completion.bash"

failures=0

if ! command -v bash >/dev/null 2>&1; then
	echo "ERROR: bash is required for test-bash-completion.sh but was not found on PATH" >&2
	exit 1
fi

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
	git -C "${mr_dir}" commit -q --no-gpg-sign -m init
	printf '%s\n' "${mr_dir}"
}

# Source git-wt-completion.bash and print COMPREPLY, one name per line.
#
# Globals:
#   WT_BASH
# Arguments:
#   $1 - directory to cd into before completing
#   $@ - COMP_WORDS (the last word is the current word)
# Outputs:
#   Candidate names, one per line
# Returns:
#   Completer status
_complete_wt() {
	cw_dir=$1
	shift
	bash -c '
		cd "$2" || exit 1
		. "$1"
		shift 2
		COMP_WORDS=("$@")
		COMP_CWORD=$(($# - 1))
		COMPREPLY=()
		_git_wt
		if [ "${#COMPREPLY[@]}" -gt 0 ]; then
			printf "%s\n" "${COMPREPLY[@]}"
		fi
	' bash "${WT_BASH}" "${cw_dir}" "$@"
}

# Print the transcript of one Tab in an interactive bash.
#
# Globals:
#   TAB_HELPER - optional bash text run before the completer is sourced
#   TAB_BIND_FN - function bound to git (default _git_wt)
# Arguments:
#   $1 - completer file
#   $2 - directory to cd into
#   $@ - words typed before Tab
# Outputs:
#   The screen text produced by that Tab
# Returns:
#   0, or exits 1 when python3 is missing
_tab_transcript() {
	tt_completer=$1
	tt_dir=$2
	shift 2
	if ! command -v python3 >/dev/null 2>&1; then
		echo "ERROR: python3 is required for tab completion tests" >&2
		exit 1
	fi
	tt_bash=$(command -v bash)
	TAB_HELPER="${TAB_HELPER-}" TAB_BIND_FN="${TAB_BIND_FN-_git_wt}" \
		python3 - "$tt_bash" "$tt_completer" "$tt_dir" "$@" <<'PY'
import os
import pty
import select
import shlex
import sys
import time

bash, completer, workdir = sys.argv[1:4]
words = sys.argv[4:]
helper = os.environ.get("TAB_HELPER", "")
bind_fn = os.environ.get("TAB_BIND_FN") or "_git_wt"

pid, fd = pty.fork()
if pid == 0:
    os.environ["PS1"] = "READY "
    os.environ["TERM"] = "dumb"
    os.execv(bash, ["bash", "--noprofile", "--norc", "-i"])

def read_for(seconds):
    buf = b""
    end = time.time() + seconds
    while time.time() < end:
        ready, _, _ = select.select([fd], [], [], 0.1)
        if not ready:
            continue
        try:
            data = os.read(fd, 4096)
        except OSError:
            break
        if not data:
            break
        buf += data
    return buf

read_for(0.2)
setup = ""
if helper:
    setup += helper + "\n"
setup += "cd %s\n" % shlex.quote(workdir)
setup += ". %s\n" % shlex.quote(completer)
setup += (
    "complete -o bashdefault -o default -o nospace -F %s git\n" % bind_fn
)
os.write(fd, setup.encode())
seen = read_for(1.0)
if b" -F " not in seen:
    sys.stderr.write("tab setup did not run\n")
    os.kill(pid, 9)
    os.waitpid(pid, 0)
    sys.exit(1)
os.write(fd, (" ".join(words) + "\t").encode())
tabbed = read_for(0.8)
os.write(fd, b"\nexit\n")
read_for(0.3)
os.kill(pid, 9)
try:
    os.waitpid(pid, 0)
except OSError:
    pass
sys.stdout.buffer.write(tabbed)
PY
}

test_wt_go_completes_local_branches() {
	twg_repo=$(make_repo)
	git -C "${twg_repo}" branch other
	twg_out=$(_complete_wt "${twg_repo}" git wt go "")
	echo "${twg_out}" | grep -qx main || fail "git wt go should complete main: ${twg_out}"
	echo "${twg_out}" | grep -qx other || fail "git wt go should complete other: ${twg_out}"
	twg_out=$(_complete_wt "${twg_repo}" wt go "")
	echo "${twg_out}" | grep -qx main || fail "wt go should complete main: ${twg_out}"
	echo "${twg_out}" | grep -qx other || fail "wt go should complete other: ${twg_out}"
	twg_out=$(_complete_wt "${twg_repo}" git-wt go "")
	echo "${twg_out}" | grep -qx main || fail "git-wt go should complete main: ${twg_out}"
	echo "${twg_out}" | grep -qx other || fail "git-wt go should complete other: ${twg_out}"
	rm -rf "${twg_repo}"
}

test_wt_go_prefix_filters() {
	twp_repo=$(make_repo)
	git -C "${twp_repo}" branch other
	twp_out=$(_complete_wt "${twp_repo}" git wt go ma)
	echo "${twp_out}" | grep -qx main || fail "prefix ma should complete main: ${twp_out}"
	echo "${twp_out}" | grep -qx other && fail "prefix ma should not complete other: ${twp_out}"
	twp_out=$(_complete_wt "${twp_repo}" git wt go zz)
	if [ -n "${twp_out}" ]; then
		fail "prefix zz should complete nothing: ${twp_out}"
	fi
	rm -rf "${twp_repo}"
}

test_wt_without_go_completes_nothing() {
	twn_repo=$(make_repo)
	git -C "${twn_repo}" branch other
	twn_out=$(_complete_wt "${twn_repo}" git wt "")
	if [ -n "${twn_out}" ]; then
		fail "git wt should complete nothing: ${twn_out}"
	fi
	twn_out=$(_complete_wt "${twn_repo}" git wt done "")
	if [ -n "${twn_out}" ]; then
		fail "git wt done should complete nothing: ${twn_out}"
	fi
	rm -rf "${twn_repo}"
}

test_wt_ignores_remote_and_outside_repo() {
	twr_repo=$(make_repo)
	git -C "${twr_repo}" update-ref refs/remotes/origin/remote-only HEAD
	twr_out=$(_complete_wt "${twr_repo}" git wt go "")
	echo "${twr_out}" | grep -qx main || fail "local main should still complete: ${twr_out}"
	echo "${twr_out}" | grep -qx remote-only \
		&& fail "remote-only should not complete: ${twr_out}"
	echo "${twr_out}" | grep -qx origin/remote-only \
		&& fail "origin/remote-only should not complete: ${twr_out}"
	twr_dir=$(mktemp -d)
	twr_out=$(_complete_wt "${twr_dir}" git wt go "")
	if [ -n "${twr_out}" ]; then
		fail "outside a repo should complete nothing: ${twr_out}"
	fi
	rm -rf "${twr_repo}" "${twr_dir}"
}

test_wt_source_binds_git_wt_and_wt() {
	tws_out=$(bash -c '. "$1"' bash "${WT_BASH}")
	if [ -n "${tws_out}" ]; then
		fail "sourcing git-wt-completion.bash should print nothing: ${tws_out}"
	fi
	tws_bind=$(bash -c '. "$1"; complete -p git-wt; complete -p wt' bash "${WT_BASH}")
	echo "${tws_bind}" | grep -q 'git-wt' || fail "complete -p should bind git-wt: ${tws_bind}"
	echo "${tws_bind}" | grep -q ' _git_wt git-wt' \
		|| fail "git-wt should use _git_wt: ${tws_bind}"
	echo "${tws_bind}" | grep -q ' _git_wt wt' \
		|| fail "wt should use _git_wt: ${tws_bind}"
}

test_wt_does_not_call_git_complete() {
	twc_out=$(bash -c '
		__git_complete() { printf "called %s %s\n" "$1" "$2"; }
		. "$1"
		complete -p wt
	' bash "${WT_BASH}")
	echo "${twc_out}" | grep -q 'called ' \
		&& fail "should not call __git_complete: ${twc_out}"
	echo "${twc_out}" | grep -qx 'complete -F _git_wt wt' \
		|| fail "wt should stay bound to _git_wt: ${twc_out}"
}

test_wt_go_keeps_literal_branch_names() {
	twl_repo=$(make_repo)
	git -C "${twl_repo}" branch 'feature/$USER'
	git -C "${twl_repo}" branch 'cmd$(true)'
	git -C "${twl_repo}" branch "has'quote"
	twl_out=$(_complete_wt "${twl_repo}" git wt go "")
	printf '%s\n' "${twl_out}" | grep -Fxq 'main' \
		|| fail "literal list should include main: ${twl_out}"
	printf '%s\n' "${twl_out}" | grep -Fxq 'feature/$USER' \
		|| fail "literal list should keep feature/\$USER: ${twl_out}"
	printf '%s\n' "${twl_out}" | grep -Fxq 'cmd$(true)' \
		|| fail "literal list should keep cmd\$(true): ${twl_out}"
	printf '%s\n' "${twl_out}" | grep -Fxq "has'quote" \
		|| fail "literal list should keep has'quote: ${twl_out}"
	printf '%s\n' "${twl_out}" | grep -Fxq 'cmd' \
		&& fail "literal list should not run a substitution: ${twl_out}"
	printf '%s\n' "${twl_out}" | grep -Fxq 'hasquote' \
		&& fail "literal list should not drop a quote: ${twl_out}"
	twl_feature=$(printf '%s\n' "${twl_out}" | grep '^feature/' || true)
	if [ "${twl_feature}" != 'feature/$USER' ]; then
		fail "feature/ line should be the literal name: ${twl_out}"
	fi
	rm -rf "${twl_repo}"
}

test_wt_go_literal_prefix() {
	twq_repo=$(make_repo)
	git -C "${twq_repo}" branch 'feature/$USER'
	twq_out=$(_complete_wt "${twq_repo}" git wt go 'feature/$U')
	if [ "${twq_out}" != 'feature/$USER' ]; then
		fail "prefix feature/\$U should complete the literal: ${twq_out}"
	fi
	rm -rf "${twq_repo}"
}

test_wt_go_tag_collision_keeps_head_name() {
	twt_repo=$(make_repo)
	git -C "${twt_repo}" branch feature/foo
	git -C "${twt_repo}" tag main
	twt_out=$(_complete_wt "${twt_repo}" git wt go "")
	printf '%s\n' "${twt_out}" | grep -Fxq 'main' \
		|| fail "tag collision should still offer main: ${twt_out}"
	printf '%s\n' "${twt_out}" | grep -Fxq 'feature/foo' \
		|| fail "tag collision should offer feature/foo: ${twt_out}"
	printf '%s\n' "${twt_out}" | grep -Fxq 'heads/main' \
		&& fail "tag collision should not offer heads/main: ${twt_out}"
	rm -rf "${twt_repo}"
}

test_wt_go_tab_skips_filenames() {
	twf_dir=$(mktemp -d)
	: > "${twf_dir}/zz-unique-file"
	twf_out=$(_tab_transcript "${WT_BASH}" "${twf_dir}" git wt go zz)
	printf '%s\n' "${twf_out}" | grep -F 'zz-unique-file' \
		&& fail "unmatched git wt go should not offer a file: ${twf_out}"
	rm -rf "${twf_dir}"
}

test_wt_go_tab_still_completes_branch() {
	twm_repo=$(make_repo)
	twm_out=$(_tab_transcript "${WT_BASH}" "${twm_repo}" git wt go ma)
	printf '%s\n' "${twm_out}" | grep -Fq 'git wt go main' \
		|| fail "git wt go ma should complete main: ${twm_out}"
	rm -rf "${twm_repo}"
}

test_sync_tab_skips_filenames_when_helper_fails() {
	tsf_dir=$(mktemp -d)
	: > "${tsf_dir}/zz-unique-file"
	tsf_out=$(
		TAB_HELPER='_get_comp_words_by_ref() { return 1; }' \
		TAB_BIND_FN=_git_sync \
		_tab_transcript "${SYNC_BASH}" "${tsf_dir}" git sync zz
	)
	printf '%s\n' "${tsf_out}" | grep -F 'zz-unique-file' \
		&& fail "git sync should not offer a file when the helper fails: ${tsf_out}"
	rm -rf "${tsf_dir}"
}

test_sync_tab_skips_filenames_when_nothing_matches() {
	tsn_repo=$(make_repo)
	: > "${tsn_repo}/zz-unique-file"
	tsn_out=$(
		TAB_HELPER='_get_comp_words_by_ref() { cur=${COMP_WORDS[COMP_CWORD]}; prev=${COMP_WORDS[COMP_CWORD-1]}; }' \
		TAB_BIND_FN=_git_sync \
		_tab_transcript "${SYNC_BASH}" "${tsn_repo}" git sync zz
	)
	printf '%s\n' "${tsn_out}" | grep -F 'zz-unique-file' \
		&& fail "unmatched git sync should not offer a file: ${tsn_out}"
	rm -rf "${tsn_repo}"
}

test_sync_tab_still_completes_branch() {
	tsm_repo=$(make_repo)
	tsm_out=$(
		TAB_HELPER='_get_comp_words_by_ref() { cur=${COMP_WORDS[COMP_CWORD]}; prev=${COMP_WORDS[COMP_CWORD-1]}; }' \
		TAB_BIND_FN=_git_sync \
		_tab_transcript "${SYNC_BASH}" "${tsm_repo}" git sync ma
	)
	printf '%s\n' "${tsm_out}" | grep -Fq 'git sync main' \
		|| fail "git sync ma should complete main: ${tsm_out}"
	rm -rf "${tsm_repo}"
}

test_bash_missing_fails() {
	tbm_bin=$(mktemp -d)
	ln -s "$(command -v dirname)" "${tbm_bin}/dirname"
	tbm_err=$(mktemp)
	tbm_rc=0
	PATH="${tbm_bin}" "${SCRIPT_DIR}/test-bash-completion.sh" >/dev/null 2>"${tbm_err}" || tbm_rc=$?
	rm -rf "${tbm_bin}"
	if [ "${tbm_rc}" -eq 0 ]; then
		rm -f "${tbm_err}"
		fail "suite should fail when bash is missing from PATH"
		return 0
	fi
	if ! grep -q bash "${tbm_err}"; then
		fail "missing-bash error should name bash: $(cat "${tbm_err}")"
	fi
	rm -f "${tbm_err}"
}

main() {
	if [ ! -f "${WT_BASH}" ]; then
		echo "FAIL: missing ${WT_BASH}" >&2
		exit 1
	fi

	test_wt_go_completes_local_branches
	test_wt_go_prefix_filters
	test_wt_without_go_completes_nothing
	test_wt_ignores_remote_and_outside_repo
	test_wt_source_binds_git_wt_and_wt
	test_wt_does_not_call_git_complete
	test_wt_go_keeps_literal_branch_names
	test_wt_go_literal_prefix
	test_wt_go_tag_collision_keeps_head_name
	test_wt_go_tab_skips_filenames
	test_wt_go_tab_still_completes_branch
	test_sync_tab_skips_filenames_when_helper_fails
	test_sync_tab_skips_filenames_when_nothing_matches
	test_sync_tab_still_completes_branch
	test_bash_missing_fails

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All bash completion tests passed"
}

main "$@"
