# -*- coding:utf-8 -*-

import sys
import os
import re

class Conf:
    def __init__(self):
        self.ti_path = ""
        self.integrated_dir = "-"
        self.conf_templ_dir = "-"
        self.cache_dir = "/tmp/ti"
        # Only download binary resources
        self.only_download = False
        self.download_path = ''

class Ti:
    def __init__(self):
        self.pds = []
        self.tikvs = []
        self.tidbs = []
        self.tiflashs = []
        self.spark_master = None
        self.spark_workers = []
        self.spark_master_ch = None
        self.spark_workers_ch = []
        self.pd_addr = []
        self.tikv_importers = []
        self.node_exporters = []
        self.prometheus = []
        self.grafanas = []

    def dump(self):
        if len(self.pds):
            print 'PDs'
        for it in self.pds:
            print vars(it)
        if len(self.tikvs):
            print 'TiKVs'
        for it in self.tikvs:
            print vars(it)
        if len(self.tidbs):
            print 'TiDBs'
        for it in self.tidbs:
            print vars(it)
        if len(self.tiflashs):
            print 'TiFlashs'
        for it in self.tiflashs:
            print vars(it)
        if self.spark_master is not None:
            print 'Spark master'
            print vars(self.spark_master)
        if len(self.spark_workers):
            print 'Spark workers'
        for it in self.spark_workers:
            print vars(it)
        if self.spark_master_ch is not None:
            print 'Spark master for chspark'
            print vars(self.spark_master_ch)
        if len(self.spark_workers_ch):
            print 'Spark workers for chspark'
        for it in self.spark_workers_ch:
            print vars(it)
        if len(self.tikv_importers):
            print('TiKV importers')
        for it in self.importers:
            print(vars(it))
        if len(self.node_exporters):
            print('Node exporters')
        for it in self.node_exporters:
            print(vars(it))
        if len(self.prometheus):
            print('Prometheus')
        for it in self.prometheus:
            print(vars(it))
        if len(self.grafanas):
            print('Grafanas')
        for it in self.grafanas:
            print(vars(it))


class Mod(object):
    def __init__(self, name):
        self.name = name
        self.dir = ""
        self.ports = "+0"
        self.host = ""
        self.pd = ""
        self.extra_tools = []

    def is_local(self):
        return self.host == "" or self.host == '127.0.0.1' or self.host == 'localhost'

class ModSparkWorker(Mod):
    def __init__(self, mod_name="spark_w"):
        super(ModSparkWorker, self).__init__(mod_name)
        self.cores = ""
        self.mem = ""

def error(msg):
    sys.stderr.write('[ti_file.py] ' + msg + '\n')
    sys.exit(1)

def parse_kvs(kvs_str, sep = '#'):
    kvs_str = kvs_str.strip()
    kvs = {}
    if len(kvs_str) == 0:
        return kvs
    for it in kvs_str.split(sep):
        kv = it.split('=')
        if len(kv) != 2:
            error('bad prop format: ' + it + ', kvs: ' + kvs_str)
        kvs['{' + kv[0] + '}'] = kv[1]
    return kvs

