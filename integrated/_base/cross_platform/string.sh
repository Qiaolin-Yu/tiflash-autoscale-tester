#!/bin/bash

function sed_inplace()
{
	if [ -z "${1+x}" ]; then
		echo "[func sed_inplace] usage: <func> is an alias of 'sed -i ...'" >&2
		return 1
	fi

	if [ `uname` == "Darwin" ]; then
		sed -i "" "${@}"
	else
		sed -i "${@}"
	fi
}
export -f sed_inplace

function sed_eres()
{
	if [ -z "${1+x}" ]; then
		echo "[func sed_eres] usage: <func> is an alias of 'sed -r ...' for using Extended Regular Expression instead of Basic Regular Expression" >&2
		return 1
	fi

	if [ `uname` == "Darwin" ]; then
		sed -E "${@}"
	else
		sed -r "${@}"
	fi
}
export -f sed_eres

function replace_substr()
{
	if [ -z "${3+x}" ]; then
		echo "[func replace_substr] usage: <func> src_str old_substr(the target part of the src) new_substr" >&2
		return 1
	fi

	local src="${1}"
	local old="${2}"
	local new="${3}"
	echo "${src}" | sed "s?${old}?${new}?g"
}
export -f replace_substr
