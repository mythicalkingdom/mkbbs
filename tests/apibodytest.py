#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The machinery of the JSON API for paths that change something (QWK packets, phase 1 of QWK-API-PLAN.md): request bodies to a spool file after the token, the limit (413), Content-Length rules (411, 400),
Expect: 100-continue, a body that stops (408) or a caller who goes, the methods a path takes (405 with Allow), binary answers streamed from a file (GET and HEAD), the log line with the bytes, no spool
file left; the qwk scopes of mkapitoken and the limits in apitokens.json.  The test paths /v1/test/... exist only with MKAPI_TEST=1.   usage: apibodytest.py <work dir>"""
import hashlib, json, os, re, shutil, socket, subprocess, sys, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src) or not os.path.exists(build + '/mkapi'):
    print('skip: no sample BBS or mkapi'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'api body: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((src + '/').encode()):] if s.startswith((src + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
os.makedirs(ra + '/tmp', exist_ok=True)
cfgj = tmp + '/cj'
os.makedirs(cfgj)
envj = dict(os.environ, MK=ra, MKJSON=cfgj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
d = json.load(open(cfgj + '/bbsconfig.json', encoding='utf-8'))
d['config']['TempPath'] = ra + '/tmp/'
json.dump(d, open(cfgj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)


def tool(*a):
    return subprocess.run([build + '/mkapitoken', '-c', ra] + list(a), capture_output=True, text=True)


# --- the tokens
r = tool('add', 'q1', '-s', 'qwk')
check('the scope qwk needs a token that names a user: refused without -u', r.returncode == 1 and '-u' in r.stderr, r.stderr)
r = tool('add', 'q2', '-s', 'qwk:reply', '-u', 'Some Node', '-q')
check('... and is accepted with -u', r.returncode == 0 and r.stdout.startswith('mkapi_'), r.stdout + r.stderr)
r = tool('limits')
check('limits: the defaults (10 MB packet, 5 MB reply, 7 days) when the file has no "qwk" object', 'max_packet 10485760' in r.stdout and 'max_reply 5242880' in r.stdout and 'keep_days 7' in r.stdout, r.stdout)
tf = json.load(open(ra + '/apitokens.json'))
tf['qwk'] = {'max_packet': 2000000, 'keep_days': 3}
json.dump(tf, open(ra + '/apitokens.json', 'w'))
r = tool('limits')
check('limits: what the "qwk" object says, the rest by default', 'max_packet 2000000' in r.stdout and 'max_reply 5242880' in r.stdout and 'keep_days 3' in r.stdout, r.stdout)
tool('add', 'again', '-s', 'status')
check('the "qwk" object is kept when mkapitoken writes the file again', json.load(open(ra + '/apitokens.json')).get('qwk') == {'max_packet': 2000000, 'keep_days': 3})
tok = tool('add', 'all', '-s', '*', '-q').stdout.strip()
stok = tool('add', 'st', '-s', 'status', '-q').stdout.strip()

cfg = {'mk': build + '/mk', 'mkapi': build + '/mkapi', 'rundir': tmp + '/run', 'logfile': work + '/listen.log', 'workdir': ra, 'nodes': '1-4',
       'loginguard': {'fails': 500, 'window': 60, 'block': 5, 'allow': []},
       'ports': [{'port': 24871, 'type': 'api', 'config': ra, 'env': {'MKAPI_TEST': '1', 'MKAPI_BODY_IDLE': '3'}},
                 {'port': 24872, 'type': 'api', 'config': ra}]}
json.dump(cfg, open(work + '/listen.json', 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)


def conn(port=24871):
    for _ in range(50):
        try:
            return socket.create_connection(('127.0.0.1', port))
        except OSError:
            time.sleep(0.1)
    raise SystemExit('cannot connect')


def readall(s, secs=8):
    s.settimeout(secs)
    b = b''
    try:
        while True:
            x = s.recv(65536)
            if not x:
                break
            b += x
    except (socket.timeout, ConnectionError):
        pass
    return b


def parse(b):
    head, _, body = b.partition(b'\r\n\r\n')
    st = int(head.split()[1]) if head.startswith(b'HTTP/1.1') else 0
    return st, head.decode('latin-1'), body


def request(method, path, body=None, token=tok, headers='', port=24871, cl=True):
    h = '%s %s HTTP/1.1\r\nHost: x\r\n' % (method, path)
    if token:
        h += 'Authorization: Bearer %s\r\n' % token
    if body is not None and cl:
        h += 'Content-Length: %d\r\n' % len(body)
    s = conn(port)
    s.sendall((h + headers + '\r\n').encode() + (body or b''))
    return parse(readall(s))


try:
    time.sleep(2)
    data = bytes((i * 31 + 7) % 256 for i in range(50000))
    st, head, body = request('PUT', '/v1/test/echo', data, headers='Content-Type: application/zip\r\n')
    j = json.loads(body) if st == 200 else {}
    check('PUT with a body: 200, the number of bytes and the SHA-256 of what came (the spool file is read back)', st == 200 and j['bytes'] == 50000 and j['sha256'] == 'sha256:' + hashlib.sha256(data).hexdigest() and j['content_type'] == 'application/zip', (st, body))
    st, _, body = request('POST', '/v1/test/echo', b'')
    check('POST with an empty body: 200 and 0 bytes', st == 200 and json.loads(body)['bytes'] == 0, (st, body))
    st, head, body = request('GET', '/v1/test/echo')
    check('GET on a path that takes POST and PUT: 405 with Allow: POST, PUT', st == 405 and 'Allow: POST, PUT' in head, (st, head))
    st, head, body = request('PUT', '/v1/status', b'x')
    check('a body on a path that reads: 405 with Allow: GET, HEAD (the method is checked first)', st == 405 and 'Allow: GET, HEAD' in head, (st, head))
    st, _, body = request('GET', '/v1/status', b'hello')
    check('a GET with a body: 400', st == 400, (st, body))
    st, _, _ = request('DELETE', '/v1/status')
    check('another method (DELETE): 405', st == 405)
    st, _, body = request('PUT', '/v1/test/echo', b'x' * 10, cl=False)
    check('a body without Content-Length: 411', st == 411, (st, body))
    st, _, body = request('PUT', '/v1/test/echo', b'', headers='Transfer-Encoding: chunked\r\n')
    check('a chunked body: 400 (send Content-Length)', st == 400 and 'chunked' in body.decode(), (st, body))
    st, _, body = request('PUT', '/v1/test/echo', b'', headers='Content-Length: abc\r\n')
    check('Content-Length that is no number: 400', st == 400, (st, body))
    # over the limit: the answer comes before the body is sent
    s = conn()
    s.sendall(('PUT /v1/test/echo HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer %s\r\nContent-Length: 100001\r\n\r\n' % tok).encode())
    st, head, body = parse(readall(s, 5))
    check('over the limit (Content-Length 100001): 413 at once, nothing was read', st == 413 and '100000' in body.decode(), (st, body))
    st, _, body = request('PUT', '/v1/test/echo', b'y' * 100000)
    check('exactly at the limit: fine', st == 200 and json.loads(body)['bytes'] == 100000, (st, body))
    # the token first: no token, no body is read
    s = conn()
    s.sendall(b'PUT /v1/test/echo HTTP/1.1\r\nHost: x\r\nContent-Length: 1000\r\n\r\n')
    st, head, body = parse(readall(s, 5))
    check('no token: 401 before any body (the body never comes)', st == 401, (st, body))
    st, _, body = request('PUT', '/v1/test/echo', b'z', token=stok)
    check('a token without the scope: 403', st == 403, (st, body))
    # Expect: 100-continue
    s = conn()
    s.sendall(('PUT /v1/test/echo HTTP/1.1\\r\\nHost: x\\r\\nAuthorization: Bearer %s\\r\\nContent-Length: 5\\r\\nExpect: 100-continue\\r\\n\\r\\n' % tok).encode().decode('unicode_escape').encode())
    s.settimeout(5)
    first = s.recv(100)
    s.sendall(b'abcde')
    st, head, body = parse(readall(s, 5))
    check('Expect: 100-continue: "100 Continue" first, then the body is read and answered', first.startswith(b'HTTP/1.1 100 Continue') and st == 200 and json.loads(body)['bytes'] == 5, (first, st, body))
    # the body stops (idle timeout 3 s in this test), and a caller who goes
    s = conn()
    s.sendall(('PUT /v1/test/echo HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer %s\r\nContent-Length: 1000\r\n\r\n' % tok).encode() + b'only a little')
    t0 = time.time()
    st, head, body = parse(readall(s, 12))
    check('a body that stops coming: 408 after the idle time', st == 408 and 2 < time.time() - t0 < 10, (st, time.time() - t0))
    s = conn()
    s.sendall(('PUT /v1/test/echo HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer %s\r\nContent-Length: 1000\r\n\r\n' % tok).encode() + b'short')
    time.sleep(0.5)
    s.close()
    time.sleep(2.5)
    log = open(work + '/listen.log').read()
    check('a caller who goes in the middle of a body: no answer, a log line says how far it got', re.search(r'PUT /v1/test/echo the caller went after 5 of 1000 bytes', log), log[-600:])
    # binary answers streamed from a file
    for size in (0, 1, 8000, 100000, 3000000):
        st, head, body = request('GET', '/v1/test/blob?size=%d' % size)
        want = bytes((i * 7 + 3) % 251 for i in range(size)) if size < 200000 else None
        ok = st == 200 and 'Content-Length: %d' % size in head and 'application/octet-stream' in head and len(body) == size
        if want is not None:
            ok = ok and body == want
        else:
            ok = ok and hashlib.sha256(body).hexdigest() == hashlib.sha256(bytes((i * 7 + 3) % 251 for i in range(size))).hexdigest()
        check('a binary answer of %d bytes, byte for byte' % size, ok, (st, head[:200], len(body)))
    st, head, body = request('HEAD', '/v1/test/blob?size=100000')
    check('HEAD: the headers and the length, no body', st == 200 and 'Content-Length: 100000' in head and body == b'', (st, head, len(body)))
    st, _, _ = request('GET', '/v1/test/blob?size=6000000')
    check('a size that is too big: 400', st == 400)
    time.sleep(0.5)
    spool = [f for f in os.listdir(ra + '/tmp') if f.startswith('api')]
    check('no spool file is left (after a body, a refusal, a caller who went)', spool == [], spool)
    log = open(work + '/listen.log').read()
    check('the log line of a writing request: token id, address, method, path, answer, bytes in and out', re.search(r'api: all 127\.0\.0\.1 PUT /v1/test/echo 200 in=50000 out=\d+', log) is not None and 'mkapi_' not in log, log[-800:])
    st, _, _ = request('PUT', '/v1/test/echo', b'abc', port=24872)
    check('the test paths exist only with MKAPI_TEST=1 (another port: 404)', st == 404, st)
    # a read path still works as before
    st, head, body = request('GET', '/v1/status', token=stok)
    check('the paths that read are unchanged', st == 200 and 'bbs' in json.loads(body))
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
