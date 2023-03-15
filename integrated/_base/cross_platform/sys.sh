#!/bin/bash

function hw_info()
{
	if [ `uname` == "Darwin" ]; then
		echo "This script is for Linux only, not for Mac OS, skipped" >&2
		return 1
	fi

	local cores=`cat /proc/cpuinfo | grep 'core id' | wc -l`
	local model=`cat /proc/cpuinfo | grep 'model name' | head -n 1 | awk -F ': ' '{print $2}'`
	local cpu_hz=`cat /proc/cpuinfo | grep 'cpu MHz' | head -n 1 | awk -F ': ' '{print $2}'`

	local mem=`free -h | grep Mem | awk '{print $2}'`
	local mem_hz=`sudo dmidecode -t memory | grep -i Speed | awk '{print $2}' | sort | uniq | head -n 1`
	if [ ! -z "${mem_hz}" ]; then
		local mem_hz=" @ ${mem_hz} MHz"
	fi

	echo "CPU: ${cores} Cores, ${model} @ ${cpu_hz} MHz"
	echo "Mem: ${mem}${mem_hz}"

	local error_handle="$-"
	set +e
	local rpm_v=`rpm --version 2>/dev/null`
	restore_error_handle_flags "${error_handle}"

	if [ ! -z "${rpm_v}" ]; then
		echo "Sys: `rpm -q centos-release`"
	else
		echo "Sys: `uname -a`"
	fi
}
export -f hw_info

function to_ts()
{
	if [ -z "${1+x}" ]; then
		echo "[func to_ts] usage: <func> time_str" >&2
		return 1
	fi

	local time="${1}"
	if [ `uname` == "Darwin" ]; then
		date -j -f "%Y-%m-%d %H:%M:%S" "${time}" +%s
	else
		date -d "${time}" +%s
	fi
}
export -f to_ts

function from_ts()
{
	if [ -z "${1+x}" ]; then
		echo "[func from_ts] usage: <func> ts" >&2
		return 1
	fi

	local ts="${1}"
	if [ `uname` == "Darwin" ]; then
		date -r "${ts}" "+%Y-%m-%d %H:%M:%S"
	else
		date -d @"${ts}" "+%Y-%m-%d %H:%M:%S"
	fi
}
export -f from_ts
