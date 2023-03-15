#!/bin/bash

# TODO: pass dir names by args
function cp_env_to_dir()
{
	if [ -z "${2+x}" ]; then
		echo "[func cp_env_to_dir] usage: <func> local_integrated_dir dest_dir" >&2
		return 1
	fi

	local integrated="${1}"
	local dest="${2}"

	mkdir -p "${dest}"
	cp -rf "${integrated}/_base" "${dest}/"
	cp -rf "${integrated}/ops" "${dest}/"
	cp -r "${integrated}/_env.sh" "${dest}/_env.sh"

	mkdir -p "${dest}/conf"
	cp -rf "${integrated}/conf" "${dest}/"
	rm -f "${dest}/conf/bin.paths"
}
export -f cp_env_to_dir

function cp_file_to_host()
{
	if [ -z "${5+x}" ]; then
		echo "[func cp_file_to_host] usage: <func> loca_src_path host remote_env_dir remote_dest_dir md5 compress(true|false)" >&2
		return 1
	fi

	local src_path="${1}"
	local host="${2}"
	local remote_env_dir="${3}"
	local remote_dest_dir="${4}"
	local md5="${5}"
	local compress="${6}"

	local file_name=`basename "${src_path}"`
	local parent_dir=`dirname "${src_path}"`
	local remote_path="${remote_dest_dir}/${file_name}"

	if [ -z "${md5}" ]; then
		local md5=`file_md5 "${src_path}"`
	fi

	local old_md5=`call_remote_func_raw "${host}" "${remote_env_dir}" file_md5 "${remote_path}"`
	if [ "$old_md5" == "${md5}" ]; then
		return 0
	fi

	ssh_exe "${host}" "mkdir -p \"${remote_dest_dir}\""

	if [ "${compress}" == "true" ]; then
		local tar_file="${file_name}.tar.gz"
		`cd "${parent_dir}" && tar -czf "${tar_file}" "${file_name}"`
		scp "${parent_dir}/${tar_file}" "${host}:${remote_dest_dir}" >/dev/null
		ssh_exe "${host}" "cd \"${remote_dest_dir}\" && tar --overwrite -xzf \"${tar_file}\" && echo \"${md5}\" >\"${remote_path}.md5\""
	else
		scp "${src_path}" "${host}:${remote_dest_dir} && echo \"${md5}\" >\"${remote_path}.md5\"" >/dev/null
	fi
}
export -f cp_file_to_host

function cp_env_to_host()
{
	if [ -z "${4+x}" ]; then
		echo "[func cp_env_to_host] usage: <func> local_integrated_dir local_cache_dir host remote_dest_dir" >&2
		return 1
	fi

	local integrated="${1}"
	local local_cache_dir="${2}"
	local host="${3}"
	local remote_dest_dir="${4}"

	cp_env_to_dir "${integrated}" "${local_cache_dir}"
	cp_dir_to_host "${local_cache_dir}" "${host}" "${remote_dest_dir}"
}
export -f cp_env_to_host

function cp_bin_to_host()
{
	if [ -z "${8+x}" ]; then
		echo "[func cp_bin_to_host] usage: <func> name_of_bin_module host remote_env_dir remote_dest_dir bin_paths_file bin_urls_file cache_dir version branch hash" >&2
		return 1
	fi

	local name="${1}"
	local host="${2}"
	local remote_env_dir="${3}"
	local remote_dest_dir="${4}"
	local bin_paths_file="${5}"
	local bin_urls_file="${6}"
	local cache_dir="${7}"
	local version="${8}"
	local branch="${9}"
	local hash="${10}"

	local host_os_type=`ssh_exe "${host}" "uname"`
	if [ "${host_os_type}" == 'Darwin' ]; then
		local bin_urls_file="${bin_urls_file}.mac"
	fi
	if [ "${host_os_type}" != `uname` ]; then
		local bin_paths_file="/dev/null"
	fi

	local bin_name=`get_bin_name_from_conf "${name}" "${bin_paths_file}" "${bin_urls_file}"`
	local md5=`get_bin_md5_from_conf "${name}" "${bin_urls_file}"`

	local cache_bin_path="${cache_dir}/master/bins/${bin_name}"

	cp_bin_to_dir "${name}" "${cache_dir}/master/bins" "${bin_paths_file}" "${bin_urls_file}" "${cache_dir}" "${version}" "${branch}" "${hash}" false

	ssh_exe "${host}" "mkdir -p \"${remote_dest_dir}\""
	rsync -qa "${cache_bin_path}" "${host}:${remote_dest_dir}/${bin_name}" >/dev/null
}
export -f cp_bin_to_host
