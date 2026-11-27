#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""MKComClient (a TCP client session with Telnet): a Python server negotiates the way a BBS does and checks the answers.
usage: clienttest.py <build dir>"""
import os, socket, subprocess, sys, threading, time

build = os.path.abspath(sys.argv[1])
fails = 0
IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240
ECHO, SGA, BINARY, TTYPE, NAWS = 1, 3, 0, 24, 31


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'client: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


def serve(listener, script, result):
    c, _ = listener.accept()
    c.settimeout(0.5)
    for chunk in script:
        c.sendall(chunk)
        time.sleep(0.15)
    data = b''
    end = time.time() + 3
    while time.time() < end:
        try:
            d = c.recv(4096)
        except socket.timeout:
            continue
        if not d:
            break
        data += d
    result.append(data)
    c.close()


def run(script, *args, listen='127.0.0.1', host=None):
    l = socket.socket(socket.AF_INET6 if ':' in listen else socket.AF_INET)
    l.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    l.bind((listen, 0))
    l.listen(1)
    res = []
    t = threading.Thread(target=serve, args=(l, script, res))
    t.start()
    p = subprocess.run([build + '/clienttest', host or listen, str(l.getsockname()[1])] + list(args), capture_output=True, text=True, timeout=30)
    t.join()
    l.close()
    return p.stdout, (res[0] if res else b'')


# what a BBS sends: its options, a banner with CR LF and a data byte 255 (IAC IAC), the terminal type request
script = [bytes([IAC, WILL, ECHO, IAC, WILL, SGA, IAC, DO, SGA, IAC, DO, BINARY, IAC, WILL, BINARY, IAC, DO, TTYPE, IAC, DO, NAWS,
                 IAC, WILL, 99, IAC, DO, 77]),
          bytes([IAC, SB, TTYPE, 1, IAC, SE]),
          b'Welcome\r\nLogin: ' + bytes([IAC, IAC]) + b'x']
out, got = run(script)
check('it connects', 'connected' in out, out)


def has(b):
    return b in got


check('SGA is offered and accepted both ways', bytes([IAC, WILL, SGA]) in got and bytes([IAC, DO, SGA]) in got, got)
check('binary is offered and accepted both ways', bytes([IAC, WILL, BINARY]) in got and bytes([IAC, DO, BINARY]) in got, got)
check('the server echoing is accepted (DO ECHO)', bytes([IAC, DO, ECHO]) in got, got)
check('terminal type and window size are accepted (WILL TTYPE, WILL NAWS)', bytes([IAC, WILL, TTYPE]) in got and bytes([IAC, WILL, NAWS]) in got, got)
check('the window size is told: 80 x 24', bytes([IAC, SB, NAWS, 0, 80, 0, 24, IAC, SE]) in got, got)
check('the terminal type is told: ansi', bytes([IAC, SB, TTYPE, 0]) + b'ansi' + bytes([IAC, SE]) in got, got)
check('an option it does not know is refused (DONT 99, WONT 77)', bytes([IAC, DONT, 99]) in got and bytes([IAC, WONT, 77]) in got, got)
check('what is typed arrives with 255 doubled', got.endswith(b'ping\r' + bytes([IAC, IAC])), got[-12:])
want = b'Welcome\r\nLogin: ' + bytes([255]) + b'x'
check('the banner arrives as it is: CR LF kept, IAC IAC is one byte 255', ('got ' + want.hex()) in out, out)
# raw: no negotiation at all, bytes as they are
out, got = run([b'hello\r\n' + bytes([IAC, 1])], 'raw')
check('raw: the bytes arrive as they are and nothing is negotiated', ('got ' + (b'hello\r\n' + bytes([IAC, 1])).hex()) in out and got == b'ping\r' + bytes([255]), (out, got))
# failures: a closed port, an unknown name
l = socket.socket(); l.bind(('127.0.0.1', 0)); port = l.getsockname()[1]; l.close()
t0 = time.time()
p = subprocess.run([build + '/clienttest', '127.0.0.1', str(port)], capture_output=True, text=True, timeout=30)
check('a closed port: an error at once', p.returncode == 1 and 'refused' in p.stdout and time.time() - t0 < 3, p.stdout)
p = subprocess.run([build + '/clienttest', 'no-such-host.invalid', '23'], capture_output=True, text=True, timeout=30)
check('an unknown host: an error', p.returncode == 1 and 'Unknown host' in p.stdout, p.stdout)
# IPv6 (skipped on a system without it)
try:
    t6 = socket.socket(socket.AF_INET6); t6.bind(('::1', 0)); t6.close()
    v6 = True
except OSError:
    v6 = False
    print('skip: no IPv6 on this system')
if v6:
    out, got = run(script, listen='::1')
    check('IPv6: it connects to ::1 and the session is the same (Telnet answers, banner, typed bytes)', 'connected' in out and bytes([IAC, WILL, SGA]) in got and got.endswith(b'ping\r' + bytes([IAC, IAC])) and ('got ' + want.hex()) in out, (out, got))
    out, got = run([b'hello\r\n'], 'raw', listen='::1', host='[::1]')
    check('IPv6: [::1] with brackets as the host, raw', 'connected' in out and got == b'ping\r' + bytes([255]), (out, got))
    out, got = run([b'hello\r\n'], 'raw', listen='::1', host='localhost')
    check('a name with an IPv4 and an IPv6 address reaches the IPv6 listener (the addresses are tried in turn)', 'connected' in out and got == b'ping\r' + bytes([255]), (out, got))
    out, got = run([b'hello\r\n'], 'raw', listen='127.0.0.1', host='localhost')
    check('... and the IPv4 listener', 'connected' in out and got == b'ping\r' + bytes([255]), (out, got))
    l = socket.socket(socket.AF_INET6); l.bind(('::1', 0)); port = l.getsockname()[1]; l.close()
    p = subprocess.run([build + '/clienttest', '::1', str(port)], capture_output=True, text=True, timeout=30)
    check('a closed IPv6 port: refused, the address in brackets in the message', p.returncode == 1 and 'refused by [::1]:%d' % port in p.stdout, p.stdout)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
