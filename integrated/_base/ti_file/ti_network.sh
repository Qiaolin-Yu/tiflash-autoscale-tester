#!/bin/bash

function cal_addr()
{
	if [ -z "${3+x}" ]; then
		echo "[func cal_addr] usage: <func> addr default_host default_port [default_pd_name]" >&2
		return 1
	fi

	local addr="${1}"
	local default_host="${2}"
	local default_port="${3}"
	local default_pd_name=""
	if [ ! -z "${4+x}" ]; then
		local default_pd_name="${4}"
	fi

	local here="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`"
	python "${here}/cal_addr.py" "${addr}" "${default_host}" "${default_port}" "${default_pd_name}"
}
export -f cal_addr
