#!/usr/bin/env python3
"""The real mk (sample BBS, private copy) with mklisten and the sysop monitor: log in, the monitor
shows the user, chat from the monitor, take / give time, disconnect.
usage: chattest.py <work dir>   (needs bbs/bbsc/ra and build/mk, mklisten, mkmon)"""
import os, re, socket, subprocess, sys, shutil, json, time

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.abspath(os.path.join(here, '..'))
root = os.path.join(here, '..')
work = os.path.abspath(sys.argv[1])
src = os.path.join(root, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
dst = os.path.join(work, 'ra')
shutil.rmtree(dst, ignore_errors=True)       # a clean copy every time
os.makedirs(dst, exist_ok=True)
subprocess.check_call(['cp', '-a', src + '/.', dst + '/'])
# point the BBS directory (users, logs ...) at the private copy
p = os.path.join(dst, 'config.mk')
d = bytearray(open(p, 'rb').read())
root = os.path.realpath(os.path.join(root, 'bbs')).encode() + b'/'
ra = os.path.realpath(src).encode() + b'/'
new = dst.encode() + b'/'
i = 0
changed = 0
while i < len(d) - 3:
    L = d[i]
    s = bytes(d[i + 1:i + 1 + L])
    if L > 0 and s.startswith(root):
        if s == ra:                          # the user files and logs go to the private copy,
            d[i] = len(new)                  # menus, texts and so on are only read
            d[i + 1:i + 1 + len(s)] = new
            i += 1 + len(new)
            changed += 1
        else:
            i += 1
    else:
        i += 1

open(p, 'wb').write(d)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'chat: ' + name)
    if not ok:
        fails += 1


cfg = {'mk': repo + '/build/mk', 'mkmon': repo + '/build/mkmon', 'rundir': os.path.join(work, 'run'),
       'logfile': os.path.join(work, 'listen.log'), 'workdir': dst, 'nodes': '1-2',
       'ports': [{'port': 24641, 'type': 'telnet', 'bind': '127.0.0.1', 'config': dst},
                 {'port': 24642, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'pw', 'config': dst}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = subprocess.Popen([repo + '/build/mklisten', '-c', os.path.join(work, 'listen.json')],
                       stdout=subprocess.DEVNULL)


def until(s, needle, secs=8):
    s.settimeout(0.2)
    b = b''
    end = time.time() + secs
    while time.time() < end and needle not in b:
        try:
            d = s.recv(4096)
            if not d:
                break
            b += d
            if b'\x1b[6n' in d:
                s.sendall(b'\x1b[1;1R')            # the terminal answers the ANSI detection
        except socket.timeout:
            pass
    return b


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def conn(port):
    for _ in range(50):
        try:
            return socket.create_connection(('127.0.0.1', port))
        except OSError:
            time.sleep(0.1)
    raise SystemExit('cannot connect')


try:
    c = conn(24641)
    until(c, b'language choice', 10); time.sleep(1.5); c.sendall(b'\r')
    until(c, b'last name: ', 10); time.sleep(2.5)
    c.sendall(b'Mark May\r'); until(c, b'assword'); time.sleep(0.5); c.sendall(b'windows\r')
    x = b''
    for _ in range(8):
        x = until(c, b'zzzz', 3)
        if b'continue' in x or b'Enter' in x:
            c.sendall(b'\r')
        else:
            break
    check('caller logged in to the menu', b'Command >' in x)
    m = conn(24642)
    until(m, b'Password: ', 3); m.sendall(b'pw\r'); b = until(m, b'Q quit', 5)
    check('monitor lists the user and the activity', b'Mark May' in b and b'Browsing' in b)
    m.sendall(b'1\r'); b = until(m, b'zzzz', 2.5)
    check('status bar has node, name, type and status', b'Ctrl-A=Help  Node 1  Mark May' in b and b'Browsing' in b)
    m.sendall(b'\x01c')
    check('chat starts', b'Chat started' in until(m, b'Chat started', 6))
    check('caller sees "Chat Started"', b'Chat Started' in strip(until(c, b'Chat Started', 4)))
    m.sendall(b'hello')
    check('the sysop text appears on the caller screen', b'hello' in strip(until(c, b'hello', 3)))
    m.sendall(b'\x1b')
    check('Esc ends the chat', b'Chat ended' in until(m, b'Chat ended', 6))
    check('caller sees "Chat Ended"', b'Chat Ended' in strip(until(c, b'Chat Ended', 4)))
    m.sendall(b'\x01+')
    check('time added', b'Added 5 min' in until(m, b'left', 4))
    m.sendall(b'\x01-')
    check('time taken', b'Took 5 min' in until(m, b'left', 4))
    m.sendall(b'\x01k'); until(m, b'Y / N', 3); m.sendall(b'y')
    check('kick answered', b'isconnected' in until(m, b'isconnected', 4))
    check('caller told', b'disconnected by the sysop' in until(c, b'disconnected by the sysop', 4))
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
