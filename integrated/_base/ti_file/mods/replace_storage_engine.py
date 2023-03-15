# -*- coding:utf-8 -*-

from __future__ import print_function

import sys
import os
import os.path

def replace_line(line, engine):
    parts = line.split('=')
    if len(parts) != 2:
        return line
    first = parts[0].strip()
    if first != 'storage_engine':
        return line
    # old_engine = parts[1].strip().strip('"')
    return 'storage_engine="{}"'.format(engine)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('[replace_storage_engine.py] usage: <bin> config_file storage_engine')
        sys.exit(1)

    config_file = sys.argv[1]
    engine = sys.argv[2]
    if not os.path.isfile(config_file):
        print('[replace_storage_engine.py] file not exist: "{}"'.format(config_file))
        sys.exit(1)
    if engine not in ('tmt', 'dt'):
        print('[replace_storage_engine.py] unsupported storage engine: "{}"'.format(engine))
        sys.exit(1)
    
    tmp_file = config_file + '.tmp'
    with open(config_file, 'r') as infile, open(tmp_file, 'w') as outfile:
        for line in infile:
            line = line.strip()
            print(replace_line(line, engine), file=outfile)
        os.rename(tmp_file, config_file)