def parse_mod(obj, line, origin):
    fields = map(lambda x: x.strip(), line.split())
    mod_extra_tools = {
        'pd': ['pd_ctl'],
        'tikv': ['tikv_ctl'],
        'spark_m': ['tispark'],
        'spark_w': ['tispark'],
        'chspark_m': ['chspark'],
        'chspark_w': ['chspark'],
        'tikv_importer': ['tidb_lightning'],
        'grafana': ['grafana_scripts'],
    }
    if obj.name in mod_extra_tools:
        obj.extra_tools.extend(mod_extra_tools[obj.name])
    for field in fields:
        if field.startswith('ports'):
            setattr(obj, 'ports', field[5:].strip())
        elif field.startswith('host'):
            kv = field.split('=')
            if len(kv) != 2 or kv[0].strip() != 'host':
                error('bad host prop: ' + origin)
            setattr(obj, 'host', kv[1].strip())
        elif field.startswith('tiflash'):
            kv = field.split('=')
            if len(kv) != 2 or kv[0].strip() != 'tiflash':
                error('bad tiflash prop: ' + origin)
            setattr(obj, 'tiflash', kv[1].strip())
        elif field.startswith('pd'):
            kv = field.split('=')
            if len(kv) != 2 or kv[0].strip() != 'pd':
                error('bad pd prop: ' + origin)
            setattr(obj, 'pd', kv[1].strip())
        elif field.startswith('cores'):
            kv = field.split('=')
            if len(kv) != 2 or kv[0].strip() != 'cores':
                error('bad cores prop: ' + origin)
            setattr(obj, 'cores', kv[1].strip())
        elif field.startswith('mem'):
            kv = field.split('=')
            if len(kv) != 2 or kv[0].strip() != 'mem':
                error('bad mem prop: ' + origin)
            setattr(obj, 'mem', kv[1].strip())
        elif field.startswith('failpoint'):
            if obj.name != 'tidb':
                error('failpoint is only supported for tidb now.')
            setattr(obj, 'failpoint', True)
        elif field.startswith('standalone'):
            if obj.name != 'tiflash':
                error('standalone is only supported for tiflash now.')
            setattr(obj, 'standalone', True)
        elif field.startswith('engine') or field.startswith('storage_engine'):
            # storage engine for tiflash
            if obj.name != 'tiflash':
                error('engine is only supported for tiflash now.')
            kv = field.split('=')
            if len(kv) != 2 or kv[0].strip() not in ('engine', 'storage_engine') \
                or kv[1].strip() not in ('tmt', 'dt'):
                error('bad engine prop: ' + origin)
            setattr(obj, 'storage_engine', kv[1].strip())
        elif field.startswith('ver') or field.startswith('version'):
            # tiup version
            kv = field.split('=')
            if len(kv) != 2 or kv[0].strip() not in ('ver', 'version') or len(kv[1].strip()) == 0:
                error('bad version prop: ' + origin)
            version = kv[1].strip().strip("'").strip('"') # trip ' or "
            if not version.startswith('v') and len(version) != 0: version = 'v' + version
            setattr(obj, 'version', version)
        elif field.startswith('branch'):
            # PingCAP internal mirror
            kv = field.split('=')
            if len(kv) != 2 or kv[0].strip() != 'branch':
                error('bad branch prop: ' + origin)
            branch = kv[1].strip().strip("'").strip('"')
            setattr(obj, 'branch', branch)
        elif field.startswith('hash'):
            kv = field.split('=')
            if len(kv) != 2 or kv[0].strip() != 'hash':
                error('bad hash prop: ' + origin)
            hash = kv[1].strip().strip("'").strip('"')
            setattr(obj, 'hash', hash)
        else:
            old_dir = str(getattr(obj, 'dir'))
            if len(old_dir) != 0:
                error('bad line: may be two dir prop: ' + old_dir + ', ' + field + '. line: ' + origin)
            setattr(obj, 'dir', field)
    if (hasattr(obj, 'version') and obj.version != '') \
        and ( (hasattr(obj, 'branch') and obj.branch != '') or (hasattr(obj, 'hash') and obj.hash != '') ):
        error('bad line: can not set both "version" and "branch:hash": ' + origin)
    return obj

def pd(res, line, origin):
    new = parse_mod(Mod('pd'), line, origin)
    i = len(res.pds)
    setattr(new, 'pd_name', 'pd' + str(i))
    res.pds.append(new)
    if len(res.pd_addr) < 3:
        res.pd_addr.append(new.host + ':' + new.ports)

def tikv(res, line, origin):
    res.tikvs.append(parse_mod(Mod('tikv'), line, origin))
def tidb(res, line, origin):
    res.tidbs.append(parse_mod(Mod('tidb'), line, origin))
def tiflash(res, line, origin):
    res.tiflashs.append(parse_mod(Mod('tiflash'), line, origin))
def spark_master(res, line, origin):
    res.spark_master = parse_mod(Mod('spark_m'), line, origin)
def spark_worker(res, line, origin):
    res.spark_workers.append(parse_mod(ModSparkWorker(), line, origin))
def spark_master_ch(res, line, origin):
    res.spark_master_ch = parse_mod(Mod('chspark_m'), line, origin)
def spark_worker_ch(res, line, origin):
    res.spark_workers_ch.append(parse_mod(ModSparkWorker('chspark_w'), line, origin))
def tikv_importer(res, line, origin):
    res.tikv_importers.append(parse_mod(Mod('tikv_importer'), line, origin))
def node_exporter(res, line, origin):
    res.node_exporters.append(parse_mod(Mod('node_exporter'), line, origin))
def prometheus(res, line, origin):
    res.prometheus.append(parse_mod(Mod('prometheus'), line, origin))
def grafana(res, line, origin):
    res.grafanas.append(parse_mod(Mod('grafana'), line, origin))


mods = {
    'pd': pd,
    'tikv': tikv,
    'tidb': tidb,
    'tiflash': tiflash,
    'spark_m': spark_master,
    'spark_w': spark_worker,
    'chspark_m': spark_master_ch,
    'chspark_w': spark_worker_ch,
    'tikv_importer': tikv_importer,
    'node_exporter': node_exporter,
    'prometheus': prometheus,
    'grafana': grafana,
}

