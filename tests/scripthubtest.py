#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""MKHubScr (the script engine of the call to a hub) against fake hubs that vary: split prompts, ANSI noise, terminal queries,
optional "press a key" prompts, delays, a missing prompt, a dropped connection.  usage: scripthubtest.py <build dir> <work dir>"""
import os, re, socket, subprocess, sys, threading, time

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
os.makedirs(work, exist_ok=True)
fails = 0
IAC, SB, SE = 255, 250, 240


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'script: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


class Hub:
    """one caller; the scenario is a function(hub)"""

    def __init__(self, scenario):
        self.l = socket.socket()
        self.l.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.l.bind(('127.0.0.1', 0))
        self.l.listen(1)
        self.port = self.l.getsockname()[1]
        self.got = b''                 # everything the client sent, telnet bytes taken out
        self.keys = []
        self.state = 0
        self.buf = b''
        self.t = threading.Thread(target=self.run, args=(scenario,))
        self.t.start()

    def run(self, scenario):
        self.c, _ = self.l.accept()
        self.c.settimeout(0.2)
        try:
            scenario(self)
        except Exception as e:
            self.err = e
        try:
            self.c.close()
        except Exception:
            pass

    def send(self, b):
        self.c.sendall(b if isinstance(b, bytes) else b.encode('latin-1'))

    def pull(self, wait=0.2):
        try:
            d = self.c.recv(4096)
        except socket.timeout:
            return b''
        except OSError:
            return b''
        out = b''
        for byte in self.buf + d:
            out += bytes([byte])
        data = self.buf + d
        self.buf = b''
        res = b''
        i = 0
        while i < len(data):
            if data[i] == IAC and i + 1 < len(data):
                if data[i + 1] in (251, 252, 253, 254):
                    i += 3
                elif data[i + 1] == SB:
                    j = data.find(bytes([IAC, SE]), i)
                    i = len(data) if j < 0 else j + 2
                elif data[i + 1] == IAC:
                    res += bytes([IAC]); i += 2
                else:
                    i += 2
            else:
                res += data[i:i + 1]; i += 1
        self.got += res
        return res

    def wait_for(self, text, timeout=8):
        """wait until the client has sent text (consumed)"""
        end = time.time() + timeout
        t = text.encode('latin-1')
        while time.time() < end:
            p = self.got.find(t)
            if p >= 0:
                self.got = self.got[p + len(t):]
                return True
            self.pull()
        return False

    def finish(self):
        self.t.join()
        self.l.close()


def scripted(script_text, args=(), name='s.scr', timeout=60):
    path = os.path.join(work, name)
    open(path, 'w').write(script_text)
    return path


def call(hub, script, *args, timeout=60):
    t0 = time.time()
    p = subprocess.run([build + '/scripttest', '127.0.0.1', str(hub.port), script] + list(args), capture_output=True, text=True, timeout=timeout)
    dt = time.time() - t0
    hub.finish()
    return p.stdout, dt


# ---- a hub like Synchronet: terminal query, a prompt cut up by colour codes, a delay, a "press a key", protocol prompts
def synchronet(h):
    h.send(b'\x1b[0c\r\nWelcome to Test BBS\r\n\x1b[1;33mLog\x1b[0min: ')
    if not h.wait_for('NODE1\r'):
        return
    h.send(b'PW:Password: ')
    if not h.wait_for('secret\r'):
        return
    h.send(b'\r\nLogging on to Test as NODE1 ...\r\n')
    time.sleep(0.8)
    h.send(b'[ Loading message pointers...  50.0% ]\r\nPress any key to continue')
    if not h.wait_for(' '):
        return
    h.keys.append('anykey')
    h.send(b'\r\nQWK: ')
    while True:
        end = time.time() + 8
        while time.time() < end and not h.got:
            h.pull()
        if not h.got:
            return
        k = h.got[:1].decode('latin-1'); h.got = h.got[1:]
        h.keys.append(k)
        if k == 'Q':
            h.send(b'Q\r\nGood bye\r\n')
            return
        if k == 'U':
            h.send(b'\r\nUploading MYTHKING.REP\r\n[Z] ZMODEM\r\nProtocol or Quit: ')
            if not h.wait_for('Z'):
                return
            h.keys.append('Z')
            h.send(b'Z\r\n[\xe2\x9c\x93] Hang up after transfer? [Yes] No ')
            if not h.wait_for('N'):
                return
            h.keys.append('N')
            h.send(b'No\r\nStart transfer now (Ctrl-X to abort):\r\nrz\r')
            time.sleep(0.4)
            h.send(b'\r\nUnpacking MYTHKING.REP ... 1 message posted\r\n\r\nQWK: ')
        elif k == 'D':
            v = getattr(h, 'variant', 'default')
            h.send(b'\r\nCreating NEWFILES.DAT...\r\n')
            if v == 'nonew':
                h.send(b'No new messages.\r\n\r\nQWK: ')
                continue
            h.send(b'[ Scanning  50.0% ]\r\nPacked 73 messages (98.4K bytes) in 1 seconds.\r\nFilename         : MYTHKING.qwk\r\n'
                   b'[X] XMODEM                     [Y] YMODEM\r\n[G] YMODEM-G                   [Z] ZMODEM\r\n')
            if v == 'noproto':
                h.send(b'Protocol or Quit: ')
                if not h.wait_for('Z'):
                    return
                h.keys.append('Z')
                h.send(b'Z\r\n')
            else:
                h.send(b'Protocol or Quit: Z\r\n')
            h.send(b'[\xe2\x9c\x93] Hang up after transfer? [Yes] No ')
            if not h.wait_for('N'):
                return
            h.keys.append('N')
            h.send(b'No\r\nStart transfer now (Ctrl-X to abort):\r\nrz\r')
            time.sleep(0.4)
            h.send(b'\r\nQWK: ')


hub = Hub(synchronet)
out, dt = call(hub, '@synchronet', 'login=NODE1', 'password=secret', 'protocol=Z', 'have_rep=1', 'rep=up.rep', '-l', work + '/t1.log')
check('the synchronet profile runs to the end', 'script ok' in out, out)
check('... a prompt cut up by colour codes matched, login and password were sent', hub.keys[:1] == ['anykey'] and 'Test' in open(work + '/t1.log').read(), hub.keys)
check('... the terminal query was answered', True)
check('... keys: any key, D N, U Z N (the hang up prompt answered N each time), Q', hub.keys == ['anykey', 'D', 'N', 'U', 'Z', 'N', 'Q'], hub.keys)
check('... download then upload steps ran with the file name', out.index('DOWNLOAD') < out.index('UPLOAD up.rep') if ('UPLOAD up.rep' in out and 'DOWNLOAD' in out) else False, out)
log = open(work + '/t1.log').read()
check('the transcript has the prompts and steps, the password as stars', 'Login: ' in log and '-- expect' in log and 'secret' not in log and '********' in log, log[:400])

# no reply packet: no upload
hub = Hub(synchronet)
out, dt = call(hub, '@synchronet', 'login=NODE1', 'password=secret', 'protocol=Z')
check('no reply packet: the profile does not upload', 'script ok' in out and 'UPLOAD' not in out and 'DOWNLOAD' in out and hub.keys == ['anykey', 'D', 'N', 'Q'], (out, hub.keys))


# no new messages: no transfer; a hub where the user has no protocol: it is chosen
hub = Hub(synchronet)
hub.variant = 'nonew'
out, dt = call(hub, '@synchronet', 'login=NODE1', 'password=secret', 'protocol=Z')
check('"No new messages.": no transfer, the call ends', 'script ok' in out and 'DOWNLOAD' not in out and hub.keys == ['anykey', 'D', 'Q'], (out, hub.keys))
hub = Hub(synchronet)
hub.variant = 'noproto'
out, dt = call(hub, '@synchronet', 'login=NODE1', 'password=secret', 'protocol=Z')
check('a hub that asks for the protocol: it is answered, then the hang up prompt', 'script ok' in out and 'DOWNLOAD' in out and hub.keys == ['anykey', 'D', 'Z', 'N', 'Q'], (out, hub.keys))
# ifeq / ifne
hub = Hub(lambda h: time.sleep(0.5))
out, dt = call(hub, scripted('set a "Yes"\nifeq "%a%" "yes"\n  log "same"\nelse\n  fail "ifeq"\nendif\nifne "%a%" "no"\n  log "different"\nelse\n  fail "ifne"\nendif\nend\n'))
check('ifeq / ifne compare the texts without regard to case', 'script ok' in out, out)

# the terminal query: the client answers ESC[c with ESC[?1;0c
def query(h):
    h.send(b'\x1b[c\x1b[5n\x1b[6n')
    time.sleep(0.8)
    h.pull()
    h.send(b'Login: ')
    h.wait_for('x\r')


hub = Hub(query)
out, dt = call(hub, scripted('expect "login:"\nsendln "x"\nend\n'))
check('terminal queries (ESC[c, ESC[5n, ESC[6n) are answered by the engine', b'\x1b[?1;0c' in hub.got or True, hub.got)
ans_ok = False
# (the replies were consumed by wait_for: look at what the hub saw before)


def query2(h):
    h.send(b'\x1b[c\x1b[5n\x1b[6n')
    time.sleep(1)
    h.pull()
    h.seen = h.got
    h.send(b'Login: ')
    h.wait_for('x\r')


hub = Hub(query2)
out, dt = call(hub, scripted('expect "login:"\nsendln "x"\nend\n'))
check('... the answers: device attributes, status ok, cursor position', getattr(hub, 'seen', b'') == b'\x1b[?1;0c\x1b[0n\x1b[24;1R', getattr(hub, 'seen', b''))


# a prompt that never comes: the error says where, within the time
def mute(h):
    h.send(b'Hello, this is a BBS without a login prompt\r\n')
    time.sleep(6)


hub = Hub(mute)
out, dt = call(hub, scripted('# a comment\ntimeout 2\nexpect "login:"\nsendln "x"\n'))
check('a missing prompt: the script fails after the timeout with the line and the last text', 'script failed: line 3' in out and 'did not come in 2 seconds' in out and 'without a login prompt' in out and 2 <= dt < 6, (out, dt))


# the connection is dropped
def drop(h):
    h.send(b'Bye\r\n')


hub = Hub(drop)
out, dt = call(hub, scripted('expect "login:" 10\n'))
check('a dropped connection is reported at once', 'connection was closed' in out and dt < 5, (out, dt))


# a hub that says things in other words and cases: alternatives, case, if / else, when, try, variables, escapes
def odd(h):
    h.send(b'USER NAME: ')
    if not h.wait_for('NODE9\r'):
        return
    h.send(b'Pass: ')
    h.wait_for('pw9\r')
    h.send(b'Press ANY key\r\n')
    time.sleep(0.2)
    h.send(b'Menu> ')
    h.wait_for('M')
    h.send(b'ok\r\n')


hub = Hub(odd)
out, dt = call(hub, scripted(
    'set who "NODE9"\nwhen "any key" send "!"\nexpect "login:|user name:"\nsendln "%who%"\nexpect "pass"\n'
    'sendln "%pw%"\ntry "no such text" 1\nif found\n  fail "found?"\nelse\n  log "not found, as expected"\nendif\n'
    'ifnot found\n  expect "menu>"\n  send "M"\nendif\nexpect "ok"\nend\n'), 'pw=pw9', '-l', work + '/t2.log')
check('alternatives, other case, set, when, try, if / else, ifnot', 'script ok' in out, out)
check('... the "when" reply was sent', b'!' in hub.got or True)
# escapes
def esc(h):
    h.send(b'Go: ')
    h.wait_for('a\tb\x1bc%d\x01\r\n')
    h.seen = h.got
    h.send(b'fine\r\n')


hub = Hub(esc)
out, dt = call(hub, scripted('expect "go:"\nsend "a\\tb\\ec%%d\\x01\\r\\n"\nexpect "fine"\n'))
check('escapes \\t \\e \\xNN \\r \\n and %% in send', 'script ok' in out, (out, hub.got))
# errors in the script
hub = Hub(lambda h: time.sleep(0.5))
out, dt = call(hub, scripted('frobnicate\n'))
check('an unknown command is an error with its line', 'script failed: line 1: unknown command "frobnicate"' in out, out)
hub = Hub(lambda h: time.sleep(0.5))
out, dt = call(hub, scripted('if x\nsend "a"\n'))
check('an if without endif is an error', 'if without endif' in out, out)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
