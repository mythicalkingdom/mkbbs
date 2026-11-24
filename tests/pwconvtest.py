#!/usr/bin/env python3
"""mkpwconv -x (extusers.bbs to the record with the hash block) and the refusal of mk and mkusered to work on a file of the old size.
usage: pwconvtest.py <build dir> <work dir>"""
import os, subprocess, sys, shutil

build = os.path.abspath(sys.argv[1])
work = os.path.abspath(sys.argv[2])
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch
OLD, NEW = 431, 614
fails = 0


def check(ok, what):
    global fails
    print(('ok   ' if ok else 'FAIL'), 'pwconv:', what)
    if not ok:
        fails += 1


def run(*a, env=None):
    return subprocess.run(list(a), capture_output=True, text=True, env=env, stdin=subprocess.DEVNULL)


d = os.path.join(work, 'pw1')
shutil.rmtree(d, ignore_errors=True)
os.makedirs(d)
recs = [bytes([(i * 7 + j) % 251 for j in range(OLD)]) for i in range(5)]
open(d + '/extusers.bbs', 'wb').write(b''.join(recs))

r = run(build + '/mkpwconv', '-x', d)
new = open(d + '/extusers.bbs', 'rb').read()
check(r.returncode == 0 and len(new) == 5 * NEW, 'five records expanded (%d bytes)' % len(new))
check(all(new[i * NEW:i * NEW + OLD] == recs[i] and new[i * NEW + OLD:(i + 1) * NEW] == bytes(NEW - OLD) for i in range(5)),
      'the old fields are kept and the hash block is empty')
check(open(d + '/extusers.bbs.old', 'rb').read() == b''.join(recs), 'the old file is kept as extusers.bbs.old')
r = run(build + '/mkpwconv', '-x', d)
check(r.returncode == 0 and 'nothing to do' in r.stdout, 'a second run does nothing')

open(d + '/extusers.bbs', 'wb').write(b''.join(recs))     # old again, but the backup is there
r = run(build + '/mkpwconv', '-x', d)
check(r.returncode == 3 and open(d + '/extusers.bbs', 'rb').read() == b''.join(recs), 'an existing backup is never replaced (exit 3, file untouched)')

open(d + '/extusers.bbs', 'wb').write(bytes(1000))
os.remove(d + '/extusers.bbs.old')
r = run(build + '/mkpwconv', '-x', d)
check(r.returncode == 2, 'a size that fits neither record is refused (exit 2)')
r = run(build + '/mkpwconv', '-x', d + '/nothere')
check(r.returncode == 0 and 'nothing to do' in r.stdout, 'no file: nothing to do')

# mk and mkusered on a BBS whose extusers.bbs has the old size
src = os.path.join(here, '..', 'bbs', 'bbsc', 'ra')
if os.path.isdir(src) and os.path.exists(src + '/extusers.bbs.old'):
    dst = cfgpatch.short_dir() + '/r'
    shutil.copytree(cfgpatch.snapshot(src), dst, ignore=lambda dd, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(dd, f), os.R_OK)])
    shutil.copy(dst + '/extusers.bbs.old', dst + '/extusers.bbs')
    env = dict(os.environ, MK=dst)
    for prog, args in (('mk', ['-L']), ('mkusered', [])):
        r = run(build + '/' + prog, *args, env=env)
        check(r.returncode == 43 and 'mkpwconv -x' in r.stderr, prog + ' refuses the old file and says what to do')
    check(open(dst + '/extusers.bbs', 'rb').read() == open(dst + '/extusers.bbs.old', 'rb').read(), 'the old file was not changed')
    r = run(build + '/mkpwconv', '-x', dst)
    os.remove(dst + '/extusers.bbs.old') if False else None
else:
    print('skip: no sample BBS with extusers.bbs.old')

# ---- mkpwconv -h: the plain passwords of the user base become hashes
import time, pty, select, struct


