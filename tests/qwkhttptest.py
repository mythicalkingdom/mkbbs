#!/usr/bin/env python3
"""mk -G with the http / https transport (QWK-API-PLAN.md phase 4) against a real hub: two private copies of the sample BBS, the hub with an api port (mklisten, mkapi) and a node user with a token, the node
calling it with the map file "hub http://..." (a front that can drop or damage an answer sits between them in some tests).  A pass: the packet is fetched, the reply packet is sent, the packet is posted and only
then acknowledged; an acknowledgement that could not be sent is sent at the next pass; the refusals; the transcript; TLS.   usage: qwkhttptest.py <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, threading, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
need = ('mk', 'mkapi', 'netsetup', 'postmsg', 'setlr', 'tosssetup', 'tossmake', 'tossdump')
if not os.path.isdir(src) or not all(os.path.exists(build + '/' + n) for n in need) or not shutil.which('zip') or not shutil.which('openssl'):
    print('skip: no sample BBS, tools, zip or openssl'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'qwk http: ' + name + ('' if ok else '  ' + str(info)[-700:]))
    if not ok:
        fails += 1


NODE = 'Chuck Ebenschweiger'
HUB = 'MythKing'


def make_bbs(tag):
    tmp = cfgpatch.short_dir()
    ra = tmp + '/r'
    shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
    cfgpatch.fix_sample(ra)
    cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((src + '/').encode()):] if s.startswith((src + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
    env = dict(os.environ, MK=ra)
    cj = tmp + '/cj'
    os.makedirs(cj)
    envj = dict(env, MKJSON=cj)
    subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
    dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
    dj['config']['ExtPack'][1]['PCmdLine'] = 'zip -q -j'
    dj['config']['ExtPack'][1]['UCmdLine'] = 'unzip -o -q'
    os.makedirs(ra + '/tmp', exist_ok=True)
    dj['config']['TempPath'] = ra + '/tmp/'
    json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
    subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
    os.makedirs(tmp + '/in', exist_ok=True)
    subprocess.run([build + '/tosssetup', tmp + '/in', tmp + '/outb', tmp + '/un'], env=env, capture_output=True, text=True)
    subprocess.run([build + '/tossmake'], env=env, capture_output=True, text=True)
    subprocess.run([build + '/netsetup', NODE, '6'], env=dict(env, NETSEC='110'), capture_output=True, text=True)
    for d in ('in', 'out'):
        os.makedirs(ra + '/' + d, exist_ok=True)
    return tmp, ra, env


htmp, hra, henv = make_bbs('hub')
ntmp, nra, nenv = make_bbs('node')


def post(env, subject, *lines):
    subprocess.run([build + '/postmsg', '6', 'Poster', 'All', subject] + list(lines), env=env, capture_output=True, text=True)


def dump(env):
    return subprocess.run([build + '/tossdump', '6'], env=env, capture_output=True, text=True).stdout


def tool(*a):
    return subprocess.run([build + '/mkapitoken', '-c', hra] + list(a), capture_output=True, text=True)


tok = tool('add', 'node5', '-s', 'qwk,qwk:reply', '-u', NODE, '-q').stdout.strip()
tok_noreply = tool('add', 'readonly', '-s', 'qwk', '-u', NODE, '-q').stdout.strip()
for cert in ('good',):
    subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', work + '/%s.key' % cert, '-out', work + '/%s.crt' % cert, '-days', '2', '-subj', '/CN=localhost',
                    '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1'], check=True, capture_output=True)
cfg = {'mk': build + '/mk', 'mkapi': build + '/mkapi', 'rundir': htmp + '/run', 'logfile': work + '/hub.log', 'workdir': hra, 'nodes': '1-4',
       'loginguard': {'fails': 500, 'window': 60, 'block': 5, 'allow': []},
       'tls': {'cert': work + '/good.crt', 'key': work + '/good.key'},
       'ports': [{'port': 24891, 'type': 'api', 'config': hra}, {'port': 24893, 'type': 'api', 'config': hra, 'tls': True}]}
json.dump(cfg, open(work + '/hub.json', 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/hub.json'], stdout=subprocess.DEVNULL)


# a front between the node and the hub that can drop the acknowledgement or damage the packet
class Front(threading.Thread):
    def __init__(self, port, up):
        super().__init__(daemon=True)
        self.port, self.up, self.mode = port, up, ''
        self.srv = socket.socket(); self.srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.srv.bind(('127.0.0.1', port)); self.srv.listen(5)

    def run(self):
        while True:
            try:
                c, _ = self.srv.accept()
            except OSError:
                return
            try:
                self.handle(c)
            except Exception:
                pass
            c.close()

    def handle(self, c):
        data = b''
        while b'\r\n\r\n' not in data:
            x = c.recv(65536)
            if not x:
                return
            data += x
        head, _, body = data.partition(b'\r\n\r\n')
        m = re.search(rb'Content-Length: (\d+)', head)
        want = int(m.group(1)) if m else 0
        while len(body) < want:
            body += c.recv(65536)
        line = head.split(b'\r\n')[0]
        if self.mode == 'dropack' and b'/ack ' in line:
            return                               # the connection just closes: no answer
        u = socket.create_connection(('127.0.0.1', self.up))
        u.sendall(head + b'\r\n\r\n' + body)
        resp = b''
        while True:
            x = u.recv(65536)
            if not x:
                break
            resp += x
        u.close()
        if self.mode == 'damage' and line.startswith(b'GET /v1/qwk/packet') and resp.startswith(b'HTTP/1.1 200'):
            h, _, b = resp.partition(b'\r\n\r\n')
            b = bytearray(b); b[len(b) // 2] ^= 0xFF
            resp = h + b'\r\n\r\n' + bytes(b)
        c.sendall(resp)


front = Front(24892, 24891)
front.start()
mapf = nra + '/' + HUB + '.map'


def write_map(token=tok, hub='http://127.0.0.1:24892', extra=''):
    open(mapf, 'w').write('inbound %s/in\noutbound %s/out\nuser %s\nhub %s\ntoken %s\nconf 6 6\n%s' % (nra, nra, NODE, hub, token, extra))
    for f in (nra + '/' + HUB + '.ack',):
        if os.path.exists(f):
            os.remove(f)


def run(*args, env=None):
    return subprocess.run([build + '/mk', '-L', '-G' + HUB] + list(args), env=env or nenv, cwd=nra, capture_output=True, text=True, timeout=180, stdin=subprocess.DEVNULL)


def waiting():
    for _ in range(50):
        try:
            s = socket.create_connection(('127.0.0.1', 24891)); break
        except OSError:
            time.sleep(0.1)
    s.sendall(('GET /v1/qwk HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer %s\r\n\r\n' % tok).encode())
    b = b''
    s.settimeout(20)
    while True:
        x = s.recv(65536)
        if not x:
            break
        b += x
    return json.loads(b.partition(b'\r\n\r\n')[2])['waiting']


def reps():
    return [f for f in os.listdir(nra + '/out') if f.lower().endswith('.rep')]


try:
    time.sleep(2)
    # catch up: the node's pointer at the hub is at the top of the area, so only new messages go
    r0 = subprocess.run([build + '/setlr', NODE, '6'], env=henv, capture_output=True, text=True).stdout
    top = int(re.search(r'was (\d+)', r0).group(1))
    write_map()
    run()                                        # a first pass takes what there is and leaves things clean
    ack = nra + '/' + HUB + '.ack'
    post(henv, 'Message from the hub', 'written on the hub')
    post(nenv, 'Message from the node', 'written on the node')
    p = run()
    tl = open(nra + '/' + HUB + '.hub.log', encoding='latin-1').read() if os.path.exists(nra + '/' + HUB + '.hub.log') else ''
    check('a pass by http: the packet is fetched, the reply packet is sent, the hub is told the packet is posted, exit 0',
          p.returncode == 0 and re.search(r'Packet fetched from the hub \(\d+ message\(s\), packet [0-9a-f]{12}\)', p.stderr) and 'The reply packet was sent' in p.stderr and 'The hub was told that packet' in p.stderr and not reps(), (p.returncode, p.stderr[-600:]))
    check('the message of the hub is posted on the node, the message of the node on the hub', 'Message from the hub' in dump(nenv) and 'Message from the node' in dump(henv), (dump(nenv)[-300:], dump(henv)[-300:]))
    check('the hub has no packet waiting after the acknowledgement, the node keeps no note of one', waiting() is None and not os.path.exists(ack) and not [f for f in os.listdir(nra + '/in') if f.lower().endswith('.qwk')], (waiting(), os.listdir(nra + '/in')))
    check('the transcript has the requests and the answers, never the token', 'GET /v1/qwk/packet' in tl and '<< 200' in tl and 'PUT /v1/qwk/reply' in tl and tok not in tl and tok not in p.stderr, tl)
    run()                                        # the message of the node comes back from the hub like any message of the area: this pass takes it
    p = run()
    check('the next pass: nothing new (204), exit 0', p.returncode == 0 and 'Nothing new at the hub' in p.stderr, (p.returncode, p.stderr[-300:]))
    check('the posts of the hub are in the node base once (the second pass did not bring them again)', dump(nenv).count('Message from the hub') == 1, dump(nenv)[-400:])
    # the acknowledgement is lost
    post(henv, 'Second from the hub', 'another one')
    front.mode = 'dropack'
    p = run()
    check('the acknowledgement could not be sent: the pass is done (exit 0), says the hub will be told at the next pass, the hub still has the packet, the node has a note', p.returncode == 0 and 'The hub could not be told' in p.stderr
          and waiting() is not None and os.path.exists(ack), (p.returncode, p.stderr[-400:], waiting(), os.path.exists(ack)))
    check('... and the messages are posted on the node', 'Second from the hub' in dump(nenv))
    front.mode = ''
    p = run()
    check('the next pass tells the hub first (before asking for a packet): the packet is not sent again, nothing is posted twice', p.returncode == 0 and 'The hub was told that packet' in p.stderr and 'Nothing new at the hub' in p.stderr
          and waiting() is None and not os.path.exists(ack) and dump(nenv).count('Second from the hub') == 1, (p.returncode, p.stderr[-400:], waiting(), dump(nenv).count('Second from the hub')))
    # a packet that is damaged on the way
    post(henv, 'Third from the hub', 'to be damaged')
    front.mode = 'damage'
    p = run()
    check('a packet that came damaged (SHA-256 does not match): exit 5, thrown away, nothing posted, the hub keeps it', p.returncode == 5 and 'damaged' in p.stderr and 'Third from the hub' not in dump(nenv) and waiting() is not None, (p.returncode, p.stderr[-400:]))
    front.mode = ''
    p = run()
    check('the next pass gets the same packet whole and posts it', p.returncode == 0 and 'Third from the hub' in dump(nenv) and waiting() is None, (p.returncode, p.stderr[-300:], waiting()))
    # the reply is refused, the token is wrong
    write_map(token=tok_noreply)
    post(nenv, 'Node message two', 'second')
    p = run()
    check('a token without qwk:reply: the packet part works, the reply packet is refused with 403: exit 5, the reply stays', p.returncode == 5 and 'did not take the reply packet' in p.stderr and '403' in p.stderr and len(reps()) == 1, (p.returncode, p.stderr[-400:], reps()))
    write_map(token='mkapi_' + 'A' * 43)
    p = run()
    check('a token that is not known: exit 5, 401 said, the reply packet stays', p.returncode == 5 and '401' in p.stderr and len(reps()) == 1, (p.returncode, p.stderr[-300:]))
    write_map(token='')
    p = run()
    check('no token in the map file: exit 5, says what is missing', p.returncode == 5 and 'no "token"' in p.stderr, (p.returncode, p.stderr[-300:]))
    write_map(token='', extra='token-env QWK_TEST_TOKEN\n')
    p = run(env=dict(nenv, QWK_TEST_TOKEN=tok))
    check('token-env: the token comes from the environment, the reply that was waiting goes', p.returncode == 0 and 'The reply packet was sent' in p.stderr and not reps() and tok not in p.stderr, (p.returncode, p.stderr[-300:], reps()))
    write_map()
    post(nenv, 'Node message three', 'third')
    p = run('-D')
    check('dry run: says HTTP, the paths, sends nothing', p.returncode == 0 and 'Hub by HTTP' in p.stderr and '/v1/qwk/packet' in p.stderr and tok not in p.stderr and len(reps()) == 0, (p.returncode, p.stderr[-400:]))
    write_map(hub='http://127.0.0.1:24899', extra='ftp-timeout 5\n')
    p = run()
    check('a hub that is not there: exit 5, the reply packet stays', p.returncode == 5 and 'HTTP with' in p.stderr, (p.returncode, p.stderr[-300:]))
    # TLS
    write_map(hub='https://localhost:24893', extra='tls-ca %s/good.crt\n' % work)
    p = run()
    check('https with the certificate checked (tls-ca, the name): the pass works, the reply that was waiting goes', p.returncode == 0 and 'Hub by HTTPS' in p.stderr and 'The reply packet was sent' in p.stderr, (p.returncode, p.stderr[-500:]))
    post(nenv, 'Node message four', 'fourth')
    write_map(hub='https://localhost:24893')
    p = run()
    check('without tls-ca the certificate (self-signed) is not accepted: exit 5, nothing is sent in the clear', p.returncode == 5 and 'TLS' in p.stderr and len(reps()) == 1, (p.returncode, p.stderr[-300:]))
    write_map(hub='https://localhost:24893', extra='tls-verify no\n')
    p = run()
    check('tls-verify no: it works with a certificate nobody vouches for', p.returncode == 0 and not reps(), (p.returncode, p.stderr[-300:]))
finally:
    front.srv.close()
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
