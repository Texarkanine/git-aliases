#!/bin/sh
#
# trim.sh - POSIX whitespace trim utility
#
# Shared by install scripts and tests.

# Trims leading and trailing whitespace from the given string.
#
# Globals:
#   None
# Arguments:
#   $1 - String to trim (required)
# Outputs:
#   Trimmed string to STDOUT
# Returns:
#   Always 0
trim_whitespace() {
	tw_input="${1}"
	printf '%s\n' "${tw_input}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