def parse_file(res, path, kvs):
    lines = open(path).readlines()
    for origin in lines:
        line = origin.strip()
        if len(line) == 0:
            continue
        if line[0] == '#':
            continue

        for k, v in kvs.items():
            line = line.replace(k, v)

        if line.find('{') >= 0:
            error('unsolved arg in line: ' + line + ', in file: ' + path + ', args: ' + str(kvs))

        if line.startswith('import'):
            import_path = line[6:].strip()
            if len(import_path) == 0:
                error('bad import line: ' + origin)
            if not (import_path[0] == '/' or import_path[0] == '\\'):
                import_path = os.path.dirname(os.path.abspath(path)) + '/' + import_path
            parse_file(res, import_path, kvs)
        else:
            matched = False
            for mod, func in mods.items():
                if re.match('^{}(\\s)?[:=]'.format(mod), line):
                    props = line[len(mod):].strip()
                    if props.startswith(':'):
                        func(res, props[1:].strip(), origin)
                        matched = True
                    elif props.startswith('='):
                        pass
                    else:
                        error('bad mod header: ' + origin)
                    break
            if not matched:
                kv = line.split('=')
                if len(kv) != 2:
                    error('bad args line: ' + origin)
                kvs['{' + kv[0].strip() + '}'] = kv[1].strip()

def check_mod_is_valid(mod, index, dirs, ports):
    setattr(mod, 'index', index)

    if len(mod.dir) == 0:
        error(mod.name + '[' + str(mod.index) + '].dir can\'t be empty')
    if mod.dir[0] != '/' and mod.is_local():
        mod.dir = os.getcwd() + '/' + mod.dir

    path = mod.host + ':' + mod.dir
    if path in dirs:
        error(mod.name + '[' + str(mod.index) + '].dir duplicated')
    else:
        dirs.add(path)
    if not mod.is_local() and mod.dir[0] != '/':
        error('relative path can\'t use for remote deployment of ' + mod.name + '[' + str(mod.index) + ']: ' + mod.dir)
    addr = mod.host + ':' + mod.ports
    if addr in ports:
        error(mod.name + '[' + str(mod.index) + '].ports duplicated')
    else:
        ports.add(addr)

def check_is_valid(res):
    dirs = set()
    for mods in [res.pds, res.tikvs, res.tidbs,
                 res.tiflashs,
                 res.spark_master, res.spark_workers, 
                 res.spark_master_ch, res.spark_workers_ch, 
                 res.tikv_importers, res.node_exporters, res.prometheus, res.grafanas]:
        ports = set()
        if isinstance(mods, list):
            for i in range(0, len(mods)):
                check_mod_is_valid(mods[i], i, dirs, ports)
        elif mods is not None:
            check_mod_is_valid(mods, 0, dirs, ports)

def print_sh_header(conf, kvs):
    print '#!/bin/bash'
    print ''
    print '# .ti rendered args: ' + str(kvs)
    print ''
    print '# Setup base env (export functions)'
    print 'source "%s/_env.sh"' % conf.integrated_dir
    print 'auto_error_handle'
    print ''
    print 'id="`print_ip_or_host`:%s"' % conf.ti_path

def print_sep():
    print ''
    print '#---------------------------------------------------------'
    print ''

def print_mod_header(mod):
    print_sep()

def print_cp_bin(mod, conf):
    # <func> name_of_bin_module dest_dir bin_paths_file bin_urls_file cache_dir version branch hash [check_os_type] [failpoint]
    line = 'cp_bin_to_dir "{name}" "{dest_dir}" "{templ_dir}/bin.paths" "{templ_dir}/bin.urls" "{cache_dir}" "{version}" "{branch}" "{hash}" "{check_os_type}" "{failpoint}"'
    format_attrs = {
        "name": mod.name, "dest_dir": mod.dir, "templ_dir": conf.conf_templ_dir, "cache_dir": conf.cache_dir,
        "version": getattr(mod, "version", ""), "branch": getattr(mod, "branch", ""), "hash": getattr(mod, "hash", ""),
        "check_os_type": str(True).lower(),
        "failpoint": str(getattr(mod, "failpoint", "")).lower()
    }

    # if we only download package, rewrite the dest_dir with download_path
    if conf.only_download:
        if len(conf.download_path) == 0:
            error('Running with cmd [download] but no download_path specified')
        format_attrs["dest_dir"] = conf.download_path + "/" + mod.name

    print line.format(**format_attrs) + '\n'
    for bin_name in mod.extra_tools:
        format_attrs["name"] = bin_name
        print line.format(**format_attrs) + '\n'

        # cluster manager should be a zipped file
        if conf.only_download and mod.name == 'tiflash' and bin_name == 'cluster_manager':
            print ' [ -d {dest_dir}/flash_cluster_manager ] && cd {dest_dir} && tar czf flash_cluster_manager.tgz ./flash_cluster_manager && cd -'.format(dest_dir=format_attrs["dest_dir"]) + '\n'

