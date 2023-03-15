#!/bin/bash

function timer_start()
{
	if [ `uname` == "Darwin" ]; then
		if hash gdate 2>/dev/null; then
			local date_cmd='gdate'
			local nano='true'
		else
			local date_cmd='date'
			local nano='false'
		fi
	else
		local date_cmd='date'
		local nano='true'
	fi

	if [ "${nano}" == 'true' ]; then
		"${date_cmd}" +%s%N
	else
		"${date_cmd}" +%s
	fi
}
export -f timer_start

function timer_end()
{
	if [ -z "${1+x}" ]; then
		echo "[func timer_end] usage: <func> start_time" >&2
		return 1
	fi

	local start_time="${1}"

	if [ `uname` == "Darwin" ]; then
		if hash gdate 2>/dev/null; then
			local date_cmd='gdate'
			local nano='true'
		else
			local date_cmd='date'
			local nano='false'
		fi
	else
		local date_cmd='date'
		local nano='true'
	fi

	if [ "${nano}" == 'true' ]; then
		local end_time=`"${date_cmd}" +%s%N`
		local elapsed=$(( (end_time - start_time) / 1000000 ))
		echo "${elapsed}ms"
	else
		local end_time=`"${date_cmd}" +%s`
		local elapsed=$((end_time - start_time))
		echo "${elapsed}s"
	fi
}
export -f timer_end
