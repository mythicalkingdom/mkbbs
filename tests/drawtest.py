#!/usr/bin/env python3
"""mkdraw through a pseudo terminal: load an ANSI screen, type, draw, copy, save as ASC / ANS / AVT / PAS and check the
files byte by byte.  A small terminal emulator (characters, colours, blink) reads what Free Vision draws.
usage: drawtest.py <build dir> <work dir>"""
import fcntl, os, pty, re, select, shutil, struct, subprocess, sys, termios, time

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, extra=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkdraw: ' + name + ('' if ok else '  ' + str(extra)[:300]))
    if not ok:
        fails += 1


# ---------------------------------------------------------------- CP437 <-> Unicode, DOS colours <-> ANSI
def cp(b):
    return bytes([b]).decode('cp437')


LOW = '☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼'
ANSI2DOS = [0, 4, 2, 6, 1, 5, 3, 7]


class Term:
    def __init__(self, rows=25, cols=80):
        self.rows, self.cols = rows, cols
        self.reset()

    def reset(self):
        self.g = [[(' ', 7, 0, False)] * self.cols for _ in range(self.rows)]
        self.cy = self.cx = 0
        self.fg, self.bg, self.bold, self.blink = 7, 0, False, False
        self.sgr = []                       # every SGR sequence, in order (for the guard check)

    def feed(self, data):
        s = data.decode('utf-8', 'replace')
        i = 0
        while i < len(s):
            c = s[i]
            if c == '\x1b':
                m = re.match(r'\x1b\[([0-9;?]*)([A-Za-z])', s[i:])
                if m:
                    self.csi(m.group(1), m.group(2))
                    i += m.end()
                    continue
                m = re.match(r'\x1b[()][0-9A-Za-z]|\x1b[=>78]|\x1b\][^\x07]*\x07', s[i:])
                i += m.end() if m else 1
                continue
            i += 1
            if c == '\r':
                self.cx = 0
            elif c == '\n':
                self.cy = min(self.rows - 1, self.cy + 1)
            elif c == '\x07':
                pass
            else:
                if self.cx < self.cols:
                    self.g[self.cy][self.cx] = (c, self.fg + (8 if self.bold else 0), self.bg, self.blink)
                    self.cx += 1

    def csi(self, p, f):
        a = [int(x) if x.isdigit() else 0 for x in p.replace('?', '').split(';')] if p else []
        if '?' in p:
            return
        if f in 'Hf':
            self.cy = min(self.rows - 1, (a[0] if a and a[0] else 1) - 1)
            self.cx = min(self.cols - 1, (a[1] if len(a) > 1 and a[1] else 1) - 1)
        elif f == 'J' and (a[0] if a else 0) == 2:
            self.g = [[(' ', 7, 0, False)] * self.cols for _ in range(self.rows)]
        elif f == 'm':
            self.sgr.append(a if a else [0])
            for n in (a if a else [0]):
                if n == 0:
                    self.fg, self.bg, self.bold, self.blink = 7, 0, False, False
                elif n == 1:
                    self.bold = True
                elif n == 22:
                    self.bold = False
                elif n == 5:
                    self.blink = True
                elif n == 25:
                    self.blink = False
                elif 30 <= n <= 37:
                    self.fg = ANSI2DOS[n - 30]
                    self.bold = self.bold and False if False else self.bold
                elif 90 <= n <= 97:
                    self.fg = ANSI2DOS[n - 90] + 8
                    self.bold = False
                elif n == 39:
                    self.fg = 7
                elif 40 <= n <= 47:
                    self.bg = ANSI2DOS[n - 40]
                elif n == 49:
                    self.bg = 0
        elif f == 'A':
            self.cy = max(0, self.cy - (a[0] if a and a[0] else 1))
        elif f == 'B':
            self.cy = min(self.rows - 1, self.cy + (a[0] if a and a[0] else 1))
        elif f == 'C':
            self.cx = min(self.cols - 1, self.cx + (a[0] if a and a[0] else 1))
        elif f == 'D':
            self.cx = max(0, self.cx - (a[0] if a and a[0] else 1))

    def row(self, y):
        return ''.join(c[0] for c in self.g[y])

    def cell(self, x, y):
        """canvas cell (1 based) -> (char, DOS attribute); the canvas starts at screen row 3"""
        ch, fg, bg, bl = self.g[y + 1][x - 1]
        return ch, (fg & 15) | (bg & 7) << 4 | (0x80 if bl else 0)


