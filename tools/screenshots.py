#!/usr/bin/env python3
"""Makes the screenshots of the README (docs/screenshots/*.png) from the real programs: the sample BBS is copied to a private directory, mklisten runs it (with the
binkp mailer mkbink when it is built next to this project), a caller logs on over telnet, mkmon and mkconfig run on pseudo terminals; every screen is drawn by a terminal emulator
(pyte) and rendered with a monospace font.
needs: build/ (run ./build.sh --build-only first), the sample BBS, python3 with pyte and Pillow (pip install pyte pillow), the DejaVu Sans Mono font.
usage: tools/screenshots.py [output directory]"""
import fcntl, json, os, pty, re, select, shutil, socket, struct, subprocess, sys, tempfile, termios, time

import pyte
from PIL import Image, ImageDraw, ImageFont

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
sys.path.insert(0, os.path.join(repo, 'tests'))
import cfgpatch

out_dir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(repo, 'docs', 'screenshots')
os.makedirs(out_dir, exist_ok=True)
sample = os.path.join(repo, 'bbs', 'bbsc', 'ra')
menus_src = os.path.join(repo, 'bbs', 'bbsc', 'myth', 'menus')
mkbink = os.environ.get('MKBINK', os.path.join(repo, '..', 'mkbink', 'build', 'mkbink'))
COLS, ROWS = 80, 25

# ------------------------------------------------------------------ rendering
PAL = {'black': '#000000', 'red': '#aa0000', 'green': '#00aa00', 'brown': '#aa5500', 'yellow': '#aa5500', 'blue': '#0000aa', 'magenta': '#aa00aa', 'cyan': '#00aaaa', 'white': '#aaaaaa',
       'brightblack': '#555555', 'brightred': '#ff5555', 'brightgreen': '#55ff55', 'brightbrown': '#ffff55', 'brightyellow': '#ffff55', 'brightblue': '#5555ff',
       'brightmagenta': '#ff55ff', 'brightcyan': '#55ffff', 'brightwhite': '#ffffff'}
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 16)
FONTB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', 16)
CW, CH = 10, 20


def colour(name, bold, default):
    if name == 'default':
        return default
    if re.fullmatch(r'[0-9a-f]{6}', name):
        return '#' + name
    if bold and name in PAL and not name.startswith('bright'):
        name = 'bright' + name if name != 'black' else 'brightblack'
    return PAL.get(name, default)


