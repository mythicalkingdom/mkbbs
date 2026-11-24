#!/usr/bin/env python3
"""MKMenu through a pseudo terminal on a private copy of a sample menu: edit, pick a command,
insert, delete, save; the bytes of the file are checked.
usage: menutest.py <work dir>   (needs bbs/bbsc/ra and bbs/bbsc/myth/menus, i.e. the sample BBS)"""
import os, re, subprocess, sys, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..')
work = os.path.abspath(sys.argv[1])
cfg = os.path.join(root, 'bbs', 'bbsc', 'ra')
menu = os.path.join(root, 'bbs', 'bbsc', 'myth', 'menus', 'message.mnu')
if not (os.path.isdir(cfg) and os.path.exists(menu)):
    print('skip: no sample BBS'); sys.exit(0)
os.makedirs(work, exist_ok=True)
# the language file of the editor: MKMENU.LC is compiled from lang/MKMENU.TXT (it has the BASIC command 169)
tmpcfg = cfgpatch.short_dir() + '/r'
shutil.copytree(cfgpatch.snapshot(cfg), tmpcfg, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(tmpcfg)
for f in os.listdir(tmpcfg):
    if f.lower() == 'mkmenu.lc':
        os.remove(os.path.join(tmpcfg, f))
subprocess.run([os.path.join(root, 'build', 'mklc'), os.path.join(root, 'lang', 'MKMENU.TXT')], capture_output=True, check=True)
shutil.copy(os.path.join(root, 'lang', 'MKMENU.LC'), os.path.join(tmpcfg, 'MKMENU.LC'))
REC = 167
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkmenu: ' + name)
    if not ok:
        fails += 1


def fresh():
    p = os.path.join(work, 'test.mnu')
    shutil.copy(menu, p)
    return p


def run(path, *keys):
    env = dict(os.environ, CFGPROG='mkmenu', CFGCWD=work, CFGDIR=tmpcfg, CFGARGS=path, CFGDELAY='0.6')
    return subprocess.run([sys.executable, os.path.join(here, 'cfgshot.py')] + list(keys), env=env,
                          capture_output=True, text=True).stdout


def rec(data, i):
    return data[i * REC:(i + 1) * REC]


def prompt(r):
    return r[7:8 + r[7]][1:].decode('latin-1')


def raw_sgr(path, *keys):
    """the colour codes the program sends (the text screen of cfgshot cannot show colours or blinking)"""
    import pty, select, struct, fcntl, termios, re
    env = {'TERM': 'xterm', 'LANG': 'C.UTF-8', 'LC_ALL': 'C.UTF-8', 'MK': tmpcfg, 'PATH': os.environ['PATH']}
    pid, fd = pty.fork()
    if pid == 0:
        os.environ.clear(); os.environ.update(env); os.chdir(work)
        os.execv(os.path.join(root, 'build', 'mkmenu'), ['mkmenu', path])
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 25, 80, 0, 0))
    buf = b''

    def drain(t):
        nonlocal buf
        end = __import__('time').time() + t
        while __import__('time').time() < end:
            r, _, _ = select.select([fd], [], [], 0.1)
            if r:
                try:
                    buf += os.read(fd, 65536)
                except OSError:
                    return
    drain(1.2)
    for k in keys:
        os.write(fd, k.encode().decode('unicode_escape').encode('latin-1')); drain(0.5)
    os.kill(pid, 9)
    os.waitpid(pid, 0)
    return re.findall(r'\x1b\[([0-9;]*)m', buf.decode('utf-8', 'replace'))


orig = open(menu, 'rb').read()
check('sample menu has whole records', len(orig) % REC == 0)

# colours: the list must not come out in Free Vision's error attribute (blinking white on red), and the
# bar must move: the item under it has another colour than the others
sg = raw_sgr(fresh())
check('no blinking text anywhere on the list screen', not [x for x in sg if '5' in x.split(';')])
sg2 = raw_sgr(fresh(), '\x1b[B')
check('the list uses its normal and its selection colours', any(x.startswith('30;46') for x in sg2) and any(x == '97;42' for x in sg2))

# the list
p = fresh()
s = run(p)
check('list shows the items', 'Scan message headers' in s and 'Check for your mail' in s)
check('the file name is in the frame', 'test.mnu' in s)

# edit the prompt of item 2 and save (Alt-S, Enter on the file name)
p = fresh()
run(p, '\x1b[B', '\r', '\t', '\t', 'Hello there', '\r', '\x1bs', '\r', '\x1bx')
d = open(p, 'rb').read()
check('file size unchanged', len(d) == len(orig))
check('prompt of item 2 changed: %r' % prompt(rec(d, 2)), prompt(rec(d, 2)) == 'Hello there')
check('the other items are as they were', rec(d, 1) == rec(orig, 1) and d[3 * REC:] == orig[3 * REC:])
check('type of item 2 is as it was', rec(d, 2)[0] == rec(orig, 2)[0])

