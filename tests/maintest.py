#!/usr/bin/env python3
"""mkmaint: the purge of the message areas by their limits (days kept, received days, messages kept), a dry run, what never goes (unread private mail, a message waiting to be
sent).  Private copies of the sample BBS.   usage: maintest.py <build dir> <work dir>"""
import json, os, re, shutil, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
live = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(live) or not os.path.exists(build + '/mkmaint'):
    print('skip: no sample BBS or mkmaint'); sys.exit(0)
fails = 0
sys.path.insert(0, here)
import fixture
live_before = fixture.live_state()


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkmaint: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)


def private(limits, squish=False, kind=''):
    """a private copy of the sample; limits = {area: (days, rcvd, kept)}"""
    tmp = cfgpatch.short_dir()
    ra = tmp + '/r'
    shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
    cfgpatch.fix_sample(ra)
    sq = {(repo + '/bbs/bbse/comp').encode(): (ra + '/sqp').encode()} if squish else {}     # a Squish base of the sample, made new in the copy
    def fn(s):
        t = s.rstrip(b'/')
        if t in sq:
            return sq[t] + s[len(t):]
        if s.startswith((live + '/').encode()):
            return (ra + '/').encode() + s[len((live + '/').encode()):]
        return b'/nonexistent/' + s[len((repo + '/bbs/').encode()):]
    cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), fn)
    if squish:
        os.makedirs(ra + '/sqp')
    env = dict(os.environ, MK=ra)
    cj = tmp + '/cj'
    os.makedirs(cj)
    envj = dict(env, MKJSON=cj)
    subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
    d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
    for k, v in d['messages'].items():
        v['DaysKept'] = v['MsgsKept'] = v['RcvdDays'] = 0
    for a, (dk, rd, kp) in limits.items():
        m = d['messages'][str(a)]
        m['DaysKept'], m['RcvdDays'], m['MsgsKept'] = dk, rd, kp
        if squish:
            if kind:
                m['MsgBaseType'] = kind
            m['MsgType'] = 0                  # a local area: nothing waits to be sent (an echomail area would keep the message that was just posted)
    json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
    subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
    return ra, env


def dump(env, area):
    o = subprocess.run([build + '/tossdump', str(area)], env=env, capture_output=True, text=True, encoding='latin-1').stdout
    msgs = re.findall(r'^msg (\d+) from=(.*?) to=(.*?) subj=(.*?) date=', o, re.M)
    return [(int(n), s) for n, f, t, s in msgs]


def post(env, area, subj, **flags):
    e = dict(env, **flags)
    subprocess.run([build + '/postmsg', str(area), 'Tester', 'All', subj, 'text'], env=e, capture_output=True, text=True)


def mk(env, *args, today=None):
    e = dict(env)
    if today:
        e['MKMAINT_TODAY'] = today
    return subprocess.run([build + '/mkmaint'] + list(args), env=e, capture_output=True, text=True)


def files_state(ra):
    import hashlib
    return {f: hashlib.sha256(open(os.path.join(ra, f), 'rb').read()).hexdigest() for f in sorted(os.listdir(ra)) if f.lower().startswith('msg') and f.lower().endswith('.bbs')}


# 1. the old messages of "T Pascal" (area 183, 1995): days kept 365
ra, env = private({183: (365, 0, 0)})
n0 = len(dump(env, 183))
other = dump(env, 4)
st = files_state(ra)
r = mk(env, '-n')
check('dry run: says what would be purged in area 183 and in no other area, changes nothing', r.returncode == 0 and re.search(r'area 183 .*: %d message\(s\), would purge %d ' % (n0, n0), r.stdout) and files_state(ra) == st and 'a dry run' in r.stdout and n0 > 10, (n0, r.stdout[-300:]))
r = mk(env)
left = dump(env, 183)
check('a purge by age: every message of 1995 goes (days kept 365), the other areas are as they were', r.returncode == 0 and len(left) == 0 and dump(env, 4) == other and 'purged %d message' % n0 in r.stdout, (len(left), r.stdout[-300:]))
r = mk(env)
check('a second run finds nothing more', 'purged 0 message' in r.stdout, r.stdout[-200:])

# 2. messages kept: the newest 10 stay
ra, env = private({183: (0, 0, 10)})
before = dump(env, 183)
r = mk(env)
left = dump(env, 183)
check('messages kept 10: the 10 newest (the highest numbers) stay', r.returncode == 0 and left == before[-10:], (before[-12:], left))
r = mk(env, '-a', '183', '-v')
check('-a one area, -v: nothing is left to say', r.returncode == 0, r.stdout)

