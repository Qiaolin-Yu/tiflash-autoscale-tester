#!/bin/bash

function prometheus_run()
{
	if [ -z "${2+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func prometheus_run] usage: <func> prometheus_dir conf_templ_dir [pd_status_addr] [tikv_status_addr] [tidb_status_addr] [tiflash_status_addr] [node_exporter_addr] [ports_delta] [listen_host] [cluster_id]" >&2
		return 1
	fi

	local prometheus_dir="${1}"
	local prometheus_dir=`abs_path "${prometheus_dir}"`

	local conf_templ_dir="${2}"

	if [ -z "${3+x}" ]; then
		local pd_status_addr=""
	else
		local pd_status_addr="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local tikv_status_addr=""
	else
		local tikv_status_addr="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local tidb_status_addr=""
	else
		local tidb_status_addr="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local tiflash_status_addr="0"
	else
		local tiflash_status_addr="${6}"
	fi

	if [ -z "${7+x}" ]; then
		local node_exporter_addr="0"
	else
		local node_exporter_addr="${7}"
	fi

	if [ -z "${8+x}" ]; then
		local ports_delta="0"
	else
		local ports_delta="${8}"
	fi

	if [ -z "${9+x}" ]; then
		local listen_host=""
	else
		local listen_host="${9}"
	fi

	if [ -z "${10+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${10}"
	fi

	local prometheus_config_template="${conf_templ_dir}/prometheus/prometheus.yml"

	echo "=> run prometheus: ${prometheus_dir}"

	if [ `uname` == "Darwin" ]; then
		echo "Prometheus is not supported on mac" >&2
		exit 1
	fi

	local default_ports="${conf_templ_dir}/default.ports"

	local default_pd_status_port=`get_value "${default_ports}" 'pd_port'`
	if [ -z "${default_pd_status_port}" ]; then
		echo "   get default pd_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tikv_status_port=`get_value "${default_ports}" 'tikv_status_port'`
	if [ -z "${default_tikv_status_port}" ]; then
		echo "   get default tikv_status_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tidb_status_port=`get_value "${default_ports}" 'tidb_status_port'`
	if [ -z "${default_tidb_status_port}" ]; then
		echo "   get default tidb_status_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_tiflash_status_port=`get_value "${default_ports}" 'tiflash_status_port'`
	if [ -z "${default_tiflash_status_port}" ]; then
		echo "   get default tiflash_status_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_proxy_status_port=`get_value "${default_ports}" 'proxy_status_port'`
	if [ -z "${default_proxy_status_port}" ]; then
		echo "   get default proxy_status_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_node_exporter_port=`get_value "${default_ports}" 'node_exporter_port'`
	if [ -z "${default_node_exporter_port}" ]; then
		echo "   get default node_exporter_port from ${default_ports} failed" >&2
		return 1
	fi
	local default_prometheus_port=`get_value "${default_ports}" 'prometheus_port'`
	if [ -z "${default_prometheus_port}" ]; then
		echo "   get default prometheus_port from ${default_ports} failed" >&2
		return 1
	fi

	local pd_status_addr=$(cal_addr "${pd_status_addr}" `must_print_ip` "${default_pd_status_port}")
	local tikv_status_addr=$(cal_addr "${tikv_status_addr}" `must_print_ip` "${default_tikv_status_port}")
	local tidb_status_addr=$(cal_addr "${tidb_status_addr}" `must_print_ip` "${default_tidb_status_port}")
	local tiflash_proxy_status_addr=$(cal_addr "${tiflash_status_addr}" `must_print_ip` "${default_proxy_status_port}")
	local tiflash_status_addr=$(cal_addr "${tiflash_status_addr}" `must_print_ip` "${default_tiflash_status_port}")
	local node_exporter_addr=$(cal_addr "${node_exporter_addr}" `must_print_ip` "${default_node_exporter_port}")

	if [ -z "${listen_host}" ]; then
		local listen_host="`must_print_ip`"
	fi

	mkdir -p "${prometheus_dir}"

	if [ ! -d "${prometheus_dir}" ]; then
		echo "   ${prometheus_dir} is not a dir" >&2
		return 1
	fi

	local conf_file="${prometheus_dir}/conf/prometheus.yml"

	local proc_cnt=`print_proc_cnt "${conf_file}"`
	if [ "${proc_cnt}" != "0" ]; then
		echo "   running(${proc_cnt}), skipped"
		return 0
	fi

	local service_port=$((${ports_delta} + ${default_prometheus_port}))

	local service_port_occupied=`print_port_occupied "${service_port}"`
	if [ "${service_port_occupied}" == "true" ]; then
		echo "   prometheus service port: ${service_port} is occupied" >&2
		return 1
	fi

	local prometheus_config_template="${conf_templ_dir}/prometheus/prometheus.yml"
	local render_str="cluster_name=${service_port}"
	render_templ "${prometheus_config_template}" "${conf_file}" "${render_str}"

	local here="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`"
	python "${here}/process_prometheus_config.py" "${conf_file}" ${pd_status_addr} ${tikv_status_addr} ${tidb_status_addr} ${tiflash_status_addr} ${tiflash_proxy_status_addr} ${node_exporter_addr}

	cp_when_diff "${conf_templ_dir}/prometheus/node.rules.yml" "${prometheus_dir}/conf/node.rules.yml"
	cp_when_diff "${conf_templ_dir}/prometheus/bypass.rules.yml" "${prometheus_dir}/conf/bypass.rules.yml"
	cp_when_diff "${conf_templ_dir}/prometheus/pd.rules.yml" "${prometheus_dir}/conf/pd.rules.yml"
	cp_when_diff "${conf_templ_dir}/prometheus/tidb.rules.yml" "${prometheus_dir}/conf/tidb.rules.yml"
	cp_when_diff "${conf_templ_dir}/prometheus/tikv.rules.yml" "${prometheus_dir}/conf/tikv.rules.yml"
	cp_when_diff "${conf_templ_dir}/prometheus/tikv.accelerate.rules.yml" "${prometheus_dir}/conf/tikv.accelerate.rules.yml"
	cp_when_diff "${conf_templ_dir}/prometheus/tiflash.rules.yml" "${prometheus_dir}/conf/tiflash.rules.yml"

	local info="${prometheus_dir}/proc.info"
	echo "listen_host	${listen_host}" > "${info}"
	echo "service_port	${service_port}" >> "${info}"

	if [ ! -f "${prometheus_dir}/extra_str_to_find_proc" ]; then
		echo "web.listen-address" > "${prometheus_dir}/extra_str_to_find_proc"
	fi
	rm -f "${prometheus_dir}/run.sh"

	echo "nohup \"${prometheus_dir}/prometheus\" --config.file \"${conf_file}\" \\" > "${prometheus_dir}/run.sh"
	echo " --web.listen-address=\":${service_port}\" \\" >> "${prometheus_dir}/run.sh"
	echo " --web.external-url=\"http://${listen_host}:${service_port}\" \\" >> "${prometheus_dir}/run.sh"
	echo " --web.enable-admin-api --log.level=\"info\" \\" >> "${prometheus_dir}/run.sh"
	echo " --storage.tsdb.path="${prometheus_dir}" \\" >> "${prometheus_dir}/run.sh"
	echo " --storage.tsdb.retention=\"30d\" 1>/dev/null 2>&1 &" >> "${prometheus_dir}/run.sh"

	chmod +x "${prometheus_dir}/run.sh"
	bash "${prometheus_dir}/run.sh"

	sleep 0.3
	local pid=`must_print_pid "${conf_file}" 2>/dev/null`
	if [ -z "${pid}" ]; then
		echo "   pid not found, failed" >&2
		return 1
	fi

	echo "pid	${pid}" >> "${info}"
	echo "   ${pid}"
}
export -f prometheus_run
