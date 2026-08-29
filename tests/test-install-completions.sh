#!/bin/sh
#
# test-install-completions.sh - Tests for make completions / installer
#
# Runs the installer under a fake HOME. Makefile contract checks use
# `make -n` so they never edit the operator's RC files.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
INSTALLER="${REPO_DIR}/scripts/install-completions.bash"

OPERATOR_HOME="${HOME}"
failures=0

ZSH_FENCE_START="# >>> git-aliases zsh completion >>>"
ZSH_FENCE_END="# <<< git-aliases zsh completion <<<"
BASH_FENCE_START="# >>> git-aliases bash completion >>>"
SHELL_FENCE_START="# >>> git-aliases shell integration >>>"

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

# Run an installer test with HOME in a temp dir.
#
# Globals:
#   OPERATOR_HOME, INSTALLER
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
	ri_status=0
	(
		HOME="${ri_home}"
		export HOME
		"${ri_body}"
	) || ri_status=$?
	rm -rf "${ri_home}"
	return "${ri_status}"
}

test_install_copies_zsh_and_writes_fence() {
	printf '# keep-zshrc\n' > "${HOME}/.zshrc"
	if ! "${INSTALLER}"; then
		fail "install should succeed"
	fi
	tic_dir="${HOME}/.local/share/git-aliases/completions"
	if [ ! -f "${tic_dir}/git-sync-completion.zsh" ]; then
		fail "missing ${tic_dir}/git-sync-completion.zsh"
	fi
	if [ ! -f "${tic_dir}/git-identity-completion.zsh" ]; then
		fail "missing ${tic_dir}/git-identity-completion.zsh"
	fi
	if ! grep -qx "${ZSH_FENCE_START}" "${HOME}/.zshrc"; then
		fail ".zshrc missing zsh fence start"
	fi
	if ! grep -qx "${ZSH_FENCE_END}" "${HOME}/.zshrc"; then
		fail ".zshrc missing zsh fence end"
	fi
	if ! grep -Fq '$+functions[compdef]' "${HOME}/.zshrc"; then
		fail ".zshrc fence should skip compinit when compdef exists"
	fi
	if ! grep -q 'compinit -C' "${HOME}/.zshrc"; then
		fail ".zshrc fence should bootstrap with compinit -C when needed"
	fi
	if ! grep -q 'git-sync-completion.zsh' "${HOME}/.zshrc"; then
		fail ".zshrc should source git-sync-completion.zsh"
	fi
	if ! grep -q 'git-identity-completion.zsh' "${HOME}/.zshrc"; then
		fail ".zshrc should source git-identity-completion.zsh"
	fi
}

test_install_fence_preserves_prior_compdefs() {
	printf '# keep-zshrc\n' > "${HOME}/.zshrc"
	if ! "${INSTALLER}"; then
		fail "install should succeed"
	fi
	if ! zsh -f -c '
		autoload -Uz compinit compdef
		compinit -C
		_dummy() { :; }
		compdef _dummy git-other
		. "${HOME}/.zshrc"
		if [[ -z ${_comps[git-other]-} ]]; then
			exit 1
		fi
	'; then
		fail "fence must not wipe a prior compdef"
	fi
}

test_install_idempotent() {
	printf '# keep-zshrc\n' > "${HOME}/.zshrc"
	"${INSTALLER}"
	"${INSTALLER}"
	tic_count=$(grep -c "${ZSH_FENCE_START}" "${HOME}/.zshrc" || true)
	if [ "${tic_count}" != 1 ]; then
		fail "zsh fence start should appear once, got ${tic_count}"
	fi
}

test_install_preserves_zshrc_and_distinct_fence() {
	printf '# keep-zshrc\n' > "${HOME}/.zshrc"
	"${INSTALLER}"
	if ! grep -q "keep-zshrc" "${HOME}/.zshrc"; then
		fail "install must preserve existing .zshrc content"
	fi
	if grep -q "${SHELL_FENCE_START}" "${HOME}/.zshrc"; then
		fail "completions fence must not use the shell-integration marker"
	fi
}

test_install_without_zsh_skips_zshrc_keeps_bash() {
	GIT_ALIASES_ZSH=
	export GIT_ALIASES_ZSH
	printf '# keep-zshrc\n' > "${HOME}/.zshrc"
	if ! "${INSTALLER}"; then
		fail "installer should exit 0 when GIT_ALIASES_ZSH is empty"
	fi
	if grep -q "${ZSH_FENCE_START}" "${HOME}/.zshrc"; then
		fail "empty GIT_ALIASES_ZSH must not write a zshrc fence"
	fi
	if ! grep -q "keep-zshrc" "${HOME}/.zshrc"; then
		fail "without-zsh install must preserve .zshrc"
	fi
	tic_dir="${HOME}/.local/share/git-aliases/completions"
	if [ ! -f "${tic_dir}/git-sync-completion.bash" ]; then
		fail "without-zsh install should still copy bash completions"
	fi
	if [ ! -f "${HOME}/.bash_completion" ]; then
		fail "without-zsh install should still write ~/.bash_completion"
	fi
	if ! grep -q "${BASH_FENCE_START}" "${HOME}/.bash_completion"; then
		fail "without-zsh install should still write the bash fence"
	fi
}

