#!/bin/bash

function print_procs()
{
	if [ -z "${1+x}" ]; then
		echo "[func print_procs] usage: <func> str_for_finding_the_procs [str2]" >&2
		return 1
	fi

	local find_str="${1}"
	local str2=''
	if [ ! -z "${2+x}" ]; then
		local str2="${2}"
	fi

	if [ `uname` == "Darwin" ]; then
		local pids=`pgrep -f "${find_str}"`
		if [ ! -z "${pids}" ]; then
			echo "${pids}" | while read pid; do
				ps -fp "${pid}" | { grep "${pid}" || test $? = 1; } | { grep "${str2}" || test $? = 1; } | { grep -v '^UID' || test $? = 1; }
			done
		fi
	else
		ps -ef | { grep "${find_str}" || test $? = 1; } | { grep "${str2}" || test $? = 1; } | { grep -v 'grep' || test $? = 1; }
	fi
}
export -f print_procs

function print_pids()
{
	if [ -z "${1+x}" ]; then
		echo "[func print_pids] usage: <func> str_for_finding_the_procs [str2]" >&2
		return 1
	fi

	local find_str="${1}"
	local str2=''
	if [ ! -z "${2+x}" ]; then
		local str2="${2}"
	fi

	print_procs "${find_str}" "${str2}" | awk '{print $2}'
}
export -f print_pids

function ps_ppid()
{
	if [ -z "${1+x}" ]; then
		echo "[func ps_ppid] usage: <func> ppid" >&2
		return 1
	fi

	local ppid="${1}"
	if [ `uname` == "Darwin" ]; then
		ps -ef | awk '{if ($3 == '${ppid}') print $0}' | grep -v 'ps_ppid'
	else
		ps -f --ppid "${ppid}" | { grep "${ppid}" || test $? = 1; }
	fi
}
export -f ps_ppid
