#!/usr/bin/env python3
"""The JSON API, phase 1: the "api" port type of mklisten, mkapi (HTTP, JSON, GET and HEAD only, one request), the token file and mkapitoken (hash only, mode 600, scopes, expiry, addresses), TLS,
the login guard counting bad tokens.  Real programs on a private copy of the sample BBS.   usage: apitest.py <work dir>"""
import json, os, re, shutil, socket, ssl, stat, subprocess, sys, time, hashlib
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
    print(('ok   ' if ok else 'FAIL ') + 'api: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((src + '/').encode()):] if s.startswith((src + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
env = dict(os.environ, MK=ra)
TF = ra + '/apitokens.json'
# a file area with files of its own (the first file area of the sample gets a directory)
cj = tmp + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
cd = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
FA = int(sorted(cd['files'], key=int)[0])
fdir = tmp + '/f1/'
os.makedirs(fdir)
cd['files'][str(FA)]['FilePath'] = fdir
json.dump(cd, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
for n_, sz in (('alpha.zip', 100), ('Beta.TXT', 2000), ('gamma.lzh', 5), ('unlisted.dat', 7)):
    open(fdir + n_, 'wb').write(b'x' * sz)
open(fdir + 'files.bbs', 'w', encoding='latin-1').write('alpha.zip     The first file\n              with a second line\nBeta.TXT      Beta notes\ngamma.lzh     A \x82cole archive\nGONE.ZIP      listed, not there\n')
os.utime(fdir + 'alpha.zip', (1700000000, 1700000000))


def tool(*a):
    return subprocess.run([build + '/mkapitoken', '-c', ra] + list(a), capture_output=True, text=True)


# --- mkapitoken
r = tool('add', 'dash', '-s', 'status,nodes', '-n', 'the dashboard', '-q')
tok = r.stdout.strip()
check('add: prints the token once (-q: only the token), 6 + 43 characters', r.returncode == 0 and re.fullmatch(r'mkapi_[A-Za-z0-9_-]{43}', tok), r.stdout + r.stderr)
d = json.load(open(TF))
check('the file holds the SHA-256 of the token, never the token', d['tokens'][0]['hash'] == 'sha256:' + hashlib.sha256(tok.encode()).hexdigest() and tok not in open(TF).read())
check('the token file is mode 600', stat.S_IMODE(os.stat(TF).st_mode) == 0o600, oct(os.stat(TF).st_mode))
r = tool('add', 'dash', '-s', 'status')
check('the same id twice is refused', r.returncode == 1 and 'already' in r.stderr, r.stderr)
r = tool('add', 'x', '-s', 'nonsense')
check('an unknown scope is refused', r.returncode == 1 and 'unknown scope' in r.stderr, r.stderr)
r = tool('add', 'x', '-s', 'self:mail')
check('a self: scope needs a user (-u)', r.returncode == 1 and '-u' in r.stderr, r.stderr)
r = tool('add', 'bad id!', '-s', 'status')
check('an id with odd characters is refused', r.returncode == 1)
exp = tool('add', 'old', '-s', 'status', '-e', '2000-01-01', '-q').stdout.strip()
net = tool('add', 'lan', '-s', 'status', '-f', '10.0.0.0/8,192.168.1.5', '-q').stdout.strip()
nodes_only = tool('add', 'nodesonly', '-s', 'nodes', '-q').stdout.strip()
allq = tool('add', 'all', '-s', '*', '-q').stdout.strip()
usr = tool('add', 'mark', '-s', 'self:mail,status', '-u', 'Mark May', '-q').stdout.strip()
r = tool('list')
check('list: scopes, expiry (EXPIRED), addresses, the user, never used; no token', 'old: scopes status expires 2000-01-01 (EXPIRED)' in r.stdout and 'from 10.0.0.0/8, 192.168.1.5' in r.stdout and 'acts for the user Mark May' in r.stdout
      and 'never used' in r.stdout and tok not in r.stdout, r.stdout)

# --- mklisten with api ports
subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', work + '/key.pem', '-out', work + '/cert.pem', '-days', '2', '-subj', '/CN=localhost',
                '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1'], capture_output=True, check=True)
