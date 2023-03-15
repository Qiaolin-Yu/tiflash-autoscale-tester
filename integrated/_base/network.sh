#!/bin/bash

function print_ip()
{
	ifconfig | { grep 'en[0123456789]\|eth[0123456789]\|wlp[0123456789]\|em[0123456789]' -A 3 || test $? = 1; } | \
		{ grep -v inet6 || test $? = 1; } | { grep inet || test $? = 1; } | { grep -i mask || test $? = 1; } | awk '{print $2}'
}
export -f print_ip

function print_ip_cnt()
{
	local ips="`print_ip`"
	if [ -z "${ips}" ]; then
		echo "0"
	else
		echo "${ips}" | wc -l | awk '{print $1}'
	fi
}
export -f print_ip_cnt

function must_print_ip()
{
	local ip_cnt="`print_ip_cnt`"
	if [ "${ip_cnt}" != "1" ]; then
		echo "127.0.0.1"
	else
		print_ip
	fi
}
export -f must_print_ip

function print_ip_or_host()
{
	local ip_cnt="`print_ip_cnt`"
	if [ "${ip_cnt}" != "1" ]; then
		hostname
	else
		print_ip
	fi
}
export -f print_ip_or_host

function is_local_host()
{
	if [ -z "${1+x}" ]; then
		echo "[func is_local_host] usage: <func> host"
		return 1
	fi

	local host="${1}"
	local local_host="`must_print_ip`"
	if [ -z "${host}" ] || [ "${host}" == '127.0.0.1' ] || [ "${host}" == 'localhost' ] || [ "${host}" == "${local_host}" ]; then
		echo 'true'
	else
		echo 'false'
	fi
}
export -f is_local_host
