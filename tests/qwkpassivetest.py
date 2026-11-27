#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mk -Q: the login of a QWK network system (MKQwkLog), on a pty, on a private copy of the sample BBS.  The system is the user
"Mark May" (QWK node flag, password NODEPW, protocol R = a script that copies the packet / drops a reply packet).
usage: qwkpassivetest.py <build dir> <work dir>"""
import os, shutil, subprocess, sys, time, zipfile, pty, select, json

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
    print(('ok   ' if ok else 'FAIL ') + 'mk -Q: ' + name)
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
cj = os.path.join(work, 'cj'); os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
cc = dj['config']
cc['ExtPack'][1]['PCmdLine'] = 'zip -q -j'
cc['ExtPack'][1]['UCmdLine'] = 'unzip -o -q'
cc['ExtProt'][0] = {'Key': 'R', 'Attr': 3, 'Name': 'TestProt', 'CmdLine': ra + '/snd.sh %F | ' + ra + '/rcv.sh'}
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
board = 'MythKing'
for t in (['tosssetup', tmp + '/in', tmp + '/outb', tmp + '/un'], ['tossmake']):
    if t[0] == 'tossmake':
        os.makedirs(tmp + '/in', exist_ok=True)
    subprocess.run([build + '/' + t[0]] + t[1:], env=env, capture_output=True, text=True)
env2 = dict(env, NETPWD='NODEPW', NETPROT='R')
r = subprocess.run([build + '/netsetup', 'Mark May', '6'], env=env2, capture_output=True, text=True)
check('the node user is set up', 'ok' in r.stdout)
open(ra + '/snd.sh', 'w').write('#!/bin/sh\ncp "$1" %s/sent.qwk\nexit 0\n' % ra)
subprocess.run([build + '/qwkmsgtest', 'reply', ra + '/reply.msg', '6', board], check=True, capture_output=True)
with zipfile.ZipFile(ra + '/reply.zip', 'w') as z:
    z.write(ra + '/reply.msg', board.upper() + '.MSG')
open(ra + '/rcv.sh', 'w').write('#!/bin/sh\ncp %s/reply.zip ./up.rep\nexit 0\n' % ra)
for f in ('snd.sh', 'rcv.sh'):
    os.chmod(ra + '/' + f, 0o755)


def dump(n):
    return subprocess.run([build + '/tossdump', str(n)], env=env, capture_output=True, text=True, encoding='latin-1').stdout


def session(script, timeout=40):
    """script: [(wait for, send)]; returns (output, exit code)"""
    m, s = pty.openpty()
    p = subprocess.Popen([build + '/mk', '-Q'], env=env, cwd=ra, stdin=s, stdout=s, stderr=s, close_fds=True)
    os.close(s)
    out = b''
    pos = 0
    t0 = time.time()
    for wait, send in script:
        while wait.encode() not in out[pos:] and time.time() - t0 < timeout:
            if select.select([m], [], [], 0.2)[0]:
                try:
                    d = os.read(m, 4096)
                except OSError:
                    break
                if not d:
                    break
                out += d
            elif p.poll() is not None:
                break
        if wait.encode() in out[pos:]:
            pos = out.index(wait.encode(), pos) + len(wait)
            if send:
                os.write(m, send.encode())
    end = time.time() + 10
    while p.poll() is None and time.time() < end:
        if select.select([m], [], [], 0.2)[0]:
            try:
                out += os.read(m, 4096)
            except OSError:
                break
    if p.poll() is None:
        p.kill()
    os.close(m)
    return out.decode('latin-1'), p.returncode


o, rc = session([('Login: ', 'Mark May\r'), ('Password: ', 'WRONG\r'), ('Login: ', 'Mark May\r'), ('Password: ', 'bad\r'),
                 ('Login: ', 'Mark May\r'), ('Password: ', 'bad\r')])
check('a wrong password three times: Login incorrect, hung up', o.count('Login incorrect') == 3 and 'QWK:' not in o)
o, rc = session([('Login: ', 'Chuck Ebenschweiger\r'), ('Password: ', 'x\r'), ('Login: ', '\r'), ('Password: ', '\r'), ('Login: ', '\r'), ('Password: ', '\r')])
check('a user without the QWK node flag cannot come in', 'QWK:' not in o)
before = dump(6)
o, rc = session([('Login: ', 'Mark May\r'), ('Password: ', 'nodepw\r'), ('QWK: ', '?'), ('QWK: ', 'D'), ('QWK: ', 'U'), ('QWK: ', 'Q')])
check('login with the password (any case): the QWK: prompt', 'QWK:' in o and 'Download QWK message packet' in o and 'Logging on to' in o)
check('D: the packet was sent (a ZIP with MESSAGES.DAT)', os.path.exists(ra + '/sent.qwk') and 'messages.dat' in [n.lower() for n in zipfile.ZipFile(ra + '/sent.qwk').namelist()])
check('U: the reply packet was posted', dump(6) != before)
check('Q: ends the call, exit 0', rc == 0)

# control messages to SBBS: the areas of the node and its last read pointers (ADD, DROP, RESET)
def ctl(*cmds):
    subprocess.run([build + '/qwkmsgtest', 'control', ra + '/reply.msg', board] + list(cmds), check=True, capture_output=True)
    os.remove(ra + '/reply.zip')
    with zipfile.ZipFile(ra + '/reply.zip', 'w') as z:
        z.write(ra + '/reply.msg', board.upper() + '.MSG')


names = []


def pull(*cmds):
    """upload control messages, then download: the number of messages in the packet in area 6 (-1 = no packet)"""
    if os.path.exists(ra + '/sent.qwk'):
        os.remove(ra + '/sent.qwk')
    ctl(*cmds)
    o, rc = session([('Login: ', 'Mark May\r'), ('Password: ', 'nodepw\r'), ('QWK: ', 'U'), ('QWK: ', 'D'), ('QWK: ', 'Q')])
    if not os.path.exists(ra + '/sent.qwk'):
        return -1, o
    with zipfile.ZipFile(ra + '/sent.qwk') as z:
        global names
        names = [n.lower() for n in z.namelist()]
        z.extract([n for n in z.namelist() if n.lower() == 'messages.dat'][0], work)
    d = subprocess.run([build + '/qwkmsgtest', 'dump', work + '/messages.dat'], capture_output=True, text=True, encoding='latin-1').stdout
    os.remove(work + '/messages.dat')
    return d.count(' conf=6 '), o


n, o = pull('6:RESET')
check('RESET: the pointer is back at the start, the area is in the packet', n >= 2 and 'RESET 6: done' in o)
check('... the control message is not posted', 'RESET' not in dump(6) or 'control message' not in dump(6))
n, o = pull('6:DROP')
check('DROP: the area leaves the packets', n <= 0 and 'DROP 6: done' in o)
n, o = pull('6:ADD 999999')
check('ADD with a pointer past the end: joined, nothing new', n <= 0 and 'ADD 6: done' in o)
n, o = pull('6:RESET 01/01/80')
check('RESET with a date: all messages from that day', n >= 2)
n, o = pull('6:RESET 12/31/79')
check('... a date after the last message: nothing new', n <= 0)
n, o = pull('6:RESETALL -1')
check('RESETALL -msgs: the last message only', n == 1 and 'RESETALL: done' in o)
n, o = pull('6:DROP 6', '6:FILES ON')
check('DROP conf# and an ignored command', n <= 0 and 'FILES: ignored' in o)
n, o = pull('3:NOSUCH')
check('an unknown command is not done and not posted', 'NOSUCH 3: not done' in o and 'NOSUCH' not in dump(3))
n, o = pull('6:ADD', '6:RESET')
check('a new node gets CONTROL.DAT and DOOR.ID by default', n >= 2 and 'control.dat' in names and 'door.id' in names)
n, o = pull('6:CONTROL OFF', '6:ADD', '6:RESET')
check('CONTROL OFF: they are gone (as on Synchronet without CONTROL ON)', n >= 2 and 'control.dat' not in names and 'door.id' not in names)
n, o = pull('6:RESET')
check('... and stay out (the setting is the node\'s)', 'control.dat' not in names)
n, o = pull('6:CONTROL ON', '6:ADD', '6:RESET')
check('CONTROL ON: they are in the packet again', 'control.dat' in names and 'door.id' in names)
n, o = pull('6:CONTROL MAYBE')
check('CONTROL with another value is not done', 'CONTROL: not done' in o)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