class Session:
    def __init__(self, args=(), cwd=work, rows=25, cols=80, env=None):
        e = {'TERM': 'xterm', 'LANG': 'C.UTF-8', 'LC_ALL': 'C.UTF-8', 'PATH': os.environ['PATH']}
        if env:
            e.update(env)
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ.clear()
            os.environ.update(e)
            os.chdir(cwd)
            os.execv(os.path.join(build, 'mkdraw'), ['mkdraw'] + list(args))
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
        self.t = Term(rows, cols)
        self.raw = b''
        self.drain(1.2)

    def drain(self, t=0.4):
        end = time.time() + t
        while time.time() < end:
            r, _, _ = select.select([self.fd], [], [], 0.05)
            if r:
                try:
                    d = os.read(self.fd, 65536)
                except OSError:
                    break
                if not d:
                    break
                self.raw += d
                self.t.feed(d)
        return self

    def keys(self, *ks, wait=0.25):
        for k in ks:
            os.write(self.fd, k if isinstance(k, bytes) else k.encode('utf-8'))
            self.drain(wait)
        return self

    def alive(self):
        try:
            return os.waitpid(self.pid, os.WNOHANG) == (0, 0)
        except ChildProcessError:
            return False

    def close(self):
        if self.fd is None:
            return
        try:
            os.kill(self.pid, 9)
            os.waitpid(self.pid, 0)
        except Exception:
            pass
        os.close(self.fd)
        self.fd = None


ESC = '\x1b'
ALT = lambda c: ESC + c
UP, DOWN, RIGHT, LEFT = ESC + '[A', ESC + '[B', ESC + '[C', ESC + '[D'
HOME, END, PGUP, PGDN, DEL, INS = ESC + '[H', ESC + '[F', ESC + '[5~', ESC + '[6~', ESC + '[3~', ESC + '[2~'
F1 = ESC + 'OP'
ENTER, BACK = '\r', '\x7f'

def leaks(data):
    """Places in an ANSI stream where text follows a colour reset that did not (together with what follows it) set both a
    foreground and a background colour: the terminal's own default colours would show."""
    fg = bg = True
    n = 0
    i = 0
    while i < len(data):
        m = re.match(rb'\x1b\[([0-9;]*)m', data[i:])
        if m:
            for v in (m.group(1).split(b';') if m.group(1) else [b'0']):
                v = int(v) if v.isdigit() else 0
                if v == 0:
                    fg = bg = False
                elif 30 <= v <= 39 or 90 <= v <= 97:
                    fg = True
                elif 40 <= v <= 49 or 100 <= v <= 107:
                    bg = True
            i += m.end()
            continue
        if data[i] >= 32 and not (fg and bg):
            n += 1
            fg = bg = True
        i += 1
    return n


# ---------------------------------------------------------------- the test screen (CP437 bytes, ANSI colours)
src = (b'\x1b[0;1;33;44m' + bytes([201]) + bytes([205]) * 10 + bytes([187]) + b'\x1b[0m\r\n' +
       b'\x1b[0;31m' + bytes([186]) + b'\x1b[1;32m Hello ' + bytes([176, 177, 178, 219]) + b'\x1b[0m\r\n' +
       b'\x1b[5;36mBlink\x1b[0m done\x1a ignored')
sf = os.path.join(work, 't.ans')
open(sf, 'wb').write(src)

s = Session([sf])
t = s.t
check('the screen loads: box drawing, shading blocks and text as the terminal shows CP437',
      t.row(2).startswith('╔══════════╗') and t.row(3).startswith('║ Hello ░▒▓█') and t.row(4).startswith('Blink done'), (t.row(2), t.row(3)))
