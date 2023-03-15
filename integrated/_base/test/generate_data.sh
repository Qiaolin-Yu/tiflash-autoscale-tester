#!/bin/bash

function download_dbgen()
{
	local dbgen_url="${1}"
	local dbgen_bin_dir="${2}"
	if [ -z "${dbgen_url}" ] || [ -z "${dbgen_bin_dir}" ]; then
		echo "[func download_dbgen] usage: <func> dbgen_url dbgen_bin_dir" >&2
		return 1
	fi
	mkdir -p "${dbgen_bin_dir}"
	local download_path="${dbgen_bin_dir}/dbgen.tar.gz.`date +%s`.${RANDOM}"
	if [ ! -f "${dbgen_bin_dir}/dbgen.tar.gz" ]; then
		wget --quiet -nd "${dbgen_url}" -O "${download_path}"
		mv "${download_path}" "${dbgen_bin_dir}/dbgen.tar.gz"
	fi
	if [ ! -f "${dbgen_bin_dir}/dbgen" ]; then
		tar -zxf "${dbgen_bin_dir}/dbgen.tar.gz" -C "${dbgen_bin_dir}"
	fi
}
export -f download_dbgen

function table_to_arguments()
{
	local table="${1}"
	if [ -z "${table}" ]; then
		echo "[func table_to_arguments] usage: <func> table_name" >&2
		return 1
	fi
	if [ "${table}" == "lineitem" ]; then
		echo "L"
	fi
	if [ "${table}" == "partsupp" ]; then
		echo "S"
	fi
	if [ "${table}" == "customer" ]; then
		echo "c"
	fi
	if [ "${table}" == "nation" ]; then
		echo "n"
	fi
	if [ "${table}" == "orders" ]; then
		echo "O"
	fi
	if [ "${table}" == "part" ]; then
		echo "P"
	fi
	if [ "${table}" == "region" ]; then
		echo "r"
	fi
	if [ "${table}" == "supplier" ]; then
		echo "s"
	fi
}
export -f table_to_arguments

function generate_tpch_data_to_dir()
{
	local data_dir="${1}"
	local scale="${2}"
	local table="${3}"
	local blocks="${4}"
	if [ -z "${data_dir}" ] || [ -z "${scale}" ] || [ -z "${table}" ] || [ -z "${blocks}" ]; then
		echo "[func generate_tpch_data_to_dir] usage: <func> data_dir scale table blocks" >&2
		return 1
	fi

	local dbgen_bin_dir="${integrated}/resource/tpch/dbgen"
	mkdir -p "${data_dir}"
	(
		cd "${data_dir}"
		if [ "${blocks}" == 1 ]; then
			"${dbgen_bin_dir}/dbgen" -q -C "${blocks}" -T `table_to_arguments "${table}"` -s "${scale}" -f
		else
			for ((i=1; i<${blocks}+1; ++i)); do
				"${dbgen_bin_dir}/dbgen" -q -C "${blocks}" -T `table_to_arguments "${table}"` -s "${scale}" -S "${i}" -f &
			done
			wait
		fi
	)
	wait
	chmod 644 "${data_dir}"/*
}
export -f generate_tpch_data_to_dir

function generate_tpch_data()
{
	local data_dir="${1}"
	local scale="${2}"
	local table="${3}"
	local blocks="${4}"

	if [ -z "${data_dir}" ] || [ -z "${scale}" ] || [ -z "${table}" ] || [ -z "${blocks}" ]; then
		echo "[func generate_tpch_data] usage: <func> data_dir scale table blocks" >&2
		return 1
	fi

	if [ -d "${data_dir}" ]; then
		return 0
	fi

	local temp_data_dir="${data_dir}_`date +%s`.${RANDOM}"
	mkdir -p "${temp_data_dir}"
	cp -r "${integrated}/resource/tpch/dbgen/dists.dss" "${temp_data_dir}"
	generate_tpch_data_to_dir "${temp_data_dir}" "${scale}" "${table}" "${blocks}"
	local data_file_count=`ls "${temp_data_dir}" | { grep "${table}" || test $? = 1; } | wc -l`
	if [ "${data_file_count}" -le '0' ]; then
		echo "[func generate_tpch_data] generate data file failed" >&2
		return 1
	fi
	mv "${temp_data_dir}" "${data_dir}"
}
export -f generate_tpch_data
