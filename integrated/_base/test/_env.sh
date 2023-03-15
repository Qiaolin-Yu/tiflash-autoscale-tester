#!/bin/bash

source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/load_data.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/ti_file.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/generate_data.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/tpcc.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/tpcc_go.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/sysbench.sh"
