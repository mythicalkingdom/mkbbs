#!/usr/bin/env python3
"""QWK packets over the JSON API (QWK-API-PLAN.md, phase 2): the node's settings, the packet (a waiting packet is sent again), the acknowledgement that moves the last-read pointers only when they are still
where they were (compare and set), the repeat of an acknowledgement, the expiry, ?rebuild=1, the size limit that leaves the rest for the next packet, the lock, and who may ask (a token with the user of a QWK
node, the scope qwk).  Real mkapi and mklisten on a private copy of the sample BBS.   usage: qwkapitest.py <work dir>"""
import hashlib, io, json, os, re, shutil, socket, subprocess, sys, time, zipfile, fcntl
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
need = ('mkapi', 'netsetup', 'postmsg', 'setlr', 'tosssetup', 'tossmake')
if not os.path.isdir(src) or not all(os.path.exists(build + '/' + n) for n in need) or not shutil.which('zip'):
    print('skip: no sample BBS, tools or zip'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'qwk api: ' + name + ('' if ok else '  ' + str(info)[-600:]))
    if not ok:
        fails += 1


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
NODE = 'Chuck Ebenschweiger'
AREA = '6'
r = subprocess.run([build + '/netsetup', NODE, AREA], env=dict(env, NETSEC='110'), capture_output=True, text=True)       # level 110: it may post in the areas
check('a QWK node is made (flag, ZIP, area 6 in its offline mail)', 'ok' in r.stdout, r.stdout + r.stderr)


def post(subject, *lines):
    subprocess.run([build + '/postmsg', AREA, 'Node Poster', 'All', subject] + list(lines), env=env, capture_output=True, text=True)


def lr():
    r = subprocess.run([build + '/setlr', NODE, AREA], env=env, capture_output=True, text=True)
    return int(re.search(r'was (\d+)', r.stdout).group(1))


def setlr(n):
    subprocess.run([build + '/setlr', NODE, AREA, str(n)], env=env, capture_output=True, text=True)


def tool(*a):
    return subprocess.run([build + '/mkapitoken', '-c', ra] + list(a), capture_output=True, text=True)


tok = tool('add', 'node5', '-s', 'qwk', '-u', NODE, '-q').stdout.strip()
tok2 = tool('add', 'other', '-s', 'qwk', '-u', 'Mark May', '-q').stdout.strip()
tokst = tool('add', 'st', '-s', 'status', '-q').stdout.strip()
cfg = {'mk': build + '/mk', 'mkapi': build + '/mkapi', 'rundir': tmp + '/run', 'logfile': work + '/listen.log', 'workdir': ra, 'nodes': '1-4',
       'loginguard': {'fails': 500, 'window': 60, 'block': 5, 'allow': []},
       'ports': [{'port': 24881, 'type': 'api', 'config': ra}]}
