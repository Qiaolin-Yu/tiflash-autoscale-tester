#!/bin/bash

function get_bin_md5_from_conf()
{
	if [ -z "${2+x}" ]; then
		echo "[func get_bin_md5_from_conf] usage: <func> mod_name bin_urls_file" >&2
		return 1
	fi
	local name="${1}"
	local bin_urls_file="${2}"

	local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
	if [ ! -z "$entry_str" ]; then
		echo "${entry_str}" | awk '{print $2}'
	fi
}
export -f get_bin_md5_from_conf

function get_bin_name_from_conf()
{
	if [ -z "${3+x}" ]; then
		echo "[func get_bin_name_from_conf] usage: <func> mod_name bin_paths_file bin_urls_file" >&2
		return 1
	fi

	local name="${1}"
	local bin_paths_file="${2}"
	local bin_urls_file="${3}"

	local entry_str=`cat "${bin_paths_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
	local bin_name=`echo "${entry_str}" | awk '{print $2}'`
	if [ -z "${bin_name}" ]; then
		local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
		local bin_name=`echo "${entry_str}" | awk '{print $3}'`
		if [ -z "${bin_name}" ]; then
			echo "[func get_bin_name_from_conf] ${name} not found in ${bin_paths_file} or in ${bin_urls_file}" >&2
			return 1
		fi
	fi
	echo "${bin_name}"
}
export -f get_bin_name_from_conf

# bin_paths_file: name \t bin_name \t path1:path2:...
function cp_bin_to_dir_from_paths()
{
	if [ -z "${4+x}" ]; then
		echo "[func cp_bin_to_dir_from_paths] usage: <func> name_of_bin_module dest_dir bin_paths_file cache_dir" >&2
		return 1
	fi

	local name="${1}"
	local dest_dir="${2}"
	local bin_paths_file="${3}"
	local cache_dir="${4}"
	local bin_cache_dir="${cache_dir}/master/bins"

	local entry_str=`cat "${bin_paths_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`

	local bin_name=`echo "${entry_str}" | awk '{print $2}'`
	# Check whether DEFAULT_BIN_PATH is overrided in `ops/conf.sh` and try to copy binary
	if [ ! -z "${DEFAULT_BIN_PATH+x}" ] && [ -f "${DEFAULT_BIN_PATH}/${bin_name}" ]; then
		cp_when_diff "${DEFAULT_BIN_PATH}/${bin_name}" "${bin_cache_dir}/${bin_name}"
		cp_when_diff "${bin_cache_dir}/${bin_name}" "${dest_dir}/${bin_name}"
		echo 'true'
		return
	fi

	# Check bin.paths and try to copy binary
	local paths_str=`echo "${entry_str}" | awk '{print $3}'`
	local found="false"
	if [ ! -z "${paths_str}" ]; then
		local paths=(${paths_str//:/ })
		for path in ${paths[@]}; do
			# TODO: Pass integrated dir from args
			local path=`replace_substr "${path}" '{integrated}' "${integrated}"`
			if [ -f "${path}" ]; then
				cp_when_diff "${path}" "${bin_cache_dir}/${bin_name}"
				cp_when_diff "${bin_cache_dir}/${bin_name}" "${dest_dir}/${bin_name}"
				local found="true"
				break
			fi
		done
	fi

	echo "${found}"
}
export -f cp_bin_to_dir_from_paths

# bin_urls_file: name \t bin_name \t path1:path2:...
function cp_bin_to_dir_from_urls()
{
	if [ -z "${4+x}" ]; then
		echo "[func cp_bin_to_dir_from_urls] usage: <func> name_of_bin_module dest_dir bin_urls_file cache_dir" >&2
		return 1
	fi

	local name="${1}"
	local dest_dir="${2}"
	local bin_urls_file="${3}"
	local cache_dir="${4}"
	local bin_cache_dir="${cache_dir}/master/bins"

	local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
	if [ -z "$entry_str" ]; then
		echo "[func cp_bin_to_dir_from_urls] ${name} not found in ${bin_paths_file} or in ${bin_urls_file}" >&2
		return 1
	fi

	local md5=`echo "${entry_str}" | awk '{print $2}'`
	local bin_name=`echo "${entry_str}" | awk '{print $3}'`
	local url=`echo "${entry_str}" | awk '{print $4}'`

	# TODO: support md5='-', means not checking md5
	if [ -f "${dest_dir}/${bin_name}" ]; then
		local old_md5=`file_md5 "${dest_dir}/${bin_name}"`
		if [ "${old_md5}" == "${md5}" ]; then
			return 0
		else
			mv -f "${dest_dir}/${bin_name}" "${dest_dir}/${bin_name}.prev"
		fi
	fi

	mkdir -p "${bin_cache_dir}"
	if [ -f "${bin_cache_dir}/${bin_name}" ]; then
		local old_md5=`file_md5 "${bin_cache_dir}/${bin_name}"`
		if [ "${old_md5}" == "${md5}" ]; then
			cp_when_diff "${bin_cache_dir}/${bin_name}" "${dest_dir}/${bin_name}"
			return 0
		fi
	fi

	local download_name="`basename ${url}`"
	local download_dir="${cache_dir}/cache/download"
	mkdir -p "${download_dir}"
	local download_path="${download_dir}/${download_name}.`date +%s`.${RANDOM}"

	local error_handle="$-"
	set +e
	#wget -nv -nd --show-progress --progress=bar:force:noscroll -P "${bin_cache_dir}" "${url}" -O "${download_path}" 2>&1
	echo "[downloading ${name} using url in file \"${url}\" ...]" >&2
	wget --quiet -nd -P "${bin_cache_dir}" "${url}" --no-check-certificate -O "${download_path}"
	local code="$?"
	restore_error_handle_flags "${error_handle}"

	if [ "${code}" != "0" ]; then
		echo "[func cp_bin_to_dir_from_urls] wget --quiet -nd -P '${bin_cache_dir}' '${url}' -O '${download_path}' failed" >&2
		rm -f "${download_path}"
		return 1
	fi
	if [ ! -f "${download_path}" ]; then
		echo "[func cp_bin_to_dir_from_urls] '${url}': wget to '${download_path}' file not found" >&2
		return 1
	fi

	local download_ext="`print_file_ext "${download_name}"`"
	local download_is_tar=`echo "${download_name}" | { grep '.tar.gz' || test $? = 1; }`
	local download_is_tgz=`echo "${download_name}" | { grep '.tgz$' || test $? = 1; }`
	local bin_name_is_tar=`echo "${bin_name}" | { grep '.tar.gz' || test $? = 1; }`

	if [ ! -z "${download_is_tar}" ]; then
		local target_tmp_path="${bin_cache_dir}/${bin_name}.`date +%s`.${RANDOM}"
		if [ -z "${bin_name_is_tar}" ]; then
			tar -O -zxf "${download_path}" > "${target_tmp_path}"
			rm -f "${download_path}"
			mv -f "${target_tmp_path}" "${bin_cache_dir}/${bin_name}"
			chmod +x "${bin_cache_dir}/${bin_name}"
			mkdir -p "${dest_dir}"
			cp_when_diff "${bin_cache_dir}/${bin_name}" "${dest_dir}/${bin_name}"
		else
			mv "${download_path}" "${bin_cache_dir}/${bin_name}"
			cp_when_diff "${bin_cache_dir}/${bin_name}" "${dest_dir}/${bin_name}"
		fi
		return 0
	fi

	# TODO: extract tgz is cache dir
	if [ -z "${download_ext}" ] || [ ! -z "${download_is_tgz}" ]; then
		mv -f "${download_path}" "${bin_cache_dir}/${bin_name}"
		local new_md5=`file_md5 "${bin_cache_dir}/${bin_name}"`
		if [ "${new_md5}" == "${md5}" ]; then
			cp_when_diff "${bin_cache_dir}/${bin_name}" "${dest_dir}/${bin_name}"
			return 0
		else
			echo "[func cp_bin_to_dir_from_urls] ${md5}(${bin_urls_file}) != ${new_md5}(${bin_cache_dir}/${bin_name}) md5 not matched" >&2
			return 1
		fi
	fi

	rm -f "${download_path}"
	echo "[func cp_bin_to_dir_from_urls] TODO: support .${download_ext} file from url" >&2
	return 1
}
export -f cp_bin_to_dir_from_urls

function copy_when_checksum_not_match()
{
	if [ -z "${2+x}" ]; then
		echo "[func replace_when_checksum_not_match] usage: <func> src_file_path dest_file_path" >&2
		return 1
	fi

	local src="${1}"
	local dest="${2}"
	# replace when binary checksum is not match
	if [ -f "${dest}" ]; then
		local new_bin_hash=`file_md5 "${src}"`
		local old_bin_hash=`file_md5 "${dest}"`
		if [ "${new_bin_hash}" == "${old_bin_hash}" ]; then
			return 0
		else
			mv -f "${dest}" "${dest}.prev"
		fi
	fi
	chmod +x "${src}"
	mkdir -p "`dirname ${dest}`"
	cp "${src}" "${dest}"
}

function get_urls_from_tiup()
{
	if [ -z "${4+x}" ]; then
		echo "[func get_urls_from_tiup] usage: <func> os arch tiup_component version" >&2
		return 1
	fi

	local os="${1}"
	local arch="${2}"
	local tiup_name="${3}"
	local version="${4}"

	local error_handle="$-"
	set +e
	local here="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`"
	local tiup_urls=`python "${here}/get_url_from_tiup.py" "${os}" "${arch}" "${tiup_name}" "${version}"`
	local code="$?"
	restore_error_handle_flags "${error_handle}"
	echo "${tiup_urls}"
	return ${code}
}
export -f get_urls_from_tiup

function cp_bin_to_dir_from_tiup_urls()
{
	# https://tiup-mirrors.pingcap.com/pd-v4.0.2-darwin-amd64.tar.gz
	if [ -z "${5+x}" ]; then
		echo "[func cp_bin_to_dir_from_tiup_urls] usage: <func> name_of_bin_module dest_dir bin_urls_file cache_dir version" >&2
		return 1
	fi

	local name="${1}"
	local dest_dir="${2}"
	local bin_urls_file="${3}"
	local cache_dir="${4}"
	local bin_cache_dir="${cache_dir}/master/bins"
	local version="${5}"

	if [[ -z "${version}" ]]; then
		return 1
	fi

	if [[ ${name} == "tidb" || ${name} == "tikv" || ${name} == "pd" ]]; then
		local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
		if [ -z "$entry_str" ]; then
			echo "[func cp_bin_to_dir_from_tiup_urls] ${name} not found in ${bin_paths_file} or in ${bin_urls_file}" >&2
			return 1
		fi
		local bin_name=`echo "${entry_str}" | awk '{print $3}'`
		local tiup_name="${name}"
	elif [[ ${name} == "tiflash" ]]; then
		local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
		if [ -z "$entry_str" ]; then
			echo "[func cp_bin_to_dir_from_tiup_urls] ${name} not found in ${bin_paths_file} or in ${bin_urls_file}" >&2
			return 1
		fi
		local bin_name=`echo "${entry_str}" | awk '{print $3}'`
		local tiup_name="tiflash"
	elif [[ ${name} == "tikv_ctl" || ${name} == "pd_ctl" ]]; then
		local bin_name=`echo ${name} | tr '_' '-'`
		local tiup_name="ctl"
	elif [[ ${name} == "tikv_importer" || ${name} == "tidb_lightning" ]]; then
		local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
		if [ -z "$entry_str" ]; then
			echo "[func cp_bin_to_dir_from_tiup_urls] ${name} not found in ${bin_paths_file} or in ${bin_urls_file}" >&2
			return 1
		fi
		local bin_name=`echo "${entry_str}" | awk '{print $3}'`
		local tiup_name=`echo ${name} | tr '_' '-'`
	else
		echo "[func cp_bin_to_dir_from_tiup_urls] ${name} can not download from tiup urls now" >&2
		return 1
	fi

	local os=`uname | tr 'A-Z' 'a-z'`
	local arch="amd64" # TODO: detect other arch

	# if version is in format 'v4.0.x', we need to resolve and update it
	local tiup_urls=`get_urls_from_tiup "${os}" "${arch}" "${tiup_name}" "${version}"`
	local version=`echo ${tiup_urls} | awk '{print $1}'`
	local url=`echo ${tiup_urls} | awk '{print $2}'`
	local sha1_url=`echo ${tiup_urls} | awk '{print $3}'`

	local download_dir="${cache_dir}/cache/download"
	mkdir -p "${download_dir}"
	local download_name="`basename ${url}`"
	local download_path="${download_dir}/${download_name}"

	# sha1 in tiup is the checksum of gzipped file
	# check whether we have download the right gzipped file or not
	local need_download="true"
	local sha1=`curl -s ${sha1_url}`
	if [ -f "${download_path}" ]; then
		local old_sha1=`file_sha1 "${download_path}"`
		if [ "${old_sha1}" == "${sha1}" ]; then
			need_download="false"
		else
			rm "${download_path}" # remove old file
		fi
	fi

	if [ x"${need_download}" == x"true" ]; then
		echo "[downloading from tiup mirror \"${url}\" ...]" >&2
		local download_path_tmp="${download_path}.`date +%s`.${RANDOM}"
		local error_handle="$-"
		set +e
		wget --quiet -nd -P "${bin_cache_dir}" "${url}" --no-check-certificate -O "${download_path_tmp}"
		local code="$?"
		restore_error_handle_flags "${error_handle}"
		if [ "${code}" != "0" ]; then
			echo "[func cp_bin_to_dir_from_tiup_urls] wget --quiet -nd -P '${bin_cache_dir}' '${url}' -O '${download_path}' failed, name=\"${name}\"" >&2
			rm -f "${download_path_tmp}"
			return 1
		fi
		mv "${download_path_tmp}" "${download_path}"
		if [ ! -f "${download_path}" ]; then
			echo "[func cp_bin_to_dir_from_tiup_urls] '${url}': wget to '${download_path}' file not found" >&2
			return 1
		fi
	fi

	local bin_name_is_tar=`echo "${bin_name}" | { grep '.tar.gz' || test $? = 1; }`
	local download_is_tar=`echo "${download_name}" | { grep '.tar.gz' || test $? = 1; }`
	if [ -z "${download_is_tar}" ]; then
		echo "[func cp_bin_to_dir_from_tiup_urls] TODO: support extra ${download_name} file from tiup" >&2
		return 1
	fi

	# if target_dir not exists or empty, clean it and extra from zipped file again
	# move the download file to the target dir and try to unpack the file if need
	local target_dir="${download_dir}/${tiup_name}-${version}-${os}-${arch}"
	if [[ ! -d "${target_dir}"  || -z "$(ls -A ${target_dir})" ]]; then
		local target_tmp_path="${download_dir}/${tiup_name}-${version}-${os}-${arch}.`date +%s`.${RANDOM}"
		mkdir -p "${target_tmp_path}"
		if [ -z "${bin_name_is_tar}" ]; then
			tar -zxf "${download_path}" -C "${target_tmp_path}"
		else
			mv "${download_path}" "${target_tmp_path}/${bin_name}"
		fi
		mv "${target_tmp_path}" "${target_dir}"
	fi
	if [[ ${name} == "tidb" || ${name} == "tikv" || ${name} == "pd" || ${name} == "tiflash" || ${name} == "tikv_ctl" || ${name} == "pd_ctl" || ${name} == "tikv_importer" || ${name} == "tidb_lightning" ]]; then
		copy_when_checksum_not_match "${target_dir}/${bin_name}" "${dest_dir}/${bin_name}"
		return 0
	else
		echo "[func cp_bin_to_dir_from_tiup_urls] TODO: support copying ${name}" >&2
		return 1
	fi
	return 1
}
export -f cp_bin_to_dir_from_tiup_urls

function warn_failpoint_is_ignore()
{
	local is_enable="$1"
	local reason="$2"
	if [[ ${is_enable} == "true" ]]; then
		echo "failpoint property in TiDB is ignored, ${reason}" >&2
	fi
}
export -f warn_failpoint_is_ignore

function cp_bin_to_dir_from_pingcap_internal()
{
	if [ -z "${7+x}" ]; then
		echo "[func cp_bin_to_dir_from_pingcap_internal] usage: <func> name_of_bin_module dest_dir bin_urls_file cache_dir version failpoint" >&2
		return 1
	fi

	local name="${1}"
	local dest_dir="${2}"
	local bin_urls_file="${3}"
	local cache_dir="${4}"
	local bin_cache_dir="${cache_dir}/master/bins"
	local branch="${5}"
	local hash="${6}"
	local failpoint="${7}"

	if [[ -z "${branch}" || -z "${hash}" ]]; then
		return 1
	fi

	# There are only images for CentOS now
	local os_type=`uname`
	if [[ "${os_type}" == 'Darwin' ]]; then
		echo "[func cp_bin_to_dir_from_pingcap_internal] platform ${os_type} is not supported, fallback to download from urls" >&2
		return 1
	fi

	local bin_name=""
	local component_name=""
	local zipped_binary_name=""
	if [[ ${name} == "tidb" || ${name} == "tikv" || ${name} == "pd" ]]; then
		#curl ${FILE_SERVER_URL}/download/builds/pingcap/tidb/${tidb_sha1}/centos7/tidb-server.tar.gz
		#curl ${FILE_SERVER_URL}/download/builds/pingcap/tikv/${tikv_sha1}/centos7/tikv-server.tar.gz
		#curl ${FILE_SERVER_URL}/download/builds/pingcap/pd/${pd_sha1}/centos7/pd-server.tar.gz
		local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
		if [ -z "$entry_str" ]; then
			echo "[func cp_bin_to_dir_from_pingcap_internal] ${name} not found in ${bin_paths_file} or in ${bin_urls_file}" >&2
			return 1
		fi
		bin_name=`echo "${entry_str}" | awk '{print $3}'`
		component_name="${name}"
		zipped_binary_name="${name}-server.tar.gz"
	elif [[ ${name} == "tiflash" ]]; then
		#curl ${FILE_SERVER_URL}/download/builds/pingcap/tiflash/${TIFLASH_BRANCH}/${tiflash_sha1}/centos7/tiflash.tar.gz
		local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
		if [ -z "$entry_str" ]; then
			echo "[func cp_bin_to_dir_from_pingcap_internal] ${name} not found in ${bin_paths_file} or in ${bin_urls_file}" >&2
			return 1
		fi
		bin_name=`echo "${entry_str}" | awk '{print $3}'`
		component_name="tiflash"
		zipped_binary_name="tiflash.tar.gz"
	elif [[ ${name} == "tikv_ctl" ]]; then 
		local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
		if [ -z "$entry_str" ]; then
			echo "[func cp_bin_to_dir_from_pingcap_internal] ${name} not found in ${bin_paths_file} or in ${bin_urls_file}" >&2
			return 1
		fi
		bin_name=`echo "${entry_str}" | awk '{print $3}'`
		component_name="tikv"
		zipped_binary_name="tikv-server.tar.gz"
	elif [[ ${name} == "pd_ctl" ]]; then
		local entry_str=`cat "${bin_urls_file}" | { grep "^${name}[[:blank:]]" || test $? = 1; }`
		if [ -z "$entry_str" ]; then
			echo "[func cp_bin_to_dir_from_pingcap_internal] ${name} not found in ${bin_paths_file} or in ${bin_urls_file}" >&2
			return 1
		fi
		bin_name=`echo "${entry_str}" | awk '{print $3}'`
		component_name="pd"
		zipped_binary_name="pd-server.tar.gz"
	else
		echo "[func cp_bin_to_dir_from_pingcap_internal] ${name} can not download from internal mirror now" >&2
		return 1
	fi

	local file_server="http://fileserver.pingcap.net"
	if [[ "${hash}" = "latest" ]]; then
		local hash=`curl -s "${file_server}/download/refs/pingcap/${component_name}/${branch}/sha1"`
	fi

	local download_dir="${cache_dir}/cache/download"
	mkdir -p "${download_dir}"
	local download_name="${component_name}.${hash}.tar.gz"
	local download_path="${download_dir}/${download_name}"

	# check whether we have downloaded the right gzipped file or not
	if [ -f "${download_path}" ]; then
		local need_download="false"
	else
		local need_download="true"
	fi

	if [ x"${need_download}" == x"true" ]; then
		if [[  ${component_name} == "tiflash" ]]; then
			local url="${file_server}/download/builds/pingcap/${component_name}/${branch}/${hash}/centos7/${zipped_binary_name}"
		else
			local url="${file_server}/download/builds/pingcap/${component_name}/${hash}/centos7/${zipped_binary_name}"
		fi
		echo "[downloading from internal mirror \"${url}\" ...]" >&2
		local download_path_tmp="${download_path}.`date +%s`.${RANDOM}"
		wget --quiet -nd -P "${bin_cache_dir}" "${url}" --no-check-certificate -O "${download_path_tmp}"
		local code="$?"
		if [ "${code}" != "0" ]; then
			echo "[func cp_bin_to_dir_from_pingcap_internal] wget --quiet -nd -P '${bin_cache_dir}' '${url}' -O '${download_path}' failed, name=\"${name}\"" >&2
			rm -f "${download_path_tmp}"

			# Retry for the commit in tikv bump version pr
			# curl ${FILE_SERVER_URL}/download/builds/pingcap/tikv/optimization/${hash}/centos7/tikv-server.tar.gz
			local url="${file_server}/download/builds/pingcap/${component_name}/optimization/${hash}/centos7/${zipped_binary_name}"
			echo "[Retry downloading from internal mirror \"${url}\" ...]" >&2
			local download_path_tmp="${download_path}.`date +%s`.${RANDOM}"
			wget --quiet -nd -P "${bin_cache_dir}" "${url}" --no-check-certificate -O "${download_path_tmp}"
			local code="$?"
			if [ "${code}" != "0" ]; then
				echo "[func cp_bin_to_dir_from_pingcap_internal] wget --quiet -nd -P '${bin_cache_dir}' '${url}' -O '${download_path}' failed, name=\"${name}\"" >&2
				rm -f "${download_path_tmp}"
				return 1
			fi
		fi
		mv "${download_path_tmp}" "${download_path}"
		if [ ! -f "${download_path}" ]; then
			echo "[func cp_bin_to_dir_from_pingcap_internal] '${url}': wget to '${download_path}' file not found" >&2
			return 1
		fi
	fi

	# if target_dir not exists or empty, clean it and extra from zipped file again
	local target_dir="${download_dir}/${component_name}-${hash}"
	local bin_name_is_tar=`echo "${bin_name}" | { grep '.tar.gz' || test $? = 1; }`

	if [[ ! -d "${target_dir}" || -z "$(ls -A ${target_dir})" ]]; then
		local target_tmp_path="${download_dir}/${component_name}-${hash}.`date +%s`.${RANDOM}"
		mkdir -p "${target_tmp_path}"
		if [[ -z "${bin_name_is_tar}" ]]; then
			tar -zxf "${download_path}" -C "${target_tmp_path}"
		else
			mv "${download_path}" "${target_tmp_path}/${bin_name}"
		fi
		mv "${target_tmp_path}" "${target_dir}"
	fi
	if [[ ${name} == "tidb" || ${name} == "tikv" || ${name} == "pd" || ${name} == "pd_ctl" || ${name} == "tikv_ctl" ]]; then
		if [[ ${name} == "tidb" && ${failpoint} == "true" ]]; then
			local failpoint_bin_file="${target_dir}/bin/tidb-server-failpoint"
			if [[ -f "${failpoint_bin_file}" ]]; then
				copy_when_checksum_not_match "${failpoint_bin_file}" "${dest_dir}/${bin_name}"
			else
				warn_failpoint_is_ignore ${failpoint} "${failpoint_bin_file} doesn't exist."
				copy_when_checksum_not_match "${target_dir}/bin/${bin_name}" "${dest_dir}/${bin_name}"
			fi
		else
			copy_when_checksum_not_match "${target_dir}/bin/${bin_name}" "${dest_dir}/${bin_name}"
		fi
	elif [[ ${name} == "tiflash" ]]; then
		copy_when_checksum_not_match "${target_dir}/${bin_name}" "${dest_dir}/${bin_name}"
	fi
}
export -f cp_bin_to_dir_from_pingcap_internal

function cp_bin_to_dir()
{
	if [ -z "${8+x}" ]; then
		echo "[func cp_bin_to_dir] usage: <func> name_of_bin_module dest_dir bin_paths_file bin_urls_file cache_dir version branch hash [check_os_type] [failpoint]" >&2
		return 1
	fi

	local name="${1}"
	local dest_dir="${2}"
	local bin_paths_file="${3}"
	local bin_urls_file="${4}"
	local cache_dir="${5}" # "/tmp/ti" by default
	local version="${6}"
	local branch="${7}"
	local hash="${8}"

	if [ -z "${9+x}" ]; then
		local check_os_type='true'
	else
		local check_os_type="${9}"
	fi

	if [ "${check_os_type}" == 'true' ] && [ `uname` == 'Darwin' ]; then
		local bin_urls_file="${bin_urls_file}.mac"
	fi

	local failpoint="${10:-"false"}"

	# 1. Find by bin.paths
	# 2. Download from tiup mirror if version is not empty
	# 3. Download from bin.urls / bin.urls.mac
	local found=`cp_bin_to_dir_from_paths "${name}" "${dest_dir}" "${bin_paths_file}" "${cache_dir}"`
	if [ "${found}" != 'true' ]; then
		local download_success=1
		# From tiup mirror
		if [[ ! -z "${version}" ]]; then
			local error_handle="$-"
			set +e
			`cp_bin_to_dir_from_tiup_urls "${name}" "${dest_dir}" "${bin_urls_file}" "${cache_dir}" "${version}"`
			download_success=$?
			restore_error_handle_flags "${error_handle}"
			warn_failpoint_is_ignore "${failpoint}" "download from tiup mirror"
		fi
		# From internal PingCAP mirror
		if [[ ! -z "${branch}" && ! -z "${hash}" ]]; then
			local error_handle="$-"
			set +e
			`cp_bin_to_dir_from_pingcap_internal "${name}" "${dest_dir}" "${bin_urls_file}" "${cache_dir}" "${branch}" "${hash}" "${failpoint}"`
			download_success=$?
			restore_error_handle_flags "${error_handle}"
		fi

		# From bin.urls / bin.urls.mac
		if [[ "${download_success}" != 0 ]]; then
			cp_bin_to_dir_from_urls "${name}" "${dest_dir}" "${bin_urls_file}" "${cache_dir}"
			warn_failpoint_is_ignore "${failpoint}" "download using url in file"
		fi
	fi
}
export -f cp_bin_to_dir

function render_templ()
{
	if [ -z "${3+x}" ]; then
		echo "[func render_templ] usage: <func> templ_file dest_file render_str(k=v#k=v#..)" >&2
		return 1
	fi

	local src="${1}"
	local dest="${2}"
	local kvs="${3}"

	local dest_dir=`dirname "${dest}"`
	mkdir -p "${dest_dir}"

	local here="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`"
	python "${here}/render_templ.py" "${kvs}" < "${src}" > "${dest}"
}
export -f render_templ