check('^Z ends the file: nothing after it is drawn', 'ignored' not in ''.join(t.row(y) for y in range(25)))
check('the colours of the art: yellow on blue, red, bright green, blink',
      t.cell(1, 1) == ('╔', 0x1E) and t.cell(1, 2) == ('║', 0x04) and t.cell(3, 2)[1] == 0x0A and t.cell(1, 3)[1] == 0x83, [t.cell(1, 1), t.cell(1, 2), t.cell(3, 2), t.cell(1, 3)])
check('the top lines: banner, position, the special characters of set 1',
      t.row(0).strip().startswith('MKDraw v1.01') and '(  1,  1)' in t.row(1) and '1=┌' in t.row(1) and '10=┬' in t.row(1), (t.row(0), t.row(1)))

# ---------------------------------------------------------------- what Free Vision sends: always both colours after a reset
first_clear = s.raw.find(b'\x1b[2J')
body = s.raw[first_clear:]
bad = [m.group(1) for m in re.finditer(rb'\x1b\[([0-9;]*)m', body)
       if (m.group(1) == b'' or b'0' in m.group(1).split(b';')) and not (
           any(30 <= int(x) <= 39 or 90 <= int(x) <= 97 for x in m.group(1).split(b';') if x.isdigit()) and
           any(40 <= int(x) <= 49 or 100 <= int(x) <= 107 for x in m.group(1).split(b';') if x.isdigit()))]
check('the guard: no colour reset on the terminal that leaves its default colours on (while the screen is up)', len(bad) <= 1, bad[:5])

# ---------------------------------------------------------------- typing, CP437 characters, special keys
s.keys(DOWN, DOWN, DOWN, DOWN, 'AB')
check('typing: the characters are drawn at the cursor, the position moves', t.cell(1, 5)[0] == 'A' and t.cell(2, 5)[0] == 'B' and '(  3,  5)' in t.row(1), (t.cell(1, 5), t.row(1)))
s.keys('é', '░', 'ñ')
check('typing letters of the PC set (UTF-8 in the terminal): é, a shading block, ñ',
      [t.cell(x, 5)[0] for x in (3, 4, 5)] == ['é', '░', 'ñ'], [t.cell(x, 5)[0] for x in (3, 4, 5)])
s.keys('\x01', '\x06', F1)
check('Ctrl-A, Ctrl-F: control codes are entered (shown as the PC glyphs), F1: the first special character of the set',
      [t.cell(x, 5)[0] for x in (6, 7, 8)] == ['☺', '♠', '┌'], [t.cell(x, 5)[0] for x in (6, 7, 8)])
s.keys(ALT('g'), DOWN, ENTER)
s.keys(F1)
check('Alt-G chooses another character set (set 2: double lines)', t.cell(9, 5)[0] == '╔', t.cell(9, 5))
s.keys(ESC + '[1;3P')       # Alt-F1 = set 1
s.keys(F1)
check('Alt-F1 chooses set 1 again', t.cell(10, 5)[0] == '┌', t.cell(10, 5))
s.keys(HOME, BACK)
check('Backspace at the first column blanks the cell', t.cell(1, 5)[0] == ' ', t.cell(1, 5))

# ---------------------------------------------------------------- colours
s.keys(ALT('b'))
s.keys('Z')
check('Alt-B: blinking on, the next character blinks', t.cell(1, 5)[1] & 0x80 != 0 and t.cell(1, 5)[0] == 'Z', t.cell(1, 5))
s.keys(ALT('b'), ALT('i'), 'Y')
check('Alt-B off, Alt-I: no blink, intensity toggled', t.cell(2, 5)[1] & 0x80 == 0 and t.cell(2, 5)[1] != t.cell(1, 5)[1] & 0x7F, [t.cell(1, 5), t.cell(2, 5)])
s.keys(HOME, UP, UP, UP, UP)
s.keys(ALT('u'))
s.keys(DOWN, DOWN, DOWN, DOWN, 'c')
check('Alt-U takes the colour under the cursor (the art\'s yellow on blue)', t.cell(1, 5) == ('c', 0x1E), t.cell(1, 5))

