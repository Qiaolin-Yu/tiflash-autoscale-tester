#!/bin/bash

function wait_for_mysql()
{
	if [ -z "${3+x}" ]; then
		echo "[func wait_for_mysql] usage: <func> host port timeout [server_id]" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local timeout="${3}"
	if [ -z "${4+x}" ]; then
		local server_id="${host}:${port}"
	else
		local server_id="${4}"
	fi

	local error_handle="$-"
	set +e

	mysql --help 1>/dev/null 2>&1
	if [ "$?" != "0" ]; then
		echo "[func wait_for_mysql] run mysql client failed" >&2
		restore_error_handle_flags "${error_handle}"
		return 1
	fi

	local failed='true'
	for ((i=0; i<${timeout}; i++)); do
		mysql -h "${host}" -P "${port}" -u root -e 'show databases' 1>/dev/null 2>&1
		if [ "$?" == "0" ]; then
			local failed='false'
			break
		else
			if [ $((${i} % 10)) = 0 ] && [ ${i} -ge 10 ]; then
				echo "#${i} waiting for mysql|tidb at '${server_id}'"
			fi
			sleep 1
		fi
	done

	restore_error_handle_flags "${error_handle}"

	if [ "${failed}" != 'false' ]; then
		return 1
	fi

	# TODO: remove this!
	sleep 5
}
export -f wait_for_mysql

# TODO: If PD/TiKV/TiDB down, do fast-failure
function wait_for_tidb()
{
	if [ -z "${1+x}" ]; then
		echo "[func wait_for_tidb] usage: <func> tidb_dir [timeout=300]" >&2
		return 1
	fi

	local tidb_dir="${1}"
	local timeout=300
	if [ ! -z "${2+x}" ]; then
		timeout="${2}"
	fi

	local tidb_info="${tidb_dir}/proc.info"
	if [ ! -f "${tidb_info}" ]; then
		echo "[func wait_for_tidb] '${tidb_dir}' tidb not exists" >&2
		return 1
	fi

	local host=`cat "${tidb_info}" | { grep 'advertise_host' || test $? = 1; } | awk -F '\t' '{print $2}'`
	local port=`cat "${tidb_info}" | { grep 'tidb_port' || test $? = 1; } | awk -F '\t' '{print $2}'`

	wait_for_mysql "${host}" "${port}" "${timeout}" "${tidb_dir}"
}
export -f wait_for_tidb

function wait_for_tidb_by_host()
{
	if [ -z "${4+x}" ]; then
		echo "[func wait_for_tidb_by_host] usage: <func> host port timeout default_ports_file" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local timeout="${3}"
	local default_ports="${4}"

	local default_tidb_port=`get_value "${default_ports}" 'tidb_port'`
	local addr=`cal_addr ":${port}" '' "${default_tidb_port}"`
	local port="${addr:1}"

	wait_for_mysql "${host}" "${port}" "${timeout}"
}
export -f wait_for_tidb_by_host

function wait_for_pd_port_ready()
{
	if [ -z "${3+x}" ]; then
		echo "[func wait_for_pd_port_ready] usage: <func> host port timeout [server_id]" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local timeout="${3}"
	if [ -z "${4+x}" ]; then
		local server_id="${host}:${port}"
	else
		local server_id="${4}"
	fi

	local failed='true'

	local error_handle="$-"
	set +e
	local nc_installed=`print_cmd_installed "nc"`
	if [ "${nc_installed}" == "false" ]; then
		echo "    nc not installed" >&2
		return 1
	fi
	for ((i=0; i<${timeout}; i++)); do
		nc -zv "${host}" "${port}" >/dev/null 2>&1
		if [ "${?}" == "0" ] && [ "`curl "${host}:${port}/health" 2>/dev/null`" == '{"health":"true"}' ]; then
			local failed='false'
			break
		else
			if [ $((${i} % 10)) = 0 ] && [ ${i} -ge 10 ]; then
				echo "#${i} waiting for pd client port ready at '${server_id}'"
			fi
		fi
		sleep 1
	done

	restore_error_handle_flags "${error_handle}"

	if [ "${failed}" != 'false' ]; then
		return 1
	fi
}
export -f wait_for_pd_port_ready

