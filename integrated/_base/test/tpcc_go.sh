#!/bin/bash

function _fetch_go_tpc_repo()
{
	local dir="${1}"
	mkdir -p "${dir}"

	local benchmark_repo="${dir}/go-tpc"
	if [ ! -d "${benchmark_repo}" ]; then
		temp_benchmark_repo="${benchmark_repo}.`date +%s`.${RANDOM}"
		rm -rf "${temp_benchmark_repo}"
		mkdir -p "${temp_benchmark_repo}"
		git clone https://github.com/pingcap/go-tpc "${temp_benchmark_repo}"
		(
			cd "${temp_benchmark_repo}" && make
		)
		wait
		mv "${temp_benchmark_repo}" "${benchmark_repo}"
	fi
}
export -f _fetch_go_tpc_repo

function tpcc_go_load()
{
	if [ -z "${4+x}" ]; then
		echo "[func tpcc_go_load] usage: <func> work_dir host port warehouses threads" >&2
		return 1
	fi

	local work_dir="${1}"
	local host="${2}"
	local port="${3}"
	local warehouses="${4}"
	local threads="${5}"

	_fetch_go_tpc_repo "${work_dir}"
	local tpc_bin="${entry_dir}/go-tpc/bin/go-tpc"
	${tpc_bin} -T "${threads}" -P "${port}" -H "${host}" tpcc --warehouses "${warehouses}" --time "72h" prepare | log_ts
}
export -f tpcc_go_load

function tpcc_go_run()
{
	if [ -z "${4+x}" ]; then
		echo "[func tpcc_go_run] usage: <func> work_dir host port warehouses threads [time=20m]" >&2
		return 1
	fi

	local work_dir="${1}"
	local host="${2}"
	local port="${3}"
	local warehouses="${4}"
	local threads="${5}"

	local dur='20m'
	if [ ! -z "${6+x}" ]; then
		local dur="${6}"
	fi

	_fetch_go_tpc_repo "${work_dir}"
	local tpc_bin="${work_dir}/go-tpc/bin/go-tpc"
	${tpc_bin} -T "${threads}" -P "${port}" -H "${host}" tpcc --warehouses "${warehouses}" --time "${dur}" run | log_ts
}
export -f tpcc_go_run
