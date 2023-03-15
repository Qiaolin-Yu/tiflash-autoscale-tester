#!/bin/bash

function check_url_connectivity()
{
	if [ -z "${1+x}" ]; then
		echo "[func check_url_connectivity] usage: <func> url [timeout]" >&2
		return 1
	fi
	local url="${1}"
	if [ -z "${2+x}" ]; then
		local timeout=5
	else
		local timeout="${2}"
	fi

	local error_handle="$-"
	set +e
	curl --silent --connect-timeout "${timeout}" "${url}" 2>&1 1>/dev/null
	if [ "${?}" -eq 0 ]; then
		local result="0"
	else
		local result="1"
	fi
	restore_error_handle_flags "${error_handle}"
	echo "${result}"
}
export -f check_url_connectivity

function upload_file()
{
	if [ -z "${1+x}" ]; then
		echo "[func upload_file] usage: <func> file [host](from transfer.sh) [route](from transfer.sh)" >&2
		return 1
	fi
	local file="${1}"
	if [ ! -f "${file}" ]; then
		echo "[func upload_file] ${file} is not a regular file" >&2
		return 1
	fi
	local filename=`basename "${file}"`
	local conf_file="${integrated}/conf/tools.kv"
	if [ -z "${2+x}" ]; then
		local host=`cross_platform_get_value "${conf_file}" "upload_server_host"`
	else
		local host="${2}"
	fi
	if [ -z "${3+x}" ]; then
		local route=`cross_platform_get_value "${conf_file}" "upload_server_route"`
	else
		local route="${3}"
	fi

	local connectivity=`check_url_connectivity "${host}"`
	if [ "${connectivity}" -eq 1 ]; then
		echo "[func upload_file] ${host} cannot be connected" >&2
		return 1
	fi

	local file_url=`curl --silent --upload-file "${file}" "${host}/${filename}" "${host}/${route}/${filename}"`
	local file_url=`replace_substr "${file_url}" "Not Found" ""`
	if [ -z "${file_url}" ]; then
		echo "[func upload_file] <func> upload ${file} failed" >&2
		return 1
	fi

	echo "${file_url}"
}
export -f upload_file
