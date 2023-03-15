#!/bin/bash

function spark_master_run()
{
	if [ -z "${5+x}" ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]; then
		echo "[func spark_master_run] usage: <func> spark_master_dir conf_templ_dir pd_addr tiflash_addr is_chspark [ports_delta] [advertise_host] [executor_memory] [cluster_id]" >&2
		return 1
	fi

	local spark_master_dir="${1}"
	local conf_templ_dir="${2}"
	local pd_addr="${3}"
	local tiflash_addr="${4}"
	local is_chspark="${5}"

	shift 5

	local spark_master_dir=`abs_path "${spark_master_dir}"`

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
		local executor_memory=""
	else
		local executor_memory="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${4}"
	fi

	if [ "${is_chspark}" == "true" ]; then
		echo "=> run chspark_m: ${spark_master_dir}"
	else
		echo "=> run spark_m: ${spark_master_dir}"
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
		local default_thriftserver_port=`get_value "${default_ports}" 'thriftserver_port_ch'`
	else
		local default_thriftserver_port=`get_value "${default_ports}" 'thriftserver_port'`
	fi
	if [ -z "${default_thriftserver_port}" ]; then
		echo "   get default thriftserver_port from ${default_ports} failed" >&2
		return 1
	fi

	if [ "${is_chspark}" == "true" ]; then
		local default_spark_master_webui_port=`get_value "${default_ports}" 'spark_master_webui_port_ch'`
	else
		local default_spark_master_webui_port=`get_value "${default_ports}" 'spark_master_webui_port'`
	fi
	if [ -z "${default_spark_master_webui_port}" ]; then
		echo "   get default spark_master_webui_port from ${default_ports} failed" >&2
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

	local str_for_finding_spark_master="${spark_master_dir}/spark/jars/"

	local proc_cnt=`print_proc_cnt "${str_for_finding_spark_master}" "org.apache.spark.deploy.master.Master"`

	if [ "${proc_cnt}" != "0" ]; then
		echo "   running(${proc_cnt}), skipped"
		return 0
	fi

	local pd_addr=$(cal_addr "${pd_addr}" `must_print_ip` "${default_pd_port}")
	local tiflash_addr=$(cal_addr "${tiflash_addr}" `must_print_ip` "${default_tiflash_tcp_port}")

	local spark_master_port=$((${ports_delta} + ${default_spark_master_port}))
	local thriftserver_port=$((${ports_delta} + ${default_thriftserver_port}))
	local spark_master_webui_port=$((${ports_delta} + ${default_spark_master_webui_port}))
	local jmxremote_port=$((${ports_delta} + ${default_jmxremote_port}))
	local jdwp_port=$((${ports_delta} + ${default_jdwp_port}))
	local spark_master_port_occupied=`print_port_occupied "${spark_master_port}"`
	if [ "${spark_master_port_occupied}" == "true" ]; then
		echo "   spark master port: ${spark_master_port} is occupied" >&2
		return 1
	fi
	local thriftserver_port_occupied=`print_port_occupied "${thriftserver_port}"`
	if [ "${thriftserver_port_occupied}" == "true" ]; then
		echo "   thrift server port: ${thriftserver_port} is occupied" >&2
		return 1
	fi
	local master_webui_port_occupied=`print_port_occupied "${spark_master_webui_port}"`
	if [ "${master_webui_port_occupied}" == "true" ]; then
		echo "   spark master webui port: ${spark_master_webui_port} is occupied" >&2
		return 1
	fi
	local jmxremote_port_occupied=`print_port_occupied "${jmxremote_port}"`
	if [ "${jmxremote_port_occupied}" == "true" ]; then
		echo "   jmxremote port: ${jmxremote_port} is occupied" >&2
		return 1
	fi
	local jdwp_port_occupied=`print_port_occupied "${jdwp_port}"`
	if [ "${jdwp_port_occupied}" == "true" ]; then
		echo "   jdwp port: ${jdwp_port} is occupied" >&2
		return 1
	fi

	local error_handle="$-"
	set +eu
	if [ ! -z "${JAVA_HOME}" ]; then
		local java_home="${JAVA_HOME}"
	else
		local java_home=""
	fi
	restore_error_handle_flags "${error_handle}"

	spark_file_prepare "${spark_master_dir}" "${conf_templ_dir}" "${pd_addr}" "${tiflash_addr}" "${jmxremote_port}" "${jdwp_port}" "${is_chspark}"

	if [ `uname` == 'Darwin' ]; then
		local bin_urls_file="${conf_templ_dir}/bin.urls.mac"
	else
		local bin_urls_file="${conf_templ_dir}/bin.urls"
	fi
	if [ "${is_chspark}" == "true" ]; then
		local mod_key="chspark"
	else
		local mod_key="tispark"
	fi
	local jar_file=`cat "${bin_urls_file}" | { grep "^${mod_key}\b" || test $? = 1; } | awk '{print $3}'`

	local run_thrift_server_command="${spark_master_dir}/spark/sbin/start-thriftserver.sh"
	local run_thrift_server_command="${run_thrift_server_command} --hiveconf hive.server2.thrift.port=${thriftserver_port}"
	local run_thrift_server_command="${run_thrift_server_command} --hiveconf hive.server2.thrift.bind.host=${listen_host}"
	if [ "${executor_memory}" != "" ]; then
		local run_thrift_server_command="${run_thrift_server_command} --executor-memory ${executor_memory}"	
	fi
	local run_thrift_server_command="${run_thrift_server_command} --jars ${spark_master_dir}/${jar_file}"
	local run_thrift_server_command="${run_thrift_server_command} --master spark://${listen_host}:${spark_master_port}"

	echo "export SPARK_MASTER_HOST=${listen_host}" > "${spark_master_dir}/run_master_temp.sh"
	echo "export SPARK_MASTER_PORT=${spark_master_port}" >> "${spark_master_dir}/run_master_temp.sh"
	echo "export SPARK_MASTER_WEBUI_PORT=${spark_master_webui_port}" >> "${spark_master_dir}/run_master_temp.sh"
	if [ ! -z "${java_home}" ]; then
		echo "export JAVA_HOME=\"${java_home}\"" >> "${spark_master_dir}/run_master_temp.sh"
		if [ -z "${PATH+x}" ]; then
			echo "export PATH=\"${JAVA_HOME}/bin\"" >> "${spark_master_dir}/run_master_temp.sh"
		else
			echo "export PATH=\"${JAVA_HOME}/bin:${PATH}\"" >> "${spark_master_dir}/run_master_temp.sh"
		fi
	fi
	echo "${spark_master_dir}/spark/sbin/start-master.sh" >> "${spark_master_dir}/run_master_temp.sh"
	echo "(" >> "${spark_master_dir}/run_master_temp.sh"
	echo "  cd ${spark_master_dir}" >> "${spark_master_dir}/run_master_temp.sh"
	echo "  ${run_thrift_server_command}" >> "${spark_master_dir}/run_master_temp.sh"
	echo ")" >> "${spark_master_dir}/run_master_temp.sh"
	echo "wait" >> "${spark_master_dir}/run_master_temp.sh"
	# TODO: remove this sleep
	echo "sleep 5" >> "${spark_master_dir}/run_master_temp.sh"
	chmod +x "${spark_master_dir}/run_master_temp.sh"
	mv "${spark_master_dir}/run_master_temp.sh" "${spark_master_dir}/run_master.sh"
	
	bash "${spark_master_dir}/run_master.sh" 2>&1 1>/dev/null

	local info="${spark_master_dir}/proc.info"
	echo "thriftserver_port	${thriftserver_port}" > "${info}"
	echo "listen_host	${listen_host}" >> "${info}"
	echo "spark_master_port	${spark_master_port}" >> "${info}"
	echo "pd_addr	${pd_addr}" >> "${info}"
	echo "tiflash_addr	${tiflash_addr}" >> "${info}"
	echo "spark_master_webui_port	${spark_master_webui_port}" >> "${info}"
	echo "jmxremote_port	${jmxremote_port}" >> "${info}"
	echo "jdwp_port	${jdwp_port}" >> "${info}"
	echo "cluster_id	${cluster_id}" >> "${info}"

	if [ ! -f "${spark_master_dir}/extra_str_to_find_proc" ]; then
		echo "org.apache.spark.deploy.master.Master" > "${spark_master_dir}/extra_str_to_find_proc"
	fi

	local spark_master_log_name=`ls -tr "${spark_master_dir}/spark/logs" | { grep "org.apache.spark.deploy.master.Master" || test $? = 1; } | tail -n 1`
	if [ -z "${spark_master_log_name}" ]; then
		echo "   spark master logs not found, failed" >&2
		return 1
	fi
	mkdir -p "${spark_master_dir}/logs"
	if [ ! -f "${spark_master_dir}/logs/spark_master.log" ]; then
		ln "${spark_master_dir}/spark/logs/${spark_master_log_name}" "${spark_master_dir}/logs/spark_master.log"
	fi

	sleep 0.3
	local pid=`must_print_pid "${str_for_finding_spark_master}" "org.apache.spark.deploy.master.Master" 2>/dev/null`
	if [ -z "${pid}" ]; then
		echo "   pid not found, failed" >&2
		return 1
	fi
	echo "pid	${pid}" >> "${info}"
	echo "   ${pid}"
}
export -f spark_master_run
