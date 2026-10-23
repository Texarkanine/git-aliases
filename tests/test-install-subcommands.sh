#!/bin/sh
#
# test-install-subcommands.sh - Tests for subcommand install help pages
#
# Runs the installer under a fake HOME so cat pages and binaries stay
# out of the operator's ~/.local.

set -eu

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(CDPATH= cd "${SCRIPT_DIR}" && pwd)
REPO_DIR=$(dirname "${SCRIPT_DIR}")
INSTALLER="${REPO_DIR}/scripts/install-subcommands.sh"

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

test_help_pages_match_dash_h() {
	if ! "${INSTALLER}"; then
		fail "install should succeed"
	fi
	if ! "${INSTALLER}"; then
		fail "second install should succeed"
	fi
	for thp_name in wt sync identity; do
		for thp_dir in "${HOME}/.local/man/cat1" "${HOME}/.local/share/man/cat1"; do
			if [ ! -f "${thp_dir}/git-${thp_name}.1" ]; then
				fail "missing ${thp_dir}/git-${thp_name}.1"
			fi
		done
		thp_want=$("${HOME}/.local/bin/git-${thp_name}" -h)
		thp_got=$(
			env -u MANPATH \
				PAGER=cat MANPAGER=cat GIT_PAGER=cat \
				PATH="${HOME}/.local/bin:${PATH}" \
				git "${thp_name}" --help
		) || fail "git ${thp_name} --help should exit 0"
		if [ "${thp_got}" != "${thp_want}" ]; then
			fail "git ${thp_name} --help should match -h: got [${thp_got}] want [${thp_want}]"
		fi
	done
}

test_install_places_shim() {
	if ! "${INSTALLER}"; then
		fail "install should succeed"
	fi
	tis_bin="${HOME}/.local/bin/gh"
	if [ ! -f "${tis_bin}" ]; then
		fail "install should place ${tis_bin}"
	fi
	if [ ! -x "${tis_bin}" ]; then
		fail "installed shim should be executable"
	fi
	if ! grep -q 'git-aliases-gh-shim' "${tis_bin}"; then
		fail "installed gh should be the shim"
	fi
	if ! cmp -s "${REPO_DIR}/shims/gh.sh" "${tis_bin}"; then
		fail "installed gh should match shims/gh.sh"
	fi
}

test_install_parks_foreign_gh() {
	tip_bin="${HOME}/.local/bin/gh"
	tip_parked="${HOME}/.local/libexec/git-aliases/gh"
	tip_bytes="${HOME}/foreign-gh-bytes"
	mkdir -p "${HOME}/.local/bin"
	printf 'foreign-gh-bytes\n' > "${tip_bytes}"
	cp "${tip_bytes}" "${tip_bin}"
	if ! "${INSTALLER}"; then
		fail "install should park a foreign gh"
	fi
	if ! cmp -s "${tip_bytes}" "${tip_parked}"; then
		fail "parked gh should keep the foreign bytes"
	fi
	if ! cmp -s "${REPO_DIR}/shims/gh.sh" "${tip_bin}"; then
		fail "${tip_bin} should be the shim after parking"
	fi
	if [ ! -x "${tip_bin}" ]; then
		fail "installed shim should be executable"
	fi
}

test_reinstall_preserves_parked_gh() {
	tir_bin="${HOME}/.local/bin/gh"
	tir_parked="${HOME}/.local/libexec/git-aliases/gh"
	tir_bytes="${HOME}/foreign-gh-bytes"
	mkdir -p "${HOME}/.local/bin"
	printf 'foreign-gh-bytes\n' > "${tir_bytes}"
	cp "${tir_bytes}" "${tir_bin}"
	if ! "${INSTALLER}"; then
		fail "first install should park a foreign gh"
	fi
	if ! "${INSTALLER}"; then
		fail "reinstall should succeed"
	fi
	if ! cmp -s "${tir_bytes}" "${tir_parked}"; then
		fail "reinstall should leave the parked bytes unchanged"
	fi
	if ! cmp -s "${REPO_DIR}/shims/gh.sh" "${tir_bin}"; then
		fail "reinstall should refresh the shim"
	fi
}