cfg = {'mk': build + '/mk', 'mkapi': build + '/mkapi', 'rundir': tmp + '/run', 'logfile': work + '/listen.log', 'workdir': ra, 'nodes': '1-4',
       'loginguard': {'fails': 500, 'window': 60, 'block': 5, 'allow': []},
       'tls': {'cert': work + '/cert.pem', 'key': work + '/key.pem'},
       'ports': [{'port': 24861, 'type': 'api', 'config': ra},
                 {'port': 24862, 'type': 'api', 'config': ra, 'tls': True, 'label': 'api-tls'}]}


def listen_t(c, name='t.json'):
    json.dump(c, open(work + '/' + name, 'w'))
    return subprocess.run([build + '/mklisten', '-c', work + '/' + name, '-t'], capture_output=True, text=True)


r = listen_t(cfg)
check('mklisten -t accepts api ports (plain on loopback, TLS) and names mkapi', r.returncode == 0 and 'mkapi:' in r.stdout, r.stdout + r.stderr)
bad = json.loads(json.dumps(cfg)); bad['ports'][0]['bind'] = '0.0.0.0'
r = listen_t(bad)
check('an api port that is not on 127.0.0.1 without TLS is refused', r.returncode != 0 and 'needs "tls"' in (r.stdout + r.stderr), r.stdout + r.stderr)
bad['ports'][0]['insecure'] = True
r = listen_t(bad)
check('... unless "insecure": true says so', r.returncode == 0, r.stdout + r.stderr)
bad = json.loads(json.dumps(cfg)); bad['ports'][1]['bind'] = '0.0.0.0'
r = listen_t(bad)
check('an api port with TLS may be on every address', r.returncode == 0, r.stdout + r.stderr)
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/t.json' if False else (json.dump(cfg, open(work + '/listen.json', 'w')) or work + '/listen.json')], stdout=subprocess.DEVNULL)


def http(raw, port=24861, tls=False, secs=6):
    for _ in range(50):
        try:
            s = socket.create_connection(('127.0.0.1', port)); break
        except OSError:
            time.sleep(0.1)
    if tls:
        ctx = ssl.create_default_context(cafile=work + '/cert.pem')
        s = ctx.wrap_socket(s, server_hostname='localhost')
    s.sendall(raw if isinstance(raw, bytes) else raw.encode())
    s.settimeout(secs)
    b = b''
    try:
        while True:
            x = s.recv(65536)
            if not x:
                break
            b += x
    except (socket.timeout, ssl.SSLError, ConnectionError):
        pass
    s.close()
    head, _, body = b.partition(b'\r\n\r\n')
    st = int(head.split()[1]) if head.startswith(b'HTTP/1.1') else 0
    return st, head.decode('latin-1'), body


def get(path, token=None, method='GET', **kw):
    h = '%s %s HTTP/1.1\r\nHost: x\r\n' % (method, path)
    if token:
        h += 'Authorization: Bearer %s\r\n' % token
    return http(h + '\r\n', **kw)


