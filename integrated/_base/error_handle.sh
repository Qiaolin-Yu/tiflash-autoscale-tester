#!/bin/bash

function auto_error_handle()
{
	set -ueo pipefail
}
export -f auto_error_handle

# Example:
#   error_handle="$-"
#   set +e
#   do something
#   restore_error_handle_flags "${error_handle}"
function restore_error_handle_flags()
{
	local flags="$1"
	if [ ! -z "`echo ${flags} | { grep 'e' || test $? = 1; }`" ]; then
		set -e
	else
		set +e
	fi
	if [ ! -z "`echo ${flags} | { grep 'u' || test $? = 1; }`" ]; then
		set -u
	else
		set +u
	fi
}
export -f restore_error_handle_flags

function assert_eq()
{
	if [ -z "${2+x}" ]; then
		echo "[func assert_eq] usage: <func> v1 v2"
		return 1
	fi

	local v1="${1}"
	local v2="${2}"
	if [ "${v1}" != "${v2}" ]; then
		echo "[func assert_eq] ${v1} != ${v2}"
		return 1
	fi
}
export -f assert_eq
