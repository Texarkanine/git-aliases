#!/bin/sh
#
# gh - pin gh to the checkout's GitHub account
#
# When local github.account is set, look up that login's token and
# exec the real gh with it. Otherwise exec the real gh unchanged.
#
# git-aliases-gh-shim

set -eu

# Return 0 when the file contains the shim marker.
#
# Globals:
#   None
# Arguments:
#   $1 - path to a candidate binary
# Outputs:
#   None
# Returns:
#   0 when the marker is present
#   1 when the marker is absent or the file cannot be read
file_has_marker() {
	if grep -q 'git-aliases-gh-shim' "$1" 2>/dev/null; then
		return 0
	fi
	return 1
}

# Locate the real gh binary.
#
# Globals:
#   HOME - libexec directory lives under HOME
#   PATH - searched when libexec has no real binary
# Arguments:
#   None
# Outputs:
#   gh path to STDOUT
# Returns:
#   0 when a real binary is found
#   1 when every candidate is missing or is this shim
resolve_real_gh() {
	rrg_libexec="${HOME}/.local/libexec/git-aliases/gh"
	if [ -f "${rrg_libexec}" ] \
		&& [ -x "${rrg_libexec}" ] \
		&& ! file_has_marker "${rrg_libexec}"; then
		printf '%s\n' "${rrg_libexec}"
		return 0
	fi

	rrg_saved_ifs="${IFS}"
	set -f
	IFS=:
	# shellcheck disable=SC2086
	set -- ${PATH}
	IFS="${rrg_saved_ifs}"
	set +f

	for rrg_dir in "$@"; do
		if [ -z "${rrg_dir}" ]; then
			rrg_dir="."
		fi
		rrg_candidate="${rrg_dir}/gh"
		if [ -f "${rrg_candidate}" ] \
			&& [ -x "${rrg_candidate}" ] \
			&& ! file_has_marker "${rrg_candidate}"; then
			printf '%s\n' "${rrg_candidate}"
			return 0
		fi
	done
	return 1
}

# Replace this process with the real gh.
#
# Globals:
#   GIT_ALIASES_GH_SHIM - exported so a later shim invocation stops
#   real_gh - path chosen by resolve_real_gh
# Arguments:
#   $@ - arguments for the real gh
# Outputs:
#   None from this process
# Returns:
#   Does not return on success
exec_real() {
	export GIT_ALIASES_GH_SHIM=1
	exec "${real_gh}" "$@"
}

# Read the local pin and exec the real gh.
#
# Globals:
#   GIT_ALIASES_GH_SHIM - when already set, this process is a loop
#   real_gh - set to the resolved binary
#   GH_TOKEN, GITHUB_TOKEN, GH_ENTERPRISE_TOKEN, GITHUB_ENTERPRISE_TOKEN
#     cleared, then the looked-up token is exported as the GH_* pair
#   GH_HOST - left unchanged
# Arguments:
#   $@ - arguments for gh
# Outputs:
#   An error to STDERR when the shim loops, no real gh exists,
#   or the pin has no token
# Returns:
#   The real gh status, or 1 when the pin cannot be honored
main() {
	if [ -n "${GIT_ALIASES_GH_SHIM-}" ]; then
		echo "Error: gh shim invoked itself" >&2
		exit 1
	fi
	export GIT_ALIASES_GH_SHIM=1

	if ! real_gh=$(resolve_real_gh); then
		echo "Error: real gh not found" >&2
		exit 1
	fi

	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		exec_real "$@"
	fi

	ga_account=$(git config --local --get github.account 2>/dev/null) \
		|| ga_account=""
	if [ -z "${ga_account}" ]; then
		exec_real "$@"
	fi

	unset GH_TOKEN
	unset GITHUB_TOKEN
	unset GH_ENTERPRISE_TOKEN
	unset GITHUB_ENTERPRISE_TOKEN

	ga_host=$(git config --local --get github.host 2>/dev/null) || ga_host=""

	ga_token=""
	if [ -n "${ga_host}" ]; then
		if ! ga_token=$(
			"${real_gh}" auth token \
				--user "${ga_account}" \
				--hostname "${ga_host}"
		); then
			echo "Error: this checkout is pinned to ${ga_account} and gh has no token for it" >&2
			exit 1
		fi
	elif ! ga_token=$("${real_gh}" auth token --user "${ga_account}"); then
		echo "Error: this checkout is pinned to ${ga_account} and gh has no token for it" >&2
		exit 1
	fi
	if [ -z "${ga_token}" ]; then
		echo "Error: this checkout is pinned to ${ga_account} and gh has no token for it" >&2
		exit 1
	fi

	export GH_TOKEN="${ga_token}"
	export GH_ENTERPRISE_TOKEN="${ga_token}"
	unset GITHUB_TOKEN
	unset GITHUB_ENTERPRISE_TOKEN
	exec_real "$@"
}

case "${0##*/}" in
	gh|gh.sh)
		main "$@"
		;;
esac