function wait_for_pd_port_ready_local()
{
	if [ -z "${1+x}" ]; then
		echo "[func wait_for_pd_port_ready_local] usage: <func> pd_dir [timeout=300]" >&2
		return 1
	fi

	local pd_dir="${1}"
	local timeout=300
	if [ ! -z "${2+x}" ]; then
		timeout="${2}"
	fi

	local pd_info="${pd_dir}/proc.info"
	if [ ! -f "${pd_info}" ]; then
		echo "[func wait_for_pd_port_ready_local] '${pd_dir}' pd not exists" >&2
		return 1
	fi
	local host=`get_value "${pd_info}" 'advertise_host'`
	local port=`get_value "${pd_info}" 'pd_port'`
	local server_id="${host}:${port}:${pd_dir}"

	wait_for_pd_port_ready "${host}" "${port}" "${timeout}" "${server_id}"
}
export -f wait_for_pd_port_ready_local

function wait_for_pd()
{
	if [ -z "${4+x}" ]; then
		echo "[func wait_for_pd] usage: <func> host port timeout bins_dir [server_id]" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local timeout="${3}"
	local bins_dir="${4}"
	if [ -z "${5+x}" ]; then
		local server_id="${host}:${port}"
	else
		local server_id="${5}"
	fi

	local error_handle="$-"
	set +e

	local pd_ctl_path="${bins_dir}/pd-ctl"
	ensure_bin_in_local_dir "pd_ctl" "${bins_dir}"
	if [ ! -f "${pd_ctl_path}" ]; then
		echo "[func wait_for_pd] '${pd_ctl_path}' not found" >&2
		return 1
	fi

	local failed='true'

	# TODO: move this key to config
	local key="6D536368656D615665FF7273696F6E4B6579FF0000000000000000F70000000000000073"
	for ((i=0; i<${timeout}; i++)); do
		local region=`"${pd_ctl_path}" -u "http://${host}:${port}" <<< "region key ${key}"` >/dev/null
		if [ "${region}" != "null" ] && [ `echo "${region}" | { grep "Failed" || test $? = 1; } | wc -l` == 0 ]; then
			local failed='false'
			break
		else
			if [ $((${i} % 10)) = 0 ] && [ ${i} -ge 10 ]; then
				echo "#${i} waiting for pd ready at '${server_id}'"
			fi
		fi
		sleep 1
	done

	restore_error_handle_flags "${error_handle}"

	if [ "${failed}" != 'false' ]; then
		return 1
	fi

	# TODO: remove this!
	sleep 5
}
export -f wait_for_pd

function wait_for_pd_local()
{
	if [ -z "${1+x}" ]; then
		echo "[func wait_for_pd] usage: <func> pd_dir [timeout=300]" >&2
		return 1
	fi

	local pd_dir="${1}"
	local timeout=300
	if [ ! -z "${2+x}" ]; then
		timeout="${2}"
	fi

	local pd_info="${pd_dir}/proc.info"
	if [ ! -f "${pd_info}" ]; then
		echo "[func wait_for_pd_local] '${pd_dir}' pd not exists" >&2
		return 1
	fi
	local host=`get_value "${pd_info}" 'advertise_host'`
	local port=`get_value "${pd_info}" 'pd_port'`
	local server_id="${host}:${port}:${pd_dir}"

	wait_for_pd "${host}" "${port}" "${timeout}" "${pd_dir}" "${server_id}"
}
export -f wait_for_pd_local

function wait_for_pd_by_host()
{
	if [ -z "${5+x}" ]; then
		echo "[func wait_for_pd_by_host] usage: <func> host port timeout bins_dir default_ports_file" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local timeout="${3}"
	local bins_dir="${4}"
	local default_ports="${5}"

	local default_pd_port=`get_value "${default_ports}" 'pd_port'`
	local addr=`cal_addr ":${port}" '' "${default_pd_port}"`
	local port="${addr:1}"

	wait_for_pd "${host}" "${port}" "${timeout}" "${bins_dir}"
}
export -f wait_for_pd_by_host

