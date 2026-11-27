#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The fixture: a snapshot of the sample BBS that the tests copy, instead of the live sample (bbs/).

  fixture.py make      take the snapshot (build/fixture/): the configuration directory (bbs/bbsc/ra), the menus, the node list and the mkqwk
                       configuration; the files that belong to the running system (mkbink.conf, events.mk, fileecho.mk) are left out.  It also writes
                       down what the live sample holds (build/fixture/live.json).
  fixture.py verify    FAIL lines when something changed during the run: a test that wrote into the fixture, or into the live sample (its
                       configuration files, or events.mk / fileecho.mk appearing there).
  fixture.py path NAME the directory of a part (ra, menus, nodelist, mkqwk)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch
The tests use cfgpatch.snapshot(path): the path of a live part gives the snapshot, so the sample that a running BBS uses is only read at the start of a
build and not while the tests run (its mailer, its own saves).  The paths inside config.mk are not changed: the tests patch them as before."""
import hashlib, json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.realpath(os.path.join(HERE, '..'))
FIX = os.path.join(REPO, 'build', 'fixture')
PARTS = {'ra': ('bbs', 'bbsc', 'ra'), 'menus': ('bbs', 'bbsc', 'myth', 'menus'), 'nodelist': ('bbs', 'bbsd', 'nodelist'), 'mkqwk': ('bbs', 'bbsc', 'mkqwk')}
LIVE_KEYS = ('config.mk', 'messages.mk', 'files.mk', 'echocfg.mk', 'mailer.mk', 'events.mk', 'fileecho.mk')   # what a test must never change in the live sample
SKIP = ('mkbink.conf',)                                           # written by the running listener
NOT_IN_SNAPSHOT = ('events.mk', 'fileecho.mk')                    # the tests start without them, and make their own


def live(name):
    return os.path.join(REPO, *PARTS[name])


def fix(name):
    return os.path.join(FIX, name)


def sha(path):
    try:
        return hashlib.sha256(open(path, 'rb').read()).hexdigest()
    except OSError:
        return None


def tree_hash(root):
    h = {}
    for d, _, files in os.walk(root):
        for f in files:
            p = os.path.join(d, f)
            h[os.path.relpath(p, root)] = sha(p)
    return h


def live_state():
    ra = live('ra')
    return {k: sha(os.path.join(ra, k)) for k in LIVE_KEYS}


def make():
    shutil.rmtree(FIX, ignore_errors=True)
    os.makedirs(FIX)
    for name in PARTS:
        src = live(name)
        if not os.path.isdir(src):
            continue
        def ignore(d, names, name=name):
            out = []
            for n in names:
                p = os.path.join(d, n)
                if n.lower().startswith(SKIP) or not os.access(p, os.R_OK):
                    out.append(n)
                elif name == 'ra' and n.lower() in NOT_IN_SNAPSHOT and os.path.dirname(p) == src:
                    out.append(n)
            return out
        shutil.copytree(src, fix(name), ignore=ignore, symlinks=True)
    json.dump({'live': live_state(), 'fix': {n: tree_hash(fix(n)) for n in PARTS if os.path.isdir(fix(n))}}, open(os.path.join(FIX, 'live.json'), 'w'))
    return fix('ra')


def ensure():
    if not os.path.isdir(fix('ra')) or not os.path.exists(os.path.join(FIX, 'live.json')):
        make()
    return fix('ra')


def verify():
    state = json.load(open(os.path.join(FIX, 'live.json')))
    bad = []
    now = live_state()
    for k, v in state['live'].items():
        if now[k] != v:
            bad.append('the live sample changed during the run: %s%s' % (k, ' (it appeared)' if v is None else ' (it is gone)' if now[k] is None else ''))
    for n, was in state['fix'].items():
        cur = tree_hash(fix(n))
        for f in sorted(set(was) | set(cur)):
            if was.get(f) != cur.get(f):
                bad.append('the fixture changed during the run: %s/%s' % (n, f))
    return bad


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'make':
        print(make())
    elif cmd == 'path':
        ensure()
        print(fix(sys.argv[2] if len(sys.argv) > 2 else 'ra'))
    elif cmd == 'verify':
        bad = verify()
        for b in bad:
            print('FAIL fixture: ' + b)
        print('fixture: %s' % ('FAIL' if bad else 'ok, the live sample and the snapshot are as they were'))
        sys.exit(1 if bad else 0)
    else:
        print(__doc__)
        sys.exit(2)
