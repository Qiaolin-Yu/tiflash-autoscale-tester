#!/bin/bash

function _ti_file_cmd_list()
{
	local dir="${1}"

	if [ ! -z "${2+x}" ] && [ ! -z "${2}" ]; then
		local matching="${2}"
	else
		local matching=''
	fi

	if [ ! -z "${3+x}" ] && [ ! -z "${3}" ]; then
		local parent="${3}/"
	else
		local parent=''
	fi

	if [ ! -z "${4+x}" ] && [ ! -z "${4}" ]; then
		local show_help="${4}"
	else
		if [ -z "${matching}" ] && [ -z "${parent}"  ]; then
			local show_help="false"
		else
			local show_help='true'
		fi
	fi

	ls "${dir}" | while read f; do
		if [ "${f:0:1}" == '_' ] || [ "${f}" == 'help' ]; then
			continue
		fi
		if [ -z "${parent}" ] && [ "${f}" == 'global' ]; then
			continue
		fi
		if [ ! -z "${matching}" ]; then
			local matched=`echo "${parent}${f}" | { grep "${matching%/*}" || test $? = 1; }`
			if [ -z "${matched}" ]; then
				continue
			fi
		fi
		local has_help_ext=`echo "${f}" | { grep "help$" || test $? = 1; }`
		if [ ! -z "${has_help_ext}" ] && [ -f "${dir}/${f}" ]; then
			local name=`basename "${f}" .help`
			local has_sum_ext=`echo "${name}" | { grep "summary$" || test $? = 1; }`
			local name=`basename "${name}" .summary`
			local has_byhost_ext=`echo "${name}" | { grep "byhost$" || test $? = 1; }`
			local name=`basename "${name}" .byhost`
			local has_local_ext=`echo "${name}" | { grep "local$" || test $? = 1; }`
			local name=`basename "${name}" .local`
			local name=`basename "${name}" .sh`

			local cmd_type=''
			if [ ! -z "${has_sum_ext}" ]; then
				local cmd_type="cmd type: summary"
			elif [ ! -z "${has_byhost_ext}" ]; then
				if [ ! -z "${has_local_ext}" ]; then
					local cmd_type="cmd type: byhost, local"
				else
					local cmd_type="cmd type: byhost"
				fi
			elif [ ! -z "${has_local_ext}" ]; then
				local cmd_type="cmd type: local"
			fi

			echo "${parent}${name}"
			if [ "${show_help}" == 'true' ]; then
				cat "${dir}/${f}" | awk '{print "    "$0}'
				if [ ! -z "${cmd_type}" ]; then
					echo "    ${cmd_type}"
				fi
			fi
			continue
		fi
		if [ -d "${dir}/${f}" ] && [ "${f}" != 'byhost' ]; then
			if [ "${show_help}" == 'true' ] && [ -f "${dir}/${f}/help" ]; then
				echo "${f}/*"
				cat "${dir}/${f}/help" | awk '{print "    "$0}'
			fi
			_ti_file_cmd_list "${dir}/${f}" "${matching#*/}" "${parent}${f}" "${show_help}"
		fi
	done
}
export -f _ti_file_cmd_list

function ti_file_help_cmds()
{
	local dir="${1}"
	if [ ! -z "${2+x}" ] && [ ! -z "${2}" ]; then
		local matching="${2}"
	else
		local matching=''
	fi
	_ti_file_cmd_list "${dir}" "${matching}" ''
}
export -f ti_file_help_cmds

function ti_file_cmd_default_help()
{
	echo "ti.sh example"
	echo "    - shows a simple example about how to use this tool"
	echo "ti.sh help [matching_string]"
	echo "    - list global cmds and their helps"
	echo "ti.sh [flags] my.ti cmds [matching_string]"
	echo "    - list the cmds can be used on the cluster defined by my.ti"
	echo "ti.sh flags"
	echo "    - detail usage of flags"
}
export -f ti_file_cmd_default_help

