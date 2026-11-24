#!/usr/bin/env python3
"""mkqwkcfg (configuration of the offline mail door) on a private copy of the sample BBS, driven in a pseudo terminal.
usage: qwkcfgtest.py <build dir> <work dir>"""
import os, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src) or not os.path.exists(build + '/mkqwkcfg'):
    print('skip: no sample BBS'); sys.exit(0)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkqwkcfg: ' + name)
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'config.mko', 'users.mko', 'confs.mko')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)


def run(*keys):
    env = dict(os.environ, CFGPROG='mkqwkcfg', CFGCWD=ra, CFGDIR=ra)
    r = subprocess.run([sys.executable, here + '/cfgshot.py'] + list(keys), env=env, capture_output=True, text=True)
    return r.stdout


# a new config.mko: defaults, the board id typed, saved
out = run('\x1bm', 'm', 'ZED', '\r', '\x1bx', 'y')
c = ra + '/config.mko'
check('config.mko is made', os.path.exists(c))
d = open(c, 'rb').read() if os.path.exists(c) else b''
check('... with the board id that was typed', d[1:1 + d[0]] == b'ZED' if d else False)
check('... the common path is the message path of the BBS (slashes)', (ra + '/').encode() in d)
# a protocol edited: Zmodem send command
out = run('\x1bm', 'p', '\r', '\t', 'sz -b %F', '\r', '\x1b', '\x1bx', 'y')
d = open(c, 'rb').read()
check('a protocol command line is saved', b'sz -b %F' in d)
# a user added: the list has only "<add a user>"
out = run('\x1bm', 'u', '\r', 'Test Node', '\r', '\x1b', '\x1bx', 'y')
u = ra + '/users.mko'
check('a user is added to users.mko', os.path.exists(u) and b'Test Node' in open(u, 'rb').read())
# the conference list: area 6 edited (short name), confs.mko made
out = run('\x1bm', 'c', '\x1b[B', '\x1b[B', '\x1b[B', '\x1b[B', '\x1b[B', '\r', 'SHORT', '\r', '\x1b', '\x1bx', 'y')
cf = ra + '/confs.mko'
check('a conference setting is written to confs.mko', os.path.exists(cf) and b'SHORT' in open(cf, 'rb').read())
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
