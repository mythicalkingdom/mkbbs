#!/usr/bin/env python3
"""mk -G<id> with "transport ftp" / "ftps" in the map file (MKFtp, MKQwkNet FtpPass) against a fake FTP server (tests/fakeftp.py): plain and explicit TLS,
the TLS session reused for the data connection, the certificate checked (CA file, name).   usage: hubftptest.py <build dir> <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time, zipfile

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch
from fakeftp import FakeFtp

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src) or not shutil.which('zip') or not shutil.which('unzip') or not shutil.which('openssl'):
    print('skip: no sample BBS (or no zip, unzip, openssl)'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'hub ftp: ' + name + ('' if ok else '  ' + str(info)[:700]))
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
cj = work + '/cj'; os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
dj['config']['ExtPack'][1]['PCmdLine'] = 'zip -q -j'
dj['config']['ExtPack'][1]['UCmdLine'] = 'unzip -o -q'
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
os.makedirs(tmp + '/in', exist_ok=True)
subprocess.run([build + '/tosssetup', tmp + '/in', tmp + '/outb', tmp + '/un'], env=env, capture_output=True, text=True)
subprocess.run([build + '/tossmake'], env=env, capture_output=True, text=True)
HUB = 'MythKing'
subprocess.run([build + '/netsetup', 'Chuck Ebenschweiger', '6'], env=env, capture_output=True, text=True)
for d in ('in', 'out'):
    os.makedirs(ra + '/' + d, exist_ok=True)
mapf = ra + '/' + HUB + '.map'
tlog = ra + '/' + HUB + '.hub.log'
PW = 'sEcr3tPw'
root = tmp + '/ftp'
os.makedirs(root + '/qwk', exist_ok=True)
port = 25700 + os.getpid() % 100


def make_packet(path):
    with zipfile.ZipFile(path, 'w') as z:
        z.writestr('CONTROL.DAT', 'The Hub\r\nHub City\r\n555-1212\r\nSysop, Sysop\r\n0000,%s\r\n01-01-2026,00:00:00\r\nChuck Ebenschweiger\r\n\r\n0\r\n0\r\n0\r\n6\r\nGeneral\r\n' % HUB)
        z.writestr('MESSAGES.DAT', b'Produced by Qmail...Copyright (c) 1987 by Sparkware.  All Rights Reserved' + b' ' * (128 - 73))


def write_map(extra='', transport='ftp', host='127.0.0.1', pw=PW, hubport=None):
    open(mapf, 'w').write('inbound %s/in\noutbound %s/out\nuser Chuck Ebenschweiger\nhub %s:%d\ntransport %s\nlogin lion\npassword %s\nconf 6 6\n%s' % (ra, ra, host, hubport or port, transport, pw, extra))


def post():
    subprocess.run([build + '/postmsg', '6', 'Node Poster', 'All', 'Ftp test %d' % time.time_ns(), 'written on the node'], env=env, capture_output=True, text=True)


def run(*args):
    return subprocess.run([build + '/mk', '-L', '-G' + HUB] + list(args), env=env, cwd=ra, capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)


def clean():
    for d in ('in', 'out'):
        for f in os.listdir(ra + '/' + d):
            os.remove(ra + '/' + d + '/' + f)
    for f in os.listdir(root):
        if os.path.isfile(root + '/' + f):
            os.remove(root + '/' + f)
    for f in os.listdir(root + '/qwk'):
        os.remove(root + '/qwk/' + f)


def reps():
    return [f for f in os.listdir(ra + '/out') if f.lower().endswith('.rep')]


# ---- plain FTP
srv = FakeFtp(root, port, password=PW)
clean(); write_map(); post(); make_packet(root + '/' + HUB + '.qwk')
p = run()
tl = open(tlog, encoding='latin-1').read() if os.path.exists(tlog) else ''
check('a pass by FTP: the packet is fetched and read, the reply packet is stored at the hub, exit 0',
      p.returncode == 0 and 'Packet received: ' + HUB + '.qwk' in p.stderr and 'The reply packet was sent' in p.stderr and os.path.exists(root + '/' + HUB + '.rep') and not reps(),
      (p.returncode, p.stderr[-500:], os.listdir(root)))
check('the packet was left at the hub (no ftp-delete)', os.path.exists(root + '/' + HUB + '.qwk'))
check('the transcript has the FTP dialogue, the password only as stars', '>> USER lion' in tl and '>> PASS ********' in tl and '<< 226' in tl and PW not in tl and PW not in p.stderr, tl)
check('the server saw RETR and STOR with the default names', 'RETR ' + HUB + '.qwk' in srv.log and 'STOR ' + HUB + '.rep' in srv.log, srv.log)
clean(); write_map('ftp-delete yes\nget qwk/%id%.QWK\nput qwk/%id%.REP\n'); post(); make_packet(root + '/qwk/' + HUB + '.QWK')
p = run()
check('"get" and "put" name the remote files (%id% replaced), ftp-delete yes removes the packet after it was fetched',
      p.returncode == 0 and os.path.exists(root + '/qwk/' + HUB + '.REP') and not os.path.exists(root + '/qwk/' + HUB + '.QWK'), (p.returncode, p.stderr[-400:], os.listdir(root + '/qwk')))
clean(); write_map(); post()
p = run()
check('no packet at the hub (550): nothing new, not an error, the reply packet still goes', p.returncode == 0 and 'Nothing new' in p.stderr and os.path.exists(root + '/' + HUB + '.rep'), (p.returncode, p.stderr[-300:]))
clean(); write_map(pw='wrong'); post()
p = run()
check('a wrong password: exit 5, says so, the reply packet stays', p.returncode == 5 and 'Login refused' in p.stderr and len(reps()) == 1, (p.returncode, p.stderr[-300:], reps()))
clean(); write_map('reply-error thank you\n'); post()
p = run()
check('reply-error looks at the last reply of the server after the reply packet (here "thank you"): exit 7, the packet stays', p.returncode == 7 and len(reps()) == 1, (p.returncode, p.stderr[-300:]))
clean(); write_map(); post()
p = run('-D')
check('dry run: says FTP, the remote names, connects to nothing', p.returncode == 0 and 'Hub by FTP' in p.stderr and HUB + '.qwk' in p.stderr, p.stderr[-400:])
srv.close()
srv2 = None
# ---- plain FTP over IPv6 (EPSV: the data connection goes to the machine of the control connection)
try:
    t6 = socket.socket(socket.AF_INET6); t6.bind(('::1', 0)); t6.close()
    v6 = True
except OSError:
    v6 = False
    print('skip: no IPv6 on this system')
if v6:
    srv6 = FakeFtp(root, port + 7, password=PW, host='::1')
    for hostform in ('[::1]', '::1'):
        clean(); write_map(host=hostform, hubport=port + 7) if hostform == '[::1]' else open(mapf, 'w').write('inbound %s/in\noutbound %s/out\nuser Chuck Ebenschweiger\nhub [::1]:%d\ntransport ftp\nlogin lion\npassword %s\nconf 6 6\n' % (ra, ra, port + 7, PW))
        post(); make_packet(root + '/' + HUB + '.qwk')
        p = run()
        check('FTP to %s (IPv6): packet fetched, reply packet stored, EPSV used' % hostform, p.returncode == 0 and 'Packet received: ' + HUB + '.qwk' in p.stderr and os.path.exists(root + '/' + HUB + '.rep') and 'EPSV' in ' '.join(srv6.log), (p.returncode, p.stderr[-400:], srv6.log[-6:]))
    srv6.close()
# a server that is not there
write_map('ftp-timeout 5\n'); post()
p = run()
check('no server: exit 5', p.returncode == 5 and 'FTP with' in p.stderr, (p.returncode, p.stderr[-300:]))

# ---- FTPS
def cert(name, cn, san):
    subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', work + '/%s.key' % name, '-out', work + '/%s.crt' % name, '-days', '2', '-subj', '/CN=' + cn,
                    '-addext', 'subjectAltName=' + san], check=True, capture_output=True)


cert('good', 'localhost', 'DNS:localhost,IP:127.0.0.1')
cert('other', 'other.example', 'DNS:other.example')
port += 3
srv = FakeFtp(root, port, password=PW, certfile=work + '/good.crt', keyfile=work + '/good.key')
clean(); write_map('tls-ca %s/good.crt\n' % work, transport='ftps', host='localhost'); post(); make_packet(root + '/' + HUB + '.qwk')
p = run()
tl = open(tlog, encoding='latin-1').read() if os.path.exists(tlog) else ''
check('FTPS (AUTH TLS, PROT P), the certificate checked against tls-ca and the name: the pass works, exit 0',
      p.returncode == 0 and 'Connected by FTPS' in p.stderr and 'Packet received' in p.stderr and os.path.exists(root + '/' + HUB + '.rep') and 'AUTH TLS' in srv.log and 'PROT P' in srv.log, (p.returncode, p.stderr[-500:], srv.log))
check('the data connections reused the TLS session of the control connection', srv.resumed and all(srv.resumed), srv.resumed)
check('the password is not in the transcript', '>> PASS ********' in tl and PW not in tl, tl)
clean(); write_map('', transport='ftps', host='localhost'); post()
p = run()
check('without tls-ca the certificate (self-signed) is not accepted: exit 5, says so, the reply packet stays', p.returncode == 5 and 'TLS' in p.stderr and len(reps()) == 1, (p.returncode, p.stderr[-300:]))
clean(); write_map('tls-verify no\n', transport='ftps', host='localhost'); post(); make_packet(root + '/' + HUB + '.qwk')
p = run()
check('tls-verify no: it works with a certificate nobody vouches for', p.returncode == 0 and 'Packet received' in p.stderr, (p.returncode, p.stderr[-300:]))
srv.close()
srv = FakeFtp(root, port + 1, password=PW, certfile=work + '/other.crt', keyfile=work + '/other.key')
clean(); open(mapf, 'w').write(open(mapf).read()); write_map('tls-ca %s/other.crt\n' % work, transport='ftps', host='localhost'); post()
s = open(mapf).read().replace(':%d' % port, ':%d' % (port + 1)); open(mapf, 'w').write(s)
p = run()
check('a certificate that is valid (tls-ca) but is for another name: exit 5, "not for localhost"', p.returncode == 5 and 'not for localhost' in p.stderr, (p.returncode, p.stderr[-300:]))
srv.close()
plain = FakeFtp(root, port + 2, password=PW)
clean(); write_map('', transport='ftps', host='localhost'); post()
s = open(mapf).read().replace(':%d' % port, ':%d' % (port + 2)); open(mapf, 'w').write(s)
p = run()
check('a server without TLS asked for FTPS: exit 5, says it does not do AUTH TLS (nothing is sent in the clear)', p.returncode == 5 and 'AUTH TLS' in p.stderr and 'STOR' not in ' '.join(plain.log), (p.returncode, p.stderr[-300:], plain.log))
plain.close()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
