# -*- coding:utf-8 -*-

import sys

def unfold(sep):
    total = []
    res = []

    while True:
        line = sys.stdin.readline()
        if not line:
            break
        if len(line) == 0:
            continue
        line = line[:-1].strip()

        # TODO: handle '\"', '\\"', etc
        line = line.replace('"', '\\\"')

        if line != sep:
            res.append('"' + line + '"')
        else:
            total.append(res)
            res = []

    total.append(res)
    res = None
    total = filter(lambda x: len(x) > 0, total)

    return total

def render(total):
    if len(total) <= 1:
        return
    for cmd_args in total:
        cmd = cmd_args[0]
        assert cmd[0] == '"', cmd
        assert cmd[-1] == '"', cmd
        cmd = cmd[1:-1]
        cmd_args = cmd_args[1:]
        if len(cmd_args) > 0:
            print cmd + '\t' + ' '.join(cmd_args)
        else:
            cmd_args = cmd.split()
            cmd = cmd_args[0]
            cmd_args = cmd_args[1:]
            print cmd + '\t' + ' '.join(cmd_args)

if __name__ == '__main__':
    render(unfold(':'))
