# -*- coding:utf-8 -*-

import sys

def error(msg):
    sys.stderr.write('[print_root_pid.py] ' + msg + '\n')
    sys.exit(1)

def run():
    pids = set()
    ppids = set()
    pp2p = {}

    while True:
        line = sys.stdin.readline()
        if not line:
            break
        if len(line) == 0:
            continue

        line = line[:-1].strip()
        if len(line) == 0:
            continue

        fields = line.split()
        if len(fields) != 2:
            error('bad "pid ppid" line: ' + line)

        pid, ppid = fields[0], fields[1]
        pids.add(pid)
        ppids.add(ppid)
        if not pp2p.has_key(ppid):
            pp2p[ppid] = set()
        pp2p[ppid].add(pid)

    removing = set()
    for ppid in ppids:
        if ppid in pids:
            children = pp2p[ppid]
            removing = removing.union(children)

    pids -= removing
    for pid in pids:
        print pid

if __name__ == '__main__':
    run()
