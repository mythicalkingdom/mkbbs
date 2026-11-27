#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The Mailer screen of the sysop monitor: mklisten runs the real mkbink (mailer on in a copy of the sample BBS, a link to a
second mkbink), mkmon on the sysop port shows it.  Needs the mkbink project built next to this one.
usage: mailmontest.py <work dir>"""
import json, os, re, shutil, signal, socket, subprocess, sys, tempfile, time

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
mkbink = os.environ.get('MKBINK', os.path.join(repo, '..', 'mkbink', 'build', 'mkbink'))
sample = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not (os.path.exists(mkbink) and os.path.isdir(sample)):
    print('skip: the real mkbink or the sample BBS is not there'); sys.exit(0)
big = int(os.environ.get('BIGMB', '300'))
work = tempfile.mkdtemp(prefix='mm', dir='/tmp')
fails = 0
procs = []


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mailer screen: ' + name)
    if not ok:
        fails += 1


def wait(cond, secs=15):
    end = time.time() + secs
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.1)
    return cond()


IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240


class Term:
    """a telnet client with an 80x25 screen"""

    def __init__(self, port, ttype=None):
        self.s = socket.create_connection(('127.0.0.1', port))
        self.s.settimeout(0.05)
        self.ttype = ttype
        self.raw = b''          # text received (telnet commands taken out)
        self.pend = b''
        self.utf8 = ttype is not None and ttype.upper().startswith('XTERM')
        self.rows = [[' '] * 80 for _ in range(25)]
        self.cy = self.cx = 0
        self.seq = b''

    def pump(self):
        try:
            d = self.s.recv(65536)
        except socket.timeout:
            return
        if not d:
            return
        b = self.pend + d
        self.pend = b''
        out = bytearray()
        i = 0
        while i < len(b):
            c = b[i]
            if c != IAC:
                out.append(c); i += 1; continue
            if i + 1 >= len(b):
                self.pend = b[i:]; break
            v = b[i + 1]
            if v == IAC:
                out.append(IAC); i += 2
            elif v in (DO, DONT, WILL, WONT):
                if i + 2 >= len(b):
                    self.pend = b[i:]; break
                o = b[i + 2]
                if v == DO:
                    self.s.sendall(bytes([IAC, WILL if (o == 24 and self.ttype) else WONT, o]))
                elif v == WILL:
                    self.s.sendall(bytes([IAC, DO if o in (1, 3) else DONT, o]))
                i += 3
            elif v == SB:
                j = b.find(bytes([IAC, SE]), i)
                if j < 0:
                    self.pend = b[i:]; break
                if b[i + 2:i + 4] == bytes([24, 1]) and self.ttype:
                    self.s.sendall(bytes([IAC, SB, 24, 0]) + self.ttype.encode() + bytes([IAC, SE]))
                i = j + 2
            else:
                i += 2
        self.raw += bytes(out)
        self.feed(bytes(out))

    def feed(self, data):
        s = (self.seq + data)
        self.seq = b''
        text = s.decode('utf-8', 'replace') if self.utf8 else s.decode('cp437', 'replace')
        i = 0
        while i < len(text):
            c = text[i]
            if c == '\x1b':
                m = re.match(r'\x1b\[([0-9;?]*)([A-Za-z])', text[i:])
                if not m:
                    if len(text) - i < 12:
                        self.seq = text[i:].encode('utf-8' if self.utf8 else 'cp437')
                        return
                    i += 1; continue
                p, f = m.group(1), m.group(2)
                a = [int(x) if x.isdigit() else 0 for x in p.replace('?', '').split(';')] if p else []
                if f in 'Hf':
                    self.cy = min(24, (a[0] if a and a[0] else 1) - 1); self.cx = min(79, (a[1] if len(a) > 1 and a[1] else 1) - 1)
                elif f == 'J' and a and a[0] == 2:
                    self.rows = [[' '] * 80 for _ in range(25)]
                i += m.end(); continue
            if c == '\r':
                self.cx = 0
            elif c == '\n':
                self.cy = min(24, self.cy + 1)
            elif c >= ' ':
                if self.cx < 80:
                    self.rows[self.cy][self.cx] = c
                    self.cx += 1
            i += 1

    def screen(self):
        return '\n'.join(''.join(r).rstrip() for r in self.rows)

    def until(self, cond, secs=10):
        return wait(lambda: (self.pump(), cond())[1], secs)

    def send(self, t):
        self.s.sendall(t.encode('latin-1'))


try:
    real = os.path.join(work, 'real')
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch
    shutil.copytree(cfgpatch.snapshot(sample), real, ignore=lambda d, names: [n for n in names if n.lower().startswith(('mkbink.conf', 'mailer.mk'))])
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(real)
    # two small nodelists in a private directory: Fidonet's zone 1 and a network with a zone of its own (77), both with binkp hosts
    nl = os.path.join(work, 'nl'); os.makedirs(nl)
    open(os.path.join(nl, 'nodelist.322'), 'w', newline='').write(
        ';A Test Nodelist -- Day number 322 : 12345\r\nZone,1,Fidonet,Somewhere,Zed,-Unpublished-,300,CM,XA,IBN\r\n'
        'Host,110,Test_Net,Town,Hoster,-Unpublished-,300,CM\r\nPvt,201,Quiet,Town,Quiet,-Unpublished-,300,CM\r\n'
        'Hub,202,Hubby,Town,Hubby,-Unpublished-,300,CM,IBN:127.0.0.1:24851\r\n\x1a')
    open(os.path.join(nl, 'fsxlist.322'), 'w', newline='').write(
        ';A Other Nodelist -- Day number 322 : 54321\r\nZone,77,Other_Net,Elsewhere,Zed,-Unpublished-,300,CM\r\n'
        'Host,7701,Other_Host,Town,Hoster,-Unpublished-,300,CM\r\nNode,1,Far,Town,Faraway,-Unpublished-,300,CM,IBN:far.example.org:24860\r\n\x1a')
    srcnl = os.path.join(repo, 'bbs', 'bbsd', 'nodelist')
    cfgpatch.patch(os.path.join(real, 'config.mk'), (repo + '/bbs/').encode(), lambda x: (nl + '/').encode() if x == (srcnl + '/').encode() else x)
    r = subprocess.run([os.path.join(repo, 'build', 'mknodeidx'), 'nodelist.322', 'fsxlist.322'], env={'PATH': os.environ['PATH'], 'MK': real},
                       capture_output=True, text=True)
    check('mknodeidx built an index of two nodelists (zones 1 and 77)', r.returncode == 0)
    ec = os.path.join(real, 'echocfg.mk')
    d = bytearray(open(ec, 'rb').read())
    for off, text in ((0, 'files/in'), (51, 'mail/out')):
        d[off:off + 51] = bytes([len(text)]) + text.encode() + bytes(50 - len(text))
    open(ec, 'wb').write(d)
    h = bytearray(184 + 64 * 178 + 1024)
    h[0:2] = (1).to_bytes(2, 'little'); h[2:4] = (3).to_bytes(2, 'little'); h[4:6] = (24841).to_bytes(2, 'little')
    h[47] = 8; h[48] = 1
    for off, v in ((49, 120), (51, 60), (53, 3600), (55, 2)):
        h[off:off + 2] = v.to_bytes(2, 'little')
    L = 184                                           # link 1: 1:110/100 "Hub B" at 127.0.0.1:24842, password secret
    for off, v in ((0, 1), (2, 110), (4, 100)):
        h[L + off:L + off + 2] = v.to_bytes(2, 'little')

    def pstr(off, text, size):
        h[L + off:L + off + size] = bytes([len(text)]) + text.encode() + bytes(size - 1 - len(text))
    pstr(8, 'Hub B', 31)
    pstr(39, '127.0.0.1', 61)
    h[L + 100:L + 102] = (24842).to_bytes(2, 'little')
    pstr(102, 'secret', 31)
    open(os.path.join(real, 'mailer.mk'), 'wb').write(h)

    # the other mailer: 1:110/100, answers 1:110/290
    bdir = os.path.join(work, 'b')
    os.makedirs(bdir + '/in'); os.makedirs(bdir + '/out')
    open(bdir + '/b.conf', 'w').write('version 1\naddress 1:110/100\nsysname Node B\nsysop Bee\ninbound %s/in\nbso %s/out\nzone 1\nport 24842\n'
                                      'bind 127.0.0.1\nlink 1:110/290\n  password secret\n  answer-only yes\n' % (bdir, bdir))
    os.chmod(bdir + '/b.conf', 0o600)
    pb = subprocess.Popen([mkbink, 'run', '-f', bdir + '/b.conf'], stdout=open(bdir + '/log', 'w'), stderr=subprocess.STDOUT)
    procs.append(pb)

    run = tempfile.mkdtemp(prefix='r', dir='/tmp')
    cfg = {'mk': os.path.join(repo, 'build', 'fakemk'), 'mkmon': os.path.join(repo, 'build', 'mkmon'),
           'rundir': run, 'logfile': os.path.join(work, 'listen.log'), 'workdir': work,
           'mailer': {'config': real, 'mkbink': mkbink, 'mkbinkcfg': os.path.join(repo, 'build', 'mkbinkcfg'), 'interval': 1, 'restart': 1},
           'ports': [{'port': 24832, 'type': 'telnet', 'nodes': '1-2', 'bind': '127.0.0.1', 'config': real},
                     {'port': 24831, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'sesame', 'config': real}]}
    json.dump(cfg, open(os.path.join(work, 'l.json'), 'w'))
    lst = subprocess.Popen([os.path.join(repo, 'build', 'mklisten'), '-c', os.path.join(work, 'l.json')], stdout=subprocess.DEVNULL)
    procs.append(lst)
    check('mklisten started the mailer with a control socket in the run directory',
          wait(lambda: os.path.exists(run + '/mailer.sock'), 15))

    def login(ttype):
        t = Term(24831, ttype)
        t.until(lambda: b'assword' in t.raw)
        t.send('sesame\r')
        t.until(lambda: 'MK sysop monitor' in t.screen())
        return t

    # ---- an ANSI-BBS terminal (CP437 bytes)
    t = login(None)
    check('the node list offers M for the mailer', 'M mailer' in t.screen())
    mark = len(t.raw)
    t.send('m')
    check('the Mailer screen: title with version and our address', t.until(lambda: 'MkBink' in t.screen() and '1:110/290' in t.screen()))
    sc = t.screen()
    for word in ('Session', 'Statistics', 'Transfer', 'Links', 'Events', 'Up since', 'We called', 'No session'):
        check('screen has "%s"' % word, word in sc)
    check('the link is listed: address, name, state idle', t.until(lambda: re.search(r'1:110/100\s+Hub B\s+idle', t.screen()) is not None))
    check('the key line shows the commands', 'oll' in sc.splitlines()[-1] and 'uit' in sc.splitlines()[-1])
    check('box characters go out as CP437 bytes to a terminal that is not UTF-8', b'\xda' in t.raw and b'\xc4' in t.raw and b'\xe2\x94' not in t.raw)
    sgrs = set(re.findall(rb'\x1b\[([0-9;]*)m', t.raw[mark:]))
    check('every colour sets the foreground and the background (no default black assumed): %d kinds' % len(sgrs),
          all(re.fullmatch(rb'0;(1;)?3[0-7];4[0-7]', x) for x in sgrs))
    check('the event log shows what the mailer did', 'Mailer running' in sc or 'Listening' in sc)

    # ---- hold, mail, poll now
    t.send('h')
    check('H holds the link: state held', t.until(lambda: re.search(r'1:110/100\s+Hub B\s+held', t.screen()) is not None))
    big_f = os.path.join(work, 'big.bin')
    chunk = os.urandom(1024 * 1024)
    with open(big_f, 'wb') as f:
        for _ in range(big):
            f.write(chunk)
    subprocess.run([mkbink, 'queue', '-O', real + '/mail/out', '-Z', '1', '-t', '1:110/100', '-x', big_f], check=True, capture_output=True)
    ok = t.until(lambda: re.search(r'1 / %d M' % big, t.screen()) is not None, 10)
    if not ok and os.environ.get('DBG'):
        print(t.screen())
    check('mail waiting for the held link is shown (1 / %d M)' % big, ok)
    t.send('p')
    seen = {'bar': False, 'pct': False, 'sess': False, 'rate': False}

    def watch():
        sc = t.screen()
        if 'IN SESSION' in sc:
            if not seen['sess'] and os.environ.get('DBG'): print(sc)
            seen['sess'] = True
        if 'Send' in sc and 'big.bin' in sc and ('█' in sc or '\xdb' in sc): seen['bar'] = True
        if re.search(r'\d+% ', sc) and 'big.bin' in sc: seen['pct'] = True
        if re.search(r'[KM]/s', sc): seen['rate'] = True
        return re.search(r'We called\s+1 \(1 ok', sc) is not None
    ok = t.until(watch, 90)
    if not ok and os.environ.get('DBG'):
        print(t.screen()); print(open(os.path.join(work, 'listen.log')).read()[-1500:])
    check('P calls the held link at once: the screen shows the session, the file with a bar and percentage', seen['sess'] and seen['bar'] and seen['pct'])
    check('... and a transfer rate', seen['rate'])
    check('... and afterwards the statistics count the call (1 ok)', ok)
    check('the file arrived at the other mailer', os.path.exists(bdir + '/in/big.bin') and os.path.getsize(bdir + '/in/big.bin') == big * 1024 * 1024)
    t.send('h')
    check('H again releases the link', t.until(lambda: re.search(r'1:110/100\s+Hub B\s+(idle|waiting)', t.screen()) is not None))
    t.send('a')
    check('A with no mail waiting says so', t.until(lambda: 'no link has mail waiting' in t.screen()))
    t.send('f')
    check('F opens the request dialog with the chosen link filled in', t.until(lambda: 'Ask for files' in t.screen() and 'System address' in t.screen() and '1:110/100' in t.screen()))
    t.send('\x1b')
    check('Esc closes it without asking', t.until(lambda: 'Ask for files' not in t.screen()))
    t.send('f')
    t.until(lambda: 'Ask for files' in t.screen())
    t.send('\r\r\r')
    t.send('one.zip !pw two.zip +599634000')
    t.send('\r\r')
    check('F then Enter through the fields sends REQ: queued and called', t.until(lambda: 'calling 1:110/100' in t.screen() or 'queued' in t.screen(), 10))
    check('... the dialog is gone', t.until(lambda: 'Ask for files' not in t.screen()))
    def ask(addr, host, files='x.zip'):
        t.send('f')
        t.until(lambda: 'Ask for files' in t.screen())
        for _ in range(20):
            t.send('\x7f')                 # clear the address, then type
        t.send(addr + '\r' + host + '\r\r' + files + '\r\r')
    ask('77:7701/1', '')
    check('F with no host for a system in the second nodelist (zone 77): the host comes from the nodelist',
          t.until(lambda: 'far.example.org:24860' in t.screen(), 10))
    ask('1:110/202', '')
    check('... and one of the first nodelist (zone 1)', t.until(lambda: '127.0.0.1:24851' in t.screen(), 10))
    ask('1:110/201', '')
    check('a system with no IBN flag: refused, the dialog stays open',
          t.until(lambda: 'No host for 1:110/201' in t.screen() and 'Ask for files' in t.screen(), 10))
    t.send('\x1b')
    t.until(lambda: 'Ask for files' not in t.screen())
    time.sleep(0.3)
    ask('1:110/999', '')
    ok = t.until(lambda: 'not in the nodelist' in t.screen(), 10)
    if not ok: print(t.screen())
    check('a system that is not in the nodelist: refused, with the reason', ok)
    t.send('\x1b')
    t.until(lambda: 'Ask for files' not in t.screen())
    t.send('q')
    check('Q goes back to the node list', t.until(lambda: 'MK sysop monitor' in t.screen() and 'MkBink' not in t.screen()))
    t.send('q')
    t.s.close()

    # ---- a UTF-8 terminal gets UTF-8 box characters
    t = login('XTERM')
    t.send('m')
    check('an XTERM terminal gets UTF-8 box characters and the same screen', t.until(lambda: 'MkBink' in t.screen()) and
          '┌'.encode() in t.raw and b'\xda' not in t.raw)
    check('... the box is drawn (corner characters on the screen)', '┌' in t.screen())
    t.s.close()

    # ---- the mailer is not running: a message, not a hang
    lst.send_signal(signal.SIGTERM)
    lst.wait(20)
finally:
    for p in procs:
        if p.poll() is None:
            p.kill()
    shutil.rmtree(work, ignore_errors=True)

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
