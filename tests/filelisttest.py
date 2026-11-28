#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mkfilelist: the list of all files for a security profile (level, flags), the formats, new files, and the index (a flat binary cache of the lists and folders).
Three file areas of a private copy of the sample with folders that the test makes: area 1 for level 100, area 2 for level 200, area 3 for level 100 with flag 3.
usage: filelisttest.py <build dir> <work dir>"""
import json, os, re, shutil, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
live = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(live) or not os.path.exists(build + '/mkfilelist'):
    print('skip: no sample BBS or mkfilelist'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkfilelist: ' + name + ('' if ok else '  ' + str(info)[-700:]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() + s[len((live + '/').encode()):] if s.startswith((live + '/').encode()) else b'/nonexistent/' + s[len((repo + '/bbs/').encode()):])
idx = work + '/filelist.idx'
env = dict(os.environ, MK=ra, MKFILEIDX=idx)
cj = tmp + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
ks = sorted(d['files'], key=int)
A1, A2, A3 = int(ks[0]), int(ks[1]), int(ks[2])
f1, f2, f3 = tmp + '/f1/', tmp + '/f2/', tmp + '/f3/'
for p in (f1, f2, f3):
    os.makedirs(p)
for k, v in d['files'].items():
    v['FilePath'] = tmp + '/none/' + k + '/'
for k, p, lv, fl in ((A1, f1, 100, 0), (A2, f2, 200, 0), (A3, f3, 100, 4)):
    e = d['files'][str(k)]
    e['FilePath'] = p
    e['ViewSec'] = {'Level': lv, 'Flags': 0}
    e['DLSec'] = {'Level': lv, 'Flags': fl}
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)


def put(p, text, enc='latin-1'):
    open(p, 'w', encoding=enc).write(text)


for n, sz in (('alpha.zip', 100), ('Beta.TXT', 2000), ('old.lzh', 7)):
    open(f1 + n, 'wb').write(b'x' * sz)
old = time.time() - 90 * 86400
os.utime(f1 + 'old.lzh', (old, old))
put(f1 + 'files.bbs', 'alpha.zip     The first file\n              with a second line\nBeta.TXT      A \x82cole archive\nold.lzh       an old one\n')
open(f2 + 'secret.zip', 'wb').write(b'y' * 50)
put(f2 + 'files.bbs', 'secret.zip    sysop only\n')
open(f3 + 'flagged.zip', 'wb').write(b'z' * 30)
put(f3 + 'DIR', 'Header\nflagged.zip    30   11-14-23  A DIR file area\n   | and more\n')


def run(*args, e=None, check_rc=True):
    r = subprocess.run([build + '/mkfilelist'] + list(args), env=e or env, capture_output=True)
    return r


def txt(*args, **kw):
    r = run(*args, **kw)
    return r.returncode, r.stdout.decode('latin-1'), r.stderr.decode('latin-1')


rc, o, e = txt('-l', '100')
check('level 100: area 1 is listed with name, size, date and description (second line under it); area 2 (level 200) and area 3 (flag 3 needed) are not',
      rc == 0 and 'Area %d:' % A1 in o and re.search(r'alpha\.zip\s+100  \d{4}-\d\d-\d\d  The first file\n\s+with a second line', o) and 'secret.zip' not in o and 'flagged.zip' not in o, (rc, o, e))
check('... the descriptions are in the DOS character set as the list has them (a CP437 e acute is byte 0x82); the totals line', '\x82cole' in o and '3 files in 1 areas, 2107 bytes' in o, o[-300:])
rc, o, e = txt('-l', '200')
check('level 200: area 2 is listed too', 'secret.zip' in o and 'alpha.zip' in o and 'flagged.zip' not in o, o)
rc, o, e = txt('-l', '100', '-f', '3')
check('level 100 with flag 3: area 3 (a PCBoard DIR file there, the DIR file itself is not a file) is listed with the description of the DIR file, and the file name DIR is not',
      'flagged.zip' in o and 'A DIR file area' in o and 'and more' in o and not re.search(r'^  DIR ', o, re.M), o)
rc, o, e = txt('-l', '100', '-a', str(A3), '-f', '3')
check('-a: only that area', 'flagged.zip' in o and 'alpha.zip' not in o and '1 files in 1 areas' in o, o)
rc, o, e = txt('-l', '100', '-n', '30')
check('-n 30: the file that is 90 days old is left out', 'alpha.zip' in o and 'Beta.TXT' in o and 'old.lzh' not in o and 'New files on' in o, o)
rc, o, e = txt('-l', '100', '-u')
check('-u: the DOS characters come out as UTF-8', '\u00e9cole'.encode('utf-8').decode('latin-1') in o, repr(o[:400]))
r = run('-l', '100', '-t', 'json')
try:
    j = json.loads(r.stdout.decode('utf-8'))
except Exception as ex:
    j = {}
fl = {f['name']: f for a in j.get('areas', []) for f in a['files']}
check('-t json: areas with files (name, size, date, description or null), UTF-8, totals', j.get('level') == 100 and j.get('files') == 3 and fl['alpha.zip']['description'] == 'The first file\nwith a second line'
      and fl['Beta.TXT']['description'] == 'A \u00e9cole archive' and fl['alpha.zip']['size'] == 100 and j['bytes'] == 2107, (j, r.stderr))
rc, o, e = txt('-l', '200', '-t', 'dir')
check('-t dir: a header line for the area, then a PCBoard DIR line for each file (name, size flush right in column 20, date MM-DD-YY, description from column 34, a bar for the next lines)',
      re.search(r'^alpha\.zip +100   \d\d-\d\d-\d\d  The first file$', o, re.M) and re.search(r'^ {32}\| with a second line$', o, re.M) and '; Area %d:' % A1 in o, o)
rc, o, e = txt('-l', '100', '-o', work + '/all.txt')
check('-o: the list is a file (nothing on the screen, no .new left)', rc == 0 and o == '' and 'alpha.zip' in open(work + '/all.txt', encoding='latin-1').read() and not [n for n in os.listdir(work) if n.endswith('.new')], (rc, o, e, os.listdir(work)))
rc, o, e = txt('-l', '100', '-o', '/nonexistent/x/all.txt')
check('-o into a folder that is not there: a message, exit 1', rc == 1 and 'cannot write' in e, (rc, e))
check('without -l: a message, exit 1; a level that is no number: exit 1', txt()[0] == 1 and txt('-l', 'x')[0] == 1 and txt('-l', '1', '-f', '99')[0] == 1 and txt('-l', '1', '-a', '5-2')[0] == 1)
r = subprocess.run([build + '/mkfilelist', '-c', ra, '-l', '100', '-N'], env={'PATH': os.environ['PATH'], 'MKFILEIDX': idx}, capture_output=True)
check('-c <dir> instead of MK', r.returncode == 0 and b'alpha.zip' in r.stdout, (r.returncode, r.stderr))

# --- the index
check('the runs above made the index (a flat binary file: MKFX, version 1)', os.path.exists(idx) and open(idx, 'rb').read(4) == b'MKFX' and open(idx, 'rb').read(6)[4:6] == b'\x01\x00', os.path.exists(idx))
rc, o, e = txt('-S')
check('-S says what it holds', rc == 0 and re.search(r'3 areas, 5 files, \d+ bytes, made', o), o)
rc, with_idx, e = txt('-l', '200')
rc, without, e = txt('-l', '200', '-N')
strip = lambda s: re.sub(r'made \d{4}-\d\d-\d\d \d\d:\d\d', '', s)
check('the list from the index is the same as the one read from the lists and folders', strip(with_idx) == strip(without), (with_idx[:300], without[:300]))
# a change of the list that keeps its size and time: the index does not see it, -N does
st = os.stat(f1 + 'files.bbs')
text = open(f1 + 'files.bbs', 'rb').read()
open(f1 + 'files.bbs', 'wb').write(text.replace(b'The first file', b'The FIRST file'))
os.utime(f1 + 'files.bbs', ns=(st.st_atime_ns, st.st_mtime_ns))
rc, o1, e = txt('-l', '100')
rc, o2, e = txt('-l', '100', '-N')
check('the index is a cache: a list changed with the same size and time is not seen (with it), -N reads the lists', 'The first file' in o1 and 'The FIRST file' in o2, (o1[:300], o2[:300]))
# a change that shows: the list is newer / a new file in the folder
time.sleep(1.1)
open(f1 + 'files.bbs', 'a').write('newone.zip     a new file in the list\n')
open(f1 + 'newone.zip', 'wb').write(b'n' * 11)
rc, o, e = txt('-l', '100')
check('a list that changed (its time and size) and a new file in the folder: the area is read again and the new file is there, with the new description of the first', 'newone.zip' in o and 'a new file in the list' in o and 'The FIRST file' in o, o)
rc, o, e = txt('-l', '100')
check('... and the index was written again: the next run has it without reading', 'newone.zip' in o, o)
time.sleep(1.1)
os.remove(f1 + 'newone.zip')
rc, o, e = txt('-l', '100')
check('a file removed from the folder is gone from the list', 'newone.zip' not in o and 'alpha.zip' in o, o)
rc, o, e = txt('-I')
check('-I: makes the index again for every area and says what it holds', rc == 0 and re.search(r'3 areas, 5 files', o), (rc, o, e))
rc, o, e = txt('-l', '100')
check('after -I the file that was changed in place is seen', 'The FIRST file' in o, o)
bad = dict(env, MKFILEIDX='/nonexistent/dir/x.idx')
rc, o, e = txt('-l', '100', e=bad)
check('an index that cannot be written: the list is made all the same (the slow way)', rc == 0 and 'alpha.zip' in o, (rc, e))
open(idx, 'wb').write(b'MKFX\x01\x00garbage')
rc, o, e = txt('-l', '100')
check('a damaged index is ignored and written again', rc == 0 and 'alpha.zip' in o and open(idx, 'rb').read(4) == b'MKFX' and len(open(idx, 'rb').read()) > 40, (rc, e, len(open(idx, 'rb').read())))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
