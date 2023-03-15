#!/bin/bash

function _fetch_tpcc_repo()
{
	local dir="${1}"
	mkdir -p "${dir}"

	local benchmark_repo="${dir}/benchmarksql"
	if [ ! -d "${benchmark_repo}" ]; then
		temp_benchmark_repo="${benchmark_repo}.`date +%s`.${RANDOM}"
		rm -rf "${temp_benchmark_repo}"
		mkdir -p "${temp_benchmark_repo}"
		git clone -b 5.0-mysql-support-opt-2.1 https://github.com/pingcap/benchmarksql.git "${temp_benchmark_repo}"
		(
			cd "${temp_benchmark_repo}" && ant
		)
		wait
		mv "${temp_benchmark_repo}" "${benchmark_repo}"
	fi
}
export -f _fetch_tpcc_repo

function _gen_tpcc_prop()
{
	local tidb_host="${1}"
	local tidb_port="${2}"
	local benchmark_dir="${3}"
	local warehouses="${4}"
	local minutes="${5}"
	local terminals="${6}"
	local load_workers="${7}"

	local db="tpcc_${warehouses}"
	local prop_file="${benchmark_dir}/props_${warehouses}.mysql"

	local tidb_addr="${tidb_host}:${tidb_port}"

	echo "db=mysql" > "${prop_file}"
	echo "driver=com.mysql.jdbc.Driver" >> "${prop_file}"
	echo "conn=jdbc:mysql://${tidb_addr}/${db}?useSSL=false&useServerPrepStmts=true&useConfigs=maxPerformance" >> \
		"${prop_file}"
	echo "user=root" >> "${prop_file}"
	echo "password=" >> "${prop_file}"
	echo "warehouses=${warehouses}" >> "${prop_file}"
	echo "loadWorkers=${load_workers}" >> "${prop_file}"
	echo "terminals=${terminals}" >> "${prop_file}"
	echo "runTxnsPerTerminal=0" >> "${prop_file}"
	echo "runMins=${minutes}" >> "${prop_file}"
	echo "limitTxnsPerMin=0" >> "${prop_file}"
	echo "terminalWarehouseFixed=true" >> "${prop_file}"

	echo "newOrderWeight=45" >> "${prop_file}"
	echo "paymentWeight=43" >> "${prop_file}"
	echo "orderStatusWeight=4" >> "${prop_file}"
	echo "deliveryWeight=4" >> "${prop_file}"
	echo "stockLevelWeight=4" >> "${prop_file}"

	echo "resultDirectory=my_result_%tY-%tm-%td_%tH%tM%tS" >> "${prop_file}"
}
export -f _gen_tpcc_prop

function _run_tpcc()
{
	local entry_dir="${1}"
	local warehouses="${2}"
	local terminals="${3}"
	local tag="${4}"

	local benchmark_dir="${entry_dir}/benchmarksql/run"
	local prop_file="props_${warehouses}.mysql"
	local start_time=`date +%s`

	(
		cd "${benchmark_dir}"
		echo "TPCC-BEGIN ${start_time}" >> ./all.log
		./runBenchmark.sh "${prop_file}" 2>&1 | grep -v 'This is deprecated' | tee -a ./all.log >"./test.log"
	)
	wait

	local end_time=`date +%s`
	local tags="tag:${tag},warehouses:${warehouses},terminals:${terminals},start_ts:${start_time},end_ts:${end_time}"
	local result=`grep "Measured tpmC" "${benchmark_dir}/test.log" | awk -F '=' '{print $2}' | tr -d ' ' | awk -F '.' '{print $1}'`
	if [ -z "${result}" ]; then
		echo "ERROR: no tpcc tpmC result" >&2
		return 1
	else
		echo "Measured tmpC: ${result} [${tags}]"
	fi

	echo "${result} ${tags}" >> "${entry_dir}/results.data"
}
export -f _run_tpcc