def render(screen, path, title):
    pad, bar = 14, 30
    w, h = COLS * CW + 2 * pad, ROWS * CH + 2 * pad + bar
    im = Image.new('RGB', (w, h), '#1b1d23')
    d = ImageDraw.Draw(im)
    for i, c in enumerate(('#ff5f56', '#ffbd2e', '#27c93f')):
        d.ellipse((pad + i * 20, 9, pad + i * 20 + 12, 21), fill=c)
    d.text((w // 2, 15), title, font=FONT, fill='#9aa0a6', anchor='mm')
    d.rectangle((pad, bar + pad - 1, pad + COLS * CW, bar + pad + ROWS * CH), fill='#000000')
    for y in range(ROWS):
        row = screen.buffer[y]
        for x in range(COLS):
            ch = row[x]
            fg = colour(ch.fg, ch.bold, PAL['white'])
            bg = colour(ch.bg, False, '#000000')
            if ch.reverse:
                fg, bg = bg, fg
            px, py = pad + x * CW, bar + pad + y * CH
            if bg != '#000000':
                d.rectangle((px, py, px + CW - 1, py + CH - 1), fill=bg)
            if ch.data != ' ':
                d.text((px + CW // 2, py + CH // 2), ch.data, font=FONTB if ch.bold and False else FONT, fill=fg, anchor='mm')
    im.save(path)
    print('wrote', path)


# ------------------------------------------------------------------ a telnet caller and a pty program, both feeding a terminal emulator
IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240


class Term:
    def __init__(self):
        self.screen = pyte.Screen(COLS, ROWS)
        self.stream = pyte.ByteStream(self.screen)
        self.carry = b''
        self.text = ''

    def feed(self, data, flush=False):
        data = self.carry + data
        self.carry = b''
        k = data.rfind(b'\x1b')
        if not flush and k >= 0 and len(data) - k < 8:      # a sequence that may go on in the next chunk is kept back
            data, self.carry = data[:k], data[k:]
        data = data.replace(b'\x1b[s\r\n\x1b[u', b'')        # the line break that only lets the BBS count lines: nothing is drawn
        data = data.replace(b'\x1b[s', b'\x1b7').replace(b'\x1b[u', b'\x1b8')      # ANSI.SYS save / restore cursor, which pyte does not know
        self.stream.feed(data)
        self.text = '\n'.join(self.screen.display)

    def has(self, s):
        return s in self.text


class Telnet(Term):
    def __init__(self, port):
        super().__init__()
        self.s = socket.create_connection(('127.0.0.1', port))
        self.s.settimeout(0.05)
        self.pend = b''

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
                    self.s.sendall(bytes([IAC, WILL if o == 24 else WONT, o]))
                elif v == WILL:
                    self.s.sendall(bytes([IAC, DO if o in (1, 3) else DONT, o]))
                i += 3
            elif v == SB:
                j = b.find(bytes([IAC, SE]), i)
                if j < 0:
                    self.pend = b[i:]; break
                if b[i + 2:i + 4] == bytes([24, 1]):
                    self.s.sendall(bytes([IAC, SB, 24, 0]) + b'xterm' + bytes([IAC, SE]))
                i = j + 2
            else:
                i += 2
        data = bytes(out)
        if b'\x1b[6n' in data:
            self.s.sendall(('\x1b[%d;%dR' % (self.screen.cursor.y + 1, self.screen.cursor.x + 1)).encode())
        self.feed(data)

    def until(self, needle, secs=10):
        end = time.time() + secs
        while time.time() < end:
            self.pump()
            if self.has(needle):
                return True
        return False

    def settle(self, secs=1.0):
        end = time.time() + secs
        while time.time() < end:
            self.pump()

    def send(self, t):
        self.s.sendall(t.encode('latin-1'))


class PtyProg(Term):
    def __init__(self, prog, env, args=()):
        super().__init__()
        e = {'TERM': 'xterm', 'LANG': 'C.UTF-8', 'LC_ALL': 'C.UTF-8', 'PATH': os.environ['PATH']}
        e.update(env)
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ.clear(); os.environ.update(e)
            os.execv(os.path.join(repo, 'build', prog), [prog] + list(args))
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack('HHHH', ROWS, COLS, 0, 0))

    def pump(self, t=0.1):
        r, _, _ = select.select([self.fd], [], [], t)
        if r:
            try:
                d = os.read(self.fd, 65536)
            except OSError:
                return
            if b'\x1b[6n' in d:
                os.write(self.fd, ('\x1b[%d;%dR' % (self.screen.cursor.y + 1, self.screen.cursor.x + 1)).encode())
            self.feed(d)

    def settle(self, secs=1.0):
        end = time.time() + secs
        while time.time() < end:
            self.pump()

    def send(self, b):
        os.write(self.fd, b)

    def close(self):
        try:
            os.kill(self.pid, 9)
            os.waitpid(self.pid, 0)
        except OSError:
            pass


# ------------------------------------------------------------------ the BBS
tmp = cfgpatch.short_dir()
ra, menus = tmp + '/r', tmp + '/m'
ign = lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)]
shutil.copytree(cfgpatch.snapshot(sample), ra, ignore=ign)
cfgpatch.fix_sample(ra)
shutil.copytree(cfgpatch.snapshot(menus_src), menus, ignore=ign)
txt = tmp + '/t'
shutil.copytree(os.path.join(repo, 'bbs', 'bbsc', 'myth', 'txtfiles'), txt)
maps = {(sample + '/').encode(): (ra + '/').encode(), (menus_src + '/').encode(): (menus + '/').encode(), (repo + '/bbs/bbsc/myth/txtfiles/').encode(): (txt + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))

procs = []
run = tempfile.mkdtemp(prefix='r', dir='/tmp')
cfg = {'mk': os.path.join(repo, 'build', 'mk'), 'mkmon': os.path.join(repo, 'build', 'mkmon'), 'rundir': run, 'logfile': os.path.join(tmp, 'listen.log'), 'workdir': ra, 'nodes': '1-4',
       'ports': [{'port': 24832, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra},
                 {'port': 24831, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'sesame', 'config': ra}]}
if os.path.exists(mkbink):
    # the mailer: one link to a second mkbink so that the Mailer screen has something to show
    h = bytearray(184 + 64 * 178 + 1024)
    h[0:2] = (1).to_bytes(2, 'little'); h[2:4] = (3).to_bytes(2, 'little'); h[4:6] = (24841).to_bytes(2, 'little')
    h[47] = 8; h[48] = 1
    for off, v in ((49, 120), (51, 60), (53, 3600), (55, 2)):
        h[off:off + 2] = v.to_bytes(2, 'little')
    L = 184
    for off, v in ((0, 1), (2, 110), (4, 100)):
        h[L + off:L + off + 2] = v.to_bytes(2, 'little')

    def pstr(off, text, size):
        h[L + off:L + off + size] = bytes([len(text)]) + text.encode() + bytes(size - 1 - len(text))
    pstr(8, 'Hub B', 31); pstr(39, '127.0.0.1', 61)
    h[L + 100:L + 102] = (24842).to_bytes(2, 'little'); pstr(102, 'secret', 31)
    open(os.path.join(ra, 'mailer.mk'), 'wb').write(h)
    ec = os.path.join(ra, 'echocfg.mk')
    d = bytearray(open(ec, 'rb').read())
    for off, text in ((0, 'files/in'), (51, 'mail/out')):
        d[off:off + 51] = bytes([len(text)]) + text.encode() + bytes(50 - len(text))
    open(ec, 'wb').write(d)
    bdir = tmp + '/b'
    os.makedirs(bdir + '/in'); os.makedirs(bdir + '/out')
    open(bdir + '/b.conf', 'w').write('version 1\naddress 1:110/100\nsysname Node B\nsysop Bee\ninbound %s/in\nbso %s/out\nzone 1\nport 24842\nbind 127.0.0.1\nlink 1:110/290\n  password secret\n  answer-only yes\n' % (bdir, bdir))
    os.chmod(bdir + '/b.conf', 0o600)
    procs.append(subprocess.Popen([mkbink, 'run', '-f', bdir + '/b.conf'], stdout=open(bdir + '/log', 'w'), stderr=subprocess.STDOUT))
    cfg['mailer'] = {'config': ra, 'mkbink': mkbink, 'mkbinkcfg': os.path.join(repo, 'build', 'mkbinkcfg'), 'interval': 1, 'restart': 1}
json.dump(cfg, open(os.path.join(tmp, 'listen.json'), 'w'))
procs.append(subprocess.Popen([os.path.join(repo, 'build', 'mklisten'), '-c', os.path.join(tmp, 'listen.json')], stdout=subprocess.DEVNULL))


def conn(port):
    for _ in range(80):
        try:
            return Telnet(port)
        except OSError:
            time.sleep(0.1)
    raise SystemExit('cannot connect')


def shot(t, name, title):
    t.settle(0.8)
    t.feed(b'', True)
    render(t.screen, os.path.join(out_dir, name), title)


try:
    time.sleep(1.5)
    # ---- mk: the first screens of a caller, then the main menu
    c = conn(24832)
    c.until('language', 10); c.settle(1.5); c.send('\r')
    c.until('last name', 10); c.settle(1.5)
    shot(c, 'mk-logon.png', 'telnet bbs.example.org 2323')
    c.send('Mark May\r'); c.until('assword'); c.settle(0.5); c.send('windows\r')
    for _ in range(10):
        c.settle(2.5)
        if c.has('Command >'):
            break
        if c.has('continue') or c.has('Enter') or c.has('ENTER') or c.has('Press'):
            c.send('\r')
    shot(c, 'mk-menu.png', 'telnet bbs.example.org 2323')
    # a second caller waits at the logon prompt so that the monitor has two nodes
    c2 = conn(24832)
    c2.until('language', 10); c2.settle(1.0); c2.send('\r'); c2.until('last name', 10)
    # ---- mkmon on the sysop port: the node list, the mailer
    m = conn(24831)
    m.until('assword', 10); m.send('sesame\r')
    m.until('sysop monitor', 10)
    m.settle(2.0)
    shot(m, 'mklisten-nodes.png', 'sysop port of mklisten: mkmon')
    if os.path.exists(mkbink):
        m.send('m')
        m.until('MkBink', 15)
        m.settle(2.5)
        shot(m, 'mklisten-mailer.png', 'sysop port of mklisten: the mailer (M)')
    m.s.close(); c2.s.close(); c.s.close()
finally:
    for p in procs:
        p.terminate()
    for p in procs:
        try:
            p.wait(5)
        except subprocess.TimeoutExpired:
            p.kill()

# ---- mkconfig on a private copy: the General menu, the message areas, an event
t = PtyProg('mkconfig', {'MK': ra})
t.settle(2.0)
t.send(b'\x1bg'); t.settle(1.0)
shot(t, 'mkconfig-general.png', 'mkconfig: General')
t.send(b'\x1b'); t.settle(0.5)
t.send(b'\x1bm'); t.settle(1.0)
shot(t, 'mkconfig-messages.png', 'mkconfig: Messages')
t.send(b'\r'); t.settle(1.5)
shot(t, 'mkconfig-areas.png', 'mkconfig: Message areas')
t.close()
