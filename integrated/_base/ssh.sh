#!/bin/bash

function ssh_exe()
{
	if [ -z "${2+x}" ]; then
		echo "[func ssh_exe] usage: <func> host cmd" >&2
		return 1
	fi
	local host="${1}"
	local cmd="${2}"
	ssh -o BatchMode=yes "${host}" "${cmd}" </dev/null
}
export -f ssh_exe

function ssh_ping()
{
	if [ -z "${1+x}" ]; then
		echo "[func ssh_ping] usage: <func> host" >&2
		return 1
	fi
	local host="${1}"
	local result=`ssh_exe "${host}" "echo \"hello\"" 2>/dev/null | { grep 'hello' || test $? = 1; }`
	if [ -z "${result}" ]; then
		echo "[func ssh_ping] can't login to '${host}' by default auth" >&2
		return 1
	fi
}
export -f ssh_ping

function script_exe()
{
	if [ -z "${1+x}" ]; then
		echo "[func script_ext] usage: <func> script_path [args]" >&2
		return 1
	fi

	local script="${1}"
	local error_handle="$-"
	set +u
	local args=("${@}")
	local args=("${args[@]:1}")
	restore_error_handle_flags "${error_handle}"

	bash "${script}" "${args[@]}"
}
export -f script_exe

function call_remote_func_raw()
{
	if [ -z "${3+x}" ]; then
		echo "[func call_remote_func] usage: <func> host remote_env_dir func [args]" >&2
		return 1
	fi

	local host="${1}"
	local env_dir="${2}"
	local func="${3}"
	shift 3

	local args_str=`esc_args "${@}"`
	ssh -o BatchMode=yes "${host}" "source \"${env_dir}/_env.sh\" && \"${func}\" ${args_str}" </dev/null 2>&1
}
export -f call_remote_func_raw

function call_remote_func()
{
	if [ -z "${3+x}" ]; then
		echo "[func call_remote_func] usage: <func> host remote_env_dir func [args]" >&2
		return 1
	fi

	local host="${1}"
	local ext=`print_file_ext "${host}"`
	local ext_len=`echo ${#ext}`
	local prefix="[${host}] "
	if [ "${ext_len}" == '2' ]; then
		local prefix="[${host}_] "
	fi
	if [ "${ext_len}" == '1' ]; then
		local prefix="[${host}__] "
	fi
	call_remote_func_raw "${@}" | awk '{print "'"${prefix}"'"$0}'
}
export -f call_remote_func

function cp_dir_to_host()
{
	if [ -z "${3+x}" ]; then
		echo "[func cp_dir_to_host] usage: <func> loca_src_dir host remote_dest_dir" >&2
		return 1
	fi

	local src="${1}"
	local host="${2}"
	local dest="${3}"

	local dir_name=`basename "${src}"`
	local parent_dir=`dirname "${src}"`
	local tar_file="${dir_name}.tar.gz"
	local tar_path="${parent_dir}/${tar_file}"

	ssh_exe "${host}" "mkdir -p \"${remote_dest_dir}\""
	rsync -qar "${src}" "${host}:${remote_dest_dir}"
	return
}
export -f cp_dir_to_host