function tpcc_report()
{
	if [ -z "${1+x}" ]; then
		echo "[func tidb_tpcc_perf_report] usage: <func> entry_dir" >&2
		return 1
	fi

	local entry_dir="${1}"

	local report="${entry_dir}/report"
	local title='<tpcc performance>'

	rm -f "${report}.tmp"

	if [ -f "${entry_dir}/results.data" ]; then
		to_table "${title}" 'cols:terminals; rows:tag,warehouses; cell:limit(20)|avg|~|cnt' 9999 "${entry_dir}/results.data" > "${report}.tmp"
	fi

	if [ -f "${report}.tmp" ]; then
		mv -f "${report}.tmp" "${report}"
	fi

	if [ -f "${report}" ]; then
		echo "-- total report --"
		cat "${report}"
	fi
}
export -f tpcc_report

function tpcc_load()
{
	if [ -z "${3+x}" ]; then
		echo "[func tpcc_load] usage: <func> work_dir host port [db=tpcc_{wh}] [warehouses] [minutes] [terminals] [load_workers]" >&2
		return 1
	fi

	local entry_dir="${1}"

	local tidb_host="${2}"
	local tidb_port="${3}"

	if [ ! -z "${4+x}" ]; then
		local db="${4}"
	else
		local db="tpcc_${warehouses}"
	fi

	if [ ! -z "${5+x}" ]; then
		local warehouses="${5}"
	else
		local warehouses='1'
	fi

	if [ ! -z "${6+x}" ]; then
		local minutes="${6}"
	else
		local minutes='1'
	fi

	if [ ! -z "${7+x}" ]; then
		local terminals="${7}"
	else
		local terminals='1'
	fi

	if [ ! -z "${8+x}" ]; then
		local load_workers="${8}"
	else
		local load_workers='1'
	fi

	_fetch_tpcc_repo "${entry_dir}"
	local benchmark_dir="${entry_dir}/benchmarksql/run"

	_gen_tpcc_prop "${tidb_host}" "${tidb_port}" "${benchmark_dir}" "${warehouses}" "${minutes}" "${terminals}" "${load_workers}"

	local prop_file="props_${warehouses}.mysql"
	local verb='This is deprecated'
	(
		cd "${benchmark_dir}"
		./runSQL.sh "${prop_file}" sql.mysql/tableCreates.sql 2>&1 | grep -v "${verb}" 1>/dev/null
		./runSQL.sh "${prop_file}" sql.mysql/indexCreates.sql 2>&1 | grep -v "${verb}" 1>/dev/null
		./runLoader.sh "${prop_file}" 2>&1 | grep -v "${verb}"
	)
	wait

	echo "${warehouses} warehouse loaded to tpcc_${warehouses}"
}
export -f tpcc_load

function tpcc_run()
{
	if [ -z "${3+x}" ]; then
		echo "[func tpcc_run] usage: <func> work_dir host port [db=tpcc_{wh}] [warehouses] [minutes] [terminals] [load_workers] [tag]" >&2
		return 1
	fi

	local entry_dir="${1}"
	local tidb_host="${2}"
	local tidb_port="${3}"

	if [ ! -z "${5+x}" ]; then
		local warehouses="${5}"
	else
		local warehouses='1'
	fi

	if [ ! -z "${4+x}" ]; then
		local db="${4}"
	else
		local db="tpcc_${warehouses}"
	fi

	if [ ! -z "${6+x}" ]; then
		local minutes="${6}"
	else
		local minutes='1'
	fi

	if [ ! -z "${7+x}" ]; then
		local terminals="${7}"
	else
		local terminals='1'
	fi

	if [ ! -z "${8+x}" ]; then
		local load_workers="${8}"
	else
		local load_workers='1'
	fi

	if [ ! -z "${9+x}" ]; then
		local tag="${9}"
	else
		local tag='-'
	fi

	_fetch_tpcc_repo "${entry_dir}"
	local benchmark_dir="${entry_dir}/benchmarksql/run"
	_gen_tpcc_prop "${tidb_host}" "${tidb_port}" "${benchmark_dir}" "${warehouses}" "${minutes}" "${terminals}" "${load_workers}"

	_run_tpcc "${entry_dir}" "${warehouses}" "${terminals}" "${tag}"
	tpcc_report "${entry_dir}"
}
export -f tpcc_run
