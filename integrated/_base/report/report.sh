#!/bin/bash

function to_table()
{
	local here="`cd $(dirname ${BASH_SOURCE[0]}) && pwd`"
	python "${here}/to_table.py" "${@}"
}
export -f to_table
