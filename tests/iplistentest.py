#!/usr/bin/env python3
"""IPv6 in mklisten (IPV6-PLAN.md phase 2): ports with no bind listen on IPv4 and IPv6, bind limits a port to one family, the address of the caller is text in its
usual form (IPv4 on the dual stack socket is a.b.c.d), PROXY headers with IPv6 addresses, loopback rules of sysop / proxy ports with ::1, maxperip per address, the
configuration checks, and the login guard for an IPv6 address (real mk over telnet on a private copy of the sample BBS).   usage: iplistentest.py <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)


def has_ipv6():
    try:
        s = socket.socket(socket.AF_INET6)
        s.bind(('::1', 0))
        s.close()
        return True
    except OSError:
        return False


if not has_ipv6():
    print('skip: no IPv6 on this system'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'ipv6 listener: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


def connect(host, port):
    fam = socket.AF_INET6 if ':' in host else socket.AF_INET
    for _ in range(60):
        s = socket.socket(fam)
        s.settimeout(3)
        try:
            s.connect((host, port))
            return s
        except OSError:
            s.close()
            time.sleep(0.1)
    return None


def reads(s, needle=b'MK=', secs=6):
    s.settimeout(0.3)
    b = b''
    end = time.time() + secs
    while time.time() < end and needle not in b:
        try:
            d = s.recv(4096)
            if not d:
                break
            b += d
        except socket.timeout:
            pass
        except OSError:
            break
    return b.decode('latin-1')


def addr_of(s):
    m = re.search(r'ADDR (\S*)', reads(s))
    return m.group(1) if m else None


tmp = cfgpatch.short_dir()
cfg = {'mk': build + '/fakemk', 'mkmon': build + '/mkmon', 'rundir': tmp + '/run', 'logfile': work + '/listen.log', 'workdir': work, 'nodes': '1-6',
       'ports': [{'port': 24861, 'type': 'raw'},
                 {'port': 24862, 'type': 'raw', 'bind': '0.0.0.0'},
                 {'port': 24863, 'type': 'raw', 'bind': '::1'},
                 {'port': 24864, 'type': 'raw', 'bind': '::1', 'proxy': True},
                 {'port': 24865, 'type': 'sysop', 'bind': '::1', 'password': 'pw'},
                 {'port': 24866, 'type': 'raw', 'maxperip': 1}]}
json.dump(cfg, open(work + '/l.json', 'w'))
r = subprocess.run([build + '/mklisten', '-c', work + '/l.json', '-t'], capture_output=True, text=True)
out = r.stdout + r.stderr
check('mklisten -t accepts the configuration and says what each port listens on', r.returncode == 0 and 'port 24861: IPv4 and IPv6' in out and 'port 24862: 0.0.0.0 only (IPv4)' in out and 'port 24863: ::1 only (IPv6)' in out, out)


def bad(port_over=None, guard=None, name='', want=''):
    c = json.loads(json.dumps(cfg))
    if port_over:
        c['ports'] = port_over
    if guard is not None:
        c['loginguard'] = guard
    json.dump(c, open(work + '/bad.json', 'w'))
    r = subprocess.run([build + '/mklisten', '-c', work + '/bad.json', '-t'], capture_output=True, text=True)
    o = r.stdout + r.stderr
    check(name, r.returncode != 0 and want in o, o)


bad([{'port': 24870, 'type': 'raw', 'bind': 'localhost'}], name='a bind that is no address (a name) is refused', want='is not an address')
bad([{'port': 24870, 'type': 'raw', 'proxy': True}], name='"proxy" on a port that is not loopback (the default bind) is refused', want='needs "bind": "127.0.0.1" or "::1"')
bad([{'port': 24870, 'type': 'sysop', 'bind': '0.0.0.0', 'password': 'pw'}], name='a sysop port on a non-loopback address is refused', want='"127.0.0.1" or "::1"')
bad(guard={'allow': ['2001:db8::/129']}, name='an IPv6 net with a prefix too long in loginguard.allow is refused', want='is not an address or a net')
bad(guard={'allow': ['junk']}, name='what is no address in loginguard.allow is refused', want='is not an address or a net')
c = json.loads(json.dumps(cfg)); c['loginguard'] = {'allow': ['2001:db8::/32', '::1', '10.0.0.0/8']}
json.dump(c, open(work + '/ok.json', 'w'))
r = subprocess.run([build + '/mklisten', '-c', work + '/ok.json', '-t'], capture_output=True, text=True)
check('loginguard.allow takes IPv6 nets and addresses', r.returncode == 0 and '2001:db8::/32' in r.stdout, r.stdout + r.stderr)

lst = subprocess.Popen([build + '/mklisten', '-c', work + '/l.json'], stdout=subprocess.DEVNULL)
try:
    time.sleep(1.5)
    s = connect('127.0.0.1', 24861)
    check('no bind: an IPv4 caller is a.b.c.d (not ::ffff:a.b.c.d)', s is not None and addr_of(s) == '127.0.0.1')
    s.close()
    s = connect('::1', 24861)
    check('no bind: an IPv6 caller is ::1', s is not None and addr_of(s) == '::1')
    s.close()
    check('bind 0.0.0.0: IPv4 works, IPv6 is refused', connect('127.0.0.1', 24862) is not None and socket.socket(socket.AF_INET6).connect_ex(('::1', 24862)) != 0)
    s = connect('::1', 24863)
    check('bind ::1: IPv6 works', s is not None and addr_of(s) == '::1')
    s.close()
    check('... IPv4 is refused', socket.create_connection(('127.0.0.1', 24863), 2) is None if False else socket.socket().connect_ex(('127.0.0.1', 24863)) != 0)
    # the PROXY header with IPv6 addresses
    for hdr, want, what in (('PROXY TCP6 2001:DB8:0:0:0:0:0:7 ::1 4000 24864\r\n', '2001:db8::7', 'an IPv6 address in the header is written in its short form'),
                            ('PROXY TCP4 192.0.2.7 127.0.0.1 4000 24864\r\n', '192.0.2.7', 'an IPv4 address in the header'),
                            ('PROXY TCP6 ::ffff:192.0.2.9 ::1 4000 24864\r\n', '192.0.2.9', 'a mapped address in the header is the IPv4 address')):
        s = connect('::1', 24864)
        s.sendall(hdr.encode())
        check('PROXY header: ' + what, addr_of(s) == want)
        s.close()
    s = connect('::1', 24865)
    check('the sysop port on ::1 answers (password prompt)', s is not None and 'assword' in reads(s, b'assword'))
    s.close()
    # maxperip: one caller for each address
    a = connect('::1', 24866)
    check('maxperip 1: the first caller from ::1 is let in', a is not None and addr_of(a) == '::1')
    b = connect('::1', 24866)
    t = reads(b, b'too many', 4) if b else ''
    check('... a second from ::1 is refused', 'ADDR' not in t)
    c4 = connect('127.0.0.1', 24866)
    check('... one from 127.0.0.1 is another address and is let in', c4 is not None and addr_of(c4) == '127.0.0.1')
    for x in (a, b, c4):
        if x:
            x.close()
finally:
    lst.terminate()
    lst.wait()

# the login guard counts an IPv6 address: real mk, two failed log-ons from ::1 block it; 127.0.0.1 is another address
if os.path.isdir(src):
    ra = tmp + '/r'
    shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
    cfgpatch.fix_sample(ra)
    cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
    gcfg = {'mk': build + '/mk', 'mkmon': build + '/mkmon', 'rundir': tmp + '/run2', 'logfile': work + '/listen2.log', 'workdir': ra, 'nodes': '1-4',
            'loginguard': {'fails': 2, 'window': 60, 'block': 8, 'allow': [], 'message': 'GUARD: try later'},
            'ports': [{'port': 24867, 'type': 'telnet', 'config': ra}]}
    json.dump(gcfg, open(work + '/g.json', 'w'))
    lst = subprocess.Popen([build + '/mklisten', '-c', work + '/g.json'], stdout=subprocess.DEVNULL)

    def until(s, needle, secs=8):
        s.settimeout(0.2)
        bb = b''
        end = time.time() + secs
        while time.time() < end and needle not in bb:
            try:
                dd = s.recv(4096)
                if not dd:
                    break
                bb += dd
                if b'\x1b[6n' in dd:
                    s.sendall(b'\x1b[1;1R')
            except socket.timeout:
                pass
        return bb

    def attempt(host, pwds):
        c = connect(host, 24867)
        seen = until(c, b'language choice', 6)
        if b'language choice' not in seen:
            c.close()
            return seen
        time.sleep(1.5); c.sendall(b'\r')
        seen += until(c, b'last name: ', 8); time.sleep(2.5)
        c.sendall(b'Mark May\r'); seen += until(c, b'assword')
        for p in pwds:
            time.sleep(0.4)
            c.sendall(p.encode() + b'\r')
            seen += until(c, b'zzzz', 2.5)
        c.close()
        return seen
    try:
        time.sleep(2)
        attempt('::1', ['x1', 'x2', 'x3'])
        time.sleep(1.5)
        attempt('::1', ['y1', 'y2', 'y3'])
        time.sleep(1.5)
        seen = attempt('::1', [])
        check('login guard: two failed log-ons from ::1 block that address (a message, no node)', b'GUARD: try later' in seen, seen[-200:])
        seen = attempt('127.0.0.1', [])
        check('... 127.0.0.1 is another address and is not blocked', b'language choice' in seen, seen[-200:])
        time.sleep(9)
        seen = attempt('::1', [])
        check('... when the block is over ::1 can log on again', b'language choice' in seen, seen[-200:])
    finally:
        lst.terminate()
        lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
