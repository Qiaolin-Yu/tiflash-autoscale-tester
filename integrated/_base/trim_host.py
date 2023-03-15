# -*- coding:utf-8 -*-

import sys
import os

def trim():
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        if len(line) != 0:
            line = line[:-1]
        if len(line) != 0 and line[0] == '[':
            i = line.find(']')
            if i >= 0:
                host = line[0:i]
                # TODO: more strick condition to make sure this is a valid host string
                if host.find(' ') < 0:
                    line = line[i + 1:]
                    if len(line) > 0 and line[0] == ' ':
                        line = line[1:]
        print line

trim()