function wait_for_tikv_port_ready()
{
	if [ -z "${3+x}" ]; then
		echo "[func wait_for_tikv_port_ready] usage: <func> host port timeout [server_id]" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local timeout="${3}"
	if [ -z "${4+x}" ]; then
		local server_id="${host}:${port}"
	else
		local server_id="${4}"
	fi

	local failed='true'

	local error_handle="$-"
	set +e
	local nc_installed=`print_cmd_installed "nc"`
	if [ "${nc_installed}" == "false" ]; then
		echo "    nc not installed" >&2
		return 1
	fi
	for ((i=0; i<${timeout}; i++)); do
		nc -zv "${host}" "${port}" >/dev/null 2>&1
		if [ "${?}" == "0" ]; then
			local failed='false'
			break
		else
			if [ $((${i} % 10)) = 0 ] && [ ${i} -ge 10 ]; then
				echo "#${i} waiting for tikv client port ready at '${server_id}'"
			fi
		fi
		sleep 1
	done

	restore_error_handle_flags "${error_handle}"

	if [ "${failed}" != 'false' ]; then
		return 1
	fi
}
export -f wait_for_tikv_port_ready

function wait_for_tikv_port_ready_local()
{
	if [ -z "${1+x}" ]; then
		echo "[func wait_for_tikv_port_ready_local] usage: <func> tikv_dir [timeout=300]" >&2
		return 1
	fi

	local tikv_dir="${1}"
	local timeout=300
	if [ ! -z "${2+x}" ]; then
		timeout="${2}"
	fi

	local tikv_info="${tikv_dir}/proc.info"
	if [ ! -f "${tikv_info}" ]; then
		echo "[func wait_for_tikv_port_ready_local] '${tikv_dir}' not exists" >&2
		return 1
	fi
	local host=`get_value "${tikv_info}" 'advertise_host'`
	local port=`get_value "${tikv_info}" 'tikv_port'`
	local server_id="${host}:${port}:${tikv_dir}"

	wait_for_tikv_port_ready "${host}" "${port}" "${timeout}" "${server_id}"
}
export -f wait_for_tikv_port_ready_local

function wait_for_tiflash()
{
	if [ -z "${3+x}" ]; then
		echo "[func wait_for_tiflash] usage: <func> host port timeout [server_id]" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local timeout="${3}"
	if [ -z "${4+x}" ]; then
		local server_id="${host}:${port}"
	else
		local server_id="${4}"
	fi

	local failed='true'

	local error_handle="$-"
	set +e
	local nc_installed=`print_cmd_installed "nc"`
	if [ "${nc_installed}" == "false" ]; then
		echo "    nc not installed" >&2
		return 1
	fi
	for ((i=0; i<${timeout}; i++)); do
		nc -z "${host}" "${port}" 1>/dev/null 2>&1
		if [ "$?" == "0" ]; then
			local failed='false'
			break
		else
			if [ $((${i} % 10)) = 0 ] && [ ${i} -ge 10 ]; then
				echo "#${i} waiting for tiflash raft port ${host}:${port} ready at '${server_id}'"
			fi
			sleep 1
		fi
	done

	restore_error_handle_flags "${error_handle}"

	if [ "${failed}" != 'false' ]; then
		return 1
	fi
}
export -f wait_for_tiflash

function wait_for_tiflash_local()
{
	if [ -z "${1+x}" ]; then
		echo "[func wait_for_tiflash_local] usage: <func> tiflash_dir [timeout=300]" >&2
		return 1
	fi

	local tiflash_dir="${1}"
	local timeout=300
	if [ ! -z "${2+x}" ]; then
		timeout="${2}"
	fi

	local tiflash_info="${tiflash_dir}/proc.info"
	if [ ! -f "${tiflash_info}" ]; then
		echo "[func wait_for_tiflash_local] '${tiflash_dir}' tiflash not exists" >&2
		return 1
	fi

	local host=`cat "${tiflash_info}" | { grep 'listen_host' || test $? = 1; } | awk -F '\t' '{print $2}'`
	local port=`cat "${tiflash_info}" | { grep 'raft_and_cop_port' || test $? = 1; } | awk -F '\t' '{print $2}'`

	wait_for_tiflash "${host}" "${port}" "${timeout}" "${tiflash_dir}"
}
export -f wait_for_tiflash_local

function wait_for_tiflash_by_host()
{
	if [ -z "${4+x}" ]; then
		echo "[func wait_for_tiflash_by_host] usage: <func> host port timeout default_ports_file" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local timeout="${3}"
	local default_ports="${4}"

	local default_tiflash_raft_and_cop_port=`get_value "${default_ports}" 'tiflash_raft_and_cop_port'`
	local addr=`cal_addr ":${port}" '' "${default_tiflash_raft_and_cop_port}"`
	local port="${addr:1}"

	wait_for_tiflash "${host}" "${port}" "${timeout}"
}
export -f wait_for_tiflash_by_host
