#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mklistmsgarea and mknodelist on the sample BBS.   usage: toolstest.py <build dir> <work dir>"""
import os, subprocess, sys

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
cfg = os.path.realpath(os.path.join(repo, 'bbs', 'bbsc', 'ra'))
if not os.path.isdir(cfg):
    print('skip: no sample BBS'); sys.exit(0)
os.makedirs(work, exist_ok=True)
env = dict(os.environ, MK=cfg)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + name)
    if not ok:
        fails += 1


out = os.path.join(work, 'areas.txt')
if os.path.exists(out):
    os.remove(out)
r = subprocess.run([os.path.join(build, 'mklistmsgarea'), out], env=env, capture_output=True, text=True)
lines = open(out, encoding='latin-1').read().split('\n') if os.path.exists(out) else []
if lines and lines[-1] == '':
    lines.pop()
check('mklistmsgarea: three lines per area (%d lines)' % len(lines), r.returncode == 0 and len(lines) > 0 and len(lines) % 3 == 0)
check('mklistmsgarea: the first area is the local General area', len(lines) >= 3 and lines[0][0] == 'H' and 'General' in ' '.join(lines[:3]))
check('mklistmsgarea: no names longer than 70', all(len(l) <= 70 for l in lines[2::3]))
r = subprocess.run([os.path.join(build, 'mklistmsgarea')], env=env, capture_output=True, text=True)
check('mklistmsgarea: no file name: syntax message', r.returncode == 1 and 'syntax' in r.stdout)
r = subprocess.run([os.path.join(build, 'mklistmsgarea'), '/nonexistent/dir/x.txt'], env=env, capture_output=True, text=True)
check('mklistmsgarea: cannot create the file', r.returncode == 2)
r = subprocess.run([os.path.join(build, 'mklistmsgarea'), out], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('mklistmsgarea: no BBS configured', r.returncode == 1 and 'No configuration' in r.stderr)

r = subprocess.run([os.path.join(build, 'mknodelist')], env=env, capture_output=True, text=True)
check('mknodelist: no address: syntax message', r.returncode == 1 and 'syntax' in r.stdout)
r = subprocess.run([os.path.join(build, 'mknodelist'), 'not an address'], env=env, capture_output=True, text=True)
check('mknodelist: bad address', r.returncode == 10 and 'Unable to parse' in r.stdout)
r = subprocess.run([os.path.join(build, 'mknodelist'), '1:110/290'], env=env, capture_output=True, text=True)
check('mknodelist: the sample index names a nodelist that is not there', r.returncode == 0 and 'Unable to Open Nodelist' in r.stdout)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