json.dump(cfg, open(work + '/listen.json', 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)


def req(method, path, token=tok):
    for _ in range(50):
        try:
            s = socket.create_connection(('127.0.0.1', 24881)); break
        except OSError:
            time.sleep(0.1)
    h = '%s %s HTTP/1.1\r\nHost: x\r\n' % (method, path)
    if token:
        h += 'Authorization: Bearer %s\r\n' % token
    s.sendall((h + '\r\n').encode())
    s.settimeout(30)
    b = b''
    try:
        while True:
            x = s.recv(65536)
            if not x:
                break
            b += x
    except (socket.timeout, ConnectionError):
        pass
    s.close()
    head, _, body = b.partition(b'\r\n\r\n')
    st = int(head.split()[1]) if head.startswith(b'HTTP/1.1') else 0
    hd = {}
    for l in head.decode('latin-1').split('\r\n')[1:]:
        if ':' in l:
            k, v = l.split(':', 1)
            hd[k.strip().lower()] = v.strip()
    return st, hd, body


def zipnames(body):
    return zipfile.ZipFile(io.BytesIO(body)).namelist()


def zipdat(body):
    z = zipfile.ZipFile(io.BytesIO(body))
    for n in z.namelist():
        if n.lower() == 'messages.dat':
            return z.read(n)
    return b''


try:
    time.sleep(2)
    st, h, body = req('GET', '/v1/qwk')
    j = json.loads(body) if st == 200 else {}
    check('GET /v1/qwk: the node, the BBS id, its conferences, the limits, no waiting packet', st == 200 and j['node'] == NODE and j['bbs_id'] and any(c['conference'] == int(AREA) for c in j['conferences'])
          and j['limits']['max_packet'] == 10485760 and j['limits']['keep_days'] == 7 and j['waiting'] is None, (st, body[:500]))
    st, _, body = req('GET', '/v1/qwk', tok2)
    check('a token of a user who is not a QWK node: 403', st == 403 and 'QWK node' in body.decode(), (st, body))
    st, _, body = req('GET', '/v1/qwk', tokst)
    check('a token without the scope qwk: 403', st == 403, (st, body))
    st, _, body = req('GET', '/v1/qwk', None)
    check('no token: 401', st == 401)
    # nothing new: set the pointer past what is there
    top = lr()
    st, h, body = req('GET', '/v1/qwk/packet')
    if st == 200:                               # the area has messages the node has not had: take them and acknowledge, to start clean
        req('POST', '/v1/qwk/packet/%s/ack' % h['x-qwk-packet'])
    st, h, body = req('GET', '/v1/qwk/packet')
    check('nothing new: 204 and X-QWK-Packet: none, no body', st == 204 and h.get('x-qwk-packet') == 'none' and body == b'', (st, h, body))
    base = lr()
    post('First one', 'written on the node', 'second line')
    post('Second one', 'another message for the packet')
    st, h, body = req('GET', '/v1/qwk/packet')
    pid = h.get('x-qwk-packet', '')
    check('GET /v1/qwk/packet: 200, application/zip, the id, 2 messages, the SHA-256 of the body, the file name <BBSID>.QWK', st == 200 and h['content-type'] == 'application/zip' and re.fullmatch(r'[0-9a-f]{12}', pid) and h['x-qwk-messages'] == '2'
          and h['x-qwk-sha256'] == hashlib.sha256(body).hexdigest() and h['content-disposition'].endswith('.QWK"') and int(h['content-length']) == len(body), (st, h))
    names = zipnames(body)
    dat = zipdat(body)
    check('the packet is a QWK packet: messages.dat with both messages, control.dat, door.id and the index', 'messages.dat' in names and b'written on the node' in dat and b'another message for the packet' in dat and 'control.dat' in names and 'door.id' in names and any(n.endswith('.ndx') for n in names), (names, dat[:200]))
    check('nothing was marked as sent: the last-read pointer is where it was', lr() == base, (lr(), base))
    st2, h2, body2 = req('GET', '/v1/qwk/packet')
    check('without an acknowledgement the same packet is sent again (same id, same bytes)', st2 == 200 and h2['x-qwk-packet'] == pid and body2 == body, (st2, h2))
    st3, h3, body3 = req('HEAD', '/v1/qwk/packet')
    check('HEAD: the headers of the waiting packet, no body', st3 == 200 and h3['x-qwk-packet'] == pid and body3 == b'' and int(h3['content-length']) == len(body), (st3, h3))
    st, _, bj = req('GET', '/v1/qwk')
    j = json.loads(bj)
    check('/v1/qwk says a packet is waiting (id, messages, bytes)', j['waiting'] and j['waiting']['id'] == pid and j['waiting']['messages'] == 2 and j['waiting']['bytes'] == len(body), bj[:400])
    st, _, bj = req('POST', '/v1/qwk/packet/%s/ack' % ('0' * 12))
    check('the acknowledgement of an id that was never there: 404', st == 404, (st, bj))
    st, _, bj = req('POST', '/v1/qwk/packet/%s/ack' % pid)
    j = json.loads(bj)
    check('POST .../ack: 200, acknowledged, 2 messages; the pointer has moved to the last message of the packet', st == 200 and j['acknowledged'] is True and j['messages'] == 2 and lr() > base, (st, bj, lr(), base))
    after = lr()
    st, h, body = req('GET', '/v1/qwk/packet')
    check('after the acknowledgement there is nothing new: 204', st == 204, (st, h))
    st, _, bj = req('POST', '/v1/qwk/packet/%s/ack' % pid)
    j = json.loads(bj)
    check('the same acknowledgement again (a lost answer): 200 with already: true, nothing moved twice', st == 200 and j.get('already') is True and lr() == after, (st, bj))
    # compare and set: the node's pointer changes between the packet and the acknowledgement
    post('Third one', 'for the conflict')
    st, h, body = req('GET', '/v1/qwk/packet')
    pid2 = h['x-qwk-packet']
    check('a new packet for a new message', st == 200 and h['x-qwk-messages'] == '1' and pid2 != pid, (st, h))
    setlr(after - 1)                             # the node fetched by another way meanwhile
    moved = lr()
    st, _, bj = req('POST', '/v1/qwk/packet/%s/ack' % pid2)
    check('the pointer changed since the packet was made: 409, nothing moves (a pointer never goes back or on by the old packet)', st == 409 and 'changed' in bj.decode() and lr() == moved, (st, bj, lr(), moved))
    st, _, bj = req('POST', '/v1/qwk/packet/%s/ack' % pid2)
    check('... and the dropped packet stays 409 for a repeat', st == 409, (st, bj))
    st, h, body = req('GET', '/v1/qwk/packet')
    check('the next packet is built anew from the pointer as it is now', st == 200 and h['x-qwk-packet'] != pid2 and int(h['x-qwk-messages']) >= 1, (st, h))
    # rebuild
    pid3 = h['x-qwk-packet']
    post('Fourth one', 'arrived after the packet')
    st, h, body = req('GET', '/v1/qwk/packet')
    same = h['x-qwk-packet'] == pid3
    st, h4, body4 = req('GET', '/v1/qwk/packet?rebuild=1')
    check('a waiting packet stays as it is; ?rebuild=1 throws it away and builds a new one with the message that came since', same and st == 200 and h4['x-qwk-packet'] != pid3 and int(h4['x-qwk-messages']) == int(h['x-qwk-messages']) + 1, (same, h, h4))
    req('POST', '/v1/qwk/packet/%s/ack' % h4['x-qwk-packet'])
    # expiry
    post('Fifth one', 'for the expiry')
    st, h, body = req('GET', '/v1/qwk/packet')
    pid5 = h['x-qwk-packet']
    sf = ra + '/qwkapi/' + re.sub(r'[^a-z0-9]', '_', NODE.lower()) + '/waiting.state'
    lines = open(sf).read().split('\n')
    lines = ['created 1000' if l.startswith('created ') else l for l in lines]
    open(sf, 'w').write('\n'.join(lines))
    st, h, body = req('GET', '/v1/qwk/packet')
    check('a waiting packet that is older than keep_days is dropped: the next request builds a new one', st == 200 and h['x-qwk-packet'] != pid5, (st, h))
    st, _, bj = req('POST', '/v1/qwk/packet/%s/ack' % pid5)
    check('the acknowledgement of the expired one: 410', st == 410, (st, bj))
    req('POST', '/v1/qwk/packet/%s/ack' % h['x-qwk-packet'])
    # the lock
    lockf = os.path.dirname(sf) + '/.lock'
    fd = os.open(lockf, os.O_RDWR | os.O_CREAT, 0o600)
    fcntl.flock(fd, fcntl.LOCK_EX)
    st, _, bj = req('GET', '/v1/qwk/packet')
    st2, _, _ = req('POST', '/v1/qwk/packet/%s/ack' % pid5)
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)
    check('another request of the node is running: 423 (the packet and the acknowledgement)', st == 423 and st2 == 423, (st, st2))
    # the size limit: what does not fit waits for the next packet
    tf = json.load(open(ra + '/apitokens.json'))
    tf['qwk'] = {'max_packet': 2200}
    json.dump(tf, open(ra + '/apitokens.json', 'w'))
    import random
    random.seed(5)
    for i in range(8):
        post('Big %d' % i, ''.join(random.choice('abcdefghijklmnopqrstuvwxyz0123456789') for _ in range(900)))
    got = []
    sizes = []
    for _ in range(10):
        st, h, body = req('GET', '/v1/qwk/packet')
        if st == 204:
            break
        got.append(int(h['x-qwk-messages']))
        sizes.append(len(body))
        req('POST', '/v1/qwk/packet/%s/ack' % h['x-qwk-packet'])
    check('the size limit (2200 bytes): the 8 messages come in several packets, none over the limit, each message once', len(got) >= 2 and sum(got) == 8 and max(sizes) <= 2200, (got, sizes))
    log = open(work + '/listen.log').read()
    check('the log has the acknowledgements and the packets with their bytes', re.search(r'api: node5 127\.0\.0\.1 POST /v1/qwk/packet/[0-9a-f]{12}/ack 200', log) and re.search(r'GET /v1/qwk/packet 200 out=\d+', log) and 'mkapi_' not in log, log[-500:])
    spool = [f for f in os.listdir(ra + '/tmp')]
    check('no temporary directory of a packet is left', spool == [] or all(not os.path.isdir(ra + '/tmp/' + f) for f in spool), spool)
    # ---- the example scripts of contrib/qwk (curl): fetch, check, acknowledge
    board_name = json.loads(req('GET', '/v1/qwk')[2])['bbs_id']
    if shutil.which('curl') and shutil.which('sha256sum'):
        fetch = repo + '/contrib/qwk/qwk-http-fetch.sh'
        ackc = repo + '/contrib/qwk/qwk-http-ack.sh'
        post('Script one', 'for the curl script')
        out = work + '/curlout'
        r = subprocess.run([fetch, 'http://127.0.0.1:24881', tok, out], capture_output=True, text=True)
        pid_s = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ''
        check('contrib/qwk/qwk-http-fetch.sh: the packet is in the directory under its name, the id on the last line, exit 0', r.returncode == 0 and re.fullmatch(r'[0-9a-f]{12}', pid_s) and os.path.exists(out + '/' + board_name + '.QWK') and zipfile.is_zipfile(out + '/' + board_name + '.QWK'), (r.returncode, r.stdout, r.stderr))
        before_ack = lr()
        r = subprocess.run([ackc, 'http://127.0.0.1:24881', tok, pid_s], capture_output=True, text=True)
        check('qwk-http-ack.sh: the hub is told, the pointer moves', r.returncode == 0 and '"acknowledged"' in r.stdout and lr() > before_ack, (r.returncode, r.stdout, r.stderr))
        r = subprocess.run([fetch, 'http://127.0.0.1:24881', tok, out], capture_output=True, text=True)
        check('the script again: nothing new, exit 3', r.returncode == 3, (r.returncode, r.stderr))
        r = subprocess.run([fetch, 'http://127.0.0.1:24881', 'mkapi_' + 'B' * 43, out], capture_output=True, text=True)
        check('a wrong token: exit 1 with the hub\'s answer', r.returncode == 1 and '401' in r.stderr, (r.returncode, r.stderr))
    # ---- phase 3: the reply packet
    tokr = tool('add', 'nodereply', '-s', 'qwk,qwk:reply', '-u', NODE, '-q').stdout.strip()
    tokm = tool('add', 'msgs', '-s', 'messages', '-q').stdout.strip()
    tf = json.load(open(ra + '/apitokens.json'))
    tf['qwk'] = {'max_packet': 10485760, 'max_reply': 4000}
    json.dump(tf, open(ra + '/apitokens.json', 'w'))
    board = json.loads(req('GET', '/v1/qwk')[2])['bbs_id']

    def put(body, token=tokr, ctype='application/zip', port=24881):
        for _ in range(50):
            try:
                sk = socket.create_connection(('127.0.0.1', port)); break
            except OSError:
                time.sleep(0.1)
        h = 'PUT /v1/qwk/reply HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer %s\r\nContent-Length: %d\r\n' % (token, len(body))
        if ctype:
            h += 'Content-Type: %s\r\n' % ctype
        sk.sendall((h + '\r\n').encode() + body)
        sk.settimeout(30)
        b = b''
        try:
            while True:
                x = sk.recv(65536)
                if not x:
                    break
                b += x
        except (socket.timeout, ConnectionError):
            pass
        sk.close()
        head, _, rb = b.partition(b'\r\n\r\n')
        return (int(head.split()[1]) if head.startswith(b'HTTP/1.1') else 0), rb

    def make_rep(tag, kind='reply', msgname=None, conf=AREA):
        base = work + '/rep_' + tag
        if kind == 'reply':
            subprocess.run([build + '/qwkmsgtest', 'reply', base + '.msg', conf, board, tag], check=True, capture_output=True)
        else:
            subprocess.run([build + '/qwkmsgtest', 'control', base + '.msg', board] + kind.split('|'), check=True, capture_output=True)
        bio = io.BytesIO()
        with zipfile.ZipFile(bio, 'w') as z:
            z.write(base + '.msg', msgname or (board.upper() + '.MSG'))
        return bio.getvalue()

    def count_replies():
        j = json.loads(req('GET', '/v1/messages/%s?q=reply&limit=500' % AREA, tokm)[2])
        return len(j.get('messages', []))

    n0 = count_replies()
    rep1 = make_rep('one')
    st, rb = put(rep1)
    j = json.loads(rb) if st == 200 else {}
    a6 = [x for x in j.get('areas', []) if x['conference'] == int(AREA)]
    a999 = [x for x in j.get('areas', []) if x['conference'] == 999]
    check('PUT /v1/qwk/reply: 200 imported; two messages posted in conference 6 (the area), the one for a conference that is not there is refused with its reason', st == 200 and j['status'] == 'imported' and j['posted'] == 2 and a6 and a6[0]['posted'] == 2
          and a6[0]['area'] and a999 and a999[0]['refused'] == 1 and 'may not post' in a999[0]['reason'] and j['refused'] == 1, (st, rb[:600]))
    check('the two messages are in the area (read through the API)', count_replies() == n0 + 2, (count_replies(), n0))
    st, rb = put(rep1)
    j = json.loads(rb) if st == 200 else {}
    check('the same packet again: 200 duplicate, nothing posted twice', st == 200 and j['status'] == 'duplicate' and j['posted'] == 2 and count_replies() == n0 + 2, (st, rb, count_replies()))
    st, rb = put(b'x' * 4001)
    check('a body over max_reply (4000): 413', st == 413, (st, rb))
    st, rb = put(b'this is not a zip file at all')
    check('something that is not a ZIP: 415', st == 415 and b'ZIP' in rb, (st, rb))
    st, rb = put(rep1, ctype='text/plain')
    check('another Content-Type: 415', st == 415, (st, rb))
    st, rb = put(make_rep('other', msgname='OTHERID.MSG'))
    check('a packet for another BBS id: 400, nothing posted', st == 400 and b'not a reply packet' in rb and count_replies() == n0 + 2, (st, rb))
    st, rb = put(make_rep('noscope'), token=tok)
    check('a token with qwk but without qwk:reply: 403', st == 403, (st, rb))
    # the control messages of a node
    st, rb = put(make_rep('ctl', kind='%s:DROP %s' % (AREA, AREA)))
    j = json.loads(rb) if st == 200 else {}
    st2, _, ib = req('GET', '/v1/qwk')
    check('a control message (DROP): carried out and reported in "commands"; the node no longer has the conference', st == 200 and any('DROP' in c and 'done' in c for c in j['commands']) and not any(c['conference'] == int(AREA) for c in json.loads(ib)['conferences']), (st, rb[:400], ib[:300]))
    st, rb = put(make_rep('ctl2', kind='%s:ADD %s' % (AREA, AREA)))
    st2, _, ib = req('GET', '/v1/qwk')
    check('ADD gives it back', st == 200 and any(c['conference'] == int(AREA) for c in json.loads(ib)['conferences']), (st, rb[:300]))
    check('no work folder of a reply is left', all(not os.path.isdir(ra + '/tmp/' + f) for f in os.listdir(ra + '/tmp')) and not [f for f in os.listdir(ra + '/tmp') if f.startswith('api')], os.listdir(ra + '/tmp'))
    # a crash between the ledger line and the end: the retry is refused, nothing is posted twice
    cfg2 = dict(cfg, ports=[{'port': 24882, 'type': 'api', 'config': ra, 'env': {'MKAPI_TEST': '1', 'MKAPI_TEST_CRASH': '1'}}], logfile=work + '/listen2.log')
    json.dump(cfg2, open(work + '/listen2.json', 'w'))
    lst2 = subprocess.Popen([build + '/mklisten', '-c', work + '/listen2.json'], stdout=subprocess.DEVNULL)
    time.sleep(2)
    before = count_replies()
    rep3 = make_rep('crash')
    st, rb = put(rep3, port=24882)
    check('a crash after the ledger line (test hook): no answer', st == 0, (st, rb))
    lst2.terminate(); lst2.wait()
    st, rb = put(rep3)
    check('the retry of that packet: 409 (an earlier upload did not finish), nothing was posted by the crash and nothing is posted now', st == 409 and b'did not finish' in rb and count_replies() == before, (st, rb, count_replies(), before))
    led = open(os.path.dirname(sf) + '/reply.ledger').read()
    check('reply.ledger has a line for each packet: done for the ones that went through, started for the one that crashed', led.count(' done ') >= 3 and led.count(' started ') == 1, led)
    log = open(work + '/listen.log').read()
    check('the log line of an upload: token, PUT, the answer, the bytes in', re.search(r'api: nodereply 127\.0\.0\.1 PUT /v1/qwk/reply 200 in=\d+', log) and re.search(r'PUT /v1/qwk/reply 409', log), log[-500:])
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
