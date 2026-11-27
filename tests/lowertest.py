#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mklower: the references in a BBS that was set up with mixed case (language file names in config.mk, menu names and
screens in the menus) are made lower case; a private copy of the sample BBS.   usage: lowertest.py <mklower>"""
import os, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

mklower = os.path.abspath(sys.argv[1])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
srcmenus = os.path.join(repo, 'bbs', 'bbsc', 'myth', 'menus')
if not (os.path.isdir(src) and os.path.isdir(srcmenus)):
    print('skip: no sample BBS'); sys.exit(0)
ign = lambda d, n: [f for f in n if f.endswith('.mixedcase') or f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)]
ra = cfgpatch.short_dir() + '/r'
menus = ra.rsplit('/', 1)[0] + '/m'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=ign)
shutil.copytree(cfgpatch.snapshot(srcmenus), menus, ignore=ign)
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))
# the sample may have been migrated already: put the mixed case back in the copy (language file names, and the first word of
# the Data of the commands that take a name, in upper case)
cfgpatch.patch(os.path.join(ra, 'config.mk'), b'prompts', lambda s: s.upper())
REC0 = 167
for f in os.listdir(menus):
    p = os.path.join(menus, f)
    if f.endswith('.mnu') and os.path.isfile(p):
        d = bytearray(open(p, 'rb').read())
        for i in range(1, len(d) // REC0):
            o = i * REC0
            if d[o] in (1, 2, 4, 5, 6, 12, 40, 45):
                a = o + 7 + 76 + 1
                n = d[a]
                txt = bytes(d[a + 1:a + 1 + n])
                w, sep, rest = txt.partition(b' ')
                d[a + 1:a + 1 + n] = w.upper() + sep + rest
        open(p, 'wb').write(d)
env = {'PATH': os.environ['PATH'], 'MK': ra}
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mklower: ' + name)
    if not ok:
        fails += 1


def run(*a):
    return subprocess.run([mklower] + list(a), env=env, capture_output=True, text=True)


def snapshot():
    out = {}
    for d in (ra, menus):
        for f in os.listdir(d):
            p = os.path.join(d, f)
            if os.path.isfile(p):
                out[p] = open(p, 'rb').read()
    return out


REC = 167


def records(path):
    d = open(path, 'rb').read()
    return [d[i * REC:(i + 1) * REC] for i in range(len(d) // REC)]


def data_of(r):
    L = r[7 + 76 + 1]
    return r[7 + 76 + 2:7 + 76 + 2 + L].decode('latin-1')


before = snapshot()
r = run()
check('a dry run lists what it would do', r.returncode == 0 and 'would be made lower case' in r.stdout and 'REALTOP -> realtop' in r.stdout
      and 'language 3 file name PROMPTS -> prompts' in r.stdout)
check('... and changes nothing', snapshot() == before)

r = run('-w')
check('-w: done', r.returncode == 0 and 'made lower case' in r.stdout)
after = snapshot()
cfg_new = after[os.path.join(ra, 'config.mk')]
cfg_old = before[os.path.join(ra, 'config.mk')]
check('config.mk: the language file names are lower case, nothing else changed',
      b'\x07prompts' in cfg_new and b'\x07PROMPTS' not in cfg_new and len(cfg_new) == len(cfg_old) and
      sum(1 for a, b in zip(cfg_new, cfg_old) if a != b) < 80)
old_m = records(os.path.join(menus, 'file.mnu'))
new_m = records(os.path.join(menus, 'file.mnu'))
check('a copy of each changed file is kept (<name>.mixedcase) and is the original',
      os.path.exists(os.path.join(menus, 'file.mnu.mixedcase')) and
      open(os.path.join(menus, 'file.mnu.mixedcase'), 'rb').read() == before[os.path.join(menus, 'file.mnu')] and
      os.path.exists(os.path.join(ra, 'config.mk.mixedcase')))
orig = records(os.path.join(menus, 'file.mnu.mixedcase'))
new = records(os.path.join(menus, 'file.mnu'))
check('menu: "MESSAGE /M=1" is now "message /M=1" (only the first word)',
      any(data_of(a).startswith('MESSAGE /M=') and data_of(b) == 'message' + data_of(a)[7:] for a, b in zip(orig, new)))
changed_other = [i for i, (a, b) in enumerate(zip(orig, new)) if a != b and a[0] not in (1, 2, 4, 5, 6, 12, 40, 45)]
check('menu: items of other types are not touched (paths and programs stay)', not changed_other)
only_data = all(a[:7 + 76 + 1] == b[:7 + 76 + 1] and a[7 + 76 + 82:] == b[7 + 76 + 82:] for a, b in zip(orig, new))
check('menu: only the Data field of an item changed', only_data)
check('all the menu files are the same size as before', all(len(after[p]) == len(before[p]) for p in before if p.startswith(menus)))

after2 = snapshot()
r = run('-w')
check('a second run finds nothing to do', 'Nothing to do' in r.stdout and snapshot() == after2)

# a menu file whose own name is not lower case is only reported
shutil.copy(os.path.join(menus, 'file.mnu'), os.path.join(menus, 'Odd.MNU'))
r = run()
check('a menu file whose name is not lower case is reported, not renamed',
      'Odd.MNU: the file name is not lower case' in r.stdout and os.path.exists(os.path.join(menus, 'Odd.MNU')))
r = subprocess.run([mklower, '-x'], env=env, capture_output=True, text=True)
check('an unknown option is refused', r.returncode == 2)
r = subprocess.run([mklower], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('without MK: says what is needed', r.returncode == 1 and 'set MK' in r.stderr)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
