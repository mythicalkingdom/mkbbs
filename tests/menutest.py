#!/usr/bin/env python3
"""MKMenu through a pseudo terminal on a private copy of a sample menu: edit, pick a command,
insert, delete, save; the bytes of the file are checked.
usage: menutest.py <work dir>   (needs bbs/bbsc/ra and bbs/bbsc/myth/menus, i.e. the sample BBS)"""
import os, subprocess, sys, shutil

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..')
work = os.path.abspath(sys.argv[1])
cfg = os.path.join(root, 'bbs', 'bbsc', 'ra')
menu = os.path.join(root, 'bbs', 'bbsc', 'myth', 'menus', 'message.mnu')
if not (os.path.isdir(cfg) and os.path.exists(menu)):
    print('skip: no sample BBS'); sys.exit(0)
os.makedirs(work, exist_ok=True)
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
    env = dict(os.environ, CFGPROG='mkmenu', CFGCWD=work, CFGDIR=os.path.realpath(cfg), CFGARGS=path, CFGDELAY='0.6')
    return subprocess.run([sys.executable, os.path.join(here, 'cfgshot.py')] + list(keys), env=env,
                          capture_output=True, text=True).stdout


def rec(data, i):
    return data[i * REC:(i + 1) * REC]


def prompt(r):
    return r[7:8 + r[7]][1:].decode('latin-1')


orig = open(menu, 'rb').read()
check('sample menu has whole records', len(orig) % REC == 0)

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

# save under a new name
p = fresh()
newp = os.path.join(work, 'copy.mnu')
if os.path.exists(newp):
    os.remove(newp)
run(p, '\x1bs', '\x15', newp, '\r', '\x1bx')
check('save as a new name', os.path.exists(newp) and open(newp, 'rb').read() == orig)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
