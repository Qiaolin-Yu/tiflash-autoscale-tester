#!/bin/bash

function ti_file_mod_stop()
{
	if [ -z "${2+x}" ]; then
		echo "[func ti_file_mod_stop] usage <func> index name dir conf fast_mode" >&2
		return 1
	fi

	local index="${1}"
	local name="${2}"
	local dir="${3}"
	local conf="${4}"
	local fast="${5}"

	local up_status=`ti_file_mod_status "${dir}" "${conf}"`
	local up_status=`echo ${up_status}`
	local ok=`echo "${up_status}" | { grep ^OK || test $? = 1; }`
	if [ -z "${ok}" ]; then
		echo "=> skipped. ${name} #${index} (${dir}) ${up_status}"
		return
	fi

	echo "=> stopping ${name} #${index} (${dir})"

	if [ "${name}" == "pd" ]; then
		pd_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "tikv" ]; then
		tikv_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "tidb" ]; then
		tidb_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "tiflash" ]; then
		tiflash_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "spark_m" ]; then
		spark_master_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "spark_w" ]; then
		spark_worker_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "chspark_m" ]; then
		spark_master_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "chspark_w" ]; then
		spark_worker_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "tikv_importer" ]; then
		tikv_importer_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "node_exporter" ]; then
		node_exporter_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "prometheus" ]; then
		prometheus_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	elif [ "${name}" == "grafana" ]; then
		grafana_stop "${dir}" "${fast}" | awk '{print "   "$0}'
	else
		echo "   unknown mod to stop."
		return 1
	fi

	local up_status=`ti_file_mod_status "${dir}" "${conf}"`
	local ok=`echo "${up_status}" | { grep ^OK || test $? = 1; }`
	if [ ! -z "${ok}" ]; then
		echo "   failed.. ${name} #${index} (${dir}) ${up_status}"
		return 1
	fi
}
export -f ti_file_mod_stop

function ti_file_cmd_stop()
{
	ti_file_mod_stop "${1}" "${2}" "${3}" "${4}" 'false'
}
export -f ti_file_cmd_stop

function ti_file_cmd_fstop()
{
	ti_file_mod_stop "${1}" "${2}" "${3}" "${4}" 'true' | { grep -v 'closing' || test $? = 1; }
}
export -f ti_file_cmd_fstop
