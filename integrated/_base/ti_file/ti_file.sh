#!/bin/bash

function get_tiflash_addr_from_dir()
{
	if [ -z "${1+x}" ]; then
		echo "[func get_tiflash_addr_from_dir] usage: <func> tiflash_dir" >&2
		return 1
	fi
	local dir="${1}"
	local host=`cat "${dir}/proc.info" | { grep 'listen_host' || test $? = 1; } | awk -F '\t' '{print $2}'`
	local port=`cat "${dir}/proc.info" | { grep 'raft_and_cop_port' || test $? = 1; } | awk -F '\t' '{print $2}'`
	echo "${host}:${port}"
}
export -f get_tiflash_addr_from_dir

function ti_file_exe()
{
	local help="[func ti_file_exe] usage: <func> cmd ti_file conf_templ_dir cmd_dir [ti_file_args(k=v#k=v#..)] [mod_names] [hosts] [byhost] [local] [cache_dir] [cmd_args...]"
	if [ -z "${3+x}" ]; then
		echo "${help}" >&2
		return 1
	fi

	local cmd="${1}"
	local ti_file="${2}"
	local conf_templ_dir="${3}"
	local cmd_dir="${4}"

	if [ -z "${5+x}" ]; then
		local ti_args=""
	else
		local ti_args="${5}"
	fi

	if [ -z "${6+x}" ]; then
		local mod_names=""
	else
		local mod_names="${6}"
	fi

	if [ -z "${7+x}" ]; then
		local cmd_hosts=""
	else
		local cmd_hosts="${7}"
	fi

	if [ -z "${8+x}" ]; then
		local indexes=""
	else
		local indexes="${8}"
	fi

	if [ -z "${9+x}" ]; then
		local cache_dir="/tmp/ti"
	else
		local cache_dir="${9}"
	fi

	shift 9

	if [ "${cmd}" == "up" ]; then
		local cmd="run"
	fi
	if [ "${cmd}" == "down" ]; then
		local cmd="stop"
	fi

	local error_handle="$-"
	set +u
	local cmd_args=("${@}")
	restore_error_handle_flags "${error_handle}"

	if [ ! -f "${ti_file}" ]; then
		if [ -d "${ti_file}" ]; then
			echo "[func ti_file_exe] '${ti_file}' is dir, not a file" >&2
		else
			echo "[func ti_file_exe] '${ti_file}' not exists" >&2
		fi
		return 1
	else
		local ti_file=`abs_path "${ti_file}"`
	fi

	local here="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`"

	# For ti file checking
	python "${here}/ti_file.py" 'hosts' \
		"${ti_file}" "${integrated}" "${conf_templ_dir}" "${cache_dir}" "${mod_names}" "${cmd_hosts}" "${indexes}" "${ti_args}" 1>/dev/null

	local hosts=`python "${here}/ti_file.py" 'hosts' \
		"${ti_file}" "${integrated}" "${conf_templ_dir}" "${cache_dir}" "${mod_names}" "${cmd_hosts}" "${indexes}" "${ti_args}"`

	# TODO: Pass paths from args
	local local_cache_env="${cache_dir}/master/integrated"
	local remote_env_parent="${cache_dir}/worker"
	local remote_env="${remote_env_parent}/`basename ${local_cache_env}`"

	local script=''
	local local='false'
	local byhost='false'
	if [ -f "${cmd_dir}/${cmd}.sh" ]; then
		local script="${cmd_dir}/${cmd}.sh"
	elif [ -f "${cmd_dir}/${cmd}.sh.local" ]; then
		local local='true'
		local script="${cmd_dir}/${cmd}.sh.local"
	elif [ -f "${cmd_dir}/${cmd}.sh.byhost" ]; then
		local byhost='true'
		local script="${cmd_dir}/${cmd}.sh.byhost"
	elif [ -f "${cmd_dir}/${cmd}.sh.local.byhost" ]; then
		local local='true'
		local byhost='true'
		local script="${cmd_dir}/${cmd}.sh.local.byhost"
	fi

	local summary="${cmd_dir}/${cmd}.sh.summary"
	if [ ! -f "${cmd_dir}/${cmd}.sh.summary" ]; then
		local summary=''
	fi

	local has_func=`func_exists "ti_file_cmd_${cmd}"`
	if [ -z "${script}" ] && [ -z "${summary}" ] && [ "${has_func}" != 'true' ] && [ "${cmd}" != 'run' ] && [ "${cmd}" != 'dry' ] && [ "${cmd}" != 'predeploy' ]; then
		echo "none of this scripts can be found:" >&2
		echo "  ${cmd_dir}/${cmd}.sh" >&2
		echo "  ${cmd_dir}/${cmd}.sh.summary" >&2
		echo "  ${cmd_dir}/${cmd}.sh.local" >&2
		echo "  ${cmd_dir}/${cmd}.sh.byhost" >&2
		echo "  ${cmd_dir}/${cmd}.sh.local.byhost" >&2
		return 1
	fi

	if [ ! -z "${script}" ]; then
		local cmd_dir=`abs_path "${cmd_dir}"`
		# TODO: assert ${cmd_dir} must under ${integrated}
		local cmd_dir_rel="${cmd_dir:${#integrated}}"
		local script=`abs_path "${script}"`
		local remote_script="${script:${#cmd_dir}}"
		local remote_script="${remote_env}${cmd_dir_rel}${remote_script}"
	fi

	local do_deploy='true'
	if [ "${cmd}" != 'predeploy' ] && [ "${cmd}" != 'run' ] && [ "${cmd}" != 'up' ]; then
		local do_deploy='false'
	fi
	if [ "${local}" == 'true' ]; then
		local do_deploy='false'
	fi
	if [ -z "${script}" ] && [ ! -z "${summary}" ]; then
		local do_deploy='false'
	fi

	if [ "${do_deploy}" == 'true' ]; then
		# TODO: Parallel ping and copy
		echo "${hosts}" | while read host; do
			if [ ! -z "${host}" ] && [ "${host}" != '127.0.0.1' ] && [ "${host}" != 'localhost' ]; then
				ssh_ping "${host}"
			fi
		done
		echo "${hosts}" | while read host; do
			if [ ! -z "${host}" ] && [ "${host}" != '127.0.0.1' ] && [ "${host}" != 'localhost' ]; then
				cp_env_to_host "${integrated}" "${local_cache_env}" "${host}" "${remote_env_parent}"
			fi
		done
	fi

	if [ "${cmd}" == 'predeploy' ]; then
		echo "script env deploying done"
		return
	fi

	if [ "${byhost}" != 'true' ]; then
		if [ "${cmd}" == 'run' ] || [ "${cmd}" == 'dry' ]; then
			if [ "${cmd}" == 'dry' ]; then
				local rendered="${ti_file}.sh"
			else
				local base_name=`basename "${ti_file}"`
				local render_dir="/tmp/ti/cache/run"
				mkdir -p "${render_dir}"
				local rendered="${render_dir}/${base_name}.`date +%s`.${RANDOM}.sh"
			fi
			python "${here}/ti_file.py" 'render' "${ti_file}" "${integrated}" "${conf_templ_dir}" \
				"${cache_dir}" "${mod_names}" "${cmd_hosts}" "${indexes}" "${ti_args}" > "${rendered}"
			chmod +x "${rendered}"
			if [ "${cmd}" == "run" ]; then
				bash "${rendered}"
				rm -f "${rendered}"
			fi
			return 0
		fi

		local mods=`python "${here}/ti_file.py" 'mods' "${ti_file}" "${integrated}" "${conf_templ_dir}" \
			"${cache_dir}" "${mod_names}" "${cmd_hosts}" "${indexes}" "${ti_args}"`

		echo "${mods}" | while read mod; do
			if [ -z "${mod}" ]; then
				continue
			fi
			local index=`echo "${mod}" | awk -F '\t' '{print $1}'`
			local name=`echo "${mod}" | awk -F '\t' '{print $2}'`
			local dir=`echo "${mod}" | awk -F '\t' '{print $3}'`
			local conf=`echo "${mod}" | awk -F '\t' '{print $4}'`
			local host=`echo "${mod}" | awk -F '\t' '{print $5}'`

			if [ -z "${host}" ] || [ "${host}" == '127.0.0.1' ] || [ "${host}" == 'localhost' ]; then
				local local='true'
			fi

			if [ ! -z "${script}" ]; then
				if [ "${local}" == 'true' ]; then
					if [ -z "${host}" ]; then
						local host=`must_print_ip`
					fi
					local dir=`abs_path "${dir}"`
					if [ -z "${cmd_args+x}" ]; then
						bash "${script}" "${index}" "${name}" "${dir}" "${conf}" "${host}"
					else
						bash "${script}" "${index}" "${name}" "${dir}" "${conf}" "${host}" "${cmd_args[@]}"
					fi
				else
					if [ -z "${cmd_args+x}" ]; then
						call_remote_func "${host}" "${remote_env}" script_exe "${remote_script}" \
							"${index}" "${name}" "${dir}" "${conf}" "${host}"
					else
						call_remote_func "${host}" "${remote_env}" script_exe "${remote_script}" \
							"${index}" "${name}" "${dir}" "${conf}" "${host}" "${cmd_args[@]}"
					fi
				fi
				continue
			fi
			if [ "${has_func}" == 'true' ]; then
				if [ -z "${host}" ] || [ "${host}" == '127.0.0.1' ] || [ "${host}" == 'localhost' ] || [ "${local}" == 'true' ]; then
					if [ -z "${cmd_args+x}" ]; then
						"ti_file_cmd_${cmd}" "${index}" "${name}" "${dir}" "${conf}" "${host}"
					else
						"ti_file_cmd_${cmd}" "${index}" "${name}" "${dir}" "${conf}" "${host}" "${cmd_args[@]}"
					fi
				else
					if [ -z "${cmd_args+x}" ]; then
						call_remote_func "${host}" "${remote_env}" "ti_file_cmd_${cmd}" "${index}" "${name}" \
							"${dir}" "${conf}" "${host}"
					else
						call_remote_func "${host}" "${remote_env}" "ti_file_cmd_${cmd}" "${index}" "${name}" \
							"${dir}" "${conf}" "${host}" "${cmd_args[@]}"
					fi
				fi
				continue
			fi
		done

		if [ ! -z "${summary}" ]; then
			if [ -z "${cmd_args+x}" ]; then
				bash "${summary}" "${ti_file}" "${ti_args}" "${mod_names}" "${cmd_hosts}" "${indexes}" "${mods}"
			else
				bash "${summary}" "${ti_file}" "${ti_args}" "${mod_names}" "${cmd_hosts}" "${indexes}" "${mods}" "${cmd_args[@]}"
			fi
		fi
	else
		echo "${hosts}" | while read host; do
			if [ -z "${host}" ]; then
				local host='127.0.0.1'
			fi
			if [ -z "${host}" ] || [ "${host}" == '127.0.0.1' ] || [ "${host}" == 'localhost' ]; then
				local local='true'
			fi
			if [ "${local}" == 'true' ]; then
				if [ -z "${cmd_args+x}" ]; then
					bash "${script}" "${host}"
				else
					bash "${script}" "${host}" "${cmd_args[@]}"
				fi
			else
				if [ -z "${cmd_args+x}" ]; then
					call_remote_func "${host}" "${remote_env}" script_exe "${remote_script}" "${host}"
				else
					call_remote_func "${host}" "${remote_env}" script_exe "${remote_script}" "${host}" "${cmd_args[@]}"
				fi
			fi
		done

		if [ ! -z "${summary}" ]; then
			if [ -z "${cmd_args+x}" ]; then
				bash "${summary}" "${ti_file}" "${ti_args}" "${mod_names}" "${cmd_hosts}" "${indexes}" "${hosts}"
			else
				bash "${summary}" "${ti_file}" "${ti_args}" "${mod_names}" "${cmd_hosts}" "${indexes}" "${hosts}" "${cmd_args[@]}"
			fi
		fi
	fi
}
export -f ti_file_exe

function split_ti_args()
{
	if [ -z "${1+x}" ]; then
		echo "[func split_ti_args] usage: <func> args" >&2
		return 1
	fi

	local args_str="${1}"
	local args=(${args_str//#/ })
	for arg in "${args[@]}"; do
		echo "${arg}"
	done
}
export -f split_ti_args
