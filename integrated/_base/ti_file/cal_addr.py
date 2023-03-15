# -*- coding:utf-8 -*-

import sys

def cal(addr, default_host, default_port, ensure_http = False):
    default_port = int(default_port)
    addr = addr.strip()

    http = 'http://'
    if addr.startswith(http):
        addr = addr[len(http):]
    elif not ensure_http:
        http = ''

    kv = addr.strip().split(':')

    host = kv[0].strip()
    if len(kv) == 1:
        port = default_port
    else:
        port = kv[1].strip()
        if len(port) == 0:
            port = default_port
        elif port[0] == '=':
            port = eval(port[0][1:])
        elif port[0] != '+' and port[0] != '-':
            port = eval(port)
        else:
            port = eval(port) + default_port
    if len(host) == 0:
        host = default_host

    return http + host + ':' + str(port)

def cals(addrs, default_host, default_port, sep):
    addrs = map(lambda x: x.strip(), addrs.split(sep))
    addrs = map(lambda x: cal(x, default_host, default_port), addrs)
    return sep.join(addrs)

def cals_pd_init(addrs, default_host, default_port, default_pd_name, sep):
    addrs = map(lambda x: x.strip(), addrs.split(sep))
    new_array = []
    for addr in addrs:
        if len(addr) == 0:
            name = default_pd_name
        else:
            kv = addr.split('=')
            if len(kv) <= 1:
                name = default_pd_name
            else:
                name = kv[0]
                addr = kv[1]
        new = cal(addr, default_host, default_port, True)
        new_array.append(name + '=' + new)
    return sep.join(new_array)

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print '[cal_addr.py] usage: <bin> addr default_host default_port [default_pd_name]'
        sys.exit(1)

    default_pd_name = ""
    if len(sys.argv) > 4:
        default_pd_name = sys.argv[4]

    addr_str = sys.argv[1]
    sep = ','
    if addr_str.find(';') >= 0:
        sep = ';'

    if len(default_pd_name) == 0:
        print cals(addr_str, sys.argv[2], sys.argv[3], sep)
    else:
        print cals_pd_init(addr_str, sys.argv[2], sys.argv[3], default_pd_name, sep)
