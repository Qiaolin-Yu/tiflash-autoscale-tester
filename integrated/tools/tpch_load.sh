#!/bin/bash

here=`cd $(dirname ${BASH_SOURCE[0]}) && pwd`
source "${here}/_env.sh"
auto_error_handle

function ti_tools_tpch_load()
{
	local help="[cmd tpch/load] usage: <cmd> tidb_host tidb_port scale table(all|lineitem|..) [threads=auto] [db_suffix=''] [float_type=decimal|double] [data_dir={integrated}/data/tpch]"
	if [ -z "${2+x}" ]; then
		echo "${help}" >&2
		return 1
	fi

	local host="${1}"
	local port="${2}"
	local scale="${3}"
	local table="${4}"

	shift 4

	if [ ! -z "${1+x}" ] && [ ! -z "${1}" ]; then
		local blocks="${1}"
	else
		local blocks='4'
	fi

	if [ ! -z "${2+x}" ] && [ ! -z "${2}" ]; then
		local db_suffix="_${2}"
	else
		local db_suffix=''
	fi

	if [ ! -z "${3+x}" ] && [ ! -z "${3}" ]; then
		local float_type="${3}"
	else
		local float_type="decimal"
	fi

	if [ ! -z "${4+x}" ] && [ ! -z "${4}" ]; then
		local data_dir="${4}"
	else
		local data_dir="${integrated}/data/tpch"
	fi

	if [ "${float_type}" == "decimal" ]; then
		local schema_dir="${integrated}/resource/tpch/mysql/schema"
	elif [ "${float_type}" == "double" ]; then
		local ori_schema_dir="${integrated}/resource/tpch/mysql/schema"
		local schema_dir="${ori_schema_dir}_double"
		# Replace fields from `DECIMAL(..,..)` to `DOUBLE`
		trans_schema_fields_decimal_to_double "${ori_schema_dir}" "${schema_dir}"
	else
		echo "[cmd tpch_load] unknown float type: ${float_type}, should be 'decimal' or 'double'" >&2
		return 1
	fi

	local db=`echo "tpch_${scale}${db_suffix}" | scale_to_name`

	if [ "${table}" != 'all' ]; then
		local tables=("${table}")
	else
		local tables=(nation customer orders part region supplier partsupp lineitem)
	fi

	local conf_file="${integrated}/conf/tools.kv"

	for table in ${tables[@]}; do
		local start_time=`date +%s`
		echo "=> [${host}] creating ${db}.${table}"
		create_tpch_table_to_mysql "${host}" "${port}" "${schema_dir}" "${db}" "${table}"

		echo "=> [${host}] loading ${db}.${table}"
		local table_dir="${data_dir}/tpch_s`echo ${scale} | scale_to_name`_b${blocks}/${table}"
		generate_tpch_data "${table_dir}" "${scale}" "${table}" "${blocks}"
		echo '   generated'

		load_tpch_data_to_mysql "${host}" "${port}" "${schema_dir}" "${table_dir}" "${db}" "${table}"

		local finish_time=`date +%s`
		local duration=$((finish_time-start_time))
		echo "   loaded in ${duration}s"
	done
}

ti_tools_tpch_load "${@}"
