#!/bin/bash

function ssh_prepare_run()
{
	if [ -z "${9+x}" ]; then
		echo "[func ssh_prepare_run] usage: <func> host mod_name dir conf_templ_dir cache_dir remote_env version branch hash" >&2
		return 1
	fi

	local host="${1}"
	local name="${2}"
	local dir="${3}"
	local conf_templ_dir="${4}"
	local cache_dir="${5}"
	local remote_env="${6}"
	local version="${7}"
	local branch="${8}"
	local hash="${9}"

	# TODO: Tidy up these paths
	local bin_paths_file="${conf_templ_dir}/bin.paths"
	local bin_urls_file="${conf_templ_dir}/bin.urls"
	local bin_name=`get_bin_name_from_conf "${name}" "${bin_paths_file}" "${bin_urls_file}"`

	# TODO: Tidy up these paths
	cp_bin_to_host "${name}" "${host}" "${remote_env}" "${cache_dir}/worker/bins" "${bin_paths_file}" "${bin_urls_file}" "${cache_dir}" "${version}" "${branch}" "${hash}"
	call_remote_func "${host}" "${remote_env}" cp_when_diff "${cache_dir}/worker/bins/${bin_name}" "${dir}/${bin_name}"
}
export -f ssh_prepare_run