test_uninstall_removes_zsh_fence() {
	printf '# keep-zshrc\n' > "${HOME}/.zshrc"
	"${INSTALLER}"
	"${INSTALLER}" --uninstall
	if grep -q "${ZSH_FENCE_START}" "${HOME}/.zshrc"; then
		fail "uninstall should remove zsh fence start"
	fi
	if grep -q "${ZSH_FENCE_END}" "${HOME}/.zshrc"; then
		fail "uninstall should remove zsh fence end"
	fi
	if ! grep -q "keep-zshrc" "${HOME}/.zshrc"; then
		fail "uninstall must preserve other .zshrc content"
	fi
}

test_second_uninstall() {
	printf '# keep-zshrc\n' > "${HOME}/.zshrc"
	"${INSTALLER}"
	"${INSTALLER}" --uninstall
	if ! "${INSTALLER}" --uninstall; then
		fail "second uninstall should succeed"
	fi
	if ! grep -q "keep-zshrc" "${HOME}/.zshrc"; then
		fail "second uninstall must preserve .zshrc content"
	fi
}

test_bash_copy_and_fence_unregressed() {
	"${INSTALLER}"
	tic_dir="${HOME}/.local/share/git-aliases/completions"
	if [ ! -f "${tic_dir}/git-sync-completion.bash" ]; then
		fail "missing bash git-sync completion copy"
	fi
	if [ ! -f "${tic_dir}/git-identity-completion.bash" ]; then
		fail "missing bash git-identity completion copy"
	fi
	if ! grep -q "${BASH_FENCE_START}" "${HOME}/.bash_completion"; then
		fail "bash fence should still be written"
	fi
	"${INSTALLER}" --uninstall
	if grep -q "${BASH_FENCE_START}" "${HOME}/.bash_completion"; then
		fail "uninstall should still strip the bash fence"
	fi
}

test_make_n_test_runs_new_suites() {
	tmn_out=$(make -C "${REPO_DIR}" -n test)
	case "${tmn_out}" in
		*test-zsh-completion.sh*) ;;
		*) fail "make -n test should invoke test-zsh-completion.sh" ;;
	esac
	case "${tmn_out}" in
		*test-install-completions.sh*) ;;
		*) fail "make -n test should invoke test-install-completions.sh" ;;
	esac
}

test_make_completions_and_clean_invoke_bash_installer() {
	tmc_out=$(make -C "${REPO_DIR}" -n completions)
	case "${tmc_out}" in
		*install-completions.bash*) ;;
		*) fail "make -n completions should invoke install-completions.bash" ;;
	esac
	case "${tmc_out}" in
		*install-completions.sh*)
			fail "make -n completions should not invoke install-completions.sh"
			;;
	esac
	tmc_clean=$(make -C "${REPO_DIR}" -n clean)
	case "${tmc_clean}" in
		*install-completions.bash*) ;;
		*) fail "make -n clean should invoke install-completions.bash" ;;
	esac
	case "${tmc_clean}" in
		*install-completions.sh*)
			fail "make -n clean should not invoke install-completions.sh"
			;;
	esac
}

run_one() {
	ro_name="$1"
	ro_isolated="$2"
	if [ "${ro_isolated}" = "isolated" ]; then
		if run_isolated "${ro_name}"; then
			:
		else
			echo "FAIL: ${ro_name}" >&2
			failures=$((failures + 1))
		fi
	else
		if "${ro_name}"; then
			:
		else
			echo "FAIL: ${ro_name}" >&2
			failures=$((failures + 1))
		fi
	fi
}

main() {
	if [ ! -f "${INSTALLER}" ]; then
		echo "FAIL: missing ${INSTALLER}" >&2
		exit 1
	fi
	chmod +x "${INSTALLER}"

	run_one test_install_copies_zsh_and_writes_fence isolated
	run_one test_install_fence_preserves_prior_compdefs isolated
	run_one test_install_idempotent isolated
	run_one test_install_preserves_zshrc_and_distinct_fence isolated
	run_one test_install_without_zsh_skips_zshrc_keeps_bash isolated
	run_one test_uninstall_removes_zsh_fence isolated
	run_one test_second_uninstall isolated
	run_one test_bash_copy_and_fence_unregressed isolated
	run_one test_make_n_test_runs_new_suites no
	run_one test_make_completions_and_clean_invoke_bash_installer no

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All completions install tests passed"
}

main "$@"
