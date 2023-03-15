#!/bin/bash

function pd_safe_run()
{
	if [ -z "${2+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func pd_safe_run] usage: <func> pd_dir conf_templ_dir [name_ports_delta] [advertise_host] [pd_name] [initial_cluster] [cluster_id]" >&2
		return 1
	fi

	local pd_dir="${1}"
	local conf_templ_dir="${2}"

	if [ -z "${3+x}" ]; then
		local name_ports_delta="0"
	else
		local name_ports_delta="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local advertise_host=""
	else
		local advertise_host="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local pd_name=""
	else
		local pd_name="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local initial_cluster=""
	else
		local initial_cluster="${6}"
	fi

	if [ -z "${7+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${7}"
	fi

	pd_run "${pd_dir}" "${conf_templ_dir}" "${name_ports_delta}" "${advertise_host}" "${pd_name}" "${initial_cluster}" "${cluster_id}"
	wait_for_pd_port_ready_local "${pd_dir}" | awk '{print "   "$0}'
}
export -f pd_safe_run

function tikv_safe_run()
{
	if [ -z "${3+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func tikv_safe_run] usage: <func> tikv_dir conf_templ_dir pd_addr [advertise_host] [ports_delta] [cluster_id]" >&2
		return 1
	fi

	local tikv_dir="${1}"
	local conf_templ_dir="${2}"
	local pd_addr="${3}"

	if [ -z "${4+x}" ]; then
		local advertise_host=""
	else
		local advertise_host="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local ports_delta="0"
	else
		local ports_delta="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${6}"
	fi

	tikv_run "${tikv_dir}" "${conf_templ_dir}" "${pd_addr}" "${advertise_host}" "${ports_delta}" "${cluster_id}"
	wait_for_tikv_port_ready_local "${tikv_dir}" | awk '{print "   "$0}'
}
export -f tikv_safe_run

function tidb_safe_run()
{
	if [ -z "${3+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func tidb_safe_run] usage: <func> tidb_dir conf_templ_dir pd_addr [advertise_host] [ports_delta] [cluster_id]" >&2
		return 1
	fi

	local tidb_dir="${1}"
	local conf_templ_dir="${2}"
	local pd_addr="${3}"

	if [ -z "${4+x}" ]; then
		local advertise_host=""
	else
		local advertise_host="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local ports_delta="0"
	else
		local ports_delta="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${6}"
	fi
	tidb_run "${tidb_dir}" "${conf_templ_dir}" "${pd_addr}" "${advertise_host}" "${ports_delta}" "${cluster_id}"
	wait_for_tidb "${tidb_dir}" | awk '{print "   "$0}'
}
export -f tidb_safe_run

function tiflash_safe_run()
{
	if [ -z "${2+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func tiflash_safe_run] usage: <func> tiflash_dir conf_templ_dir [daemon_mode] [pd_addr] [ports_delta] [listen_host] [cluster_id] [standalone] [storage_engine]" >&2
		return 1
	fi

	local tiflash_dir="${1}"
	local conf_templ_dir="${2}"

	if [ -z "${3+x}" ]; then
		local daemon_mode="false"
	else
		local daemon_mode="${3}"
	fi

	if [ -z "${4+x}" ]; then
		local pd_addr=""
	else
		local pd_addr="${4}"
	fi

	if [ -z "${5+x}" ]; then
		local tidb_addr=""
	else
		local tidb_addr="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local ports_delta="0"
	else
		local ports_delta="${6}"
	fi

	if [ -z "${7+x}" ]; then
		local listen_host=""
	else
		local listen_host="${7}"
	fi

	if [ -z "${8+x}" ]; then
		local cluster_id="<none>"
	else
		local cluster_id="${8}"
	fi

	if [ -z "${9+x}" ]; then
		local standalone="false"
	else
		local standalone="${9}"
	fi

	# storage_engine is empty by default, keep the storage_engine in "config.toml"
	if [ -z "${10+x}" ]; then
		local storage_engine=""
	else
		local storage_engine="${10}"
	fi

	tiflash_run "${tiflash_dir}" "${conf_templ_dir}" "${daemon_mode}" "${pd_addr}" "${tidb_addr}" "${ports_delta}" "${listen_host}" "${cluster_id}" "${standalone}" "${storage_engine}"
	wait_for_tiflash_local "${tiflash_dir}" | awk '{print "   "$0}'
}
export -f tiflash_safe_run
