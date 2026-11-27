#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mkmsgconv (MSGCONV-PLAN.md phase 1): an area of each kind (Hudson, Squish, Fido *.msg, JAM, Merlin, Synchronet) is filled with a few different messages and converted into every
other kind; the new base is read by a second program (convdump) and compared with the old one; reply links go through the number map; a deleted message stays out; the old base is not
changed; a destination with messages is refused; a message waiting to be sent stops the area; the dry run writes nothing.   usage: msgconvtest.py <build dir> <work dir>"""
import json, os, re, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
live = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(live) or not os.path.exists(build + '/mkmsgconv'):
    print('skip: no sample BBS or mkmsgconv'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkmsgconv: ' + name + ('' if ok else '  ' + str(info)[-700:]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((live + '/').encode()):] if s.startswith((live + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
env = dict(os.environ, MK=ra)
mb = ra + '/mb/'
os.makedirs(mb)
cj = tmp + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
d['config']['MsgPath'][0] = mb
KINDS = 'HSFJMY'
FIDS = {'H': '', 'S': 'sq', 'F': 'fm', 'J': 'jm', 'M': 'mr', 'Y': 'sy'}
AREA = {k: a for k, a in zip(KINDS, (1, 2, 3, 4, 6, 7))}            # areas of the sample that exist: 1 is Hudson, 2 Squish ... (the numbers are not in a row)
for k, a in AREA.items():
    m = d['messages'][str(a)]
    m['MsgBaseType'], m['FileId'], m['MsgBaseDir'], m['MsgType'] = k, FIDS[k], 1, 0
    m['DaysKept'] = m['MsgsKept'] = m['RcvdDays'] = 0
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)


def ident(kind, area, fid):
    if kind == 'H':
        return 'H%03d%s' % (area, mb)
    if kind == 'F':
        return 'F' + mb + fid + '/'
    return kind + mb + fid


def dump(aid, nokludge=False):
    r = subprocess.run([build + '/convdump', aid], env=dict(env, CONVDUMP_NOKLUDGE='1') if nokludge else env, capture_output=True, text=True, encoding='latin-1')
    return [l.split('|') for l in r.stdout.splitlines()] if r.returncode == 0 else None


def conv(*args):
    return subprocess.run([build + '/mkmsgconv'] + list(args), env=env, capture_output=True, text=True, encoding='latin-1')


for k, a in AREA.items():
    r = subprocess.run([build + '/convfill', str(a)], env=env, capture_output=True, text=True)
    check('area %d (%s) filled' % (a, k), r.returncode == 0, r.stderr)

src = {k: dump(ident(k, AREA[k], FIDS[k])) for k in KINDS}
check('every kind holds 6 messages (the third was deleted)', all(v is not None and len(v) == 6 for v in src.values()), {k: (len(v) if v else v) for k, v in src.items()})

# the dry run first: nothing is written
before = sorted(os.listdir(mb))
r = conv('-n', '-a', '2', '-t', 'J')

n = 0
for sk in KINDS:
    for tk in KINDS:
        if sk == tk:
            continue
        fid = 'to%s%s' % (tk.lower(), sk.lower())
        r = conv('-a', str(AREA[sk]), '-t', tk, '-d', fid)
        out = r.stdout + r.stderr
        ok = r.returncode == 0 and 'copied 6 message(s)' in out and 'checked' in out
        a_src = dump(ident(sk, AREA[sk], FIDS[sk]), tk == 'Y')                # Synchronet keeps no kludge lines: both sides are compared without them
        a_dst = dump(ident(tk, AREA[sk], fid), tk == 'Y')
        same = False
        if ok and a_dst is not None and len(a_dst) == 6:
            same = True
            for i, (x, y) in enumerate(zip(a_src, a_dst)):
                # number (renumbered from 1), from, to, subject, date, time, ... refer, seealso (through the map), text length and sum
                nm = {int(o): int(a_dst[i2][0]) for i2, o in enumerate([z[0] for z in a_src])}         # the new number of each old one (Hudson numbers run through all its areas)
                xs = x[1:3] + x[4:6]
                ys = y[1:3] + y[4:6]
                if xs != ys or x[-2:] != y[-2:] or (tk != 'H' and int(y[0]) != i + 1):
                    same = False
                refer = int(x[9])
                if int(y[9]) != (nm.get(refer, 0) if refer else 0):
                    same = False
        n += 1
        check('%s -> %s: copied, checked, the messages are the same (numbers 1-6, reply links through the map, text exactly)' % (sk, tk), ok and same, (out[-300:], a_src, a_dst))

# the old bases are untouched
now = {k: dump(ident(k, AREA[k], FIDS[k])) for k in KINDS}
check('the old bases are not changed', now == src)
r = conv('-a', '2', '-t', 'J', '-d', 'tojsh')
check('a new base is made', r.returncode == 0 and 'copied 6' in r.stdout, r.stdout)
r = conv('-a', '2', '-t', 'J', '-d', 'tojsh')
check('converting again into a base that holds messages is refused (-f adds)', r.returncode == 2 and 'REFUSED' in r.stdout and 'already holds' in r.stdout, r.stdout)
r = conv('-a', '2', '-t', 'J', '-d', 'tojsh', '-f')
check('... -f adds the copy to them', r.returncode == 0 and 'copied 6' in r.stdout and len(dump(ident('J', 2, 'tojsh'))) == 12, r.stdout)
r = conv('-a', '2', '-t', 'S')
check('an area that is of the kind already is left alone', 'already Squish' in r.stdout or r.returncode == 1, r.stdout)
r = conv('-k', 'F', '-t', 'M', '-d', 'bykind')
check('-k: every area of a kind (here the one Fido area)', r.returncode == 0 and 'copied 6 message(s)' in r.stdout and '1 of 1' in r.stdout, r.stdout)
r = conv('-a', '999', '-t', 'J')
check('an area that is not there: nothing to do (exit 1)', r.returncode == 1, r.stdout + r.stderr)
r = conv('-a', '2', '-t', 'Q')
check('a kind that does not exist: refused with a usage message', r.returncode == 1, r.stdout + r.stderr)

# phase 2: the last-read pointers of the users go through the map; callers on line stop it
def lr(op, aid, user, val=None):
    r = subprocess.run([build + '/lrtool', op, aid, str(user)] + ([str(val)] if val is not None else []), env=env, capture_output=True, text=True)
    return int(r.stdout.strip()) if op == 'get' and r.returncode == 0 and r.stdout.strip() else (None if op == 'get' else r.returncode)


def expect(live, dst, p):
    """the new number of the last live message at or below the old number p"""
    c = len([x for x in live if int(x[0]) <= p])
    return int(dst[c - 1][0]) if c else 0


for sk, tk in (('H', 'J'), ('J', 'S'), ('M', 'H'), ('Y', 'F'), ('S', 'M'), ('F', 'Y'), ('J', 'F'), ('S', 'H')):
    aid = ident(sk, AREA[sk], FIDS[sk])
    live = dump(aid)
    olds = [int(x[0]) for x in live]
    ptr = {10: olds[3], 11: olds[1], 12: olds[-1] + 50, 13: olds[2] - 1, 14: 0}
    for u, p in ptr.items():
        lr('set', aid, u, p)
    fid = 'lr%s%s' % (tk.lower(), sk.lower())
    r = conv('-a', str(AREA[sk]), '-t', tk, '-d', fid, '-v', '-f')           # -f: a Hudson board of the area is shared by every conversion into Hudson
    did = ident(tk, AREA[sk], fid)
    dst = dump(did)[-6:]
    got = {u: lr('get', did, u) for u in ptr}
    want = {u: expect(live, dst, p) for u, p in ptr.items()}
    if sk == 'Y':
        want = {u: 0 for u in ptr}                                           # Synchronet keeps no pointers
    if tk == 'Y':
        check('%s -> Y: the pointers are dropped and the report says so' % sk, 'dropped' in r.stdout and r.returncode == 0, r.stdout[-300:])
        continue
    check('%s -> %s: the last-read pointers of 5 users went through the map (%s)' % (sk, tk, want), r.returncode == 0 and got == want and (sk == 'Y' or 'last-read pointer(s) moved' in r.stdout), (got, want, r.stdout[-300:]))

r = conv('-n', '-a', '4', '-t', 'S', '-d', 'drylr')
check('the dry run counts the pointers and writes none', r.returncode == 0 and 'would be moved' in r.stdout and not os.path.exists(mb + 'drylr.sqd'), r.stdout)
subprocess.run([build + '/lrtool', 'useron', 'Test Caller', '1'], env=env, check=True)
r = conv('-a', '4', '-t', 'S', '-d', 'busy')
check('a caller on line stops the conversion (exit 3, -f goes on)', r.returncode == 3 and 'on line' in r.stderr and not os.path.exists(mb + 'busy.sqd'), (r.returncode, r.stdout, r.stderr))
r = conv('-a', '4', '-t', 'S', '-d', 'busy', '-f')
check('... -f goes on', r.returncode == 0 and 'copied 6' in r.stdout, r.stdout + r.stderr)
r = conv('-n', '-a', '4', '-t', 'M', '-d', 'busy2')
check('... a dry run is allowed', r.returncode == 0, r.stdout + r.stderr)
subprocess.run([build + '/lrtool', 'useron', '-'], env=env, check=True)
r = conv('-a', '4', '-t', 'M', '-d', 'free', '-m')
check('nobody on line: it goes (-m keeps the map)', r.returncode == 0 and os.path.exists(ra + '/convmap/area4.map'), (r.stdout, r.stderr, os.listdir(ra)))

# phase 3: -s switches the area in the configuration (config.mk and bbsconfig.json together)
shutil.copy(cj + '/bbsconfig.json', ra + '/bbsconfig.json')
envj2 = dict(env, MKJSON=ra)


def areaid(e, a):
    return subprocess.run([build + '/lrtool', 'areaid', str(a)], env=e, capture_output=True, text=True).stdout.strip()


r = conv('-a', '2', '-t', 'J', '-d', 'swj')
check('without -s the configuration is unchanged', r.returncode == 0 and areaid(env, 2) == ident('S', 2, 'sq') and areaid(envj2, 2) == ident('S', 2, 'sq'), (areaid(env, 2), areaid(envj2, 2)))
r = subprocess.run([build + '/mkmsgconv', '-a', '2', '-t', 'J', '-d', 'swj2', '-s'], env=env, capture_output=True, text=True, encoding='latin-1')
check('-s: the area is JAM in config.mk', r.returncode == 0 and 'configuration now' in r.stdout and areaid(env, 2) == ident('J', 2, 'swj2'), (r.stdout, r.stderr, areaid(env, 2)))
check('... and in bbsconfig.json (both kept in step)', areaid(envj2, 2) == ident('J', 2, 'swj2'), areaid(envj2, 2))
check('... the old Squish base is still there and the new one holds the messages', len(dump(ident('S', 2, 'sq')) or []) == 6 and len(dump(ident('J', 2, 'swj2')) or []) == 6)
# and the other way round, with the JSON file in use
r = subprocess.run([build + '/mkmsgconv', '-a', '2', '-t', 'M', '-d', 'swm', '-s'], env=envj2, capture_output=True, text=True, encoding='latin-1')
check('-s with MKJSON set: JSON and records both change', r.returncode == 0 and areaid(env, 2) == ident('M', 2, 'swm') and areaid(envj2, 2) == ident('M', 2, 'swm'), (r.stdout, r.stderr, areaid(env, 2), areaid(envj2, 2)))
r = conv('-a', '2', '-t', 'H', '-s', '-n')
check('-s with -n changes nothing', r.returncode == 0 and areaid(env, 2) == ident('M', 2, 'swm'), r.stdout)
r = conv('-a', '1-3', '-t', 'Y', '-q')
check('a range of areas (-q: the total only)', r.returncode == 0 and 'area 1' not in r.stdout and '18 message(s) in 3 of 3' in r.stdout, r.stdout)
r = conv('-a', '1-3', '-t', 'Y', '-q')
check('... again: each area is refused and named, exit 2, the total still comes', r.returncode == 2 and r.stdout.count('REFUSED') == 3 and '0 message(s) in 0 of 3' in r.stdout, r.stdout)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
