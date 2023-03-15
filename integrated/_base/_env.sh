#!/bin/bash

# The path of this folder, used by other scripts
export integrated="$(dirname `cd $(dirname ${BASH_SOURCE[0]}) && pwd`)"

source "${integrated}/_base/error_handle.sh"

source "${integrated}/_base/pipe.sh"

source "${integrated}/_base/cross_platform/_env.sh"
source "${integrated}/_base/log.sh"
source "${integrated}/_base/path.sh"
source "${integrated}/_base/network.sh"
source "${integrated}/_base/misc.sh"
source "${integrated}/_base/upload.sh"
source "${integrated}/_base/fio.sh"

source "${integrated}/_base/ssh.sh"
source "${integrated}/_base/proc.sh"

source "${integrated}/_base/json/_env.sh"
source "${integrated}/_base/ti_file/_env.sh"
source "${integrated}/_base/report/_env.sh"
source "${integrated}/_base/test/_env.sh"
source "${integrated}/_base/kp_file/_env.sh"
