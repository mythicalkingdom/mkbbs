#!/usr/bin/env python3
"""MKRead through a pseudo terminal on a private copy of the sample BBS:
read a Squish message, then reply into the local Hudson area and check the base grew.
usage: readtest.py <work dir>   (needs bbs/bbsc/ra, i.e. the sample BBS)"""
import os, subprocess, sys, shutil

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch
root = os.path.join(here, '..')
work = os.path.abspath(sys.argv[1])
src = os.path.join(root, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
dst = cfgpatch.short_dir() + '/r'      # a short path: the configuration holds it in a fixed size field
shutil.copytree(src, dst, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(dst)
# point the message base directory of the Hudson areas at the private copy and every other
# directory of the sample BBS at a place that does not exist: the test must never write
# into the real sample bases
p = os.path.join(dst, 'config.mk')
root = os.path.realpath(os.path.join(root, 'bbs')).encode() + b'/'
ra = os.path.realpath(src).encode() + b'/'
new = dst.encode() + b'/'
cfgpatch.patch(p, root, lambda s: new if s == ra else b'/nonexistent/' + s[len(root):])
env = dict(os.environ, CFGPROG='mkread', CFGCWD=dst, CFGDIR=dst, CFGDELAY='0.8', CFGARGS='-A183')
shot = os.path.join(here, 'cfgshot.py')


def run(*keys):
    r = subprocess.run([sys.executable, shot] + list(keys), env=env, capture_output=True, text=True)
    return r.stdout


run('\r')                                     # first run: accept the default settings (writes MKRead.Cfg)
size0 = os.path.getsize(os.path.join(dst, 'msgidx.bbs'))
s = run()                                      # -A183 opens area 183 (a Hudson area) at once
ok1 = 'Area: 183' in s and 'From: Patrick' in s
print('ok  ' if ok1 else 'FAIL', 'mkread: a message is displayed')
run('r', '\\x1b[H', '\\r', '\\r', 'n', 'reply from the test\\r', '\\x1b', 'y', 'y')
size1 = os.path.getsize(os.path.join(dst, 'msgidx.bbs'))
ok2 = size1 == size0 + 3
print('ok  ' if ok2 else 'FAIL', 'mkread: a reply was written to the Hudson base (%d -> %d bytes)' % (size0, size1))
sys.exit(0 if (ok1 and ok2) else 1)
