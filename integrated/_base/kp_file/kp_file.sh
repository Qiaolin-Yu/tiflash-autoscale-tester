#!/bin/bash

function _kp_file_proc_exists()
{
	if [ -z "${1+x}" ]; then
		echo "[func _kp_file_proc_exists] usage: <func> kp_file" >&2
		return 1
	fi

	local file="${1}"
	local find_str="keep_script_running ${file}"
	local procs=`print_procs "${find_str}"`
	if [ -z "${procs}" ]; then
		echo 'false'
	else
		echo 'true'
	fi
}
export -f _kp_file_proc_exists

function _kp_file_pid()
{
	if [ -z "${1+x}" ]; then
		echo "[func _kp_file_pid] usage: <func> kp_file" >&2
		return 1
	fi

	local file="${1}"
	print_root_pids "keep_script_running ${file}"
}
export -f _kp_file_pid

function keep_script_running()
{
	if [ -z "${6+x}" ]; then
		echo "[func keep_script_running] usage: <func> script write_log args_string continue_on_err check_interval backoffs" >&2
		return 1
	fi

	local script="${1}"
	local write_log="${2}"
	local args="${3}"
	local continue_on_err="${4}"
	local interval="${5}"
	shift 5

	if [ "${write_log}" == 'true' ]; then
		mkdir -p "${script}.data"
		local log="${script}.data/stdout.log"
		local err_log="${script}.data/stderr.log"
	else
		local log="/dev/null"
		local err_log="/dev/null"
	fi

	local backoffs=("${@}")
	local backoff_i=0

	if [ -z "${args}" ]; then
		local args_str=''
	else
		local args_str=" ${args}"
	fi

	while true; do
		local pid=`print_root_pids "bash ${script}" "${args}" 'true'`
		if [ -z "${pid}" ]; then
			local proc_cnt='0'
		else
			local proc_cnt=`echo "${pid}" | wc -l | awk '{print $1}'`
		fi

		if [ "${proc_cnt}" == '1' ]; then
			# echo "[`date +'%D %T'`] RUNNING ${script}${args_str}"
			local backoff_i=0
			sleep "${interval}"
			continue
		fi

		if [ "${proc_cnt}" != '0' ]; then
			echo "[`date +'%D %T'`] ERROR ${script}${args_str}: more than 1 instance: ${proc_cnt}"
			local backoff_i=0
			sleep "${interval}"
			continue
		fi

		local backoff="${backoffs[${backoff_i}]}"
		local backoff_i=$((backoff_i + 1))
		if [ ${backoff_i} -ge ${#backoffs[@]} ]; then
			local backoff_i=$((${#backoffs[@]} - 1))
		fi

		local ts=`date +%s`
		local time=`date +'%D %T'`

		if [ "${continue_on_err}" != 'true' ] && [ -f "${log}" ]; then
			local grace_end=`tail -n 1 "${log}" | grep '!END\|!STOP'`
			if [ -z "${grace_end}" ]; then
				local sys_end=`tail -n 1 "${log}" | grep '^!'`
				if [ -z "${sys_end}" ]; then
					echo "!ERR ${ts} [${time}]" >> "${log}"
				fi
				sleep "${backoff}"
				continue
			fi
		fi

		echo "!RUN ${ts} [${time}]" >> "${log}"
		echo "!RUN ${ts} [${time}]" >> "${err_log}"

		local error_handle="$-"
		set +e
		if [ -f "${script}.stop" ]; then
			nohup bash "${script}.stop" 'false' >> "${log}" 2>> "${err_log}"
		fi
		nohup bash "${script}" ${args} >> "${log}" 2>> "${err_log}" && \
			echo "!END ${ts} [`date +'%D %T'`]" >> "${log}" &
		sleep 0.05
		restore_error_handle_flags "${error_handle}"

		local proc_cnt=`print_proc_cnt "bash ${script}"`
		if [ "${proc_cnt}" == '1' ]; then
			echo "[`date +'%D %T'`] START ${script}${args_str}"
			continue
		fi

		echo "[`date +'%D %T'`] WARNING ${script}${args_str}: exited too quick, retry in ${backoff} secs"
		sleep "${backoff}"
	done
}
export -f keep_script_running

function _kp_iter()
{
	if [ -z "${1+x}" ]; then
		echo "[func _kp_iter] usage: <func> path [ignored_file_list]" >&2
		return 1
	fi

	local path="${1}"
	if [ -z "${2+x}" ]; then
		local ignoreds=''
	else
		local ignoreds="${2}"
	fi

	if [ -f "${path}" ]; then
		local ext=`print_file_ext "${path}"`
		if [ "${ext}" != 'sh' ]; then
			return
		fi
		abs_path "${path}"
	elif [ -d "${path}" ]; then
		for file in "${path}"/*; do
			local ignored=`echo "${ignoreds}" | { grep "${file}" || test $? = 1; }`
			if [ ! -z "${ignored}" ] && [ "${ignored}" == "!${file}" ]; then
				continue
			fi
			_kp_iter "${file}" "${ignoreds}"
		done
	else
		echo "[func _kp_iter] ${path} is not file or dir" >&2
		return 1
	fi
}
export -f _kp_iter

function kp_file_iter()
{
	if [ -z "${1+x}" ]; then
		echo "[func _kp_file_iter] usage: <func> kp_file" >&2
		return 1
	fi

	local file="${1}"
	if [ ! -f "${file}" ]; then
		echo "[func kp_file_iter] ${file} is not file" >&2
		return 1
	fi
	local file_abs=`abs_path "${file}"`
	local file_dir=`dirname "${file_abs}"`

	local rendered="/tmp/kp_file_iter.rendered.`date +%s`.${RANDOM}"
	rm -f "${rendered}"

	local lines=`cat "${file_abs}" | { grep -v '^#' || test $? = 1; } | { grep -v '^$' || test $? = 1; }`
	if [ -z "${lines}" ]; then
		return
	fi
	local lines_cnt=`echo "${lines}" | wc -l | awk '{print $1}'`
	if [ "${lines_cnt}" == '0' ]; then
		return
	fi
	local uniq_lines=`echo "${lines}" | sort | uniq`
	local uniq_cnt=`echo "${uniq_lines}" | wc -l | awk '{print $1}'`
	if [ "${uniq_cnt}" != "${lines_cnt}" ]; then
		echo "[func kp_file_iter] ${file} has duplicated lines ${uniq_cnt} != ${lines_cnt}" >&2
		return 1
	fi

	echo "${lines}" | while read line; do
		if [ "${line:0:1}" == '!' ]; then
			local ignored='true'
			local line="${line:1}"
		else
			local ignored='false'
		fi
		if [ "${line:0:1}" != '/' ]; then
			local line="${file_dir}/${line}"
		fi
		if [ "${ignored}" == 'true' ]; then
			local line="!${line}"
		fi
		echo "${line}" >> "${rendered}"
	done

	local ignoreds=`cat "${rendered}" | { grep '^!' || test $? = 1; } | sort | uniq`
	cat "${rendered}" | { grep -v '^!' || test $? = 1; } | while read line; do
		_kp_iter "${line}" "${ignoreds}"
	done

	rm -f "${rendered}"
}
export -f kp_file_iter

function kp_file_run()
{
	if [ -z "${2+x}" ]; then
		echo "[func kp_file_run] usage: <func> kp_file continue_on_err" >&2
		return 1
	fi

	local file="${1}"
	local continue_on_err="${2}"

	local file_dir=$(dirname `abs_path "${file}"`)

	cat "${file}" | { grep '^!' || test $? = 1; } | sort | uniq | while read line; do
		if [ "${line:0:1}" != '/' ]; then
			local line="${file_dir}/${line:1}"
		else
			local line="${line:1}"
		fi
		local result=`kp_sh_stop "${line}" 'true'`
		local skipped=`echo "${result}" | { grep 'skipped' || test $? = 1; }`
		if [ -z "${skipped}" ]; then
			echo "[`date +'%D %T'`] STOP ${line}" >> "${file}.log"
		fi
	done

	kp_file_iter "${file}" | while read line; do
		if [ -z "${line}" ]; then
			continue
		fi
		local pid=`_kp_file_pid "${line}"`
		echo "=> [task] ${line}"
		if [ ! -z "${pid}" ]; then
			local pid_cnt=`echo "${pid}" | wc -l | awk '{print $1}'`
			if [ "${pid_cnt}" == '1' ]; then
				echo "   running, skipped"
			else
				echo "   error: multi instance"
			fi
		else
			local is_running=`_kp_file_proc_exists "${line}"`
			if [ "${is_running}" == 'false' ]; then
				nohup bash "${integrated}"/_base/call_func.sh \
					keep_script_running "${line}" 'true' '' "${continue_on_err}" 9 1 2 3 4 8 16 32 >> "${file}.log" 2>&1 &
				echo "   starting"
			else
				echo "   error: pid detecting failed: '${line}'"
			fi
		fi
	done
}
export -f kp_file_run

function kp_sh_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func kp_sh_stop] usage: <func> sh_file [clean] [quiet]" >&2
		return 1
	fi

	local file="${1}"
	if [ -z "${2+x}" ]; then
		local clean='false'
	else
		local clean="${2}"
	fi
	if [ -z "${3+x}" ]; then
		local quiet='false'
	else
		local quiet="${3}"
	fi

	local pids=`print_tree_pids "keep_script_running ${file}"`
	if [ -z "${pids}" ]; then
		if [ "${quiet}" != 'true' ]; then
			echo "=> [task] ${file}"
			echo "   not running, skipped"
		fi
		return
	fi

	if [ "${quiet}" != 'true' ]; then
		echo "=> [task] ${file}"
		stop_pids "${pids}" | awk '{print "   "$0}'
	else
		stop_pids "${pids}" >/dev/null 2>&1
	fi

	local pids=`print_tree_pids "bash ${file}"`
	if [ ! -z "${pids}" ]; then
		if [ "${quiet}" != 'true' ]; then
			stop_pids "${pids}" | awk '{print "   "$0}'
		else
			stop_pids "${pids}" >/dev/null 2>&1
		fi
	fi

	mkdir -p "${file}.data"
	local ts=`date +%s`
	local sys_end=`tail -n 1 "${file}.data/stdout.log" | grep '^!'`
	if [ -z "${sys_end}" ]; then
		echo "!STOPPED ${ts} [`date +'%D %T'`]" >> "${file}.data/stdout.log"
	fi

	local stop_script="${file}.stop"
	if [ -f "${stop_script}" ]; then
		local result=`bash "${stop_script}" "${clean}" 2>&1`
		if [ "$?" != 0 ] || [ ! -z "${result}" ]; then
			echo "!STOPPING" >> "${file}.data/stop.log"
			echo "${result}" >> "${file}.data/stop.log"
		fi
	fi
}
export -f kp_sh_stop

function kp_file_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func kp_file_stop] usage: <func> kp_file [clean]" >&2
		return 1
	fi

	local file="${1}"
	if [ -z "${2+x}" ]; then
		local clean='false'
	else
		local clean="${2}"
	fi

	kp_file_iter "${file}" | while read line; do
		local result=`kp_sh_stop "${line}" "${clean}"`
		local skipped=`echo "${result}" | { grep 'skipped' || test $? = 1; }`
		if [ -z "${skipped}" ]; then
			echo "[`date +'%D %T'`] STOP ${line}" >> "${file}.log"
		fi
		echo "${result}"
	done
}
export -f kp_file_stop

function _kp_sh_last_active()
{
	if [ -z "${1+x}" ]; then
		echo "[func _kp_sh_last_active] usage: <func> kp_file" >&2
		return 1
	fi

	local file="${1}"
	local atime='0'
	local err_atime='0'
	if [ -f "${file}.data/stdout.log" ]; then
		local atime=`file_mtime "${file}.data/stdout.log"`
	elif [ -f "${file}.log" ]; then
		local atime=`file_mtime "${file}.log"`
	fi

	if [ -f "${file}.data/stderr.log" ]; then
		local err_atime=`file_mtime "${file}.data/stderr.log"`
	elif [ -f "${file}.err.log" ]; then
		local err_atime=`file_mtime "${file}.err.log"`
	fi
	if [ ${err_atime} -gt ${atime} ]; then
		local atime="${err_atime}"
	fi

	local now=`date +%s`
	if [ "${atime}" != '0' ]; then
		echo $((now - atime))
	else
		echo '(unknown)'
	fi
}
export -f _kp_sh_last_active

function kp_file_status()
{
	if [ -z "${2+x}" ]; then
		echo "[func kp_file_status] usage: <func> kp_file width" >&2
		return 1
	fi

	local file="${1}"
	local width="${2}"

	if [ ! -f "${file}" ]; then
		echo "[func kp_file_status] ${file} is not a file" >&2
		return 1
	fi

	kp_file_iter "${file}" | while read line; do
		if [ -f "${line}.data/stdout.log" ]; then
			local start_time=`tail -n 99999 "${line}.data/stdout.log" | { grep '!RUN' || test $? = 1; } | tail -n 1 | awk '{print $2}'`
		else
			local start_time=''
		fi

		local atime=`_kp_sh_last_active "${line}"`
		if [ ! -z "${start_time}" ]; then
			local now=`date +%s`
			local stime=$((now - start_time))
			local time_status=" \033[34m${stime}s\033[0m:\033[35m${atime}s\033[0m"
		elif [ ! -z "${atime}" ]; then
			local time_status=" \033[34m${atime}s\033[0m"
		else
			local time_status=''
		fi

		local pid=`_kp_file_pid "${line}"`
		if [ ! -z "${pid}" ]; then
			local pid_cnt=`echo "${pid}" | wc -l | awk '{print $1}'`
			if [ "${pid_cnt}" == '1' ]; then
				local run_status="\033[32m[+]\033[0m"
			else
				local run_status="\033[33m[?]\033[0m"
			fi
		else
			local run_status="\033[31m[!]\033[0m"
		fi

		echo -e "${run_status} \033[36m[task] ${line}\033[0m${time_status}"

		if [ -f "${line}.data/report" ]; then
			cat "${line}.data/report" | awk '{print "    "$0}'
		fi

		if [ ! -z "${start_time}" ] && [ -f "${line}.data/stderr.log" ]; then
			local stderr=`tail -n 9999 "${line}.data/stderr.log" | { grep "!RUN ${start_time}" -A 9999 || test $? = 1; } | { grep -v '!RUN' || test $? = 1; } | { grep -v "${start_time}" || test $? = 1; }`
			if [ ! -z "${stderr}" ]; then
				local err_cnt=`echo "${stderr}" | wc -l | awk '{print $1}'`
				if [ "${err_cnt}" -gt '4' ]; then
					local stderr=`echo "$stderr" | tail -n 4`
				fi
				echo -e '    \033[33m-- stderr --\033[0m'
				echo "${stderr}" | awk '{print "    \033[33m"$0"\033[0m"}'
			fi
		fi

		if [ ! -f "${line}.data/stdout.log" ]; then
			continue
		fi

		local here="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`"
		python "${here}/kp_log_report.py" "${line}.data/stdout.log" \
			"${line}.err.log" "${width}" 'color' | awk '{print "    \033[32m<<\033[0m"$0}'
	done
}
export -f kp_file_status

function kp_print_line()
{
	local width=`terminal_width 2>/dev/null`
	local width=$((width - 4))
	local line=`yes '-' | head -n "${width}"`
	echo "${line}" | tr "\n" ' ' | sed 's/ //g' | awk '{print "    "$0}'
}
export -f kp_print_line
