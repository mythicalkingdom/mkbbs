#!/usr/bin/env python3
"""mktoss on a private copy of the sample BBS: packets (made with MessagePacket.js under node) in the inbound
are tossed into the Hudson areas of the sample.
usage: tosstest.py <build dir> <work dir>"""
import os, re, shutil, subprocess, sys, zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
srcra = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(srcra) or subprocess.run(['node', '--version'], capture_output=True).returncode != 0:
    print('skip: no sample BBS or no node'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
cfg = tmp + '/r'
inb, outb, unsec = tmp + '/in', tmp + '/out', tmp + '/un'
for d in (inb, outb, unsec):
    os.makedirs(d)
shutil.copytree(srcra, cfg, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'echocfg.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
shutil.copy2(os.path.join(srcra, [f for f in os.listdir(srcra) if f.lower() == 'echocfg.mk'][0]), cfg + '/echocfg.mk') if any(f.lower() == 'echocfg.mk' for f in os.listdir(srcra)) else None
cfgpatch.fix_sample(cfg)
assert cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
                      lambda s: (cfg + '/').encode() + s[len((srcra + '/').encode()):] if s.startswith((srcra + '/').encode()) else s) >= 1
env = dict(os.environ, MK=cfg)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'toss: ' + name)
    if not ok:
        fails += 1


def run(prog, *a):
    return subprocess.run([os.path.join(build, prog)] + list(a), capture_output=True, text=True, env=env, encoding='latin-1')


r = run('tosssetup', inb, outb, unsec)
check('the configuration is made ready', r.returncode == 0)
r = run('tossdump', '6', '9', '10', '4')
before = {a: int(l.split('n=')[1]) for l in r.stdout.splitlines() if l.startswith('area') for a in [l.split()[1]]}
check('the sample areas open (%s)' % before, set(before) == {'6', '9', '10', '4'})

