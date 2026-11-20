#!/usr/bin/env python3
"""Passwords at the login (mk -Q on a pty, private copy of the sample BBS): a plain password (any case, as in the DOS days) and a
hashed one (exactly as typed, blanks and a slash allowed, the right one only).
usage: pwlogintest.py <build dir> <work dir>"""
import os, shutil, subprocess, sys, time, pty, select

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src) or not os.path.exists(build + '/netsetup'):
    print('skip: no sample BBS'); sys.exit(0)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'login: ' + name)
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(src, ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
env = dict(os.environ, MK=ra)

# two QWK node users: Mark May (the password as a hash) and a new one with a plain password
r = subprocess.run([build + '/netsetup', 'Mark May', '6'], env=dict(env, NETPWD='Pass Word/9x', NETPWMODE='1'), capture_output=True, text=True)
check('the hashed user is set up', 'ok' in r.stdout)
subprocess.run([build + '/useradd', 'PWT Plain', 'x'], env=env, capture_output=True, text=True)
r = subprocess.run([build + '/netsetup', 'PWT Plain', '6'], env=dict(env, NETPWD='plainpw'), capture_output=True, text=True)
check('the plain user is set up', 'ok' in r.stdout)

users = open(ra + '/users.bbs', 'rb').read()
check('the hashed user has * in the Pwd field and no password in the file', b'Pass Word' not in users and b'PASS WORD' not in users)
check('the plain user has the password in the file, as before', b'plainpw' in users.lower())


def session(script, timeout=15, args=('-Q',), tail=2):
    m, s = pty.openpty()
    p = subprocess.Popen([build + '/mk'] + list(args), env=dict(env, TERM='ansi'), cwd=ra, stdin=s, stdout=s, stderr=s, close_fds=True)
    os.close(s)
    out = b''
    pos = 0
    def find(wait):
        hits = [(out.index(w.encode(), pos), len(w)) for w in wait.split('|') if w.encode() in out[pos:]]
        return min(hits) if hits else None
    for wait, send in script:
        t0 = time.time()
        while find(wait) is None and time.time() - t0 < timeout:
            if select.select([m], [], [], 0.2)[0]:
                try:
                    d = os.read(m, 4096)
                except OSError:
                    break
                if not d:
                    break
                out += d
            elif p.poll() is not None:
                break
        hit = find(wait)
        if hit:
            pos = hit[0] + hit[1]
            if send:
                os.write(m, send.encode())
    end = time.time() + tail
    while p.poll() is None and time.time() < end:
        if select.select([m], [], [], 0.2)[0]:
            try:
                out += os.read(m, 4096)
            except OSError:
                break
    if p.poll() is None:
        p.kill()
    os.close(m)
    return out.decode('latin-1'), p.returncode


def login(name, pwd):
    out, rc = session([('Login: ', name + '\r'), ('Password: ', pwd + '\r'), ('QWK: |Login incorrect', 'Q\r')])
    return 'QWK: ' in out, out


ok, out = login('Mark May', 'Pass Word/9x')
check('hashed: the right password (blanks and a slash) gets in', ok)
ok, out = login('Mark May', 'pass word/9x')
check('hashed: the wrong case does not', not ok and 'Login incorrect' in out)
ok, out = login('Mark May', 'Pass Word')
check('hashed: the first word does not', not ok)
ok, out = login('Mark May', '*')
check('hashed: * does not', not ok)
ok, out = login('Mark May', 'unavailable')
check('hashed: the word shown to doors does not', not ok)
ok, out = login('PWT Plain', 'plainpw')
check('plain: the right password gets in', ok)
ok, out = login('PWT Plain', 'PLAINPW')
check('plain: any case gets in (as in the DOS days)', ok)
ok, out = login('PWT Plain', 'plainpx')
check('plain: the wrong password does not', not ok)


# the BBS itself: the login by name and password, and the menu command that changes the password (Your settings, Password)
def bbs(name, pwd, then=(), tail=3):
    script = [('choice', '\r'), ('name:', name + '\r'), ('Password:', pwd + '\r')]
    if then is not None:
        script += [('continue', '\r'), ('Command >', '')]
    script += list(then)
    if not then:                                    # a login that worked ends with the log-off
        script += [('', 'g'), ('Command >', 'y')]
    out, rc = session(script, args=('-L',), tail=tail)
    return out


def badlogin(name, pwd):
    """True when the password is not taken: no menu, the BBS asks again or hangs up"""
    out, rc = session([('choice', '\r'), ('name:', name + '\r'), ('Password:', pwd + '\r')], args=('-L',), tail=3)
    return 'Minutes Remaining' not in out and 'Press (Enter) to continue' not in out.split('looking up user record')[-1]


def in_(out):
    return 'Minutes Remaining' in out


def change(name, old, new, again=None):
    return bbs(name, old, [('', 'y'), ('Command:', 'p'), ('old password:', old + '\r'), ('new password:', new + '\r'),
                           ('Re-enter', (again if again is not None else new) + '\r'), ('continue', '\r'),
                           ('Command:', 'q'), ('Command >', 'g'), ('Command >', 'y')], tail=3)


r = subprocess.run([build + '/useradd', 'PWT Caller', 'x'], env=env, capture_output=True, text=True)
r = subprocess.run([build + '/netsetup', 'PWT Caller', '6'], env=dict(env, NETPWD='First Pw/1', NETPWMODE='1'), capture_output=True, text=True)
check('BBS: the hashed caller is set up', 'ok' in r.stdout)
check('BBS: hashed, the right password (blanks and a slash) gets in', in_(bbs('PWT Caller', 'First Pw/1')))
check('BBS: hashed, another case does not', badlogin('PWT Caller', 'first pw/1'))
check('BBS: hashed, the first word does not', badlogin('PWT Caller', 'First'))
out = change('PWT Caller', 'First Pw/1', 'Second Pw/2')
check('BBS: the password was changed (hashed account)', 'Password has been changed' in out)
check('BBS: the new password gets in', in_(bbs('PWT Caller', 'Second Pw/2')))
check('BBS: the old one does not', badlogin('PWT Caller', 'First Pw/1'))
out = change('PWT Caller', 'Second Pw/2', 'Third Pw', again='Third Px')
check('BBS: a change with a different second entry is refused', 'Password has been changed' not in out)
check('BBS: ... and the password stays', in_(bbs('PWT Caller', 'Second Pw/2')))
out = bbs('PWT Caller', 'Second Pw/2', [('', 'y'), ('Command:', 'p'), ('old password:', 'Wrong One\r')], tail=3)
check('BBS: a change with the wrong old password is refused', 'Enter your new password' not in out)
out = change('PWT Caller', 'Second Pw/2', '*')
check('BBS: * is no password', 'Password has been changed' not in out)

subprocess.run([build + '/useradd', 'PWT Old', 'x'], env=env, capture_output=True, text=True)
subprocess.run([build + '/netsetup', 'PWT Old', '6'], env=dict(env, NETPWD='oldpw'), capture_output=True, text=True)
check('BBS: plain, the right password gets in', in_(bbs('PWT Old', 'oldpw')))
check('BBS: plain, any case gets in', in_(bbs('PWT Old', 'OLDPW')))
out = change('PWT Old', 'oldpw', 'newpw')
check('BBS: the password was changed (plain account)', 'Password has been changed' in out)
check('BBS: plain, the new password gets in, in any case', in_(bbs('PWT Old', 'NewPw')))
check('BBS: plain, the old one does not', badlogin('PWT Old', 'oldpw'))
check('BBS: the plain account is still plain (the new password is in the file)', b'NEWPW' in open(ra + '/users.bbs', 'rb').read())
print('failures:', fails)
sys.exit(1 if fails else 0)
