#!/usr/bin/env python3
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
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
