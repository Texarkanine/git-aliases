#!/bin/bash
#
# Bash completion for git-identity
# This script provides tab completion for git-identity commands and identity names

_git_identity_complete() {
    local cur prev words cword
    _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null || return

    # If _get_comp_words_by_ref failed, try manual approach
    if [ -z "$cur" ]; then
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    fi

    # Main git-identity commands
    local commands="list use current create"
    
    # Handle different completion contexts
    case "$prev" in
        git-identity|identity)
            # Complete with available commands
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            return 0
            ;;
        use)
            # Complete with available identities for the use command
            local identities_dir="${HOME}/.git-identities"
            if [[ -d "${identities_dir}" ]]; then
                local identities=$(find "${identities_dir}" -type f -not -name ".current" -exec basename {} \; 2>/dev/null)
                COMPREPLY=($(compgen -W "$identities" -- "$cur"))
            fi
            return 0
            ;;
        create|list|current)
            # For these commands, we don't suggest anything specific
            return 0
            ;;
    esac

    # Check if this is a git subcommand invocation
    if [[ ${COMP_CWORD} -ge 2 && "${COMP_WORDS[COMP_CWORD-2]}" == "git" && "${COMP_WORDS[COMP_CWORD-1]}" == "identity" ]]; then
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return 0
    fi

    # Default to command names if no context is recognized
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    return 0
}

# Register the completion function for both standalone and git subcommand usage
complete -F _git_identity_complete git-identity

# For when used as a git subcommand
if declare -F __git_complete >/dev/null; then
    __git_complete git-identity _git_identity_complete
else
    complete -o default -F _git_identity_complete git
fi
