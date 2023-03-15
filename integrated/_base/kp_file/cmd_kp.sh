#!/bin/bash

function kp_file_watch
{
	if [ -z "${1+x}" ] || [ -z "${1}" ]; then
		echo "[func kp_file_watch] usage: <func> kp_file [watch_interval=5] [display_width=80]" >&2
		exit 1
	fi

	local file="${1}"
	if [ -z "${2+x}" ]; then
		local interval='5'
	else
		local interval="${2}"
	fi
	if [ ! -z "${3+x}" ]; then
		local width="${3}"
	else
		local width=`terminal_width 2>/dev/null`
	fi
	if [ -z "${width}" ]; then
		local width='80'
	else
		local width=$((width - 6))
	fi

	watch -c -n "${interval}" -t "COLUMNS= ${integrated}/ops/kp.sh \"${file}\" status \"${width}\""
}

function kp_mon_report
{
	if [ -z "${2+x}" ]; then
		echo "[func kp_mon_report] usage: <func> kp_file width" >&2
		return 1
	fi

	local file="${1}"
	local log="${file}.log"
	if [ ! -f "${file}" ] || [ ! -f "${log}" ]; then
		return
	fi

	local width="${2}"

	local logs=`tail -n 9999 "${log}" | { grep -v 'RUNNING' || test $? = 1; }`

	kp_file_iter "${file}" | while read line; do
		local last_msg=`echo "${logs}" | { grep "${line}" || test $? = 1; } | tail -n 1 | { grep 'ERROR' || test $? = 1; }`
		if [ ! -z "${last_msg}" ]; then
			echo "${last_msg}"
		fi
	done

	local random=`yes '-' | head -n 999`
	local lines=`cat "${log}" | { grep 'START\|RUNNING\|ERROR\|STOP\|WARNING' || test $? = 1; } | tail -n 999`
	echo -e "${random}\n${lines}" | \
		awk '{if ($3 == "START") print "\033[32m+\033[0m"; else if ($3 == "WARNING") print "\033[33m~\033[0m"; else if ($3 == "RUNNING") print "\033[32m-\033[0m"; else if ($3 == "ERROR") print "\033[31mE\033[0m"; else if ($3 == "STOP") print "\033[35m!\033[0m"; else print "-"}' | tail -n "${width}" | \
		tr "\n" ' ' | sed 's/ //g' | awk '{print "\033[32m<<\033[0m"$0}'
}
export -f kp_mon_report

function cmd_kp()
{
	local file="${1}"
	local cmd="${2}"

	auto_error_handle

	local help_str="[func cmd_kp] usage: <func> kp_file [cmd=run|stop|status|list|clean|watch] [width=80]"

	if [ -z "${file}" ]; then
		echo "${help_str}" >&2
		return 1
	fi

	if [ -z "${2+x}" ]; then
		shift 1
	else
		shift 2
	fi

	if [ -z "${cmd}" ]; then
		local cmd='status'
	fi
	if [ "${cmd}" == 'up' ]; then
		local cmd='run'
	fi
	if [ "${cmd}" == 'down' ]; then
		local cmd='stop'
	fi
	if [ "${cmd}" == 'ls' ]; then
		local cmd='list'
	fi

	local file_abs=`abs_path "${file}"`

	local mon_pids=`_kp_file_pid "${file_abs}.mon"`
	# TODO: this is for zsh debug, remove it later
	local is_running=`_kp_file_proc_exists "${file_abs}.mon"`
	if [ "${is_running}" == 'true' ] && [ -z "${mon_pids}" ]; then
		echo "[func cmd_kp] error: pid detecting failed: '${file_abs}.mon'"
		return 1
	fi

	if [ "${cmd}" == 'run' ]; then
		if [ -z "${1+x}" ]; then
			echo "[func cmd_kp] usage: <func> kp_file run continue_on_error(true|false)"
			return 1
		fi
		local continue_on_err="${1}"
		if [ ! -z "${mon_pids}" ]; then
			echo "=> [^__^] ${file_abs}"
			echo '   running, skipped'
		else
			echo "# This file is generated" >"${file_abs}.mon"
			echo "source \"${integrated}/_env.sh\"" >>"${file_abs}.mon"
			echo 'auto_error_handle' >>"${file_abs}.mon"
			echo "kp_file_run \"${file_abs}\" \"${continue_on_err}\"" >>"${file_abs}.mon"
			chmod +x "${file_abs}.mon"
			nohup bash "${integrated}"/_base/call_func.sh \
				keep_script_running "${file_abs}.mon" 'false' '' 'true' 10 10 >/dev/null 2>&1 &
			echo "=> [^__^] ${file_abs}"
			echo '   starting'
		fi
		echo "=> [task] (s)"
		kp_file_iter "${file}" | awk '{print "   "$0}'
	elif [ "${cmd}" == 'stop' ]; then
		echo "=> [^__^] ${file_abs}"
		if [ ! -z "${mon_pids}" ]; then
			stop_pids "${mon_pids}" | awk '{print "   "$0}'
		else
			echo '   nor running, skipped'
		fi
		kp_file_stop "${file}" 'false'
	elif [ "${cmd}" == 'status' ]; then
		if [ ! -z "${1+x}" ] && [ ! -z "${1}" ]; then
			local width="${1}"
		else
			local width=`terminal_width 2>/dev/null`
			if [ -z "${width}" ]; then
				local width='80'
			else
				local width=$((width - 6))
			fi
		fi
		local atime=`_kp_sh_last_active "${file}"`
		if [ ! -z "${mon_pids}" ]; then
			local mon_proc_cnt=`echo "${mon_pids}" | wc -l | awk '{print $1}'`
			if [ "${mon_proc_cnt}" == '1' ]; then
				local run_status="\033[32m[+]\033[0m"
			else
				local run_status="\033[33m[?]\033[0m"
			fi
		else
			local run_status="\033[31m[!]\033[0m"
		fi
		echo -e "${run_status}\033[36m [^__^] ${file_abs}\033[0m \033[35m${atime}s\033[0m"
		kp_mon_report "${file}" "${width}" | awk '{print "    "$0}'
		kp_file_status "${file}" "${width}"
	elif [ "${cmd}" == 'list' ]; then
		kp_file_iter "${file}"
	elif [ "${cmd}" == 'watch' ]; then
		if [ -z "${1+x}" ]; then
			kp_file_watch "${file}"
		else
			kp_file_watch "${file}" "${@}"
		fi
	elif [ "${cmd}" == 'clean' ]; then
		echo "=> [^__^] ${file_abs}"
		if [ ! -z "${mon_pids}" ]; then
			stop_pids "${mon_pids}" | awk '{print "   "$0}'
		else
			echo '   nor running, skipped'
		fi
		kp_file_stop "${file}" 'true'
		rm -f "${file}.mon"
		rm -f "${file}.log"
		kp_file_iter "${file}" | while read line; do
			rm -rf "${line}.data"
		done
	else
		echo "${cmd}: unknow command" >&2
		echo "${help_str}" >&2
		return 1
	fi
}
export -f cmd_kp
