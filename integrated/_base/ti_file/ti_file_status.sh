#!/bin/bash

function ti_file_mod_status()
{
	if [ -z "${2+x}" ]; then
		echo "[func ti_file_mod_status] usage <func> dir conf" >&2
		return 1
	fi

	local dir="${1}"
	local conf="${2}"

	local up_status="OK    "
	if [ ! -d "${dir}" ]; then
		local up_status="MISSED"
	elif [ -f "${dir}/extra_str_to_find_proc" ]; then
		local extra_str_to_find_proc=`cat "${dir}/extra_str_to_find_proc"`
		local pid_cnt=`print_proc_cnt "${dir}/" "${extra_str_to_find_proc}"`
		if [ "${pid_cnt}" == "0" ]; then
			local up_status="DOWN  "
		else
			if [ "${pid_cnt}" != "1" ]; then
				local up_status="MULTI "
			fi
		fi
	else
		local conf_file=`abs_path "${dir}"`/${conf}
		local pid_cnt=`print_proc_cnt "${conf_file}"`
		if [ "${pid_cnt}" == "0" ]; then
			local up_status="DOWN  "
		else
			if [ "${pid_cnt}" != "1" ]; then
				local up_status="MULTI "
			fi
		fi
	fi
	echo "${up_status}"
}
export -f ti_file_mod_status

function ti_file_cmd_status()
{
	if [ -z "${4+x}" ]; then
		echo "[func ti_file_cmd_status] usage <func> index name dir conf" >&2
		return 1
	fi

	local index="${1}"
	local name="${2}"
	local dir="${3}"
	local conf="${4}"

	local up_status=`ti_file_mod_status "${dir}" "${conf}"`

	echo "${up_status} ${name} #${index} (${dir})"
}
export -f ti_file_cmd_status
