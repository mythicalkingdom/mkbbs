#!/usr/bin/env python3
"""Sysop monitor: mklisten with a telnet port and a sysop port, fakemk as the BBS.
usage: montest.py <mklisten> <fakemk> <mkmon> <workdir>"""
import os, re, socket, subprocess, sys, time, json, hashlib

mklisten, fakemk, mkmon, work = [os.path.abspath(a) for a in sys.argv[1:5]]
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


BAR = re.compile(rb'\x1b7\x1b\[\d+;1H.*?\x1b8')


def read_until(s, needle, secs=4):
    # the status bar may be drawn in between: match without it, return the raw bytes
    buf = b''
    end = time.time() + secs
    while time.time() < end and needle not in buf and needle not in BAR.sub(b'', buf):
        try:
            d = s.recv(4096)
            if not d:
                break
            buf += d
        except socket.timeout:
            pass
    return buf


cfg = {
    'mk': fakemk, 'mkmon': mkmon, 'logfile': os.path.join(work, 'mon.log'), 'rundir': run,
    'ports': [
        {'port': 24611, 'type': 'telnet', 'nodes': '1-2', 'bind': '127.0.0.1', 'config': '/nonexistent'},
        {'port': 24612, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'sesame'},
        {'port': 24613, 'type': 'sysop', 'bind': '127.0.0.1',
         'password': 'sha1:' + hashlib.sha1(b'hashed').hexdigest()},
    ]}
json.dump(cfg, open(os.path.join(work, 'mon.json'), 'w'))
bad = dict(cfg); bad['ports'] = [{'port': 24619, 'type': 'sysop', 'password': 'x'}]
json.dump(bad, open(os.path.join(work, 'bad.json'), 'w'))
r = subprocess.run([mklisten, '-t', '-c', os.path.join(work, 'bad.json')], capture_output=True, text=True)
check('sysop port must bind to 127.0.0.1', r.returncode != 0 and '127.0.0.1' in r.stderr)

