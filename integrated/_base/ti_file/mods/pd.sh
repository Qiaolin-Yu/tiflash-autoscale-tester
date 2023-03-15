#!/bin/bash

function pd_run()
{
	if [ -z "${2+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func pd_run] usage: <func> pd_dir conf_templ_dir [name_ports_delta] [advertise_host] [pd_name] [initial_cluster] [cluster_id]" >&2
		return 1
	fi

	local pd_dir="${1}"
	local pd_dir=`abs_path "${pd_dir}"`

	local conf_templ_dir="${2}"

	if [ -z "${3+x}" ]; then
		local name_ports_delta="0"
	else
		local name_ports_delta="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local advertise_host=""
	else
		local advertise_host="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local pd_name=""
	else
		local pd_name="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local initial_cluster=""
	else
		local initial_cluster="${6}"
	fi

	if [ -z "${7+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${7}"
	fi

	if [ -z "${advertise_host}" ]; then
		local ip_cnt="`print_ip_cnt`"
		if [ "${ip_cnt}" != "1" ]; then
			local advertise_host="127.0.0.1"
		else
			local advertise_host="`print_ip`"
		fi
	fi

	if [ -z "${pd_name}" ]; then
		local pd_name="pd${name_ports_delta}"
	fi

	local default_ports="${conf_templ_dir}/default.ports"

	echo "=> run pd: ${pd_dir}"

	local default_pd_port=`get_value "${default_ports}" 'pd_port'`
	if [ -z "${default_pd_port}" ]; then
		echo "   get default pd_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_pd_peer_port=`get_value "${default_ports}" 'pd_peer_port'`
	if [ -z "${default_pd_peer_port}" ]; then
		echo "   get default pd_peer_port from ${default_ports} failed" >&2
		return 1
	fi

	local proc_cnt=`print_proc_cnt "${pd_dir}/pd.toml" "\-\-config"`
	if [ "${proc_cnt}" != "0" ]; then
		echo "   running(${proc_cnt}), skipped"
		return 0
	fi

	local pd_port=$((${name_ports_delta} + ${default_pd_port}))
	local peer_port=$((${name_ports_delta} + ${default_pd_peer_port}))
	local pd_port_occupied=`print_port_occupied "${pd_port}"`
	if [ "${pd_port_occupied}" == "true" ]; then
		echo "   pd port: ${pd_port} is occupied" >&2
		return 1
	fi
	local peer_port_occupied=`print_port_occupied "${peer_port}"`
	if [ "${peer_port_occupied}" == "true" ]; then
		echo "   peer port: ${peer_port} is occupied" >&2
		return 1
	fi

	if [ -z "${initial_cluster}" ]; then
		local initial_cluster="${pd_name}=http://${advertise_host}:${peer_port}"
	else
		local initial_cluster=$(cal_addr "${initial_cluster}" "${advertise_host}" "${default_pd_peer_port}" "${pd_name}")
	fi
	
	cp_when_diff "${conf_templ_dir}/pd.toml" "${pd_dir}/pd.toml"

	local info="${pd_dir}/proc.info"
	echo "pd_name	${pd_name}" > "${info}"
	echo "advertise_host	${advertise_host}" >> "${info}"
	echo "pd_port	${pd_port}" >> "${info}"
	echo "peer_port	${peer_port}" >> "${info}"
	echo "initial_cluster	${initial_cluster}" >> "${info}"
	echo "cluster_id	${cluster_id}" >> "${info}"

	echo "nohup \"${pd_dir}/pd-server\" \\" > "${pd_dir}/run.sh"
	echo "	--name=\"${pd_name}\" \\" >> "${pd_dir}/run.sh"
	echo "	--client-urls=\"http://${advertise_host}:${pd_port}\" \\" >> "${pd_dir}/run.sh"
	echo "	--advertise-client-urls=\"http://${advertise_host}:${pd_port}\" \\" >> "${pd_dir}/run.sh"
	echo "	--peer-urls=\"http://${advertise_host}:${peer_port}\" \\" >> "${pd_dir}/run.sh"
	echo "	--advertise-peer-urls=\"http://${advertise_host}:${peer_port}\" \\" >> "${pd_dir}/run.sh"
	echo "	--data-dir=\"${pd_dir}/data\" \\" >> "${pd_dir}/run.sh"
	echo "	--initial-cluster=\"${initial_cluster}\" \\" >> "${pd_dir}/run.sh"
	echo "	--config=\"${pd_dir}/pd.toml\" \\" >> "${pd_dir}/run.sh"
	echo "	--log-file=\"${pd_dir}/pd.log\" \\" >> "${pd_dir}/run.sh"
	echo "	2>> \"${pd_dir}/pd_stderr.log\" 1>&2 &" >> "${pd_dir}/run.sh"

	chmod +x "${pd_dir}/run.sh"
	bash "${pd_dir}/run.sh"

	sleep 0.3
	local pid=`must_print_pid "${pd_dir}/pd.toml" "\-\-config" 2>/dev/null`
	if [ -z "${pid}" ]; then
		echo "   pid not found, failed" >&2
		return 1
	fi
	echo "pid	${pid}" >> "${info}"
	echo "   ${pid}"
}
export -f pd_run
