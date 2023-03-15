# -*- coding:utf-8 -*-

import sys
import os

def error(msg):
    sys.stderr.write('[kp_log_report.py] ' + msg + '\n')
    sys.exit(1)

def report(std_log_path, err_log_path, result_limit, color = True):
    lines_limit = 99999

    # TODO: too slow
    std_log = []
    if os.path.exists(std_log_path):
        with open(std_log_path) as file:
            std_log = file.readlines()[-lines_limit:]
    err_log = []
    if os.path.exists(err_log_path):
        with open(err_log_path) as file:
            err_log = file.readlines()[-lines_limit:]

    if color:
        s_ok = '\033[32m-\033[0m'
        s_err = '\033[31mE\033[0m'
        s_warn = '\033[33m~\033[0m'
        s_arrow = '\033[35m<\033[0m'
        s_stop = '\033[35m!\033[0m'
    else:
        s_ok = '-'
        s_err = 'E'
        s_warn = '~'
        s_arrow = '<'
        s_stop = '!'

    result = ['-' for i in range(result_limit)]
    started = False
    started_time = None
    err_log_i = 0

    last_line = None

    for sline in std_log:
        if sline.startswith('!RUN '):
            if started:
                result.append(s_err)
            else:
                if started_time:
                    mark = '!RUN ' + started_time
                    while True:
                        if err_log_i >= len(err_log):
                            break
                        if err_log[err_log_i].startswith(mark):
                            err_log_i += 1
                            break
                        err_log_i += 1
                started = True
            fields = sline.split()
            if len(fields) > 1:
                started_time = fields[1]
        elif sline.startswith('!END '):
            if err_log_i < len(err_log) and not err_log[err_log_i].startswith('!RUN '):
                result.append(s_warn)
            else:
                result.append(s_ok)
            started = False
        elif sline.startswith('!STOPPED '):
            result.append(s_stop)
            started = False
        elif sline.startswith('!ERR '):
            result.append(s_err)
            started = False

        last_line = sline

    if last_line and not sline.startswith('!'):
        result.append(s_arrow)

    return result

if __name__ == '__main__':
    if len(sys.argv) < 4:
        error('usage: <bin> std_log err_logi [result_limit=120] [color=false]')

    if len(sys.argv) > 3:
        result_limit = int(sys.argv[3])
    else:
        result_limit = 120
    if len(sys.argv) > 4:
        color = (sys.argv[4].lower() == 'color' or (sys.argv[4].lower() == 'true'))
    else:
        color = False

    result = report(sys.argv[1], sys.argv[2], result_limit, color)[-result_limit:]
    print ''.join(result)