function ti_file_global_cmd_flags()
{
	echo 'usage: ops/ti.sh [mods_selector] [conf_flags] ti_file_path cmd [args]'
	echo
	echo 'example: ops/ti.sh my.ti run'
	echo '    cmd:'
	echo '        could be one of run|stop|fstop|status|burn|...'
	echo '        (`up` and `down` are aliases of `run` and `stop`)'
	echo '        and could be one script of `{integrated}/ops/ti.sh.cmds/<command>.sh[.summary][.local][.byhost]`'
	echo '        the ext name `.byhost` means execute script on each host(node), instead of on each module.'
	echo '        the ext name `.local` means execute script on current host, instead of on remote host.'
	echo '        the ext name `.summary` means only execute script once on current host, instead of once of each module/host.'
	echo '    args:'
	echo '        the args pass to the command script.'
	echo '        format `cmd1:cmd2:cmd3` can be used to execute commands sequently, if all args are empty.'
	echo
	echo 'the selecting flags below are for selecting mods from the .ti file defined a cluster.'
	echo 'example: ops/ti.sh -m pd -i 0,2 my.ti stop'
	echo '    -m:'
	echo '        the module name, could be one of pd|tikv|tidb|tiflash|sparkm|sparkw.'
	echo '        and could be multi modules like: `pd,tikv`.'
	echo '        if this arg is not provided, it means all modules.'
	echo '    -h:'
	echo '        the host names, format: `host,host,..`'
	echo '        if this arg is not provided, it means all specified host names in the .ti file.'
	echo '    -i:'
	echo '        specify the module index, format: `1,4,3`.'
	echo '        eg, 3 tikvs in a cluster, then we have tikv[0], tikv[1], tikv[2].'
	echo '        if this arg is not provided, it means all.'
	echo
	echo 'the configuring flags below are rarely used.'
	echo 'example: ops/ti.sh -c /data/my_templ_dir -s /data/my_cmd_dir -t /tmp/my_cache_dir -k foo=bar my.ti status'
	echo '    -k:'
	echo '        specify the key-value(s) string, will be used as vars in the .ti file, format: k=v#k=v#..'
	echo '    -c:'
	echo '        specify the config template dir, will be `{integrated}/conf` if this arg is not provided.'
	echo '    -s:'
	echo '        specify the sub-command dir, will be `{integrated}/ops/ti.sh.cmds/remote` if this arg is not provided.'
	echo '    -t:'
	echo '        specify the cache dir for download bins and other things in all hosts.'
	echo '        will be `/tmp/ti` if this arg is not provided.'
}
export -f ti_file_global_cmd_flags

function ti_file_exe_global_cmd()
{
	if [ -z "${2+x}" ]; then
		echo "[func ti_file_exe_global_cmd] usage: <func> cmd cmd_dir" >&2
		return
	fi

	local cmd="${1}"
	local cmd_dir="${2}"
	shift 2

	if [ "${cmd}" == 'help' ]; then
		if [ -z "${1+x}" ]; then
			ti_file_help_cmds "${cmd_dir}/global"
		else
			local cmd_args=("${@}")
			ti_file_help_cmds "${cmd_dir}/global" "${cmd_args[@]}"
		fi
		return
	fi

	local has_func=`func_exists "ti_file_global_cmd_${cmd}"`
	if [ "${has_func}" == 'true' ]; then
		if [ -z "${1+x}" ]; then
			"ti_file_global_cmd_${cmd}"
		else
			local cmd_args=("${@}")
			"ti_file_global_cmd_${cmd}" "${cmd_args[@]}"
		fi
		return
	fi

	if [ -f "${cmd_dir}/global/${cmd}.sh" ]; then
		if [ -z "${1+x}" ]; then
			bash "${cmd_dir}/global/${cmd}.sh"
		else
			local cmd_args=("${@}")
			bash "${cmd_dir}/global/${cmd}.sh" "${cmd_args[@]}"
		fi
		return
	fi

	echo "error: unknown cmd '${cmd}', usage: "
	ti_file_cmd_default_help | awk '{print "    "$0}'
	return 1
}
export -f ti_file_exe_global_cmd

