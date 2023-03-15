#!/bin/bash

function is_the_same_file()
{
	# TODO: implement
	if [ "${src}" == "${dest}" ]; then
		echo "true"
	else
		echo "false"
	fi
}
export -f is_the_same_file

function normalize_path()
{
	echo "$(dirname $1)/$(basename $1)"
}
export -f normalize_path

function cp_when_diff()
{
	if [ -z "${2+x}" ]; then
		echo "[func cp_when_diff] usage: <func> src_file_path dest_file_path" >&2
		return 1
	fi

	local src="$(normalize_path ${1})"
	local dest="$(normalize_path ${2})"

	local same=`is_the_same_file "${src}" "${dest}"`
	if [ "${same}" == "true" ]; then
		return 0
	fi

	mkdir -p `dirname "${dest}"`

	# TODO: Update mode
	# Rename old file first due to FLASH-946
	if [ -f "${dest}" ]; then
		mv "${dest}" "${dest}.old"
	fi
	cp -f "${src}" "${dest}"
}
export -f cp_when_diff

function abs_path()
{
	if [ -z ${1+x} ]; then
		echo "[func abs_path] usage: <func> src_path" >&2
		return 1
	fi

	local src="${1}"

	if [ "${src:0:1}" == '/' ]; then
		echo "${src}"
		return
	fi

	if [ `uname` == "Darwin" ]; then
		if [ -d "${src}" ]; then
		    local path=$(cd "${src}"; pwd)
		elif [ -f "${src}" ]; then
		    local dir=$(cd "$(dirname "${src}")"; pwd)
		    local path="${dir}/`basename ${src}`"
		else
			echo "`pwd`/${src}"
			return 1
		fi
		echo "${path}"
	else
		readlink -f "${src}"
	fi
}
export -f abs_path

function file_md5()
{
	if [ -z "${1+x}" ]; then
		echo "[func file_md5] usage: <func> src_path" >&2
		return 1
	fi

	local file="$1"
	if [ `uname` == "Darwin" ]; then
		md5 "${file}" 2>/dev/null | awk -F ' = ' '{print $2}'
	else
		md5sum -b "${file}" 2>/dev/null | awk '{print $1}'
	fi
}
export -f file_md5

function file_sha1()
{
	if [ -z "${1+x}" ]; then
		echo "[func file_sha1] usage: <func> src_path" >&2
		return 1
	fi

	local file="$1"
	sha1sum "${file}" 2>/dev/null | awk '{print $1}'
}
export -f file_sha1

function file_mtime()
{
	if [ -z "${1+x}" ]; then
		echo "[func file_mtime] usage: <func> file_path" >&2
		return 1
	fi

	local file="$1"

	if [ ! -f "${file}" ]; then
		echo '0'
		return
	fi

	if [ `uname` == "Darwin" ]; then
		gstat -c %Y "${file}"
	else
		stat -c %Y "${file}"
	fi
}
export -f file_mtime
