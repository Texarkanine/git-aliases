#!/bin/bash
#
# Bash completion for git-sync
# This script provides tab completion for git-sync command with branch names

# Define completion function using Git's own naming convention
_git_sync() {
    local cur prev words cword
    _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null || return

    # If _get_comp_words_by_ref failed, try manual approach
    if [ -z "$cur" ]; then
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    fi

    # Get a clean list of local branches
    local branches=$(git --no-pager for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)
    
    # Options
    local opts="-m --merge -h --help"

    # Handle different completion contexts
    case "$prev" in
        git-sync|sync)
            # Complete only with branches for better UX
            if [[ "$cur" == -* ]]; then
                # Only suggest options if user started typing a dash
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            else
                # Otherwise suggest branches
                COMPREPLY=($(compgen -W "$branches" -- "$cur"))
            fi
            return 0
            ;;
        -m|--merge)
            # After -m or --merge, complete with branches
            COMPREPLY=($(compgen -W "$branches" -- "$cur"))
            return 0
            ;;
        -h|--help)
            # No completions after help flag
            return 0
            ;;
    esac

    # Default to branches
    if [[ "$cur" == -* ]]; then
        # Only suggest options if user started typing a dash
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    else
        # Otherwise suggest branches
        COMPREPLY=($(compgen -W "$branches" -- "$cur"))
    fi
    return 0
}

# For standalone command git-sync
complete -F _git_sync git-sync

# For git's built-in completion system
if declare -F __git_complete >/dev/null; then
    # This allows git sync to use our custom completion
    # The _git_ prefix is important for Git's completion system
    __git_complete sync _git_sync
fi 