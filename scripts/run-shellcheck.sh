#!/bin/sh
#
# run-shellcheck.sh - Run ShellCheck on *.sh files at error severity.
#
# Usage: run-shellcheck.sh [dir]
#
# With no arguments, checks tracked *.sh in this repository (git ls-files).
# With one directory argument, checks *.sh under that directory only.
# Does not scan *.bash. Dialect comes from each file's shebang.

set -eu

if ! command -v shellcheck >/dev/null 2>&1; then
	echo "error: shellcheck is required on PATH" >&2
	exit 1
fi

if [ "$#" -gt 1 ]; then
	echo "usage: ${0} [dir]" >&2
	exit 1
fi

rsc_repo=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

if [ "$#" -eq 1 ]; then
	rsc_list=$(find "$1" -name '*.sh' -type f)
else
	rsc_list=$(CDPATH= cd "${rsc_repo}" && git ls-files '*.sh')
fi

if [ -z "${rsc_list}" ]; then
	exit 0
fi

rsc_old_ifs=${IFS}
IFS='
'
# shellcheck disable=SC2086
set -- ${rsc_list}
IFS=${rsc_old_ifs}

if [ "$#" -eq 0 ]; then
	exit 0
fi

shellcheck --severity=error "$@"
