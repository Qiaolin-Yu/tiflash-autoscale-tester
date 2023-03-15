#!/bin/bash

function _print_file_dir_when_abs()
{
	local path="${1}"
	if [ "${path:0:1}" == '/' ]; then
		dirname "${path}"
	else
		echo "${path}"
	fi
}
export -f _print_file_dir_when_abs

function print_file_ext()
{
	if [ -z "${1+x}" ]; then
		echo "[func print_file_ext] usage: <func> file" >&2
		return 1
	fi

	local file="${1}"

	local name="${file##*\/}"
	local ext="${file##*\.}"
	if [ ".""${ext}" == "${name}" ]; then
		ext=""
	fi
	echo "${ext}"
}
export -f print_file_ext
