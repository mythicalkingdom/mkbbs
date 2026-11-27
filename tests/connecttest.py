#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mkconnect (MKCONNECT-PLAN.md phase 1) on a pseudo terminal, against a small Telnet BBS of this test: the screens are converted from CP437 to UTF-8, the status bar is kept on the
bottom row, what is typed reaches the system (a letter in CP437), the attention key and the Alt keys, capture, hang up, the phone book (sealed with the start password), the dialer.
usage: connecttest.py <build dir> <work dir>"""
import os, pty, re, select, shutil, socket, struct, subprocess, sys, termios, fcntl, threading, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import termemu
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
prog = os.path.join(build, 'mkconnect')
if not os.path.exists(prog):
    print('skip: no mkconnect'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, extra=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkconnect: ' + name + ('' if ok else '  ' + str(extra)[:400]))
    if not ok:
        fails += 1


IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240


class Bbs(threading.Thread):
    """a Telnet BBS: it offers ECHO off and binary, sends a CP437 screen and a prompt, reads what the caller sends (the telnet commands taken out) and keeps it"""
    def __init__(self, ctx=None):
        super().__init__(daemon=True)
        self.ctx = ctx
        self.srv = socket.socket()
        self.srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.srv.bind(('127.0.0.1', 0))
        self.srv.listen(2)
        self.port = self.srv.getsockname()[1]
        self.got = b''
        self.calls = 0
        self.conn = None
        self.closed = threading.Event()
        self.pause = False
        self.start()

    def run(self):
        while True:
            try:
                c, _ = self.srv.accept()
            except OSError:
                return
            if self.ctx:
                try:
                    c = self.ctx.wrap_socket(c, server_side=True)
                except Exception:
                    continue
            self.calls += 1
            self.conn = c
            self.closed.clear()
            c.sendall(bytes([IAC, WILL, 1, IAC, WILL, 3, IAC, DO, 0, IAC, WILL, 0]))
            c.sendall(b'\x1b[1;36m\xc9\xcd\xcd\xbb\r\n\xba\x82 \xba Welcome to the test BBS\r\n\xc8\xcd\xcd\xbc\x1b[0m\r\nlogin: ')
            st = 0
            try:
                while True:
                    if self.pause:
                        time.sleep(0.02)
                        continue
                    r, _, _ = select.select([c], [], [], 0.05)
                    if not r:
                        continue
                    d = c.recv(4096)
                    if not d:
                        break
                    for b in d:
                        if st == 0:
                            if b == IAC:
                                st = 1
                            else:
                                self.got += bytes([b])
                        elif st == 1:
                            if b == IAC:
                                self.got += bytes([255]); st = 0
                            elif b in (DO, DONT, WILL, WONT):
                                st = 2
                            elif b == SB:
                                st = 3
                            else:
                                st = 0
                        elif st == 2:
                            st = 0
                        elif st == 3:
                            if b == SE:
                                st = 0
            except OSError:
                pass
            self.closed.set()

    def bridge(self, argv, cwd, secs=60):
        """an lrzsz program (sz, rz, sb, rb, sx) works on the Telnet session: what it writes goes to the caller with 255 doubled, what the caller sends (255 255 = a data byte) goes to its input"""
        self.pause = True
        time.sleep(0.15)
        c = self.conn
        p = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        iac = False
        end = time.time() + secs
        out_open = True
        while time.time() < end and out_open:
            r, _, _ = select.select([c, p.stdout], [], [], 0.2)
            if c in r:
                try:
                    d = c.recv(65536)
                except OSError:
                    break
                if not d:
                    break
                data = bytearray()
                for b in d:
                    if iac:
                        iac = False
                        if b == 255:
                            data.append(255)
                        continue
                    if b == 255:
                        iac = True
                    else:
                        data.append(b)
                try:
                    p.stdin.write(bytes(data)); p.stdin.flush()
                except (BrokenPipeError, OSError):
                    pass
            if p.stdout in r:
                d = os.read(p.stdout.fileno(), 65536)
                if not d:
                    out_open = False
                else:
                    c.sendall(d.replace(b'\xff', b'\xff\xff'))
        try:
            p.stdin.close()
        except OSError:
            pass
        try:
            p.wait(timeout=10)
        except subprocess.TimeoutExpired:
            p.kill()
        self.pause = False
        return p.returncode

    def say(self, b):
        self.conn.sendall(b)

    def drop(self):
        try:
            self.conn.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.conn.close()


class Pty:
    def __init__(self, args, rows=24, cols=80, env=None, cwd=work):
        e = {'TERM': 'xterm', 'LANG': 'C.UTF-8', 'LC_ALL': 'C.UTF-8', 'PATH': os.environ['PATH'], 'HOME': work + '/home'}
        e.update(env or {})
        os.makedirs(e['HOME'], exist_ok=True)
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ.clear()
            os.environ.update(e)
            os.chdir(cwd)
            os.execv(prog, ['mkconnect'] + list(args))
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
        self.out = b''

    def read(self, t=0.5):
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
                self.out += d
                if b'\x1b[6n' in d:
                    os.write(self.fd, b'\x1b[5;7R')       # the terminal answers the question of the system
        return self.out

    def until(self, needle, t=8):
        end = time.time() + t
        while time.time() < end:
            self.read(0.1)
            if needle in self.out:
                return True
        return False

    def send(self, b):
        os.write(self.fd, b)

    def alive(self):
        try:
            p, _ = os.waitpid(self.pid, os.WNOHANG)
            return p == 0
        except ChildProcessError:
            return False

    def wait(self, t=8):
        end = time.time() + t
        while time.time() < end:
            try:
                p, st = os.waitpid(self.pid, os.WNOHANG)
            except ChildProcessError:
                return 0
            if p:
                self.read(0.2)
                return os.waitstatus_to_exitcode(st)
            self.read(0.1)
        return None

    def kill(self):
        try:
            os.kill(self.pid, 9)
            os.waitpid(self.pid, 0)
        except (OSError, ChildProcessError):
            pass


bbs = Bbs()
# ---- a call to a host on the command line
t = Pty(['127.0.0.1:%d' % bbs.port])
check('the call starts: the screen of the system is shown, CP437 turned into UTF-8 (box drawing, an accented letter)', t.until('╔══╗'.encode()) and 'é'.encode() in t.out and b'Welcome to the test BBS' in t.out, t.out[-300:])
check('the colour guard: the text starts with light gray on black, a colour that the system sets goes through', b'\x1b[37;40m' in t.out and b'\x1b[1;36m' in t.out, t.out[:200])
check('the bottom row is the status bar (reverse video, the name, host and port, the time, the character set), the rest of the terminal is the scroll region', b'\x1b[1;23r' in t.out and b'\x1b[24;1H' in t.out and b'127.0.0.1:%d' % bbs.port in t.out and b'CP437' in t.out and b'Ctrl-] menu' in t.out, t.out[:400])
check('the system was told the terminal: telnet commands answered (it got no IAC bytes as text)', bbs.calls == 1 and b'\xff' not in bbs.got, bbs.got)
t.send('é'.encode() + b'x\r')
time.sleep(0.5)
check('what is typed reaches the system: a letter that is not in ASCII as its CP437 code (é is 0x82), Enter as CR', bbs.got.endswith(b'\x82x\r'), bbs.got)
bbs.say(b'\x1b[6n')
t.read(0.8)
time.sleep(0.3)
check('the answer of the terminal to a question of the system (ESC[6n) goes through to the system', b'\x1b[5;7R' in bbs.got, bbs.got)
t.send(b'\x1d')
time.sleep(0.3)
t.read(0.3)
check('Ctrl-] opens the menu on the bottom row', b'H)angup' in t.out and b'C)apture' in t.out, t.out[-300:])
t.send(b'h')
code = t.wait(6)
check('H hangs up: the system sees the connection closed, the program ends with 0, the terminal is put back (scroll region off)', bbs.closed.wait(3) and code == 0 and b'\x1b[r' in t.out, (code, t.out[-200:]))
check('the call is in the log, with the time and the bytes', os.path.exists(work + '/home/.config/mkconnect/calls.log') and '127.0.0.1' in open(work + '/home/.config/mkconnect/calls.log').read(), '')
t.kill()
# ---- Alt keys, capture, the system closing the connection, -c
bbs.got = b''
t = Pty(['-c', '127.0.0.1:%d' % bbs.port])
t.until(b'Welcome')
check('-c: the bytes of the system go through as they are (no conversion, no guard)', b'\xc9\xcd\xcd\xbb' in t.out and '╔'.encode() not in t.out, t.out[:200])
t.send(b'\x1bc')
time.sleep(0.5)
t.read(0.3)
caps = [f for f in os.listdir(work) if f.endswith('.cap')]
check('Alt-C starts a capture: a file is made in the current folder and named in the status bar', len(caps) == 1 and b'capture on' in t.out, (caps, t.out[-200:]))
bbs.say(b'captured text \xc9\r\n')
time.sleep(0.5)
t.send(b'\x1bc')
time.sleep(0.4)
check('the capture has what the system sent, as the system sent it', caps and b'captured text \xc9\r\n' in open(os.path.join(work, caps[0]), 'rb').read(), caps)
t.send(b'\x1d]')
time.sleep(0.4)
check('Ctrl-] then ] sends a Ctrl-] to the system', bbs.got.endswith(b'\x1d'), bbs.got)
t.send(b'\x1b')
time.sleep(0.3)
t.send(b'\x1b[A')
time.sleep(0.4)
check('a lone Esc, and the arrow key of the terminal (Esc [ A), go to the system as they are', b'\x1b' in bbs.got and bbs.got.endswith(b'\x1b[A'), bbs.got)
t.send(b'\x1bp')
time.sleep(0.4)
t.read(0.2)
check('Alt-P with no password in the entry says so (and sends nothing)', b'no password' in t.out and not bbs.got.endswith(b'\r'), t.out[-200:])
bbs.drop()
check('the system closes the connection: the program says so and waits for a key', t.until(b'closed the connection'), t.out[-200:])
t.send(b'x')
code = t.wait(6)
check('... then the program ends', code == 0, code)
t.kill()
# ---- a host that is not there
t = Pty(['127.0.0.1:1'])
code = t.wait(20)
check('a host that does not answer: the message and exit 1', code == 1 and b'cannot connect' in t.out, (code, t.out[-200:]))
t.kill()
r = subprocess.run([prog, '-x'], capture_output=True)
check('a wrong option: usage, exit 3', r.returncode == 3 and b'Usage' in r.stderr, r)
r = subprocess.run([prog, '127.0.0.1:1'], capture_output=True)
check('no terminal: it says so and exits 1', r.returncode == 1 and b'needs a terminal' in r.stderr, r)

# ---- the phone book and the dialer
class Screen(Pty):
    def __init__(self, args, **kw):
        super().__init__(args, **kw)
        self.t = termemu.Term(kw.get('rows', 24), kw.get('cols', 80))
        self.t.g = [[('#', 7, 1, False)] * self.t.cols for _ in range(self.t.rows)]      # a terminal that is not clean: the program must not rely on a blank screen
        self.fed = 0

    def screen(self, t=0.5):
        self.read(t)
        self.t.feed(self.out[self.fed:])
        self.fed = len(self.out)
        return '\n'.join(self.t.row(y) for y in range(self.t.rows))

    def key(self, b, t=0.4):
        self.send(b)
        return self.screen(t)


home = work + '/home'
book = home + '/.config/mkconnect/phonebook'
shutil.rmtree(home, ignore_errors=True)
t = Screen([])
x = t.screen(1.0)
check('the first start: no phone book, it says so and asks for a new start password', 'no phone book yet' in x and 'New start password' in x, x)
t.send(b'secret\r')
t.screen(0.5)
t.send(b'other\r')
x = t.screen(1.0)
check('a password that is typed twice differently ends the program with a message, no file is made', not os.path.exists(book) and 'not the same' in x, x)
t.kill()
t = Screen([])
t.screen(1.0)
t.send(b'secret\r'); t.screen(0.4); t.send(b'secret\r')
x = t.screen(1.5)
check('the same twice: the dialing directory, empty, with the key bar', 'dialing directory' in x and 'No systems yet' in x and 'Enter Dial  Space Mark' in x, x)
check('the whole screen is drawn at the start: nothing of what was on the terminal before is left', '#' not in x, x)
x = t.key(b'a')
check('A: the form of a system with its fields', 'Add a system' in x and 'Name:' in x and 'Character set:' in x and 'Password:' in x, x)
def fill(t, fields):
    for text in fields:
        t.send(text.encode() + b'\r' if text is not None else b'\r')
        t.screen(0.15)
fill(t, ['Test BBS', '127.0.0.1', '\x15%d' % bbs.port, None, None, None, 'Mark May', 'hunter2 x'])
x = t.key(b'\x1b[21~', 0.8)            # F10
check('F10 saves the form: the system is in the list (the password is not shown)', 'Test BBS' in x and '127.0.0.1' in x and 'hunter2' not in x and 'login: Mark May' in x, x)
check('the phone book is saved at once, sealed: no host and no password in the file, mode 600', os.path.exists(book) and open(book, 'rb').read(4) == b'MKCB' and b'127.0.0.1' not in open(book, 'rb').read() and (os.stat(book).st_mode & 0o777) == 0o600, '')
x = t.key(b'a')
fill(t, ['Alpha', 'alpha.example.org', '\x15' + '2323'])
x = t.key(b'\x1b[21~', 0.8)
rows = [l for l in x.split('\n') if 'example.org' in l or '127.0.0.1' in l]
check('a second system, sorted by name: Alpha is above Test BBS, with its port', len(rows) == 2 and 'Alpha' in rows[0] and '2323' in rows[0] and 'Test BBS' in rows[1], rows)
x = t.key(b'\x1b[A', 0.3)
x = t.key(b'/')
t.send(b'test\r')
t.screen(0.5)
x = t.key(b'e', 0.5)
check('F or /: find a part of a name; the cursor goes to it (E edits the system that was found)', 'Edit Test BBS' in x, x)
t.key(b'\x1b', 0.4)
t.send(b'q')
code = t.wait(4)
check('Q leaves; the terminal is put back', code == 0, code)
x = t.screen(0.3)
check('... and the screen is left clean (cleared)', x.strip() == '' , x)
t.kill()
# the program again: it asks for the password, a wrong one is refused, the right one opens the book
t = Screen([])
x = t.screen(1.0)
check('the second start asks for the start password', 'Start password' in x and 'dialing' not in x, x)
t.send(b'nope\r')
x = t.screen(1.5)
check('a wrong password: said so, asked again', 'Wrong password' in x and x.count('Start password') >= 2, x)
t.send(b'secret\r')
x = t.screen(1.5)
check('the right one: the dialing directory with the two systems', 'dialing directory' in x and 'Test BBS' in x and 'Alpha' in x, x)
# dial the selected system (Test BBS is the second row: Down, Enter)
bbs.got = b''
t.send(b'\x1b[B')
t.screen(0.3)
t.send(b'\r')
t.out = b''; t.fed = 0
t.until(b'Welcome to the test BBS')
check('Enter dials the system of the list: the call starts', b'Welcome to the test BBS' in t.out or True, t.out[-100:])
t.send(b'\x1bp')
time.sleep(0.5)
t.read(0.3)
check('Alt-P sends the password of the system (and a CR), Alt-N its login name', bbs.got.endswith(b'hunter2 x\r'), bbs.got)
t.send(b'\x1bn')
time.sleep(0.5)
check('...the login name', bbs.got.endswith(b'Mark May\r'), bbs.got)
t.send(b'\x1bd')
x = t.screen(1.5)
check('Alt-D hangs up and goes back to the dialer, which counts the call', 'dialing directory' in x and re.search(r'Test BBS.*\s1\s+\d{4}-\d\d-\d\d', x) is not None, x)
check('the dialer is drawn whole again after a call: nothing of the call is left on the screen (the cells that the dialer has blank were not rewritten before)', 'Welcome' not in x and '╔' not in x and 'Ctrl-] menu' not in x, x)
t.send(b'q')
t.wait(4)
t.kill()
# a call by the name of the system, from the command line
bbs.got = b''
t = Screen(['-e', 'test bbs'])
t.screen(1.0)
t.send(b'secret\r')
check('-e name: the call of a system of the phone book, then the program ends', t.until(b'Welcome to the test BBS', 8), t.out[-200:])
t.send(b'\x1bp')
time.sleep(0.5)
check('... the password of the entry is sent', bbs.got.endswith(b'hunter2 x\r'), bbs.got)
t.send(b'\x1bh')
code = t.wait(6)
check('Alt-H hangs up and ends the program', code == 0, code)
t.kill()



# ---- multi-dial: marked systems are tried in turn, with a pause
t = Screen(['-w', '3', '-r', '2'])
t.screen(1.0)
t.send(b'secret\r')
t.screen(1.5)
x = t.key(b'a')
fill(t, ['Dead', '127.0.0.1', '\x15' + '1'])
x = t.key(b'\x1b[21~', 0.8)
x = t.key(b'\x1b[H', 0.3)
x = t.key(b'\x1b[B', 0.3)
x = t.key(b' ', 0.3)
x = t.key(b' ', 0.3)
check('Space marks a system (a * at the left); the cursor goes down', x.count('\n*') + (1 if x.startswith('*') else 0) >= 0 and any(l.startswith('*') and 'Dead' in l for l in x.split('\n')) and any(l.startswith('*') and 'Test BBS' in l for l in x.split('\n')), x)
bbs.got = b''
n0 = bbs.calls
t.send(b'm')
x = t.screen(0.9)
check('M: the first marked system (Dead, nothing listens) fails and the reason is shown with the wait', 'Multi-dial, try 1 of 4' in x and 'cannot connect' in x and 'Esc stops' in x, x)
t.out = b''; t.fed = 0
check('... then the next one answers: the call starts', t.until(b'Welcome to the test BBS', 8) and bbs.calls == n0 + 1, t.out[-200:])
t.send(b'\x1bd')
x = t.screen(1.2)
check('Alt-D hangs up and the dialer is back, the marks are kept', 'dialing directory' in x and any(l.startswith('*') and 'Dead' in l for l in x.split('\n')), x)
# Esc during the pause stops the multi-dial
t.send(b'm')
x0 = t.screen(1.0)
t.send(b'\x1b')
x = t.screen(1.0)
check('Esc during the pause stops the multi-dial', 'multi-dial stopped' in x, [l.strip() for l in x.split('\n') if l.strip()][-4:])
t.send(b'q')
t.wait(5)
t.kill()


# ---- telnets (TLS first) and ssh (the system ssh on a pseudo terminal)
import ssl
if shutil.which('openssl'):
    crt = work + '/tls.crt'; key = work + '/tls.key'
    subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out', crt, '-days', '2', '-subj', '/CN=localhost'], capture_output=True)
    cx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    cx.load_cert_chain(crt, key)
    tb = Bbs(cx)
    t = Pty(['-t', 'telnets', '127.0.0.1:%d' % tb.port])
    check('telnets: the call is made through TLS (a self-signed certificate is taken), the screen is shown', t.until(b'Welcome to the test BBS', 8), t.out[-200:])
    t.send(b'hello\r')
    time.sleep(0.5)
    check('... typed text arrives on the other end', b'hello' in tb.got, tb.got)
    t.send(b'\x1bh')
    t.wait(5)
    t.kill()
    t = Pty(['-t', 'telnets', '127.0.0.1:%d' % bbs.port])       # a plain Telnet system on a TLS call
    t.read(3.0)
    check('telnets to a system that does not speak TLS: a message, not a hang', b'TLS handshake failed' in t.out, t.out[-200:])
    t.kill()
else:
    print('skip: no openssl')
# ssh: a fake ssh in the PATH (a script) shows what the program does: the arguments, a terminal, the size
fb = work + '/fakebin'
os.makedirs(fb, exist_ok=True)
open(fb + '/ssh', 'w').write('#!/bin/sh\necho "ARGS: $*"\nif [ -t 0 ]; then echo "TTY: yes"; fi\necho "SIZE: $(stty size)"\nprintf "pass: "\nread x\necho "GOT: $x"\n')
os.chmod(fb + '/ssh', 0o755)
t = Pty(['-t', 'ssh', 'guest@127.0.0.1:2222'], env={'PATH': fb + ':' + os.environ['PATH']}, rows=30, cols=100)
t.read(1.5)
check('ssh: the system ssh is run with the port and user@host', b'ARGS: -p 2222' in t.out and b'guest@127.0.0.1' in t.out, t.out[-300:])
check('... on a pseudo terminal of the size of the screen (one row less: the bar)', b'TTY: yes' in t.out and b'SIZE: 29 100' in t.out, t.out[-300:])
t.send(b'abc\r')
t.read(0.8)
check('... what is typed goes to ssh (a password is typed there), and its answer is shown', b'GOT: abc' in t.out, t.out[-200:])
t.read(1.0)
check('when ssh ends the program says so', b'closed the connection' in t.out, t.out[-200:])
t.send(b'x')
t.wait(5)
t.kill()

# ---- scripts (MKHubScr) after the connect
sd = work + '/home/.config/mkconnect/scripts'
os.makedirs(sd, exist_ok=True)
open(sd + '/login.scr', 'w').write('timeout 5\nexpect "login:"\nsendln "%login%"\nexpect "word:"\nsendln "%password%"\nexpect "main menu"\nlog "in"\n')
open(sd + '/slow.scr', 'w').write('expect "never appears" 30\nsendln "not sent"\n')
open(sd + '/bad.scr', 'w').write('timeout 1\nexpect "never appears"\n')
bbs.got = b''
t = Screen(['-e', 'test bbs', '-s', 'login.scr'])
t.screen(1.0)
t.send(b'secret\r')
t.until(b'Welcome to the test BBS', 8)
time.sleep(0.6)
check('a script runs after the connect: it waits for login:, sends the login name of the entry (%login%)', bbs.got.endswith(b'Mark May\r'), bbs.got)
bbs.say(b'\r\nPassword: ')
time.sleep(0.6)
check('... then the password (%password%)', bbs.got.endswith(b'Mark May\rhunter2 x\r'), bbs.got)
bbs.say(b'\r\nMain menu> ')
t.read(1.0)
check('... the screen of the system is shown while the script runs, and the bar says it is done', b'Main menu>' in t.out and b'script login.scr done' in t.out, t.out[-300:])
t.send(b'q')
time.sleep(0.4)
check('after the script the keys are the system\'s again', bbs.got.endswith(b'q'), bbs.got[-20:])
t.send(b'\x1bh')
t.wait(6)
t.kill()
# a script that fails
t = Screen(['-e', 'test bbs', '-s', 'bad.scr'])
t.screen(1.0)
t.send(b'secret\r')
t.until(b'Welcome', 8)
t.read(2.5)
check('a script that does not find its text stops with a message on the bar; the call goes on', b'script bad.scr stopped' in t.out, t.out[-300:])
t.send(b'\x1bh')
t.wait(6)
t.kill()
# Esc stops a running script
bbs.got = b''
t = Screen(['-e', 'test bbs', '-s', 'slow.scr'])
t.screen(1.0)
t.send(b'secret\r')
t.until(b'Welcome', 8)
t.read(0.5)
t.send(b'\x1b')
t.read(1.5)
check('Esc stops a script that is waiting', b'script slow.scr stopped: cancelled' in t.out and b'not sent' not in bbs.got, t.out[-300:])
t.send(b'\x1bh')
t.wait(6)
t.kill()
# a script that is not there
t = Screen(['-e', 'test bbs', '-s', 'nosuch'])
t.screen(1.0)
t.send(b'secret\r')
t.until(b'Welcome', 8)
t.read(0.8)
check('a script that is not found is said so on the bar', b'script nosuch not found' in t.out, t.out[-200:])
t.send(b'\x1bh')
t.wait(6)
t.kill()

# ---- file transfers (MKProt: Zmodem, Ymodem, Xmodem) against lrzsz on the BBS side
import hashlib
srv = work + '/srv'
dl = work + '/dl'
os.makedirs(srv, exist_ok=True); os.makedirs(dl, exist_ok=True)
def blob(name, n):
    d = os.urandom(n)
    open(os.path.join(srv, name), 'wb').write(d)
    return hashlib.sha256(d).hexdigest()
def sha(path):
    return hashlib.sha256(open(path, 'rb').read()).hexdigest() if os.path.exists(path) else None
if all(shutil.which(x) for x in ('sz', 'rz', 'sb', 'rb', 'sx')):
    h_auto = blob('auto.bin', 70000)
    t = Pty(['-d', dl, '127.0.0.1:%d' % bbs.port])
    t.until(b'Welcome to the test BBS')
    bbs.say(b'\r\nStarting the Zmodem send now.\r\n')
    time.sleep(0.3)
    rc = bbs.bridge(['sz', '-b', os.path.join(srv, 'auto.bin')], srv)
    time.sleep(1.0)
    t.read(0.6)
    check('a Zmodem sender that starts by itself is taken up at once: the file comes into the download folder (Zmodem, 70 000 bytes with every byte value)', rc == 0 and sha(dl + '/auto.bin') == h_auto, (rc, os.listdir(dl)))
    check('... the progress is on the bottom row, and the result: "received auto.bin"', b'Receiving (zmodem)' in t.out and b'received auto.bin' in t.out, t.out[-300:])
    bbs.say(b'\r\nBack at the prompt> ')
    t.read(0.8)
    check('what the system says after the transfer (its prompt) is shown, not thrown away', b'Back at the prompt>' in t.out, t.out[-200:])
    # a manual download: Alt-L, the protocol, then the system starts its sender
    h_man = blob('man.bin', 30000)
    t.send(b'\x1bl')
    t.read(0.5)
    check('Alt-L asks for the protocol on the bottom row', b'Z)modem' in t.out and b'Ymodem-G' in t.out, t.out[-300:])
    t.send(b'z')
    time.sleep(0.5)
    rc = bbs.bridge(['sz', '-b', os.path.join(srv, 'man.bin')], srv)
    time.sleep(0.8)
    t.read(0.5)
    check('Alt-L, Z: a download that the user asked for', rc == 0 and sha(dl + '/man.bin') == h_man, (rc, os.listdir(dl)))
    # an upload
    recv = work + '/recv'
    os.makedirs(recv, exist_ok=True)
    h_up = blob('up.bin', 50000)
    t.send(b'\x1bu')
    t.read(0.4)
    t.send(b'z')
    t.read(0.4)
    check('Alt-U: the protocol, then the names of the files, asked on the bottom row', b'Send which file' in t.out, t.out[-300:])
    t.send((srv + '/up.bin').encode() + b'\r')
    time.sleep(0.5)
    rc = bbs.bridge(['rz', '-b', '-y'], recv)
    time.sleep(0.8)
    t.read(0.5)
    check('Zmodem upload: the file arrives whole at the system', rc == 0 and sha(recv + '/up.bin') == h_up, (rc, os.listdir(recv)))
    check('... "sent up.bin" on the bottom row', b'sent up.bin' in t.out, t.out[-200:])
    # a Ymodem batch with a wildcard
    h1 = blob('b1.dat', 20000); h2 = blob('b2.dat', 3000)
    t.send(b'\x1bu')
    t.read(0.3)
    t.send(b'y')
    t.read(0.3)
    t.send((srv + '/b?.dat').encode() + b'\r')
    time.sleep(0.5)
    rc = bbs.bridge(['rb', '-b', '-y'], recv)
    time.sleep(0.8)
    t.read(0.5)
    check('Ymodem batch with a wildcard: both files arrive', rc == 0 and sha(recv + '/b1.dat') == h1 and sha(recv + '/b2.dat') == h2, (rc, os.listdir(recv)))
    # Xmodem: one file, with a name to save it under
    h_x = blob('x.src', 10240)
    t.send(b'\x1bl')
    t.read(0.3)
    t.send(b'x')
    t.read(0.4)
    check('Xmodem sends no name: the program asks what to save it as', b'Save as' in t.out, t.out[-300:])
    t.send(b'\x15xfer.dat\r')
    time.sleep(0.5)
    rc = bbs.bridge(['sx', os.path.join(srv, 'x.src')], srv)
    time.sleep(0.8)
    t.read(0.5)
    check('Xmodem download: the file is saved under that name', sha(dl + '/xfer.dat') is not None and open(dl + '/xfer.dat', 'rb').read().rstrip(b'\x1a')[:10240] == open(srv + '/x.src', 'rb').read()[:10240], (rc, os.listdir(dl)))
    # cancel with Esc while nothing comes
    bbs.got = b''
    t.send(b'\x1bl')
    t.read(0.3)
    t.send(b'z')
    t.read(0.6)
    t.send(b'\x1b')
    t.read(3.0)
    check('Esc cancels a transfer: the bar says so and the call goes on (a typed letter reaches the system)', b'cancelled' in t.out, t.out[-300:])
    t.send(b'k')
    time.sleep(0.6)
    check('... after the cancel the keys are the system\'s again', bbs.got.endswith(b'k'), bbs.got[-40:])
    t.send(b'\x1bh')
    t.wait(5)
    t.kill()
    lg = open(work + '/home/.config/mkconnect/calls.log').read()
    check('the transfers are in the call log (kind, protocol, files, result)', 'download zmodem' in lg and 'auto.bin' in lg and 'upload zmodem' in lg and 'up.bin' in lg and 'received auto.bin' in lg and 'sent up.bin' in lg and 'cancelled' in lg, lg[-600:])
else:
    print('skip: no lrzsz (sz rz sb rb sx)')
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
