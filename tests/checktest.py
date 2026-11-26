#!/usr/bin/env python3
"""mkcheck on a BBS that mksetup made (nothing wrong), then on copies of it with one thing broken at a time: each break is reported as FAIL or WARN with the reason, the exit code follows.
usage: checktest.py <build dir> <work dir>"""
import os, re, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
if not os.path.exists(build + '/mkcheck') or not os.path.exists(repo + '/lang/AMERICAN.lc'):
    print('skip: no mkcheck or language files'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkcheck: ' + name + ('' if ok else '  ' + str(info)[-700:]))
    if not ok:
        fails += 1


tmp = cfgpatch.short_dir()
src = tmp + '/src'
r = subprocess.run([build + '/mksetup', '-L', repo + '/lang', '-d', src, '-n', 'Check BBS', '-s', 'Check Sysop', '-u', '-p', 'sysop1', '-y'], capture_output=True, text=True)
assert r.returncode == 0, r.stdout + r.stderr
n = [0]


def run(*a, bbs=None):
    return subprocess.run([build + '/mkcheck', '-c', bbs or src] + list(a), capture_output=True, text=True)


def has(r, tag):
    return re.search('^' + tag + ' ', r.stdout, re.M) is not None


def broken(fn):
    """a copy of the BBS with fn(path) applied: its report"""
    n[0] += 1
    d = tmp + '/b%d' % n[0]
    shutil.copytree(src, d, symlinks=True)
    # the configuration holds the paths of the BBS it was made in: the copy is checked through the same paths, so the copy is moved to the place of the original
    shutil.move(src, src + '.keep')
    shutil.move(d, src)
    try:
        fn(src)
        return run()
    finally:
        shutil.rmtree(src)
        shutil.move(src + '.keep', src)


r = run()
check('a BBS that mksetup made: exit 0, nothing FAIL or WARN, "mk can run this BBS"', r.returncode == 0 and not has(r, 'FAIL') and not has(r, 'WARN') and 'mk can run this BBS' in r.stdout, r.stdout)
r = run('-q')
check('-q: only the summary when everything is fine (the info lines are left out too)', r.stdout.strip().startswith('mkcheck: nothing FAIL') and r.stdout.count('\n') <= 2, r.stdout)
r = run('-v')
check('-v: the fine things too', r.stdout.count('ok  ') > 10 and 'language 1 (American)' in r.stdout, r.stdout)
check('-v: what each port of the listener binds (IPv4 and IPv6 by default)', 'listener port 2323: IPv4 and IPv6' in r.stdout, r.stdout)

r = broken(lambda d: os.remove(d + '/newuser.q-a'))
check('no newuser.q-a: FAIL with the error a caller would get', r.returncode == 2 and 'FAIL newuser.q-a is not there' in r.stdout and 'Error in Questionaire' in r.stdout, r.stdout)
r = broken(lambda d: os.remove(d + '/limits.ctl'))
check('no limits.ctl: FAIL (no time for anybody)', r.returncode == 2 and 'FAIL limits.ctl is not there' in r.stdout, r.stdout)
r = broken(lambda d: open(d + '/limits.ctl', 'w').write('50 120 20000\n'))
check('limits.ctl without a line for the new caller level: FAIL', r.returncode == 2 and 'no line for the level of a new caller' in r.stdout, r.stdout)
r = broken(lambda d: os.remove(d + '/american.lc'))
check('no language file: FAIL', r.returncode == 2 and 'FAIL the language file american.lc is not in the BBS folder' in r.stdout, r.stdout)
r = broken(lambda d: os.remove(d + '/menus/top.mnu'))
check('no top menu: FAIL', r.returncode == 2 and 'FAIL the menu top.mnu is not in' in r.stdout, r.stdout)


def menu_to_nowhere(d):
    m = bytearray(open(d + '/menus/top.mnu', 'rb').read())
    i = len(m) // 167 - 1                       # the last item: goodbye
    m[i * 167] = 1
    m[i * 167 + 84] = 6; m[i * 167 + 85:i * 167 + 91] = b'nomenu'
    open(d + '/menus/top.mnu', 'wb').write(m)


r = broken(menu_to_nowhere)
check('an item that goes to a menu that is not there: FAIL, and there is no way to log off: WARN', r.returncode == 2 and 'goes to the menu nomenu, which is not there' in r.stdout and 'no way to log off' in r.stdout, r.stdout)


def bad_screen(d):
    m = bytearray(open(d + '/menus/top.mnu', 'rb').read())
    i = len(m) // 167 - 2
    m[i * 167] = 5
    m[i * 167 + 84] = 7; m[i * 167 + 85:i * 167 + 92] = b'noscreen'[:7]
    open(d + '/menus/top.mnu', 'wb').write(m)


r = broken(bad_screen)
check('an item that shows a screen that is not there: WARN', r.returncode == 0 and has(r, 'WARN') and 'shows the screen noscree' in r.stdout, r.stdout)

# menu command 172 (a door of doors.cfg)
os.makedirs(tmp + '/dd', exist_ok=True)
open(tmp + '/dd/Lord.Exe', 'w').write('x')
open(tmp + '/fakedos', 'w').write('x')


def door_item(name, cfgtext=None):
    def f(d):
        m = bytearray(open(d + '/menus/top.mnu', 'rb').read())
        i = len(m) // 167 - 2
        m[i * 167] = 172
        nb = name.encode()
        m[i * 167 + 84] = len(nb); m[i * 167 + 85:i * 167 + 85 + len(nb)] = nb
        open(d + '/menus/top.mnu', 'wb').write(m)
        if cfgtext is not None:
            open(d + '/doors.cfg', 'w').write(cfgtext)
    return f


good = '[global]\ndosemu = %s/fakedos\n[lord]\ntype = dos\ndir = %s/dd\ncommand = LORD.EXE *N\n' % (tmp, tmp)
r = broken(door_item('lord', good))
check('a door that is all there (the command in the other case: DOS names): nothing to say', r.returncode == 0 and not has(r, 'WARN') and not has(r, 'FAIL'), r.stdout)
r = broken(door_item('lord'))
check('a door command and no doors.cfg: WARN', 'WARN menu top' in r.stdout and 'there is no doors.cfg' in r.stdout and r.returncode == 0, r.stdout)
r = broken(door_item('other', good))
check('a door that is not in doors.cfg: WARN', 'the door other, which is not in doors.cfg' in r.stdout, r.stdout)
r = broken(door_item('lord', good.replace('/dd', '/nodir')))
check('the door directory is not there: WARN', 'the directory of the door lord is not there' in r.stdout, r.stdout)
r = broken(door_item('lord', good.replace('LORD.EXE', 'GONE.EXE')))
check('the command is not in the door directory: WARN', 'the command GONE.EXE of the door lord is not in' in r.stdout, r.stdout)
r = broken(door_item('lord', good.replace('/fakedos', '/nodosemu')))
check('dosemu2 is not there: WARN', 'needs dosemu2, but' in r.stdout and 'is not there' in r.stdout, r.stdout)
r = broken(door_item('lord', good + 'dropfiles = door.sys door32.sys foo.sys\n'))
check('a drop file name MK does not write, and door32.sys for a DOS door: WARN', 'the drop file foo.sys, which MK does not write' in r.stdout and 'door32.sys is for native doors' in r.stdout, r.stdout)
r = broken(door_item('lord', '[sandbox]\nprogram = /nonexistent/bwrap\n' + good))
check('a sandboxed door and no bwrap: WARN (the door will not be run)', 'runs in the sandbox' in r.stdout and 'is not installed: the door will not be run' in r.stdout, r.stdout)
r = broken(door_item('lord', good + 'bind = /nonexistent/scores\nrobind = /nonexistent/files\n'))
check('bind / robind paths that are not there: WARN', 'bind = /nonexistent/scores is not there' in r.stdout and 'robind = /nonexistent/files is not there' in r.stdout, r.stdout)
r = broken(door_item('lord', good + 'sandbox = off\n'))
check('sandbox = off: nothing to say about bwrap', 'sandbox' not in r.stdout.replace('sandbox = off', ''), r.stdout)
r = broken(door_item('lord', good + 'bogus = 1\ncom = 12\n'))
check('doors.cfg lines that are not understood: WARN with the line number', 'WARN doors.cfg line 7: unknown setting bogus' in r.stdout and 'line 8: com is a number' in r.stdout, r.stdout)
# menu command 173 (uploads) and uploads.cfg
def upload_item(data, cfgtext=None):
    def f(d):
        m = bytearray(open(d + '/menus/top.mnu', 'rb').read())
        i = len(m) // 167 - 2
        m[i * 167] = 173
        nb = data.encode()
        m[i * 167 + 84] = len(nb); m[i * 167 + 85:i * 167 + 85 + len(nb)] = nb
        open(d + '/menus/top.mnu', 'wb').write(m)
        if cfgtext is not None:
            open(d + '/uploads.cfg', 'w').write(cfgtext)
    return f


r = broken(upload_item(''))
check('an upload item and no uploads.cfg: nothing wrong (an info line only)', r.returncode == 0 and not has(r, 'WARN') and 'there is no uploads.cfg' in r.stdout, r.stdout)
r = broken(upload_item('999'))
check('an upload item for a file area that is not there: WARN', 'uploads into the file area "999", which is not a file area' in r.stdout, r.stdout)
os.makedirs(tmp + '/qq', exist_ok=True)
fine = '[global]\nquarantine = %s/qq\nsandbox = off\nscan = /bin/true %%f\n[type zip]\ntest = /bin/true %%f\ndiz = /bin/true %%f\n' % tmp
r = broken(upload_item('', fine))
check('a uploads.cfg with programs that are there: nothing to say', r.returncode == 0 and not has(r, 'WARN'), r.stdout)
r = broken(upload_item('', fine.replace('/bin/true %f\n[type', '/nonexistent/scanner %f\n[type', 1)))
check('a scanner that is not there: WARN', 'uploads.cfg: the scanner: /nonexistent/scanner is not there' in r.stdout, r.stdout)
r = broken(upload_item('', fine.replace('test = /bin/true', 'test = nosuchtool-xyz')))
check('a test program that is not installed: WARN', 'the test of zip: nosuchtool-xyz is not installed' in r.stdout, r.stdout)
r = broken(upload_item('', fine.replace('[type zip]', 'bogus = 1\nscanfail = maybe\n[type zip]')))
check('uploads.cfg lines that are not understood: WARN with the line number', 'WARN uploads.cfg line 5: unknown setting bogus' in r.stdout and 'scanfail is refuse or accept' in r.stdout, r.stdout)
r = broken(upload_item('', fine.replace('sandbox = off', 'sandbox = on\nrobind = /nonexistent/clam')))
check('a robind that is not there: WARN', 'robind = /nonexistent/clam is not there' in r.stdout, r.stdout)
r = broken(upload_item('', fine.replace(tmp + '/qq', '/proc/nowhere/q')))
check('a quarantine directory that cannot be made: WARN', 'the quarantine directory /proc/nowhere/q cannot be made' in r.stdout, r.stdout)
# multi-node chat (chat.mk)
import struct
def chat_mk(enabled=1, level=0, log=1, wordfile=''):
    def f(d):
        pas = lambda t, n: bytes([len(t)]) + t.encode().ljust(n, b'\0')
        rec = struct.pack('<HBH', 1, enabled, level) + pas('Chat', 20) + struct.pack('<HBBBBBBB', 160, 5, 10, 2, 10, 1, 1, log) + pas(wordfile, 60) + struct.pack('<BH', 0, 0) + bytes(40)
        assert len(rec) == 139
        open(d + '/chat.mk', 'wb').write(rec)
    return f


r = broken(lambda d: None)
check('no chat.mk: chat is off, an info line only', r.returncode == 0 and 'multi-node chat is off' in r.stdout, r.stdout)
r = broken(chat_mk(0))
check('chat.mk with chat off: off', 'multi-node chat is off' in r.stdout and not has(r, 'WARN chat'), r.stdout)
r = broken(chat_mk(1, 20))
check('chat on, level 20, logged: an info line with the room and the flood limit, nothing wrong', 'multi-node chat is ON: room "Chat", level 20 and up, flood limit 5 lines in 10 s, every line logged' in r.stdout and 'WARN chat' not in r.stdout, r.stdout)
def chat_item(enabled):
    def f(d):
        upload_item('')(d)
        m = bytearray(open(d + '/menus/top.mnu', 'rb').read())
        i = len(m) // 167 - 2
        m[i * 167] = 174
        open(d + '/menus/top.mnu', 'wb').write(m)
        chat_mk(enabled, 20)(d)
    return f


def ext_item(data, cfgtext=None, files=()):
    def f(d):
        upload_item('')(d)
        m = bytearray(open(d + '/menus/top.mnu', 'rb').read())
        i = len(m) // 167 - 2
        m[i * 167] = 175
        nb = data.encode()
        m[i * 167 + 84] = len(nb); m[i * 167 + 85:i * 167 + 85 + len(nb)] = nb
        open(d + '/menus/top.mnu', 'wb').write(m)
        os.makedirs(d + '/scripts', exist_ok=True)
        for n in files:
            open(d + '/scripts/' + n, 'w').write('10 PRINT 1\n')
        if cfgtext is not None:
            open(d + '/extensions.cfg', 'w').write(cfgtext)
    return f


r = broken(ext_item('who top 10', '[who]\nfile = scripts/who.bas\ncaps = users:read\n', ['who.bas']))
check('an extension menu item whose entry and program are there: nothing to say about it', 'WARN menu top item' not in r.stdout or 'extension' not in r.stdout.split('WARN menu top item')[-1], r.stdout)
r = broken(ext_item('nothere', '[who]\nfile = scripts/who.bas\n', ['who.bas']))
check('an extension menu item that names no entry: WARN', 'the extension "nothere" is not in extensions.cfg' in r.stdout, r.stdout)
r = broken(ext_item('', None))
check('an extension menu item with no name in its data: WARN', 'no name of an extension in its data' in r.stdout, r.stdout)
r = broken(ext_item('who', '[who]\nfile = scripts/gone.bas\n'))
check('an extension menu item whose program is not there: WARN', 'the program of the extension who is not there' in r.stdout, r.stdout)

# extensions.cfg
def ext_cfg(text, files=()):
    def f(d):
        os.makedirs(d + '/scripts', exist_ok=True)
        for n in files:
            open(d + '/scripts/' + n, 'w').write('10 PRINT 1\n')
        open(d + '/extensions.cfg', 'w').write(text)
    return f


r = broken(lambda d: None)
check('no extensions.cfg: an info line only', r.returncode == 0 and 'there is no extensions.cfg' in r.stdout, r.stdout)
r = broken(ext_cfg('[who]\nfile = scripts/who.bas\ncaps = users:read nodes:read\n', ['who.bas']))
check('an extension with its file and known capabilities: nothing wrong, counted', r.returncode == 0 and 'WARN extensions' not in r.stdout and '1 extension(s) in extensions.cfg' in r.stdout, r.stdout)
r = broken(ext_cfg('[who]\nfile = scripts/nothere.bas\ncaps = users:read\n[b]\nfile = scripts/x.txt\n[c]\nfile = scripts/c.bas\ncaps = users:destroy\nbogus = 1\n', ['x.txt', 'c.bas']))
check('a file that is not there, a file that is not .bas / .pas, an unknown capability and setting: WARN each, with the line',
      'extensions.cfg: who: ' in r.stdout and 'nothere.bas is not there' in r.stdout and 'x.txt is not a .bas or a .pas file' in r.stdout and 'WARN extensions.cfg line 8: unknown capability users:destroy' in r.stdout
      and 'WARN extensions.cfg line 9: unknown setting bogus' in r.stdout, r.stdout)
r = broken(ext_cfg('[who]\ncaps = users:read\n[who]\nfile = a.bas\n'))
check('an extension with no file, the same name twice: WARN', 'the extension who has no file' in r.stdout and 'the extension who is there already' in r.stdout, r.stdout)
r = broken(chat_item(0))
check('a menu item for chat and chat off: WARN', 'the multi-node chat command, and chat is off' in r.stdout, r.stdout)
r = broken(chat_item(1))
check('a menu item for chat and chat on: nothing to say about it', 'the multi-node chat command' not in r.stdout, r.stdout)
r = broken(chat_mk(1, 0))
check('chat on for level 0: WARN (new users may join)', 'WARN chat: the lowest level is 0' in r.stdout, r.stdout)
r = broken(chat_mk(1, 20, 0))
check('chat on and not logged: WARN', 'WARN chat: lines are not logged' in r.stdout, r.stdout)
r = broken(chat_mk(1, 20, 1, '/nonexistent/words.txt'))
check('a word file that is not there: WARN', 'WARN chat: the word file /nonexistent/words.txt is not there' in r.stdout, r.stdout)
r = broken(lambda d: os.remove(d + '/games/cowsandbulls.pas'))
check('the sample door is gone: WARN, the BBS still runs (exit 0)', r.returncode == 0 and 'WARN menu top' in r.stdout and 'cowsandbulls.pas, which is not there' in r.stdout, r.stdout)
r = broken(lambda d: os.remove(d + '/msgs/gen.mer'))
check('a message base that is not there: FAIL with the area', r.returncode == 2 and 'FAIL message area 1 (General Messages)' in r.stdout, r.stdout)
r = broken(lambda d: shutil.rmtree(d + '/files/area01'))
check('a file area folder that is not there: WARN', r.returncode == 0 and 'WARN file area 1 (Example Files)' in r.stdout, r.stdout)
r = broken(lambda d: open(d + '/users.bbs', 'ab').write(b'x' * 10))
check('a user file that is not whole records: FAIL', r.returncode == 2 and 'users.bbs has a size that is not a number of' in r.stdout, r.stdout)
r = broken(lambda d: os.truncate(d + '/extusers.bbs', 0))
check('extusers.bbs out of step with users.bbs: FAIL', r.returncode == 2 and 'extusers.bbs' in r.stdout and 'FAIL' in r.stdout, r.stdout)
r = broken(lambda d: os.remove(d + '/users.bbs'))
check('no user file: only something to know (it is made at the first registration)', r.returncode == 0 and 'info there is no user file yet' in r.stdout and not has(r, 'FAIL'), r.stdout)
r = broken(lambda d: open(d + '/mklisten.json', 'w').write('{ "mk": '))
check('a listener configuration that mklisten does not accept: FAIL with its reason', r.returncode == 2 and 'FAIL mklisten -t does not accept' in r.stdout, r.stdout)
r = broken(lambda d: os.remove(d + '/mklisten.json'))
check('no mklisten.json: only something to know', r.returncode == 0 and 'info no mklisten.json' in r.stdout, r.stdout)
r = broken(lambda d: shutil.rmtree(d + '/menus'))
check('no menu folder: FAIL', r.returncode == 2 and 'FAIL the menu folder' in r.stdout, r.stdout)
r = subprocess.run([build + '/mkcheck'], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('no configuration named: exit 1', r.returncode == 1 and 'No configuration' in r.stderr, r.stderr)
r = subprocess.run([build + '/mkcheck', '-c', tmp + '/nothing'], capture_output=True, text=True)
check('a folder without a configuration: FAIL, exit 2', r.returncode == 2 and 'FAIL the configuration cannot be loaded' in r.stdout, r.stdout + r.stderr)
# the sample BBS of the repository: its menus lead to places that were never there
samp = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if os.path.isdir(samp):
    r = subprocess.run([build + '/mkcheck', '-c', samp, '-q'], capture_output=True, text=True)
    check('the sample BBS (DOS data): reports its missing menus (FAIL) and programs (WARN) and changes nothing', r.returncode == 2 and 'goes to the menu' in r.stdout and 'WARN' in r.stdout, r.stdout[-400:])
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
