#!/bin/bash

function print_jpath()
{
	python "${integrated}/_base/json/json_jpath.py" "${1}"
}
export -f print_jpath

function print_json()
{
	python "${integrated}/_base/json/json_jpath.py" ''
}
export -f print_json
