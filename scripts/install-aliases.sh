#!/usr/bin/env bash
#
# install-aliases.sh - Install or uninstall Git aliases from alias files
#
# This script reads alias definition files from the 'aliases/' directory
# and installs or uninstalls them as Git aliases using 'git config'
#
# Usage:
#   ./install-aliases.sh         # Install aliases
#   ./install-aliases.sh --uninstall # Uninstall aliases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ALIASES_DIR="$REPO_DIR/aliases"
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

if [[ "$MODE" == "install" ]]; then
    echo "📥 Installing Git aliases..."
    
    for file in "$ALIASES_DIR"/*; do
    	if [ -f "$file" ] && [ "$(basename "$file")" != "README.md" ]; then
    		echo "📃 $(basename "$file")..."
    		
    		while IFS= read -r line; do
    			if [ -n "$line" ] && ! echo "$line" | grep -q "^[[:space:]]*#"; then
    				name=$(echo "$line" | cut -d'=' -f1 | sed 's/^[ \t]*//;s/[ \t]*$//')
    				value=$(echo "$line" | cut -d'=' -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')
    				
    				if [ -n "$name" ] && [ -n "$value" ]; then
    					echo "	$name -> $value"
    					git config --global "alias.$name" "$value"
    				fi
    			fi
    		done < "$file"
    	fi
    done
    
    echo "✅ Git aliases installed successfully!"
else
    echo "📤 Uninstalling Git aliases..."
    
    for file in "$ALIASES_DIR"/*; do
    	if [ -f "$file" ] && [ "$(basename "$file")" != "README.md" ]; then
    		echo "📃 $(basename "$file")..."
    		
    		while IFS= read -r line; do
    			if [ -n "$line" ] && ! echo "$line" | grep -q "^[[:space:]]*#"; then
    				name=$(echo "$line" | cut -d'=' -f1 | sed 's/^[ \t]*//;s/[ \t]*$//')
    				
    				if [ -n "$name" ]; then
    					echo "	Removing alias.$name"
    					git config --global --unset "alias.$name" || true
    				fi
    			fi
    		done < "$file"
    	fi
    done
    
    echo "✅ Git aliases uninstalled successfully!"
fi 