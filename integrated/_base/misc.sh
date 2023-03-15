#!/bin/bash

function func_exists()
{
	local has=`LC_ALL=C type ${1} 2>/dev/null | { grep 'is a function' || test $? = 1; }`
	if [ -z "${has}" ]; then
		echo 'false'
	else
		echo 'true'
	fi
}
export -f func_exists

function echo_test()
{
	local error_handle="$-"
	set +u
	local args=("${@}")
	restore_error_handle_flags "${error_handle}"

	echo "=> echo test start"
	echo "args count: ${#args[@]}"
	echo "args: ${args[@]}"
	echo "=> echo test end"
}
export -f echo_test

function get_value()
{
	if [ -z "${2+x}" ]; then
		echo "[func get_value] usage: <func> from_file key"
		return 1
	fi

	local file="${1}"
	local key="${2}"

	if [ ! -f "${file}" ]; then
		echo "[func get_value] '${file}' not exists" >&2
		return 1
	fi

	local value=`cat "${file}" | { grep "^${key}\b" || test $? = 1; } | awk '{print $2}'`
	if [ -z "${value}" ]; then
		return 1
	fi
	echo "${value}"
}
export -f get_value

# TODO: unused
function watch_file()
{
	if [ -z "${2+x}" ]; then
		echo "[func watch_file] usage: <func> file_path timeout" >&2
		return 1
	fi

	local file="${1}"
	local timeout="${2}"

	local latest_mtime=`file_mtime "${file}"`

	local unchanged_times='0'
	for (( i = 0; i < "${timeout}"; i++ )); do
		local mtime=`file_mtime "${file}"`
		if [ "${latest_mtime}" != "${mtime}" ]; then
			local unchanged_times='0'
			local latest_mtime="${mtime}"
			local i=0
			echo "changed!! #${i} < ${timeout} ${file}"
			continue
		fi
		local unchanged_times=$((unchanged_times + 1))
		echo "unchanged #${i} < ${timeout} ${file}"
		sleep 1
	done

	# TODO
}
export -f watch_file

# TODO: unused
function watch_files()
{
	if [ -z "${2+x}" ]; then
		echo "[func watch_files] usage: <func> dir_path timeout" >&2
		return 1
	fi

	local dir="${1}"
	local timeout="${2}"
	for file in "${dir}"; do
		watch_file "${file}" "${timeout}"
	done
}
export -f watch_files

function cross_platform_get_value()
{
	if [ -z "${2+x}" ]; then
		echo "[func cross_platform_get_value] usage: <func> file key"
		return 1
	fi

	local file="${1}"
	local key="${2}"
	if [ `uname` == "Darwin" ]; then
		local key="${key}_mac"
	fi

	if [ ! -f "${file}" ]; then
		echo "[func cross_platform_get_value] '${file}' not exists" >&2
		return 1
	fi

	local value=`cat "${file}" | { grep "^${key}\b" || test $? = 1; } | awk '{print $2}'`
	if [ -z "${value}" ]; then
		return 1
	fi
	echo "${value}"
}
export -f cross_platform_get_value


function local_package_get_value()
{
	if [ -z "${3+x}" ]; then
		echo "[func local_package_get_value] usage: <func> file key archive_path"
		return 1
	fi

	local file="${1}"
	local key="${2}"
	local archive_path="${3}"
	if [ `uname` == "Darwin" ]; then
		local key="${key}_mac"
	fi

	if [ ! -f "${file}" ]; then
		echo "[func local_package_get_value] '${file}' not exists" >&2
		return 1
	fi

	local value=`cat "${file}" | { grep "^${key}\b" || test $? = 1; } | awk '{print $2}'`
	if [ -z "${value}" ]; then
		return 1
	fi
	echo "${archive_path}/${value}"
}
export -f local_package_get_value

function terminal_width()
{
	stty size | awk '{print $2}'
}
export -f terminal_width

function print_hhr()
{
	echo '====================='
}
export -f print_hhr

function print_hr()
{
	echo '---------------------'
}
export -f print_hr

function print_args()
{
	if [ -z "${1+x}" ]; then
		return
	fi
	for it in "${@}"; do
		if [ "${it:0:2}" == '--' ]; then
			echo -n '--' && echo "${it:2}"
		elif [ "${it:0:1}" == '-' ]; then
			echo -n '-' && echo "${it:1}"
		else
			echo "${it}"
		fi
	done
}
export -f print_args

function esc_args()
{
	if [ ! -z "${1+x}" ]; then
		print_args "${@}" | python "${integrated}/_base/esc_args.py"
	fi
}
export -f esc_args

function print_cmd_installed()
{
	if [ -z "${1+x}" ]; then
		return
	fi
	local error_handle="$-"
	set +e
	local cmd="${1}"
	which which 1>/dev/null 2>&1
	if [ "${?}" -ne 0 ]; then
		echo "command which is not available" >&2
		echo "false"
	else
		which "${cmd}" 1>/dev/null 2>&1
		if [ "${?}" -eq 0 ]; then
			echo "true"
		else
			echo "false"
		fi
	fi
	restore_error_handle_flags "${error_handle}"
}
export -f print_cmd_installed