# choose another command for item 1 from the lists: Type field, F2, group, command (the one after)
p = fresh()
s = run(p, '\r', '\t', '\x1bOQ', '\r', '\x1b[B', '\r')
check('the form shows the chosen command', 'Display Asc/Ans/Avt and wait' in s)
run(p, '\r', '\t', '\x1bOQ', '\r', '\x1b[B', '\r', '\r', '\x1bs', '\r', '\x1bx')
d = open(p, 'rb').read()
check('type of item 1 is now 45 (was %d): %d' % (rec(orig, 1)[0], rec(d, 1)[0]), rec(orig, 1)[0] == 40 and rec(d, 1)[0] == 45)

# delete item 1: everything moves up; the last item is empty
p = fresh()
run(p, '\x1b[3~', '\x1bs', '\r', '\x1bx')
d = open(p, 'rb').read()
n = len(orig) // REC
check('delete: item 2 is now item 1', rec(d, 1) == rec(orig, 2))
check('delete: file is one record shorter or equal', len(d) <= len(orig))

# insert a blank line before item 1 and fill it in
p = fresh()
run(p, '\x1b[2~', '\x1bs', '\r', '\x1bx')
d = open(p, 'rb').read()
check('insert: a blank item 1, the old item 1 is item 2', rec(d, 1)[0] == 0 and rec(d, 2) == rec(orig, 1))

# leaving with unsaved changes asks; No leaves the file alone
p = fresh()
run(p, '\x1b[3~', '\x1bx', 'n')
check('leaving without saving keeps the file', open(p, 'rb').read() == orig)

# the menu prompt (Alt-P): the header record
p = fresh()
run(p, '\x1bp', 'Pick one>', '\r', '\x1bs', '\r', '\x1bx')
d = open(p, 'rb').read()
check('header prompt changed: %r' % prompt(rec(d, 0)), prompt(rec(d, 0)) == 'Pick one>' and d[REC:] == orig[REC:])

# load another file by name (Alt-L, the name replaces the mask)
other = os.path.join(work, 'other.mnu')
shutil.copy(os.path.join(root, 'bbs', 'bbsc', 'myth', 'menus', 'file.mnu'), other)
p = fresh()
s = run(p, '\x1bl', '\x15', other, '\r')
check('load: the other menu is shown', 'other.mnu' in s and 'test.mnu' not in s)

# the BASIC command (169, group "External & Misc", 8th in it): picked from the lists, saved in the file
p = fresh()
s = run(p, '\r', '\t', '\x1bOQ', '\x1b[A', '\x1b[A', '\x1b[A', '\r')
check('External & Misc lists "Run BASIC program"', 'Run BASIC program' in s and '169' in s)
s = run(p, '\r', '\t', '\x1bOQ', '\x1b[A', '\x1b[A', '\x1b[A', '\r', *(['\x1b[B'] * 7), '\r')
check('the form shows type 169 with its descriptions', ' 169' in s and 'Run BASIC program' in s and 'Path of the BASIC program' in s)
run(p, '\r', '\t', '\x1bOQ', '\x1b[A', '\x1b[A', '\x1b[A', '\r', *(['\x1b[B'] * 7), '\r', '\r', '\x1bs', '\r', '\x1bx')
d = open(p, 'rb').read()
check('saved: item 1 has type 169 (was %d), the rest is as it was' % rec(orig, 1)[0],
      rec(d, 1)[0] == 169 and rec(d, 1)[1:] == rec(orig, 1)[1:] and d[2 * REC:] == orig[2 * REC:])

# the Pascal command (170) is the 9th of the same group
p = fresh()
run(p, '\r', '\t', '\x1bOQ', '\x1b[A', '\x1b[A', '\x1b[A', '\r', *(['\x1b[B'] * 8), '\r', '\r', '\x1bs', '\r', '\x1bx')
d = open(p, 'rb').read()
check('Pascal command: item 1 saved with type 170', rec(d, 1)[0] == 170 and rec(d, 1)[1:] == rec(orig, 1)[1:])
s = run(fresh(), '\r', '\t', '\x1bOQ', '\x1b[A', '\x1b[A', '\x1b[A', '\r', *(['\x1b[B'] * 8), '\r')
check('... with its descriptions in the form', 'Run Pascal program' in s and 'Path of the Pascal program' in s)

# save under a new name
p = fresh()
newp = os.path.join(work, 'copy.mnu')
if os.path.exists(newp):
    os.remove(newp)
run(p, '\x1bs', '\x15', newp, '\r', '\x1bx')
check('save as a new name', os.path.exists(newp) and open(newp, 'rb').read() == orig)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