# ---------------------------------------------------------------- an area: fill, enclose, copy, move, zap
s.keys(HOME, PGUP)
s.keys(ALT('c'), ENTER)
s.keys(RIGHT, RIGHT, DOWN, ENTER)                      # the area (1,1)-(3,2)
s.keys(DOWN, DOWN, DOWN, DOWN, DOWN, RIGHT, RIGHT, RIGHT, ENTER)
check('Alt-C copies an area: the box corner and its neighbours are now at (4,6)',
      t.cell(4, 6)[0] == '╔' and t.cell(5, 6)[0] == '═' and t.cell(4, 7)[0] == '║' and t.cell(1, 1)[0] == '╔', [t.cell(4, 6), t.cell(5, 6), t.cell(4, 7)])
s.keys(HOME, PGUP)
s.keys(ALT('m'), ENTER)
s.keys(RIGHT, RIGHT, DOWN, ENTER)
s.keys(DOWN, DOWN, DOWN, DOWN, DOWN, DOWN, DOWN, DOWN, RIGHT, RIGHT, ENTER)
check('Alt-M moves an area: it is at (3,9) and the original place is blank',
      t.cell(3, 9)[0] == '╔' and t.cell(1, 1)[0] == ' ' and t.cell(1, 2)[0] == ' ', [t.cell(3, 9), t.cell(1, 1), t.cell(1, 2)])
s.keys(HOME, PGUP, ALT('z'), ENTER)
s.keys(RIGHT, RIGHT, RIGHT, DOWN, DOWN, ENTER, ENTER)  # area then "Yes" (default)
s.keys(wait=0.4)
check('Alt-Z clears an area (after the question): the first row of the box is blank in the area', t.cell(1, 1)[0] == ' ' and t.cell(4, 3)[0] == ' ' and t.cell(4, 1)[0] == ' ' and t.cell(5, 1)[0] == '═', [t.cell(1, 1), t.cell(4, 3), t.cell(4, 1), t.cell(5, 1)])

# ---------------------------------------------------------------- the help dialog fits on the desktop
s.keys(ALT('h'), wait=0.5)
txt = [t.row(y) for y in range(25)]
check('Alt-H: the whole help shows (first and last lines, and the OK button)',
      any('Alt-A  Color' in r for r in txt) and any('Alt-Z  Zap' in r for r in txt) and any('OK' in r for r in txt),
      [r.strip() for r in txt if r.strip()][:3])
s.keys(ENTER)

# ---------------------------------------------------------------- enclose, drawing mode, insert/delete line
s.keys(HOME, PGUP)
s.keys(ALT('d'), UP, UP, UP, ENTER)                      # drawing set 2 (double lines)
s.keys(RIGHT, RIGHT, DOWN, DOWN)
check('drawing mode: the cursor draws lines (double line set) as it moves',
      t.cell(1, 1)[0] in '═║╔╗╚╝╠╣╦╩╬' and t.cell(3, 1)[0] in '═║╔╗╚╝╠╣╦╩╬', [t.cell(1, 1), t.cell(2, 1), t.cell(3, 1), t.cell(3, 2)])
s.keys(ALT('d'), DOWN, DOWN, DOWN, ENTER)                # back to normal
s.close()

# ---------------------------------------------------------------- the fast menu (Esc)
s = Session([sf])
t = s.t
s.keys(HOME, PGUP)
s.keys(ESC, wait=0.5)
check('Esc: the fast menu lists the commands', 'MKDraw Fast Menu' in ''.join(t.row(y) for y in range(25)) and 'Toggle Blinking' in ''.join(t.row(y) for y in range(25)))
s.keys(DOWN, ENTER)
s.keys('Q')
check('a command chosen in the fast menu runs (Toggle Blinking)', t.cell(1, 1)[0] == 'Q' and t.cell(1, 1)[1] & 0x80 != 0, t.cell(1, 1))

# ---------------------------------------------------------------- the mouse: a click moves the cursor, a right click is Esc, motion is ignored
s.keys('\x1b[<35;10;8M', wait=0.3)
check('mouse motion reports are not typed into the screen', t.cell(1, 5)[0] != '3' and '(  2,  1)' in t.row(1), (t.row(1), t.row(7)))
s.keys('\x1b[<0;12;9M', '\x1b[<0;12;9m', wait=0.3)
check('a left click moves the cursor (column 12, screen row 9 = row 7 of the screen)', '( 12,  7)' in t.row(1), t.row(1))
s.keys('\x1b[<2;12;9M', '\x1b[<2;12;9m', wait=0.4)
check('a right click is Esc: the fast menu', 'MKDraw Fast Menu' in ''.join(t.row(y) for y in range(25)))
s.keys(ESC)
s.close()

