#!/usr/bin/env python3
"""Menu command 174 (run an extension, MHOST-PLAN.md phase 2) in the real mk over telnet, two nodes at once, on a private copy of the sample BBS: off by default, the level
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
    print(('ok   ' if ok else 'FAIL ') + 'ext: ' + name + ('' if ok else '  ' + str(info)[-500:]))
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


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def show(b):
    return b[-400:].decode('latin-1').replace('\r', '\\r').replace('\n', '\\n')


class Caller:
    def __init__(self):
        for _ in range(50):
            try:
                self.s = socket.create_connection(('127.0.0.1', 24691))
                break
            except OSError:
                time.sleep(0.1)
        self.s.sendall(bytes([255, 251, 0, 255, 253, 0]))
        self.buf = b''
        self.seen = b''
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
        self.seen += strip(b)
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



# one menu item for each case; the data is the name of the extension and its arguments
path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
used = {chr(d[i * REC + 7 + 1 + 75]).upper() for i in range(1, len(d) // REC) if d[i * REC] != 0}
free = [k for k in 'WXYZ1234567ABCDEFGHJKLNOPQRSTUV890' if k not in used]
keys = {}
slot = 1
CASES = [('who', 'who'), ('args', 'args one "two words"'), ('deny', 'deny'), ('high', 'high'), ('nothere', 'nothere'), ('loop', 'loop'), ('hang', 'hang'), ('bad', 'bad')]
for name, data in CASES:
    while slot * REC < len(d) and d[slot * REC] != 0:
        slot += 1
    if (slot + 1) * REC > len(d):
        d += bytes((slot + 1) * REC - len(d))
    k = free.pop(0)
    r = bytearray(REC)
    r[0] = 175
    prompt = ('EXT ' + name).encode()
    r[7] = len(prompt); r[8:8 + len(prompt)] = prompt
    r[7 + 76] = ord(k)
    dd = data.encode()
    r[84] = len(dd); r[85:85 + len(dd)] = dd
    r[REC - 2] = 15; r[REC - 1] = 0
    d[slot * REC:(slot + 1) * REC] = r
    keys[name] = k
    slot += 1
open(path, 'wb').write(d)

os.makedirs(ra + '/scripts', exist_ok=True)
def script(n, t):
    open(ra + '/scripts/' + n, 'w').write(t)
script('who.bas', '''10 U = VAL(HOST$("bbs.user"))
20 PRINT "WHO:"; HOST$("field 1 name"); "|level"; HOST$("field 1 level"); "|ansi"; HOST$("field 1 ansi")
30 PRINT "NODE:"; HOST$("=bbs.node")
40 N = VAL(HOST$("node.list"))
50 PRINT "NODES:"; N; "|"; HOST$("field 1 user"); "|"; HOST$("field 1 type")
60 PRINT "AREAS:"; VAL(HOST$("msg.areas"))
70 PRINT "ARGC:"; HOST$("argc"); "|"; HOST$("arg 0")
80 X = VAL(HOST$("bbs.pause"))
90 PRINT "DONE"
''')
script('args.pas', '''program a;
begin
  writeln('PARAMS=', ParamCount, ' ', ParamStr(1), '|', ParamStr(2));
  writeln('ARG=', HostCall('argc'), ' ', HostCall('arg 0'), ' ', HostCall('arg 2'));
  writeln('NAME=', HostCall('=bbs.user'));
  writeln(HostCall('log.write pascal extension ran'));
  writeln(HostCall('bbs.file ../secret'));
end.
''')
script('deny.bas', '10 PRINT HOST$("user.list")\n')
script('high.bas', '10 PRINT "SHOULD NOT RUN"\n')
script('loop.bas', '10 GOTO 10\n')
script('hang.bas', '10 PRINT "BYE"\n20 X = VAL(HOST$("bbs.hangup"))\n30 PRINT "AFTER"\n')
script('bad.txt', 'x')
open(ra + '/extensions.cfg', 'w').write("""# test extensions
[who]
file = scripts/who.bas
caps = session:read session:control nodes:read msgs:read
[args]
file = scripts/args.pas
caps = session:read log:write session:control
[deny]
file = scripts/deny.bas
caps = nodes:read
[high]
file = scripts/high.bas
level = 60000
[loop]
file = scripts/loop.bas
timeout = 2
[hang]
file = scripts/hang.bas
caps = session:control
[bad]
file = scripts/bad.txt
""")

cfg = {'mk': build + '/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-4', 'ports': [{'port': 24691, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = None
configure(None)

def bbslog():
    p = cfgpatch.log_file(ra)
    return open(p, encoding='latin-1').read() if os.path.exists(p) else ''


def run(c, name, needle, secs=10):
    c.s.sendall(keys[name].encode())
    return c.until(needle, secs)


try:
    start()
    c = Caller()
    check('caller logged in', c.at_menu)
    x = run(c, 'who', b'Press (Enter) to continue', 12)
    check('BASIC extension: the caller (bbs.user), the node, the node list, the areas, the arguments',
          b'WHO:Mark May|level' in x and b'NODE:1' in x and b'NODES:' in x and b'AREAS:' in x and b'ARGC: 0|who' in x.replace(b'ARGC:0', b'ARGC: 0'), show(x))
    check('... the node list has the caller (not a script)', re.search(rb'NODES: ?\d+ ?\|Mark May\|telnet', x) is not None, show(x))
    c.s.sendall(b'\r')
    x = c.until(b'DONE', 8)
    check('... bbs.pause waited for Enter, then the program went on', b'DONE' in x, show(x))
    c.until(b'Command >', 8)
    x = run(c, 'args', b'Press (Enter) to continue', 12)
    check('Pascal extension: ParamStr and arg get the arguments (a quoted one is one word), bbs.user, log.write',
          b'PARAMS=2 one|two words' in x and b'ARG=2 args two words' in x and b'NAME=Mark May' in x, show(x))
    check('... bbs.file with a folder in the name is refused (run-time error 300)', b'bbs.file needs the name of a text file' in x, show(x))
    check('... log.write is in the BBS log', 'Ext args: pascal extension ran' in bbslog(), bbslog()[-300:])
    c.s.sendall(b'\r'); c.until(b'Command >', 8)
    x = run(c, 'deny', b'Press (Enter) to continue', 8)
    check('a call outside the capabilities of the entry is an error the caller sees, and a log line', b'not allowed: user.list needs users:read' in x and 'Ext deny: refused: not allowed: user.list needs users:read' in bbslog(), (show(x), bbslog()[-200:]))
    c.s.sendall(b'\r'); c.until(b'Command >', 8)
    x = run(c, 'high', b'Press (Enter)', 8)
    check('the level of the entry is above the caller\'s: refused, the program does not run', b'Your security level is too low for that.' in x and b'SHOULD NOT RUN' not in x and 'Ext high: refused: level' in bbslog(), show(x))
    c.s.sendall(b'\r'); c.until(b'Command >', 8)
    x = run(c, 'nothere', b'Press (Enter)', 8)
    check('a name that is not in extensions.cfg: "not available", a log line', b'That extension is not available.' in x and 'Ext nothere: not in extensions.cfg' in bbslog(), show(x))
    c.s.sendall(b'\r'); c.until(b'Command >', 8)
    x = run(c, 'bad', b'Press (Enter)', 8)
    check('an entry whose file is no .bas / .pas: "not available"', b'That extension is not available.' in x, show(x))
    c.s.sendall(b'\r'); c.until(b'Command >', 8)
    t0 = time.time()
    x = run(c, 'loop', b'Press (Enter)', 20)
    check('a program that never ends is stopped by the timeout of its entry (2 s) and the menu comes back', time.time() - t0 < 15 and b'Press (Enter)' in x, (time.time() - t0, show(x)))
    c.s.sendall(b'\r'); y = c.until(b'Command >', 8)
    check('... at the menu again', b'Command >' in y, show(y))
    x = run(c, 'hang', b'BYE', 8)
    time.sleep(2)
    c.s.settimeout(3)
    try:
        more = c.s.recv(4096)
    except (socket.timeout, OSError):
        more = b'still open'
    check('bbs.hangup ends the call (the program does not go on, the connection closes)', b'BYE' in x and b'AFTER' not in x + (more if more != b'still open' else b'') and more != b'still open', (show(x), more))
    c.close()

    # ---- phase 3: hooks
    script('hk_logon.bas', '10 PRINT "HK-LOGON|"; HOST$("arg 1"); "|"; HOST$("arg 2"); "|"; HOST$("arg 3"); "|"; HOST$("arg 4")\n')
    script('hk_menu.bas', '10 PRINT "HK-MENU|"; HOST$("arg 1"); "|"; HOST$("arg 3")\n')
    script('hk_menutop.bas', '10 PRINT "HK-MENUTOP"\n')
    script('hk_bad.bas', '10 PRINT "HK-BAD-START"\n20 PRINT HOST$("nonsense")\n')
    script('hk_slow.bas', '10 GOTO 10\n')
    script('hk_low.bas', '10 PRINT "HK-LOW-RAN"\n')
    script('hk_log.bas', '10 X = VAL(HOST$("log.write logoff hook ran; event=" + HOST$("arg 1") + " user=" + HOST$("arg 2") + " reason=" + HOST$("arg 3")))\n')
    script('hk_hang.bas', '10 PRINT "HK-HANG"\n20 X = VAL(HOST$("bbs.hangup"))\n')
    open(ra + '/extensions.cfg', 'w').write("""[logon_greet]
