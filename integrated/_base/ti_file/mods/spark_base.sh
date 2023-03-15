#!/bin/bash

function prepare_spark_env()
{
	local error_handle="$-"
	set +eu
	local conf_file="${integrated}/conf/envs.kv"
	local java_home=`get_value "${conf_file}" "java_home"`
	if [ -z "${JAVA_HOME}" ] && [ ! -z "${java_home}" ]; then
		export JAVA_HOME="${java_home}"
		if [ -z "${PATH+x}" ]; then
			export PATH="${JAVA_HOME}/bin"
		else
			export PATH="${JAVA_HOME}/bin:${PATH}"
		fi
	fi

	restore_error_handle_flags "${error_handle}"
}
export -f prepare_spark_env

function print_java_installed()
{
	local error_handle="$-"
	set +e
	local java8_installed=`java -version 2>&1 | grep "1.8" | wc -l`
	if [ "${java8_installed}" -eq 0 ]; then
		echo "false"
	else
		echo "true"
	fi

	restore_error_handle_flags "${error_handle}"
}
export -f print_java_installed

function spark_file_prepare()
{
	if [ -z "${7+x}" ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ] || [ -z "${6}" ] || [ -z "${7}" ]; then
		echo "[func spark_file_prepare] usage: <func> spark_mod_dir conf_templ_dir pd_addr tiflash_addr jmxremote_port jdwp_port is_chspark" >&2
		return 1
	fi

	local spark_mod_dir="${1}"
	local conf_templ_dir="${2}"
	local pd_addr="${3}"
	local tiflash_addr="${4}"
	local jmxremote_port="${5}"
	local jdwp_port="${6}"
	local is_chspark="${7}"

	local default_ports="${conf_templ_dir}/default.ports"

	local render_str="pd_addresses=${pd_addr}"
	local render_str="${render_str}#spark_local_dir=${spark_mod_dir}/spark_local_dir"
	local render_str="${render_str}#jmxremote_port=${jmxremote_port}"
	local render_str="${render_str}#jdwp_port=${jdwp_port}"
	if [ "${is_chspark}" == "true" ]; then
		local render_str="${render_str}#flash_addresses=${tiflash_addr}"
		local spark_conf_file="${conf_templ_dir}/spark-defaults-ch.conf"
	else
		local spark_conf_file="${conf_templ_dir}/spark-defaults.conf"
	fi
	render_templ "${spark_conf_file}" "${spark_mod_dir}/spark-defaults.conf" "${render_str}"

	if [ ! -d "${spark_mod_dir}/spark" ]; then
	    # TODO: remove spark file name from this func
		local spark_file="spark-2.3.4-bin-hadoop2.7"
		local spark_file_name="${spark_file}.tgz"
		if [ ! -f "${spark_mod_dir}/${spark_file_name}" ]; then
			echo "[func spark_file_prepare] cannot find spark file" >&2
			return 1
		fi
		tar -zxf "${spark_mod_dir}/${spark_file_name}" -C ${spark_mod_dir} 1>/dev/null
		rm -f "${spark_mod_dir}/${spark_file_name}"
		mv "${spark_mod_dir}/${spark_file}" "${spark_mod_dir}/spark"
	fi
	mkdir -p "${spark_mod_dir}/pids"
	if [ -f "${spark_mod_dir}/spark-defaults.conf" ]; then
		mv "${spark_mod_dir}/spark-defaults.conf" "${spark_mod_dir}/spark/conf"
	fi
	if [ ! -f "${spark_mod_dir}/spark/conf/spark-env.sh" ]; then
		echo "SPARK_PID_DIR=\"${spark_mod_dir}/pids\"" > "${spark_mod_dir}/spark/conf/spark-env.sh"
	fi
}
export -f spark_file_prepare