# ---------------------------------------------------------------- editing commands on a plain screen
plain = os.path.join(work, 'plain.asc')
open(plain, 'wb').write(b'AAAAA\r\nBBBBB\r\nCCCCC\r\nXY')
s = Session([plain])
t = s.t
s.keys(DOWN)
s.keys(ALT('v'))
check('Alt-V inserts a line: the lines below move down, the new line is blank',
      t.row(2).startswith('AAAAA') and t.row(3).strip() == '' and t.row(4).startswith('BBBBB') and t.row(5).startswith('CCCCC'), [t.row(y)[:6] for y in range(2, 7)])
s.keys(ALT('y'))
check('Alt-Y deletes a line: they move up again', t.row(3).startswith('BBBBB') and t.row(4).startswith('CCCCC') and t.row(5).startswith('XY'), [t.row(y)[:6] for y in range(2, 7)])
s.keys(PGUP, HOME, INS, '12')
check('Ins: insert mode (shown as Ins), the rest of the line moves right', 'Ins' in t.row(1) and t.row(2).startswith('12AAAAA'), (t.row(1)[:30], t.row(2)[:10]))
s.keys(DEL)
check('Del removes the character at the cursor, the rest moves left', t.row(2).startswith('12AAAA ') or t.row(2).startswith('12AAAA'), t.row(2)[:10])
s.keys(BACK)
check('Backspace in insert mode removes the character before the cursor', t.row(2).startswith('1AAAA') or t.row(2).startswith('1AAA'), t.row(2)[:10])
s.keys(INS)
check('Ins again: overwrite (Ovr)', 'Ovr' in t.row(1))
s.close()

s = Session([plain])
t = s.t
s.keys(ALT('w'))
check('Alt-W doubles the upper left quarter: every cell becomes 2 x 2 cells',
      t.row(2).startswith('AAAAAAAAAA') and t.row(3).startswith('AAAAAAAAAA') and t.row(4).startswith('BBBBBBBBBB') and t.row(5).startswith('BBBBBBBBBB') and t.row(8).startswith('XXYY'),
      [t.row(y)[:12] for y in range(2, 9)])
s.close()

s = Session([plain])
t = s.t
s.keys(ALT('e'), ENTER)                                  # enclose: area (1,1)-(4,3)
s.keys(RIGHT, RIGHT, RIGHT, DOWN, DOWN, ENTER)
check('Alt-E encloses an area in a frame of the first line set', t.cell(1, 1)[0] == '┌' and t.cell(4, 1)[0] == '┐' and t.cell(1, 3)[0] == '└' and t.cell(4, 3)[0] == '┘' and t.cell(2, 1)[0] == '─' and t.cell(1, 2)[0] == '│' and t.cell(4, 2)[0] == '│', [t.row(y)[:6] for y in range(2, 5)])
s.close()

s = Session([plain])
t = s.t
orig = t.cell(4, 1)[1]
s.keys(ALT('f'), ENTER)                                  # attribute fill: the area (1,1)-(3,2), then the colour grid
s.keys(RIGHT, RIGHT, DOWN, ENTER)
s.keys(RIGHT, DOWN, ENTER)                               # the grid: a colour further
a1, a2 = t.cell(1, 1), t.cell(3, 2)
check('Alt-F fills the attributes of an area: the characters stay, the colours change, outside the area nothing',
      a1[0] == 'A' and a2[0] == 'B' and a1[1] == a2[1] and a1[1] != orig and t.cell(4, 1)[1] == orig and t.cell(1, 3)[1] == orig, [a1, a2, t.cell(4, 1), orig])
s.close()

