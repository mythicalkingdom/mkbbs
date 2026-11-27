#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""MKMsgPkt against javascript/MessagePacket.js (node): packets written by one are read by the other, and the
bytes of the same messages written by both are the same.  Also runs "pkttest self".
usage: pkttest.py <build dir> <work dir>"""
import json, os, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
exe = os.path.join(build, 'pkttest')
js = os.path.join(here, 'pktjs.mjs')
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'pktjs: ' + name)
    if not ok:
        fails += 1


def pas(*a):
    r = subprocess.run([exe] + list(a), capture_output=True, text=True, encoding='latin-1')
    return r.returncode, r.stdout, r.stderr


def node(*a):
    r = subprocess.run(['node', js] + list(a), capture_output=True, text=True, encoding='utf-8')
    return r.returncode, r.stdout, r.stderr


if subprocess.run(['node', '--version'], capture_output=True).returncode != 0 or not os.path.isdir(os.path.join(here, '..', 'javascript')):
    print('skip: no node or no javascript directory')
    sys.exit(0)

# the self test of the unit
rc, out, err = pas('self', work)
for line in out.splitlines():
    if line.startswith('FAIL'):
        print(line)
        fails += 1
print('ok   pktjs: the unit test ran (%d checks)' % sum(1 for l in out.splitlines() if l.startswith('ok')))
if rc != 0:
    fails += 1

# JS writes, Pascal reads
jp, pp = os.path.join(work, 'js.pkt'), os.path.join(work, 'pas.pkt')
rc, out, err = node('write', jp)
check('MessagePacket.js writes the two messages (%s)' % (err.strip()[:60] if rc else 'ok'), rc == 0 and os.path.exists(jp))
rc, out, err = pas('dump', jp)
L = out.split('\n')
check('Pascal reads it: packet header (addresses, password, 2 messages, clean)',
      L[0] == 'packet 1:110/290.0 1:110/100.0 pwd=SECRET n=2 clean=TRUE')
check('... message 1: names, subject (CP437 e acute), date, area, msgid, addresses',
      L[1] == 'msg 1 from=Mark May to=All subj=Caf\x82 test date=11-16-26 time=13:14 orig=1:110/290.0 dest=1:110/100.0 attr=0 cost=0 area=TEST.ECHO msgid=1:110/290 6a0b0001')
t = L[2]
check('... its text: kludges, body, tear, origin, SEEN-BY, PATH',
      t.startswith('text ^MSGID: 1:110/290 6a0b0001|Hello|second line \x82|--- mkbbs| * Origin: mkbbs (1:110/290)|^SEEN-BY: 110/100 290|^PATH: 110/290|'))
check('... message 2: private + crash (attr 3), INTL / FMPT / TOPT addresses',
      L[3] == 'msg 2 from=Mark May to=Sysop subj=Net date=11-16-26 time=13:14 orig=1:110/290.2 dest=2:250/1.3 attr=3 cost=0 area= msgid=1:110/290.2 6a0b0002')
check('... its text', L[4].startswith('text ^INTL 2:250/1 1:110/290|^FMPT 2|^TOPT 3|^MSGID: 1:110/290.2 6a0b0002|net body|'))

# Pascal writes the same, the bytes are the same (but for the time in the packet header)
rc, out, err = pas('write', pp)
check('Pascal writes the same two messages', rc == 0 and os.path.exists(pp))
a, b = bytearray(open(jp, 'rb').read()), bytearray(open(pp, 'rb').read())
for x in (a, b):
    x[4:16] = bytes(12)
check('the two packets are the same bytes (%d / %d bytes)' % (len(a), len(b)), a == b)
if a != b:
    for i in range(min(len(a), len(b))):
        if a[i] != b[i]:
            print('  first difference at', i, a[i:i + 20], b[i:i + 20])
            break

# JS reads what Pascal wrote
rc, out, err = node('read', pp)
j = json.loads(out) if rc == 0 and out.strip() else {'packet': {}, 'messages': []}
check('MessagePacket.js reads the Pascal packet: header', j['packet'].get('origin') == '1:110/290' and j['packet'].get('destination') == '1:110/100'
      and j['packet'].get('password') == 'SECRET' and len(j['messages']) == 2)
m1, m2 = (j['messages'] + [{}, {}])[:2]
check('... message 1', m1.get('from') == 'Mark May' and m1.get('subject') == 'Café test' and m1.get('area') == 'TEST.ECHO'
      and m1.get('text', '').startswith('Hello\r\nsecond line é\r\n--- mkbbs'))
check('... message 2', m2.get('to') == 'Sysop' and m2.get('origin') == '1:110/290.2' and m2.get('destination') == '2:250/1.3' and m2.get('attr') == 3)

# the packet written by "self" in UTF-8: JS decodes it
up = os.path.join(work, 'utf.pkt')
rc, out, err = node('read', up)
j = json.loads(out) if rc == 0 and out.strip() else {'messages': []}
m1 = (j['messages'] + [{}])[0]
check('a UTF-8 packet written by Pascal (CHRS: UTF-8 4) is read by JS: names, subject, text',
      m1.get('from') == 'José' and m1.get('subject') == 'Café ░' and 'café █ end' in m1.get('text', ''))

# the hold flag written by Pascal is the attribute bit $0200 for MessagePacket.js too
rc, out, err = node('read', os.path.join(work, 'hold.pkt'))
j = json.loads(out) if rc == 0 and out.strip() else {'messages': []}
m1 = (j['messages'] + [{}])[0]
check('a message written with SetHold(True): attribute $0201 (private + hold) in MessagePacket.js', m1.get('attr') == 0x0201)

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
