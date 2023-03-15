#!/bin/bash

function _ti_stop()
{
	if [ -z "${2+x}" ]; then
		echo "[func _ti_stop] usage: <func> module_dir conf_rel_path [fast=false]" >&2
		return 1
	fi

	local ti_dir="${1}"
	local conf_rel_path="${2}"

	if [ -z "${3+x}" ]; then
		local fast=""
	else
		local fast="${3}"
	fi

	local ti_dir=`abs_path "${ti_dir}"`
	if [ -z "${conf_rel_path}" ]; then
	    local conf_file="${ti_dir}"
	else
	    local conf_file="${ti_dir}/${conf_rel_path}"
	fi

	local extra_str_to_find_proc="\-\-config"
	if [ -f "${ti_dir}/extra_str_to_find_proc" ]; then
		local extra_str_to_find_proc="`cat ${ti_dir}/extra_str_to_find_proc`"
	fi

	local proc_cnt=`print_proc_cnt "${conf_file}" "${extra_str_to_find_proc}"`
	if [ "${proc_cnt}" == "0" ]; then
		echo "[func ti_stop] ${ti_dir} is not running, skipping"
		return 0
	fi

	if [ "${proc_cnt}" != "1" ]; then
		echo "[func ti_stop] ${ti_dir} has ${proc_cnt} instances, skipping" >&2
		return 1
	fi

	stop_procs "${conf_file}" "${extra_str_to_find_proc}" "${fast}"
}
export -f _ti_stop

function tiflash_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func tiflash_stop] usage: <func> tiflash_dir [fast_mode=false]" >&2
		return 1
	fi
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	_ti_stop "${1}" "conf/config.toml" "${fast}"
}
export -f tiflash_stop

function pd_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func pd_stop] usage: <func> pd_dir [fast_mode=false]" >&2
		return 1
	fi
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	_ti_stop "${1}" "pd.toml" "${fast}"
}
export -f pd_stop

function tikv_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func tikv_stop] usage: <func> tikv_dir [fast_mode=false]" >&2
		return 1
	fi
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	_ti_stop "${1}" "tikv.toml" "${fast}"
}
export -f tikv_stop

function tidb_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func tidb_stop] usage: <func> tidb_dir [fast_mode=false]" >&2
		return 1
	fi
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	_ti_stop "${1}" "tidb.toml" "true" "${fast}"
}
export -f tidb_stop

function spark_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func spark_stop] usage: <func> spark_mod_dir extra_str_to_find_proc [fast_mode=false]" >&2
		return 1
	fi
	local spark_mod_dir="${1}"
	local extra_str_to_find_proc="${2}"
	local fast="false"
	if [ ! -z "${3+x}" ]; then
		local fast="${3}"
	fi
	stop_procs "${spark_mod_dir}/" "${extra_str_to_find_proc}" "${fast}"
}
export -f spark_stop

function spark_master_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func spark_master_stop] usage: <func> spark_master_dir [fast_mode=false]" >&2
		return 1
	fi
	local spark_master_dir="${1}"
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	spark_stop "${spark_master_dir}" "org.apache.spark.deploy.master.Master" "${fast}"
	spark_stop "${spark_master_dir}" "org.apache.spark.sql.hive.thriftserver.HiveThriftServer2" "${fast}"
}
export -f spark_master_stop

function spark_worker_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func spark_worker_stop] usage: <func> spark_worker_dir [fast_mode=false]" >&2
		return 1
	fi
	local spark_worker_dir="${1}"
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	spark_stop "${spark_worker_dir}" "org.apache.spark.deploy.worker.Worker" "${fast}"
}
export -f spark_worker_stop

function tikv_importer_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func tikv_importer_stop] usage: <func> tikv_importer_dir [fast_mode=false]" >&2
		return 1
	fi
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	_ti_stop "${1}" "tikv-importer.toml" "${fast}"
}
export -f tikv_importer_stop

function node_exporter_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func node_exporter_stop] usage: <func> node_exporter_dir [fast_mode=false]" >&2
		return 1
	fi
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	_ti_stop "${1}" "" "${fast}"
}
export -f node_exporter_stop

function prometheus_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func prometheus_stop] usage: <func> prometheus_dir [fast_mode=false]" >&2
		return 1
	fi
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	_ti_stop "${1}" "conf/prometheus.yml" "${fast}"
}
export -f prometheus_stop

function grafana_stop()
{
	if [ -z "${1+x}" ]; then
		echo "[func grafana_stop] usage: <func> grafana_dir [fast_mode=false]" >&2
		return 1
	fi
	local fast="false"
	if [ ! -z "${2+x}" ]; then
		local fast="${2}"
	fi
	_ti_stop "${1}" "conf/grafana.ini" "${fast}"
}
export -f grafana_stop
