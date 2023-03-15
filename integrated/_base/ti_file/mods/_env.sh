#!/bin/bash

source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/pd.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/tikv.sh"

source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/tidb.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/tiflash.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/spark_base.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/sparkm.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/sparkw.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/importer.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/node_exporter.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/prometheus.sh"
source "`cd $(dirname ${BASH_SOURCE[0]}) && pwd`/grafana.sh"
