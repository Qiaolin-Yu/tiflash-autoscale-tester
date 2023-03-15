#!/bin/bash

function spark_worker_run()
{
	if [ -z "${6+x}" ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ] || [ -z "${6}" ]; then
		echo "[func spark_worker_run] usage: <func> spark_worker_dir conf_templ_dir pd_addr tiflash_addr spark_master_addr is_chspark [ports_delta] [advertise_host] [cores] [memory] [cluster_id]" >&2
		return 1
	fi

	local spark_worker_dir="${1}"
	local conf_templ_dir="${2}"
	local pd_addr="${3}"
	local tiflash_addr="${4}"
	local spark_master_addr="${5}"
	local is_chspark="${6}"

	shift 6

	local spark_worker_dir=`abs_path "${spark_worker_dir}"`

	if [ -z "${1+x}" ]; then
		local ports_delta="0"
	else
		local ports_delta="${1}"
	fi

	if [ -z "${2+x}" ]; then
		local advertise_host=""
	else
		local advertise_host="${2}"
	fi

	if [ -z "${3+x}" ]; then
		local worker_cores=""
	else
		local worker_cores="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local worker_memory=""
	else
		local worker_memory="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${5}"
	fi

	if [ "${is_chspark}" == "true" ]; then
		echo "=> run chspark_w: ${spark_worker_dir}"
	else
		echo "=> run spark_w: ${spark_worker_dir}"
	fi

	prepare_spark_env
	local java8_installed=`print_java_installed`
	if [ "${java8_installed}" == "false" ]; then
		echo "   java8 not installed" >&2
		return 1
	fi

	local default_ports="${conf_templ_dir}/default.ports"

	if [ "${is_chspark}" == "true" ]; then
		local default_spark_master_port=`get_value "${default_ports}" 'spark_master_port_ch'`
	else
		local default_spark_master_port=`get_value "${default_ports}" 'spark_master_port'`
	fi
	if [ -z "${default_spark_master_port}" ]; then
		echo "   get default spark_master_port from ${default_ports} failed" >&2
		return 1
	fi

	if [ "${is_chspark}" == "true" ]; then
		local default_spark_worker_webui_port=`get_value "${default_ports}" 'spark_worker_webui_port_ch'`
	else
		local default_spark_worker_webui_port=`get_value "${default_ports}" 'spark_worker_webui_port'`
	fi
	if [ -z "${default_spark_worker_webui_port}" ]; then
		echo "   get default spark_worker_webui_port from ${default_ports} failed" >&2
		return 1
	fi

	if [ "${is_chspark}" == "true" ]; then
		local default_jmxremote_port=`get_value "${default_ports}" 'jmxremote_port_ch'`
	else
		local default_jmxremote_port=`get_value "${default_ports}" 'jmxremote_port'`
	fi
	if [ -z "${default_jmxremote_port}" ]; then
		echo "   get default jmxremote_port from ${default_ports} failed" >&2
		return 1
	fi

	if [ "${is_chspark}" == "true" ]; then
		local default_jdwp_port=`get_value "${default_ports}" 'jdwp_port_ch'`
	else
		local default_jdwp_port=`get_value "${default_ports}" 'jdwp_port'`
	fi
	if [ -z "${default_jdwp_port}" ]; then
		echo "   get default jdwp_port from ${default_ports} failed" >&2
		return 1
	fi

	local default_pd_port=`get_value "${default_ports}" 'pd_port'`
	if [ -z "${default_pd_port}" ]; then
		echo "   get default pd_port from ${default_ports} failed" >&2
		return 1
	fi

	local default_tiflash_tcp_port=`get_value "${default_ports}" 'tiflash_tcp_port'`
	if [ -z "${default_tiflash_tcp_port}" ]; then
		echo "   get default tiflash_tcp_port from ${default_ports} failed" >&2
		return 1
	fi

	local listen_host=""
	if [ "${advertise_host}" != "localhost" ] && [ "${advertise_host}" != "" ]; then
		local listen_host="${advertise_host}"
	else
		local listen_host="`must_print_ip`"
	fi

	local str_for_finding_spark_worker="${spark_worker_dir}/spark/jars/"
	local proc_cnt=`print_proc_cnt "${str_for_finding_spark_worker}" "org.apache.spark.deploy.worker.Worker"`
	if [ "${proc_cnt}" != "0" ]; then
		echo "   running(${proc_cnt}), skipped"
		return 0
	fi

	local spark_worker_webui_port=$((${ports_delta} + ${default_spark_worker_webui_port}))
	# TODO: jmxremote_port and jdwp_port not used in spark worker, remove them
	local jmxremote_port=$((${ports_delta} + ${default_jmxremote_port}))
	local jdwp_port=$((${ports_delta} + ${default_jdwp_port}))
	local worker_webui_port_occupied=`print_port_occupied "${spark_worker_webui_port}"`
	if [ "${worker_webui_port_occupied}" == "true" ]; then
		echo "   spark worker webui port: ${spark_worker_webui_port} is occupied" >&2
		return 1
	fi

	local pd_addr=$(cal_addr "${pd_addr}" `must_print_ip` "${default_pd_port}")
	local tiflash_addr=$(cal_addr "${tiflash_addr}" `must_print_ip` "${default_tiflash_tcp_port}")
	local spark_master_addr=$(cal_addr "${spark_master_addr}" `must_print_ip` "${default_spark_master_port}")

	local error_handle="$-"
	set +eu
	if [ ! -z "${JAVA_HOME}" ]; then
		local java_home="${JAVA_HOME}"
	else
		local java_home=""
	fi
	restore_error_handle_flags "${error_handle}"
	
	spark_file_prepare "${spark_worker_dir}" "${conf_templ_dir}" "${pd_addr}" "${tiflash_addr}" "${jmxremote_port}" "${jdwp_port}" "${is_chspark}"

	local info="${spark_worker_dir}/proc.info"
	echo "listen_host	${listen_host}" > "${info}"
	echo "spark_worker_webui_port	${spark_worker_webui_port}" >> "${info}"
	echo "cluster_id	${cluster_id}" >> "${info}"

	local run_worker_cmd="${spark_worker_dir}/spark/sbin/start-slave.sh ${spark_master_addr} --host ${listen_host}"
	if [ "${worker_cores}" != "" ]; then
		local run_worker_cmd="${run_worker_cmd} --cores ${worker_cores}"
	fi
	if [ "${worker_memory}" != "" ]; then
		local run_worker_cmd="${run_worker_cmd} --memory ${worker_memory}"
	fi

	echo "export SPARK_WORKER_WEBUI_PORT=${spark_worker_webui_port}" > "${spark_worker_dir}/run_worker_temp.sh"
	if [ ! -z "${java_home}" ]; then
		echo "export JAVA_HOME=\"${java_home}\"" >> "${spark_worker_dir}/run_worker_temp.sh"
		if [ -z "${PATH+x}" ]; then
			echo "export PATH=\"${JAVA_HOME}/bin\"" >> "${spark_worker_dir}/run_master_temp.sh"
		else
			echo "export PATH=\"${JAVA_HOME}/bin:${PATH}\"" >> "${spark_worker_dir}/run_master_temp.sh"
		fi
	fi

	echo "${run_worker_cmd}" >> "${spark_worker_dir}/run_worker_temp.sh"
	chmod +x "${spark_worker_dir}/run_worker_temp.sh"
	mv "${spark_worker_dir}/run_worker_temp.sh" "${spark_worker_dir}/run_worker.sh"

	mkdir -p "${spark_worker_dir}/logs"
	bash "${spark_worker_dir}/run_worker.sh" 2>&1 1>/dev/null

	if [ ! -f "${spark_worker_dir}/extra_str_to_find_proc" ]; then
		echo "org.apache.spark.deploy.worker.Worker" > "${spark_worker_dir}/extra_str_to_find_proc"
	fi

	local spark_worker_log_name=`ls -tr "${spark_worker_dir}/spark/logs" | { grep "org.apache.spark.deploy.worker.Worker" || test $? = 1; } | tail -n 1`
	if [ -z "${spark_worker_log_name}" ]; then
		echo "   spark worker logs not found, failed" >&2
		return 1
	fi

	mkdir -p "${spark_worker_dir}/logs"
	if [ ! -f "${spark_worker_dir}/logs/spark_worker.log" ]; then
		ln "${spark_worker_dir}/spark/logs/${spark_worker_log_name}" "${spark_worker_dir}/logs/spark_worker.log"
	fi

	sleep 0.3
	local pid=`must_print_pid "${str_for_finding_spark_worker}" "org.apache.spark.deploy.worker.Worker" 2>/dev/null`
	if [ -z "${pid}" ]; then
		echo "   pid not found, failed" >&2
		return 1
	fi
	echo "pid	${pid}" >> "${info}"
	echo "   ${pid}"
}
export -f spark_worker_run