def chk(name, ok):
    check(ok, name)


if os.path.isdir(src) and os.path.exists(build + '/netsetup'):
    UREC = 158                                     # UsersType: Pwd is the third field (after Name String[35], City String[25])
    PWOFF = 36 + 26
    tmp = cfgpatch.short_dir()
    ra = tmp + '/r'
    repo = os.path.realpath(os.path.join(here, '..'))
    shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda dd, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(dd, f), os.R_OK)
                                                    or f.lower().endswith(('.pwbak', '.old'))])
    cfgpatch.fix_sample(ra)
    cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
    env = dict(os.environ, MK=ra)
    r = subprocess.run([build + '/netsetup', 'Mark May', '6'], env=dict(env, NETPWD='NodePw'), capture_output=True, text=True)
    chk('the node user has a plain password', 'ok' in r.stdout)

    def pwds():
        u = open(ra + '/users.bbs', 'rb').read()
        return [u[i * UREC + PWOFF + 1:i * UREC + PWOFF + 1 + u[i * UREC + PWOFF]] for i in range(len(u) // UREC)]

    def names():
        u = open(ra + '/users.bbs', 'rb').read()
        return [u[i * UREC + 1:i * UREC + 1 + u[i * UREC]].decode('latin-1') for i in range(len(u) // UREC)]

    def digest():
        import hashlib
        return [hashlib.md5(open(ra + '/' + f, 'rb').read()).hexdigest() for f in ('users.bbs', 'extusers.bbs')]

    def mkpw(*a, e=None):
        return run(build + '/mkpwconv', *a, env=e or env)

    before = pwds()
    plain0 = sum(1 for x in before if x not in (b'', b'*'))
    d0 = digest()
    r = mkpw('-h', '-n')
    chk('dry run: counts the plain passwords, changes nothing, makes no backup',
          r.returncode == 0 and ('%d with a plain password' % plain0) in r.stdout and digest() == d0 and not os.path.exists(ra + '/users.bbs.pwbak'))

    open(ra + '/useron.bbs', 'wb').write(b'\x08Mark May' + bytes(27) + bytes(36) + bytes([1]) + bytes(2) + bytes(26) + bytes([3]))
    r = mkpw('-h', '-u', 'Mark May')
    chk('a caller on line: nothing is done (exit 5, the name is shown)', r.returncode == 5 and 'Mark May' in r.stdout and digest() == d0)
    r = mkpw('-h', '-u', 'Somebody Else')
    chk('... a caller who is not the one asked for does not stop it', r.returncode == 0 and 'Mark May' not in r.stdout)
    for f in ('users.bbs.pwbak', 'extusers.bbs.pwbak'):
        if os.path.exists(ra + '/' + f):
            os.remove(ra + '/' + f)
    os.remove(ra + '/useron.bbs')

    r = mkpw('-h', '-u', 'mark may', '-i', '300', '-v')
    p1 = pwds()
    nm = names()
    mm = [i for i, n in enumerate(nm) if n.upper() == 'MARK MAY'][0]
    chk('one user: his Pwd is * and the others are as they were', r.returncode == 0 and p1[mm] == b'*' and
          all(p1[i] == before[i] for i in range(len(p1)) if i != mm))
    chk('... the user is listed (-v), the iterations are those asked for, a backup was made',
          'Mark May' in r.stdout and '300 iterations' in r.stdout and os.path.exists(ra + '/users.bbs.pwbak') and os.path.exists(ra + '/extusers.bbs.pwbak'))
    ext = open(ra + '/extusers.bbs', 'rb').read()
    hb = ext[mm * NEW + OLD:(mm + 1) * NEW]
    chk('... the hash block: version 1, algorithm 1, upper case flag, 300 iterations, a salt and a hash, reserved bytes zero',
          hb[0] == 1 and hb[1] == 1 and hb[2] == 1 and struct.unpack('<i', hb[3:7])[0] == 300 and hb[7:23] != bytes(16) and hb[23:55] != bytes(32) and hb[55:] == bytes(128))
    chk('... the other extended records are untouched',
          all(ext[i * NEW:(i + 1) * NEW] == open(ra + '/extusers.bbs.pwbak', 'rb').read()[i * NEW:(i + 1) * NEW] for i in range(0, 50) if i != mm))
    r = mkpw('-h')
    chk('a backup of an earlier run is in the way: exit 3, nothing changed', r.returncode == 3 and pwds() == p1)

    def session(script, timeout=15, tail=2):
        m, s = pty.openpty()
        p = subprocess.Popen([build + '/mk', '-Q'], env=dict(env, TERM='ansi'), cwd=ra, stdin=s, stdout=s, stderr=s, close_fds=True)
        os.close(s)
        out = b''
        pos = 0
        for wait, send in script:
            t0 = time.time()
            while wait.encode() not in out[pos:] and time.time() - t0 < timeout:
                if select.select([m], [], [], 0.2)[0]:
                    try:
                        d = os.read(m, 4096)
                    except OSError:
                        break
                    if not d:
                        break
                    out += d
            if wait.encode() in out[pos:]:
                pos = out.index(wait.encode(), pos) + len(wait)
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
        return out.decode('latin-1')

    def login(pw):
        return 'QWK: ' in session([('Login: ', 'Mark May\r'), ('Password: ', pw + '\r'), ('QWK: ', 'Q\r')])

    chk('the converted user logs in with his old password, in any case', login('NodePw') and login('nodepw') and login('NODEPW'))
    chk('... and not with another', not login('NodePx'))

    for f in ('users.bbs.pwbak', 'extusers.bbs.pwbak'):
        os.remove(ra + '/' + f)
    r = mkpw('-h', '-i', '200')
    p2 = pwds()
    chk('the whole user base: no plain password is left',
          r.returncode == 0 and all(x in (b'', b'*') for x in p2) and sum(1 for x in p2 if x == b'*') == plain0)
    chk('... the report says how many', ('%d passwords converted' % (plain0 - 1)) in r.stdout and 'not MK cannot check' in r.stdout)
    r = mkpw('-h', '-n')
    chk('... a second dry run finds nothing to convert', r.returncode == 0 and '0 with a plain password' in r.stdout and
          ('%d with a hash already' % plain0) in r.stdout)
    for f in ('users.bbs.pwbak', 'extusers.bbs.pwbak'):
        os.remove(ra + '/' + f)
    r = mkpw('-h')
    chk('... and a real one converts nothing and says so', r.returncode == 0 and 'Nothing to convert' in r.stdout and not os.path.exists(ra + '/users.bbs.pwbak'))
    chk('... the converted user still logs in', login('nodepw'))

    # a directory that is not an MK configuration, and an old extusers.bbs
    d3 = os.path.join(work, 'notmk')
    shutil.rmtree(d3, ignore_errors=True)
    os.makedirs(d3)
    open(d3 + '/users.bbs', 'wb').write(bytes(UREC))
    open(d3 + '/extusers.bbs', 'wb').write(bytes(NEW))
    r = run(build + '/mkpwconv', '-h', d3)
    chk('not an MK configuration: refused (exit 4)', r.returncode == 4 and 'MK only' in r.stdout)
    open(d3 + '/config.mk', 'wb').write(b'x')
    open(d3 + '/extusers.bbs', 'wb').write(bytes(OLD))
    r = run(build + '/mkpwconv', '-h', d3)
    chk('an extusers.bbs of the old size: refused, says to run -x (exit 4)', r.returncode == 4 and 'mkpwconv  -x' in r.stdout.replace('-x', ' -x ').replace('  ', '  ') or (r.returncode == 4 and '-x' in r.stdout))
else:
    print('skip: no sample BBS')
print('failures:', fails)
sys.exit(1 if fails else 0)