def print_ssh_prepare(mod, conf, env_dir):
    # <func> host mod_name dir conf_templ_dir cache_dir remote_env version branch hash
    format_attrs = {
        "host": mod.host, "name": mod.name,
        "dest_dir": mod.dir, "templ_dir": conf.conf_templ_dir, "cache_dir": conf.cache_dir, "remote_env": env_dir,
        "version": getattr(mod, "version", ""), "branch": getattr(mod, "branch", ""), "hash": getattr(mod, "hash", "")
    }

    prepare = 'ssh_prepare_run "{host}" {name} "{dest_dir}" "{templ_dir}" "{cache_dir}" "{remote_env}" "{version}" "{branch}" "{hash}"'
    print prepare.format(**format_attrs)
    for bin_name in mod.extra_tools:
        format_attrs["name"] = bin_name
        print prepare.format(**format_attrs)
        print ''

def render_pds(res, conf, hosts, indexes):
    pds = res.pds
    if len(pds) == 0:
        return
    cluster = []
    for i in range(0, len(pds)):
        if i >= 3:
            break
        pd = pds[i]
        addr = pd.host + ':' + pd.ports
        cluster.append(pd.pd_name + '=http://' + addr)
    if len(pds) <= 1 and pds[0].host == '':
        cluster = ''
    else:
        cluster = ','.join(cluster)

    for i in range(0, len(pds)):
        pd = pds[i]
        if len(hosts) != 0 and (pd.host not in hosts):
            continue
        if len(indexes) != 0 and (i not in indexes):
            continue
        print_mod_header(pd)

        if pd.is_local():
            ssh = ''
            conf_templ_dir = conf.conf_templ_dir
            print_cp_bin(pd, conf)
        else:
            env_dir = conf.cache_dir + '/worker/integrated'
            ssh = 'call_remote_func "%s" "%s" ' % (pd.host, env_dir)
            conf_templ_dir = env_dir + '/conf'
            print_ssh_prepare(pd, conf, env_dir)

        if i == len(pds) - 1:
            print '# pd_safe_run dir conf_templ_dir ports_delta advertise_host pd_name initial_cluster cluster_id'
            print ssh + 'pd_safe_run "%s" \\' % pd.dir
            print '\t"%s" \\' % conf_templ_dir
            print '\t"%s" "%s" "%s" "%s" "${id}"' % (pd.ports, pd.host, pd.pd_name, cluster)
        else:
            print '# pd_run dir conf_templ_dir ports_delta advertise_host pd_name initial_cluster cluster_id'
            print ssh + 'pd_run "%s" \\' % pd.dir
            print '\t"%s" \\' % conf_templ_dir
            print '\t"%s" "%s" "%s" "%s" "${id}"' % (pd.ports, pd.host, pd.pd_name, cluster)

def render_tikvs(res, conf, hosts, indexes):
    for i in range(0, len(res.tikvs)):
        tikv = res.tikvs[i]
        if len(hosts) != 0 and tikv.host not in hosts:
            continue
        if len(indexes) != 0 and (i not in indexes):
            continue
        print_mod_header(tikv)

        if tikv.is_local():
            ssh = ''
            conf_templ_dir = conf.conf_templ_dir
            print_cp_bin(tikv, conf)
        else:
            env_dir = conf.cache_dir + '/worker/integrated'
            ssh = 'call_remote_func "%s" "%s" ' % (tikv.host, env_dir)
            conf_templ_dir = env_dir + '/conf'
            print_ssh_prepare(tikv, conf, env_dir)

        print '# tikv_safe_run dir conf_templ_dir pd_addr advertise_host ports_delta cluster_id'
        print ssh + 'tikv_safe_run "%s" \\' % tikv.dir
        print '\t"%s" \\' % conf_templ_dir
        pd_addr = tikv.pd or ','.join(res.pd_addr)
        print '\t"%s" "%s" "%s" "${id}"' % (pd_addr, tikv.host, tikv.ports)

def render_tidbs(res, conf, hosts, indexes):
    for i in range(0, len(res.tidbs)):
        tidb = res.tidbs[i]
        if len(hosts) != 0 and tidb.host not in hosts:
            continue
        if len(indexes) != 0 and (i not in indexes):
            continue
        print_mod_header(tidb)

        if tidb.is_local():
            ssh = ''
            conf_templ_dir = conf.conf_templ_dir
            print_cp_bin(tidb, conf)
        else:
            env_dir = conf.cache_dir + '/worker/integrated'
            ssh = 'call_remote_func "%s" "%s" ' % (tidb.host, env_dir)
            conf_templ_dir = env_dir + '/conf'
            print_ssh_prepare(tidb, conf, env_dir)

        print '# tidb_safe_run dir conf_templ_dir pd_addr advertise_host ports_delta cluster_id'
        print ssh + 'tidb_safe_run "%s" \\' % tidb.dir
        print '\t"%s" \\' % conf_templ_dir
        pd_addr = tidb.pd or ','.join(res.pd_addr)
        print '\t"%s" "%s" "%s" "${id}"' % (pd_addr, tidb.host, tidb.ports)

