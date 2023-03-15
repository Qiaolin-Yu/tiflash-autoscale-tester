# -*- coding:utf-8 -*-

import sys

def run():
    res = []
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        if len(line) == 0:
            continue
        line = line[:-1]

        # TODO: handle '\"', '\\"', etc
        line = line.replace('"', '\\\"')
        res.append('"' + line + '"')

    print ' '.join(res)

if __name__ == '__main__':
    run()
