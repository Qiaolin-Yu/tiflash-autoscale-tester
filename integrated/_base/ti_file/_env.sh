#!/bin/bash

source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_network.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_conf.sh"

source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/mods/_env.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_wait.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_stop.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_status.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_safe_proc.sh"

source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_ssh.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_ssh_proc.sh"

source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_file_status.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_file_stop.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_file.sh"

source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/cmd_ti.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_ops_cmd.sh"
