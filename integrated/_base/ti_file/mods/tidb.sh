#!/bin/bash

function tidb_run()
{
	if [ -z "${3+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func tidb_run] usage: <func> tidb_dir conf_templ_dir pd_addr [advertise_host] [ports_delta] [cluster_id]" >&2
		return 1
	fi

	local tidb_dir="${1}"
	local tidb_dir=`abs_path "${tidb_dir}"`

	local conf_templ_dir="${2}"
	local pd_addr="${3}"

	if [ -z "${4+x}" ]; then
		local advertise_host=""
	else
		local advertise_host="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local ports_delta="0"
	else
		local ports_delta="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${6}"
	fi

	echo "=> run tidb: ${tidb_dir}"

	local default_ports="${conf_templ_dir}/default.ports"

	local default_pd_port=`get_value "${default_ports}" 'pd_port'`
	if [ -z "${default_pd_port}" ]; then
		echo "   get default pd_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tidb_port=`get_value "${default_ports}" 'tidb_port'`
	if [ -z "${default_tidb_port}" ]; then
		echo "   get default tidb_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tidb_status_port=`get_value "${default_ports}" 'tidb_status_port'`
	if [ -z "${default_tidb_status_port}" ]; then
		echo "   get default tidb_status_port from ${default_ports} failed" >&2
		return 1
	fi

	local pd_addr=$(cal_addr "${pd_addr}" `must_print_ip` "${default_pd_port}")

	if [ -z "${advertise_host}" ]; then
		local advertise_host="`must_print_ip`"
	fi

	local proc_cnt=`print_proc_cnt "${tidb_dir}/tidb.toml" "\-\-config"`
	if [ "${proc_cnt}" != "0" ]; then
		echo "   running(${proc_cnt}), skipped"
		return 0
	fi

	local tidb_port=$((${ports_delta} + ${default_tidb_port}))
	local status_port=$((${ports_delta} + ${default_tidb_status_port}))
	local tidb_port_occupied=`print_port_occupied "${tidb_port}"`
	if [ "${tidb_port_occupied}" == "true" ]; then
		echo "   tidb port: ${tidb_port} is occupied" >&2
		return 1
	fi
	local status_port_occupied=`print_port_occupied "${status_port}"`
	if [ "${status_port_occupied}" == "true" ]; then
		echo "   tidb status port: ${status_port} is occupied" >&2
		return 1
	fi

	local listen_host=""
	if [ "${advertise_host}" != "127.0.0.1" ] || [ "${advertise_host}" != "localhost" ]; then
		local listen_host="${advertise_host}"
	else
		local listen_host="`must_print_ip`"
	fi

	local render_str="tidb_listen_host=${listen_host}"
	render_templ "${conf_templ_dir}/tidb.toml" "${tidb_dir}/tidb.toml" "${render_str}"

	local info="${tidb_dir}/proc.info"
	echo "advertise_host	${advertise_host}" > "${info}"
	echo "tidb_port	${tidb_port}" >> "${info}"
	echo "status_port	${status_port}" >> "${info}"
	echo "pd_addr	${pd_addr}" >> "${info}"
	echo "cluster_id	${cluster_id}" >> "${info}"

	# Enable http api for triggling TiDB's failpoints
	echo "export GO_FAILPOINTS=\"github.com/pingcap/tidb/server/enableTestAPI=return\"" > "${tidb_dir}/run.sh"
	echo "nohup \"${tidb_dir}/tidb-server\" \\" >> "${tidb_dir}/run.sh"
	echo "	-P \"${tidb_port}\" \\" >> "${tidb_dir}/run.sh"
	echo "	--status=\"${status_port}\" \\" >> "${tidb_dir}/run.sh"
	echo "	--advertise-address=\"${advertise_host}\" \\" >> "${tidb_dir}/run.sh"
	echo "	--path=\"${pd_addr}\" \\" >> "${tidb_dir}/run.sh"
	echo "	--config=\"${tidb_dir}/tidb.toml\" \\" >> "${tidb_dir}/run.sh"
	echo "	--log-slow-query=\"${tidb_dir}/tidb_slow.log\" \\" >> "${tidb_dir}/run.sh"
	echo "	--log-file=\"${tidb_dir}/tidb.log\" \\" >> "${tidb_dir}/run.sh"
	echo "	2>> \"${tidb_dir}/tidb_stderr.log\" 1>&2 &" >> "${tidb_dir}/run.sh"

	chmod +x "${tidb_dir}/run.sh"
	bash "${tidb_dir}/run.sh"

	sleep 0.3
	local pid=`must_print_pid "${tidb_dir}/tidb.toml" "\-\-config" 2>/dev/null`
	if [ -z "${pid}" ]; then
		echo "   pid not found, failed" >&2
		return 1
	fi
	echo "pid	${pid}" >> "${info}"
	echo "   ${pid}"
}
export -f tidb_run
