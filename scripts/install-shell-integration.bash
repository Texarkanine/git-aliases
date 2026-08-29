#!/usr/bin/env bash
#
# install-shell-integration.bash - Install or uninstall wt() shell wrappers
#
# Copies bash/zsh snippets to ~/.local/share/git-aliases/shell/ and manages
# fenced blocks in ~/.bashrc and ~/.zshrc. Not part of default `make`.
#
# Usage:
#   ./install-shell-integration.bash            # Install
#   ./install-shell-integration.bash --uninstall # Uninstall

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
FENCE_START="# >>> git-aliases shell integration >>>"
FENCE_END="# <<< git-aliases shell integration <<<"
INSTALL_DIR="${HOME}/.local/share/git-aliases/shell"
SRC_DIR="${REPO_DIR}/shell"
MODE="install"

# Remove a git-aliases shell-integration fenced block from an RC file.
#
# Globals:
#   FENCE_START, FENCE_END
# Arguments:
#   $1 - path to RC file
# Outputs:
#   None
# Returns:
#   0 (missing file is a no-op)
strip_fence() {
	local rc_file="${1}"
	[[ -f "${rc_file}" ]] || return 0
	awk -v start="${FENCE_START}" -v end="${FENCE_END}" \
		'BEGIN{inblock=0} {if($0==start){inblock=1} else if($0==end){inblock=0; next} if(!inblock) print $0}' \
		"${rc_file}" > "${rc_file}.tmp"
	mv "${rc_file}.tmp" "${rc_file}"
}

# Append a fenced source block for one wrapper snippet.
#
# Globals:
#   FENCE_START, FENCE_END
# Arguments:
#   $1 - path to RC file (created if missing)
#   $2 - snippet filename (wt.bash or wt.zsh)
# Outputs:
#   None
# Returns:
#   0
append_fence() {
	local rc_file="${1}"
	local snippet="${2}"
	touch "${rc_file}"
	cat >> "${rc_file}" <<EOF
${FENCE_START}
_ga_shell="\$HOME/.local/share/git-aliases/shell"
[[ -f "\$_ga_shell/${snippet}" ]] && source "\$_ga_shell/${snippet}"
${FENCE_END}
EOF
}

# Copy snippets and write fenced RC blocks.
#
# Globals:
#   HOME, INSTALL_DIR, SRC_DIR
# Arguments:
#   None
# Outputs:
#   Progress on STDOUT
# Returns:
#   0 on success
install_shell() {
	echo "📥 Installing shell integration..."
	mkdir -p "${INSTALL_DIR}"
	cp -f "${SRC_DIR}/wt.bash" "${INSTALL_DIR}/wt.bash"
	cp -f "${SRC_DIR}/wt.zsh" "${INSTALL_DIR}/wt.zsh"
	echo "	wt.bash"
	echo "	wt.zsh"

	strip_fence "${HOME}/.bashrc"
	append_fence "${HOME}/.bashrc" "wt.bash"
	strip_fence "${HOME}/.zshrc"
	append_fence "${HOME}/.zshrc" "wt.zsh"

	echo "✅ Shell integration installed."
	echo "Note: Source ~/.bashrc / ~/.zshrc or restart your shell to enable wt()"
}

# Remove snippets and fenced RC blocks.
#
# Globals:
#   HOME, INSTALL_DIR
# Arguments:
#   None
# Outputs:
#   Progress on STDOUT
# Returns:
#   0 (missing files are a no-op)
uninstall_shell() {
	echo "📤 Uninstalling shell integration..."
	if [[ -d "${INSTALL_DIR}" ]]; then
		rm -rf "${INSTALL_DIR}"
		echo "	Removed snippet directory: ${INSTALL_DIR}"
	fi
	if [[ -f "${HOME}/.bashrc" ]]; then
		strip_fence "${HOME}/.bashrc"
		echo "	Removed git-aliases shell integration from ${HOME}/.bashrc"
	fi
	if [[ -f "${HOME}/.zshrc" ]]; then
		strip_fence "${HOME}/.zshrc"
		echo "	Removed git-aliases shell integration from ${HOME}/.zshrc"
	fi
	echo "✅ Shell integration uninstalled."
}

# Parse arguments and run install or uninstall.
#
# Globals:
#   MODE
# Arguments:
#   $@ - optional --uninstall
# Outputs:
#   Progress on STDOUT; errors on STDERR
# Returns:
#   0 on success, non-zero on unknown option
main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--uninstall)
				MODE="uninstall"
				shift
				;;
			*)
				echo "Unknown option: $1" >&2
				echo "Usage: $0 [--uninstall]" >&2
				exit 1
				;;
		esac
	done

	if [[ "${MODE}" == "install" ]]; then
		install_shell
	else
		uninstall_shell
	fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
