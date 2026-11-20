#!/usr/bin/env python3
"""The events screen of the sysop monitor (E in the node list): the events mklisten runs, their state, next time, and R to run
one now (mklisten does it).  mklisten with events and a sysop port, a telnet client with an 80x25 screen.
usage: eventsmontest.py <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, tempfile, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'events screen: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


def wait(cond, secs=15):
    end = time.time() + secs
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.1)
    return cond()


def read(p):
    try:
        return open(p).read()
    except OSError:
        return ''


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



tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(src, ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cj = os.path.join(work, 'cj'); os.makedirs(cj)
env = dict(os.environ, MK=ra)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=dict(env, MKJSON=cj), capture_output=True, input='', text=True)
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
marker = os.path.join(work, 'ran.out')
base = dict(d['events']['Ev']['1'])
d['config']['Events'] = {'1': {'Status': 1, 'Time': '03:30', 'ErrorLvl': 0, 'Days': 127, 'Forced': 0, 'LastRun': ''},
                         '2': {'Status': 2, 'Time': '04:00', 'ErrorLvl': 6, 'Days': 62, 'Forced': 0, 'LastRun': ''},
                         '3': {'Status': 1, 'Time': '05:00', 'ErrorLvl': 0, 'Days': 127, 'Forced': 0, 'LastRun': ''}}
e1 = dict(base); e1.update({'Action': 1, 'Cmd': "/bin/sh -c 'echo ran >> %s'" % marker, 'Flags': 0})
e2 = dict(base); e2.update({'Action': 0})
e3 = dict(base); e3.update({'Action': 4, 'Cmd': '*', 'Flags': 1})
d['events']['Ev'] = {'1': e1, '2': e2, '3': e3}
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'))
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=dict(env, MKJSON=cj), capture_output=True, input='', text=True)

_lt = time.localtime()
today = int(time.mktime((_lt.tm_year, _lt.tm_mon, _lt.tm_mday, 0, 0, 0, 0, 0, -1)))
run = tempfile.mkdtemp(prefix='r', dir='/tmp')
log = os.path.join(work, 'listen.log')
cfg = {'mk': build + '/mk', 'mkmon': build + '/mkmon', 'rundir': run, 'logfile': log, 'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': 24661, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'sesame', 'config': ra}],
       'events': {'config': ra, 'mkevents': build + '/mkevents', 'interval': 1, 'clock': today + 3 * 3600}}
json.dump(cfg, open(work + '/l.json', 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/l.json'], stdout=subprocess.DEVNULL)
try:
    check('mklisten writes events.info for the monitor', wait(lambda: os.path.exists(run + '/events.info'), 15))
    t = Term(24661)
    t.until(lambda: b'assword' in t.raw)
    t.send('sesame\r')
    t.until(lambda: 'MK sysop monitor' in t.screen())
    check('the node list offers E for the events', 'E events' in t.screen(), t.screen())
    t.send('e')
    check('the events screen: title and the columns', t.until(lambda: 'mklisten events' in t.screen() and 'State' in t.screen() and 'Next' in t.screen()), t.screen())
    sc = t.screen()
    check('event 1: 03:30, every day, what it runs, idle, in 30 minutes',
          re.search(r'1\s+03:30\s+SMTWTFS\s+run /bin/sh.*idle\s+in 30m', sc) is not None, sc)
    check('event 2: disabled, 04:00, Monday to Friday, errorlevel 6', re.search(r'2\s+04:00\s+\.MTWTF\.\s+.*\[EL 6\].*disabled', sc) is not None, sc)
    check('event 3: exclusive (!) mailer poll, in 2 hours', re.search(r'3\s+05:00\s+SMTWTFS\s+! poll \*.*idle\s+in 2h00', sc) is not None, sc)
    t.send('\x1b[B')          # down: event 2
    t.send('\x1b[A')          # up: event 1
    t.send('r')
    check('R asks first', t.until(lambda: 'Run event 1 now' in t.screen()), t.screen())
    t.send('n')
    check('N: not run', t.until(lambda: 'Not run' in t.screen()) and read(marker) == '', t.screen())
    t.send('r')
    t.until(lambda: 'Run event 1 now' in t.screen())
    t.send('y')
    check('Y: mklisten is asked, runs the event, and says so in its log',
          wait(lambda: 'ran' in read(marker), 10) and 'run now (asked for by the sysop monitor)' in read(log), (read(marker), read(log)[-300:]))
    check('the screen shows the event with a last run and the result 0', t.until(lambda: re.search(r'1\s+03:3\d.*\d\d:\d\d 0', t.screen()) is not None, 8) or
          re.search(r'03:30.*\d\d:\d\d 0', t.screen()) is not None, t.screen())
    t.send('q')
    check('Q goes back to the node list', t.until(lambda: 'MK sysop monitor' in t.screen() and 'mklisten events' not in t.screen()), t.screen())
finally:
    lst.terminate()
    lst.wait()
    shutil.rmtree(run, ignore_errors=True)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
