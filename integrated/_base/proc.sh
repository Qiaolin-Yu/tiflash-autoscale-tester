#!/bin/bash

function kill_pid()
{
	if [ -z "${1+x}" ]; then
		echo "[func kill_pid] usage: <func> pid [force=false]" >&2
		return 1
	fi

	local pid="${1}"
	local force='false'
	if [ ! -z "${2+x}" ]; then
		local force="${2}"
	fi

	local error_handle="$-"
	set +e
	if [ "${force}" == 'true' ]; then
		kill -9 "${pid}" 2>/dev/null
	else
		kill "${pid}" 2>/dev/null
	fi
	restore_error_handle_flags "${error_handle}"
}
export -f kill_pid

function pid_exists()
{
	if [ -z "${1+x}" ]; then
		echo "[func pid_exists] usage: <func> pid" >&2
		return 1
	fi

	local pid="${1}"
	local exists=`ps -fp "${pid}" | { grep "${pid}" || test $? = 1; } | awk '{print $2}'`
	if [ -z "${exists}" ]; then
		echo 'false'
	else
		echo 'true'
	fi
}
export -f pid_exists

function print_root_pids()
{
	if [ -z "${1+x}" ]; then
		echo "[func print_root_pids] usage: <func> str_for_finding_the_procs [str2] [dump_if_not_uniq]" >&2
		return 1
	fi

	local find_str="${1}"
	local str2=""
	if [ ! -z "${2+x}" ]; then
		local str2="${2}"
	fi
	local dump='true'
	if [ ! -z "${3+x}" ]; then
		local dump="${3}"
	fi

	local procs=`print_procs "${find_str}" "${str2}"`
	local here="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`"
	local result=`echo "${procs}" | awk '{print $2, $3}' | python "${here}/print_root_pid.py"`
	if [ "${dump}" == 'true' ] && [ ! -z "${result}" ]; then
		local cnt=`echo "${result}" | wc -l | awk '{print $1}'`
		if [ "${cnt}" != '1' ]; then
			echo "DUMP START --(${find_str}, ${str2})" >&2
			echo "${procs}" >&2
			echo "DUMP END   --(${find_str}, ${str2})" >&2
		fi
	fi

	if [ ! -z "${result}" ]; then
		echo "${result}"
	fi
}
export -f print_root_pids

function print_pids_by_ppid()
{
	if [ -z "${1+x}" ]; then
		echo "[func print_pids_by_ppid] usage: <func> ppid" >&2
		return 1
	fi

	local ppid="${1}"
	local pids=`ps_ppid "${ppid}" | awk '{print $2}'`
	echo "${pids}" | while read pid; do
		if [ -z "${pid}" ]; then
			continue
		fi
		echo "${pid}"
		print_pids_by_ppid "${pid}"
	done
}
export -f print_pids_by_ppid

function _print_sub_pids()
{
	local pids="${1}"
	echo "${pids}" | while read pid; do
		if [ ! -z "${pid}" ]; then
			print_pids_by_ppid "${pid}"
		fi
	done
}
export -f _print_sub_pids

function print_tree_pids
{
	if [ -z "${1+x}" ]; then
		echo "[func print_root_pids] usage: <func> str_for_finding_the_procs [str2]" >&2
		return 1
	fi

	local find_str="${1}"
	local str2=""
	if [ ! -z "${2+x}" ]; then
		local str2="${2}"
	fi

	local pids=`print_pids "${find_str}" "${str2}"`
	local sub_pids=`_print_sub_pids "${pids}"`

	echo "${pids}" | while read pid; do
		if [ -z "${pid}" ]; then
			continue
		fi
		local is_in_sub=`echo "${sub_pids}" | { grep "^${pid}$" || test $? = 1; }`
		if [ -z "${is_in_sub}" ]; then
			echo "${pid}"
		fi
	done

	if [ ! -z "${sub_pids}" ]; then
		echo "${sub_pids}"
	fi
}
export -f print_tree_pids

function print_proc_cnt()
{
	if [ -z "${1+x}" ]; then
		echo "[func print_proc_cnt] usage: <func> str_for_finding_the_procs [str2]" >&2
		return 1
	fi

	local find_str="${1}"
	local str2=""
	if [ ! -z "${2+x}" ]; then
		local str2="${2}"
	fi

	local procs=`print_procs "${find_str}" "${str2}"`
	if [ -z "${procs}" ]; then
		echo "0"
	else
		echo "${procs}" | wc -l | awk '{print $1}'
	fi
}
export -f print_proc_cnt

