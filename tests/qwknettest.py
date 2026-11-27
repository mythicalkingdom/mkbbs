#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mk -G<id>: a pass with a QWK network system (MKQwkNet), on a private copy of the sample BBS.  The system is the user
"Chuck Ebenschweiger" (QWK node flag, ZIP, area 6 in his offline mail); its map file says conference 12 = area 6.
usage: qwknettest.py <build dir> <work dir>"""
import os, shutil, subprocess, sys, zipfile

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src) or not shutil.which('zip') or not shutil.which('unzip'):
    print('skip: no sample BBS (or no zip/unzip)'); sys.exit(0)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'qwknet: ' + name)
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
env = dict(os.environ, MK=ra)
# the packer commands for this machine
import json
cj = os.path.join(work, 'cj'); os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
dj['config']['ExtPack'][1]['PCmdLine'] = 'zip -q -j'
dj['config']['ExtPack'][1]['UCmdLine'] = 'unzip -o -q'
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)

inb, outb, run = work + '/in', work + '/out', work + '/run'
for d in (inb, outb, run):
    os.makedirs(d)
open(ra + '/NODE1.map', 'w').write('; the hub\ninbound %s\noutbound %s\nuser Chuck Ebenschweiger\nconf 12 6   ; the hub calls it 12\nconf 3 6\n' % (inb, outb))
r = subprocess.run([build + '/netsetup', 'Chuck Ebenschweiger', '6'], env=env, capture_output=True, text=True)
check('the node user is set up (QWK node, ZIP, area 6)', r.returncode == 0 and 'ok' in r.stdout)


# two local messages in area 6 (written like the BBS editor does)
for t in (['tosssetup', tmp + '/in', tmp + '/outb', tmp + '/un'], ['tossmake']):
    if t[0] == 'tossmake':
        os.makedirs(tmp + '/in', exist_ok=True)
    subprocess.run([build + '/' + t[0]] + t[1:], env=env, capture_output=True, text=True)


def mk(*args):
    return subprocess.run([build + '/mk', '-L'] + list(args), env=env, cwd=run, capture_output=True, text=True, encoding='latin-1', stdin=subprocess.DEVNULL, timeout=120)


def dump(n):
    return subprocess.run([build + '/tossdump', str(n)], env=env, capture_output=True, text=True, encoding='latin-1').stdout


def packet(conf):
    subprocess.run([build + '/qwkmsgtest', 'hub', work + '/messages.dat', str(conf)], check=True, capture_output=True)
    q = inb + '/node1.qwk'                        # the case of the name is the hub's
    with zipfile.ZipFile(q, 'w') as z:
        z.write(work + '/messages.dat', 'MESSAGES.DAT')
    os.remove(work + '/messages.dat')


r = mk('-GNOPE')
check('no map file: exit 1', r.returncode == 1)
before = dump(6)
check('the sample area has messages to send', len(before) > 50)
packet(12)
r = mk('-GNODE1')
print(r.stdout[-700:], r.stderr[-300:])
check('mk -GNODE1 runs: exit 0', r.returncode == 0)
check('the reply packet NODE1.rep is in the outbound directory', os.path.exists(outb + '/NODE1.rep'))
names = zipfile.ZipFile(outb + '/NODE1.rep').namelist() if os.path.exists(outb + '/NODE1.rep') else []
check('... a ZIP with NODE1.msg', names == ['NODE1.msg'])
if names:
    with zipfile.ZipFile(outb + '/NODE1.rep') as z:
        z.extract('NODE1.msg', work)
    rd = subprocess.run([build + '/qwkmsgtest', 'dump', work + '/NODE1.msg', 'rep'], capture_output=True, text=True, encoding='latin-1').stdout
    check('... its messages are in conference 12 (the number field of a REP), the local ones, none from the hub', rd.count('msg ') >= 2 and 'conf=12' in rd and 'conf=6 ' not in rd and 'Hub message' not in rd and 'local echo message' in rd)
check('the packet of the hub is posted: the two messages of conference 12 are in area 6', 'Hub message one' in dump(6) and 'Hub message two' in dump(6))
check('... the one of the unmapped conference 99 is not', 'Unmapped' not in dump(6))
check('... NODE1.qwk is kept as .old', os.path.exists(inb + '/node1.qwk.old') and not os.path.exists(inb + '/node1.qwk'))
check('... the duplicate file is next to the map file', os.path.exists(ra + '/NODE1.dup'))

# the next pass: the last REP is still there; then without it: nothing new for the hub (its own messages do not come back)
os.remove(outb + '/NODE1.rep')
r = mk('-GNODE1')
check('a second pass: no packet, exit 0, no new reply packet (the hub messages are not sent back)', r.returncode == 0 and not os.path.exists(outb + '/NODE1.rep'))
# the same packet again: the messages are duplicates
packet(12)
r = mk('-GNODE1')
check('the same packet again: duplicates, nothing is posted twice', r.returncode == 0 and dump(6).count('Hub message one') == 1)
# new messages of this BBS go to the hub, the hub messages still do not
subprocess.run([build + '/tossmake'], env=env, capture_output=True, text=True)
r = mk('-GNODE1')
check('new local messages are in the next reply packet', r.returncode == 0 and os.path.exists(outb + '/NODE1.rep'))
if os.path.exists(outb + '/NODE1.rep'):
    with zipfile.ZipFile(outb + '/NODE1.rep') as z:
        z.extract('NODE1.msg', work)
    rd = subprocess.run([build + '/qwkmsgtest', 'dump', work + '/NODE1.msg', 'rep'], capture_output=True, text=True, encoding='latin-1').stdout
    check('... exactly the 2 new ones, none from the hub (the last read was moved past the hub messages)', rd.count('msg ') == 2 and 'Hub message' not in rd and 'local echo message' in rd)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
