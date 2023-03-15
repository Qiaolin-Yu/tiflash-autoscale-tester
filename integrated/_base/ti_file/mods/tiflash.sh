#!/bin/bash

function install_proxy_lib_on_mac()
{
	if [ -z "${1+x}" ]; then
		echo "[func install_proxy_lib_on_mac] usage: <func> tiflash_dir" >&2
		return 1
	fi

	local dir="${1}"

	if [ `uname` != "Darwin" ]; then
		return
	fi

	# TODO: remove hard code file name from this func
	local proxy_file_name="libtiflash_proxy.dylib"
	local tiflash_bin_name="tiflash"
	if [ ! -f "${dir}/${proxy_file_name}" ]; then
		echo "[func install_proxy_lib_on_mac] can not find dir ${dir}/${proxy_file_name}" >&2
		return 1
	fi
	local orig_proxy_path=`otool -L "${dir}/${proxy_file_name}" | grep "libtiflash_proxy.dylib[[:blank:]]" | awk -F '(' '{print $1}'`
	if [ ! -z "${orig_proxy_path}" ] && [ "${orig_proxy_path}" != "${dir}/${proxy_file_name}" ]; then
		install_name_tool -id "${dir}/${proxy_file_name}" "${dir}/${proxy_file_name}"
	fi

	if [ ! -f "${dir}/${tiflash_bin_name}" ]; then
		echo "[func install_proxy_lib_on_mac] can not find dir ${dir}/${tiflash_bin_name}" >&2
		return 1
	fi
	local dependent_proxy_path=`otool -L "${dir}/${tiflash_bin_name}" | grep "libtiflash_proxy.dylib[[:blank:]]" | awk -F '(' '{print $1}' | trim_space`
	if [ ! -z "${dependent_proxy_path}" ] && [ "${dependent_proxy_path}" != "${dir}/${proxy_file_name}" ]; then
		install_name_tool -change "${dependent_proxy_path}" "${dir}/${proxy_file_name}" "${dir}/${tiflash_bin_name}"
	fi
}
export -f install_proxy_lib_on_mac

function get_tiflash_lib_path_for_linux()
{
	if [ -z "${1+x}" ]; then
		echo "[func get_tiflash_lib_path_for_linux] usage: <func> tiflash_dir" >&2
		return 1
	fi

	local dir="${1}"

	if [ `uname` == "Darwin" ]; then
		return
	fi

	# TODO: check whether the following path exists before use it
	# use library in tiflash binary first
	local lib_path="${dir}:.:/usr/local/lib64:/usr/local/lib:/usr/lib64:/usr/lib"
	if [ -z "${LD_LIBRARY_PATH+x}" ]; then
		echo "${lib_path}"
	else
		echo "${LD_LIBRARY_PATH}:${lib_path}"
	fi
}
export -f get_tiflash_lib_path_for_linux

function run_query_through_ch_client()
{
	if [ -z "${1+x}" ] || [ -z "${1}" ]; then
		echo "[func run_query_through_ch_client] usage: <func> ch_binary [args]" >&2
		return 1
	fi

	local ch_binary="${1}"
	local bin_dir=`dirname "${ch_binary}"`

	shift 1

	if [ -z "${1+x}" ]; then
		echo "[func run_query_through_ch_client] no args provided" >&2
		return 0
	fi

	if [ `uname` == "Darwin" ]; then
		install_proxy_lib_on_mac "${bin_dir}"
		"${ch_binary}" client "${@}"
	else
		LD_LIBRARY_PATH="`get_tiflash_lib_path_for_linux ${bin_dir}`" "${ch_binary}" client "${@}"
	fi
}
export -f run_query_through_ch_client

function get_storage_engine_in_config()
{
	if [ -z "${1+x}" ] || [ -z "${1}" ]; then
		echo "[func get_storage_engine_in_config] usage: <func> config_file" >&2
		return 1
	fi

	local config_file="${1}"
	if [ ! -f "${config_file}" ];then
		echo "[func replace_storage_engine_in_config] file not exist: \"${config_file}\"" >&2
		return 1
	fi

	local engine=$(cat "${config_file}" | grep -v '^#' | grep 'storage_engine' | awk -F= '{print $2}' | awk -F'"' '{print $2}')
	if [ -z "${engine}" ]; then
		echo "[func get_storage_engine_in_config] can not get storage_engine in \"${config_file}\"!" >&2
		return 1
	else
		echo "${engine}"
	fi
}