lst = subprocess.Popen([mklisten, '-c', os.path.join(work, 'mon.json')], stdout=subprocess.DEVNULL)
try:
    caller = connect(24611)
    read_until(caller, b'ADDR 127.0.0.1')
    time.sleep(0.3)
    check('node info file written', os.path.exists(os.path.join(run, 'node1.info')))
    check('snoop socket created by the node', os.path.exists(os.path.join(run, 'node1.snoop')))
    check('run directory is private', (os.stat(run).st_mode & 0o777) == 0o700)
    out = subprocess.run([mkmon, '-l', '-r', run], capture_output=True, text=True).stdout
    check('mkmon -l lists node 1', '127.0.0.1' in out and 'telnet' in out)

    # wrong password, then the right one
    s = connect(24612)
    b = read_until(s, b'Password: ')
    check('password prompt', b'Password: ' in b)
    s.sendall(b'nope\r')
    b = read_until(s, b'Wrong password')
    check('wrong password refused', b'Wrong password' in b)
    b = read_until(s, b'Password: ', 5)
    s.sendall(b'sesame\r')
    b = read_until(s, b'R refresh, Q quit', 5)
    check('node table shown after login', b'MK sysop monitor' in b and b'127.0.0.1' in b and b'telnet' in b)
    check('table shows the node 1 row', b'\r\n1   ' in b)

    # snoop node 1
    s.sendall(b'1\r')
    time.sleep(2.0)
    caller.sendall(b'hello')
    b = read_until(s, b'HELLO', 4)
    check('caller output is mirrored to the monitor', b'HELLO' in BAR.sub(b'', b))
    time.sleep(1.2)
    b += read_until(s, b'zzzz', 1.5)
    check('scrolling region keeps the bottom row free', b'\x1b[1;24r' in b)
    check('status bar: help, node, type', b'Ctrl-A=Help' in b and b'Node 1' in b and b'telnet' in b and b'\x1b[25;1H' in b)
    s.sendall(b'\x18')
    b = read_until(s, b'R refresh, Q quit', 4)
    check('Ctrl-X returns to the node table', b'MK sysop monitor' in b)
    # typing: off by default, on with Ctrl-A T
    s.sendall(b'1\r'); time.sleep(1.8)
    read_until(s, b'zzzz', 0.5)
    s.sendall(b'view')                       # typing is off: goes nowhere
    time.sleep(0.5)
    s.sendall(b'\x01t')
    b = read_until(s, b'Typing is ON', 3)
    check('Ctrl-A T switches typing on', b'Typing is ON' in b)
    s.sendall(b'ab')
    b = read_until(caller, b'AB', 3)
    check('typed text reaches the BBS as the caller\'s input', b'AB' in b and b'VIEW' not in b)
    s.sendall(b'\x1b[24;1Rc')                # a terminal answer, then a letter
    b = read_until(caller, b'C', 3)
    check('terminal answers are not typed into the BBS', b'C' in b and b'24' not in b and b'\x1b' not in b)
    s.sendall(b'\x1b')                       # a lone Esc is a key
    b = read_until(caller, b'\x1b', 3)
    check('a lone Esc reaches the BBS', b'\x1b' in b)
    # the bar is never drawn inside an escape sequence of the node's output
    time.sleep(3.3)                          # earlier answers are gone from the bar
    read_until(s, b'zzzz', 0.5)
    caller.sendall(b'\x1b[3')               # a sequence that is not finished
    time.sleep(0.4)
    s.sendall(b'\x01?')
    b = read_until(s, b'^A: T type', 1.5)
    check('bar waits while the node is inside an escape sequence', b'^A: T type' not in b)
    caller.sendall(b'1M')                    # finished
    b = read_until(s, b'^A: T type', 3)
    check('bar is drawn when the sequence is complete', b'^A: T type' in b)
    # the bar puts the node's colors back
    time.sleep(3.3)
    caller.sendall(b'#')                     # the node sets bold red
    time.sleep(0.4)
    s.sendall(b'\x01?')
    b = read_until(s, b'^A: T type', 3)
    time.sleep(0.2); b += read_until(s, b'zzzz', 0.3)
    check('colors of the node are restored after the bar', b'\x1b8\x1b[0m\x1b[1;31m' in b)
    time.sleep(3.3)
    # chat: Ctrl-A C, what is typed goes to the caller's screen (not as its input), Esc ends
    time.sleep(3.3)
    s.sendall(b'\x01c')
    b = read_until(s, b'Chat started', 4)
    check('Ctrl-A C starts a chat', b'Chat started' in b)
    b = read_until(s, b'[CHAT', 5)
    check('bar shows the chat', b'[CHAT' in b)
    s.sendall(b'hi')
    b = read_until(caller, b'hi', 3)
    check('chat text reaches the caller as typed (not echoed as input)', b'hi' in b and b'HI' not in b)
    s.sendall(b'\x1b')
    b = read_until(s, b'Chat ended', 4)
    check('Esc ends the chat', b'Chat ended' in b)
    time.sleep(3.3)
    s.sendall(b'\x01+')
    b = read_until(s, b'Added 5 min, 35 left', 3)
    check('Ctrl-A + adds time: ' + b[-40:].decode('latin-1'), b'Added 5 min, 35 left' in b)
    s.sendall(b'\x01-')
    b = read_until(s, b'Took 5 min, 30 left', 3)
    check('Ctrl-A - takes time', b'Took 5 min, 30 left' in b)
    s.sendall(b'\x18')
    read_until(s, b'R refresh, Q quit', 3)
    # from the node list: number and + / -
    s.sendall(b'1+')
    b = read_until(s, b'Added 5 min, 35 left', 3)
    check('node list: 1 + adds time', b'Added 5 min, 35 left' in b)
    s.sendall(b'1-')
    b = read_until(s, b'Took 5 min, 30 left', 3)
    check('node list: 1 - takes time', b'Took 5 min, 30 left' in b)
    s.sendall(b'q')
    b = read_until(s, b'Bye', 3)
    check('Q ends the monitor', b'Bye' in b)
    s.close()

    # the snooped caller was never disturbed
    caller.sendall(b'again')
    b = read_until(caller, b'AGAIN', 3)
    check('caller still works', b'AGAIN' in b)

    # hashed password
    s = connect(24613)
    read_until(s, b'Password: ')
    s.sendall(b'hashed\r')
    b = read_until(s, b'R refresh, Q quit', 5)
    check('sha1 password accepted', b'MK sysop monitor' in b)
    s.close()

    # attach late: replay of what was sent before
    s = connect(24612)
    read_until(s, b'Password: ')
    s.sendall(b'sesame\r')
    read_until(s, b'R refresh, Q quit', 5)
    s.sendall(b'1\r')
    b = read_until(s, b'AGAIN', 5)
    check('late monitor sees the recent output', b'AGAIN' in BAR.sub(b'', b))
    s.sendall(b'\x18'); time.sleep(0.3); s.close()

    # chat from the node list: the watch window opens and the chat starts
    s = connect(24612)
    read_until(s, b'Password: '); s.sendall(b'sesame\r'); read_until(s, b'R refresh, Q quit', 5)
    s.sendall(b'1c')
    b = read_until(s, b'Chat started', 5)
    check('node list: 1 C opens the watch window and starts the chat', b'Chat started' in b)
    s.sendall(b'yo')
    check('chat from the node list reaches the caller', b'yo' in read_until(caller, b'yo', 3))
    s.sendall(b'\x1b')
    check('Esc ends it', b'Chat ended' in read_until(s, b'Chat ended', 4))
    s.sendall(b'\x18'); read_until(s, b'R refresh, Q quit', 3); s.sendall(b'q'); time.sleep(0.3); s.close()
    # kick from the node list
    s = connect(24612)
    read_until(s, b'Password: '); s.sendall(b'sesame\r'); read_until(s, b'R refresh, Q quit', 5)
    s.sendall(b'1k')
    b = read_until(s, b'Y / N', 3)
    check('kick asks first', b'Disconnect node 1?' in b)
    s.sendall(b'n')
    b = read_until(s, b'Not disconnected', 3)
    check('kick can be refused', b'Not disconnected' in b)
    caller.sendall(b'x')
    check('caller still connected after a refused kick', b'X' in read_until(caller, b'X', 3))
    s.sendall(b'1k'); read_until(s, b'Y / N', 3); s.sendall(b'y')
    b = read_until(s, b'Node kicked', 3)
    check('kick answered', b'Node kicked' in b)
    b = read_until(caller, b'disconnected by the sysop', 3)
    check('caller is told', b'disconnected by the sysop' in b)
    s.close()
    time.sleep(1.5)
    caller.close()
    time.sleep(1.5)
    check('node files removed when the caller leaves',
          not os.path.exists(os.path.join(run, 'node1.info')) and not os.path.exists(os.path.join(run, 'node1.snoop')))
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
