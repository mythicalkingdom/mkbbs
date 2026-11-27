#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mkbackup on a private copy of the sample BBS: a backup, its list and test, damage found, a restore (dry run, kept files, -f, another root), retention, the lock of
the message bases, the config .bak.   usage: backuptest.py <build dir> <work dir>"""
import glob, hashlib, os, shutil, subprocess, sys, tarfile, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
live = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(live) or not os.path.exists(build + '/mkbackup'):
    print('skip: no sample BBS or mkbackup'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkbackup: ' + name + ('' if ok else '  ' + str(info)[:500]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf',)) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
# the ra paths of config.mk lead to the copy, every other path to a place that is not there (the sample's other bases and file areas are not part of this test)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((live + '/').encode()):] if s.startswith((live + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
env = dict(os.environ, MK=ra)
out = tmp + '/b'


def run(*args, **kw):
    return subprocess.run([build + '/mkbackup'] + list(args), env=kw.get('env', env), capture_output=True, text=True)


sha = lambda p: hashlib.sha256(open(p, 'rb').read()).hexdigest()
before = {os.path.relpath(os.path.join(d, f), ra): sha(os.path.join(d, f)) for d, _, fs in os.walk(ra) for f in fs}
r = run('-o', out)
arcs = glob.glob(out + '/mkbbs-*.tar.gz')
check('a backup is made: exit 0, one archive, readable only by its owner', r.returncode == 0 and len(arcs) == 1 and (os.stat(arcs[0]).st_mode & 0o077) == 0, (r.returncode, r.stdout, r.stderr))
arc = arcs[0] if arcs else ''
try:
    t = tarfile.open(arc)
    names = t.getnames()
    ok_tar = True
except Exception as e:
    names, ok_tar = [], False
check('it is an ordinary tar.gz (python tarfile opens it), the manifest is the last entry', ok_tar and names and names[-1] == 'MKBACKUP.MANIFEST', names[-3:])
cfgname = ra.lstrip('/') + '/config.mk'
check('the configuration directory is in it (config.mk, the user files, the message base files of the area directory)', cfgname in names and ra.lstrip('/') + '/msgidx.bbs' in names and ra.lstrip('/') + '/users.bbs' in names, [n for n in names if n.endswith('.mk')][:5])
if ok_tar and cfgname in names:
    check('the content is the file as it was', hashlib.sha256(t.extractfile(cfgname).read()).hexdigest() == before['config.mk'])
check('the lists of the file areas (files.bbs of each area that has one) are in it', any(n.endswith('/files.bbs') and not n.startswith(ra.lstrip('/')) for n in names), [n for n in names if 'files.bbs' in n][:3])
check('the node directories, locks and the backup directory itself are not in it', not any('/node1/' in n or n.endswith('.lock') or '/backup/' in n for n in names))
r = run('-l', arc)
check('-l lists the files with size and time', r.returncode == 0 and ra + '/config.mk' in r.stdout and 'file(s)' in r.stdout, r.stdout[-200:])
r = run('-t', arc)
check('-t: the archive is good, every checksum matches', r.returncode == 0 and 'is good' in r.stdout, r.stdout + r.stderr)
# damage: one byte flipped in the middle of the compressed data
bad = work + '/bad.tar.gz'
d = bytearray(open(arc, 'rb').read())
d[len(d) // 2] ^= 0xFF
open(bad, 'wb').write(d)
r = run('-t', bad)
check('a damaged archive is found by -t (exit 3, or the decompression fails)', r.returncode != 0, (r.returncode, r.stdout, r.stderr))
# a truncated archive
open(work + '/short.tar.gz', 'wb').write(open(arc, 'rb').read()[:len(d) // 2])
r = run('-t', work + '/short.tar.gz')
check('a truncated archive is found (no manifest or damaged)', r.returncode != 0, (r.returncode, r.stderr))

# restore: first the dry run, the files are as they are: nothing to do
root = work + '/root'
r = run('-r', arc, '-n', '-C', root)
check('restore -n -C root: says it would restore the files, writes nothing', r.returncode == 0 and 'would restore' in r.stdout and not os.path.exists(root), (r.returncode, r.stdout[-300:], r.stderr[-200:]))
r = run('-r', arc, '-C', root)
rel = ra + '/config.mk'
check('restore -C root: the files are below root, with their content', r.returncode == 0 and os.path.exists(root + rel) and sha(root + rel) == before['config.mk'], (r.returncode, r.stdout[-300:], r.stderr[-200:]))
check('... every file of the sample is there and the same', all(os.path.exists(root + ra + '/' + k) and sha(root + ra + '/' + k) == v for k, v in before.items() if not k.startswith(('node', 'backup'))))
# restore into place after damage
open(ra + '/config.mk', 'ab').write(b'X')
os.remove(ra + '/users.bbs')
r = run('-r', arc, '-n')
check('dry run in place: the file that differs is "kept (differs; -f replaces it)", the missing one "would restore"', 'kept (differs' in r.stdout and 'would restore' in r.stdout and ra + '/users.bbs' in r.stdout, r.stdout[-400:])
r = run('-r', arc, env=dict(env))
check('restore in place without -f: the missing file comes back, the changed one is kept', os.path.exists(ra + '/users.bbs') and sha(ra + '/users.bbs') == before['users.bbs'] and sha(ra + '/config.mk') != before['config.mk'], (r.stdout[-300:], r.stderr[-200:]))
r = run('-r', arc, '-f')
check('restore -f: the changed file is replaced, the old one is kept as config.mk.pre-restore', sha(ra + '/config.mk') == before['config.mk'] and os.path.exists(ra + '/config.mk.pre-restore'), r.stdout[-300:])
# a mk that runs on this BBS: a restore in place is refused (not a dry run, not -C, not -f)
fake = tmp + '/mk'
shutil.copy('/bin/sleep', fake)
proc = subprocess.Popen([fake, '60'], env=dict(env), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(0.5)
open(ra + '/config.mk', 'ab').write(b'Y')
r = run('-r', arc)
check('a mk that runs on this BBS: the restore in place is refused (exit 4)', r.returncode == 4 and 'is running' in r.stderr and sha(ra + '/config.mk') != before['config.mk'], (r.returncode, r.stderr))
r = run('-r', arc, '-n')
check('... a dry run is allowed', r.returncode == 0, (r.returncode, r.stderr))
r = run('-r', arc, '-C', work + '/root2')
check('... and a restore into another root', r.returncode == 0 and os.path.exists(work + '/root2' + ra + '/config.mk'), (r.returncode, r.stderr))
r = run('-r', arc, '-f')
check('... and -f restores under it', r.returncode == 0 and sha(ra + '/config.mk') == before['config.mk'], (r.returncode, r.stderr))
proc.kill(); proc.wait()
# retention
time.sleep(1.1)
run('-o', out, '-q'); time.sleep(1.1); run('-o', out, '-q'); time.sleep(1.1)
r = run('-o', out, '-q', '-k', '2')
check('-k 2 keeps the two newest archives', len(glob.glob(out + '/mkbbs-*.tar.gz')) == 2, glob.glob(out + '/*'))
# the default place: the backup directory below the configuration directory
r = run('-q')
check('without -o the archive goes to <configuration directory>/backup', len(glob.glob(ra + '/backup/mkbbs-*.tar.gz')) == 1, os.listdir(ra))
r = run('-q')
check('... and the backup directory is not part of the next backup', not any('/backup/' in n for n in tarfile.open(sorted(glob.glob(ra + '/backup/*.tar.gz'))[-1]).getnames()))
# -c names the configuration directory
r = run('-c', ra, '-q', '-o', out + '2', env={'PATH': os.environ['PATH']})
check('-c <dir> instead of MK in the environment', r.returncode == 0 and len(glob.glob(out + '2/mkbbs-*.tar.gz')) == 1, (r.returncode, r.stderr))
# no configuration
r = run('-q', env={'PATH': os.environ['PATH']})
check('no configuration: exit 1, says so', r.returncode == 1 and 'No configuration' in r.stderr, (r.returncode, r.stderr))
check('nothing was written into the live sample', not os.path.exists(live + '/backup'))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
