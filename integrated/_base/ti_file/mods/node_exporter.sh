#!/bin/bash

function node_exporter_run()
{
	if [ -z "${1+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func node_exporter_run] usage: <func> node_exporter_dir conf_templ_dir [ports_delta] [listen_host] [cluster_id]" >&2
		return 1
	fi

	local node_exporter_dir="${1}"
	local node_exporter_dir=`abs_path "${node_exporter_dir}"`

	local conf_templ_dir="${2}"

	if [ -z "${3+x}" ]; then
		local ports_delta="0"
	else
		local ports_delta="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local listen_host=""
	else
		local listen_host="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${5}"
	fi

	echo "=> run node_exporter: ${node_exporter_dir}"

	if [ `uname` == "Darwin" ]; then
		echo "Node_exporter is not supported on mac" >&2
		exit 1
	fi

	local default_ports="${conf_templ_dir}/default.ports"

	local default_node_exporter_port=`get_value "${default_ports}" 'node_exporter_port'`
	if [ -z "${default_node_exporter_port}" ]; then
		echo "   get default node_exporter_port from ${default_ports} failed" >&2
		return 1
	fi


	if [ -z "${listen_host}" ]; then
		local listen_host="`must_print_ip`"
	fi

	mkdir -p "${node_exporter_dir}"

	if [ ! -d "${node_exporter_dir}" ]; then
		echo "   ${node_exporter_dir} is not a dir" >&2
		return 1
	fi

	local process_hint="${node_exporter_dir}"

	local proc_cnt=`print_proc_cnt "${process_hint}" "\-\-web.listen\-address"`
	if [ "${proc_cnt}" != "0" ]; then
		echo "   running(${proc_cnt}), skipped"
		return 0
	fi

	local node_exporter_port=$((${ports_delta} + ${default_node_exporter_port}))

	local node_exporter_port_occupied=`print_port_occupied "${node_exporter_port}"`
	if [ "${node_exporter_port_occupied}" == "true" ]; then
		echo "   node_exporter service port: ${node_exporter_port} is occupied" >&2
		return 1
	fi

	local info="${node_exporter_dir}/proc.info"
	echo "listen_host	${listen_host}" > "${info}"
	echo "node_exporter_port	${node_exporter_port}" >> "${info}"

	if [ ! -f "${node_exporter_dir}/extra_str_to_find_proc" ]; then
		echo "web.listen-address" > "${node_exporter_dir}/extra_str_to_find_proc"
	fi
	rm -f "${node_exporter_port}/run.sh"

	echo "nohup \"${node_exporter_dir}/node_exporter\" \\" > "${node_exporter_dir}/run.sh"
	echo " --web.listen-address=\":${node_exporter_port}\" \\" >> "${node_exporter_dir}/run.sh"
	echo " --collector.tcpstat \\" >> "${node_exporter_dir}/run.sh"
	echo " --collector.systemd \\" >> "${node_exporter_dir}/run.sh"
	echo " --collector.mountstats \\" >> "${node_exporter_dir}/run.sh"
	echo " --collector.meminfo_numa \\" >> "${node_exporter_dir}/run.sh"
	echo " --collector.interrupts \\" >> "${node_exporter_dir}/run.sh"
	echo " --collector.vmstat.fields=\"^.*\" \\" >> "${node_exporter_dir}/run.sh"
	echo " --log.level=\"info\" 1>/dev/null 2>&1 &" >> "${node_exporter_dir}/run.sh"

	chmod +x "${node_exporter_dir}/run.sh"
	bash "${node_exporter_dir}/run.sh"

	sleep 0.3
	local pid=`must_print_pid "${node_exporter_dir}" "\-\-web.listen\-address" 2>/dev/null`
	if [ -z "${pid}" ]; then
		echo "   pid not found, failed" >&2
		return 1
	fi

	echo "pid	${pid}" >> "${info}"
	echo "   ${pid}"
}
export -f node_exporter_run