def render_tiflashs(res, conf, hosts, indexes):
    if len(res.tiflashs) == 0:
        return

    if len(res.pds) != 0:
        print_sep()
        print '# Wait for pd to ready'
        for pd in res.pds:
            if pd.is_local():
                print 'wait_for_pd_local "%s" | awk \'{print "   "$0}\'' % pd.dir
            else:
                bins_dir = conf.cache_dir + '/master/bins'
                wait_str = 'wait_for_pd_by_host "%s" "%s" 300 %s %s | awk \'{print "   "$0}\''
                print wait_str % (pd.host, pd.ports, bins_dir, conf.integrated_dir + '/conf/default.ports')

    for i in range(0, len(res.tiflashs)):
        tiflash = res.tiflashs[i]
        if len(hosts) != 0 and tiflash.host not in hosts:
            continue
        if len(indexes) != 0 and (i not in indexes):
            continue
        if hasattr(tiflash, "standalone"):
            if tiflash.standalone and (len(res.pds) != 0 or len(res.tidbs) != 0 or len(res.tikvs) != 0):
                error("deploy standalone tiflash with pd/tidb/tikv is not supported.")
        # storage_engine is empty by default, keep the storage_engine in "config.toml"
        storage_engine = ''
        if hasattr(tiflash, "storage_engine"):
            storage_engine = tiflash.storage_engine
        print_mod_header(tiflash)

        def print_run_cmd(ssh, conf_templ_dir, storage_engine):
            print '# tiflash_safe_run dir conf_templ_dir daemon_mode pd_addr tidb_addr ports_delta listen_host cluster_id standalone storage_engine'
            print (ssh + 'tiflash_safe_run "%s" \\') % tiflash.dir
            print '\t"%s" \\' % conf_templ_dir
            pd_addr = tiflash.pd and tiflash.pd or ','.join(res.pd_addr)
            tidb_addr = '' if len(res.tidbs) <= 0 else ','.join(map(lambda x: x.host + ':' + x.ports, res.tidbs))
            standalone = 'false'
            if hasattr(tiflash, "standalone") and tiflash.standalone:
                standalone = 'true'
            print '\t"true" "%s" "%s" "%s" "%s" "${id}" \\' % (pd_addr, tidb_addr, tiflash.ports, tiflash.host)
            print '\t"%s" "%s"' % (standalone, storage_engine)

        if tiflash.is_local():
            print_cp_bin(tiflash, conf)
            print_run_cmd('', conf.conf_templ_dir, storage_engine)
        else:
            env_dir = conf.cache_dir + '/worker/integrated'
            print_ssh_prepare(tiflash, conf, env_dir)
            print_run_cmd('call_remote_func "%s" "%s" ' % (tiflash.host, env_dir), env_dir + '/conf', storage_engine)

def render_spark_master(res, conf, hosts, indexes, is_chspark=False):
    if is_chspark:
        spark_workers = res.spark_workers_ch
        spark_master = res.spark_master_ch
    else:
        spark_workers = res.spark_workers
        spark_master = res.spark_master
    if len(hosts) != 0 and spark_master.host not in hosts:
        return
    if len(indexes) != 0 and (0 not in indexes):
        return

    executor_memory = 0
    if len(spark_workers) != 0:
        for w in spark_workers:
            memory = w.mem
            if memory == "":
                continue
            if memory[-1] != "G":
                continue
            memory = int(memory[0:-1])
            if executor_memory == 0 or memory < executor_memory:
                executor_memory = memory
    executor_memory_repr = ""
    if executor_memory != 0:
        executor_memory_repr = str(executor_memory) + "G"

    print_mod_header(spark_master)

    tiflash_addr = []
    for i in range(0, len(res.tiflashs)):
        tiflash = res.tiflashs[i]
        addr = tiflash.host + ':' + tiflash.ports
        tiflash_addr.append(addr)

    def print_run_cmd(ssh, conf_templ_dir):
        print '# spark_master_run dir conf_templ_dir pd_addr tiflash_addr is_chspark ports_delta listen_host executor_memory cluster_id'
        print (ssh + 'spark_master_run "%s" \\') % spark_master.dir
        print '\t"%s" "%s" "%s" \\' % (conf_templ_dir, ",".join(res.pd_addr), ",".join(tiflash_addr))
        print '\t "%s" "%s" "%s" "%s" "${id}"' % ("true" if is_chspark else "false", spark_master.ports, spark_master.host, executor_memory_repr)

    if spark_master.is_local():
        print_cp_bin(spark_master, conf)
        print_run_cmd('', conf.conf_templ_dir)
    else:
        env_dir = conf.cache_dir + '/worker/integrated'
        print_ssh_prepare(spark_master, conf, env_dir)
        print_run_cmd('call_remote_func "%s" "%s" ' % (spark_master.host, env_dir), env_dir + '/conf')