function print_port_occupied()
{
	if [ -z "${1+x}" ]; then
		return
	fi
	local error_handle="$-"
	set +e
	local port="${1}"

	lsof -h 1>/dev/null 2>&1
	if [ "$?" != "0" ]; then
		echo "[func print_port_occupied] lsof not installed" >&2
		restore_error_handle_flags "${error_handle}"
		return 1
	fi

	local listen_num=`lsof -i:"${port}" | grep 'LISTEN' | wc -l` 
	if [ "${listen_num}" -eq 0 ]; then
		echo "false"
	else
		echo "true"
	fi
	restore_error_handle_flags "${error_handle}"
}
export -f print_port_occupied

function _range_points()
{
	local min="${1}"
	local max="${2}"
	local times="${3}"
	local times=$(( times + 1 ))

	echo "${min}"
	if [ "${min}" -ne "${max}" ]; then
		echo "${max}"
	fi

	local mid=$(( (max - min) / 2 + min ))
	if [ "${mid}" == "${min}" ] || [ "${mid}" == "${max}" ]; then
		return
	fi

	if [ "${times}" -gt 2 ]; then
		local times=$(( times / 2 ))
		if [ "${mid}" != "${min}" ]; then
			_range_points "${min}" "${mid}" "${times}"
		fi
		if [ "${mid}" != "${max}" ]; then
			_range_points "${mid}" "${max}" "${times}"
		fi
	fi
}
export -f _range_points

function range_points()
{
	if [ -z "${3+x}" ]; then
		echo "[func range_points] usage: <func> min max rough_times" >&2
		return 1
	fi

	local min="${1}"
	local max="${2}"
	local times="${3}"

	_range_points "${min}" "${max}" "${times}" | sort -n | uniq
}
export -f range_points

function ensure_bin_in_local_dir()
{
	if [ -z "${2+x}" ] || [ -z "${1}" ] || [ -z "${2}" ]; then
		echo "[func ensure_bin_in_local_dir] usage: <func> binary_name bin_dir" >&2
		return 1
	fi
	local bin_name="${1}"
	local target_bin_dir="${2}"

	# TODO: tidy up these path	
	local conf_templ_dir="${integrated}/conf"
	local bin_paths_file="${conf_templ_dir}/bin.paths"
	local bin_urls_file="${conf_templ_dir}/bin.urls"
	local cache_dir="/tmp/ti"

	cp_bin_to_dir "${bin_name}" "${target_bin_dir}" "${bin_paths_file}" "${bin_urls_file}" "${cache_dir}" "" "" "" 'true'
}
export -f ensure_bin_in_local_dir

function download_test_binary()
{
	if [ -z "${3+x}" ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]; then
		echo "[func download_test_binary] usage: <func> binary_url binary_file_name bin_dir" >&2
		return 1
	fi
	local binary_url="${1}"
	local binary_file_name="${2}"
	local bin_dir="${3}"

	mkdir -p "${bin_dir}"
	local download_path="${bin_dir}/${binary_file_name}.tar.gz.`date +%s`.${RANDOM}"
	# TODO: refine all download process in ops to avoid multi-thread hazard
	if [ ! -f "${bin_dir}/${binary_file_name}.tar.gz" ]; then
		wget --quiet -nd "${binary_url}" -O "${download_path}"
		mv "${download_path}" "${bin_dir}/${binary_file_name}.tar.gz"
	fi
	if [ ! -f "${bin_dir}/${binary_file_name}" ]; then
		tar -zxf "${bin_dir}/${binary_file_name}.tar.gz" -C "${bin_dir}"
	fi
}
export -f download_test_binary

function copy_test_binary()
{
	if [ -z "${3+x}" ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]; then
		echo "[func copy_test_binary] usage: <func> binary_from_path binary_file_name bin_dir" >&2
		return 1
	fi
	local binary_from_path="${1}"
	local binary_file_name="${2}"
	local bin_dir="${3}"

	mkdir -p "${bin_dir}"
	# TODO: refine all download process in ops to avoid multi-thread hazard
	if [ ! -f "${bin_dir}/${binary_file_name}.tar.gz" ]; then
		cp "${binary_from_path}" "${bin_dir}/${binary_file_name}.tar.gz"
	fi
	if [ ! -f "${bin_dir}/${binary_file_name}" ]; then
		tar -zxf "${bin_dir}/${binary_file_name}.tar.gz" -C "${bin_dir}"
	fi
}
export -f copy_test_binary

function bash_conf_write()
{
	if [ -z "${3+x}" ]; then
		echo "[func bash_conf_write] usage: <func> file-path key value" >&2
		return 1
	fi

	local file="${1}"
	local key="${2}"
	local value="${3}"

	local tmp="${file}.tmp"
	cat "${file}" | { grep -v "${key}" || test $? = 1; } > "${tmp}"
	echo "export ${key}='"${value}"'" >> "${tmp}"
	mv -f "${tmp}" "${file}"
}
export -f bash_conf_write

function bash_conf_get()
{
	if [ -z "${2+x}" ]; then
		echo "[func bash_conf_get] usage: <func> file-path key" >&2
		return 1
	fi

	local file="${1}"
	local key="${2}"

	local value=`cat "${file}" | { grep "${key}" || test $? = 1; } | awk -F '=' '{print $2}'`
	if [ -z "${value}" ]; then
		echo "(not set)"
	else
		local value=`echo "${value}" | tr -d '"' | tr -d "'"`
		echo "${value}"
	fi
}
export -f bash_conf_get
