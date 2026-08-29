#!/bin/sh
#
# test-install-shell-integration.sh - Tests for make shell / installer
#
# Runs the installer under a fake HOME. Makefile contract checks use
# `make -n` so they never edit the operator's RC files.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
INSTALLER="${REPO_DIR}/scripts/install-shell-integration.bash"

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

test_install_files_and_fences() {
	printf '# keep-bashrc\n' > "${HOME}/.bashrc"
	printf '# keep-zshrc\n' > "${HOME}/.zshrc"
	if ! "${INSTALLER}"; then
		fail "install should succeed"
	fi
	tif_dir="${HOME}/.local/share/git-aliases/shell"
	if [ ! -f "${tif_dir}/wt.bash" ]; then
		fail "missing ${tif_dir}/wt.bash"
	fi
	if [ ! -f "${tif_dir}/wt.zsh" ]; then
		fail "missing ${tif_dir}/wt.zsh"
	fi
	if ! grep -q "keep-bashrc" "${HOME}/.bashrc"; then
		fail "install must preserve existing .bashrc content"
	fi
	if ! grep -q "keep-zshrc" "${HOME}/.zshrc"; then
		fail "install must preserve existing .zshrc content"
	fi
	if ! grep -q "# >>> git-aliases shell integration >>>" "${HOME}/.bashrc"; then
		fail ".bashrc missing fence start"
	fi
	if ! grep -q "# <<< git-aliases shell integration <<<" "${HOME}/.bashrc"; then
		fail ".bashrc missing fence end"
	fi
	if ! grep -q "wt.bash" "${HOME}/.bashrc"; then
		fail ".bashrc should source wt.bash"
	fi
	if grep -q "wt.zsh" "${HOME}/.bashrc"; then
		fail ".bashrc should not source wt.zsh"
	fi
	if ! grep -q "# >>> git-aliases shell integration >>>" "${HOME}/.zshrc"; then
		fail ".zshrc missing fence start"
	fi
	if ! grep -q "wt.zsh" "${HOME}/.zshrc"; then
		fail ".zshrc should source wt.zsh"
	fi
	if grep -q "wt.bash" "${HOME}/.zshrc"; then
		fail ".zshrc should not source wt.bash"
	fi
}

test_install_creates_rc_if_absent() {
	if [ -f "${HOME}/.bashrc" ] || [ -f "${HOME}/.zshrc" ]; then
		fail "precondition: RC files should be absent"
	fi
	if ! "${INSTALLER}"; then
		fail "install should create missing RC files"
	fi
	if [ ! -f "${HOME}/.bashrc" ] || [ ! -f "${HOME}/.zshrc" ]; then
		fail "install should create .bashrc and .zshrc"
	fi
}

test_install_idempotent() {
	"${INSTALLER}"
	"${INSTALLER}"
	tii_bash=$(grep -c "# >>> git-aliases shell integration >>>" "${HOME}/.bashrc")
	tii_zsh=$(grep -c "# >>> git-aliases shell integration >>>" "${HOME}/.zshrc")
	if [ "${tii_bash}" -ne 1 ]; then
		fail ".bashrc should have one fence after reinstall, got ${tii_bash}"
	fi
	if [ "${tii_zsh}" -ne 1 ]; then
		fail ".zshrc should have one fence after reinstall, got ${tii_zsh}"
	fi
	if [ ! -f "${HOME}/.local/share/git-aliases/shell/wt.bash" ]; then
		fail "snippets should remain after reinstall"
	fi
}

test_uninstall() {
	"${INSTALLER}"
	if ! "${INSTALLER}" --uninstall; then
		fail "uninstall should succeed"
	fi
	if [ -e "${HOME}/.local/share/git-aliases/shell/wt.bash" ] \
		|| [ -e "${HOME}/.local/share/git-aliases/shell/wt.zsh" ]; then
		fail "uninstall should remove snippet files"
	fi
	if grep -q "git-aliases shell integration" "${HOME}/.bashrc" 2>/dev/null; then
		fail "uninstall should remove .bashrc fence"
	fi
	if grep -q "git-aliases shell integration" "${HOME}/.zshrc" 2>/dev/null; then
		fail "uninstall should remove .zshrc fence"
	fi
}

test_second_uninstall() {
	"${INSTALLER}"
	"${INSTALLER}" --uninstall
	if ! "${INSTALLER}" --uninstall; then
		fail "second uninstall should be clean"
	fi
}

test_make_all_does_not_depend_on_shell() {
	tma_out=$(make -C "${REPO_DIR}" -n all)
	case "${tma_out}" in
		*install-shell-integration*)
			fail "make -n all must not invoke the shell installer"
			;;
	esac
}

test_make_clean_invokes_shell_uninstall() {
	tmc_out=$(make -C "${REPO_DIR}" -n clean)
	case "${tmc_out}" in
		*install-shell-integration.bash*) ;;
		*) fail "make -n clean should invoke the shell installer" ;;
	esac
	case "${tmc_out}" in
		*--uninstall*) ;;
		*) fail "make -n clean should pass --uninstall" ;;
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

	run_one test_install_files_and_fences isolated
	run_one test_install_creates_rc_if_absent isolated
	run_one test_install_idempotent isolated
	run_one test_uninstall isolated
	run_one test_second_uninstall isolated
	run_one test_make_all_does_not_depend_on_shell no
	run_one test_make_clean_invokes_shell_uninstall no

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All shell-integration install tests passed"
}

main "$@"
