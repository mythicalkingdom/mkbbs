#!/usr/bin/env python3
"""Menu command 174 (multi-node chat, MCHAT-PLAN.md) in the real mk over telnet, two nodes at once, on a private copy of the sample BBS: off by default, the level
and the ban list, lines of both nodes, joins and leaves, /who, /msg, /me, /ignore, control characters dropped, the word file, the flood limit, chat.log.
usage: mchattest.py <build dir> <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
srcmenus = os.path.join(repo, 'bbs', 'bbsc', 'myth', 'menus')
if not (os.path.isdir(src) and os.path.isdir(srcmenus)) or not os.path.exists(build + '/mk'):
    print('skip: no sample BBS'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
menus = tmp + '/m'
ign = lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'chat.mk')) or not os.access(os.path.join(d, f), os.R_OK)]
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=ign)
cfgpatch.fix_sample(ra)
shutil.copytree(cfgpatch.snapshot(srcmenus), menus, ignore=ign)
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'multichat: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


cj = os.path.join(work, 'cj'); os.makedirs(cj)
envj = dict(os.environ, MK=ra, MKJSON=cj)
os.makedirs(ra + '/temp', exist_ok=True)


def configure(chat):
    """the chat settings of the BBS (None: no chat.mk at all)"""
    subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
    dj = json.load(open(os.path.join(cj, 'bbsconfig.json'), encoding='utf-8'))
    dj['config']['TempPath'] = ra + '/temp/'
    if chat is not None:
        dj['chat'].update(chat)
    json.dump(dj, open(os.path.join(cj, 'bbsconfig.json'), 'w', encoding='utf-8'), ensure_ascii=False)
    subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)


# the top menu gets an item for command 174
path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
used = {chr(d[i * REC + 7 + 1 + 75]).upper() for i in range(1, len(d) // REC) if d[i * REC] != 0}
KEY = [k for k in 'WXYZ1234567ABCDEFGHJKLNOPQRSTUV890' if k not in used][0]
slot = 1
while slot * REC < len(d) and d[slot * REC] != 0:
    slot += 1
if (slot + 1) * REC > len(d):
    d += bytes((slot + 1) * REC - len(d))
r = bytearray(REC)
r[0] = 174
prompt = b'CHAT'
r[7] = len(prompt); r[8:8 + len(prompt)] = prompt
r[7 + 76] = ord(KEY)
r[REC - 2] = 15; r[REC - 1] = 0
d[slot * REC:(slot + 1) * REC] = r
open(path, 'wb').write(d)

cfg = {'mk': build + '/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-4', 'mkmon': build + '/mkmon',
       'ports': [{'port': 24681, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}, {'port': 24682, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'sesame'}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = None


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def show(b):
    return b[-400:].decode('latin-1').replace('\r', '\\r').replace('\n', '\\n')


class Caller:
    def __init__(self):
        for _ in range(50):
            try:
                self.s = socket.create_connection(('127.0.0.1', 24681))
                break
            except OSError:
                time.sleep(0.1)
        self.s.sendall(bytes([255, 251, 0, 255, 253, 0]))
        self.buf = b''
        self.until(b'language choice', 10)
        time.sleep(1.5); self.s.sendall(b'\r')
        self.until(b'last name: ', 10); time.sleep(2.5)
        self.s.sendall(b'Mark May\r'); self.until(b'assword'); time.sleep(0.5); self.s.sendall(b'windows\r')
        x = b''
        for _ in range(8):
            x = self.until(b'zzzz', 3)
            if b'continue' in x or b'Enter' in x:
                self.s.sendall(b'\r')
            else:
                break
        self.at_menu = b'Command >' in x

    def until(self, needle, secs=8):
        """read until the needle is in what came since the last call (returns everything of that time)"""
        self.s.settimeout(0.2)
        b = b''
        mores = 0
        end = time.time() + secs
        while time.time() < end and needle not in strip(b):
            try:
                d = self.s.recv(4096)
                if not d:
                    break
                b += d
                if b'\x1b[6n' in d:
                    self.s.sendall(b'\x1b[1;1R')
                if strip(b).count(b'More? (Y)es (N)o (C)ontinuous?') > mores:
                    mores += 1
                    self.s.sendall(b'c')
            except socket.timeout:
                pass
        return strip(b)

    def line(self, text):
        self.s.sendall(text.encode('latin-1') + b'\r')

    def close(self):
        self.s.close()


def start():
    global lst
    stop()
    lst = subprocess.Popen([build + '/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)
    time.sleep(1.5)


def stop():
    global lst
    if lst:
        lst.terminate(); lst.wait()
        lst = None
        time.sleep(0.5)


def logtext():
    p = os.path.join(os.path.dirname(cfgpatch.log_file(ra)), 'chat.log')
    return open(p, encoding='latin-1').read() if os.path.exists(p) else ''


try:
    # 1. no chat.mk: off
    configure(None)
    start()
    a = Caller()
    check('caller logged in', a.at_menu)
    a.s.sendall(KEY.encode())
    b = a.until(b'not available', 6)
    check('chat is off by default: "Multi-node chat is not available."', b'Multi-node chat is not available.' in b, show(b))
    a.s.sendall(b'\r'); a.until(b'Command >', 5)
    check('... and the room has no files (nothing was created)', not os.path.exists(work + '/run/chat'))
    a.close()

    # 2. on, level too high
    configure({'Enabled': True, 'MinLevel': 60000, 'ShowHandle': False})
    a = Caller()
    a.s.sendall(KEY.encode())
    b = a.until(b'too low', 6)
    check('on, but the level is too low: said so', b'Your security level is too low for chat.' in b, show(b))
    a.close()

    # 3. on, banned
    configure({'Enabled': True, 'MinLevel': 0, 'ShowHandle': False})
    open(ra + '/chatban.lst', 'w').write('# banned\nmark may\n')
    a = Caller()
    a.s.sendall(KEY.encode())
    b = a.until(b'may not use chat', 6)
    check('a name on chatban.lst (any case) may not join', b'You may not use chat.' in b, show(b))
    a.close()
    os.remove(ra + '/chatban.lst')

    # 4. two nodes in the room
    open(work + '/words.txt', 'w').write('# words\nbadword\n')
    configure({'Enabled': True, 'MinLevel': 0, 'ShowHandle': False, 'WordFile': work + '/words.txt', 'FloodLines': 4, 'FloodSecs': 20, 'MuteMinutes': 1, 'RoomName': 'Test Room'})
    a = Caller(); b_ = Caller()
    a.s.sendall(KEY.encode())
    x = a.until(b'In the room:', 6)
    check('node 1 joins: the room name and the help hint', b'Test Room' in x and b'type /help' in x, show(x))
    time.sleep(0.5)
    b_.s.sendall(KEY.encode())
    y = b_.until(b'In the room: 2', 6)
    check('node 2 joins: two callers in the room', b'In the room: 2' in y, show(y))
    x = a.until(b'joined', 5)
    check('node 1 is told that node 2 joined', b'*** Mark May (node 2) joined' in x, show(x))
    b_.line('hello from two')
    x = a.until(b'hello from two', 5)
    y = b_.until(b'hello from two', 5)
    check('a line of node 2 is shown on node 1 as <name> text', b'<Mark May> hello from two' in x, show(x))
    check('... and on node 2 itself', b'<Mark May> hello from two' in y, show(y))
    a.line('/who')
    x = a.until(b'node 2:', 5)
    check('/who lists both nodes', b'node 1: Mark May' in x and b'node 2: Mark May' in x, show(x))
    b_.line('/msg 1 for your eyes only')
    x = a.until(b'eyes only', 5)
    y = b_.until(b'private to', 5)
    check('/msg: the receiver sees [private from ...], the sender sees [private to ...]', b'[private from Mark May (node 2)] for your eyes only' in x and b'[private to Mark May (node 1)] for your eyes only' in y, (show(x), show(y)))
    a.line('/me waves')
    x = b_.until(b'waves', 5)
    check('/me: * name action', b'* Mark May waves' in x, show(x))
    b_.line('\x1b[31mred\x07 text')
    x = a.until(b'text', 5)
    check('control characters of a caller are dropped (an escape sequence is swallowed, the bell too): no escape reaches the others', b'<Mark May> red text' in x and b'31m' not in x and b'\x1b' not in x.replace(b'\x1b[', b'') and b'\x07' not in x, show(x))
    b_.line('this is a BadWord line')
    x = a.until(b'line', 5)
    check('a word of the word file is masked with *', b'this is a ******* line' in x and b'BadWord' not in x, show(x))
    # /ignore node 2: node 1 does not see its lines, node 2 does not know
    a.line('/ignore 2')
    a.until(b'Not showing', 4)
    b_.line('you cannot see this')
    time.sleep(1.2)
    a.line('marker line')
    x = a.until(b'marker line', 5)
    check('/ignore 2: its lines are not shown on node 1 (node 1\'s own are)', b'you cannot see this' not in x and b'marker line' in x, show(x))
    # the flood limit: 4 lines in 20 s; node 2 has sent 5 already (hello, private, badword, red, ...): muted after the limit
    for i in range(6):
        b_.line('flood %d' % i)
    y = b_.until(b'muted', 6)
    check('more lines than the flood limit: the caller is told they are muted', b'you are muted for 1 minute' in y or b'You are muted' in y, show(y))
    b_.line('still here?')
    y = b_.until(b'You are muted for', 4)
    check('... and cannot speak while muted', b'You are muted for' in y, show(y))
    # leaving
    b_.line('/quit')
    y = b_.until(b'Command >', 6)
    check('/quit: back at the menu', b'Command >' in y, show(y))
    time.sleep(1)
    x = a.until(b'left', 2)
    check('node 1 (which ignores node 2) is not told that it left', b'left' not in x, show(x))
    check('the presence file of node 2 is gone, node 1 stays', not os.path.exists(work + '/run/chat/in2') and os.path.exists(work + '/run/chat/in1'))
    a.close()                                      # a hang-up leaves the room too
    time.sleep(2.5)
    check('a hang-up leaves the room as well (no presence file stays)', not os.path.exists(work + '/run/chat/in1'), os.listdir(work + '/run/chat'))
    b_.close()
    # a caller that joins later sees the last lines
    c = Caller()
    c.s.sendall(KEY.encode())
    x = c.until(b'In the room:', 6)
    check('a caller joining later sees the last lines of the room (history)', b'<Mark May> hello from two' in x and b'* Mark May waves' in x and b'[private' not in x, show(x))
    c.line('/help')
    x = c.until(b'/quit', 4)
    check('/help lists the commands', b'/who' in x and b'/msg' in x and b'/ignore' in x, show(x))
    c.line('/nonsense')
    x = c.until(b'Not a command', 4)
    check('an unknown command is said so, not sent to the room', b'Not a command: type /help' in x, show(x))
    c.close()
    time.sleep(1.5)
    t = logtext()
    check('chat.log has the lines with node and name, the private one marked, the joins and leaves', 'n2 Mark May: hello from two' in t and 'n2 Mark May -> n1 (private): for your eyes only' in t
          and 'n1 * Mark May waves' in t and 'n1 Mark May joined' in t and 'n2 Mark May left' in t, t[-800:])
    check('... the line as sent (masked, no escape characters) is what the log has', 'this is a ******* line' in t and '\x1b' not in t and '\x07' not in t, repr(t[-600:]))

    # ---- phase 3: the sysop
    configure({'Enabled': True, 'MinLevel': 0, 'ShowHandle': False, 'FloodLines': 0, 'WordFile': '', 'RoomName': 'Test Room'})
    run = work + '/run'
    ctl = lambda *a: subprocess.run([build + '/mkchatctl', '-r', run, '-c', ra] + list(a), capture_output=True, text=True)
    a = Caller(); b_ = Caller(); m = Caller()          # m stays at the menu (never joins)
    a.s.sendall(KEY.encode()); a.until(b'In the room:', 6)
    b_.s.sendall(KEY.encode()); b_.until(b'In the room: 2', 6)
    time.sleep(1)
    r = ctl('who')
    check('mkchatctl who: both nodes, name and real name', r.returncode == 0 and 'node 1: Mark May' in r.stdout and 'node 2: Mark May' in r.stdout, r.stdout + r.stderr)
    b_.line('/msg 1 a secret'); b_.until(b'private to', 4)
    r = ctl('log', '10')
    check('mkchatctl log: the lines of the room, the private one too (for the sysop)', '[private Mark May (node 2) to node 1] a secret' in r.stdout and 'joined' in r.stdout, r.stdout)
    ctl('say', 'hello from the sysop')
    x = a.until(b'hello from the sysop', 5); y = b_.until(b'hello from the sysop', 5)
    check('say: the sysop\'s line is shown in the room on both nodes as [sysop] text', b'[sysop] hello from the sysop' in x and b'[sysop] hello from the sysop' in y, (show(x), show(y)))
    ctl('notice', 'be nice')
    x = a.until(b'be nice', 5)
    check('notice: *** text', b'*** be nice' in x, show(x))
    ctl('announce', 'the BBS closes at noon')
    x = a.until(b'closes at noon', 5); y = b_.until(b'closes at noon', 5); z = m.until(b'closes at noon', 6)
    check('announce: every node sees it, in the room (both) and at the menu (a caller who never joined)', all(b'Message from the sysop: the BBS closes at noon' in v for v in (x, y, z)), (show(x), show(y), show(z)))
    ctl('announce', 'second message')
    z = m.until(b'second message', 6)
    check('... and a second one later', b'Message from the sysop: second message' in z, show(z))
    m.close()
    r = ctl('mute', '2', '1')
    y = b_.until(b'muted by the sysop', 5)
    check('mute: node 2 is told', b'You have been muted by the sysop for 1 minute(s).' in y, show(y))
    b_.line('can you hear me')
    y = b_.until(b'You are muted for', 4)
    x = a.until(b'muted by the sysop for 1', 3)
    check('... node 2 cannot speak, the room is told (notice)', b'You are muted for' in y and b'*** Mark May was muted by the sysop for 1 minute(s)' in x, (show(y), show(x)))
    ctl('unmute', '2')
    y = b_.until(b'may speak again', 5)
    b_.line('free again')
    x = a.until(b'free again', 5)
    check('unmute: node 2 speaks again', b'The sysop lets you speak again.' in y and b'<Mark May> free again' in x, (show(y), show(x)))
    r = ctl('kick', '2')
    y = b_.until(b'Command >', 8)
    check('kick: node 2 is told and is back at the menu', b'You have been removed from the room by the sysop.' in y and b'Command >' in y, show(y))
    check('... and the presence file of node 2 is gone', not os.path.exists(run + '/chat/in2'))
    b_.s.sendall(KEY.encode())
    y = b_.until(b'In the room:', 6)
    check('a caller that was removed may come back', b'Test Room' in y, show(y))
    b_.s.sendall(b'/quit\r'); b_.until(b'Command >', 5)
    b_.s.sendall(KEY.encode()); b_.until(b'In the room', 5)
    r = ctl('ban', '2')
    y = b_.until(b'Command >', 8)
    check('ban: removed, the name is on chatban.lst', b'removed from the room' in y and 'Mark May' in open(ra + '/chatban.lst').read(), (show(y), r.stderr))
    b_.s.sendall(KEY.encode())
    y = b_.until(b'may not use chat', 6)
    check('... and cannot join again', b'You may not use chat.' in y, show(y))
    b_.s.sendall(b'\r'); b_.until(b'Command >', 4)
    r = ctl('unban', 'mark may')
    check('unban: the name is off the list', r.returncode == 0 and 'Mark May' not in open(ra + '/chatban.lst').read() and ctl('bans').stdout.strip() == '', r.stdout + r.stderr)
    r = ctl('mute', '9')
    check('a node that is not in the room is refused', r.returncode == 1 and 'not in the room' in r.stderr, r.stderr)
    # the sysop monitor
    sm = socket.create_connection(('127.0.0.1', 24682)); sm.settimeout(0.3)
    def mon(needle, secs=6):
        buf = b''
        end = time.time() + secs
        while time.time() < end and needle not in buf:
            try:
                d = sm.recv(8192)
                if not d:
                    break
                buf += d
                if b'\x1b[6n' in d:
                    sm.sendall(b'\x1b[1;1R')
            except socket.timeout:
                pass
        return strip(buf)
    mon(b'Password: '); sm.sendall(b'sesame\r'); mon(b'H chat room')
    sm.sendall(b'H')
    x = mon(b'node 1', 6)
    check('mkmon H: the chat screen with the room and who is in it', b'multi-node chat' in x and b'be nice' in x and b'node 1' in x and b'free again' in x, show(x))
    sm.sendall(b'A'); mon(b'To every node:', 4); sm.sendall(b'from mkmon\r')
    y = a.until(b'from mkmon', 6)
    check('mkmon A: a message to every node reaches the callers', b'Message from the sysop: from mkmon' in y, show(y))
    sm.sendall(b'T'); mon(b'Say in the room:', 4); sm.sendall(b'typed in mkmon\r')
    y = a.until(b'typed in mkmon', 6)
    check('mkmon T: a line of the sysop in the room', b'[sysop] typed in mkmon' in y, show(y))
    sm.sendall(b'K'); mon(b'Remove node', 4); sm.sendall(b'y')
    x = a.until(b'Command >', 8)
    check('mkmon K: the chosen caller is removed (node 1 is the first in the list)', b'removed from the room by the sysop' in x and b'Command >' in x, show(x))
    sm.sendall(b'Q'); mon(b'R refresh', 4)
    sm.close(); a.close(); b_.close()
    time.sleep(1.5)
    t = logtext()
    check('chat.log has what the sysop did to the callers (muted, unmuted, removed)', 'Mark May muted by the sysop for 1 minute(s)' in t and 'Mark May unmuted by the sysop' in t and 'Mark May removed by the sysop' in t, t[-700:])
finally:
    stop()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
