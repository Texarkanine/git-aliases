#!/usr/bin/env bash
#
# git-identity - Git addon to manage multiple identities
# 
# This script allows switching between multiple Git identities
# with different configuration settings.

# Directory to store identity configurations
readonly IDENTITIES_DIR="${HOME}/.git-identities"

# Display usage information
function show_usage() {
    cat <<EOF
Usage: git identity <command> [<args>]

Commands:
  list                 List available identities
  use <identity>       Switch to specified identity
  create <identity>    Create a new identity
  -h                   Show this help message
EOF
}

# List available identities
function list_identities() {
    echo "Available identities:"
    
    if [[ ! -d "${IDENTITIES_DIR}" || -z "$(ls -A "${IDENTITIES_DIR}")" ]]; then
        echo "  No identities found"
        return
    fi
    
    for file in "${IDENTITIES_DIR}"/*; do
        if [[ -f "${file}" ]]; then
            echo "  $(basename "${file}")"
        fi
    done
}

# Process special directives (lines starting with @)
function process_directive() {
    local directive="$1"
    local value="$2"
    
    case "${directive}" in
        hostname)
            # Get current remote URLs
            git --no-pager remote -v | grep "(push)" | while read -r remote_line; do
                if [[ "${remote_line}" =~ ^([^[:space:]]+)[[:space:]]+(.+)[[:space:]]\(push\)$ ]]; then
                    local remote_name="${BASH_REMATCH[1]}"
                    local remote_url="${BASH_REMATCH[2]}"
                    
                    # Extract current hostname for SSH URLs
                    if [[ "${remote_url}" =~ ^git@([^:]+): ]]; then
                        local current_hostname="${BASH_REMATCH[1]}"
                        # Reconstruct the URL with the new hostname
                        local new_url="git@${value}:${remote_url#git@${current_hostname}:}"
                        git remote set-url "${remote_name}" "${new_url}"
                        echo "Updated remote '${remote_name}' to use ${value}"
                    # Extract current hostname for HTTPS URLs
                    elif [[ "${remote_url}" =~ ^(https?://)([^/]+)(/.*)$ ]]; then
                        local protocol="${BASH_REMATCH[1]}"
                        local current_hostname="${BASH_REMATCH[2]}"
                        local path="${BASH_REMATCH[3]}"
                        # Reconstruct the URL with the new hostname
                        local new_url="${protocol}${value}${path}"
                        git remote set-url "${remote_name}" "${new_url}"
                        echo "Updated remote '${remote_name}' to use ${value}"
                    fi
                fi
            done
            ;;
        # Add more special directives here as needed
        *)
            echo "Warning: Unknown directive '@${directive}'"
            ;;
    esac
}

# Switch to the specified identity
function use_identity() {
    local identity="$1"
    local identity_file="${IDENTITIES_DIR}/${identity}"

    if [[ ! -f "${identity_file}" ]]; then
        echo "Error: Identity '${identity}' not found"
        exit 1
    fi

    echo "Switching to identity: ${identity}"

    # Process the identity file
    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip comments and empty lines
        if [[ "${line}" =~ ^[[:space:]]*# || -z "${line// }" ]]; then
            continue
        fi
        
        # Handle special directives (lines starting with @)
        if [[ "${line}" =~ ^@([^ ]+)[[:space:]]+(.+)$ ]]; then
            local directive="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            # Remove quotes if present
            value="${value#\"}"
            value="${value%\"}"
            
            process_directive "${directive}" "${value}"
        else
            # Regular git config line - run it as-is
            eval "git config --replace-all ${line}"
            echo "Set ${line}"
        fi
    done < "${identity_file}"

    echo "Successfully switched to identity: ${identity}"
}

# Create a new identity
function create_identity() {
    local identity="$1"
    local identity_file="${IDENTITIES_DIR}/${identity}"

    if [[ -f "${identity_file}" ]]; then
        echo "Error: Identity '${identity}' already exists"
        exit 1
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "${IDENTITIES_DIR}"
    
    # Create template identity file
    cat > "${identity_file}" << EOF
# Git Identity Configuration for ${identity}
# Standard git config settings
user.name "Your Name"
user.email "your.email@example.com"
# user.signingkey "YOUR_GPG_KEY_ID"
commit.gpgsign false

# Special directives (prefixed with @)
# @hostname github-${identity}.com
EOF

    echo "Created new identity: ${identity}"
    echo "Edit ${identity_file} to configure your identity"
}

# Ensure arguments are provided
if [[ $# -eq 0 ]]; then
    show_usage
    exit 0
fi

# Check for help option
if [[ "$1" == "-h" ]]; then
    show_usage
    exit 0
fi

# Handle --help (exit with error code to let git's help system take over)
if [[ "$1" == "--help" ]]; then
    exit 1
fi

# Verify we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 1
fi

# Main command dispatcher
command="$1"
shift

case "${command}" in
    list)
        list_identities
        ;;
    use)
        if [[ $# -eq 0 ]]; then
            echo "Error: Missing identity name"
            exit 1
        fi
        use_identity "$1"
        ;;
    create)
        if [[ $# -eq 0 ]]; then
            echo "Error: Missing identity name"
            exit 1
        fi
        create_identity "$1"
        ;;
    *)
        echo "Error: Unknown command '${command}'"
        show_usage
        exit 1
        ;;
esac
