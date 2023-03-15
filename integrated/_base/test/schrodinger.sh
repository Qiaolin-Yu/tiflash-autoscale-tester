#!/bin/bash

function _fetch_pingcap_repo()
{
	local dir="${1}"
	local repo_name="${2}"
	mkdir -p "${dir}"

	local repo="${dir}/${repo_name}"
	if [ ! -d "${repo}" ]; then
		temp_repo="${repo}.`date +%s`.${RANDOM}"
		rm -rf "${temp_repo}"
		mkdir -p "${temp_repo}"
		git clone "https://github.com/pingcap/${repo_name}" "${temp_repo}"
		mv "${temp_repo}" "${repo}"
	fi
}
export -f _fetch_pingcap_repo

function prepare_schrodinger_bin()
{
	local dir="${1}"
	local mod_name="${2}"
	local repo='schrodinger-test'
	_fetch_pingcap_repo "${dir}" "${repo}"
	(
		cd "${dir}/${repo}" && make "${mod_name}"
	)
}
export -f prepare_schrodinger_bin
