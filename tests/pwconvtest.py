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
    shutil.copytree(src, dst, ignore=lambda dd, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(dd, f), os.R_OK)])
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
print('failures:', fails)
sys.exit(1 if fails else 0)
