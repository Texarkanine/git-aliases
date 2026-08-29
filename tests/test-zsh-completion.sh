#!/bin/sh
#
# test-zsh-completion.sh - Zsh completion tests for git-sync and git-identity
#
# Invokes completer functions via zsh -c with a stubbed compadd. Does not
# drive git <TAB> through zsh's _git. Fails (does not skip) if zsh is missing.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
SYNC_ZSH="${REPO_DIR}/subcommands/git-sync/git-sync-completion.zsh"
IDENTITY_ZSH="${REPO_DIR}/subcommands/git-identity/git-identity-completion.zsh"

failures=0

if ! command -v zsh >/dev/null 2>&1; then
	echo "ERROR: zsh is required for test-zsh-completion.sh but was not found on PATH" >&2
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

# Source git-sync-completion.zsh and print _git_sync candidates.
#
# Globals:
#   SYNC_ZSH
# Arguments:
#   $1 - directory to cd into before completing
#   $@ - words array (CURRENT is the last word)
# Outputs:
#   Candidate names, one per line
# Returns:
#   Completer status
_complete_sync() {
	cs_dir=$1
	shift
	zsh -c '
		GIT_ALIASES_COMPLETION_TEST=1
		export GIT_ALIASES_COMPLETION_TEST
		cd "$2" || exit 1
		. "$1"
		shift
		shift
		words=("$@")
		CURRENT=$#
		compadd() {
			local a
			for a; do
				[[ "$a" == -- ]] && continue
				print -r -- "$a"
			done
		}
		_git_sync
	' zsh "${SYNC_ZSH}" "${cs_dir}" "$@"
}

# Source git-sync-completion.zsh and print stdout from sourcing.
#
# Globals:
#   SYNC_ZSH
# Arguments:
#   None
# Outputs:
#   Completer stdout
# Returns:
#   Source status
_source_sync() {
	zsh -c '
		GIT_ALIASES_COMPLETION_TEST=1
		export GIT_ALIASES_COMPLETION_TEST
		. "$1"
	' zsh "${SYNC_ZSH}"
}

test_sync_completes_branches() {
	tscb_repo=$(make_repo)
	git -C "${tscb_repo}" branch ga-other
	tscb_out=$(_complete_sync "${tscb_repo}" git-sync "")
	echo "${tscb_out}" | grep -qx main || fail "git-sync should complete main: ${tscb_out}"
	echo "${tscb_out}" | grep -qx ga-other || fail "git-sync should complete ga-other: ${tscb_out}"
	tscb_out=$(_complete_sync "${tscb_repo}" git sync "")
	echo "${tscb_out}" | grep -qx main || fail "git sync should complete main: ${tscb_out}"
	echo "${tscb_out}" | grep -qx ga-other || fail "git sync should complete ga-other: ${tscb_out}"
	rm -rf "${tscb_repo}"
}

test_sync_completes_flags_when_cur_starts_dash() {
	tscf_repo=$(make_repo)
	tscf_out=$(_complete_sync "${tscf_repo}" git-sync -)
	echo "${tscf_out}" | grep -qx -- -m || fail "dash cur should complete -m: ${tscf_out}"
	echo "${tscf_out}" | grep -qx -- --merge || fail "dash cur should complete --merge: ${tscf_out}"
	echo "${tscf_out}" | grep -qx -- -h || fail "dash cur should complete -h: ${tscf_out}"
	echo "${tscf_out}" | grep -qx -- --help || fail "dash cur should complete --help: ${tscf_out}"
	echo "${tscf_out}" | grep -qx main && fail "dash cur should not complete branches: ${tscf_out}"
	rm -rf "${tscf_repo}"
}

test_sync_after_merge_flag_completes_branches() {
	tsam_repo=$(make_repo)
	git -C "${tsam_repo}" branch ga-other
	tsam_out=$(_complete_sync "${tsam_repo}" git-sync -m "")
	echo "${tsam_out}" | grep -qx main || fail "after -m should complete main: ${tsam_out}"
	echo "${tsam_out}" | grep -qx ga-other || fail "after -m should complete ga-other: ${tsam_out}"
	tsam_out=$(_complete_sync "${tsam_repo}" git-sync --merge "")
	echo "${tsam_out}" | grep -qx main || fail "after --merge should complete main: ${tsam_out}"
	rm -rf "${tsam_repo}"
}

