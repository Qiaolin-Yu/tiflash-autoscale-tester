#!/bin/bash

function trans_schema_fields_decimal_to_double()
{
	if [ -z "${2+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func trans_schema_fields_decimal_to_double] cmd src_schema_dir dst_schema_dir" >&2
		return 1
	fi

	local src_schema_dir="${1}"
	local dst_schema_dir="${2}"

	# Replace fields from `DECIMAL(..,..)` to `DOUBLE`
	if [ -d "${dst_schema_dir}" ]; then
		local num_ori_schemas=`ls "${src_schema_dir}" | grep "ddl" | wc -l | awk '{print $1}'`
		local num_schemas=`ls "${dst_schema_dir}" | grep "ddl" | wc -l | awk '{print $1}'`
		if [ "${num_schemas}" == "${num_ori_schemas}" ]; then
			echo "schema with double fields are already exist in \"${dst_schema_dir}\""
		else
			# Not complete, clean and creating them again
			echo "preparing schema with double fields.."
			rm -r "${dst_schema_dir}"
			mkdir -p "${dst_schema_dir}"
			for f in $(ls "${src_schema_dir}" | grep "ddl"); do
				sed_eres 's/DECIMAL\([0-9]+,[0-9]+\)/DOUBLE/g' "${src_schema_dir}/${f}" > "${dst_schema_dir}/${f}"
			done
			echo "schema with double fields generated in \"${dst_schema_dir}\""
		fi
	else
		mkdir -p "${dst_schema_dir}"
		for f in $(ls "${src_schema_dir}" | grep "ddl"); do
			sed_eres 's/DECIMAL\([0-9]+,[0-9]+\)/DOUBLE/g' "${src_schema_dir}/${f}" > "${dst_schema_dir}/${f}"
		done
		echo "schema with double fields generated in \"${dst_schema_dir}\""
	fi
}
export -f trans_schema_fields_decimal_to_double

function create_tpch_table_to_mysql()
{
	if [ -z "${5+x}" ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]; then
		echo "[func create_tpch_table_to_mysql] cmd mysql_host mysql_port schema_dir db table" >&2
		return 1
	fi

	local mysql_host="${1}"
	local mysql_port="${2}"
	local schema_dir="${3}"
	local db="${4}"
	local table="${5}"

	local schema_file="${schema_dir}/${table}.ddl"
	if [ ! -f "${schema_file}" ]; then
		echo "[func create_tpch_table_to_mysql] ${schema_file} not exists" >&2
		return 1
	fi

	local create_table_stmt=`cat "${schema_file}" | tr -s "\n" " "`
	mysql -u 'root' -p1 -P "${mysql_port}" -h "${mysql_host}" -e "CREATE DATABASE IF NOT EXISTS ${db}"
	mysql -u 'root' -p1 -P "${mysql_port}" -h "${mysql_host}" -D "${db}" -e "${create_table_stmt}"
}
export -f create_tpch_table_to_mysql

function load_tpch_data_to_mysql()
{
	if [ -z "${6+x}" ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ] || [ -z "${6}" ]; then
		echo "[func load_tpch_data_to_mysql] cmd mysql_host mysql_port schema_dir data_dir db table [block_index]" >&2
		return 1
	fi

	local mysql_host="${1}"
	local mysql_port="${2}"
	local schema_dir="${3}"
	local data_dir="${4}"
	local db="${5}"
	local table="${6}"

	local block=''
	if [ ! -z "${7+x}" ] && [ ! -z "${7}" ]; then
		local block="${7}"
	fi

	local blocks=`ls "${data_dir}" | { grep "${table}.tbl" || test $? = 1; } | wc -l`

	if [ -f "${data_dir}/${table}.tbl" ] && [ -f "${data_dir}/${table}.tbl.1" ]; then
		echo "[func load_tpch_data_to_mysql] '${data_dir}' not data dir" >&2
		return 1
	fi

	if [ -f "${data_dir}/${table}.tbl" ]; then
		if [ -z "${block}" ] || [ "${block}" == '0' ]; then
			local data_file="${data_dir}/${table}.tbl"
			mysql -u 'root' -p1 -P "${mysql_port}" -h "${mysql_host}" -D "${db}" --local-infile=1 \
				-e "load data local infile '${data_file}' into table ${table} fields terminated by '|' lines terminated by '|\n';"
		fi
	else
		for (( i = 1; i < ${blocks} + 1; ++i)); do
			if [ ! -z "${block}" ] && [ "${block}" != "${i}" ]; then
				continue
			fi
			local data_file="${data_dir}/${table}.tbl.${i}"
			if [ ! -f "${data_file}" ]; then
				echo "[func load_tpch_data_to_mysql] ${data_file} not exists" >&2
				return 1
			fi
			mysql -u 'root' -p1 -P "${mysql_port}" -h "${mysql_host}" -D "${db}" --local-infile=1 \
				-e "set tidb_batch_insert = 1;set tidb_dml_batch_size = 20000; load data local infile '${data_file}' into table ${table} fields terminated by '|' lines terminated by '|\n';" &
		done
		wait
	fi

	local max_block_idx=$((block - 1))
	#if [ -z "${block}" ] || [ "${max_block_idx}" == "${block}" ]; then
	#	mysql -u 'root' -p1 -P "${mysql_port}" -h "${mysql_host}" -D "${db}" -e "analyze table ${table};"
	#fi
}
export -f load_tpch_data_to_mysql

function load_tpch_data_to_ch()
{
	if [ -z "${7+x}" ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ] || [ -z "${6}" ] || [ -z "${7}" ]; then
		echo "[func load_tpch_data_to_ch] cmd ch_bin ch_host ch_port schema_dir data_dir db table" >&2
		return 1
	fi

	local ch_bin="${1}"
	local ch_host="${2}"
	local ch_port="${3}"
	local schema_dir="${4}"
	local data_dir="${5}"
	local db="${6}"
	local table="${7}"

	local blocks=`ls "${data_dir}" | { grep "${table}.tbl" || test $? = 1; } | wc -l | awk '$1=$1'`

	## Create database and tables
	local create_db_stmt="create database if not exists ${db}"
	local create_table_stmt=`cat "${schema_dir}/${table}.ddl" | tr -s "\n" " "`
	local ch_bin_dir="`dirname ${ch_bin}`"
	run_query_through_ch_client "${ch_bin}" --host="${ch_host}" --port="${ch_port}" --query="${create_db_stmt}"
	run_query_through_ch_client "${ch_bin}" --host="${ch_host}" --port="${ch_port}" -d "${db}" --query="${create_table_stmt}"
	
	if [ -f "${data_dir}/${table}.tbl" ] && [ -f "${data_dir}/${table}.tbl.1" ]; then
		echo "[func load_tpch_data_to_ch] '${data_dir}' not data dir" >&2
		return 1
	fi

	local workspace="${integrated}/_base/test"

	if [ -f "${data_dir}/${table}.tbl" ]; then
		local data_file="${data_dir}/${table}.tbl"
		local csv_file="${data_dir}/${table}.csv.tbl"
		if [ ! -f "${csv_file}" ]; then
			## trans delimiter "|" to ","
			cat "${data_file}" | python "${workspace}/trans/${table}.py" > "${csv_file}"
		fi
		cat "${csv_file}" | run_query_through_ch_client "${ch_bin}" --host="${ch_host}" \
				--port="${ch_port}" -d "${db}" --query="INSERT INTO $table FORMAT CSV"
	else
		## Ensure all blocks exist.
		echo "   check and translate data files."
		for (( i = 1; i < ${blocks} + 1; ++i)); do
			local data_file="${data_dir}/${table}.tbl.${i}"
			if [ ! -f "${data_file}" ]; then
				echo "[func load_tpch_data_to_mysql] ${data_file} not exists" >&2
				return 1
			else
				local csv_file="${data_dir}/${table}.csv.tbl.${i}"
				if [ ! -f "${csv_file}" ]; then
					## trans delimiter "|" to ","
					local workspace="${integrated}/_base/test"
					cat "${data_file}" | python "${workspace}/trans/${table}.py" > "${csv_file}" &
				fi
			fi
		done
		wait ## Wait for all csv file generated.
		echo "   check and translate done."
		for ((i=1; i<${blocks}+1; ++i)); do
			local csv_file="${data_dir}/${table}.csv.tbl.${i}"
			cat "${csv_file}" | run_query_through_ch_client "${ch_bin}" --host="${ch_host}" \
					--port="${ch_port}" -d "${db}" --query="INSERT INTO $table FORMAT CSV" &
		done
		wait ## Wait for all blocks loaded
	fi
}
export -f load_tpch_data_to_ch