def render_spark_workers(res, conf, hosts, indexes, is_chspark=False):
    if is_chspark:
        spark_workers = res.spark_workers_ch
        spark_master = res.spark_master_ch
    else:
        spark_workers = res.spark_workers
        spark_master = res.spark_master
    if len(spark_workers) == 0:
        return
    if spark_master is None:
        if is_chspark:
            error("spark master for chspark is not specified")
        else:
            error("spark master for tispark is not specified")
    spark_master_addr = spark_master.host + ':' + spark_master.ports

    for i in range(0, len(spark_workers)):
        spark_worker = spark_workers[i]
        if len(hosts) != 0 and spark_worker.host not in hosts:
            continue
        if len(indexes) != 0 and (i not in indexes):
            continue
        print_mod_header(spark_worker)

        tiflash_addr = []
        for i in range(0, len(res.tiflashs)):
            tiflash = res.tiflashs[i]
            addr = tiflash.host + ':' + tiflash.ports
            tiflash_addr.append(addr)

        def print_run_cmd(ssh, conf_templ_dir):
            print '# spark_worker_run dir conf_templ_dir pd_addr tiflash_addr spark_master_addr is_chspark ports_delta listen_host cores memory cluster_id'
            print (ssh + 'spark_worker_run "%s" \\') % spark_worker.dir
            print '\t"%s" "%s" "%s" "%s" \\' % (conf_templ_dir, ",".join(res.pd_addr), ",".join(tiflash_addr), spark_master_addr)
            print '\t"%s" "%s" "%s" "%s" "%s" "${id}"' % ("true" if is_chspark else "false", spark_worker.ports, spark_worker.host, spark_worker.cores, spark_worker.mem)

        if spark_worker.is_local():
            print_cp_bin(spark_worker, conf)
            print_run_cmd('', conf.conf_templ_dir)
        else:
            env_dir = conf.cache_dir + '/worker/integrated'
            print_ssh_prepare(spark_worker, conf, env_dir)
            print_run_cmd('call_remote_func "%s" "%s" ' % (spark_worker.host, env_dir), env_dir + '/conf')

def render_tikv_importers(res, conf, hosts, indexes):
    if len(res.tikv_importers) == 0:
        return

    for i, tikv_importer in enumerate(res.tikv_importers):
        if len(hosts) != 0 and tikv_importer.host not in hosts:
            continue
        if len(indexes) != 0 and (i not in indexes):
            continue
        print_mod_header(tikv_importer)

        def print_run_cmd(ssh, conf_templ_dir):
            print '# tikv_importer_run dir conf_templ_dir ports_delta listen_host cluster_id'
            print (ssh + 'tikv_importer_run "%s" \\') % tikv_importer.dir
            print '\t"%s" \\' % conf_templ_dir
            print '\t"%s" "%s" "${id}"' % (tikv_importer.ports, tikv_importer.host)

        if tikv_importer.is_local():
            print_cp_bin(tikv_importer, conf)
            print_run_cmd('', conf.conf_templ_dir)
        else:
            env_dir = conf.cache_dir + '/worker/integrated'
            print_ssh_prepare(tikv_importer, conf, env_dir)
            print_run_cmd('call_remote_func "%s" "%s" ' % (tikv_importer.host, env_dir), env_dir + '/conf')

def render_node_exporters(res, conf, hosts, indexes):
    if len(res.node_exporters) == 0:
        return

    for i, node_exporter in enumerate(res.node_exporters):
        if len(hosts) != 0 and node_exporter.host not in hosts:
            continue
        if len(indexes) != 0 and (i not in indexes):
            continue
        print_mod_header(node_exporter)

        def print_run_cmd(ssh, conf_templ_dir):
            print '# node_exporter_run dir conf_templ_dir ports_delta listen_host cluster_id'
            print (ssh + 'node_exporter_run "%s" \\') % node_exporter.dir
            print '\t"%s" \\' % conf_templ_dir
            pd_addr = ','.join(res.pd_addr)
            print '\t"%s" "%s" "${id}"' % (node_exporter.ports, node_exporter.host)

        if node_exporter.is_local():
            print_cp_bin(node_exporter, conf)
            print_run_cmd('', conf.conf_templ_dir)
        else:
            env_dir = conf.cache_dir + '/worker/integrated'
            print_ssh_prepare(node_exporter, conf, env_dir)
            print_run_cmd('call_remote_func "%s" "%s" ' % (node_exporter.host, env_dir), env_dir + '/conf')