function cmd_ti()
{
	if [ -z "${1+x}" ]; then
		ti_file_cmd_default_help
		return
	fi

	local conf_templ_dir="${integrated}/conf"
	local cmd_dir="${integrated}/ops/ti.sh.cmds"
	local cache_dir="/tmp/ti"
	local mods=""
	local hosts=""
	local ti_args=""
	local indexes=""

	while getopts ':k:c:m:s:h:i:t:bl' OPT; do
		case ${OPT} in
			c)
				local conf_templ_dir="${OPTARG}";;
			s)
				local cmd_dir="${OPTARG}";;
			t)
				local cache_dir="${OPTARG}";;
			m)
				local mods="${OPTARG}";;
			h)
				local hosts="${OPTARG}";;
			i)
				local indexes="${OPTARG}";;
			k)
				local ti_args="${OPTARG}";;
			?)
				echo '[func cmd_ti] illegal option(s)' >&2
				echo '' >&2
				ti_file_cmd_default_help >&2
				return 1;;
		esac
	done
	shift $((${OPTIND} - 1))

	local ext=`print_file_ext "${1}"`
	if [ "${ext}" != 'ti' ]; then
		local ti_file=''
	else
		local ti_file="${1}"
		shift 1
	fi

	auto_error_handle

	if [ -z "${ti_file}" ] && [ -z "${1+x}" ]; then
		ti_file_cmd_default_help "${cmd_dir}" >&2
		return 1
	fi

	if [ ! -z "${1+x}" ]; then
		if [ "${1}" == 'parallel' ] || [ "${1}" == 'must' ] || [ "${1}" == 'repeat' ] || [ "${1}" == 'loop' ] || [ "${1}" == 'floop' ]; then
			local cmd="${1}"
			shift 1
			if [ -z "${1}" ] || [ -z "${ti_file}" ]; then
				echo "[?] TODO: put some help here"
				return 1
			fi
			ti_file_exe "${cmd}" "${ti_file}" "${conf_templ_dir}" "${cmd_dir}" "${ti_args}" \
				"${mods}" "${hosts}" "${indexes}" "${cache_dir}" "${@}"
			return
		fi
	fi

	if [ ! -z "${1+x}" ]; then
		local cmds_and_args=`unfold_cmd_chain "${@}"`
	else
		local cmds_and_args=''
	fi

	if [ -z "${cmds_and_args}" ]; then
		if [ -z "${1+x}" ]; then
			local cmd='status'
		else
			local cmd="${1}"
			shift 1
		fi
		if [ -z "${ti_file}" ]; then
			if [ ! -z "${1+x}" ]; then
				ti_file_exe_global_cmd "${cmd}" "${cmd_dir}" "${@}"
			else
				ti_file_exe_global_cmd "${cmd}" "${cmd_dir}"
			fi
		else
			if [ ! -z "${1+x}" ]; then
				ti_file_exe "${cmd}" "${ti_file}" "${conf_templ_dir}" "${cmd_dir}" "${ti_args}" \
					"${mods}" "${hosts}" "${indexes}" "${cache_dir}" "${@}"
			else
				ti_file_exe "${cmd}" "${ti_file}" "${conf_templ_dir}" "${cmd_dir}" "${ti_args}" \
					"${mods}" "${hosts}" "${indexes}" "${cache_dir}"
			fi
		fi
		return
	fi

	local cmds_cnt=`echo "${cmds_and_args}" | wc -l | awk '{print $1}'`

	echo "${cmds_and_args}" | while read cmd_and_args; do
		local cmd=`echo "${cmd_and_args}" | awk -F '\t' '{print $1}'`
		local cmd_args=`echo "${cmd_and_args}" | awk -F '\t' '{print $2}'`

		if [ "${cmds_cnt}" != 1 ]; then
			print_hhr
			if [ -z "${cmd_args}" ]; then
				local cmd_display="${cmd}"
			else
				local cmd_display="${cmd} ${cmd_args}"
			fi
			echo ":: ${cmd_display}"
			print_hr
		fi

		if [ -z "${ti_file}" ]; then
			eval "ti_file_exe_global_cmd \"${cmd}\" \"${cmd_dir}\" ${cmd_args}"
		else
			eval "ti_file_exe \"${cmd}\" \"${ti_file}\" \"${conf_templ_dir}\" \"${cmd_dir}\" \"${ti_args}\" \
				\"${mods}\" \"${hosts}\" \"${indexes}\" \"${cache_dir}\" ${cmd_args}"
		fi
	done
}
export -f cmd_ti
