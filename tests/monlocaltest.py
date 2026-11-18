#!/usr/bin/env python3
"""mkmon L key: the BBS in local mode (mk -L -N<localnode>) on the sysop connection, back to the node table.
usage: monlocaltest.py <mklisten> <mkmon> <workdir>"""
import os, re, socket, subprocess, sys, time, json, stat

mklisten, mkmon, work = [os.path.abspath(a) for a in sys.argv[1:4]]
os.makedirs(work, exist_ok=True)
run = os.path.join(work, 'run')
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + name)
    if not ok:
        fails += 1


def connect(port):
    for _ in range(50):
        s = socket.socket()
        try:
            s.connect(('127.0.0.1', port))
            s.settimeout(0.2)
            return s
        except OSError:
            s.close()
            time.sleep(0.1)
    raise SystemExit('cannot connect')


def read_until(s, needle, secs=4):
    buf = b''
    end = time.time() + secs
    while time.time() < end and needle not in buf:
        try:
            d = s.recv(4096)
            if not d:
                break
            buf += d
        except socket.timeout:
            pass
    return buf


def login(port):
    s = connect(port)
    read_until(s, b'Password: ')
    s.sendall(b'sesame\r')
    read_until(s, b'R refresh', 5)
    return s


fake = os.path.join(work, 'fakemk.sh')
open(fake, 'w').write('#!/bin/sh\necho "FAKE-LOCAL $* TERM=$TERM"\nread x\necho "GOT $x"\nexit ${FAKE_EXIT:-0}\n')
os.chmod(fake, 0o755)


def config(name, **extra):
    cfg = {'mk': fake, 'mkmon': mkmon, 'logfile': os.path.join(work, name + '.log'), 'rundir': run,
           'ports': [{'port': 24621, 'type': 'telnet', 'nodes': '1-2', 'bind': '127.0.0.1'},
                     {'port': 24622, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'sesame'}]}
    cfg.update(extra)
    p = os.path.join(work, name + '.json')
    json.dump(cfg, open(p, 'w'))
    return p


r = subprocess.run([mklisten, '-t', '-c', config('bad', localnode=2)], capture_output=True, text=True)
check('localnode inside the nodes of a port is refused', r.returncode != 0 and 'localnode' in r.stderr)
r = subprocess.run([mklisten, '-t', '-c', config('ok', localnode=9)], capture_output=True, text=True)
check('localnode outside them is accepted', r.returncode == 0)

# not set up: a message, the table stays
lst = subprocess.Popen([mklisten, '-c', config('none')], stdout=subprocess.DEVNULL)
try:
    s = login(24622)
    s.sendall(b'l')
    b = read_until(s, b'not set up', 3)
    check('without localnode L says so', b'not set up' in b)
    s.close()
finally:
    lst.terminate(); lst.wait()

lst = subprocess.Popen([mklisten, '-c', config('loc', localnode=9)], stdout=subprocess.DEVNULL)
try:
    s = login(24622)
    s.sendall(b'L')
    b = read_until(s, b'FAKE-LOCAL', 4)
    check('L runs mk -L -N9 on the connection', b'FAKE-LOCAL -L -N9' in b)
    check('with the terminal type of the session', re.search(rb'TERM=\S+', b) is not None)
    # a second monitor session cannot start another one
    s2 = login(24622)
    s2.sendall(b'l')
    b2 = read_until(s2, b'already running', 3)
    check('a second local session is refused', b'already running' in b2)
    s2.close()
    s.sendall(b'hi there\r')
    b = read_until(s, b'GOT hi there', 3)
    check('what is typed reaches the local BBS', b'GOT hi there' in b)
    b = read_until(s, b'R refresh', 4)
    check('back at the node table when it ends', b'MK sysop monitor' in b and b'local BBS' in b)
    s.sendall(b'L')
    b = read_until(s, b'FAKE-LOCAL', 4)
    check('and it can be started again', b'FAKE-LOCAL -L -N9' in b)
    s.sendall(b'x\r')
    read_until(s, b'R refresh', 4)
    s.close()
finally:
    lst.terminate(); lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
