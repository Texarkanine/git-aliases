#!/usr/bin/env bash
#
# git-sync - Git addon to synchronize your current branch with another branch
# 
# Allows rebasing or merging to keep your branch up to date with the main branch

# Default values
SOURCE_BRANCH="main"
MERGE_MODE=false
HELP=false

# Display usage information
function show_usage() {
    cat <<EOF
Usage: git sync [options] [source-branch]

Options:
  -m, --merge           Use merge instead of rebase
  -h                    Show this help message

Arguments:
  source-branch         Specify source branch to sync with (default: main)
EOF
}

# Verify we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    	-m|--merge)
    		MERGE_MODE=true
    		shift
    		;;
    	-h)
    		HELP=true
    		shift
    		;;
    	--help)
    		# Pass --help along to git's help system
    		exit 1
    		;;
    	--*)
    		echo "Unknown option: $1"
    		show_usage
    		exit 1
    		;;
    	*)
    		# First non-option argument is the source branch
    		SOURCE_BRANCH="$1"
    		shift
    		;;
    esac
done

# Show help and exit if requested
if [[ "$HELP" = true ]]; then
    show_usage
    exit 0
fi

# Get current branch
CURRENT_BRANCH=$(git --no-pager branch --show-current)

if [[ -z "$CURRENT_BRANCH" ]]; then
    echo "Error: Not currently on a branch"
    exit 1
fi

# Check if current branch is the source branch
if [[ "$CURRENT_BRANCH" == "$SOURCE_BRANCH" ]]; then
    echo "You are currently on the source branch '$SOURCE_BRANCH'."
    echo "Nothing to synchronize. Exiting."
    exit 0
fi

# Check if there's a remote
HAS_REMOTE=$(git --no-pager remote)
if [[ -z "$HAS_REMOTE" ]]; then
    echo "Warning: No remote repository configured. Will sync with local branches only."
fi

# Check for uncommitted changes
UNCOMMITTED_CHANGES=$(git --no-pager status --porcelain)
NEED_STASH=false

if [[ -n "$UNCOMMITTED_CHANGES" ]]; then
    NEED_STASH=true
fi

# Confirm action with user
if [[ "$MERGE_MODE" = true ]]; then
    read -p "Merge updated $SOURCE_BRANCH into current branch ($CURRENT_BRANCH)? [yN] " CONFIRM
else
    read -p "Rebase current branch ($CURRENT_BRANCH) onto updated $SOURCE_BRANCH? [yN] " CONFIRM
fi

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Stash uncommitted changes if necessary
if [[ "$NEED_STASH" = true ]]; then
    echo "Stashing uncommitted changes..."
    git stash push -m "git-sync: auto-stash before sync"
    if [[ $? -ne 0 ]]; then
    	echo "Error: Failed to stash changes. Aborting."
    	exit 1
    fi
fi

# Switch to source branch and update
echo "Switching to $SOURCE_BRANCH..."
git checkout "$SOURCE_BRANCH"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to switch to $SOURCE_BRANCH. Aborting."
    if [[ "$NEED_STASH" = true ]]; then
    	echo "Restoring stashed changes..."
    	git stash pop
    fi
    exit 1
fi

# Pull latest changes if there's a remote
if [[ -n "$HAS_REMOTE" ]]; then
    echo "Pulling latest changes for $SOURCE_BRANCH..."
    git pull
    if [[ $? -ne 0 ]]; then
    	echo "Error: Failed to pull latest changes. Aborting."
    	git checkout "$CURRENT_BRANCH"
    	if [[ "$NEED_STASH" = true ]]; then
    		echo "Restoring stashed changes..."
    		git stash pop
    	fi
    	exit 1
    fi
fi

# Switch back to the original branch
echo "Switching back to $CURRENT_BRANCH..."
git checkout "$CURRENT_BRANCH"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to switch back to $CURRENT_BRANCH."
    echo "You are currently on $SOURCE_BRANCH."
    if [[ "$NEED_STASH" = true ]]; then
    	echo "Warning: Your stashed changes have not been restored."
    	echo "You can restore them with 'git stash pop'."
    fi
    exit 1
fi

# Perform the requested sync operation
if [[ "$MERGE_MODE" = true ]]; then
    echo "Merging $SOURCE_BRANCH into $CURRENT_BRANCH..."
    git merge "$SOURCE_BRANCH"
    SYNC_STATUS=$?
else
    echo "Rebasing $CURRENT_BRANCH onto $SOURCE_BRANCH..."
    git rebase "$SOURCE_BRANCH"
    SYNC_STATUS=$?
fi

# Check if sync operation was successful
if [[ $SYNC_STATUS -ne 0 ]]; then
    echo "Warning: Sync operation completed with issues."
    if [[ "$MERGE_MODE" = true ]]; then
    	echo "You may need to resolve merge conflicts."
    else
    	echo "You may need to resolve rebase conflicts."
    	echo "After resolving conflicts, run 'git rebase --continue'"
    	echo "Or to abort, run 'git rebase --abort'"
    fi
    
    # Don't restore stash if we have conflicts
    echo "Stashed changes were not restored due to conflicts."
    echo "You can restore them later with 'git stash pop' after resolving conflicts."
    exit 1
fi

# Pop the stash if we stashed changes
if [[ "$NEED_STASH" = true ]]; then
    echo "Restoring stashed changes..."
    git stash pop
    if [[ $? -ne 0 ]]; then
    	echo "Warning: There were conflicts when restoring your stashed changes."
    	echo "Please resolve these conflicts manually."
    	exit 1
    fi
fi

echo "Sync complete! Your $CURRENT_BRANCH branch is now up to date with $SOURCE_BRANCH." 