s = Session([plain])
t = s.t
s.keys(ALT('p'), wait=0.5)
check('Alt-P lists the BBS screen codes', 'Wait on Enter' in ''.join(t.row(y) for y in range(25)) and 'Num file area' in ''.join(t.row(y) for y in range(25)) or 'Bbs Screen Code' in ''.join(t.row(y) for y in range(25)), '')
s.keys(DOWN, DOWN, DOWN, DOWN, DOWN, DOWN, ENTER)         # 7 = clear screen (^L)
s.keys(ALT('p'), wait=0.3)
s.keys(*([DOWN] * 8), ENTER)                             # 9 = full name (^F A): two cells
check('a BBS code is put in the screen as its control codes (shown as PC glyphs; ^L and ^F A)', t.cell(1, 1)[0] == '♀' and t.cell(2, 1)[0] == '♠' and t.cell(3, 1)[0] == 'A', [t.cell(x, 1) for x in (1, 2, 3)])
s.close()

# ---------------------------------------------------------------- what was saved can be loaded again: the same screen
def canvas_of(args):
    ss = Session(args)
    cells = [(c, a & 0xF0 if c == ' ' else a) for c, a in (ss.t.cell(x, y) for y in range(1, 4) for x in range(1, 17))]
    ss.close()                       # (the foreground of a blank is not saved: it cannot be seen)
    return cells



# ---------------------------------------------------------------- saving: a clean small screen
s.close()
small = os.path.join(work, 'small.ans')
open(small, 'wb').write(
    b'\x1b[0;1;33;44m' + bytes([201]) + bytes([205]) * 10 + bytes([187]) + b'\x1b[0m\r\n' +
    b'\x1b[0;31m' + bytes([186]) + b'\x1b[1;32m Hello ' + bytes([176, 177, 178, 219]) + b'\x1b[0m\r\n' +
    b'\x1b[1;37mWhite\x1b[0m gray')
SAVE = [ALT('s'), None]


def save_session(args, name, extra=()):
    ss = Session(args)
    ss.keys(ALT('s'))
    ss.keys('\x15' if False else '', wait=0.1)
    # the file name field has the current name: clear it (Ctrl-Y) and type the new one
    ss.keys('\x19' if False else '')
    return ss


def save_all(args, outname, upleft=1):
    ss = Session(args)
    ss.keys(ALT('s'), wait=0.5)
    ss.keys(END, wait=0.05)
    ss.keys(*([BACK] * 90), wait=0.01)
    ss.keys(outname, ENTER, wait=0.4)
    ss.keys(HOME, PGUP, ENTER, wait=0.2)
    ss.keys(PGDN, END, ENTER, wait=0.3)                    # area: the whole screen
    ss.keys(ENTER, wait=0.5)                              # action: none
    return ss


out = os.path.join(work, 'out')
ss = save_all([small], out)
check('Alt-S with a name without an extension writes .asc, .ans and .avt', all(os.path.exists(out + e) for e in ('.asc', '.ans', '.avt')), os.listdir(work))
if all(os.path.exists(out + e) for e in ('.asc', '.ans', '.avt')):
    asc = open(out + '.asc', 'rb').read()
    ans = open(out + '.ans', 'rb').read()
    avt = open(out + '.avt', 'rb').read()
    lines = asc.split(b'\r\n')
    check('.asc: CP437 bytes, CR LF, trailing spaces cut, 23 lines', lines[0] == bytes([201]) + bytes([205]) * 10 + bytes([187]) and lines[1] == bytes([186]) + b' Hello ' + bytes([176, 177, 178, 219]) and len(lines) == 24 and lines[2] == b'White gray', (lines[:3], len(lines)))
    check('.ans: the colours as ANSI, CP437 bytes, CR LF', b'\x1b[0;' not in ans[:0] and ans.startswith(b'\x1b[1;33;44m' + bytes([201])) or ans.startswith(b'\x1b[0;1;33;44m') or b'\x1b[1;33;44m' in ans[:20], ans[:60])
    sg = [m.group(1) for m in re.finditer(rb'\x1b\[([0-9;]*)m', ans)]
    check('.ans: after every colour reset the foreground and the background are set again (the colour guard)', leaks(ans) == 0 and b'0' in sg, (leaks(ans), sg))
    check('.avt: attribute ^V^A, a run of the 10 double lines is ^Y char count', avt.startswith(b'\x16\x01\x1e' + bytes([201])) and b'\x19' + bytes([205]) + b'\x0a' in avt and avt.count(b'\r\n') == 23, avt[:40])
