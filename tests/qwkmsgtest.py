#!/usr/bin/env python3
"""MKMsgQwk against javascript/MessageQWK.js (node): files written by one are read by the other, and the bytes of the
same messages written by both are the same (MESSAGES.DAT style and REP style).  Also runs "qwkmsgtest self".
usage: qwkmsgtest.py <build dir> <work dir>"""
import json, os, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
exe = os.path.join(build, 'qwkmsgtest')
js = os.path.join(here, 'qwkjs.mjs')
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'qwkjs: ' + name)
    if not ok:
        fails += 1


def pas(*a):
    r = subprocess.run([exe] + list(a), capture_output=True, text=True, encoding='latin-1')
    return r.returncode, r.stdout, r.stderr


def node(*a):
    r = subprocess.run(['node', js] + list(a), capture_output=True, text=True, encoding='utf-8')
    return r.returncode, r.stdout, r.stderr


# the self test of the unit
rc, out, err = pas('self', work)
for line in out.splitlines():
    if line.startswith('FAIL'):
        print(line)
        fails += 1
print('ok   qwkjs: the unit test ran (%d checks)' % sum(1 for l in out.splitlines() if l.startswith('ok')))
if rc != 0:
    fails += 1

if subprocess.run(['node', '--version'], capture_output=True).returncode != 0 or not os.path.isdir(os.path.join(here, '..', 'javascript')):
    print('skip: no node or no javascript directory')
    sys.exit(1 if fails else 0)

for mode in ('', 'rep'):
    tag = ('REP style: ' if mode else 'MESSAGES.DAT style: ')
    args = (mode,) if mode else ()
    jp, pp = os.path.join(work, 'js%s.dat' % mode), os.path.join(work, 'pas%s.dat' % mode)
    rc, out, err = node('write', jp, *args)
    check(tag + 'MessageQWK.js writes the three messages (%s)' % (err.strip()[:80] if rc else 'ok'), rc == 0 and os.path.exists(jp))
    rc, out, err = pas('write', pp, *args)
    check(tag + 'Pascal writes the same three messages', rc == 0 and os.path.exists(pp))
    a, b = open(jp, 'rb').read(), open(pp, 'rb').read()
    check(tag + 'the two files are the same bytes (%d / %d bytes)' % (len(a), len(b)), a == b)
    if a != b:
        for i in range(min(len(a), len(b))):
            if a[i] != b[i]:
                print('  first difference at', i, a[i:i + 24], b[i:i + 24])
                break
    # Pascal reads the JS file
    rc, out, err = pas('dump', jp, *args)
    L = out.split('\n')
    check(tag + 'Pascal reads the JS file: id MKBBS, 3 messages, clean', L[0] == 'file id=MKBBS n=3 clean=T')
    ec = 'T' if mode else 'F'
    num1 = 7 if mode else 1
    check(tag + '... message 1: conference 7, names, subject (CP437), date, msgid',
          L[1] == 'msg 1 conf=7 qwk=%d logical=%s from=MARK MAY to=ALL subj=Caf\x82 test date=11-16-26 time=13:14 priv=F rcvd=F ref=0 status=  echo=%s tag=F msgid=1:110/290 6a0b0001 reply=' % (num1, '1' if not mode else '', ec) if not mode else
          L[1].startswith('msg 1 conf=7 qwk=7 ') and 'from=MARK MAY to=ALL subj=Caf\x82 test date=11-16-26 time=13:14' in L[1] and ' echo=T ' in L[1])
    check(tag + '... its text: the MSGID kludge, the body with CP437 e acute',
          L[2] == 'text ^MSGID: 1:110/290 6a0b0001|Hello|second line \x82|')
    check(tag + '... message 2: private, reference 1, reply id', ' priv=T rcvd=F ref=1 ' in L[3] and ' reply=1:110/290 6a0b0001' in L[3])
    check(tag + '... message 3: private and read, conference 12', 'conf=12' in L[5] and ' priv=T rcvd=T ' in L[5] and L[6] == 'text three||lines|')
    # JS reads the Pascal file
    rc, out, err = node('read', pp, *args)
    j = json.loads(out) if rc == 0 and out.strip() else {'info': {}, 'messages': []}
    m = j['messages']
    check(tag + 'MessageQWK.js reads the Pascal file: id and 3 messages', j['info'].get('packetId') == 'MKBBS' and len(m) == 3)
    check(tag + '... message 1: fields and text',
          len(m) == 3 and m[0]['conference'] == 7 and m[0]['from'] == 'MARK MAY' and m[0]['to'] == 'ALL' and m[0]['subject'] == 'Café test'
          and m[0]['msgId'] == '1:110/290 6a0b0001' and m[0]['text'] == 'Hello\r\nsecond line é')
    check(tag + '... message 2: private, unread, reference 1, reply id',
          len(m) == 3 and m[1]['isPrivate'] and not m[1]['isReceived'] and m[1]['reference'] == 1 and m[1]['replyId'] == '1:110/290 6a0b0001')
    check(tag + '... message 3: private and read, conference 12, empty line kept',
          len(m) == 3 and m[2]['conference'] == 12 and m[2]['isPrivate'] and m[2]['isReceived'] and m[2]['text'] == 'three\r\n\r\nlines')

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
