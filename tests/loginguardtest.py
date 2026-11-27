#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The login guard of mklisten: a caller that fails to log on (mk ends with the errorlevel 88) is counted by address; at "fails" of them
within "window" seconds the address is refused for "block" seconds (a message, no node).  A good log-on is no failure.
Real mk over telnet on a private copy of the sample BBS.   usage: loginguardtest.py <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'login guard: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
env = dict(os.environ, MK=ra)
cfg = {'mk': build + '/mk', 'mkmon': build + '/mkmon', 'rundir': tmp + '/run', 'logfile': work + '/listen.log', 'workdir': ra, 'nodes': '1-4',
       'loginguard': {'fails': 2, 'window': 60, 'block': 6, 'allow': [], 'message': 'GUARD: try later'},
       'ports': [{'port': 24841, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra},
                 {'port': 24842, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'pw', 'config': ra}]}
json.dump(cfg, open(work + '/listen.json', 'w'))
r = subprocess.run([build + '/mklisten', '-c', work + '/listen.json', '-t'], capture_output=True, text=True)
check('the configuration with "loginguard" is accepted by mklisten -t', r.returncode == 0, r.stdout + r.stderr)
bad = dict(cfg, loginguard={'fails': 2, 'nonsense': 1})
json.dump(bad, open(work + '/bad.json', 'w'))
r = subprocess.run([build + '/mklisten', '-c', work + '/bad.json', '-t'], capture_output=True, text=True)
check('an unknown key in "loginguard" is refused', r.returncode != 0 and 'loginguard' in (r.stdout + r.stderr), r.stdout + r.stderr)
# the defaults: on, 5 failures, 600 s, an hour; the machine itself is never blocked; off with fails 0; allow takes addresses and nets
def guardline(guard):
    c = dict(cfg)
    if guard is None:
        c.pop('loginguard')
    else:
        c['loginguard'] = guard
    json.dump(c, open(work + '/g.json', 'w'))
    r = subprocess.run([build + '/mklisten', '-c', work + '/g.json', '-t'], capture_output=True, text=True)
    return [l for l in r.stdout.splitlines() if 'login guard' in l], r
gl, r = guardline(None)
check('without a "loginguard" section the guard is on: 5 failed log-ons within 600 s block the address for 3600 s, the machine itself is never blocked',
      gl and '5 failed log-ons within 600 s' in gl[0] and 'for 3600 s' in gl[0] and '127.0.0.1' in gl[0], (gl, r.stdout))
gl, r = guardline({'fails': 0})
check('"fails": 0 turns it off', gl and gl[0].strip().endswith('off'), gl)
gl, r = guardline({'allow': ['10.0.0.0/8', '192.168.1.5']})
check('"allow" replaces the list: nets (a.b.c.d/n) and single addresses', gl and '10.0.0.0/8' in gl[0] and '192.168.1.5' in gl[0] and '127.0.0.1' not in gl[0], gl)
gl, r = guardline({'allow': 'x'})
check('"allow" must be a list', r.returncode != 0 and 'allow' in (r.stdout + r.stderr), r.stdout + r.stderr)
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)


def until(s, needle, secs=8):
    s.settimeout(0.2)
    b = b''
    end = time.time() + secs
    while time.time() < end and needle not in b:
        try:
            dd = s.recv(4096)
            if not dd:
                break
            b += dd
            if b'\x1b[6n' in dd:
                s.sendall(b'\x1b[1;1R')
        except socket.timeout:
            pass
    return b


def conn(port):
    for _ in range(50):
        try:
            return socket.create_connection(('127.0.0.1', port))
        except OSError:
            time.sleep(0.1)
    raise SystemExit('cannot connect')


def attempt(pwds):
    """a caller: language, name, the passwords given; returns (what was seen, True when the BBS let it in)"""
    c = conn(24841)
    seen = until(c, b'language choice', 6)
    if b'language choice' not in seen:
        c.close()
        return seen, False                     # refused before the BBS started
    time.sleep(1.5); c.sendall(b'\r')
    seen += until(c, b'last name: ', 8); time.sleep(2.5)
    c.sendall(b'Mark May\r'); seen += until(c, b'assword')
    ok = False
    for p in pwds:
        time.sleep(0.4)
        c.sendall(p.encode() + b'\r')
        x = until(c, b'zzzz', 2.5)
        seen += x
        if b'Minutes Remaining' in x or b'continue' in x:
            ok = True
            break
    c.close()
    return seen, ok


try:
    time.sleep(2)
    seen, ok = attempt(['windows'])
    check('a good log-on gets in and is no failure', ok)
    time.sleep(1.5)
    seen, ok = attempt(['bad1', 'bad2', 'bad3'])
    check('three wrong passwords: not in (the first failed log-on)', not ok)
    time.sleep(2)
    log = open(work + '/listen.log').read()
    check('mklisten saw the errorlevel 88 (the caller was not turned away by the guard yet)', 'ended (exit 88)' in log, log[-500:])
    seen, ok = attempt(['bad1', 'bad2', 'bad3'])
    time.sleep(2)
    log = open(work + '/listen.log').read()
    check('the second failed log-on from the same address blocks it: said in the log', 'loginguard: 127.0.0.1 is blocked for 6 seconds after 2 failed log-ons' in log, log[-600:])
    c = conn(24841)
    m = until(c, b'try later', 4)
    c.close()
    check('the next caller from that address gets the message and no node', b'GUARD: try later' in m and b'language choice' not in m, m)
    check('the log says it was refused', 'refused 127.0.0.1: blocked after failed log-ons' in open(work + '/listen.log').read())
    s2 = conn(24842)
    b2 = until(s2, b'Password: ', 3)
    s2.close()
    check('the sysop port is not blocked', b'Password' in b2, b2)
    time.sleep(7)
    seen, ok = attempt(['windows'])
    check('when the block is over the address can log on again', ok, seen[-200:])
    # the machine itself (the default "allow"): failures from 127.0.0.1 never block it
    lst.terminate(); lst.wait()
    c2 = dict(cfg, loginguard={'fails': 1, 'window': 60, 'block': 30}, ports=[{'port': 24841, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}], logfile=work + '/listen2.log')
    json.dump(c2, open(work + '/listen2.json', 'w'))
    lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen2.json'], stdout=subprocess.DEVNULL)
    time.sleep(2)
    attempt(['bad1', 'bad2', 'bad3'])
    time.sleep(1.5)
    seen, ok = attempt(['windows'])
    log2 = open(work + '/listen2.log').read()
    check('failed log-ons from the machine itself (allowed by default) do not block it, even with "fails": 1', ok and 'is blocked' not in log2, (seen[-150:], log2[-300:]))
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
