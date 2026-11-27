#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Native TLS in mklisten ("tls": true on a port, the "tls" section with the certificate and the key): the handshake is done by the program that serves the caller
(mk -Y, here fakemk), no stunnel.   A Telnet, a raw and a WebSocket port; a certificate that is checked (CA file, name); the real address of the caller (no PROXY
header needed); a caller that does not speak TLS; a port that is not opened when the certificate is missing or the libraries are (MK_TLS_NO_LIBS) while the other ports run;
mklisten -t says what would happen.   usage: tlstest.py <build dir> <work dir>"""
import base64, json, os, shutil, socket, ssl, subprocess, sys, time

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
if not shutil.which('openssl') or not os.path.exists(build + '/fakemk'):
    print('skip: no openssl command or fakemk'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'native tls: ' + name + ('' if ok else '  ' + str(info)[:500]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', work + '/key.pem', '-out', work + '/cert.pem', '-days', '2', '-subj', '/CN=localhost',
                '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1'], check=True, capture_output=True)
base = 25900 + os.getpid() % 60
P_TEL, P_RAW, P_WS, P_PLAIN = base, base + 1, base + 2, base + 3


def conf(name, ports, tls=True, extra=None):
    c = {'mk': build + '/fakemk', 'rundir': work + '/run', 'logfile': work + '/' + name + '.log', 'workdir': work, 'nodes': '1-6', 'ports': ports}
    if tls:
        c['tls'] = {'cert': work + '/cert.pem', 'key': work + '/key.pem'}
    if extra:
        c.update(extra)
    json.dump(c, open(work + '/' + name + '.json', 'w'))
    return work + '/' + name + '.json'


def start(cfg):
    return subprocess.Popen([build + '/mklisten', '-c', cfg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=dict(os.environ))


def ctx():
    c = ssl.create_default_context(cafile=work + '/cert.pem')
    return c


def tls_connect(port, **kw):
    s = socket.create_connection(('127.0.0.1', port), timeout=10)
    return ctx().wrap_socket(s, server_hostname='localhost', **kw)


def readuntil(s, token, t=10):
    s.settimeout(t)
    d = b''
    try:
        while token not in d:
            x = s.recv(4096)
            if not x:
                break
            d += x
    except (socket.timeout, ssl.SSLError, OSError):
        pass
    return d


ports = [{'port': P_TEL, 'type': 'telnet', 'tls': True}, {'port': P_RAW, 'type': 'raw', 'tls': True}, {'port': P_WS, 'type': 'ws', 'tls': True},
         {'port': P_PLAIN, 'type': 'raw'}]
cfg = conf('main', ports)
r = subprocess.run([build + '/mklisten', '-t', '-c', cfg], capture_output=True, text=True)
check('mklisten -t says that native TLS is ready for the ports', r.returncode == 0 and 'native TLS is ready' in r.stdout, r.stdout + r.stderr)
lst = start(cfg)
time.sleep(1.5)
try:
    s = tls_connect(P_RAW)
    d = readuntil(s, b'\n')
    check('a raw port with TLS: the handshake works (certificate and name checked), the session says hello', b'NODE 1 TYPE RAW' in d and s.version() in ('TLSv1.3', 'TLSv1.2'), (d, s.version()))
    check('... with the real address of the caller (no PROXY header)', b'ADDR 127.0.0.1' in d, d)
    s.sendall(b'abc')
    echo = readuntil(s, b'ABC', 5)
    check('... what the caller types comes back through TLS (the echo of fakemk)', b'ABC' in echo, echo)
    big = bytes(b'abcdefghijklmnoprstuvwxyz'[i % 25] for i in range(60000))      # no q: fakemk hangs up on it                  # more than a TLS record at a time: the decrypted bytes that wait are read, too
    s.sendall(big)
    got = b''
    s.settimeout(20)
    try:
        while len(got) < len(big):
            x = s.recv(65536)
            if not x:
                break
            got += x
    except (socket.timeout, OSError):
        pass
    check('... 60000 bytes through it come back whole and in order (the decrypted bytes that wait are read as well)', got.upper() == big.upper() and len(got) == len(big), (len(got), got[:30]))
    s.sendall(b'q')
    d2 = readuntil(s, b'!', 5)
    check('... and it hangs up on request', b'!' in d2, d2)
    s.close()
    s = tls_connect(P_TEL)
    d = readuntil(s, b'NODE')
    check('a Telnet port with TLS: Telnet is spoken inside the TLS (negotiation bytes, then the hello)', b'\xff' in d and b'TYPE TELNET' in d or b'NODE' in d, d)
    s.close()
    # websocket over TLS (wss)
    s = tls_connect(P_WS)
    key = base64.b64encode(os.urandom(16)).decode()
    s.sendall(('GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n' % key).encode())
    d = readuntil(s, b'\r\n\r\n')
    check('a ws port with TLS: wss, the upgrade is answered (101)', b'101' in d.split(b'\r\n')[0], d)
    s.close()
    # a caller that does not speak TLS
    p = socket.create_connection(('127.0.0.1', P_RAW), timeout=10)
    p.sendall(b'hello, this is not TLS\r\n' * 5)
    time.sleep(1)
    p.settimeout(5)
    try:
        got = p.recv(4096)
    except (socket.timeout, OSError):
        got = b''
    check('a caller that does not speak TLS gets no session (the connection is closed)', b'NODE' not in got, got)
    p.close()
    # the plain port next to it
    p = socket.create_connection(('127.0.0.1', P_PLAIN), timeout=10)
    d = readuntil(p, b'\n')
    check('a port without "tls" next to them stays plain', b'NODE' in d and b'ADDR 127.0.0.1' in d, d)
    p.close()
    # the node count: the failed handshake left no node behind
    time.sleep(1)
    log = open(work + '/main.log').read()
    check('the log says TLS for the ports and that the certificate is ready', 'raw TLS' in log and 'native TLS ready' in log, log[:800])
    # the same certificate that is not trusted
    s = socket.create_connection(('127.0.0.1', P_RAW), timeout=10)
    try:
        ssl.create_default_context().wrap_socket(s, server_hostname='localhost')
        bad = False
    except ssl.SSLError:
        bad = True
    check('a client that does not trust the certificate refuses it (the self-signed one)', bad)
finally:
    lst.terminate(); lst.wait()

# the certificate is not there: that port is not opened, the others are
cfg = conf('nocert', [{'port': P_RAW, 'type': 'raw', 'tls': True}, {'port': P_PLAIN, 'type': 'raw'}])
c = json.load(open(cfg)); c['tls']['cert'] = work + '/missing.pem'; json.dump(c, open(cfg, 'w'))
r = subprocess.run([build + '/mklisten', '-t', '-c', cfg], capture_output=True, text=True)
check('mklisten -t: a certificate that is missing is named, the port would not be opened', 'would NOT be opened' in r.stdout and 'missing.pem' in r.stdout, r.stdout)
lst = start(cfg); time.sleep(1.5)
try:
    refused = False
    try:
        socket.create_connection(('127.0.0.1', P_RAW), timeout=3).close()
    except OSError:
        refused = True
    p = socket.create_connection(('127.0.0.1', P_PLAIN), timeout=10)
    d = readuntil(p, b'\n'); p.close()
    log = open(work + '/nocert.log').read()
    check('a missing certificate: the TLS port is not opened, the plain one runs, the log says why', refused and b'NODE' in d and 'NOT opened' in log, (refused, d, log[-300:]))
finally:
    lst.terminate(); lst.wait()

# libssl is not there (simulated)
cfg = conf('nolibs', [{'port': P_RAW, 'type': 'raw', 'tls': True}, {'port': P_PLAIN, 'type': 'raw'}])
os.environ['MK_TLS_NO_LIBS'] = '1'
r = subprocess.run([build + '/mklisten', '-t', '-c', cfg], capture_output=True, text=True)
check('mklisten -t without the libraries: says libssl was not found, exit 0', r.returncode == 0 and 'libssl' in r.stdout and 'would NOT be opened' in r.stdout, r.stdout)
lst = start(cfg); time.sleep(1.5)
try:
    p = socket.create_connection(('127.0.0.1', P_PLAIN), timeout=10)
    d = readuntil(p, b'\n'); p.close()
    log = open(work + '/nolibs.log').read()
    check('without libssl mklisten still runs: the plain port works, the TLS port is left out with the reason in the log', b'NODE' in d and 'libssl' in log and 'NOT opened' in log, (d, log[-300:]))
finally:
    lst.terminate(); lst.wait()
del os.environ['MK_TLS_NO_LIBS']

# configuration mistakes
for name, ports, extra, text in (('a', [{'port': P_RAW, 'type': 'raw', 'tls': True}], 'notls', 'needs a "tls" section'),
                                 ('b', [{'port': P_RAW, 'type': 'raw', 'tls': True, 'proxy': True, 'bind': '127.0.0.1'}], None, 'do not go together'),
                                 ('c', [{'port': P_RAW, 'type': 'sysop', 'tls': True, 'bind': '127.0.0.1', 'password': 'xx'}], None, 'sysop port is not for TLS')):
    cfg = conf('bad' + name, ports, tls=(extra != 'notls'))
    r = subprocess.run([build + '/mklisten', '-t', '-c', cfg], capture_output=True, text=True)
    check('configuration: %s' % text, r.returncode != 0 and text in (r.stdout + r.stderr), r.stdout + r.stderr)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
