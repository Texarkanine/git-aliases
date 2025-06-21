#!/usr/bin/env bash
# install-bash-completion.sh
#
# Installs or uninstalls git-aliases bash completion scripts in ~/.bash_completion.
# Usage:
#   ./install-bash-completion.sh install   # Add or update fenced block
#   ./install-bash-completion.sh uninstall # Remove fenced block
#
# - Copies completion scripts to ~/.local/share/git-aliases/completions/
# - Always uses ~/.bash_completion (cross-platform)
# - Idempotent: removes any previous git-aliases block before adding
#
# Returns 0 on success, 1 on error.

set -euo pipefail

FENCE_START="# >>> git-aliases bash completion >>>"
FENCE_END="# <<< git-aliases bash completion <<<"
COMPLETIONS_FILE="$HOME/.bash_completion"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/git-aliases/completions"

usage() {
  echo "Usage: $0 install|uninstall" >&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  usage
fi

case "$1" in
  install)
    # Find all completion scripts
    COMPLETION_FILES=$(find "$REPO_DIR/subcommands" -name "*-completion.bash" -type f)
    if [ -z "$COMPLETION_FILES" ]; then
      echo "No completion scripts found in $REPO_DIR/subcommands"
      exit 1
    fi

    # Create directories
    mkdir -p "$HOME"
    mkdir -p "$INSTALL_DIR"
    touch "$COMPLETIONS_FILE"

    # Copy completion files to install directory
    for completion_file in $COMPLETION_FILES; do
      base_name=$(basename "$completion_file")
      cp -f "$completion_file" "$INSTALL_DIR/$base_name"
      chmod +x "$INSTALL_DIR/$base_name"
      echo "	$base_name"
    done
    
    # Remove any previous git-aliases fenced block
    awk -v start="$FENCE_START" -v end="$FENCE_END" 'BEGIN{inblock=0} {if($0==start){inblock=1} else if($0==end){inblock=0; next} if(!inblock) print $0}' "$COMPLETIONS_FILE" > "$COMPLETIONS_FILE.tmp"
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
    echo "Installed completions to $INSTALL_DIR and referenced in $COMPLETIONS_FILE"
    ;;
    
  uninstall)
    # Remove the completion scripts directory
    if [ -d "$INSTALL_DIR" ]; then
      rm -rf "$INSTALL_DIR"
      echo "Removed completion scripts directory: $INSTALL_DIR"
    fi
    
    # Remove the fenced block from bash_completion
    if [ -f "$COMPLETIONS_FILE" ]; then
      awk -v start="$FENCE_START" -v end="$FENCE_END" 'BEGIN{inblock=0} {if($0==start){inblock=1} else if($0==end){inblock=0; next} if(!inblock) print $0}' "$COMPLETIONS_FILE" > "$COMPLETIONS_FILE.tmp"
      mv "$COMPLETIONS_FILE.tmp" "$COMPLETIONS_FILE"
      echo "Removed git-aliases completions from $COMPLETIONS_FILE"
    fi
    ;;
    
  *)
    usage
    ;;
esac

exit 0