# 3. what never goes, and the received days; "today" is moved a year ahead so the new messages are old
ra, env = private({1: (30, 0, 0), 6: (30, 0, 0)})
p1 = dump(env, 1)
post(env, 1, 'public old')
post(env, 1, 'private unread', POSTPRIV='1')
post(env, 1, 'private read', POSTPRIV='1', POSTRCVD='1')
post(env, 6, 'echo waiting', POSTTYPE='echo')
future = time.strftime('%Y-%m-%d', time.localtime(time.time() + 400 * 86400))
r = mk(env, today=future)
a1 = [s for n, s in dump(env, 1)]
a6 = [s for n, s in dump(env, 6)]
check('days kept 30, a year later: the public message goes, the unread private one stays, the read private one goes', 'public old' not in a1 and 'private unread' in a1 and 'private read' not in a1, (a1, r.stdout[-300:]))
check('an echomail message that the tosser has not scanned yet stays however old', 'echo waiting' in a6, a6)
check('the summary says how many were kept for sending or unread', re.search(r'area 1 .*kept for sending or unread', r.stdout) and re.search(r'area 6 .*kept for sending or unread', r.stdout), r.stdout)
ra, env = private({1: (0, 30, 0)})
post(env, 1, 'normal unread')
post(env, 1, 'normal read', POSTRCVD='1')
r = mk(env, today=future)
a1 = [s for n, s in dump(env, 1)]
check('received days 30: the read message goes, the unread one stays (days kept is off)', 'normal read' not in a1 and 'normal unread' in a1, a1)
check('a day that is not yet old: nothing goes', 'purged 0' in mk(env, today=time.strftime('%Y-%m-%d')).stdout)
r = subprocess.run([build + '/mkmaint', '-c', ra, '-n', '-q'], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('-c <dir> instead of MK in the environment', r.returncode == 0 and 'would purge' in r.stdout, (r.returncode, r.stdout, r.stderr))
r = mk(env, '-a', '9999')
check('an area that is not there: exit 1', r.returncode == 1, (r.returncode, r.stderr))
r = mk(env, today='nonsense')
check('a bad MKMAINT_TODAY: exit 1', r.returncode == 1, (r.returncode, r.stderr))
r = subprocess.run([build + '/mkmaint'], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('no configuration: exit 1, says so', r.returncode == 1 and 'No configuration' in r.stderr, (r.returncode, r.stderr))
cjs = cfgpatch.short_dir() + '/n'
os.makedirs(cjs)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=dict(os.environ, MK=cfgpatch.snapshot(live), MKJSON=cjs), check=True, capture_output=True)
SQ = int([k for k, v in json.load(open(cjs + '/bbsconfig.json', encoding='utf-8'))['messages'].items() if v['Name'] == 'U-Pascal'][0])
# a Squish base (U-Pascal of the sample, made new in the copy): the same rules through the common message object
ra, env = private({SQ: (30, 0, 0)}, squish=True)
post(env, SQ, 'squish old')
post(env, SQ, 'squish private', POSTPRIV='1')
r = mk(env, today=future)
a112 = [s for n, s in dump(env, SQ)]
check('a Squish base: a message that is old goes, an unread private one stays', 'squish old' not in a112 and 'squish private' in a112 and r.returncode == 0, (a112, r.stdout[-300:], r.stderr[-200:]))
# packing the Hudson bases (-p): the deleted messages leave the files, the others are as they were
ra, env = private({183: (365, 0, 0)})
post(env, 6, 'echo A', POSTTYPE='echo')
post(env, 6, 'echo B', POSTTYPE='echo')
def full(area):
    return subprocess.run([build + '/tossdump', str(area)], env=env, capture_output=True, text=True, encoding='latin-1').stdout
keep_before = {a: full(a) for a in (1, 4, 6)}
big = lambda: sum(os.path.getsize(ra + '/' + f) for f in ('msghdr.bbs', 'msgidx.bbs', 'msgtoidx.bbs', 'msgtxt.bbs'))
size0 = big()
echo0 = open(ra + '/echomail.bbs', 'rb').read() if os.path.exists(ra + '/echomail.bbs') else b''
r = mk(env, '-n', '-p')
check('-n -p: says which base has deleted messages and would be packed (after nothing is deleted yet: none), changes nothing', r.returncode == 0 and big() == size0, r.stdout[-300:])
r = mk(env)
size1 = big()
check('the purge only marks the messages deleted: the files are as big as before', size1 == size0, (size0, size1))
r = mk(env, '-n', '-p')
check('-n -p after the purge: the base would be packed, nothing is changed', re.search(r'pack \S+/: \d+ deleted message\(s\) of \d+ would be removed', r.stdout) and big() == size1 and 'would be packed' in r.stdout, r.stdout[-400:])
r = mk(env, '-p')
size2 = big()
check('-p: the deleted messages leave the files, the files are smaller, the bytes given back are said', r.returncode == 0 and size2 < size1 and re.search(r'deleted message\(s\) removed, \d+ stay, %d bytes given back' % (size1 - size2), r.stdout), (size1, size2, r.stdout[-400:]))
check('the messages of the other areas are the same, with their texts (areas 1, 4 and 6)', all(full(a) == keep_before[a] for a in (1, 4, 6)))
check('area 183 is empty', len(dump(env, 183)) == 0)
info = open(ra + '/msginfo.bbs', 'rb').read()
nhdr = os.path.getsize(ra + '/msghdr.bbs') // 187
act = int.from_bytes(info[4:6], 'little')
check('msginfo.bbs counts the messages that are left (Active, the high number is kept so that numbers are not used again)', act == nhdr and act > 0, (act, nhdr))
hdr = open(ra + '/msghdr.bbs', 'rb').read()
ech = open(ra + '/echomail.bbs', 'rb').read() if os.path.exists(ra + '/echomail.bbs') else b''
pos = [int.from_bytes(ech[i:i + 2], 'little') for i in range(0, len(ech), 2)]
subjects = [hdr[p * 187 + 114 + 1: p * 187 + 114 + 1 + hdr[p * 187 + 114]].decode('latin-1') for p in pos if p < nhdr]
check('echomail.bbs (the messages waiting to be exported) points at the headers of the same messages in their new places', subjects[-2:] == ['echo A', 'echo B'] and len(subjects) == len(pos), (pos[-3:], subjects[-3:]))
check('the old files are kept as name.prepack', all(os.path.exists(ra + '/' + f + '.prepack') for f in ('msghdr.bbs', 'msgtxt.bbs', 'msgidx.bbs', 'msgtoidx.bbs', 'msginfo.bbs')))
before_high = int.from_bytes(info[2:4], 'little')
post(env, 6, 'after the pack')
check('a message can be written after the pack and gets the next number', [n for n, t in dump(env, 6) if t == 'after the pack'] == [before_high + 1], (before_high, dump(env, 6)[-2:]))
r = mk(env, '-p')
check('a second -p finds nothing to pack', '0 message base(s) packed' in r.stdout, r.stdout[-200:])
# -x: the copies are removed at once
ra, env = private({183: (365, 0, 0)})
mk(env)
r = mk(env, '-p', '-x')
check('-p -x: packed, no .prepack files are left', r.returncode == 0 and 'bytes given back' in r.stdout and not [f for f in os.listdir(ra) if f.endswith('.prepack')], (r.stdout[-200:], [f for f in os.listdir(ra) if f.endswith('.prepack')]))

# packing a JAM base (the area of the Squish test, made a JAM base): numbers stay, the headers and texts of deleted messages go, the empty entries at the start of the index leave
ra, env = private({SQ: (30, 0, 0)}, squish=True, kind='J')
for subj, fl in (('j1 public', {}), ('j2 private', dict(POSTPRIV='1')), ('j3 public', {}), ('j4 private', dict(POSTPRIV='1')), ('j5 public', {})):
    post(env, SQ, subj, **fl)
before = dump(env, SQ)
check('JAM: five messages are in the base', [t for n, t in before] == ['j1 public', 'j2 private', 'j3 public', 'j4 private', 'j5 public'], before)
r = mk(env, today=future)
mid = dump(env, SQ)
check('JAM: the purge by age deletes the public ones, the unread private ones stay (numbers 2 and 4)', mid == [before[1], before[3]], (mid, r.stdout[-300:]))
base = [f for f in os.listdir(ra + '/sqp') if f.endswith('.jhr')][0][:-4]
sz = lambda: sum(os.path.getsize(ra + '/sqp/' + base + e) for e in ('.jhr', '.jdt', '.jdx'))
s0 = sz()
r = mk(env, '-n', '-p', today=future)
check('JAM: -n -p says the base would be packed and changes nothing', 'would be packed' in r.stdout and sz() == s0, r.stdout[-300:])
text_before = full(SQ) if False else subprocess.run([build + '/tossdump', str(SQ)], env=env, capture_output=True, text=True, encoding='latin-1').stdout
r = mk(env, '-p', today=future)
s1 = sz()
check('JAM: -p removes the deleted messages: the files are smaller by the bytes said', r.returncode == 0 and s1 < s0 and re.search(r'\(JAM\): 3 deleted message\(s\) removed, 2 stay, %d bytes given back' % (s0 - s1), r.stdout), (s0, s1, r.stdout[-300:]))
after = dump(env, SQ)
text_after = subprocess.run([build + '/tossdump', str(SQ)], env=env, capture_output=True, text=True, encoding='latin-1').stdout
check('JAM: the two messages are as they were, with the same numbers and texts', after == mid and text_after.split('\n', 1)[1] == text_before.split('\n', 1)[1], (after, mid))
hdr = open(ra + '/sqp/' + base + '.jhr', 'rb').read()
basenum = int.from_bytes(hdr[20:24], 'little')
check('JAM: the number of the first message moved up past the deleted one at the start (2); the active count is 2', basenum == 2 and int.from_bytes(hdr[12:16], 'little') == 2, (basenum, int.from_bytes(hdr[12:16], 'little')))
post(env, SQ, 'j6 after')
check('JAM: the next message gets the next number (6): numbers are not used again', [n for n, t in dump(env, SQ) if t == 'j6 after'] == [6], dump(env, SQ))
check('JAM: the old files are kept as .prepack', all(os.path.exists(ra + '/sqp/' + base + e + '.prepack') for e in ('.jhr', '.jdt', '.jdx')))
r = mk(env, '-p')
check('JAM: a second pack finds nothing to pack', '0 message base(s) packed' in r.stdout, r.stdout[-200:])

import fixture
check('nothing was written into the live sample', fixture.live_state() == live_before)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
