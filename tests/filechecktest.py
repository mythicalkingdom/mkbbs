#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mkfilecheck: file areas against their lists (files.bbs).  Two file areas of a private copy of the sample get directories that the test makes: a listed file that is not there, a file that is
there and not listed, a file listed twice, a name in another case; -f takes the lines of missing files out (with their description lines), -l lists the others, files.bbs.bak; the exit code.
usage: filechecktest.py <build dir> <work dir>"""
import json, os, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
live = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(live) or not os.path.exists(build + '/mkfilecheck'):
    print('skip: no sample BBS or mkfilecheck'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkfilecheck: ' + name + ('' if ok else '  ' + str(info)[-600:]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((live + '/').encode()):] if s.startswith((live + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
env = dict(os.environ, MK=ra)
cj = tmp + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
ks = sorted(d['files'], key=int)
A1, A2 = int(ks[0]), int(ks[1])
a1, a2 = tmp + '/f1/', tmp + '/f2/'
os.makedirs(a1); os.makedirs(a2)
for k, v in d['files'].items():
    v['FilePath'] = tmp + '/none/' + k + '/'                  # no other area has a directory that is there
d['files'][str(A1)]['FilePath'] = a1
d['files'][str(A2)]['FilePath'] = a2
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)


def put(p, text):
    open(p, 'w').write(text)


for n in ('GOOD.ZIP', 'newfile.zip', 'Mixed.Zip', 'SECOND.ZIP'):
    put(a1 + n, 'x')
put(a1 + 'files.bbs', 'GOOD.ZIP      A good file\n              with a long description\nGONE.ZIP      A file that is not there\n              its description,\n              two lines\nMIXED.ZIP     in another case\n; a comment\nSECOND.ZIP    listed\nSECOND.ZIP    listed again\n')
put(a2 + 'ONLY.ZIP', 'x')
put(a2 + 'files.bbs', 'ONLY.ZIP      all well\n')
list1 = open(a1 + 'files.bbs').read()


def run(*args):
    return subprocess.run([build + '/mkfilecheck'] + list(args), env=env, capture_output=True, text=True)


r = run('-a', str(A1), '-v')
check('a listed file that is not there, a file that is not listed, a file listed twice, a name in another case: all named, exit 2',
      r.returncode == 2 and 'listed, not there: GONE.ZIP' in r.stdout and 'there, not listed: newfile.zip' in r.stdout and 'listed twice: SECOND.ZIP' in r.stdout and 'case: listed as MIXED.ZIP, the file is Mixed.Zip' in r.stdout
      and '1 missing, 1 not listed, 1 listed twice, 1 in another case' in r.stdout, r.stdout + r.stderr)
check('the report changes nothing', open(a1 + 'files.bbs').read() == list1)
r = run('-a', str(A2))
check('an area that is right: no complaint, exit 0', r.returncode == 0 and '1 listed, 1 file(s)' in r.stdout and 'missing' not in r.stdout, (r.returncode, r.stdout))
r = run('-a', str(A1), '-f')
fixed = open(a1 + 'files.bbs').read()
check('-f: the line of the missing file and its two description lines are gone, the name in the wrong case is written as the file is, the others stay (comment, the file listed twice), the old list is files.bbs.bak',
      'GONE.ZIP' not in fixed and 'its description' not in fixed and 'two lines' not in fixed and 'GOOD.ZIP' in fixed and 'with a long description' in fixed and '; a comment' in fixed
      and fixed.count('SECOND.ZIP') == 2 and 'Mixed.Zip ' in fixed and 'MIXED.ZIP' not in fixed and open(a1 + 'files.bbs.bak').read() == list1, (fixed, r.stdout))
check('... exit 2 still: the file that is not listed is left to look at', r.returncode == 2 and 'there, not listed: newfile.zip' in r.stdout, (r.returncode, r.stdout))
r = run('-a', str(A1), '-f', '-l')
listed = open(a1 + 'files.bbs').read()
check('-l: the file that was not listed is listed with a line "(not described)"; then nothing is left: exit 0', r.returncode == 0 and re.search(r'newfile\.zip\s+\(not described\)', listed) if False else (r.returncode == 0 and 'newfile.zip' in listed and '(not described)' in listed), (r.returncode, listed, r.stdout))
r = run('-a', str(A1))
check('after the fixes the area is right (the duplicate is only noted)', r.returncode == 0 and '0 missing, 0 not listed, 1 listed twice, 0 in another case' in r.stdout, (r.returncode, r.stdout))
r = run('-a', '9999')
check('an area that is not there: exit 1', r.returncode == 1, (r.returncode, r.stderr))
r = subprocess.run([build + '/mkfilecheck', '-c', ra, '-a', str(A2), '-q'], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('-c <dir> instead of MK', r.returncode == 0 and 'file area(s) checked' in r.stdout, (r.returncode, r.stderr))
r = subprocess.run([build + '/mkfilecheck'], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('no configuration: exit 1', r.returncode == 1 and 'No configuration' in r.stderr, r.stderr)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
