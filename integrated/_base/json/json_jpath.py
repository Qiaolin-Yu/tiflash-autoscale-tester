# -*- coding:utf-8 -*-

import sys
import json
import jsonpath

def print_obj(obj, level = 0, parent = ''):
    if isinstance(obj, dict):
        #max_len = max(map(lambda x: len(x), obj.keys()))
        for k, v in obj.iteritems():
            if isinstance(v, list):
                print_obj(v, level, k)
            elif isinstance(v, dict):
                sys.stdout.write('    ' * level + k + ':\n')
                print_obj(v, level + 1, k)
            else:
                #indent = ' ' * (max_len - len(k))
                indent = ''
                sys.stdout.write('    ' * level + k + ': ' + indent + str(v) + '\n')
    elif isinstance(obj, list):
        i = 0
        for it in obj:
            if parent != '':
                sys.stdout.write('    ' * level + parent + '[' + str(i) + ']:\n')
                print_obj(it, level + 1)
            else:
                print_obj(it, level)
            i += 1
    else:
        sys.stdout.write('    ' * level + str(obj) + '\n')

def print_json(jpath):
    # TODO: json.loads(sys.stdin)
    lines = ''
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        lines += line

    try:
        obj = json.loads(lines)
    except:
        print lines
        return
    if jpath != '':
        obj = jsonpath.jsonpath(obj, jpath)
        if str(obj) == 'False':
            sys.exit(1)
    print_obj(obj)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print '[bin json.py] usage: <bin> jpath_str'
        sys.exit(1)

    jpath = sys.argv[1]
    print_json(jpath)