try:
    time.sleep(2)
    st, head, body = get('/v1/status', tok)
    j = json.loads(body) if st == 200 else {}
    check('a good token: 200 and the status as JSON (bbs, software, time, nodes)', st == 200 and 'bbs' in j and 'software' in j and 'in_use' in j.get('nodes', {}) and 'application/json' in head, (st, head, body))
    check('the answer has the length, no caching, nosniff, close', 'Content-Length: %d' % len(body) in head and 'no-store' in head and 'nosniff' in head and 'Connection: close' in head, head)
    st, head, body = get('/v1', tok)
    j = json.loads(body)
    check('/v1: the token id, its scopes and the paths', st == 200 and j['token'] == 'dash' and j['scopes'] == ['status', 'nodes'] and '/v1/status' in j['paths'], body)
    st, head, body = get('/v1/status', tok, method='HEAD')
    check('HEAD: the headers and the length, no body', st == 200 and body == b'' and 'Content-Length:' in head)
    st, _, body = get('/v1/status', allq)
    check('the scope * is every scope', st == 200)
    st, _, body = get('/v1/nothing', tok)
    check('an unknown path with a good token: 404 JSON', st == 404 and json.loads(body)['error'], body)
    st, _, body = get('/v1/status', nodes_only)
    check('a token without the scope of the endpoint: 403', st == 403 and json.loads(body)['error'], (st, body))
    time.sleep(0.5)
    st, _, body = get('/v1/status', exp)
    check('an expired token: 401', st == 401)
    st, _, body = get('/v1/status', net)
    check('a token for other addresses: 401 from 127.0.0.1', st == 401)
    st, head, body = get('/v1/status', usr)
    check('a token that names a user works for the scopes it has (the self: scopes have no endpoint yet)', st == 200)
    st, head, body = http('POST /v1/status HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer %s\r\nContent-Length: 2\r\n\r\n{}' % tok)
    check('POST: 405 with Allow: GET, HEAD (read only)', st == 405 and 'Allow: GET, HEAD' in head, (st, head))
    st, head, body = http('GET /v1/status HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer %s\r\nContent-Length: 5\r\n\r\nhello' % tok)
    check('a GET with a body is refused (400)', st == 400, (st, body))
    st, head, body = http('GARBAGE\r\n\r\n')
    check('a request line that is no HTTP: 400', st == 400, (st, body))
    st, head, body = http('GET /v1/status HTTP/1.1\r\nX: ' + 'a' * 9000 + '\r\n\r\n')
    check('a header that is too long: 431', st == 431, (st, head))
    st, head, body = get('/v1/status', 'mkapi_' + 'A' * 43)
    check('a token that is not known: 401 with WWW-Authenticate, and the answer does not say why', st == 401 and 'WWW-Authenticate: Bearer' in head and json.loads(body)['error'] == 'a valid token is needed', (st, head, body))
    # last use, the log
    time.sleep(0.5)
    lu = open(ra + '/apitokens.use').read()
    check('apitokens.use has the last use of the token (id, time, address)', re.search(r'^dash\t\d+\t127\.0\.0\.1$', lu, re.M), lu)
    log = open(work + '/listen.log').read()
    check('the log has a line for each request (token id, address, request, answer) and never a token', 'api: dash 127.0.0.1 GET /v1/status 200' in log and 'mkapi_' not in log, log[-700:])
    # ---- phase 2: the data endpoints
    run = tmp + '/run'
    import struct, threading
    # nodes: a node file whose process is there (this one), a record of useron.bbs for the node
    open(run + '/node2.info', 'w').write('node=2\npid=%d\nport=2323\ntype=telnet\nbaud=0\naddr=192.0.2.9\nstart=%d\n' % (os.getpid(), int(time.time()) - 600))
    open(run + '/node3.info', 'w').write('node=3\npid=999999\nport=2323\ntype=telnet\nbaud=0\naddr=192.0.2.10\nstart=1\n')     # a process that is not there
    rec = bytes([len(b'Test Caller')]) + b'Test Caller'.ljust(35, b'\0') + bytes([0]) + b''.ljust(35, b'\0') + bytes([2]) + struct.pack('<H', 0) + bytes([5]) + b'Dayton'.ljust(25, b'\0') + bytes([4])
    uo = bytearray(open(ra + '/useron.bbs', 'rb').read().ljust(1020, b'\0'))
    uo[102:204] = rec
    open(ra + '/useron.bbs', 'wb').write(bytes(uo))
    st, _, body = get('/v1/nodes', allq)
    j = json.loads(body)
    n2 = [x for x in j['nodes'] if x['node'] == 2]
    check('/v1/nodes: the nodes in use only (a node file whose process is gone is left out), with user, activity (as mkmon shows it), port, address, since', st == 200 and j['count'] == 1 and n2 and n2[0]['user'] == 'Test Caller'
          and n2[0]['activity'] == 'door' and n2[0]['address'] == '192.0.2.9' and n2[0]['port'] == 2323 and 'T' in n2[0]['since'], (st, body))
    # events: events.info as mklisten writes it
    open(run + '/events.info', 'w').write('# written by mklisten\nnow=%d\nblocked=1\nqueue=0\nrunning=1\ncallers=2\nE\t1\t1\t150\t127\tidle\t1\t45\t%d\t0\t0\trun /bbs/bin/housekeeping.sh\nE\t2\t0\t60\t0\tdisabled\t0\t-1\t0\t-1\t5\t\n' % (time.time(), int(time.time()) - 3600))
    st, _, body = get('/v1/events', allq)
    j = json.loads(body)
    e1 = j['events'][0] if st == 200 and j.get('events') else {}
    check('/v1/events: the events with time, days, state, exclusive, next, last run and result, action; the counters', st == 200 and len(j['events']) == 2 and e1.get('time') == '02:30' and e1['days'] == ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']
          and e1['exclusive'] is True and e1['next_in_minutes'] == 45 and e1['last_result'] == 0 and e1['action'] == 'run /bbs/bin/housekeeping.sh' and j['new_logons_refused'] is True and j['callers'] == 2 and j['running'] == 1
          and j['events'][1]['enabled'] is False and j['events'][1]['next_in_minutes'] is None and j['events'][1]['last_run'] is None, (st, body))
    # the mailer: a control socket that sends a frame
    frame = 'STATE 1700000000\nME 2:123/456\tTest BBS\tSysop\t1700000000\t24554\tmkbink 1\nSTAT 5\t4\t1\t2\t1000\t2000\t3\t4\n' + \
            'LINK 2:123/1\tHub\thub.example.org\tCM\t60\tidle\t0\t1700003600\tok\t2\t4096\t1700000000\nSESS 7\tO\t2:123/1\tHub\tAdmin\tSomewhere\t1700000100\tbusy\t\t100\t200\t1\t2\n' + 'END\n'
    sockp = run + '/mailer.sock'
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(sockp); srv.listen(2); srv.settimeout(10)
    def serve():
        try:
            while True:
                c, _ = srv.accept()
                c.sendall(frame.encode()); time.sleep(0.3); c.close()
        except OSError:
            pass
    threading.Thread(target=serve, daemon=True).start()
    st, _, body = get('/v1/mailer', allq)
    j = json.loads(body)
    check('/v1/mailer: the frame of the mailer as JSON (me, statistics, links, sessions); nothing is sent to it', st == 200 and j['running'] and j['me']['address'] == '2:123/456' and j['statistics']['calls'] == 5 and j['statistics']['bytes_received'] == 2000
          and j['links'][0]['address'] == '2:123/1' and j['links'][0]['waiting_bytes'] == 4096 and j['sessions'][0]['direction'] == 'out' and j['sessions'][0]['files_received'] == 2, (st, body))
    srv.close(); os.remove(sockp)
    st, _, body = get('/v1/mailer', allq)
    check('/v1/mailer without a mailer: {"running": false}', st == 200 and json.loads(body) == {'running': False}, body)
    # statistics and calls: lines in stats/
    os.makedirs(ra + '/stats', exist_ok=True)
    t0 = 1795000000
    def line(i, user, res, secs, node=1, label='telnet', day='2026-11-20', hour=10):
        return '\t'.join([str(t0 + i * 100), str(t0 + i * 100 + secs), day, str(node), 'telnet', label, '2323', '192.0.2.%d' % i, user, res, str(secs), '1', '2', '10', '20', '3', '']) + '\n'
    lines = ['#mkstats 1\n', line(1, 'Ann', 'ok', 600), line(2, 'Bob', 'ok', 300, node=2), line(3, '', 'failed', 20, day='2026-11-21'), line(4, 'Ann', 'ok', 60, day='2026-11-21'), line(5, '', 'nologon', 1, day='2026-10-30')]
    open(ra + '/stats/2026-11.tsv', 'w').write(''.join(lines[:5]))
    open(ra + '/stats/2026-10.tsv', 'w').write('#mkstats 1\n' + lines[5])
    st, _, body = get('/v1/stats?from=2026-11-01&to=2026-11-30', allq)
    j = json.loads(body)
    t = j['totals']
    check('/v1/stats: totals for the days (calls, logons, failed, callers, minutes, files, K, messages, busiest day)', st == 200 and t['calls'] == 4 and t['logons'] == 3 and t['failed'] == 1 and t['no_logon'] == 0 and t['callers'] == 2 and t['minutes'] == 16.3
          and t['upload_files'] == 4 and t['download_k'] == 80 and t['messages'] == 12 and t['busiest_day'] in ('2026-11-20', '2026-11-21'), (st, body))
    st, _, body = get('/v1/stats?from=2026-10-01&to=2026-11-30&by=user', allq)
    j = json.loads(body)
    rows = {r['user']: r for r in j['rows']}
    check('/v1/stats?by=user: a row for each user, over two months', st == 200 and j['totals']['calls'] == 5 and rows['Ann']['calls'] == 2 and rows['Bob']['logons'] == 1 and rows['(nobody)']['calls'] == 2, (st, body))
    st, _, body = get('/v1/stats?by=nonsense', allq)
    check('/v1/stats with a wrong "by" or a bad date: 400', st == 400 and get('/v1/stats?from=yesterday', allq)[0] == 400, (st, body))
    st, _, body = get('/v1/calls?limit=3', allq)
    j = json.loads(body)
    check('/v1/calls?limit=3: the last calls, newest first, with start, user, result, seconds, address', st == 200 and j['count'] == 3 and len(j['calls']) == 3 and j['calls'][0]['user'] == 'Ann' and j['calls'][0]['seconds'] == 60 and j['calls'][0]['address'] == '192.0.2.4'
          and j['calls'][0]['start'] > j['calls'][1]['start'], (st, body))
    st, _, body = get('/v1/calls?limit=500&since=%d' % (t0 + 250), allq)
    check('/v1/calls?since=<unix time>: only the calls from then on', st == 200 and json.loads(body)['count'] == 3, body)
    # the areas of the sample
    st, _, body = get('/v1/areas/messages', allq)
    j = json.loads(body)
    a4 = [a for a in j['areas'] if a['number'] == 4]
    check('/v1/areas/messages: every area with its type, base kind, messages and highest number (the netmail area has one message)', st == 200 and len(j['areas']) > 10 and a4 and a4[0]['type'] == 'netmail' and a4[0]['base'] == 'H' and a4[0]['messages'] == 1 and a4[0]['highest'] >= 1, (st, body[:300]))
    st, _, body = get('/v1/areas/files', allq)
    j = json.loads(body)
    check('/v1/areas/files: every area with number, name, files, listed, bytes (or "available": false)', st == 200 and len(j['areas']) > 10 and all('available' in a and 'name' in a for a in j['areas']), (st, body[:300]))
    # the files of an area
    st, _, body = get('/v1/areas/files/%d' % FA, allq)
    j = json.loads(body)
    fl = {f['name']: f for f in j.get('files', [])}
    check('/v1/areas/files/<area>: the files that are there with name, description (continuation lines joined), size and date; the listed file that is gone is left out', st == 200 and j['area'] == FA and sorted(fl, key=str.lower) == ['alpha.zip', 'Beta.TXT', 'gamma.lzh', 'unlisted.dat']
          and fl['alpha.zip']['description'] == 'The first file\nwith a second line' and fl['alpha.zip']['size'] == 100 and fl['alpha.zip']['date'] == '2023-11-14' and fl['Beta.TXT']['size'] == 2000 and 'GONE.ZIP' not in fl, (st, body[:500]))
    check('a file that the list does not name: description null; CP437 descriptions come out as UTF-8; the order is by name without regard to case', fl['unlisted.dat']['description'] is None and fl['gamma.lzh']['description'] == 'A \u00e9cole archive'
          and [f['name'] for f in j['files']] == ['alpha.zip', 'Beta.TXT', 'gamma.lzh', 'unlisted.dat'], body[:500])
    st, _, body = get('/v1/areas/files/%d?limit=2' % FA, allq)
    j = json.loads(body)
    st2, _, body2 = get('/v1/areas/files/%d?limit=2&after=%s' % (FA, j['next']), allq)
    j2 = json.loads(body2)
    check('paging: limit 2 gives "next" (the last name), after= continues, the last page has next null', st == 200 and j['count'] == 2 and j['next'] == 'Beta.TXT' and [f['name'] for f in j2['files']] == ['gamma.lzh', 'unlisted.dat'] and j2['next'] is None, (body, body2))
    j = json.loads(get('/v1/areas/files/%d?q=beta' % FA, allq)[2])
    check('q searches names and descriptions (any case)', [f['name'] for f in j['files']] == ['Beta.TXT'] and len(json.loads(get('/v1/areas/files/%d?q=second%%20line' % FA, allq)[2])['files']) == 1)
    check('an area that is not there: 404', get('/v1/areas/files/9999', allq)[0] == 404 and get('/v1/areas/files/x', allq)[0] == 404)
    tf = tool('add', 'areasonly', '-s', 'areas', '-q').stdout.strip()
    check('the files need their own scope: "areas" lists the areas, not the files (403)', get('/v1/areas/files', tf)[0] == 200 and get('/v1/areas/files/%d' % FA, tf)[0] == 403)
    # users
    st, _, body = get('/v1/users?limit=5', allq)
    j = json.loads(body)
    check('/v1/users?limit=5: five users, no password or phone, "next" for the following page', st == 200 and j['count'] == 5 and len(j['users']) == 5 and j['next'] == j['users'][-1]['number'] and b'password' not in body.lower() and b'phone' not in body.lower()
          and all(k in j['users'][0] for k in ('number', 'name', 'city', 'level', 'calls', 'last_call', 'deleted')), (st, body[:400]))
    st, _, body2 = get('/v1/users?limit=5&after=%d' % j['next'], allq)
    j2 = json.loads(body2)
    check('the next page starts after it (no user twice)', st == 200 and j2['users'][0]['number'] > j['next'] and not ({u['number'] for u in j['users']} & {u['number'] for u in j2['users']}), body2[:200])
    st, _, body = get('/v1/users?q=mark%20may&limit=10', allq)
    j = json.loads(body)
    check('/v1/users?q=: a search in names and handles (any case)', st == 200 and j['count'] >= 1 and all('mark may' in u['name'].lower() or (u['handle'] or '').lower().find('mark may') >= 0 for u in j['users']), body[:300])
    st, _, body = get('/v1/users/Mark%20May', allq)
    check('/v1/users/<name>: one user, any case, URL encoded', st == 200 and json.loads(body)['name'].lower() == 'mark may' and get('/v1/users/mark%20MAY', allq)[0] == 200, (st, body))
    check('/v1/users/<name> for nobody: 404', get('/v1/users/No%20Such%20Person', allq)[0] == 404)
    alln = json.loads(get('/v1/users?limit=1000', allq)[2])
    withdel = json.loads(get('/v1/users?limit=1000&deleted=1', allq)[2])
    check('deleted users are hidden unless asked for (?deleted=1)', all(not u['deleted'] for u in alln['users']) and withdel['count'] >= alln['count'], (alln['count'], withdel['count']))
    check('every data endpoint needs its scope: a token with only "status" gets 403 on all of them', all(get(pth, tool('add', 'st' + str(i), '-s', 'status', '-q').stdout.strip())[0] == 403 for i, pth in enumerate(['/v1/nodes', '/v1/events', '/v1/mailer', '/v1/stats', '/v1/calls', '/v1/areas/messages', '/v1/areas/files', '/v1/areas/files/1', '/v1/users', '/v1/users/x'])))
    # TLS
    st, head, body = get('/v1/status', tok, port=24862, tls=True)
    check('TLS: the same answer over HTTPS (certificate and name checked)', st == 200 and 'bbs' in json.loads(body), (st, head, body))
    check('the log says api-tls for the label / TLS ready', 'native TLS ready' in open(work + '/listen.log').read())
    st, head, body = http('GET /v1/status HTTP/1.1\r\n\r\n', port=24862, secs=3)
    check('plain HTTP on a TLS port gets no answer', st == 0)
    # the login guard: 3 failed tokens within 60 s block the address (mklisten again with "fails": 3)
    lst.terminate(); lst.wait()
    cfg['loginguard'] = {'fails': 3, 'window': 60, 'block': 5, 'allow': []}
    json.dump(cfg, open(work + '/listen.json', 'w'))
    lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)
    time.sleep(2)
    for i in range(3):
        get('/v1/status', 'mkapi_' + 'B' * 43)
        time.sleep(0.4)
    time.sleep(1.5)
    st, head, body = get('/v1/status', tok)
    log = open(work + '/listen.log').read()
    check('the login guard counts bad tokens: the address is blocked after 3 (even for a good token), said in the log', st != 200 and 'is blocked' in log and 'refused 127.0.0.1: blocked after failed log-ons' in log, (st, log[-500:]))
    time.sleep(6)
    st, head, body = get('/v1/status', tok)
    check('... and can use the API again when the block is over', st == 200, (st, log[-200:]))
    # rotate / revoke work without a restart
    new = tool('rotate', 'dash', '-q').stdout.strip()
    st1, _, _ = get('/v1/status', tok)
    st2, _, _ = get('/v1/status', new)
    check('rotate: the old token stops, the new one works (no restart)', st1 == 401 and st2 == 200, (st1, st2))
    tool('revoke', 'dash')
    time.sleep(1)
    st, _, _ = get('/v1/status', new)
    check('revoke: the token stops at once', st == 401, st)
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
