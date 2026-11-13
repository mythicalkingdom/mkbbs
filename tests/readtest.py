#!/usr/bin/env python3
"""MKRead through a pseudo terminal on a private copy of the sample BBS:
read a Squish message, then reply into the local Hudson area and check the base grew.
usage: readtest.py <work dir>   (needs bbs/bbsc/ra, i.e. the sample BBS)"""
import os, subprocess, sys, shutil

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..')
work = os.path.abspath(sys.argv[1])
src = os.path.join(root, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
dst = os.path.join(work, 'ra')
os.makedirs(dst, exist_ok=True)
subprocess.check_call(['cp', '-a', src + '/.', dst + '/'])
# point the message base directories at the private copy
p = os.path.join(dst, 'config.mk')
d = bytearray(open(p, 'rb').read())
old = os.path.realpath(src).encode() + b'/'
new = dst.encode() + b'/'
i = 0
while i < len(d) - 3:
    L = d[i]
    if L == len(old) and bytes(d[i + 1:i + 1 + L]) == old:
        d[i] = len(new)
        d[i + 1:i + 1 + len(new)] = new
        i += 1 + len(new)
    else:
        i += 1
open(p, 'wb').write(d)
env = dict(os.environ, CFGPROG='mkread', CFGCWD=dst, CFGDIR=dst, CFGDELAY='0.8')
shot = os.path.join(here, 'cfgshot.py')


def run(*keys):
    r = subprocess.run([sys.executable, shot] + list(keys), env=env, capture_output=True, text=True)
    return r.stdout


size0 = os.path.getsize(os.path.join(dst, 'msgidx.bbs'))
s = run('\\t', '\\r')                          # Tab = next area with new mail, Enter = open it
ok1 = 'Msg:' in s and 'Date:' in s
print('ok  ' if ok1 else 'FAIL', 'mkread: a Squish message is displayed')
run('\\t', '\\r', 'r', '\\x1b[H', '\\r', '\\r', 'n', 'reply from the test\\r', '\\x1b', 'y', 'y')
size1 = os.path.getsize(os.path.join(dst, 'msgidx.bbs'))
ok2 = size1 == size0 + 3
print('ok  ' if ok2 else 'FAIL', 'mkread: a reply was written to the Hudson base (%d -> %d bytes)' % (size0, size1))
sys.exit(0 if (ok1 and ok2) else 1)