def render_prometheus(res, conf, hosts, indexes):
    if len(res.prometheus) == 0:
        return

    for i, prometheus in enumerate(res.prometheus):
        if len(hosts) != 0 and prometheus.host not in hosts:
            continue
        if len(indexes) != 0 and (i not in indexes):
            continue
        print_mod_header(prometheus)

        def print_run_cmd(ssh, conf_templ_dir):
            print '# prometheus_run dir conf_templ_dir pd_status_addr tikv_status_addr tidb_status_addr tiflash_status_addr ports_delta listen_host cluster_id'
            print (ssh + 'prometheus_run "%s" \\') % prometheus.dir
            print '\t"%s" \\' % conf_templ_dir
            pd_addr = ','.join(res.pd_addr)
            tikv_addr = '' if len(res.tikvs) <= 0 else ','.join(map(lambda x: x.host + ':' + x.ports, res.tikvs))
            tidb_addr = '' if len(res.tidbs) <= 0 else ','.join(map(lambda x: x.host + ':' + x.ports, res.tidbs))
            tiflash_addr = '' if len(res.tiflashs) <= 0 else ','.join(map(lambda x: x.host + ':' + x.ports, res.tiflashs))
            node_exporter_addr = '' if len(res.node_exporters) <= 0 else ','.join(map(lambda x: x.host + ':' + x.ports, res.node_exporters))
            print '\t"%s" "%s" "%s" "%s" "%s" \\' % (pd_addr, tikv_addr, tidb_addr, tiflash_addr, node_exporter_addr)
            print '\t"%s" "%s" "${id}"' % (prometheus.ports, prometheus.host)

        if prometheus.is_local():
            print_cp_bin(prometheus, conf)
            print_run_cmd('', conf.conf_templ_dir)
        else:
            env_dir = conf.cache_dir + '/worker/integrated'
            print_ssh_prepare(prometheus, conf, env_dir)
            print_run_cmd('call_remote_func "%s" "%s" ' % (prometheus.host, env_dir), env_dir + '/conf')

def render_grafanas(res, conf, hosts, indexes):
    if len(res.grafanas) == 0:
        return

    for i, grafana in enumerate(res.grafanas):
        if len(hosts) != 0 and grafana.host not in hosts:
            continue
        if len(indexes) != 0 and (i not in indexes):
            continue
        print_mod_header(grafana)

        def print_run_cmd(ssh, conf_templ_dir):
            print '# grafana_run dir conf_templ_dir prometheus_addr ports_delta listen_host cluster_id'
            print (ssh + 'grafana_run "%s" \\') % grafana.dir
            print '\t"%s" \\' % conf_templ_dir
            prometheus_addr = '' if len(res.prometheus) <= 0 else ','.join(map(lambda x: x.host + ':' + x.ports, res.prometheus))
            print '\t"%s" \\' % (prometheus_addr)
            print '\t"%s" "%s" "${id}"' % (grafana.ports, grafana.host)

        if grafana.is_local():
            print_cp_bin(grafana, conf)
            print_run_cmd('', conf.conf_templ_dir)
        else:
            env_dir = conf.cache_dir + '/worker/integrated'
            print_ssh_prepare(grafana, conf, env_dir)
            print_run_cmd('call_remote_func "%s" "%s" ' % (grafana.host, env_dir), env_dir + '/conf')

def render(res, conf, kvs, mod_names, hosts, indexes):
    def should_render(mod_name):
        if len(mod_names) == 0 or (mod_name in mod_names):
            return True
        else:
            return False

    print_sh_header(conf, kvs)
    if should_render('pd'):
        render_pds(res, conf, hosts, indexes)
    if should_render('tikv'):
        render_tikvs(res, conf, hosts, indexes)
    if should_render('tidb'):
        render_tidbs(res, conf, hosts, indexes)
    if should_render('tiflash'):
        render_tiflashs(res, conf, hosts, indexes)
    if should_render('spark_m') and res.spark_master is not None:
        render_spark_master(res, conf, hosts, indexes, False)
    if should_render('spark_w'):
        render_spark_workers(res, conf, hosts, indexes, False)
    if should_render('chspark_m') and res.spark_master_ch is not None:
        render_spark_master(res, conf, hosts, indexes, True)
    if should_render('chspark_w'):
        render_spark_workers(res, conf, hosts, indexes, True)
    if should_render('tikv_importer'):
        render_tikv_importers(res, conf, hosts, indexes)
    if should_render('node_exporter'):
        render_node_exporters(res, conf, hosts, indexes)
    if should_render('prometheus'):
        render_prometheus(res, conf, hosts, indexes)
    if should_render('grafana'):
        render_grafanas(res, conf, hosts, indexes)

