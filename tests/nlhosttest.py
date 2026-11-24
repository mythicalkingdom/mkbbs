#!/usr/bin/env python3
"""mkbinkcfg looks the host of a link without one up in the nodelist (IBN / INA flags).
usage: nlhosttest.py <build dir> <work dir>"""
import os, shutil, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
srcra = os.path.join(repo, 'bbs', 'bbsc', 'ra')
srcnl = os.path.join(repo, 'bbs', 'bbsd', 'nodelist')
if not os.path.isdir(srcra):
    print('skip: no sample BBS'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
cfg, nl = tmp + '/r', tmp + '/n'
os.makedirs(nl)
shutil.copytree(cfgpatch.snapshot(srcra), cfg, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(cfg)
maps = {(srcra + '/').encode(): (cfg + '/').encode(), (srcnl + '/').encode(): (nl + '/').encode()}
assert cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s)) >= 2
for f in os.listdir(cfg):
    if f.lower() == 'echocfg.mk':
        os.remove(os.path.join(cfg, f))
open(os.path.join(nl, 'nodelist.999'), 'w').write('\r\n'.join([
    ';A  test nodelist',
    'Zone,1,Test_Zone,Somewhere,Zone_Coord,-Unpublished-,300,CM,IBN',
    'Host,110,Test_Net,Somewhere,Net_Coord,-Unpublished-,300,CM,IBN',
    ',100,Hub,Town,Hub_Op,-Unpublished-,300,CM,IBN:binkp.example.org:24555,INA:ignored.example.org',
    ',200,Plain,Town,Op,-Unpublished-,300,CM,INA:b.example.net,IBN',
    ',300,PortOnly,Town,Op,-Unpublished-,300,CM,IBN:24600,INA:c.example.org',
    ',400,Modem,Town,Op,-Unpublished-,300,CM,INA:d.example.org',
    ',500,NoHost,Town,Op,-Unpublished-,300,CM,IBN',
    ',600,Mine,Town,Op,-Unpublished-,300,CM,IBN,INA:e.example.org',
    ',700,Answers,Town,Op,-Unpublished-,300,CM,IBN,INA:f.example.org',
    ',800,Gone,Town,Op,-Unpublished-,300,CM,IBN,INA:g.example.org',
    '']))
env = {'PATH': os.environ['PATH'], 'MK': cfg}
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'nlhost: ' + name)
    if not ok:
        fails += 1


def run(prog, *args):
    return subprocess.run([os.path.join(build, prog)] + list(args), env=env, capture_output=True, text=True, cwd=work)


def put(d, off, text, size):
    d[off:off + size] = bytes([len(text)]) + text.encode() + bytes(size - 1 - len(text))


SIZE, LINKS, LINK = 12600, 184, 178
d = bytearray(SIZE)
d[0:2] = (1).to_bytes(2, 'little')
d[2:4] = (3).to_bytes(2, 'little')
d[4:6] = (24554).to_bytes(2, 'little')


def link(i, node, host='', port=0, flags=0, name=''):
    b = LINKS + i * LINK
    d[b:b + 8] = b''.join(v.to_bytes(2, 'little') for v in (1, 110, node, 0))
    put(d, b + 8, name, 31)
    put(d, b + 39, host, 61)
    d[b + 100:b + 102] = port.to_bytes(2, 'little')
    put(d, b + 102, 'pw', 31)
    d[b + 133:b + 135] = flags.to_bytes(2, 'little')


link(0, 100)                                  # IBN:host:port
link(1, 200)                                  # INA + IBN
link(2, 300)                                  # IBN:port, INA
link(3, 400)                                  # no IBN: cannot be called
link(4, 500)                                  # IBN without a host
link(5, 600, host='mine.example.com')         # set by hand: wins
link(6, 700, flags=1)                         # answer only: not looked up
link(7, 800, port=24999)                      # port set by hand: wins
link(8, 900)                                  # not in the nodelist
open(os.path.join(cfg, 'mailer.mk'), 'wb').write(d)
e = bytearray(open(os.path.join(srcra, [f for f in os.listdir(srcra) if f.lower() == 'echocfg.mk'][0]), 'rb').read()) if any(f.lower() == 'echocfg.mk' for f in os.listdir(srcra)) else bytearray(2000)
put(e, 0, 'files/in', 51)
put(e, 51, 'mail/out', 51)
open(os.path.join(cfg, 'echocfg.mk'), 'wb').write(e)


def block(out, addr):
    t = out.split('link %s\n' % addr)
    return t[1].split('\nlink ')[0] if len(t) > 1 else ''


r = run('mkbinkcfg', '-n')
check('without an index: still written, one note, links keep no host', r.returncode == 0 and 'no nodelist index' in r.stderr
      and 'host binkp' not in r.stdout and 'host mine.example.com' in r.stdout)
r = run('mknodeidx', 'nodelist.999')
check('the index is built', r.returncode == 0 and 'Wrote' in r.stdout)
r = run('mkbinkcfg', '-n')
out = r.stdout
check('mkbinkcfg ran', r.returncode == 0 and 'no nodelist index' not in r.stderr)
b = block(out, '1:110/100')
check('IBN:host:port: host and port from the nodelist (INA ignored)', 'host binkp.example.org' in b and 'port 24555' in b and 'ignored' not in b)
check('... marked as coming from the nodelist', '# from the nodelist' in b)
b = block(out, '1:110/200')
check('INA:host with IBN: host, default port', 'host b.example.net' in b and 'port' not in b)
b = block(out, '1:110/300')
check('IBN:port with INA:host: both', 'host c.example.org' in b and 'port 24600' in b)
check('no IBN flag: no host', 'host' not in block(out, '1:110/400'))
check('IBN without any host name: no host', 'host' not in block(out, '1:110/500'))
b = block(out, '1:110/600')
check('a host set in the link wins (no nodelist note)', 'host mine.example.com' in b and 'nodelist' not in b and 'e.example.org' not in b)
check('answer-only links are not looked up', 'host' not in block(out, '1:110/700'))
b = block(out, '1:110/800')
check('a port set in the link wins over the nodelist\'s', 'host g.example.org' in b and 'port 24999' in b)
check('a node that is not in the nodelist: no host, no error', 'host' not in block(out, '1:110/900') and 'link 1:110/900' in out)
sys.stdout.flush()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
