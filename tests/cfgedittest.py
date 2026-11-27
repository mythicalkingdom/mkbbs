#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mkconfig edits through a pseudo terminal on private copies of the sample BBS (a path, the General screen, an event, a transfer protocol), and the saved
config.mk is checked.  The copies are in a short directory with the paths of config.mk pointing at them, so a save can never reach the sample.
usage: cfgedittest.py <work dir>"""
import os, re, shutil, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
live = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(live):
    print('skip: no sample BBS'); sys.exit(0)
fails = 0
sys.path.insert(0, here)
import fixture
live_before = fixture.live_state()


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkconfig: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


def private():
    d = cfgpatch.short_dir() + '/ra'
    shutil.copytree(cfgpatch.snapshot(live), d, ignore=lambda dd, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk'))
                                                                 or not os.access(os.path.join(dd, f), os.R_OK)])
    cfgpatch.patch(os.path.join(d, 'config.mk'), (repo + '/bbs/').encode(),
                   lambda p: (d + '/').encode() + p[len((live + '/').encode()):] if p.startswith((live + '/').encode()) else p)
    return d


def shot(d, *keys):
    env = dict(os.environ, CFGDIR=d, CFGDELAY='0.5')
    subprocess.run([sys.executable, os.path.join(here, 'cfgshot.py')] + list(keys), env=env, capture_output=True, text=True)


def has(d, pat):
    return re.search(pat, open(os.path.join(d, 'config.mk'), 'rb').read(), re.M) is not None


d = private()
rd = lambda dd, n: open(os.path.join(dd, n), 'rb').read() if os.path.exists(os.path.join(dd, n)) else None
orig = rd(d, 'config.mk')
shot(d, '\\x1bg', '\\x1b[B', '\\r', '\\t\\t\\t\\t', '/x\\\\y', '\\r', '\\x1bx', 'y')
check('edited path saved with slashes', has(d, rb'/x/y/'))
check('the file that was replaced is kept as config.mk.bak (one generation)', rd(d, 'config.mk.bak') == orig and rd(d, 'config.mk') != orig)
first = rd(d, 'config.mk')
shot(d, '\\x1bg', '\\r', '\\t\\t\\t', 'ZZQ', '\\r', '\\x1bx', 'y')
check('General screen edit saved', has(d, rb'ZZQ'))
check('the next save replaces the .bak with the version before it (not the original)', rd(d, 'config.mk.bak') == first)
shot(d, '\\x1bg', '\\x1bx', 'y')
check('a save that changes nothing leaves the .bak alone', rd(d, 'config.mk.bak') == first)
d2 = private()
before = open(os.path.join(d2, 'config.mk'), 'rb').read()
shot(d2, '\\x1be', '\\r', ' ', '\\r', '\\x1b', '\\x1bx', 'y')
after = open(os.path.join(d2, 'config.mk'), 'rb').read()
n = sum(1 for a, b in zip(before, after) if a != b)
check('event status choice saved (%d bytes differ)' % n, len(before) == len(after) and 1 <= n <= 4, n)
d3 = private()
shot(d3, '\\x1bg', 't', *(['\\x1b[B'] * 10), '\\r', 'Zed', '\\t', 'R', '\\t', '\\t', '\\t', 'sz %F | rz', '\\r', '\\x1b', '\\x1bx', 'y')
check('external protocol command line saved', has(d3, rb'sz %F \| rz'))
check('nothing was written into the live sample (its configuration files are as they were)', fixture.live_state() == live_before)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