def download(res, conf, kvs):
    print_sh_header(conf, kvs)
    if len(res.pds) > 0:
        print_cp_bin(res.pds[0], conf)
    if len(res.tikvs) > 0:
        print_cp_bin(res.tikvs[0], conf)
    if len(res.tidbs) > 0:
        print_cp_bin(res.tidbs[0], conf)
    if len(res.tiflashs) > 0:
        print_cp_bin(res.tiflashs[0], conf)
    # TODO: support download other components

def get_mods(res, mod_names, hosts, indexes):
    confs = {
        'pd' : 'pd.toml',
        'tikv': 'tikv.toml',
        'tidb': 'tidb.toml',
        'tiflash': 'conf/config.toml',
        'spark_m': 'spark-defaults.conf',
        'spark_w': 'spark-defaults.conf',
        'chspark_m': 'spark-defaults-ch.conf',
        'chspark_w': 'spark-defaults-ch.conf',
        'tikv_importer': 'tikv-importer.toml',
        'node_exporter': '',
        'prometheus': 'prometheus.yml',
        'grafana': 'grafana.ini',
    }

    def output_mod(mod, index):
        if mod is None:
            return
        if len(indexes) != 0 and (index not in indexes):
            return
        if len(hosts) == 0 or (mod.host in hosts):
            if len(mod_names) == 0 or (mod.name in mod_names):
                print '\t'.join([str(index), mod.name, mod.dir, confs[mod.name], mod.host])

    def output(mod_array):
        for i in range(0, len(mod_array)):
            output_mod(mod_array[i], i)

    output(res.pds)
    output(res.tikvs)
    output(res.tidbs)
    output(res.tiflashs)
    output_mod(res.spark_master, 0)
    output(res.spark_workers)
    output_mod(res.spark_master_ch, 0)
    output(res.spark_workers_ch)
    output(res.tikv_importers)
    output(res.node_exporters)
    output(res.prometheus)
    output(res.grafanas)

def get_hosts(res, mod_names, hosts, indexes):
    host_infos = set()
    def output_mod(mod, index):
        if mod is None:
            return
        if len(mod.host) == 0:
            return
        if len(indexes) != 0 and (index not in indexes):
            return
        if len(hosts) == 0 or (mod.host in hosts):
            if len(mod_names) == 0 or (mod.name in mod_names):
                if mod.host not in host_infos:
                    host_infos.add(mod.host)

    def output(mod_array):
        for i in range(0, len(mod_array)):
            output_mod(mod_array[i], i)

    output(res.pds)
    output(res.tikvs)
    output(res.tidbs)
    output(res.tiflashs)
    output_mod(res.spark_master, 0)
    output(res.spark_workers)
    output_mod(res.spark_master_ch, 0)
    output(res.spark_workers_ch)

    for host in host_infos:
        print host

if __name__ == '__main__':
    if len(sys.argv) < 6:
        error('usage: <bin> file cmd(render|mods|hosts|download) integrated_dir conf_templ_dir cache_dir [mod_nams] [hosts] [indexes] [args_str(k=v#k=v#..)]')

    cmd = sys.argv[1]
    path = sys.argv[2]

    conf = Conf()
    conf.ti_path = path
    conf.integrated_dir = sys.argv[3]
    conf.conf_templ_dir = sys.argv[4]
    conf.cache_dir = sys.argv[5]

    mod_names = set()
    if len(sys.argv) > 6 and len(sys.argv[6]) != 0:
        mod_names = set(sys.argv[6].split(','))
    for name in mod_names:
        if not mods.has_key(name):
            error(name + ' is not a valid module name')

    hosts = set()
    if len(sys.argv) > 7 and len(sys.argv[7]) != 0:
        hosts = set(sys.argv[7].split(','))

    indexes = set()
    if len(sys.argv) > 8 and len(sys.argv[8]) != 0:
        indexes = set(map(lambda x: int(x), sys.argv[8].split(',')))
    
    kvs_str = ""
    if len(sys.argv) > 9:
        kvs_str = sys.argv[9]

    if len(sys.argv) > 10 and len(sys.argv[10]) != 0:
        conf.download_path = sys.argv[10]

    res = Ti()
    kvs = parse_kvs(kvs_str)
    parse_file(res, path, kvs)
    check_is_valid(res)

    if cmd == 'render':
        render(res, conf, kvs, mod_names, hosts, indexes)
    elif cmd == 'download':
        conf.only_download = True
        download(res, conf, kvs)
    elif cmd == 'mods':
        get_mods(res, mod_names, hosts, indexes)
    elif cmd == 'hosts':
        get_hosts(res, mod_names, hosts, indexes)
    else:
        error('unknown cmd: ' + cmd)
