#!/bin/bash

function ssh_get_value_from_proc_info()
{
	if [ -z "${3+x}" ]; then
		echo "[func ssh_get_value_from_proc_info] host dir key" >&2
		return 1
	fi

	local host="${1}"
	local dir="${2}"
	local key="${3}"

	local info_file="${dir}/proc.info"

	if [ "`is_local_host ${host}`" == 'true' ]; then
		if [ ! -f "${info_file}" ]; then
			return
		fi
		get_value "${info_file}" "${key}"
	else
		local has_info=`ssh_exe "${host}" "test -f \"${info_file}\" && echo true"`
		if [ "${has_info}" != 'true' ]; then
			return
		fi
		ssh_exe "${host}" "grep \"${key}\" \"${info_file}\"" | awk '{print $2}'
	fi
}
export -f ssh_get_value_from_proc_info

function from_mods_by_type()
{
	if [ -z "${2+x}" ]; then
		echo "[func from_mods_by_type] usage: <func> mods_info_lines candidate_type" >&2
		return 1
	fi

	local mods="${1}"
	local type="${2}"
	if [ -z "${type}" ]; then
		echo "${mods}"
	else
		echo "${mods}" | { grep $'\t'"${type}[[:blank:]]" || test $? = 1; }
	fi
}
export -f from_mods_by_type

function from_mods_not_type()
{
	if [ -z "${2+x}" ]; then
		echo "[func from_mods_not_type] usage: <func> mods_info_lines type" >&2
		return 1
	fi

	local mods="${1}"
	local type="${2}"
	if [ -z "${type}" ]; then
		echo "${mods}"
	else
		echo "${mods}" | { grep -v $'\t'"${type}[[:blank:]]" || test $? = 1; }
	fi
}
export -f from_mods_not_type

function from_mods_get_mod()
{
	if [ -z "${3+x}" ]; then
		echo "[func from_mods_get_mod] usage: <func> mods_info_lines candidate_type index" >&2
		return 1
	fi

	local mods="${1}"
	local type="${2}"
	local index="${3}"

	local instances=`from_mods_by_type "${mods}" "${type}"`
	if [ -z "${instances}" ]; then
		return
	fi
	local count=`echo "${instances}" | wc -l | awk '{print $1}'`

	local index_base_1=$((index + 1))
	local mod=`echo "${instances}" | head -n "${index_base_1}" | tail -n 1`
	# TODO: check the meaning of the following fix
	# "${mod_index}" is mod's index in ti_file
	# "${index}" is mod's index in "${mods}"
	# So "${mod_index}" cannot be compared with "${index}"
	# local mod_index=`echo "${mod}" | awk '{print $1}'`
	# if [ "${mod_index}" == "${index}" ]; then
	# 	echo "${mod}"
	# fi
	echo "${mod}"
}
export -f from_mods_get_mod

function from_mods_random_mod()
{
	if [ -z "${2+x}" ]; then
		echo "[func from_mods_random_mod] usage: <func> mods_info_lines candidate_type [index_only=true]" >&2
		return 1
	fi

	local mods="${1}"
	local type="${2}"

	local index_only='true'
	if [ ! -z "${3+x}" ]; then
		local index_only="${3}"
	fi

	local instances=`from_mods_by_type "${mods}" "${type}"`
	if [ -z "${instances}" ]; then
		return
	fi
	local count=`echo "${instances}" | wc -l | awk '{print $1}'`

	local index="${RANDOM}"
	local index=$((index % count))
	local mod=`from_mods_get_mod "${mods}" "${type}" "${index}"`
	if [ "${index_only}" == 'true' ]; then
		echo "${mod}" | awk '{print $1}'
	else
		echo "${mod}"
	fi
}
export -f from_mods_random_mod

function from_mod_get_index()
{
	if [ -z "${1+x}" ]; then
		echo "[func from_mod_get_index] usage: <func> mod_info_line" >&2
		return 1
	fi
	local mod="${1}"
	echo "${mod}" | awk -F '\t' '{print $1}'
}
export -f from_mod_get_index

function from_mod_get_name()
{
	if [ -z "${1+x}" ]; then
		echo "[func from_mod_get_name] usage: <func> mod_info_line" >&2
		return 1
	fi
	local mod="${1}"
	echo "${mod}" | awk -F '\t' '{print $2}'
}
export -f from_mod_get_name

function from_mod_get_dir()
{
	if [ -z "${1+x}" ]; then
		echo "[func from_mod_get_dir] usage: <func> mod_info_line" >&2
		return 1
	fi
	local mod="${1}"
	echo "${mod}" | awk -F '\t' '{print $3}'
}
export -f from_mod_get_dir

function from_mod_get_conf()
{
	if [ -z "${1+x}" ]; then
		echo "[func from_mod_get_conf] usage: <func> mod_info_line" >&2
		return 1
	fi
	local mod="${1}"
	echo "${mod}" | awk -F '\t' '{print $4}'
}
export -f from_mod_get_conf

function from_mod_get_host()
{
	if [ -z "${1+x}" ]; then
		echo "[func from_mod_get_host] usage: <func> mod_info_line" >&2
		return 1
	fi
	local mod="${1}"
	local host=`echo "${mod}" | awk -F '\t' '{print $5}'`
	if [ -z "${host}" ]; then
		local host=`must_print_ip`
	fi
	echo "${host}"
}
export -f from_mod_get_host

function from_mod_get_proc_info()
{
	if [ -z "${2+x}" ]; then
		echo "[func from_mod_get_proc_info] usage: <func> mod_info_line match_key" >&2
		return 1
	fi
	local mod="${1}"
	local dir=`from_mod_get_dir "${mod}"`
	local host=`from_mod_get_host "${mod}"`
	local key="${2}"
	ssh_get_value_from_proc_info "${host}" "${dir}" "${key}"
}
export -f from_mod_get_proc_info

function mysql_explain()
{
	if [ -z "${4+x}" ]; then
		echo "[func mysql_explain] usage: <func> host port query si" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local query_input="${3}"
	local si="${4}"

	# if query_input is a file, read its content.
    if [ -f "${query_input}" ]; then
        local query=`cat "${query_input}"`
    else
        local query="${query_input}"
    fi

	if [ ! -z "`echo ${query} | sed 's/ //g' | { grep '^explain' || test $? = 1; }`" ]; then
		return
	fi

	if [ ! -z "${si}" ]; then
		local si="set @@session.tidb_isolation_read_engines=\"${si}\"; "
	fi

	local explain='explain '
	if [ ! -z "`echo ${query} | { grep 'select' || test $? = 1; }`" ]; then
		local plan=`mysql -h "${host}" -P "${port}" -u root --database="${db}" --comments -e "${si}${explain}${query}" 2>&1`
		if [ ! -z "`echo ${plan} | { grep 'ERROR' || test $? = 1; }`" ]; then
			#echo "${plan}"
			#echo "when executing: '${si}${explain}${query}'"
			return
		else
			echo "${query}"
			echo "------------"
			echo "${plan}"
			echo "------------"
		fi
	fi
}
export -f mysql_explain

function unfold_cmd_chain()
{
	if [ -z "${1+x}" ]; then
		echo "[func unfold_cmd_chain] usage: <func> cmd_and_args"
		return 1
	fi
	print_args "${@}" | python "${integrated}/_base/ti_file/unfold_cmd_chain.py"
}
export -f unfold_cmd_chain