test_sync_after_help_flag_completes_nothing() {
	tsah_repo=$(make_repo)
	git -C "${tsah_repo}" branch ga-other
	tsah_out=$(_complete_sync "${tsah_repo}" git-sync -h "")
	if [ -n "${tsah_out}" ]; then
		fail "after -h should complete nothing: ${tsah_out}"
	fi
	tsah_out=$(_complete_sync "${tsah_repo}" git-sync --help "")
	if [ -n "${tsah_out}" ]; then
		fail "after --help should complete nothing: ${tsah_out}"
	fi
	rm -rf "${tsah_repo}"
}

test_sync_empty_repo_completes_nothing() {
	tser_dir=$(mktemp -d)
	git init -b main "${tser_dir}" >/dev/null
	tser_out=$(_complete_sync "${tser_dir}" git-sync "")
	if [ -n "${tser_out}" ]; then
		fail "unborn repo should complete no branches: ${tser_out}"
	fi
	rm -rf "${tser_dir}"
}

test_sync_registers_compdef_without_prior_compinit() {
	tsrc_got=$(zsh -f -c '
		emulate -L zsh
		. "$1"
		if [[ -n ${_comps[git-sync]:-} ]]; then
			print -r -- yes
		else
			print -r -- no
		fi
	' zsh "${SYNC_ZSH}")
	if [ "${tsrc_got}" != yes ]; then
		fail "should register compdef for git-sync without prior compinit: ${tsrc_got}"
	fi
}

test_sync_source_is_silent() {
	tssi_out=$(_source_sync)
	if [ -n "${tssi_out}" ]; then
		fail "sourcing git-sync-completion.zsh should print nothing: ${tssi_out}"
	fi
}

# Source git-identity-completion.zsh and print _git_identity candidates.
#
# Globals:
#   IDENTITY_ZSH
# Arguments:
#   $1 - HOME directory (identities live under .git-identities)
#   $@ - words array (CURRENT is the last word)
# Outputs:
#   Candidate names, one per line
# Returns:
#   Completer status
_complete_identity() {
	ci_home=$1
	shift
	HOME="${ci_home}" zsh -c '
		GIT_ALIASES_COMPLETION_TEST=1
		export GIT_ALIASES_COMPLETION_TEST
		. "$1"
		shift
		words=("$@")
		CURRENT=$#
		compadd() {
			local a
			for a; do
				[[ "$a" == -- ]] && continue
				print -r -- "$a"
			done
		}
		_git_identity
	' zsh "${IDENTITY_ZSH}" "$@"
}

# Source git-identity-completion.zsh and print stdout from sourcing.
#
# Globals:
#   IDENTITY_ZSH
# Arguments:
#   None
# Outputs:
#   Completer stdout
# Returns:
#   Source status
_source_identity() {
	zsh -c '
		GIT_ALIASES_COMPLETION_TEST=1
		export GIT_ALIASES_COMPLETION_TEST
		. "$1"
	' zsh "${IDENTITY_ZSH}"
}

test_identity_completes_commands() {
	ticc_home=$(mktemp -d)
	ticc_out=$(_complete_identity "${ticc_home}" git-identity "")
	echo "${ticc_out}" | grep -qx list || fail "git-identity should complete list: ${ticc_out}"
	echo "${ticc_out}" | grep -qx use || fail "git-identity should complete use: ${ticc_out}"
	echo "${ticc_out}" | grep -qx create || fail "git-identity should complete create: ${ticc_out}"
	ticc_out=$(_complete_identity "${ticc_home}" git identity "")
	echo "${ticc_out}" | grep -qx use || fail "git identity should complete use: ${ticc_out}"
	rm -rf "${ticc_home}"
}

test_identity_use_completes_names() {
	tiuc_home=$(mktemp -d)
	mkdir -p "${tiuc_home}/.git-identities"
	printf 'x\n' > "${tiuc_home}/.git-identities/work"
	printf 'x\n' > "${tiuc_home}/.git-identities/personal"
	tiuc_out=$(_complete_identity "${tiuc_home}" git-identity use "")
	echo "${tiuc_out}" | grep -qx work || fail "use should complete work: ${tiuc_out}"
	echo "${tiuc_out}" | grep -qx personal || fail "use should complete personal: ${tiuc_out}"
	rm -rf "${tiuc_home}"
}

test_identity_use_missing_dir_completes_nothing() {
	tium_home=$(mktemp -d)
	tium_out=$(_complete_identity "${tium_home}" git-identity use "")
	if [ -n "${tium_out}" ]; then
		fail "use with no identities dir should complete nothing: ${tium_out}"
	fi
	rm -rf "${tium_home}"
}

test_identity_after_list_or_create_completes_nothing() {
	tial_home=$(mktemp -d)
	tial_out=$(_complete_identity "${tial_home}" git-identity list "")
	if [ -n "${tial_out}" ]; then
		fail "after list should complete nothing: ${tial_out}"
	fi
	tial_out=$(_complete_identity "${tial_home}" git-identity create "")
	if [ -n "${tial_out}" ]; then
		fail "after create should complete nothing: ${tial_out}"
	fi
	rm -rf "${tial_home}"
}

test_identity_registers_compdef_without_prior_compinit() {
	tirc_got=$(zsh -f -c '
		emulate -L zsh
		. "$1"
		if [[ -n ${_comps[git-identity]:-} ]]; then
			print -r -- yes
		else
			print -r -- no
		fi
	' zsh "${IDENTITY_ZSH}")
	if [ "${tirc_got}" != yes ]; then
		fail "should register compdef for git-identity without prior compinit: ${tirc_got}"
	fi
}

test_identity_source_is_silent() {
	tisi_out=$(_source_identity)
	if [ -n "${tisi_out}" ]; then
		fail "sourcing git-identity-completion.zsh should print nothing: ${tisi_out}"
	fi
}

test_zsh_missing_fails() {
	tzm_bin=$(mktemp -d)
	ln -s "$(command -v dirname)" "${tzm_bin}/dirname"
	tzm_err=$(mktemp)
	tzm_rc=0
	PATH="${tzm_bin}" "${SCRIPT_DIR}/test-zsh-completion.sh" >/dev/null 2>"${tzm_err}" || tzm_rc=$?
	rm -rf "${tzm_bin}"
	if [ "${tzm_rc}" -eq 0 ]; then
		rm -f "${tzm_err}"
		fail "suite should fail when zsh is missing from PATH"
		return 0
	fi
	if ! grep -q zsh "${tzm_err}"; then
		fail "missing-zsh error should name zsh: $(cat "${tzm_err}")"
	fi
	rm -f "${tzm_err}"
}

main() {
	if [ ! -f "${SYNC_ZSH}" ]; then
		echo "FAIL: missing ${SYNC_ZSH}" >&2
		exit 1
	fi
	if [ ! -f "${IDENTITY_ZSH}" ]; then
		echo "FAIL: missing ${IDENTITY_ZSH}" >&2
		exit 1
	fi

	test_sync_completes_branches
	test_sync_completes_flags_when_cur_starts_dash
	test_sync_after_merge_flag_completes_branches
	test_sync_after_help_flag_completes_nothing
	test_sync_empty_repo_completes_nothing
	test_sync_registers_compdef_without_prior_compinit
	test_sync_source_is_silent
	test_identity_completes_commands
	test_identity_use_completes_names
	test_identity_use_missing_dir_completes_nothing
	test_identity_after_list_or_create_completes_nothing
	test_identity_registers_compdef_without_prior_compinit
	test_identity_source_is_silent
	test_zsh_missing_fails

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All zsh completion tests passed"
}

main "$@"
