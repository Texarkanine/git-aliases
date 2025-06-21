#!/bin/bash
#
# Script to test git-identity bash completion

# Create a test directory for identities
mkdir -p ~/.git-identities
touch ~/.git-identities/test-identity1
touch ~/.git-identities/test-identity2
echo "Created test identities in ~/.git-identities/"

# Source the completion script directly
echo "Loading completion script..."
source "$(pwd)/subcommands/git-identity/git-identity-completion.bash"
echo "Completion script loaded. Try typing 'git-identity ' and press Tab, or 'git identity ' and press Tab"

# Debug information
echo
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
echo "2. cp subcommands/git-identity/git-identity-completion.bash ~/.local/share/bash-completion/completions/git-identity"
echo "3. chmod +x ~/.local/share/bash-completion/completions/git-identity"
echo "4. source ~/.bashrc"
echo
echo "If bash-completion isn't installed, try:"
echo "sudo apt-get install bash-completion  # For Debian/Ubuntu"
echo "or"
echo "sudo dnf install bash-completion  # For Fedora/RHEL" 