# -*- coding:utf-8 -*-

import sys
import os
from string import Template

def serializeAddr(addrs):
    result = []
    for addr in addrs:
        result.append("- '" + addr + "'\n")
    return "".join(result)


def generateConfig(name, addrs):
    config = ""
    config += Template('- job_name: "$name"\n').substitute(name=name)
    config += "  honor_labels: true # don't overwrite job & instance labels\n"
    config += "  static_configs:\n"
    config += "  - targets:\n"
    for addr in addrs:
        config += "    - '" + addr + "'\n"
    return config

def writeFile(lines, file, indent):
    for line in lines.split("\n"):
        file.write(" " * indent + line + "\n")


if __name__ == '__main__':
    if len(sys.argv) < 8:
        print('[process_prometheus_config.py] usage: <bin> conf_file pd_status_addr tikv_status_addr '
              'tidb_status_addr tiflash_status_addr tiflash_proxy_status_addr node_exporter_addr')
        sys.exit(1)

    config_file = sys.argv[1]
    pd_status_addrs = sys.argv[2].split(",")
    tikv_status_addrs = sys.argv[3].split(",")
    tidb_status_addrs = sys.argv[4].split(",")
    tiflash_status_addrs = sys.argv[5].split(",")
    tiflash_proxy_status_addrs = sys.argv[6].split(",")
    node_exporter_addrs = sys.argv[7].split(",")
    tiflash_status_addrs.extend(tiflash_proxy_status_addrs)
    if not os.path.isfile(config_file):
        print('[process_prometheus_config.py] file not exist: "{}"'.format(config_file))
        sys.exit(1)

    all_config_items = [
        ["pd", pd_status_addrs],
        ["tikv", tikv_status_addrs],
        ["tidb", tidb_status_addrs],
        ["tiflash", tiflash_status_addrs],
        ["overwritten-nodes", node_exporter_addrs],
    ]

    scrape_configs = ""
    for item in all_config_items:
        if len(item[1]) == 0:
            continue
        scrape_configs += generateConfig(item[0], item[1])

    all_status_addr = []
    tmp_file = config_file + '.tmp'
    with open(config_file, 'r') as infile, open(tmp_file, 'w') as outfile:
        for line in infile:
            if "[scrape_configs]" in line:
                indent = line.find("[scrape_configs]")
                writeFile(scrape_configs, outfile, indent)
            else:
                outfile.write(line)
        os.rename(tmp_file, config_file)
