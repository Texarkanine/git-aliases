#!/usr/bin/env bash
#
# install-subcommands.sh - Install or uninstall Git subcommands
#
# This script installs or uninstalls Git subcommands to/from ~/.local/bin/
#
# Usage:
#   ./install-subcommands.sh         # Install subcommands
#   ./install-subcommands.sh --uninstall # Uninstall subcommands

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SUBCOMMANDS_DIR="$REPO_DIR/subcommands"
INSTALL_DIR="${HOME}/.local/bin"
MODE="install"

# Parse arguments
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

# Install the gh shim and park a foreign binary aside.
#
# Globals:
#   HOME - install paths live under HOME
#   REPO_DIR - repository root, source of shims/gh.sh
# Arguments:
#   None
# Outputs:
#   An error to STDERR when a foreign gh and a parked gh both exist
# Returns:
#   0 when the shim is installed
#   1 when installing would destroy a parked binary
install_gh_shim() {
	local shim_src="${REPO_DIR}/shims/gh.sh"
	local target="${HOME}/.local/bin/gh"
	local parked="${HOME}/.local/libexec/git-aliases/gh"
	local libexec_dir="${HOME}/.local/libexec/git-aliases"

	mkdir -p "${libexec_dir}"
	mkdir -p "${HOME}/.local/bin"

	if [[ -f "${target}" ]] && grep -q 'git-aliases-gh-shim' "${target}"; then
		cp "${shim_src}" "${target}"
		chmod +x "${target}"
		echo "	gh"
		return 0
	fi

	if [[ -e "${target}" ]]; then
		if [[ -e "${parked}" ]]; then
			echo "Error: ${target} is not the gh shim and ${parked} already exists" >&2
			return 1
		fi
		mv "${target}" "${parked}"
	fi

	cp "${shim_src}" "${target}"
	chmod +x "${target}"
	echo "	gh"
}

# Remove the gh shim and restore a parked binary.
#
# Globals:
#   HOME - install paths live under HOME
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   0
uninstall_gh_shim() {
	local target="${HOME}/.local/bin/gh"
	local parked="${HOME}/.local/libexec/git-aliases/gh"

	if [[ -f "${target}" ]] && grep -q 'git-aliases-gh-shim' "${target}"; then
		echo "	Removing gh"
		rm -f "${target}"
	fi
	if [[ -e "${parked}" && ! -e "${target}" ]]; then
		mv "${parked}" "${target}"
	fi
}

if [[ "$MODE" == "install" ]]; then
    echo "📥 Installing Git subcommands..."
    
    # Create installation directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    install_gh_shim
    
    # Find all bash scripts (not completion scripts) and install them.
    # The loop stays in this shell so a failing -h aborts the install.
    while IFS= read -r -d '' file; do
    	cmd_name=$(basename "$file" .bash)
    	cmd_base=$(basename "$cmd_name" | sed 's/^git-//')
    	target="$INSTALL_DIR/git-$cmd_base"
    	
    	echo "	git-$cmd_base"
    	cp "$file" "$target"
    	chmod +x "$target"

    	help_empty=$(mktemp -d)
    	help_file=$(mktemp)
    	(
    		cd "${help_empty}" && "${target}" -h </dev/null > "${help_file}"
    	)
    	rm -rf "${help_empty}"
    	for help_dir in "${HOME}/.local/man/cat1" "${HOME}/.local/share/man/cat1"; do
    		mkdir -p "${help_dir}"
    		cp "${help_file}" "${help_dir}/git-${cmd_base}.1"
    	done
    	rm -f "${help_file}"
    done < <(find "$SUBCOMMANDS_DIR" -name "*.bash" -type f ! -name "*-completion.bash" -print0)
    
    echo "✅ Git subcommands installed successfully!"
    echo "Make sure ${HOME}/.local/bin is in your PATH."
else
    echo "📤 Uninstalling Git subcommands..."
    
    # Find all subcommand files in the repo and remove their installed versions.
    while IFS= read -r -d '' file; do
    	cmd_name=$(basename "$file" .bash)
    	cmd_base=$(basename "$cmd_name" | sed 's/^git-//')
    	target="$INSTALL_DIR/git-$cmd_base"
    	
    	if [ -f "$target" ]; then
    		echo "	Removing git-$cmd_base"
    		rm -f "$target"
    	fi
    	rm -f "${HOME}/.local/man/cat1/git-${cmd_base}.1"
    	rm -f "${HOME}/.local/share/man/cat1/git-${cmd_base}.1"
    done < <(find "$SUBCOMMANDS_DIR" -name "*.bash" -type f ! -name "*-completion.bash" -print0)

    uninstall_gh_shim
    
    echo "✅ Git subcommands uninstalled successfully!"
fi 