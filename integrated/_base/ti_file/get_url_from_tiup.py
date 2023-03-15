from __future__ import print_function

import sys
import json
import urllib2

def exit_with_unrecognized_version(version):
    print('[get_url_from_tiup.py] unrecognized version:`{}`'.format(version), file=sys.stderr)
    sys.exit(1)

def is_version_match_major_minor(lhs, rhs):
    l, r = lhs.split('.'), rhs.split('.')
    return l[0:2] == r[0:2]

def split_suffix(s):
    """
    "4.0.0-beta" -> ["4.0.4", "beta"]
    """
    idx = s.find('-')
    if idx == -1:
        return s, ''
    else:
        return s[:idx], s[idx + 1:]

def compare_version(lhs, rhs):
    lhs, l_suffix = split_suffix(lhs)
    rhs, r_suffix = split_suffix(rhs)
    if (len(l_suffix) == 0) ^ (len(r_suffix) == 0):
        # suffix is "alpha"/"beta"/"rc" should be less than GA versions
        if len(l_suffix) == 0:
            return 1
        else:
            return -1
    else:
        l, r = list(map(int, lhs.split('.'))), list(map(int, rhs.split('.')))
        if len(l) != len(r):
            return cmp(len(l), len(r))
        ver_cmp_result = cmp(l, r)
        if ver_cmp_result != 0:
            return ver_cmp_result
        else:
            return cmp(l_suffix, r_suffix)


def print_latest_version_url(domain, os, arch, component, version):
    # fetch "snapshot.json"
    snapshot_url = domain + "/snapshot.json"
    content = urllib2.urlopen(snapshot_url).read()
    meta = json.loads(content)["signed"]["meta"]
    key = '/' + component + ".json"
    comp_tiup_snapshot_version = meta[key]["version"]

    # fetch component details
    comp_versions_url = domain + '/{}.{}.json'.format(comp_tiup_snapshot_version, component)
    # print(comp_versions_url)
    content = urllib2.urlopen(comp_versions_url).read()
    jobj = json.loads(content)
    support_platforms = jobj['signed']['platforms']
    platform = os + "/" + arch
    if platform not in support_platforms:
        print('[get_url_from_tiup.py] unsupported platform:' + platform, file=sys.stderr)
        sys.exit(1)
    
    # from pprint import pprint; pprint(support_platforms)
    # version should be in this format: v3.1.x, we should pick the latest version from specified platform
    version = version.strip().lstrip('v')
    available_versions = filter(
        lambda x: is_version_match_major_minor(x, version),
        [x.strip().lstrip('v') for x in support_platforms[platform]]
    )
    available_versions = sorted(available_versions, cmp=compare_version)
    # print(available_versions)
    max_version = available_versions[-1]
    max_version = 'v' + max_version # prepend a 'v' in front of version
    print("{version}\t{domain}/{comp}-{version}-{os}-{arch}.tar.gz\t{domain}/{comp}-{version}-{os}-{arch}.sha1".format(
        domain=domain, comp=component, os=os, arch=arch, version=max_version
    ))


if __name__ == '__main__':
    if len(sys.argv) < 5:
        print('[get_url_from_tiup.py] usage: <bin> os arch component_name version', file=sys.stderr)
        sys.exit(1)

    domain = "https://tiup-mirrors.pingcap.com"
    [os, arch, component, version] = sys.argv[1:5]

    ## version format: "v${major}-${minor}-${patch}"
    # v4.0.x / v3.1.x -- Download the latest released version of specified branch
    # v4.0.5 / v3.1.2 -- Specified version

    dot_splitted = version.split('.')
    if len(dot_splitted) != 3:
        exit_with_unrecognized_version(version)
    
    if dot_splitted[-1] == 'x':
        print_latest_version_url(domain, os, arch, component, version)
    else:
        try:
            patch = dot_splitted[-1]
            print("{version}\t{domain}/{comp}-{version}-{os}-{arch}.tar.gz\t{domain}/{comp}-{version}-{os}-{arch}.sha1".format(
                domain=domain, comp=component, os=os, arch=arch, version=version
            ))
        except ValueError as e:
            exit_with_unrecognized_version(version)