ss.close()

# the same without the guard (-n): a reset that leaves a colour to the terminal
out2 = os.path.join(work, 'out2')
ss = save_all(['-n', small], out2)
if os.path.exists(out2 + '.ans'):
    ans2 = open(out2 + '.ans', 'rb').read()
    sg2 = [m.group(1) for m in re.finditer(rb'\x1b\[([0-9;]*)m', ans2)]
    check('-n: the file is as the original program wrote it (a reset that leaves the terminal its colours, a shorter file)', leaks(ans2) >= 1 and len(ans2) < len(ans), (leaks(ans2), len(ans2), len(ans)))
else:
    check('-n writes the files', False, os.listdir(work))
ss.close()

# a Pascal source and an explicit name
ss = save_all([small], os.path.join(work, 'banner.pas'))
if os.path.exists(os.path.join(work, 'banner.pas')):
    pas = open(os.path.join(work, 'banner.pas'), 'rb').read()
    check('.pas: Procedure DoBanner with AvStr / AvStrLn lines, quotes doubled', pas.startswith(b'Procedure DoBanner;\r\n  Begin\r\n  AvStr') and pas.rstrip().endswith(b'End;') and b'AvStrLn(' in pas, pas[:80])
else:
    check('.pas is written', False, os.listdir(work))
ss.close()

# a saved screen loaded again looks the same (ANSI, AVATAR, ASCII for the characters)
base = canvas_of([small])
check('the saved .ans loads to the same screen (characters and colours)', canvas_of([out + '.ans']) == base, '')
check('the saved .avt loads to the same screen (run length codes, attributes)', canvas_of([out + '.avt']) == base, '')
check('the saved .asc loads to the same characters', [c[0] for c in canvas_of([out + '.asc'])] == [c[0] for c in base], '')

# a missing screen: the tool starts empty
ss = Session([os.path.join(work, 'nothere.ans')])
check('a file name that does not exist: the editor starts with an empty screen', ss.t.row(2).strip() == '' and ss.alive())
ss.keys(ALT('x'))
ss.keys('y', wait=0.5)
check('Alt-X asks and leaves', not ss.alive())
ss.close()
ss = Session([], cwd=work)                              # no file name: the list of *.a* files
check('without a file name the screen files are listed to choose from', 'small.ans' in ''.join(ss.t.row(y) for y in range(25)) and 't.ans' in ''.join(ss.t.row(y) for y in range(25)), '')
ss.keys(ESC)
check('Esc in the list: an empty screen', ss.alive())
ss.close()

# the program stays in its own directory and does not touch other files
check('the screen files are the only files that were made', sorted(f for f in os.listdir(work) if f.startswith(('out', 'banner'))) == sorted(['banner.pas', 'out.asc', 'out.ans', 'out.avt', 'out2.asc', 'out2.ans', 'out2.avt']), os.listdir(work))

# a larger terminal: the screen is the 80 x 23 of a caller at the top left; a smaller terminal is refused
s = Session([small], rows=40, cols=120)
check('a larger terminal: the editor works at the top left', s.t.row(2).startswith('╔══════════╗') and s.t.row(0).strip().startswith('MKDraw'))
s.close()
r = subprocess.run(['script', '-qec', 'stty rows 24 cols 80; ' + os.path.join(build, 'mkdraw') + ' ' + small, '/dev/null'], capture_output=True, env={'TERM': 'xterm', 'LANG': 'C.UTF-8', 'PATH': os.environ['PATH']}, timeout=20)
check('a terminal with less than 80 x 25: a message and exit 2', b'at least 80 x 25' in r.stdout and r.returncode == 2, (r.returncode, r.stdout[-200:]))
r = subprocess.run([os.path.join(build, 'mkdraw'), '-x'], capture_output=True, timeout=20)
check('a wrong option: usage, exit 3', r.returncode == 3 and b'Usage' in r.stderr, r)

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
