#!/bin/bash

function tikv_importer_run()
{
	if [ -z "${2+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func tikv_importer_run] usage: <func> importer_dir conf_templ_dir [ports_delta] [listen_host] [cluster_id]" >&2
		return 1
	fi

	local importer_dir="${1}"
	local importer_dir=`abs_path "${importer_dir}"`

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

	echo "=> run tikv_importer: ${importer_dir}"

	local default_ports="${conf_templ_dir}/default.ports"

	local default_importer_port=`get_value "${default_ports}" 'tikv_importer_port'`
	if [ -z "${default_importer_port}" ]; then
		echo "   get default tikv_importer_port from ${default_ports} failed" >&2
		return 1
	fi

	if [ -z "${listen_host}" ]; then
		local listen_host="`must_print_ip`"
	fi

	mkdir -p "${importer_dir}"

	if [ ! -d "${importer_dir}" ]; then
		echo "   ${importer_dir} is not a dir" >&2
		return 1
	fi

	local conf_file="${importer_dir}/tikv-importer.toml"

	local proc_cnt=`print_proc_cnt "${conf_file}" "\-\-config"`
	if [ "${proc_cnt}" != "0" ]; then
		echo "   running(${proc_cnt}), skipped"
		return 0
	fi

	local listen_port=$((${ports_delta} + ${default_importer_port}))
	local listen_port_occupied=`print_port_occupied "${listen_port}"`
	if [ "${listen_port_occupied}" == "true" ]; then
		echo "   tikv-importer listen port: ${listen_port} is occupied" >&2
		return 1
	fi

	local render_str="importer_listen_host=${listen_host}"
	local render_str="${render_str}#importer_listen_port=${listen_port}"
	local render_str="${render_str}#importer_dir=${importer_dir}"

	render_templ "${conf_templ_dir}/tikv-importer.toml" "${conf_file}" "${render_str}"

	local info="${importer_dir}/proc.info"
	echo "listen_host	${listen_host}" > "${info}"
	echo "listen_port	${listen_port}" >> "${info}"
	echo "cluster_id	${cluster_id}" >> "${info}"

	rm -f "${importer_dir}/run.sh"
	echo "nohup \"${importer_dir}/tikv-importer\" --config \"${conf_file}\" 1>/dev/null 2>&1 &" >> "${importer_dir}/run.sh"

	chmod +x "${importer_dir}/run.sh"
	bash "${importer_dir}/run.sh"

	sleep 0.3
	local pid=`must_print_pid "${conf_file}" "\-\-config" 2>/dev/null`
	if [ -z "${pid}" ]; then
		echo "   pid not found, failed" >&2
		return 1
	fi

	echo "pid	${pid}" >> "${info}"
	echo "   ${pid}"
}
export -f tikv_importer_run
