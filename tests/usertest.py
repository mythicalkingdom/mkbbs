#!/usr/bin/env python3
"""MKUserEd through a pseudo terminal on a private copy of the sample BBS directory (the user files):
browse, edit, delete, search, go to, add, validate; every run starts a fresh program on the same files.
usage: usertest.py <work dir>   (needs bbs/bbsc/ra, i.e. the sample BBS)"""
import os, re, subprocess, sys, shutil

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.abspath(os.path.join(here, '..'))
root = os.path.join(here, '..')
work = os.path.abspath(sys.argv[1])
src = os.path.join(root, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
dst = os.path.join(work, 'ra')
shutil.rmtree(dst, ignore_errors=True)       # a clean copy every time
os.makedirs(dst, exist_ok=True)
subprocess.check_call(['cp', '-a', src + '/.', dst + '/'])
# point the BBS directory (users, logs ...) at the private copy
p = os.path.join(dst, 'config.mk')
d = bytearray(open(p, 'rb').read())
root = os.path.realpath(os.path.join(root, 'bbs')).encode() + b'/'
ra = os.path.realpath(src).encode() + b'/'
new = dst.encode() + b'/'
i = 0
changed = 0
while i < len(d) - 3:
    L = d[i]
    s = bytes(d[i + 1:i + 1 + L])
    if L > 0 and s.startswith(root):
        if s == ra:                          # the user files and logs go to the private copy,
            d[i] = len(new)                  # menus, texts and so on are only read
            d[i + 1:i + 1 + len(s)] = new
            i += 1 + len(new)
            changed += 1
        else:
            i += 1
    else:
        i += 1

open(p, 'wb').write(d)

fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkusered: ' + name)
    if not ok:
        fails += 1


def run(*keys):
    env = dict(os.environ, CFGPROG='mkusered', CFGCWD=dst, CFGDIR=dst, CFGDELAY='0.7')
    env.pop('CFGARGS', None)
    return subprocess.run([sys.executable, os.path.join(here, 'cfgshot.py')] + list(keys), env=env,
                          capture_output=True, text=True).stdout


s = run()
m = re.search(r'User 0 of (\d+)', s)
check('first user is shown', 'Mark May' in s and m is not None)
total = int(m.group(1)) if m else 0
s = run('n')
check('Next shows user 1', 'User 1 of' in s and 'Mark May' not in s)
s = run('g', '5', '\r')
check('GoTo 5', 'User 5 of' in s)
s = run('\x1b[F')
check('End goes to the last user: ' + str(total - 1), ('User %d of' % (total - 1)) in s)
s = run('s', 'Chuck', '\r')
check('Search finds Chuck', 'Chuck Ebenschweiger' in s and 'User 1 of' in s)

# edit the handle of user 0 (Tab: Password, Handle), OK; a new program sees it
run('\r', '\t', '\t', 'TestHandle', '\r')
s = run()
check('edited handle is saved', 'Handle:    TestHandle' in s)
s = run('\r', '\t', '\t', 'Other', '\x1b')
s = run()
check('Esc leaves the record alone', 'Handle:    TestHandle' in s)

# delete / undelete
s = run('d')
check('Delete marks the user', '(DELETED)' in s)
s = run()
check('the deleted mark is in the file', '(DELETED)' in s)
s = run('d')
check('Delete again unmarks', '(DELETED)' not in s)

# add a user: the Name field is first
s = run('a', 'Nobody Special', '\r')
check('Add: the new user is last: %r' % re.search(r'User (\d+) of (\d+)', s).group(0) if re.search(r'User (\d+) of (\d+)', s) else 'Add',
      ('User %d of %d' % (total, total + 1)) in s and 'Nobody Special' in s)
s = run('\x1b[F')
check('the new user is in the file', 'Nobody Special' in s and ('User %d of %d' % (total, total + 1)) in s)

# a template and validate with it: template 1 gives security 77
run('\x1bc', '77', '\r')
s = run('v', '1', 'n', '\r', '\x1b')
check('Validate with template 1: security 77', 'Security: 77' in s)
s = run()
check('and it is saved', 'Security: 77' in s)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
