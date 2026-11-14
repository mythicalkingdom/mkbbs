#!/usr/bin/env python3
"""mknodeidx / mknodelist on a private copy of the sample BBS: the index built from the sample nodelists must be
byte for byte the index of the real BBS (nodeidx.ra), and nodes are found through it.
usage: nodetest.py <build dir> <work dir>"""
import os, shutil, struct, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
srcra = os.path.join(repo, 'bbs', 'bbsc', 'ra')
srcnl = os.path.join(repo, 'bbs', 'bbsd', 'nodelist')
if not (os.path.isdir(srcra) and os.path.exists(os.path.join(srcnl, 'nodelist.262'))):
    print('skip: no sample BBS'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
# short paths: the strings of the configuration are fixed size fields, a longer path cannot be patched in
tmp = cfgpatch.short_dir()
dst = os.path.join(tmp, 'r')
nl = os.path.join(tmp, 'n')
os.makedirs(nl)
shutil.copytree(srcra, dst)
for f in ('nodelist.262', 'techlist.346', 'icdmlist.353'):
    shutil.copy2(os.path.join(srcnl, f), nl)             # keeps the file dates (they go into the index)

# the configuration of the copy: the BBS directory and the nodelist directory are the private ones
maps = {(srcra + '/').encode(): (dst + '/').encode(), (srcnl + '/').encode(): (nl + '/').encode()}
n = cfgpatch.patch(os.path.join(dst, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))
assert n >= 2, 'the configuration paths were not found'

fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + name)
    if not ok:
        fails += 1


env = {'PATH': os.environ['PATH'], 'MK': dst}


def run(prog, *args):
    return subprocess.run([os.path.join(build, prog)] + list(args), env=env, capture_output=True, text=True, cwd=work)


# 1. no index yet
r = run('mknodelist', '1:110/290')
check('mknodelist without an index says so', r.returncode == 2 and 'mknodeidx' in r.stderr)

# 2. build it
r = run('mknodeidx', 'nodelist.262', 'techlist.346', 'icdmlist.353')
check('mknodeidx: built the index: ' + r.stdout.strip().splitlines()[-1] if r.stdout.strip() else 'mknodeidx', r.returncode == 0 and 'Wrote' in r.stdout)
mine = open(os.path.join(nl, 'NodeIdx.Mk'), 'rb').read() if os.path.exists(os.path.join(nl, 'NodeIdx.Mk')) else b''
real = open(os.path.join(srcnl, 'nodeidx.ra'), 'rb').read()
check('index = the real nodeidx.ra byte for byte (%d entries)' % (len(real) // 10), mine == real)
inc = open(os.path.join(nl, 'NodeInc.Mk'), 'rb').read() if os.path.exists(os.path.join(nl, 'NodeInc.Mk')) else b''
rinc = open(os.path.join(srcnl, 'nodeinc.ra'), 'rb').read()


def incs(b):
    return [(b[i * 17 + 1:i * 17 + 1 + b[i * 17]], struct.unpack('<i', b[i * 17 + 13:i * 17 + 17])[0]) for i in range(len(b) // 17)]


mi, ri = incs(inc), incs(rinc)
check('include file: same names, same file dates', len(mi) == 3 and [a for a, b in mi] == [a for a, b in ri]
      and [b >> 16 for a, b in mi] == [b >> 16 for a, b in ri])
check('techlist and icdmlist times are exact', mi[1] == ri[1] and mi[2] == ri[2])

# 3. look a node up: the system of the sample BBS
lines = open(os.path.join(nl, 'nodelist.262'), 'rb').read().decode('latin-1').split('\n')
want = None
net = None
for ln in lines:
    ln = ln.rstrip('\r')
    if ln.lower().startswith('host,'):
        net = ln.split(',')[1]
    if 'Mark_May' in ln and net == '110':
        want = ln.split(',')
        break
check('the sample nodelist has the BBS itself (node %s)' % (want[1] if want else '?'), want is not None)
if want:
    r = run('mknodelist', '1:110/%s' % want[1])
    out = r.stdout
    sp = lambda t: t.replace('_', ' ')                    # mknodelist shows the underscores as blanks
    check('mknodelist finds it: System = %s' % sp(want[2]), r.returncode == 0 and ('System = ' + sp(want[2])) in out
          and ('Number = ' + want[1]) in out and ('Sysop  = ' + sp(want[4])) in out and ('Phone  = ' + want[5]) in out)
r = run('mknodelist', '1:110/9999')
check('a node that is not in the net: Address Not Found', 'Address Not Found' in r.stdout)
r = run('mknodelist', '1:9999/1')
check('a net that is not there: Address Not Found', 'Address Not Found' in r.stdout)
r = run('mknodelist', '77:1/1')
check('a zone that is not there: Address Not Found (and no endless loop)', 'Address Not Found' in r.stdout)

# 4. again without names (the lists of the index), and with a mask
before = open(os.path.join(nl, 'NodeIdx.Mk'), 'rb').read()
os.remove(os.path.join(nl, 'NodeIdx.Mk'))
r = run('mknodeidx')
check('without names: the lists of the include file are indexed again',
      r.returncode == 0 and open(os.path.join(nl, 'NodeIdx.Mk'), 'rb').read() == before)
os.remove(os.path.join(nl, 'NodeIdx.Mk'))
r = run('mknodeidx', 'NODELIST.*', 'techlist.346', 'icdmlist.353')
check('NODELIST.* takes the newest file', r.returncode == 0 and open(os.path.join(nl, 'NodeIdx.Mk'), 'rb').read() == before)

# 5. errors
r = run('mknodeidx', 'nothere.123')
check('missing nodelist', r.returncode == 2 and 'nothere.123' in r.stderr)
open(os.path.join(work, 'notalist.txt'), 'w').write('hello\nthis is no nodelist\n')
r = run('mknodeidx', os.path.join(work, 'notalist.txt'))
check('a file without Zone/Region/Host lines is refused', r.returncode == 3)
check('and the index was not damaged', open(os.path.join(nl, 'NodeIdx.Mk'), 'rb').read() == before)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
