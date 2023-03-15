#!/bin/bash

function file_line_cnt()
{
	if [ -z "${1+x}" ]; then
		echo "[func file_line_cnt] usage: <func> file"
		return 1
	fi

	local file="${1}"

	if [ ! -f "${file}" ]; then
		echo "0"
	else
		cat "${file}" | wc -l | awk '{print $1}'
	fi
}
export -f file_line_cnt

function wait_for_log()
{
	local file="${1}"
	local from_line="${2}"
	local from_line_tail="$((1 + ${2}))"
	local str="${3}"
	local timeout="${4}"

	for ((i=0; i<${timeout}; i++)); do
		if [ ! -f "${file}" ]; then
			sleep 1
			continue
		fi
		local found=`tail -n +${from_line_tail} "${file}" | { grep -n "${str}" || test $? = 1; } | head -n 1`
		if [ -z "${found}" ]; then
			sleep 1
			continue
		else
			echo "$from_line => ${found}"
			return 0
		fi
	done

	echo "[func wait_for_log] timeout: waiting for \"${str}\" in ${file}" >&2
	return 1
}
export -f wait_for_log