function must_print_pid()
{
	if [ -z "${1+x}" ]; then
		echo "[func print_pid] usage: <func> str_for_finding_the_process [str2]" >&2
		return 1
	fi

	local find_str="${1}"
	local str2=""
	if [ ! -z "${2+x}" ]; then
		local str2="${2}"
	fi

	local pids=`print_pids "${find_str}" "${str2}"`
	if [ -z "${pids}" ]; then
		echo "[func must_print_pid] '${find_str}' process not exists " >&2
		return 1
	fi
	local pid_count=`echo "${pids}" | wc -l | awk '{print $1}'`
	if [ "${pid_count}" != "1" ]; then
		echo "[func must_print_pid] '${find_str}' pid count: ${pid_count} != 1" >&2
		return 1
	fi
	echo "${pids}"
}
export -f must_print_pid

function stop_pid()
{
	if [ -z "${1+x}" ]; then
		echo "[func stop_pid] usage: <func> pid [fast_mode=false] [timeout=60]" >&2
		return 1
	fi

	local pid="${1}"

	if [ -z "${2+x}" ]; then
		local fast=''
	else
		local fast="${2}"
	fi

	if [ -z "${3+x}" ]; then
		local timeout='60'
	else
		local timeout="${3}"
	fi

	local pid_exists=`pid_exists "${pid}"`
	if [ "${pid_exists}" == "false" ]; then
		return
	fi

	local fail_timeout=$((timeout * 2))

	local heavy_kill="false"
	local heaviest_kill="false"

	if [ "${fast}" == "true" ]; then
		local heaviest_kill="true"
	fi

	for ((i = 0; i < 9999; i++)); do
		if [ "${heaviest_kill}" == 'true' ]; then
			echo "${pid} closing, using 'kill -9'..."
			kill_pid "${pid}" 'true'
		else
			if [ "${heavy_kill}" == 'true' ]; then
				if [ "$((${i} % 3))" == '0' ] && [ "${i}" -ge '10' ]; then
					echo "${pid} closing..."
				fi
			else
				if [ "$((${i} % 10))" == '0' ] && [ "${i}" -ge '10' ]; then
					echo "${pid} closing..."
				fi
			fi
			kill_pid "${pid}"
		fi

		if [ "${heaviest_kill}" != "true" ]; then
			sleep 0.05
		fi

		local pid_exists=`pid_exists "${pid}"`
		if [ "${pid_exists}" == "false" ]; then
			echo "${pid} closed"
			break
		fi

		sleep 0.5

		if [ "${i}" -ge '21' ]; then
			local heavy_kill="true"
		fi
		if [ "${i}" -ge "${timeout}" ]; then
			local heaviest_kill="true"
		fi

		if [ "${i}" -ge "${fail_timeout}" ]; then
			echo "${pid} close failed" >&2
			return 1
		fi
	done
}
export -f stop_pid

function stop_pids()
{
	if [ -z "${1+x}" ]; then
		echo "[func stop_pids] usage: <func> pids [fast_mode=false] [timeout=60]" >&2
		return 1
	fi

	local pids="${1}"

	if [ -z "${2+x}" ]; then
		local fast=''
	else
		local fast="${2}"
	fi

	if [ -z "${3+x}" ]; then
		local timeout='60'
	else
		local timeout="${3}"
	fi

	echo "${pids}" | while read pid; do
		if [ ! -z "${pid}" ]; then
			stop_pid "${pid}" "${fast}" "${timeout}"
		fi
	done
}
export -f stop_pids

function stop_procs()
{
	if [ -z "${1+x}" ]; then
		echo "[func stop_procs] usage: <func> str_for_finding_the_procs [str2] [fast_mode=false] [timeout=60]" >&2
		return 1
	fi

	local find_str="${1}"
	local str2=''
	if [ ! -z "${2+x}" ]; then
		local str2="${2}"
	fi

	if [ -z "${3+x}" ]; then
		local fast=''
	else
		local fast="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local timeout='60'
	else
		local timeout="${4}"
	fi

	local pids=`print_tree_pids "${find_str}" "${str2}"`
	if [ -z "${pids}" ]; then
		return
	fi
	stop_pids "${pids}" "${fast}" "${timeout}"

	local new_sub_pids=`_print_sub_pids "${pids}"`
	if [ ! -z "${new_sub_pids}" ]; then
		stop_pids "${new_sub_pids}" "${fast}" "${timeout}"
	fi
}
export -f stop_procs

function stop_pids_tree()
{
	if [ -z "${1+x}" ]; then
		echo "[func stop_procs] usage: <func> pid_or_pids [fast=false] [timeout=60]" >&2
		return 1
	fi

	local pids="${1}"

	if [ -z "${2+x}" ]; then
		local fast=''
	else
		local fast="${2}"
	fi

	if [ -z "${3+x}" ]; then
		local timeout='60'
	else
		local timeout="${3}"
	fi

	local sub_pids=`_print_sub_pids "${pids}"`

	stop_pids "${pids}" "${fast}" "${timeout}"
	stop_pids "${sub_pids}" "${fast}" "${timeout}"
}
export -f stop_pids_tree
