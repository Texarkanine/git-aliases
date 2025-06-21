#!/bin/bash
#
# Script to test git-sync bash completion

# Source the completion script directly
echo "Loading completion script..."
source "$(pwd)/subcommands/git-sync/git-sync-completion.bash"
echo "Completion script loaded."

# Display available branches
echo
echo "Available branches in the current repository:"
echo "--------------------------------------------"
git --no-pager for-each-ref --format='%(refname:short)' refs/heads/
echo

# Emulate completion for various scenarios
echo "Testing completion scenarios:"
echo "----------------------------"

# Setup test function to emulate bash completion
test_completion() {
    local input="$1"
    echo -n "Completing '$input': "
    
    # Parse into words
    read -r -a COMP_WORDS <<< "$input"
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    COMP_LINE="$input"
    COMP_POINT=${#COMP_LINE}
    
    # Set cur to last word
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]:-}"
    
    # Run completion function
    COMPREPLY=()
    _git_sync_complete
    
    # Print results
    echo "${COMPREPLY[*]}"
}

# Test scenarios
test_completion "git sync "
test_completion "git sync m"
test_completion "git sync --merge "
test_completion "git-sync "

echo
echo "For interactive testing, try:"
echo "- git sync <TAB>"
echo "- git sync m<TAB>"
echo "- git sync --merge <TAB>"
echo

# Debug information
echo "Debugging information:"
echo "---------------------"
echo "Bash completion directories:"
for dir in $(pkg-config --variable=completionsdir bash-completion 2>/dev/null) \
          /etc/bash_completion.d \
          /usr/share/bash-completion/completions \
          /usr/local/share/bash-completion/completions \
          ~/.local/share/bash-completion/completions; do
    if [ -d "$dir" ]; then
        echo " - $dir (exists)"
    else
        echo " - $dir (does not exist)"
    fi
done

echo
echo "Installation commands to try:"
echo "1. mkdir -p ~/.local/share/bash-completion/completions"
echo "2. cp subcommands/git-sync/git-sync-completion.bash ~/.local/share/bash-completion/completions/git-sync"
echo "3. chmod +x ~/.local/share/bash-completion/completions/git-sync"
echo "4. source ~/.bashrc"
echo
echo "If bash-completion isn't installed, try:"
echo "sudo apt-get install bash-completion  # For Debian/Ubuntu"
echo "or"
echo "sudo dnf install bash-completion  # For Fedora/RHEL" 