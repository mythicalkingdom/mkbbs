#!/usr/bin/env python3
"""mkuserpack on a private copy of the sample BBS: users marked deleted (mkuserpurge) leave users.bbs and extusers.bbs in step, usersidx.bbs is made again (the entries of the users who stay are the
old ones), the map (usermap.txt and a dated copy), the refusal while a mk runs, the dry run, a second pack.   usage: userpacktest.py <build dir> <work dir>"""
import glob, os, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
live = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(live) or not os.path.exists(build + '/mkuserpack'):
    print('skip: no sample BBS or mkuserpack'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkuserpack: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((live + '/').encode()):] if s.startswith((live + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
env = dict(os.environ, MK=ra, MKPURGE_TODAY='2026-11-24')
UR, XR, IR = 158, None, 8


def rd(n):
    return open(ra + '/' + n, 'rb').read()


def run(*a):
    return subprocess.run([build + '/mkuserpack'] + list(a), env=env, capture_output=True, text=True)


r = run('-q')
check('no user is deleted yet: nothing to pack, nothing written', r.returncode == 0 and 'nothing to pack' in r.stdout and not os.path.exists(ra + '/usermap.txt'), r.stdout + r.stderr)
subprocess.run([build + '/mkuserpurge', '-d', '4000', '-q', '-u', '99999'], env=env, check=True, capture_output=True)
u0, x0, i0 = rd('users.bbs'), rd('extusers.bbs'), rd('usersidx.bbs')
N = len(u0) // UR
XR = len(x0) // N
gone = [i for i in range(N) if u0[i * UR + 119] & 1]
keep = [i for i in range(N) if i not in gone]
check('the sample has deleted users after the purge (the test means something)', 5 < len(gone) < N - 5 and len(x0) % N == 0 and len(i0) == N * IR, (len(gone), N))
r = run('-n')
check('dry run: says how many go, changes nothing', r.returncode == 0 and 'would go' in r.stdout and rd('users.bbs') == u0 and not os.path.exists(ra + '/usermap.txt') and rd('usersidx.bbs') == i0, r.stdout + r.stderr)

fake = tmp + '/mk'
shutil.copy('/bin/sleep', fake)
proc = subprocess.Popen([fake, '60'], env=dict(env), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    r = run()
    check('refused while a mk of this BBS is running: exit 3, nothing changed', r.returncode == 3 and rd('users.bbs') == u0, (r.returncode, r.stderr))
finally:
    proc.kill(); proc.wait()
r = run('-q')
check('the pack succeeds', r.returncode == 0 and 'packed' in r.stdout, r.stdout + r.stderr)
u1, x1, i1 = rd('users.bbs'), rd('extusers.bbs'), rd('usersidx.bbs')
check('users.bbs: the others in their order, the deleted ones gone', u1 == b''.join(u0[i * UR:(i + 1) * UR] for i in keep), (len(u1), len(keep) * UR))
check('extusers.bbs: the same records went, in step', x1 == b''.join(x0[i * XR:(i + 1) * XR] for i in keep))
check('usersidx.bbs is made again: for each user who stays the old entry (name and handle CRC), nothing else', i1 == b''.join(i0[i * IR:(i + 1) * IR] for i in keep), (len(i1), len(keep) * IR))
check('name.prepack copies of the three files', all(open(ra + '/' + n + '.prepack', 'rb').read() == o for n, o in (('users.bbs', u0), ('extusers.bbs', x0), ('usersidx.bbs', i0))))
m = open(ra + '/usermap.txt', encoding='latin-1').read().splitlines()
rows = [l.split('\t') for l in m if not l.startswith('#')]
check('the map: a line for every old number, "-" for the ones that went, the new numbers 0.. in order', len(rows) == N and [int(r_[0]) for r_ in rows] == list(range(N))
      and all((r_[1] == '-') == (int(r_[0]) in gone) for r_ in rows) and [int(r_[1]) for r_ in rows if r_[1] != '-'] == list(range(len(keep))), m[:6])
check('names are in the map', all(r_[2] == u0[int(r_[0]) * UR + 1:int(r_[0]) * UR + 1 + u0[int(r_[0]) * UR]].decode('latin-1') for r_ in rows))
dated = glob.glob(ra + '/usermap.*-*.txt')
check('a dated copy of the map beside it, the same', len(dated) == 1 and open(dated[0], 'rb').read() == open(ra + '/usermap.txt', 'rb').read(), dated)
r = run('-q')
check('a second pack finds nothing to do and keeps the map', r.returncode == 0 and 'nothing to pack' in r.stdout and rd('users.bbs') == u1 and len(glob.glob(ra + '/usermap.*-*.txt')) == 1, r.stdout)
r = subprocess.run([build + '/mkuserpack', '-c', ra, '-n'], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('-c <dir> instead of MK', r.returncode == 0, (r.returncode, r.stderr))
r = subprocess.run([build + '/mkuserpack'], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('no configuration: exit 1', r.returncode == 1 and 'No configuration' in r.stderr, r.stderr)

# the last-read step: a second private copy, pack and step in one run (-a), the pointers follow the map
tmp2 = cfgpatch.short_dir()
ra = tmp2 + '/r'
shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((live + '/').encode()):] if s.startswith((live + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
env = dict(os.environ, MK=ra, MKPURGE_TODAY='2026-11-24')
subprocess.run([build + '/mkuserpurge', '-d', '4000', '-q', '-u', '99999'], env=env, check=True, capture_output=True)
LB = 400
u0, l0 = rd('users.bbs'), rd('lastread.bbs')
N = len(u0) // UR
gone = [i for i in range(N) if u0[i * UR + 119] & 1]
keep = [i for i in range(N) if i not in gone]
# marks that tell the users apart: block i gets the number i in the first board (a new file where the sample has none)
nb = len(l0) // LB
marked = bytearray(l0 if len(l0) >= N * LB else l0 + bytes(N * LB - len(l0)))
for i in range(N):
    marked[i * LB:i * LB + 2] = (i + 1000).to_bytes(2, 'little')
open(ra + '/lastread.bbs', 'wb').write(bytes(marked))
r = run('-n', '-a')
check('dry run with -a: nothing changes, no map', r.returncode == 0 and rd('lastread.bbs') == bytes(marked) and not os.path.exists(ra + '/usermap.txt'), r.stdout + r.stderr)
r = run('-a')
lr = rd('lastread.bbs')
check('-a: the pack and the last-read step in one run (exit 0 or 2: areas of other kinds are listed)', r.returncode in (0, 2) and 'block(s) moved' in r.stdout, (r.returncode, r.stdout + r.stderr))
check('lastread.bbs: the blocks of the users who stay are at their new numbers, in order; the others are gone',
      lr == b''.join(bytes(marked[i * LB:(i + 1) * LB]) for i in keep), (len(lr), len(keep) * LB))
check('the old file is kept as lastread.bbs.prepack', rd('lastread.bbs.prepack') == bytes(marked))
check('usermap.state names the file as done for this map', 'done ' in open(ra + '/usermap.state').read() and open(ra + '/usermap.state').read().startswith('map # usermap:'))
r = run('-L')
check('a second -L moves nothing again (the file is done for this map)', r.returncode in (0, 2) and 'already done' in r.stdout and rd('lastread.bbs') == lr, r.stdout)
if r.returncode == 2:
    check('areas of other kinds of message bases are listed and left alone', 'NOT handled yet' in r.stdout, r.stdout)
else:
    check('(the sample has only Hudson areas)', True)
# users came after the pack: refused
with open(ra + '/users.bbs', 'ab') as f:
    f.write(bytes(UR))
shutil.copy(ra + '/lastread.bbs', tmp2 + '/lr.keep')
os.remove(ra + '/usermap.state')
r = run('-L')
check('-L after users came after the pack: refused (exit 3), nothing moved', r.returncode == 3 and rd('lastread.bbs') == open(tmp2 + '/lr.keep', 'rb').read(), (r.returncode, r.stderr))
os.remove(ra + '/usermap.txt')
r = run('-L')
check('-L without a map: exit 1', r.returncode == 1 and 'no pack' in r.stderr, (r.returncode, r.stderr))
r = run('-a', '-L')
check('-a and -L together: exit 1', r.returncode == 1, r.returncode)

# the other kinds of message bases: Squish (.sql, a long for each user), Fido *.msg (LastRead, a word for each user), JAM (.jlr records with the user number), Synchronet (keeps none)
import json
tmp3 = cfgpatch.short_dir()
ra = tmp3 + '/r'
shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((live + '/').encode()):] if s.startswith((live + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
env = dict(os.environ, MK=ra, MKPURGE_TODAY='2026-11-24')
cj = tmp3 + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
ms = sorted(d['messages'], key=int)
for k, (t, fid) in zip(ms[1:6], (('S', 'sqbase'), ('J', 'jambase'), ('F', 'fidodir'), ('Y', 'synbase'), ('M', 'mer.mk'))):
    d['messages'][k]['MsgBaseType'] = t
    d['messages'][k]['FileId'] = fid
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
subprocess.run([build + '/mkuserpurge', '-d', '4000', '-q', '-u', '99999'], env=env, check=True, capture_output=True)
u0 = rd('users.bbs')
N = len(u0) // UR
gone = [i for i in range(N) if u0[i * UR + 119] & 1]
keep = [i for i in range(N) if i not in gone]
sql = b''.join((i + 70000).to_bytes(4, 'little') for i in range(N))                 # user i: 70000 + i
os.makedirs(ra + '/fidodir')
lrf = b''.join((i + 1000).to_bytes(2, 'little') for i in range(N))
jlr = b''.join((i * 7).to_bytes(4, 'little') + i.to_bytes(4, 'little') + (i + 500).to_bytes(4, 'little') + (i + 900).to_bytes(4, 'little') for i in range(N))
jlr += (12345).to_bytes(4, 'little') + (N + 50).to_bytes(4, 'little') + bytes(8)       # a user number the map does not know: dropped
open(ra + '/sqbase.sql', 'wb').write(sql)
open(ra + '/fidodir/LastRead', 'wb').write(lrf)
open(ra + '/jambase.jlr', 'wb').write(jlr)
have_mer = os.path.exists(build + '/merlr')
if have_mer:
    subprocess.run([build + '/merlr', 'set', ra + '/mer.mk', str(N)], check=True)
r = run('-a')
check('-a with Squish, Fido, JAM and Synchronet areas: all handled, exit 0', r.returncode == 0 and 'NOT handled' not in r.stdout, (r.returncode, [l for l in r.stdout.splitlines() if 'NOT' in l]))
check('Squish .sql: the long of each user who stays at the new number', rd('sqbase.sql') == b''.join(sql[i * 4:i * 4 + 4] for i in keep))
check('Fido LastRead: the word of each user who stays at the new number', rd('fidodir/LastRead') == b''.join(lrf[i * 2:i * 2 + 2] for i in keep))
nj = rd('jambase.jlr')
exp = b''
for n_, i in enumerate(keep):
    exp += (i * 7).to_bytes(4, 'little') + n_.to_bytes(4, 'little') + (i + 500).to_bytes(4, 'little') + (i + 900).to_bytes(4, 'little')
check('JAM .jlr: the records of users who stay get the new user number (the rest of the record stays), the records of users who went and of unknown numbers are dropped', nj == exp, (len(nj), len(exp)))
if have_mer:
    want = [(keep[j] + 70000) for j in range(len(keep))]
    got = [int(subprocess.run([build + '/merlr', 'get', ra + '/mer.mk', str(j)], capture_output=True, text=True).stdout or -1) for j in (0, 1, len(keep) - 1)]
    gone_val = int(subprocess.run([build + '/merlr', 'get', ra + '/mer.mk', str(len(keep))], capture_output=True, text=True).stdout or -1)
    check('Merlin: the pointers of the users who stay at their new numbers, the numbers behind them empty', got == [want[0], want[1], want[-1]] and gone_val == 0, (got, want[:2], gone_val))
check('.prepack copies of all three', all(os.path.exists(ra + '/' + n + '.prepack') for n in ('sqbase.sql', 'fidodir/LastRead', 'jambase.jlr')))
r = run('-L')
check('a second -L moves nothing again', r.returncode == 0 and rd('sqbase.sql') == b''.join(sql[i * 4:i * 4 + 4] for i in keep) and nj == rd('jambase.jlr'), r.stdout)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
