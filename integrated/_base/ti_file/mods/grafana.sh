#!/bin/bash

function grafana_run()
{
	if [ -z "${1+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func grafana_run] usage: <func> grafana_dir conf_templ_dir [prometheus_addr] [ports_delta] [listen_host] [cluster_id]" >&2
		return 1
	fi

	local grafana_dir="${1}"
	local grafana_dir=`abs_path "${grafana_dir}"`

	local conf_templ_dir="${2}"

	if [ -z "${3+x}" ]; then
		local prometheus_addr=""
	else
		local prometheus_addr="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local ports_delta="0"
	else
		local ports_delta="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local listen_host=""
	else
		local listen_host="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${6}"
	fi

	echo "=> run grafana: ${grafana_dir}"

	if [ `uname` == "Darwin" ]; then
		echo "Grafana is not supported on mac" >&2
		exit 1
	fi

	local default_ports="${conf_templ_dir}/default.ports"

	local default_prometheus_port=`get_value "${default_ports}" 'prometheus_port'`
	if [ -z "${default_prometheus_port}" ]; then
		echo "   get default prometheus_port from ${default_ports} failed" >&2
		return 1
	fi
	local prometheus_port=$((${ports_delta} + ${default_prometheus_port}))

	local default_grafana_port=`get_value "${default_ports}" 'grafana_port'`
	if [ -z "${default_grafana_port}" ]; then
		echo "   get default grafana_port from ${default_ports} failed" >&2
		return 1
	fi

	local prometheus_addr=$(cal_addr "${prometheus_addr}" `must_print_ip` "${default_prometheus_port}")

	if [ -z "${listen_host}" ]; then
		local listen_host="`must_print_ip`"
	fi

	mkdir -p "${grafana_dir}"

	if [ ! -d "${grafana_dir}" ]; then
		echo "   ${grafana_dir} is not a dir" >&2
		return 1
	fi

	local process_hint="${grafana_dir}"

	local conf_file="${grafana_dir}/conf/grafana.ini"

	local proc_cnt=`print_proc_cnt "${conf_file}" "\-\-config"`
	if [ "${proc_cnt}" != "0" ]; then
		echo "   running(${proc_cnt}), skipped"
		return 0
	fi

	local grafana_port=$((${ports_delta} + ${default_grafana_port}))

	local grafana_port_occupied=`print_port_occupied "${grafana_port}"`
	if [ "${grafana_port_occupied}" == "true" ]; then
		echo "   grafana service port: ${grafana_port} is occupied" >&2
		return 1
	fi

	local cluster_name="${prometheus_port}"
	local render_str="grafana_dir=${grafana_dir}"
	local render_str="${render_str}#cluster_name=${cluster_name}"
	local render_str="${render_str}#prometheus_addr=${prometheus_addr}"
	local render_str="${render_str}#grafana_port=${grafana_port}"
	local render_str="${render_str}#grafana_host=${listen_host}"

	render_templ "${conf_templ_dir}/grafana/dashboard.yml" "${grafana_dir}/provisioning/dashboards/dashboard.yml" "${render_str}"
	render_templ "${conf_templ_dir}/grafana/datasource.yml" "${grafana_dir}/provisioning/datasources/datasource.yml" "${render_str}"
	render_templ "${conf_templ_dir}/grafana/grafana.ini" "${conf_file}" "${render_str}"

	local info="${grafana_dir}/proc.info"
	echo "listen_host	${listen_host}" > "${info}"
	echo "grafana_port	${grafana_port}" >> "${info}"

	if [ ! -f "${grafana_dir}/extra_str_to_find_proc" ]; then
		echo "\-\-homepath" > "${grafana_dir}/extra_str_to_find_proc"
	fi

	local grafana_scripts="grafana_scripts"
	if [ ! -d "${grafana_dir}/${grafana_scripts}" ]; then
		local grafana_scripts_name="grafana_scripts.tgz"
		if [ ! -f "${grafana_dir}/${grafana_scripts_name}" ]; then
			echo "   cannot find grafana_scripts file"
			return 1
		fi
		tar -zxf "${grafana_dir}/${grafana_scripts_name}" -C "${grafana_dir}" 1>/dev/null
		rm -f "${grafana_dir}/${grafana_scripts_name}"
	fi

	mkdir -p ${grafana_dir}/plugins
	mkdir -p ${grafana_dir}/dashboards
	mkdir -p ${grafana_dir}/provisioning/dashboards
	mkdir -p ${grafana_dir}/provisioning/datasources

	cp ${grafana_dir}/grafana_scripts/*.json ${grafana_dir}/dashboards/

	find ${grafana_dir}/dashboards/ -type f -exec sed -i "s/\${DS_.*-CLUSTER}/${cluster_name}/g" {} \;
	find ${grafana_dir}/dashboards/ -type f -exec sed -i "s/\${DS_LIGHTNING}/${cluster_name}/g" {} \;
	find ${grafana_dir}/dashboards/ -type f -exec sed -i "s/test-cluster/${cluster_name}/g" {} \;
	find ${grafana_dir}/dashboards/ -type f -exec sed -i "s/Test-Cluster/${cluster_name}/g" {} \;

	echo "LANG=en_US.UTF-8 \\" > "${grafana_dir}/run.sh"
	echo "nohup \"${grafana_dir}/grafana-server\" \\" >> "${grafana_dir}/run.sh"
	echo " --homepath=\"${grafana_dir}/grafana_scripts\" \\" >> "${grafana_dir}/run.sh"
	echo " --config=\"${grafana_dir}/conf/grafana.ini\" 1>/dev/null 2>&1 &" >> "${grafana_dir}/run.sh"

	chmod +x "${grafana_dir}/run.sh"
	bash "${grafana_dir}/run.sh"

	sleep 0.3
	local pid=`must_print_pid "${grafana_dir}" "\-\-homepath" 2>/dev/null`
	if [ -z "${pid}" ]; then
		echo "   pid not found, failed" >&2
		return 1
	fi

	echo "pid	${pid}" >> "${info}"
	echo "   ${pid}"
}
export -f grafana_run
