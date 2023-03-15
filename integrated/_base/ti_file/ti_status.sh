#!/bin/bash

function _print_mod_info()
{
	local dir="${1}"
	if [ -d "${dir}" ] && [ -f "${dir}/proc.info" ]; then
		local cluster_id=`cat "${dir}/proc.info" | { grep 'cluster_id' || test $? = 1; } | awk -F '\t' '{print $2}'`
	else
		local cluster_id=''
	fi
	if [ ! -z "${cluster_id}" ]; then
		echo "   [deployed from ${cluster_id}] ${dir}"
	else
		echo "   [unmanaged by ops-ti] ${dir}"
	fi
}
export -f _print_mod_info

function ls_tiflash_proc()
{
	local procs=`print_procs 'tiflash' "\-\-config\-file" | awk -F '--config-file' '{print $2}' | awk '{print $1}'`
	if [ ! -z "${procs}" ]; then
		echo "${procs}" | while read conf; do
			local path=`_print_file_dir_when_abs "${conf}"`
			local path=`_print_file_dir_when_abs "${path}"`
			_print_mod_info "${path}"
		done
	fi
}
export -f ls_tiflash_proc

function ls_pd_proc()
{
	local procs=`print_procs 'pd-server' "\-\-config" | awk -F '--config=' '{print $2}' | awk '{print $1}'`
	if [ ! -z "${procs}" ]; then
		echo "${procs}" | while read conf; do
			_print_mod_info `_print_file_dir_when_abs "${conf}"`
		done
	fi
}
export -f ls_pd_proc

function ls_tikv_proc()
{
	local procs=`print_procs 'tikv-server' "\-\-config" | awk -F '--config' '{print $2}' | awk '{print $1}'`
	if [ ! -z "${procs}" ]; then
		echo "${procs}" | while read conf; do
			_print_mod_info `_print_file_dir_when_abs "${conf}"`
		done
	fi
}
export -f ls_tikv_proc

function ls_tidb_proc()
{
	local procs=`print_procs 'tidb-server' "\-\-config" | awk -F '--config=' '{print $2}' | awk '{print $1}'`
	if [ ! -z "${procs}" ]; then
		echo "${procs}" | while read conf; do
			_print_mod_info `_print_file_dir_when_abs "${conf}"`
		done
	fi
}
export -f ls_tidb_proc

function ls_sparkm_proc()
{
	local procs=`print_procs 'org.apache.spark.deploy.master.Master' '/spark/conf' | \
		awk -F '-cp' '{print $2}' | awk -F ':' '{print $1}' | \
		awk -F '/spark/conf' '{print $1}'`
	if [ ! -z "${procs}" ]; then
		echo "${procs}" | while read mod_dir; do
			_print_mod_info "${mod_dir}"
		done
	fi
}
export -f ls_sparkm_proc

function ls_sparkw_proc()
{
	local procs=`print_procs 'org.apache.spark.deploy.worker.Worker' '/spark/conf' | \
		awk -F '-cp' '{print $2}' | awk -F ':' '{print $1}' | \
		awk -F '/spark/conf' '{print $1}'`
	if [ ! -z "${procs}" ]; then
		echo "${procs}" | while read mod_dir; do
			_print_mod_info "${mod_dir}"
		done
	fi
}
export -f ls_sparkw_proc

function _ls_ti_proc()
{
	local name="$1"
	local res=`"ls_${name}_proc"`
	if [ -z "${res}" ]; then
		return
	fi
	echo "=> ${name}:"
	echo "${res}"
}
export -f _ls_ti_proc

function ls_ti_procs()
{
	_ls_ti_proc 'pd'
	_ls_ti_proc 'tikv'
	_ls_ti_proc 'tidb'
	_ls_ti_proc 'tiflash'
	_ls_ti_proc 'sparkm'
	_ls_ti_proc 'sparkw'
}
export -f ls_ti_procs