function tiflash_run()
{
	if [ -z "${2+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func tiflash_run] usage: <func> tiflash_dir conf_templ_dir [daemon_mode] [pd_addr] [tidb_addr] [ports_delta] [listen_host] [cluster_id] [standalone] [storage_engine]" >&2
		return 1
	fi

	local tiflash_dir="${1}"
	local tiflash_dir=`abs_path "${tiflash_dir}"`

	local conf_templ_dir="${2}"

	if [ -z "${3+x}" ]; then
		local daemon_mode="false"
	else
		local daemon_mode="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local pd_addr=""
	else
		local pd_addr="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local tidb_addr=""
	else
		local tidb_addr="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local ports_delta="0"
	else
		local ports_delta="${6}"
	fi

	if [ -z "${7+x}" ]; then
		local listen_host=""
	else
		local listen_host="${7}"
	fi

	if [ -z "${8+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${8}"
	fi

	if [ -z "${9+x}" ]; then
		local standalone="false"
	else
		local standalone="${9}"
	fi

	# print a warning if try to set up tiflash without pd/tidb and not running with standalone mode.
	# tiflash may not run normally in this situation.
	if [ -z "${tidb_addr}" ] || [ -z "${pd_addr}" ] && [ "${standalone}" != 'true'  ]; then
		echo "[warn] If you want to run a standalone tiflash without pd/tidb/tikv, consider to add 'standalone' at the end for tiflash."
	fi

	# for standalone mode, we remove proxy from config file
	if [ "${standalone}" != "true" ]; then
		local tiflash_config_template="${conf_templ_dir}/tiflash/config.toml"
	else
		local tiflash_config_template="${conf_templ_dir}/tiflash/standalone.toml"
	fi

	if [ -z "${10+x}" ] || [ -z "${10}" ] ; then
		# by default, keep the storage_engine in "config.toml"
		local storage_engine=$(get_storage_engine_in_config "${tiflash_config_template}")
		if [ -z ${storage_engine} ]; then
			echo "[func tiflash_run] please set storage_engine in ${tiflash_config_template} or set engine=(dt|tmt) for tiflash in your .ti file" >&2
			return 1
		fi
	else
		local storage_engine="${10}"
	fi

	if [ "${standalone}" != 'true' ]; then
		echo "=> run tiflash(${storage_engine}): ${tiflash_dir}"
	else
		echo "=> run tiflash(${storage_engine})(standalone): ${tiflash_dir}"
	fi

	local default_ports="${conf_templ_dir}/default.ports"

	local default_pd_port=`get_value "${default_ports}" 'pd_port'`
	if [ -z "${default_pd_port}" ]; then
		echo "   get default pd_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tidb_status_port=`get_value "${default_ports}" 'tidb_status_port'`
	if [ -z "${default_tidb_status_port}" ]; then
		echo "   get default tidb_status_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tiflash_http_port=`get_value "${default_ports}" 'tiflash_http_port'`
	if [ -z "${default_tiflash_http_port}" ]; then
		echo "   get default tiflash_http_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tiflash_tcp_port=`get_value "${default_ports}" 'tiflash_tcp_port'`
	if [ -z "${default_tiflash_tcp_port}" ]; then
		echo "   get default tiflash_tcp_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tiflash_interserver_http_port=`get_value "${default_ports}" 'tiflash_interserver_http_port'`
	if [ -z "${default_tiflash_interserver_http_port}" ]; then
		echo "   get default tiflash_interserver_http_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tiflash_raft_and_cop_port=`get_value "${default_ports}" 'tiflash_raft_and_cop_port'`
	if [ -z "${default_tiflash_raft_and_cop_port}" ]; then
		echo "   get default tiflash_raft_and_cop_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tiflash_status_port=`get_value "${default_ports}" 'tiflash_status_port'`
	if [ -z "${default_tiflash_status_port}" ]; then
		echo "   get default tiflash_status_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_proxy_port=`get_value "${default_ports}" 'proxy_port'`
	if [ -z "${default_proxy_port}" ]; then
		echo "   get default proxy_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_proxy_status_port=`get_value "${default_ports}" 'proxy_status_port'`
	if [ -z "${default_proxy_status_port}" ]; then
		echo "   get default proxy_status_port from ${default_ports} failed" >&2
		return 1
	fi

	local pd_addr=$(cal_addr "${pd_addr}" `must_print_ip` "${default_pd_port}")
	local tidb_addr=$(cal_addr "${tidb_addr}" `must_print_ip` "${default_tidb_status_port}")

	if [ -z "${listen_host}" ]; then
		local listen_host="`must_print_ip`"
	fi

	mkdir -p "${tiflash_dir}"

	if [ ! -d "${tiflash_dir}" ]; then
		echo "   ${tiflash_dir} is not a dir" >&2
		return 1
	fi

	local conf_file="${tiflash_dir}/conf/config.toml"
	local proxy_conf_file="${tiflash_dir}/conf/proxy.toml"

	local proc_cnt=`print_proc_cnt "${conf_file}" "\-\-config"`
	if [ "${proc_cnt}" != "0" ]; then
		echo "   running(${proc_cnt}), skipped"
		return 0
	fi

	local http_port=$((${ports_delta} + ${default_tiflash_http_port}))
	local tcp_port=$((${ports_delta} + ${default_tiflash_tcp_port}))
	local interserver_http_port=$((${ports_delta} + ${default_tiflash_interserver_http_port}))
	local tiflash_raft_and_cop_port=$((${ports_delta} + ${default_tiflash_raft_and_cop_port}))
	local tiflash_status_port=$((${ports_delta} + ${default_tiflash_status_port}))
	local proxy_port=$((${ports_delta} + ${default_proxy_port}))
	local proxy_status_port=$((${ports_delta} + ${default_proxy_status_port}))

	local http_port_occupied=`print_port_occupied "${http_port}"`
	if [ "${http_port_occupied}" == "true" ]; then
		echo "   tiflash http port: ${http_port} is occupied" >&2
		return 1
	fi
	local tcp_port_occupied=`print_port_occupied "${tcp_port}"`
	if [ "${tcp_port_occupied}" == "true" ]; then
		echo "   tiflash tcp port: ${tcp_port} is occupied" >&2
		return 1
	fi
	local interserver_http_port_occupied=`print_port_occupied "${interserver_http_port}"`
	if [ "${interserver_http_port_occupied}" == "true" ]; then
		echo "   tiflash interserver http port: ${interserver_http_port} is occupied" >&2
		return 1
	fi
	local raft_and_cop_port_occupied=`print_port_occupied "${tiflash_raft_and_cop_port}"`
	if [ "${raft_and_cop_port_occupied}" == "true" ]; then
		echo "   tiflash raft and cop port: ${tiflash_raft_and_cop_port} is occupied" >&2
		return 1
	fi
	local tiflash_status_port_occupied=`print_port_occupied "${tiflash_status_port}"`
	if [ "${tiflash_status_port_occupied}" == "true" ]; then
		echo "   tiflash status port: ${tiflash_status_port} is occupied" >&2
		return 1
	fi
	# if running with standalone == false, we need to check proxy's ports are not occupied
	if [ "${standalone}" != "true" ]; then
		local proxy_port_occupied=`print_port_occupied "${proxy_port}"`
		if [ "${proxy_port_occupied}" == "true" ]; then
			echo "   proxy port: ${proxy_port} is occupied" >&2
			return 1
		fi
		local proxy_status_port_occupied=`print_port_occupied "${proxy_status_port}"`
		if [ "${proxy_status_port_occupied}" == "true" ]; then
			echo "   proxy status port: ${proxy_status_port} is occupied" >&2
			return 1
		fi
	fi

	local disk_avail=`df -k "${tiflash_dir}" | tail -n 1 | awk '{print $4}'`
	local max_capacity=$(( 2048 * 1024 * 1024 ))
	if [ ${disk_avail} -gt ${max_capacity} ]; then
		local disk_avail=${max_capacity}
	fi
	local disk_avail=$(( ${disk_avail} * 1024 ))

	local render_str="tiflash_dir=${tiflash_dir}"
	local render_str="${render_str}#tiflash_pd_addr=${pd_addr}"
	local render_str="${render_str}#tiflash_tidb_addr=${tidb_addr}"
	local render_str="${render_str}#tiflash_listen_host=${listen_host}"
	local render_str="${render_str}#tiflash_http_port=${http_port}"
	local render_str="${render_str}#tiflash_tcp_port=${tcp_port}"
	local render_str="${render_str}#tiflash_interserver_http_port=${interserver_http_port}"
	local render_str="${render_str}#tiflash_raft_and_cop_port=${tiflash_raft_and_cop_port}"
	local render_str="${render_str}#tiflash_status_port=${tiflash_status_port}"
	local render_str="${render_str}#proxy_port=${proxy_port}"
	local render_str="${render_str}#proxy_status_port=${proxy_status_port}"
	local render_str="${render_str}#disk_avail=${disk_avail}"

	if [ "${standalone}" != "true" ]; then
		render_templ "${tiflash_config_template}" "${conf_file}" "${render_str}"
		render_templ "${conf_templ_dir}/tiflash/proxy.toml" "${proxy_conf_file}" "${render_str}"
	else
		render_templ "${tiflash_config_template}" "${conf_file}" "${render_str}"
	fi
	local here="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`"
	python "${here}/replace_storage_engine.py" "${conf_file}" "${storage_engine}"
	cp_when_diff "${conf_templ_dir}/tiflash/users.toml" "${tiflash_dir}/conf/users.toml"

	# TODO: remove hard code file name from this func
	local tiflash_binary_dir="${tiflash_dir}/tiflash/"
	# it's hard to judge whether need to unpack tar.gz file, so always unpack it here.
	rm -rf "${tiflash_binary_dir}"
	local bin_tar_name="tiflash.tar.gz"
	if [ ! -f "${tiflash_dir}/${bin_tar_name}" ]; then
		echo "   cannot find tiflash.tar.gz at path ${tiflash_dir}/${bin_tar_name}"
		return 1
	fi
	tar -zxf "${tiflash_dir}/${bin_tar_name}" -C "${tiflash_dir}" 1>/dev/null

	if [ "${daemon_mode}" == "false" ]; then
		if [ `uname` == "Darwin" ]; then
			install_proxy_lib_on_mac "${tiflash_binary_dir}"
		else
			export LD_LIBRARY_PATH="`get_tiflash_lib_path_for_linux ${tiflash_binary_dir}`"
		fi
		"${tiflash_binary_dir}/tiflash" server --config-file "${conf_file}"
		return ${?}
	fi

	local info="${tiflash_dir}/proc.info"
	echo "listen_host	${listen_host}" > "${info}"
	echo "interserver_http_port	${interserver_http_port}" >> "${info}"
	echo "raft_and_cop_port	${tiflash_raft_and_cop_port}" >> "${info}"
	echo "http_port	${http_port}" >> "${info}"
	echo "tcp_port	${tcp_port}" >> "${info}"
	echo "proxy_port	${proxy_port}" >> "${info}"
	echo "pd_addr	${pd_addr}" >> "${info}"
	echo "cluster_id	${cluster_id}" >> "${info}"
	echo "standalone	${standalone}" >> "${info}"
	echo "storage_engine	${storage_engine}" >> "${info}"

	if [ ! -f "${tiflash_dir}/extra_str_to_find_proc" ]; then
		echo "config-file" > "${tiflash_dir}/extra_str_to_find_proc"
	fi

	rm -f "${tiflash_dir}/run.sh"
	if [ `uname` == "Darwin" ]; then
		install_proxy_lib_on_mac "${tiflash_binary_dir}"
	else 
		local lib_path="`get_tiflash_lib_path_for_linux ${tiflash_binary_dir}`"
		if [ -z "${LD_LIBRARY_PATH+x}" ]; then
			echo "export LD_LIBRARY_PATH=\"$lib_path\"" >> "${tiflash_dir}/run.sh"
		else
			echo "export LD_LIBRARY_PATH=\"$LD_LIBRARY_PATH:$lib_path\"" >> "${tiflash_dir}/run.sh"
		fi
	fi
	echo "nohup \"${tiflash_binary_dir}/tiflash\" server --config-file \"${conf_file}\" 1>/dev/null 2>&1 &" >> "${tiflash_dir}/run.sh"

	chmod +x "${tiflash_dir}/run.sh"
	bash "${tiflash_dir}/run.sh"

	sleep 0.3
	local pid=`must_print_pid "${conf_file}" "\-\-config" 2>/dev/null`
	if [ -z "${pid}" ]; then
		echo "   pid not found, failed" >&2
		return 1
	fi

	echo "pid	${pid}" >> "${info}"
	echo "   ${pid}"
}
export -f tiflash_run
