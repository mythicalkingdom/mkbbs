#!/usr/bin/env python3
"""MKUserEd through a pseudo terminal on a private copy of the sample BBS directory (the user files):
browse, edit, delete, search, go to, add, validate; every run starts a fresh program on the same files.
usage: usertest.py <work dir>   (needs bbs/bbsc/ra, i.e. the sample BBS)"""
import os, re, subprocess, sys, shutil

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch
repo = os.path.abspath(os.path.join(here, '..'))
root = os.path.join(here, '..')
work = os.path.abspath(sys.argv[1])
src = os.path.join(root, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
dst = cfgpatch.short_dir() + '/r'      # a short path: the configuration holds it in a fixed size field
shutil.copytree(src, dst, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(dst)
p = os.path.join(dst, 'config.mk')
root = os.path.realpath(os.path.join(root, 'bbs')).encode() + b'/'
ra = os.path.realpath(src).encode() + b'/'
new = dst.encode() + b'/'
cfgpatch.patch(p, root, lambda s: new if s == ra else s)

fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkusered: ' + name + ('' if ok else '  ' + str(info)))
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

# the password state (MK users): set when, the wrong passwords in a row, a lock
import time as _t
pw = os.path.join(repo, 'build', 'pwstate')
if os.path.exists(pw):
    e = dict(os.environ, MK=dst)
    subprocess.run([pw, 'Mark May', str(int(_t.time()) - 5 * 86400), '2', str(int(_t.time()) - 100), '0'], env=e, capture_output=True, text=True)
    s = run()
    check('the password state is shown: when it was set and the wrong ones in a row', 'Password: password set' in s and 'wrong in a row: 2' in s and '[LOCKED]' not in s, s)
    subprocess.run([pw, 'Mark May', str(int(_t.time()) - 5 * 86400), '5', str(int(_t.time()) - 100), str(int(_t.time()) + 3600)], env=e, capture_output=True, text=True)
    s = run()
    check('a locked account is marked [LOCKED]', '[LOCKED]' in s and 'wrong in a row: 5' in s)
    s = run('\r')
    check('the edit form has Locked: checked for it', 'Locked:  [X]' in s, [l for l in s.split('\n') if 'ocked' in l])
    subprocess.run([pw, 'Mark May', '0', '0', '0', '0'], env=e, capture_output=True, text=True)

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

# a BBS with no user files at all: the first user is added, and saved (it used to be lost without a word), with dates of today
import time
dst2 = cfgpatch.short_dir() + '/r'
shutil.copytree(dst, dst2, ignore=lambda d, n: [f for f in n if f.lower() in ('users.bbs', 'usersidx.bbs', 'extusers.bbs')])
cfgpatch.patch(os.path.join(dst2, 'config.mk'), (dst + '/').encode(), lambda s: (dst2 + '/').encode() if s == (dst + '/').encode() else s)


def run2(*keys):
    env = dict(os.environ, CFGPROG='mkusered', CFGCWD=dst2, CFGDIR=dst2, CFGDELAY='0.7')
    env.pop('CFGARGS', None)
    return subprocess.run([sys.executable, os.path.join(here, 'cfgshot.py')] + list(keys), env=env,
                          capture_output=True, text=True).stdout


s = run2()
check('no user files: the editor starts with 0 users', 'User 0 of 0' in s)
s = run2('a', 'First Person', '\r')
check('Add with no users.bbs: the user is added', 'User 0 of 1' in s and 'First Person' in s, s[:300])
check('... users.bbs was made (one record), with the index and the extra file',
      os.path.exists(dst2 + '/users.bbs') and os.path.getsize(dst2 + '/users.bbs') > 0 and os.path.exists(dst2 + '/usersidx.bbs') and os.path.exists(dst2 + '/extusers.bbs'))
s = run2()
check('... and it is there in a new run', 'User 0 of 1' in s and 'First Person' in s)
today = time.strftime('%m-%d-%y')
check('a new user has first call, last call and new files date of today (%s)' % today,
      ('First Called: %s' % today) in s and ('Last Called: %s' % today) in s and ('New Files Date: %s' % today) in s, s[:900])

# a template and validate with it: template 1 gives security 77
run('\x1bc', '77', '\r')
s = run('v', '1', 'n', '\r', '\x1b')
check('Validate with template 1: security 77', 'Security: 77' in s)
s = run()
check('and it is saved', 'Security: 77' in s)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
