#!/bin/bash

source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/_env.sh"

func="${1}"
shift 1
$func "${@}"