# ---- how mktoss is called: the switch, file names (the mailer's hook), one at a time
import fcntl, time
mailer_mk = cfg + '/mailer.mk'
flags = bytearray(open(mailer_mk, 'rb').read())
flags[2] &= ~128
open(mailer_mk, 'wb').write(flags)
r = run('mktoss', '-t')
check('the tosser switched off in the configuration: mktoss does nothing, says so, exit 3', r.returncode == 3 and 'not switched on' in r.stdout)
r = run('mktoss', '-t', '-q')
check('... quietly with -q', r.returncode == 3 and r.stdout == '')
r = run('mktoss', '-t', '-f')
check('-f runs it anyway', r.returncode == 0 and 'mktoss done' in r.stdout)
flags[2] |= 128
open(mailer_mk, 'wb').write(flags)
r = run('mktoss', '-t', '-q', inb + '/0001aaaa.pkt', inb + '/0002bbbb.mo1')
check('file names (as the mailer\'s hook passes them) are accepted and ignored', r.returncode == 0)
lockf = open(inb + '/mktoss.lock', 'a')
fcntl.flock(lockf, fcntl.LOCK_EX)
p1 = subprocess.Popen([os.path.join(build, 'mktoss'), '-t', '-q'], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
time.sleep(1.5)
waited = p1.poll() is None
fcntl.flock(lockf, fcntl.LOCK_UN)
try:
    p1.wait(10)
except subprocess.TimeoutExpired:
    p1.kill()
check('a second mktoss waits while another holds the lock (mktoss.lock), then runs', waited and p1.returncode == 0)
lockf.close()

r = subprocess.run(['node', os.path.join(here, 'tosspkts.mjs'), inb], capture_output=True, text=True)
check('MessagePacket.js made the packets (%s)' % r.stderr.strip()[:80], r.returncode == 0 and os.path.exists(inb + '/0001aaaa.pkt'))
open(unsec + '/0005eeee.pkt', 'wb').write(open(inb + '/0003cccc.pkt', 'rb').read())

r = run('tossmake')
check('the BBS wrote local messages (echomail in area 6, three netmails in area 4)', r.returncode == 0 and 'cannot' not in r.stdout)
mkbink = os.environ.get('MKBINK', os.path.join(repo, '..', 'mkbink', 'build', 'mkbink'))
have_mkbink = os.path.exists(mkbink)
r = run('mktoss', '-b', mkbink if have_mkbink else 'mkbink')
out = r.stdout
print(out)
check('mktoss exits 2 (some mail was bad)', r.returncode == 2)
check('the summary: 4 tossed (3 MK, 1 BBS), 2 netmail, 1 passed through, 2 duplicates, 2 bad',
      '4 tossed, 2 netmail, 1 passed through, 2 duplicates, 2 bad;' in out)
d = run('tossdump', '6', '10', '4').stdout
after = {}
cur = None
for l in d.splitlines():
    if l.startswith('area'):
        cur = l.split()[1]
        after[cur] = {'n': int(l.split('n=')[1]), 'msgs': []}
    elif l.startswith('msg '):
        after[cur]['msgs'].append([l, ''])
    elif l.startswith('text '):
        after[cur]['msgs'][-1][1] = l
if os.environ.get('TOSSDEBUG'):
    print(d)
n6 = len([m for m in after['6']['msgs'] if 'from=Remote User' in m[0]])
check('area 6 (MK): 3 new messages (first, second, third; the duplicates and the other tags are not there)', n6 == 3)
new6 = sorted([m for m in after['6']['msgs'] if 'from=Remote User' in m[0]], key=lambda m: m[0].split('subj=')[1])
check('... first mail from Remote User to All, date 11-16-26 13:14', 'subj=first mail' in new6[0][0] and 'from=Remote User' in new6[0][0] and 'date=11-16-26 time=13:14' in new6[0][0])
check('... "mk" in lower case found the area too', 'subj=second, tag in lower case' in new6[1][0] and 'subj=third mail' in new6[2][0])
check('... not marked as local or to be exported', 'echo=FALSE' in new6[0][0] and 'local=FALSE' in new6[0][0])
check('... the text is there, kludges and the origin / tear lines come with it',
      'line one|line two|' in new6[0][1] and '--- test' in new6[0][1] and 'Origin: Test System' in new6[0][1])
check('... MSGID and PID are kept as kludges (^A)', '^MSGID: 1:110/100 11111111|' in new6[0][1] and '^PID: Test 1.0|' in new6[0][1])
check('... SEEN-BY and PATH are kept (area options), hidden as kludges (^A)', '^SEEN-BY: 110/100 290|' in new6[0][1] and '^PATH: 110/100|' in new6[0][1])
check('area 10 (BBS): the mail without a MSGID was tossed (to Sysop)', after['10']['n'] - before['10'] == 1 and 'to=Sysop' in after['10']['msgs'][-1][0])
check('pass-through area 9: nothing stored', run('tossdump', '9').stdout.split('n=')[1].split()[0] == str(before['9']))
n4 = len([m for m in after['4']['msgs'] if 'from=Remote User' in m[0]])
check('netmail area (4): 2 new netmails', n4 == 2)
m1, m2 = [m for m in after['4']['msgs'] if 'from=Remote User' in m[0]]
check('... for us: private, destination 1:110/290, not sent', 'subj=netmail for us' in m1[0] and 'priv=TRUE' in m1[0] and 'dest=1:110/290' in m1[0] and 'sent=FALSE' in m1[0])
check('... for 2:250/1: stored for the scanner (not sent, not for us), origin 1:110/100.5', 'subj=netmail for 2:250/1' in m2[0] and 'sent=TRUE' in m2[0] and 'orig=1:110/100 ' in m2[0] and 'dest=2:250/1' in m2[0])
check('... INTL / FMPT are not copied into the text (the base makes them): only one FMPT', m2[1].count('FMPT') == 1 and 'MSGID: 1:110/100.5 77777777|' in m2[1])

check('the log lines: duplicate, unknown area, not linked, unknown system, damaged file',
      'duplicate in MK' in out and 'no area with the tag NOSUCHAREA' in out and 'not linked to the area LINUX' in out
      and 'not in the echo systems list' in out and 'cannot read' in out)
check('tossed packets are gone, the stranger and the not-a-packet are renamed .bad, a text file is left alone',
      not os.path.exists(inb + '/0001aaaa.pkt') and not os.path.exists(inb + '/0003cccc.pkt')
      and os.path.exists(inb + '/0002bbbb.pkt.bad') and os.path.exists(inb + '/0004dddd.pkt.bad') and os.path.exists(inb + '/notmail.txt'))
check('bad mail is kept in bad/bad.pkt (unknown area, unlinked area), readable as a packet', os.path.exists(inb + '/bad/bad.pkt'))
rb = subprocess.run([os.path.join(build, 'pkttest'), 'dump', inb + '/bad/bad.pkt'], capture_output=True, text=True, encoding='latin-1').stdout
check('... 2 messages in it (NOSUCHAREA, LINUX)', 'n=2' in rb and 'area=NOSUCHAREA' in rb and 'area=LINUX' in rb)
check('the unsecure inbound is not tossed, only mentioned', os.path.exists(unsec + '/0005eeee.pkt') and 'unsecure inbound' in out)

# ---- phase 2: passing on, scanning, packing, the outbound
def unzip(path, name):
    d = work + '/unz_' + name
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    zipfile.ZipFile(path).extractall(d)
    return [os.path.join(d, f) for f in sorted(os.listdir(d))]


def pktdump(path):
    return subprocess.run([os.path.join(build, 'pkttest'), 'dump', path], capture_output=True, text=True, encoding='latin-1').stdout


def msgs(dump):
    # [(header line, text line)] of a pkttest dump
    L = dump.split('\n')
    return [(L[i], L[i + 1]) for i in range(len(L)) if L[i].startswith('msg ')]


def subjects(ms):
    return sorted(re.search(r'subj=(.*?) date=', m[0]).group(1) for m in ms)


if have_mkbink:
    flo = {}
    for f in os.listdir(outb):
        if f.endswith('lo'):
            flo[f] = open(os.path.join(outb, f)).read().split()
    check('the outbound has the mail for 1:110/100 (hold: .hlo, crash: .clo) and for 1:110/200 (normal: .flo)',
          set(flo) == {'006e0064.hlo', '006e0064.clo', '006e00c8.flo'})
    check('... each file lists bundles / packets to be deleted after they were sent (^): hold 2 (echomail with our address, netmail with the TechNet address), crash 1, system 2 two',
          all(all(x.startswith('^') and os.path.exists(x[1:]) for x in v) for v in flo.values())
          and [len(flo[k]) for k in ('006e0064.hlo', '006e0064.clo', '006e00c8.flo')] == [2, 1, 2])
    check('the spool has no packets left (all packed and queued)', not [f for f in os.listdir(outb + '/mktoss') if f.startswith('s')])
    hold = [x for i, v in enumerate(flo['006e0064.hlo']) for x in unzip(v[1:], 'hold%d' % i)]
    crash = [x for i, v in enumerate(flo['006e0064.clo']) for x in unzip(v[1:], 'crash%d' % i)]
    check('system 1 (ZIP): the hold bundles hold one packet each, the crash bundle one', len(hold) == 2 and len(crash) == 1)
    h1 = [m for x in hold for m in msgs(pktdump(x))]
    c1 = [m for x in crash for m in msgs(pktdump(x))]
    check('... hold: the local echomail, the netmail for 1:110/100, the transit netmail for 2:250/1; nothing that came from system 1',
          subjects(h1) == ['held netmail to 1:110/100', 'local echo message', 'netmail for 2:250/1'])
    check('... crash: the crash netmail for 2:250/1 (private + crash, destination 2:250/1)',
          len(c1) == 1 and 'subj=crash netmail to 2:250/1' in c1[0][0] and 'attr=3' in c1[0][0] and 'dest=2:250/1.0' in c1[0][0]
          and 'orig=87:1001/11.0' in c1[0][0])
    ec = [m for m in h1 if 'local echo message' in m[0]][0]
    check('the scanned echomail: area MK, from us (1:110/290), SEEN-BY 110/100 200 290, PATH 110/290, a MSGID of ours, the BBS tear and origin lines',
          'area=MK' in ec[0] and 'orig=1:110/290.0' in ec[0] and '^SEEN-BY: 110/100 200 290|' in ec[1] and '^PATH: 110/290|' in ec[1]
          and '^MSGID: 1:110/290 ' in ec[1] and '--- MK Bbs v0.01|' in ec[1] and ' * Origin: ' in ec[1] and 'written by the BBS|' in ec[1])
    tr = [m for m in h1 if 'netmail for 2:250/1' in m[0]][0]
    check('the transit netmail: a Via line, INTL for 2:250/1, FMPT 5 (the point that sent it), private',
          '^Via 87:1001/11 @' in tr[1] and '^INTL 2:250/1 1:110/100|' in tr[1] and '^FMPT 5|' in tr[1] and 'attr=1 ' in tr[0])
    m2 = [m for v in flo['006e00c8.flo'] for m in msgs(pktdump(v[1:]))]
    check('system 2 (packet as it is): the 4 passed on (first, second, third mail, pass-through), the scanned one, the direct netmail',
          subjects(m2) == ['first mail', 'local echo message', 'netmail to 1:110/200', 'pass-through area', 'second, tag in lower case', 'third mail'])
    fm = [m for m in m2 if 'subj=first mail' in m[0]][0]
    check('a message passed on: unchanged but for SEEN-BY 110/100 200 290 and PATH 110/100 110/290; same MSGID and PID; our packet origin',
          'area=MK' in fm[0] and '^MSGID: 1:110/100 11111111|' in fm[1] and '^PID: Test 1.0|' in fm[1] and '^SEEN-BY: 110/100 200 290|' in fm[1]
          and '^PATH: 110/100 110/290|' in fm[1] and 'line one|line two|--- test|' in fm[1] and 'orig=1:110/290.0' in fm[0])
    check('the netmail for 1:110/200 went direct (no Via: it is ours)', '^Via' not in [m for m in m2 if 'netmail to 1:110/200' in m[0]][0][1])
    d = run('tossdump', '6', '4').stdout
    check('local messages that were sent are marked sent and not to be exported; the one that was not marked is left alone',
          re.search(r'subj=local echo message .*echo=FALSE sent=TRUE local=TRUE', d) is not None
          and re.search(r'subj=local, not to be exported .*echo=FALSE sent=FALSE', d) is not None)
    check('the netmails in area 4 are marked sent (the one that came in for 2:250/1 as well), the one for us is not',
          len(re.findall(r'subj=[^ ]*[^\n]*netmail[^\n]* sent=TRUE', d)) == 4 and re.search(r'subj=netmail for us .*sent=FALSE', d) is not None)
    names = lambda: sorted(os.listdir(outb))
    sizes = lambda: [os.path.getsize(os.path.join(outb, f)) for f in names() if os.path.isfile(os.path.join(outb, f))]
    snap = (names(), sizes())
    r2 = run('mktoss', '-b', mkbink)
    check('a second run: nothing scanned, nothing sent, the outbound is the same',
          '0 scanned, 0 netmail sent' in r2.stdout and snap == (names(), sizes()))
else:
    print('skip: mkbink is not built (../mkbink/build/mkbink): the outbound is not checked')

# a second run: nothing new, no repeats of the mail that was tossed
n_before = after['6']['n']
r = run('mktoss')
d2 = run('tossdump', '6').stdout
check('a second run changes nothing (still %d messages in area 6)' % n_before, ('n=%d' % n_before) in d2)

# a zip bundle with a packet in it (needs zip support in python, unzip on the machine)
if shutil.which('unzip'):
    shutil.copy2(inb + '/0002bbbb.pkt.bad', work + '/x.pkt')
    subprocess.run(['node', os.path.join(here, 'tosspkts.mjs'), work], capture_output=True)
    z = zipfile.ZipFile(inb + '/00aabbcc.MO1', 'w')
    z.write(work + '/0003cccc.pkt', '0003cccc.pkt')
    z.close()
    r = run('mktoss')
    d3 = run('tossdump', '6').stdout
    check('a bundle (ZIP, *.MO1) is unpacked and its packet tossed (third mail was a duplicate, "first mail" too: no new message)',
          not os.path.exists(inb + '/00aabbcc.MO1') and 'duplicate in MK' in r.stdout and ('n=%d' % n_before) in d3)
    z = zipfile.ZipFile(inb + '/00aabbdd.TU2', 'w')
    z.write(work + '/0001aaaa.pkt', '0001aaaa.pkt')
    z.close()
    r = run('mktoss')
    check('another bundle: the duplicates are found again by the dupe file', 'duplicate in MK' in r.stdout and not os.path.exists(inb + '/00aabbdd.TU2'))
else:
    print('skip: no unzip')

# ---- phase 3: areafix and packet passwords
def cfgmatrix():
    return run('tosscfg').stdout.split('\n')[:2]


if have_mkbink:
    check('before the requests: system 1 has areas 6 9 10, system 2 has 6 9',
          cfgmatrix() == ['sys1: 6=Y 9=Y 10=Y 11=n 12=n 15=n', 'sys2: 6=Y 9=Y 10=n 11=n 12=n 15=n'])
    old_flo = {f: open(os.path.join(outb, f)).read().split() for f in os.listdir(outb) if f.endswith('lo')}
    r = subprocess.run(['node', os.path.join(here, 'tossareafix.mjs'), inb], capture_output=True, text=True)
    check('MessagePacket.js made the areafix requests (%s)' % r.stderr.strip()[:60], r.returncode == 0)
    r = run('mktoss', '-b', mkbink)
    out = r.stdout
    print(out)
    check('3 areafix requests were answered (2 from system 2, 1 from system 1); the one from an unknown sender was stored',
          '3 areafix' in out and 'areafix request from 5:5/5, which is not a system of ours' in out)
    check('the packet with the wrong packet password is refused and renamed .bad', 'has the wrong packet password' in out and os.path.exists(inb + '/0010ccc1.pkt.bad'))
    check('a wrong areafix password: logged, nothing changed', 'areafix request from 1:110/200: wrong password' in out)
    check('areas linked / unlinked as asked (system 2: -MK +BBS +DAYTON_SYSOP -MKBETA day*_newsys; system 1: +LINUX -MK; the request after the --- line and the wrong password / packet password did nothing)',
          cfgmatrix() == ['sys1: 6=n 9=n 10=Y 11=Y 12=n 15=Y', 'sys2: 6=n 9=n 10=Y 11=Y 12=Y 15=n'])
    check('the hub is asked for DAYTON_SYSOP (system 1 is linked to it now) and told to stop MKBETA (pass-through, nobody takes it from us any more)',
          'area DAYTON_SYSOP is asked for from the hub 1:110/100' in out and 'area MKBETA is no longer needed' in out)
    new = {}
    for f in os.listdir(outb):
        if f.endswith('lo'):
            cur = open(os.path.join(outb, f)).read().split()
            new[f] = [x for x in cur if x not in old_flo.get(f, [])]
    newpk = {}
    for f, v in new.items():
        for x in v:
            q = x[1:]
            if f == '006e00c8.flo':
                newpk.setdefault(f, []).extend(msgs(pktdump(q)))
            else:
                newpk.setdefault(f, []).extend(m for pz in unzip(q, 'af' + os.path.basename(q)) for m in msgs(pktdump(pz)))
    to2 = newpk.get('006e00c8.flo', [])
    resp = [m for m in to2 if 'subj=Areafix response' in m[0]]
    pwerr = [m for m in to2 if 'subj=Areafix: password error' in m[0]]
    check('system 2 gets two answers: the response and the password error (flavour normal, from Areafix to the name that asked)',
          len(to2) == 2 and len(resp) == 1 and len(pwerr) == 1 and 'from=Areafix to=Remote Sysop' in resp[0][0] and 'dest=1:110/200' in resp[0][0])
    t = resp[0][1]
    check('... %QUERY shows the areas it had before the changes (* = linked), then every command is answered',
          'Areas you have:|* MK ' in t and '* MKBETA ' in t and '-MK: unlinked|' in t and '+BBS: linked|' in t and '+NOSUCH: no such area|' in t
          and '+DAYTON_SYSOP: linked|' in t and '-MKBETA: unlinked|' in t and '+DAYTON_NEWSYS: linked|' in t
          and '%FROB: not a command that is known (%HELP)|' in t)
    check('... nothing after the --- line is done (no answer about +LINUX)', 'LINUX' not in t)
    check('... the password error says so', 'the password in the subject is not right' in pwerr[0][1])
    to1 = [m for f in newpk if f.startswith('006e0064') for m in newpk[f]]
    r1 = [m for m in to1 if 'subj=Areafix response' in m[0]]
    hubreq = [m for m in to1 if 'to=Areafix' in m[0] and 'subj=secret' in m[0]]
    check('system 1 gets its answer (%LIST, +LINUX, -MK) and the request for DAYTON_SYSOP / MKBETA, with its areafix password as the subject',
          len(r1) == 1 and 'Areas you can have:|' in r1[0][1] and '+LINUX: linked|' in r1[0][1] and '-MK: unlinked|' in r1[0][1] and '(* = linked)|' in r1[0][1]
          and len(hubreq) == 1 and '+DAYTON_SYSOP|-MKBETA|' in hubreq[0][1])
    check('the unknown sender\'s request is in the netmail area for the sysop; the answers are gone from it (kill after sent)',
          re.search(r'to=Areafix .*orig=5:5/5', run('tossdump', '4').stdout) is not None and 'from=Areafix' not in run('tossdump', '4').stdout)
    check('the spool is empty again', not [f for f in os.listdir(outb + '/mktoss') if f.startswith('s')])
else:
    print('skip: no mkbink, the areafix answers are not checked')

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