test_install_refuses_second_foreign_gh() {
	tif_bin="${HOME}/.local/bin/gh"
	tif_parked="${HOME}/.local/libexec/git-aliases/gh"
	tif_bin_bytes="${HOME}/foreign-bin-bytes"
	tif_parked_bytes="${HOME}/parked-bytes"
	mkdir -p "${HOME}/.local/bin" "${HOME}/.local/libexec/git-aliases"
	printf 'foreign-bin\n' > "${tif_bin_bytes}"
	printf 'parked-bytes\n' > "${tif_parked_bytes}"
	cp "${tif_bin_bytes}" "${tif_bin}"
	cp "${tif_parked_bytes}" "${tif_parked}"
	if "${INSTALLER}"; then
		fail "install should refuse when a foreign gh and a parked gh both exist"
	fi
	if ! cmp -s "${tif_bin_bytes}" "${tif_bin}"; then
		fail "refused install should leave the foreign gh in place"
	fi
	if ! cmp -s "${tif_parked_bytes}" "${tif_parked}"; then
		fail "refused install should leave the parked gh unchanged"
	fi
}

test_uninstall_restores_parked_gh() {
	tur_bin="${HOME}/.local/bin/gh"
	tur_parked="${HOME}/.local/libexec/git-aliases/gh"
	tur_bytes="${HOME}/foreign-gh-bytes"
	mkdir -p "${HOME}/.local/bin"
	printf 'foreign-gh-bytes\n' > "${tur_bytes}"
	cp "${tur_bytes}" "${tur_bin}"
	if ! "${INSTALLER}"; then
		fail "install before uninstall should park the foreign gh"
	fi
	if ! cmp -s "${tur_bytes}" "${tur_parked}"; then
		fail "install should park the foreign gh before uninstall"
	fi
	if ! "${INSTALLER}" --uninstall; then
		fail "uninstall should succeed"
	fi
	if [ ! -f "${tur_bin}" ]; then
		fail "uninstall should put the parked gh back"
	fi
	if ! cmp -s "${tur_bytes}" "${tur_bin}"; then
		fail "restored gh should be the parked bytes"
	fi
	if [ -e "${tur_parked}" ]; then
		fail "uninstall should move the parked gh back, not leave it"
	fi
}

test_uninstall_leaves_foreign_gh() {
	tul_bin="${HOME}/.local/bin/gh"
	tul_bytes="${HOME}/foreign-gh-bytes"
	mkdir -p "${HOME}/.local/bin"
	printf 'foreign-gh-bytes\n' > "${tul_bytes}"
	cp "${tul_bytes}" "${tul_bin}"
	if ! "${INSTALLER}" --uninstall; then
		fail "uninstall should succeed when gh is foreign"
	fi
	if ! cmp -s "${tul_bytes}" "${tul_bin}"; then
		fail "uninstall should leave a foreign gh in place"
	fi
}

test_uninstall_removes_help_pages() {
	if ! "${INSTALLER}"; then
		fail "install before uninstall should succeed"
	fi
	if ! "${INSTALLER}" --uninstall; then
		fail "uninstall should succeed"
	fi
	for tuh_name in wt sync identity; do
		for tuh_dir in "${HOME}/.local/man/cat1" "${HOME}/.local/share/man/cat1"; do
			if [ -e "${tuh_dir}/git-${tuh_name}.1" ]; then
				fail "uninstall should remove ${tuh_dir}/git-${tuh_name}.1"
			fi
		done
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
	if [ ! -f "${INSTALLER}" ]; then
		echo "FAIL: missing ${INSTALLER}" >&2
		exit 1
	fi
	chmod +x "${INSTALLER}"

	run_one test_help_pages_match_dash_h
	run_one test_uninstall_removes_help_pages
	run_one test_install_places_shim
	run_one test_install_parks_foreign_gh
	run_one test_reinstall_preserves_parked_gh
	run_one test_install_refuses_second_foreign_gh
	run_one test_uninstall_restores_parked_gh
	run_one test_uninstall_leaves_foreign_gh

	if [ "${failures}" -ne 0 ]; then
		echo "${failures} test(s) failed" >&2
		exit 1
	fi
	echo "All install-subcommands tests passed"
}

main "$@"
