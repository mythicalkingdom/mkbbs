#!/usr/bin/env python3
"""CP437 -> UTF-8 in the real mk over telnet: five callers log in to the sample BBS (private copy) and what they
receive is checked: the terminal type they report (or not) and the port's "charset" decide whether the DOS box
characters arrive as CP437 bytes or as UTF-8.   usage: charsetnettest.py <work dir>"""
import concurrent.futures, json, os, re, shutil, socket, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
work = os.path.abspath(sys.argv[1])
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
ra = cfgpatch.short_dir() + '/r'
shutil.copytree(src, ra)
srcmenus = os.path.join(repo, 'bbs', 'bbsc', 'myth', 'menus')
menus = ra.rsplit('/', 1)[0] + '/m'
shutil.copytree(srcmenus, menus)
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))
# the top menu gets an item of type 171 (toggle UTF-8 / CP437), in a free slot
path = [os.path.join(menus, f) for f in os.listdir(menus) if f.lower() == 'realtop.mnu'][0]
d = bytearray(open(path, 'rb').read())
REC = 167
used = {chr(d[i * REC + 7 + 1 + 75]).upper() for i in range(1, len(d) // REC) if d[i * REC] != 0}
KEY = [k for k in 'WXYZ' if k not in used][0]
slot = 1
while slot * REC < len(d) and d[slot * REC] != 0:
    slot += 1
if (slot + 1) * REC > len(d):
    d += bytes((slot + 1) * REC - len(d))
r = bytearray(REC)
r[0] = 171
pr = b'CHARSET'
r[7] = len(pr); r[8:8 + len(pr)] = pr
r[7 + 76] = ord(KEY)
r[REC - 2] = 15
d[slot * REC:(slot + 1) * REC] = r
open(path, 'wb').write(d)

cfg = {'mk': repo + '/build/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-8',
       'ports': [{'port': 24671, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra},
                 {'port': 24672, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra, 'charset': 'utf8'},
                 {'port': 24673, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra, 'charset': 'cp437'}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = subprocess.Popen([repo + '/build/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)

IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240


class Caller:
    """a telnet client: answers the negotiation (terminal type if it has one), the ANSI detection, logs in"""

    def __init__(self, port, ttype):
        self.s = socket.create_connection(('127.0.0.1', port))
        self.s.settimeout(0.2)
        self.ttype = ttype
        self.data = b''                  # what the BBS sent as text (telnet commands taken out)
        self.pend = b''

    def feed(self, raw):
        b = self.pend + raw
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
                    if o == 24 and self.ttype is not None:
                        self.s.sendall(bytes([IAC, WILL, 24]))
                    else:
                        self.s.sendall(bytes([IAC, WONT, o]))
                elif v == WILL:
                    self.s.sendall(bytes([IAC, DO if o in (1, 3, 0) else DONT, o]))
                i += 3
            elif v == SB:
                j = b.find(bytes([IAC, SE]), i)
                if j < 0:
                    self.pend = b[i:]; break
                sub = b[i + 2:j]
                if sub[:2] == bytes([24, 1]) and self.ttype is not None:
                    self.s.sendall(bytes([IAC, SB, 24, 0]) + self.ttype.encode() + bytes([IAC, SE]))
                i = j + 2
            else:
                i += 2
        self.data += bytes(out)
        return bytes(out)

    def until(self, needle, secs=10):
        end = time.time() + secs
        seen = b''
        while time.time() < end and needle not in seen:
            try:
                d = self.s.recv(4096)
                if not d:
                    break
                t = self.feed(d)
                seen += t
                if b'\x1b[6n' in t:
                    self.s.sendall(b'\x1b[1;1R')
            except socket.timeout:
                pass
        return seen

    def login(self):
        self.until(b'language choice', 12); time.sleep(1.5); self.s.sendall(b'\r')
        self.until(b'last name: ', 12); time.sleep(2.5)
        self.s.sendall(b'Mark May\r'); self.until(b'assword'); time.sleep(0.5); self.s.sendall(b'windows\r')
        for _ in range(8):
            x = self.until(b'zzzz', 3)
            if b'continue' in x or b'Enter' in x:
                self.s.sendall(b'\r')
            else:
                break
        return b'Command >' in x


def scenario(port, ttype):
    c = Caller(port, ttype)
    ok = c.login()
    return ok, c.data


def high(d):
    return len(re.findall(rb'[\x80-\xff]', d))


def valid_utf8(d):
    try:
        d.decode('utf-8')
        return True
    except UnicodeDecodeError:
        return False


fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'charset: ' + name)
    if not ok:
        fails += 1


try:
    jobs = {'xterm': (24671, 'XTERM'), 'bbs': (24671, 'ANSI-BBS'), 'none': (24671, None),
            'forced utf8': (24672, 'ANSI-BBS'), 'forced cp437': (24673, 'XTERM')}
    with concurrent.futures.ThreadPoolExecutor(5) as ex:
        res = {k: ex.submit(scenario, *v) for k, v in jobs.items()}
        res = {k: f.result() for k, f in res.items()}
    for k, (ok, d) in res.items():
        check('%s: logged in to the menu (%d bytes, %d high)' % (k, len(d), high(d)), ok)
    x = res['xterm'][1]
    check('XTERM caller: valid UTF-8 with the box characters (U+2550)', valid_utf8(x) and '═'.encode() in x)
    b = res['bbs'][1]
    check('ANSI-BBS caller: the DOS bytes as they are (CD, B0 ...), no UTF-8', b'\xcd' in b and b'\xe2\x95' not in b)
    n = res['none'][1]
    check('a client that reports no terminal type: as they are', b'\xcd' in n and b'\xe2\x95' not in n)
    f = res['forced utf8'][1]
    check('port charset utf8 with ANSI-BBS: UTF-8', valid_utf8(f) and '═'.encode() in f)
    r = res['forced cp437'][1]
    check('port charset cp437 with XTERM: as they are', b'\xcd' in r and b'\xe2\x95' not in r)
    nonascii = len([ch for ch in x.decode('utf-8') if ord(ch) > 127])
    check('the same screens: the UTF-8 stream has as many characters as the CP437 stream has high bytes (%d / %d)' % (nonascii, high(b)),
          nonascii == high(b))

    # the caller switches the character set with the menu command (type 171)
    c = Caller(24671, 'XTERM')
    check('toggle: logged in', c.login())
    c.s.sendall(KEY.lower().encode())
    t = c.until(b'ress', 6)
    check('XTERM caller presses the key: now CP437 (message in plain text)', b'Character set: CP437' in t)
    c.s.sendall(b'\r')
    t = c.until(b'Command >', 8)
    check('... and the menu is drawn with the DOS bytes', b'\xcd' in t and b'\xe2\x95' not in t)
    c.s.sendall(KEY.lower().encode())
    t = c.until(b'ress', 6)
    check('pressing it again: UTF-8', b'Character set: UTF-8' in t)
    c.s.sendall(b'\r')
    t = c.until(b'Command >', 8)
    check('... and the menu is drawn in UTF-8 again', valid_utf8(t) and '\u2550'.encode() in t)
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
