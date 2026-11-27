#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mkuserpurge on a private copy of the sample BBS: the users who have not called for a long time are marked deleted (the records stay, nothing else changes), the ones that are protected
are not (keep file, security level), a dry run, the warning list.  The expectation is made from users.bbs itself.   usage: userpurgetest.py <build dir> <work dir>"""
import os, re, shutil, subprocess, sys, datetime

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
live = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(live) or not os.path.exists(build + '/mkuserpurge'):
    print('skip: no sample BBS or mkuserpurge'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkuserpurge: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
REC = 158
TODAY = '2026-11-24'
tday = (datetime.date(2026, 11, 24) - datetime.date(1970, 1, 1)).days


def private():
    tmp = cfgpatch.short_dir()
    ra = tmp + '/r'
    shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
    cfgpatch.fix_sample(ra)
    cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((live + '/').encode()):] if s.startswith((live + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
    return ra, dict(os.environ, MK=ra, MKPURGE_TODAY=TODAY)


def users(ra):
    d = open(ra + '/users.bbs', 'rb').read()
    out = []
    for i in range(len(d) // REC):
        r = d[i * REC:(i + 1) * REC]
        name = r[1:1 + r[0]].decode('latin-1')
        ld = r[110 + 1:110 + 1 + r[110]].decode('latin-1')
        m = re.match(r'(\d\d)-(\d\d)-(\d\d)', ld)
        day = None
        if m:
            mm, dd, yy = map(int, m.groups())
            yy += 2000 if yy < 70 else 1900
            try:
                day = (datetime.date(yy, mm, dd) - datetime.date(1970, 1, 1)).days
            except ValueError:
                pass
        out.append(dict(name=name, attr=r[119], last=day, sec=int.from_bytes(r[132:134], 'little'), calls=int.from_bytes(r[134:136], 'little'), rec=r))
    return out


def expected(ra, days, level=0, keep=()):
    gone = []
    for u in users(ra):
        if u['attr'] & 1 or u['attr'] & 16 or not u['name'] or u['name'].upper() in keep:
            continue
        if level and u['sec'] >= level:
            continue
        if u['last'] is not None and u['calls'] > 0 and tday - u['last'] > days:
            gone.append(u['name'])
    return gone


def run(env, *a):
    return subprocess.run([build + '/mkuserpurge'] + list(a), env=env, capture_output=True, text=True)


ra, env = private()
exp = expected(ra, 4000)
check('the sample has users that have not called for a long time, and users that have (the test means something)', 5 < len(exp) < len(users(ra)) - 5, (len(exp), len(users(ra))))
before = open(ra + '/users.bbs', 'rb').read()
r = run(env, '-d', '4000', '-n', '-q')
check('dry run: says how many would be purged, writes nothing', r.returncode == 0 and re.search(r'would purge %d user\(s\) of \d+' % len(exp), r.stdout) and open(ra + '/users.bbs', 'rb').read() == before and 'a dry run' in r.stdout, (len(exp), r.stdout[-300:]))
r = run(env, '-d', '4000', '-q', '-u', '99999')
after = users(ra)
deleted = [u['name'] for u in after if u['attr'] & 1]
check('the purge marks exactly the users who have not called for more than the days (users who never called are left: -u 99999)', sorted(deleted) == sorted(exp) and r.returncode == 0 and 'purged %d user(s)' % len(exp) in r.stdout, (len(deleted), len(exp), r.stdout[-300:]))
raw_after = open(ra + '/users.bbs', 'rb').read()
diff = [i for i in range(len(before)) if before[i] != raw_after[i]]
check('only the attribute byte of those records changed (the records stay, nothing is renumbered)', len(raw_after) == len(before) and all(i % REC == 119 for i in diff) and len(diff) == len(exp), (len(diff), len(exp)))
r = run(env, '-d', '4000', '-q', '-u', '99999')
check('a second run purges nobody more', 'purged 0 user(s)' in r.stdout, r.stdout[-200:])

# the keep file, the security level, the warning list
ra, env = private()
us = users(ra)
cand = [u for u in us if u['name'] in expected(ra, 4000)]
keepname = cand[0]['name']
open(ra + '/keepusers.txt', 'w').write('; never purged\n' + keepname.lower() + '\n')
exp2 = expected(ra, 4000, keep=(keepname.upper(),))
r = run(env, '-d', '4000', '-n', '-q')
check('keepusers.txt in the BBS directory is used without being named: the user in it (any case) is not purged', re.search(r'would purge %d user\(s\)' % len(exp2), r.stdout) and len(exp2) == len(expected(ra, 4000)) - 1, (len(exp2), r.stdout[-200:]))
levels = sorted({u['sec'] for u in cand})
lv = levels[len(levels) // 2]
exp3 = expected(ra, 4000, level=lv, keep=(keepname.upper(),))
r = run(env, '-d', '4000', '-n', '-q', '-s', str(lv))
check('-s LEVEL: users with that security level or more are not purged', re.search(r'would purge %d user\(s\)' % len(exp3), r.stdout) and len(exp3) < len(exp2), (len(exp3), len(exp2), r.stdout[-200:]))
# a user that is not old yet: the warning list
ok_ = [u for u in us if u['last'] is not None and u['calls'] > 0 and not (u['attr'] & 17) and u['name'] and u['name'] != keepname]
ages = sorted(tday - u['last'] for u in ok_)
young = [u for u in ok_ if tday - u['last'] == ages[0]][0]
days = ages[0] + 10
r = run(env, '-d', str(days), '-w', '15')
check('-w DAYS: the list of the users who would be purged in the next days (the newest caller, %d days ago, with -d %d: 10 days to go)' % (ages[0], days), young['name'] in r.stdout and ('%d day(s) to go' % 11) in r.stdout, r.stdout[:400])
r2 = run(env, '-d', str(days), '-w', '15')
check('-w changes nothing', open(ra + '/users.bbs', 'rb').read() == before)
r = run(env)
check('without -d nothing is purged: the usage, exit 1', r.returncode == 1 and 'usage' in r.stdout, (r.returncode, r.stdout))
r = subprocess.run([build + '/mkuserpurge', '-d', '30'], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('no configuration: exit 1', r.returncode == 1 and 'No configuration' in r.stderr, r.stderr)
r = subprocess.run([build + '/mkuserpurge', '-c', ra, '-d', '4000', '-n', '-q'], env={'PATH': os.environ['PATH'], 'MKPURGE_TODAY': TODAY}, capture_output=True, text=True)
check('-c <dir> instead of MK', r.returncode == 0 and 'would purge' in r.stdout, (r.returncode, r.stderr))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
