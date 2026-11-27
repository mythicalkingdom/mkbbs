# SPDX-License-Identifier: GPL-3.0-or-later
"""A telnet client with an 80x25 screen (for the tests of the sysop monitor)."""
import re, socket, time


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



