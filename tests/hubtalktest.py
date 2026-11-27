#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mk -G<id> -K (talk to a hub by hand, record the call) and mk -G<id> -F<transcript> (the profile against a recording), MKHubTalk / MKHubReplay.
A fake hub is a thread; one private copy of the sample BBS.   usage: hubtalktest.py <build dir> <work dir>"""
import json, os, shutil, socket, subprocess, sys, threading, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'hub talk: ' + name + ('' if ok else '  ' + str(info)[:700]))
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
HUB = 'TalkHub'
PW = 'sEcr3tPw'
port = 25500 + os.getpid() % 300
mapf = ra + '/' + HUB + '.map'
tlog = ra + '/' + HUB + '.hub.log'


def serve():
    srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(('127.0.0.1', port)); srv.listen(5)
    while True:
        try:
            c, _ = srv.accept()
        except OSError:
            return
        threading.Thread(target=session, args=(c,), daemon=True).start()


def readline(c):
    b = b''
    while True:
        d = c.recv(1)
        if not d:
            return None
        if d in (b'\r', b'\n'):
            if b:
                return b.decode('latin-1')
            continue
        if d == b'\0':
            continue
        b += d


def session(c):
    try:
        c.sendall(b'\x1b[2JWelcome to the Fake Hub\r\nLogin: ')
        if readline(c) is None: return
        c.sendall(b'Password: ')
        if readline(c) is None: return
        c.sendall(b'\r\nMain> ')
        while True:
            d = c.recv(1)
            if not d or d == b'Q':
                c.sendall(b'Bye\r\n'); break
            if d == b'D':
                c.sendall(b'D\r\nNo new messages.\r\nMain> ')
    except OSError:
        pass
    finally:
        c.close()


threading.Thread(target=serve, daemon=True).start()
time.sleep(0.5)
open(mapf, 'w').write('inbound %s\noutbound %s\nuser Chuck Ebenschweiger\nhub localhost:%d\nscript hub.scr\nlogin lion\npassword %s\nconf 6 6\n' % (ra, ra, port, PW))
SCRIPT = '''timeout 10
expect "login:"
sendln "%login%"
expect "password:"
sendln "%password%"
expect "Main>"
send "D"
expect "Main>"
send "Q"
hangup
'''
open(ra + '/hub.scr', 'w').write(SCRIPT)


def talk(chunks, delay=0.7):
    p = subprocess.Popen([build + '/mk', '-L', '-G' + HUB, '-K'], env=env, cwd=ra, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(1.5)
    for c in chunks:
        p.stdin.write(c); p.stdin.flush(); time.sleep(delay)
    p.stdin.close()
    p.stdin = None
    try:
        out, err = p.communicate(timeout=60)
    except subprocess.TimeoutExpired:
        p.kill(); out, err = p.communicate()
    return p.returncode, out, err


rc, out, err = talk([b'lion\r', PW.encode() + b'\r', b'D', b'Q'])
tl = open(tlog, 'rb').read().decode('latin-1') if os.path.exists(tlog) else ''
check('talk: the call ends, exit 0, the hub\'s text came to the screen', rc == 0 and b'Fake Hub' in out and b'No new messages' in out, (rc, out[-200:], err[-300:]))
check('the transcript has what the hub said (cleaned) and what was typed', '<< Login:' in tl and '>> lion\r' in tl and '>> D' in tl and '>> Q' in tl and '<< No new messages.' in tl, tl)
check('the password typed is stars in the transcript, and nowhere else', '>> ********\r' in tl and PW not in tl, tl)
rep = lambda *a: subprocess.run([build + '/mk', '-L', '-G' + HUB] + list(a), env=env, cwd=ra, capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
shutil.copy(tlog, ra + '/good.log')
# replay: the script against the recording; another password makes no difference
open(mapf, 'a').write('')
p = rep('-F' + ra + '/good.log')
check('replay: the script goes the same way (exit 0)', p.returncode == 0 and 'the same way' in p.stdout, (p.returncode, p.stdout, p.stderr[-300:]))
s2 = open(mapf).read().replace('password ' + PW, 'password other-password')
open(mapf, 'w').write(s2)
p = rep('-F' + ra + '/good.log')
check('replay with another password: the stars match any', p.returncode == 0, (p.returncode, p.stdout, p.stderr[-300:]))
# a script that does something else
open(ra + '/hub.scr', 'w').write(SCRIPT.replace('send "D"', 'send "X"'))
t0 = time.time()
p = rep('-F' + ra + '/good.log')
check('replay: a script that sends other text is found out: exit 6, says what it sent and what the recording has', p.returncode == 6 and 'sent "X"' in p.stdout and 'has "D"' in p.stdout, (p.returncode, p.stdout, p.stderr[-300:]))
open(ra + '/hub.scr', 'w').write(SCRIPT.replace('expect "Main>"\nsend "D"', 'expect "Zzz never"\nsend "D"'))
t0 = time.time()
p = rep('-F' + ra + '/good.log')
check('replay: a script that waits for text that is not in the recording fails at once (not after its timeout)', p.returncode == 6 and time.time() - t0 < 8, (p.returncode, time.time() - t0, p.stdout[-300:]))
open(ra + '/hub.scr', 'w').write(SCRIPT.replace('send "Q"\nhangup', 'hangup'))
p = rep('-F' + ra + '/good.log')
check('replay: a script that ends before the recording does says so', p.returncode == 6 and 'recording goes on' in p.stdout, (p.returncode, p.stdout))
p = rep('-F' + ra + '/nonexistent.log')
check('replay: no recording: exit 1', p.returncode == 1, (p.returncode, p.stderr[-200:]))
# transfers: steps of the recording
open(ra + '/xfer.log', 'w').write('<< Login:\n>> lion\r\n<< Main>\n>> D\n<< Begin transfer now\n-- download \n-- download done\n<< Main>\n>> Q\n')
open(ra + '/xfer.scr', 'w').write('expect "login:"\nsendln "%login%"\nexpect "Main>"\nsend "D"\nexpect "begin transfer"\ndownload\nexpect "Main>"\nsend "Q"\nhangup\n')
open(mapf, 'w').write(s2.replace('script hub.scr', 'script xfer.scr'))
p = rep('-F' + ra + '/xfer.log')
check('replay: the download is a step of the recording (the script takes it at the same place)', p.returncode == 0, (p.returncode, p.stdout, p.stderr[-300:]))
open(ra + '/xfer.scr', 'w').write('expect "login:"\nsendln "%login%"\nexpect "Main>"\nsend "D"\nexpect "begin transfer"\nexpect "Main>"\nsend "Q"\nhangup\n')
p = rep('-F' + ra + '/xfer.log')
check('replay: a script that does not take the download where the recording has it: found out', p.returncode == 6, (p.returncode, p.stdout))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
