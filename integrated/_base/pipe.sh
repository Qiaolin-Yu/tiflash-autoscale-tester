#!/bin/bash

function uncolor()
{
	sed 's/\x1B\[[0-9;]\+[A-Za-z]//g'
}
export -f uncolor

function trim_host()
{
	python "${integrated}/_base/trim_host.py"
}
export -f trim_host

function scale_to_name()
{
	tr '.' '_'
}
export -f scale_to_name

function trim_space()
{
	sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'
}
export -f trim_space

function log_ts()
{
	while read line; do
		echo "[`date +%d-%T`] ${line}"
	done
}
export -f log_ts

function std_ev()
{
	awk '{x[NR]=$0; s+=$0; n++} END{a=s/n; for (i in x){ss += (x[i]-a)^2} sd = sqrt(ss/n); print sd}'
}
export -f std_ev
