#!/usr/bin/env bash
#
# install-completions.bash - Install or uninstall Bash and Zsh completion scripts
#
# Copies *-completion.bash and *-completion.zsh to
# ~/.local/share/git-aliases/completions/. Manages a fenced block in
# ~/.bash_completion, and when zsh is available a fenced block in ~/.zshrc.
#
# Usage:
#   ./install-completions.bash            # Install completions
#   ./install-completions.bash --uninstall # Uninstall completions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
FENCE_START="# >>> git-aliases bash completion >>>"
FENCE_END="# <<< git-aliases bash completion <<<"
COMPLETIONS_FILE="${HOME}/.bash_completion"
INSTALL_DIR="${HOME}/.local/share/git-aliases/completions"
MODE="install"
ZSH_FENCE_START="# >>> git-aliases zsh completion >>>"
ZSH_FENCE_END="# <<< git-aliases zsh completion <<<"
ZSH_RC="${HOME}/.zshrc"
GIT_ALIASES_ZSH="${GIT_ALIASES_ZSH-$(command -v zsh || true)}"

# Copy zsh completers and write a fenced ~/.zshrc block.
#
# Globals:
#   GIT_ALIASES_ZSH, INSTALL_DIR, REPO_DIR, ZSH_FENCE_START, ZSH_FENCE_END, ZSH_RC
# Arguments:
#   None
# Outputs:
#   Progress on STDOUT
# Returns:
#   0
install_zsh_completions() {
	local izc_file
	local izc_base

	if [[ -z "${GIT_ALIASES_ZSH}" ]]; then
		return 0
	fi

	echo "📥 Installing zsh completions..."
	find "${REPO_DIR}/subcommands" -name "*-completion.zsh" -type f -print0 |
		while IFS= read -r -d '' izc_file; do
			izc_base=$(basename "${izc_file}")
			cp -f "${izc_file}" "${INSTALL_DIR}/${izc_base}"
			chmod +x "${INSTALL_DIR}/${izc_base}"
			echo "	${izc_base}"
		done

	uninstall_zsh_completions
	touch "${ZSH_RC}"
	{
		echo "${ZSH_FENCE_START}"
		echo "autoload -Uz compinit compdef"
		echo "compinit -C"
		for izc_file in "${INSTALL_DIR}"/*-completion.zsh; do
			if [ -f "${izc_file}" ]; then
				echo "if [ -f \"${izc_file}\" ]; then"
				echo "  source \"${izc_file}\""
				echo "fi"
				echo ""
			fi
		done
		echo "${ZSH_FENCE_END}"
	} >> "${ZSH_RC}"
	echo "✅ Zsh completions installed successfully!"
}

# Strip the zsh completions fence from ~/.zshrc.
#
# Globals:
#   ZSH_FENCE_START, ZSH_FENCE_END, ZSH_RC
# Arguments:
#   None
# Outputs:
#   Progress on STDOUT
# Returns:
#   0
uninstall_zsh_completions() {
	if [[ ! -f "${ZSH_RC}" ]]; then
		return 0
	fi
	awk -v start="${ZSH_FENCE_START}" -v end="${ZSH_FENCE_END}" \
		'BEGIN{inblock=0} {if($0==start){inblock=1} else if($0==end){inblock=0; next} if(!inblock) print $0}' \
		"${ZSH_RC}" > "${ZSH_RC}.tmp"
	mv "${ZSH_RC}.tmp" "${ZSH_RC}"
}

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

if [[ "$MODE" == "install" ]]; then
    # Check for completion scripts using null-terminated names
    if [ -z "$(find "$REPO_DIR/subcommands" -name "*-completion.bash" -type f -print0 | tr -d '\0')" ]; then
    	echo "No completion scripts found in $REPO_DIR/subcommands"
    	exit 1
    fi
    
    echo "📥 Installing bash completions..."
    
    # Create directories (home dir already exists, no need to create)
    mkdir -p "$INSTALL_DIR"
    touch "$COMPLETIONS_FILE"
    
    # Copy completion files to install directory using null-terminated names
    find "$REPO_DIR/subcommands" -name "*-completion.bash" -type f -print0 | while IFS= read -r -d '' completion_file; do
    	base_name=$(basename "$completion_file")
    	cp -f "$completion_file" "$INSTALL_DIR/$base_name"
    	chmod +x "$INSTALL_DIR/$base_name"
    	echo "	$base_name"
    done
    
    # Remove any previous git-aliases fenced block
    awk -v start="$FENCE_START" -v end="$FENCE_END" \
    	'BEGIN{inblock=0} {if($0==start){inblock=1} else if($0==end){inblock=0; next} if(!inblock) print $0}' \
    	"$COMPLETIONS_FILE" > "$COMPLETIONS_FILE.tmp"
    mv "$COMPLETIONS_FILE.tmp" "$COMPLETIONS_FILE"
    
    # Append new fenced block
    echo "$FENCE_START" >> "$COMPLETIONS_FILE"
    
    # Add each installed completion file
    for completion_file in "$INSTALL_DIR"/*-completion.bash; do
    	if [ -f "$completion_file" ]; then
    		echo "# Source $(basename "$completion_file")" >> "$COMPLETIONS_FILE"
    		echo "if [ -f \"$completion_file\" ]; then" >> "$COMPLETIONS_FILE"
    		echo "  source \"$completion_file\"" >> "$COMPLETIONS_FILE"
    		echo "fi" >> "$COMPLETIONS_FILE"
    		echo "" >> "$COMPLETIONS_FILE"
    	fi
    done
    
    echo "$FENCE_END" >> "$COMPLETIONS_FILE"
    install_zsh_completions
    echo "✅ Bash completions installed successfully!"
    echo "Note: Source your ~/.bash_completion or restart your shell to enable completions"
else
    echo "📤 Uninstalling bash completions..."
    uninstall_zsh_completions
    
    # Remove the completion scripts directory
    if [ -d "$INSTALL_DIR" ]; then
    	rm -rf "$INSTALL_DIR"
    	echo "	Removed completion scripts directory: $INSTALL_DIR"
    fi
    
    # Remove the fenced block from bash_completion
    if [ -f "$COMPLETIONS_FILE" ]; then
    	awk -v start="$FENCE_START" -v end="$FENCE_END" \
    		'BEGIN{inblock=0} {if($0==start){inblock=1} else if($0==end){inblock=0; next} if(!inblock) print $0}' \
    		"$COMPLETIONS_FILE" > "$COMPLETIONS_FILE.tmp"
    	mv "$COMPLETIONS_FILE.tmp" "$COMPLETIONS_FILE"
    	echo "	Removed git-aliases completions from $COMPLETIONS_FILE"
    fi
    
    echo "✅ Bash completions uninstalled successfully!"
fi 