file = scripts/hk_logon.bas
[menu_all]
file = scripts/hk_menu.bas
[menu_top]
file = scripts/hk_menutop.bas
[bad]
file = scripts/hk_bad.bas
[slow]
file = scripts/hk_slow.bas
timeout = 2
[low]
file = scripts/hk_low.bas
level = 60000
[tally]
file = scripts/hk_log.bas
caps = log:write
[hooks]
logon = bad low logon_greet slow
logoff = tally
menu = menu_all
menu.top = menu_top
newuser = nothere
""")
    c = Caller()
    t0 = time.time()
    seen = c.seen
    check('logon hook: the greeting reaches the caller with the event, the user, the level, the node', b'HK-LOGON|logon|Mark May|120|1' in seen.replace(b'HK-LOGON| logon', b'HK-LOGON|logon'), show(seen))
    check('a hook that fails does not stop the caller or the hooks after it (the error is only shown, no Press Enter): the greeting came after it', b'HK-BAD-START' in seen and seen.find(b'HK-BAD-START') < seen.find(b'HK-LOGON'), show(seen))
    check('a hook for a higher level is skipped, without a word', b'HK-LOW-RAN' not in seen, show(seen))
    check('menu hooks: the generic one gets the event and the menu (top, then the menu it goes on to), the one for menu.top only the first', b'HK-MENU|menu|top' in seen and b'HK-MENU|menu|realtop' in seen and seen.count(b'HK-MENUTOP') == 1, show(seen))
    check('a slow hook is stopped by its timeout and the caller gets the menu', c.at_menu and 'Ext slow: ended' in bbslog(), (c.at_menu, bbslog()[-300:]))
    lg = bbslog()
    check('the log has what ran: run lines with the caller, the failing one, the missing one', 'Ext logon_greet: run for Mark May' in lg and 'Ext bad: ended' in lg and 'Ext tally' not in lg.split('logon_greet')[0], lg[-600:])
    c.s.sendall(b'G'); c.s.sendall(b'\r')
    time.sleep(0.5)
    c.close()
    time.sleep(3)
    lg = bbslog()
    check('logoff hook: runs at the end of the call with the event, the user and the reason', 'Ext tally: logoff hook ran; event=logoff user=Mark May reason=' in lg, lg[-500:])
    open(ra + '/extensions.cfg', 'w').write("[hang]\nfile = scripts/hk_hang.bas\ncaps = session:control\n[hooks]\nlogon = hang\n")
    c = Caller()
    check('a hook that ends the call (bbs.hangup) ends it: no menu', 'Ext hang: ended' in bbslog() and not c.at_menu, show(c.seen))
    c.close()
    open(ra + '/extensions.cfg', 'w').write("[hooks]\nbogus = x\nlogon = ghost\n")
    r = subprocess.run([build + '/mkcheck', '-c', ra], capture_output=True, text=True)
    check('mkcheck says an unknown hook and an extension a hook names that is not defined', 'unknown hook bogus' in r.stdout and 'the hook logon names the extension ghost' in r.stdout, r.stdout[-600:])
finally:
    stop()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
