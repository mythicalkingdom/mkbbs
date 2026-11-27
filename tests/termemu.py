"""A small terminal emulator for the pty tests: characters, colours, blink, the cursor, the scroll region of the tests that need it (CP437 glyphs of the low codes are the
Unicode ones).  Copied from drawtest.py (Term); tests/connecttest.py uses it to read the dialing directory."""
import re

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


