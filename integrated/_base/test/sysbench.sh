#!/bin/bash

function _install_sysbench()
{
	local dir="${1}"
	mkdir -p "${dir}"

	local error_handle="$-"
	set +e
	sysbench --help >/dev/null 2>&1
	if [ $? == 0 ]; then
		return
	fi
	restore_error_handle_flags "${error_handle}"

	local ver='1.0.14'
	local url="https://github.com/akopytov/sysbench/archive/${ver}.tar.gz"
	local name="sysbench.${ver}.tar.gz"
	rm -f "${dir}/${name}"
	wget --quiet -nd "${url}" -O "${dir}/${name}"
	(
		cd "${dir}" && tar -xzf "${name}"
		cd "sysbench-${ver}"
		sudo yum -y install make automake libtool pkgconfig libaio-devel mysql-devel
		./autogen.sh
		./configure
		make -j
		make install
	)
	rm -f "${dir}/${name}"
}
export -f _install_sysbench

function sysbench_load()
{
	if [ -z "${6+x}" ]; then
		echo "[func sysbench_load] usage: <func> work_dir host port tables table_size threads" >&2
		return 1
	fi

	local work_dir="${1}"
	local host="${2}"
	local port="${3}"
	local tables="${4}"
	local table_size="${5}"
	local threads="${6}"

	_install_sysbench "${work_dir}"

	sysbench oltp_common \
		--threads="${threads}" \
		--rand-type=uniform \
		--db-driver=mysql \
		--mysql-db=sbtest \
		--mysql-host="${host}" \
		--mysql-port="${port}" \
		--mysql-user=root \
		prepare --tables="${tables}" --table-size="${table_size}"
}
export -f sysbench_load

function sysbench_run()
{
	if [ -z "${8+x}" ]; then
		echo "[func sysbench_run] usage: <func> work_dir host port tables table_size threads duration work_load" >&2
		return 1
	fi

	local work_dir="${1}"
	local host="${2}"
	local port="${3}"
	local tables="${4}"
	local table_size="${5}"
	local threads="${6}"
	local dur="${7}"
	local workload="${8}"

	_install_sysbench "${work_dir}"

	sysbench "${workload}" \
		--threads="${threads}" \
		--time="${dur}" \
		--report-interval=10 \
		--rand-type=uniform \
		--rand-seed=${RANDOM} \
		--db-driver=mysql \
		--mysql-db=sbtest \
		--mysql-host="${host}" \
		--mysql-port="${port}" \
		--mysql-user=root \
		run --tables="${tables}" --table-size="${table_size}"
}
export -f sysbench_run
