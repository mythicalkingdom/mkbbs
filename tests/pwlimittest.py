#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Password limits at the login (mk -L on a pty, private copy of the sample BBS): an account is locked after wrong passwords in a row (even the right one is
refused while it is locked), the failures are told at the next good log-on, a password that has expired must be changed, one that is about to is
announced.   usage: pwlimittest.py <build dir> <work dir>"""
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
    print(('ok   ' if ok else 'FAIL ') + 'password limits: ' + name)
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
env = dict(os.environ, MK=ra)

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



import json, time
Run = lambda prog, *a, **kw: subprocess.run([build + '/' + prog] + list(a), env=dict(env, **kw), capture_output=True, text=True)

# the settings (the JSON form): lock after 3 wrong passwords for 1 minute, a password is good for 30 days, warn 7 days before
cj = work + '/cj'
os.makedirs(cj)
Run('mkcfgcvt', '-y', '1', '5', MKJSON=cj)
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
d['config'].update({'LockFails': 3, 'LockMinutes': 1, 'PwdExpire': 30, 'PwdWarn': 7, 'PassTries': 3, 'LimitsMark': 173, 'LogFileName': ra + '/limits.log'})      # the log of the sample is in /var/log/mkbbs
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
Run('mkcfgcvt', '-y', '5', '1', MKJSON=cj)
Run('mkcfgcvt', '-y', '1', '5', MKJSON=cj)
check('the settings are in config.mk and read back (LockFails 3, LockMinutes 1, PwdExpire 30, PwdWarn 7)', {k: json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))['config'].get(k) for k in ('LockFails', 'LockMinutes', 'PwdExpire', 'PwdWarn')} == {'LockFails': 3, 'LockMinutes': 1, 'PwdExpire': 30, 'PwdWarn': 7})

NOW = int(time.time())


def state(name):
    out = Run('pwstate', name).stdout
    return {k: int(v) for k, v in (x.split('=') for x in out.split())}


def setstate(name, changed, fails=0, failtime=0, lockuntil=0):
    return Run('pwstate', name, str(changed), str(fails), str(failtime), str(lockuntil)).stdout.strip() == 'set'


for nm, pw, mode in (('LIM Hashed', 'Hashed Pw/1', '1'), ('LIM Plain', 'plainpw', None)):
    subprocess.run([build + '/useradd', nm, 'x'], env=env, capture_output=True, text=True)
    r = subprocess.run([build + '/netsetup', nm, '6'], env=dict(env, NETPWD=pw, **({'NETPWMODE': mode} if mode else {})), capture_output=True, text=True)
    check('%s is set up' % nm, 'ok' in r.stdout)
    setstate(nm, NOW - 86400)                       # the password was set yesterday


def logtext():
    p = ra + '/limits.log'
    return open(p, encoding='latin-1', errors='replace').read() if os.path.exists(p) else ''


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




# 1. wrong passwords: counted, kept; three of them lock the account
_o = bbs('LIM Hashed', 'Hashed Pw/1')
check('the right password gets in; no failures yet', in_(_o) and state('LIM Hashed')['fails'] == 0)
out, rc = session([('choice', '\r'), ('name:', 'LIM Hashed\r'), ('Password:', 'wrong one\r'), ('Password:', 'wrong two\r')], args=('-L',), tail=3)
check('two wrong passwords: counted (2), kept in the file at once, the time of the last one is there', state('LIM Hashed')['fails'] == 2 and abs(state('LIM Hashed')['failtime'] - NOW) < 120)
out, rc = session([('choice', '\r'), ('name:', 'LIM Hashed\r'), ('Password:', 'wrong three\r')], args=('-L',), tail=3)
st = state('LIM Hashed')
check('the third wrong password locks the account for LockMinutes (1): LockUntil is a minute ahead', st['fails'] == 3 and 0 < st['lockuntil'] - int(time.time()) <= 60)
check('the log says the account is locked', 'is locked for 1 minute(s): 3 wrong passwords in a row' in logtext())
check('a locked account takes no password, the right one included (and the caller is told nothing about a lock)', badlogin('LIM Hashed', 'Hashed Pw/1'))
out, rc = session([('choice', '\r'), ('name:', 'LIM Hashed\r'), ('Password:', 'Hashed Pw/1\r')], args=('-L',), tail=3)
check('... it is the ordinary "incorrect password" and no word of a lock', 'ocked' not in out and 'Incorrect' in out or 'incorrect' in out.lower())
check('... the failures are not counted on top while it is locked (still 3)', state('LIM Hashed')['fails'] == 3)
check('the log says that a locked account tried a password', 'Locked account LIM Hashed tried a password' in logtext())

# 2. the lock is over: the account works again, and tells the failures of the time before
setstate('LIM Hashed', NOW - 86400, 3, NOW - 120, NOW - 60)
out = bbs('LIM Hashed', 'Hashed Pw/1')
check('when the lock is over the right password gets in', in_(out))
check('... the failures of the time before are said (3 wrong passwords since your last log-on)', 'since your last log-on: 3' in out)
st = state('LIM Hashed')
check('... and are forgotten: no failures, no lock', st['fails'] == 0 and st['lockuntil'] == 0)

out, rc = session([('choice', '\r'), ('name:', 'LIM Hashed\r'), ('Password:', 'one more\r')], args=('-L',), tail=2)
setstate('LIM Hashed', NOW - 86400, 3, NOW - 120, NOW - 60)
session([('choice', '\r'), ('name:', 'LIM Hashed\r'), ('Password:', 'a wrong one\r')], args=('-L',), tail=2)
check('the first wrong password after a lock is a new count (1), not an instant new lock', state('LIM Hashed')['fails'] == 1 and state('LIM Hashed')['lockuntil'] == 0)
setstate('LIM Hashed', NOW - 86400)

# 3. a good password between the wrong ones starts the count again
out, rc = session([('choice', '\r'), ('name:', 'LIM Plain\r'), ('Password:', 'bad1\r'), ('Password:', 'bad2\r')], args=('-L',), tail=3)
check('plain account: two wrong passwords counted', state('LIM Plain')['fails'] == 2)
out = bbs('LIM Plain', 'plainpw')
check('... a good one gets in, says 2 and clears them', in_(out) and 'since your last log-on: 2' in out and state('LIM Plain')['fails'] == 0)

# 4. LockFails 0: never locked
d['config']['LockFails'] = 0
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
Run('mkcfgcvt', '-y', '5', '1', MKJSON=cj)
for i in range(2):
    session([('choice', '\r'), ('name:', 'LIM Plain\r'), ('Password:', 'x%d\r' % i), ('Password:', 'y%d\r' % i), ('Password:', 'z%d\r' % i)], args=('-L',), tail=2)
check('with Lock After Failures 0 nothing is counted and nothing locks', state('LIM Plain')['fails'] == 0 and in_(bbs('LIM Plain', 'plainpw')))
d['config']['LockFails'] = 3
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
Run('mkcfgcvt', '-y', '5', '1', MKJSON=cj)

# 4b. a configuration from before (LimitsMark 0, whatever bytes the four settings have): they are off
d['config']['LimitsMark'] = 0
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
Run('mkcfgcvt', '-y', '5', '1', MKJSON=cj)
session([('choice', '\r'), ('name:', 'LIM Plain\r'), ('Password:', 'q1\r'), ('Password:', 'q2\r'), ('Password:', 'q3\r')], args=('-L',), tail=2)
setstate('LIM Plain', NOW - 400 * 86400)
check('without the mark (an older config.mk) the limits are off: wrong passwords are not counted and a password of any age is good', state('LIM Plain')['fails'] == 0 and in_(bbs('LIM Plain', 'plainpw')))
# a hand made JSON that names a limit but not the mark: the loader says they are real
hand = work + '/hand'
os.makedirs(hand, exist_ok=True)
hd = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
del hd['config']['LimitsMark']
hd['config']['LockFails'] = 3
json.dump(hd, open(hand + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
mk5 = work + '/mk5'
os.makedirs(mk5, exist_ok=True)
Run('mkcfgcvt', '-y', '5', '1', MK=mk5, MKJSON=hand)
Run('mkcfgcvt', '-y', '1', '5', MK=mk5, MKJSON=work + '/back') if os.makedirs(work + '/back', exist_ok=True) is None else None
check('a JSON file that has LockFails and no LimitsMark: the mark is set by the loader (so the limit counts)', json.load(open(work + '/back/bbsconfig.json', encoding='utf-8'))['config'].get('LimitsMark') == 173)
d['config']['LimitsMark'] = 173
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
Run('mkcfgcvt', '-y', '5', '1', MKJSON=cj)

# 5. a password that is about to expire: told; one that has expired: must be changed
setstate('LIM Plain', NOW - 25 * 86400)             # 30 days: 5 left, warn at 7
out = bbs('LIM Plain', 'plainpw')
check('a password that expires in 5 days (warn 7): in gets, told "Your password expires in 5 day(s)."', in_(out) and 'Your password expires in 5 day(s).' in out)
setstate('LIM Plain', NOW - 10 * 86400)
check('a password with 20 days left: no word of it', 'expires' not in bbs('LIM Plain', 'plainpw'))
setstate('LIM Plain', NOW - 40 * 86400)             # expired
out = bbs('LIM Plain', 'plainpw', [('new password:', 'plainpw\r'), ('Re-enter', 'plainpw\r'), ('different from the old', ''), ('new password:', 'brandnew\r'), ('Re-enter', 'brandnew\r'),
                                  ('has been changed', ''), ('continue', '\r'), ('Command >', 'g'), ('Command >', 'y')], tail=3)
check('an expired password: "Your password has expired", a new one is asked for, the old one is refused as the new one, a new one is taken', 'has expired' in out and 'must be different from the old one' in out and 'has been changed' in out)
check('... the new password works, the old one does not, and the clock started again (changed = now)',
      in_(bbs('LIM Plain', 'brandnew')) and badlogin('LIM Plain', 'plainpw') and abs(state('LIM Plain')['changed'] - int(time.time())) < 300)
check('... the log says it was changed because it had expired', 'Password changed (it had expired)' in logtext())

# 6. an expired password that is not changed: the call ends
setstate('LIM Hashed', NOW - 40 * 86400)
out = bbs('LIM Hashed', 'Hashed Pw/1', [('new password:', 'a\r'), ('Re-enter', 'b\r'), ('new password:', 'a\r'), ('Re-enter', 'b\r'), ('new password:', 'a\r'), ('Re-enter', 'b\r')], tail=3)
check('an expired password that is not changed in 3 tries: the call ends, no menu', 'Minutes Remaining' not in out and 'this call ends' in out)
check('... and the password is still the old one', state('LIM Hashed')['changed'] == NOW - 40 * 86400)

# 7. a password that is not known to be old: the clock starts at the next good log-on, nobody is made to change at once
setstate('LIM Hashed', 0)
out = bbs('LIM Hashed', 'Hashed Pw/1')
check('a password with no date (an account from before): gets in at once, the clock starts now', in_(out) and 'has expired' not in out and abs(state('LIM Hashed')['changed'] - int(time.time())) < 300)

# 8. PwdExpire 0: never
d['config']['PwdExpire'] = 0
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
Run('mkcfgcvt', '-y', '5', '1', MKJSON=cj)
setstate('LIM Hashed', NOW - 400 * 86400)
check('with Password Expires 0 a password of any age is good', in_(bbs('LIM Hashed', 'Hashed Pw/1')))

# 9. the QWK node login (mk -Q): locks the same way, no expiry
d['config']['PwdExpire'] = 30
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
Run('mkcfgcvt', '-y', '5', '1', MKJSON=cj)
for nm, pw in (('LIM Node', 'Node Pw/1'),):
    subprocess.run([build + '/useradd', nm, 'x'], env=env, capture_output=True, text=True)
    subprocess.run([build + '/netsetup', nm, '6'], env=dict(env, NETPWD=pw, NETPWMODE='1'), capture_output=True, text=True)
    setstate(nm, NOW - 400 * 86400)


def qlogin(name, pwd):
    out, rc = session([('Login: ', name + '\r'), ('Password: ', pwd + '\r'), ('QWK: |Login incorrect', 'Q\r')])
    return 'QWK: ' in out


check('a QWK node with a password of any age gets in (an unattended login cannot change a password)', qlogin('LIM Node', 'Node Pw/1'))
for i in range(3):
    session([('Login: ', 'LIM Node\r'), ('Password: ', 'nope%d\r' % i), ('Login incorrect', '')], tail=1)
check('three wrong QWK logins in a row lock the node too: the right password is refused', state('LIM Node')['fails'] >= 3 and not qlogin('LIM Node', 'Node Pw/1'))
check('... and the log says so', 'QWK login for "LIM Node": the account is locked' in logtext())

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
