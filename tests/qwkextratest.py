#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The extras of a QWK packet from the door (mkqwk -L): the BBS screens, bulletins and the new files list (MKOffExt): what is in the
ZIP, the CONTROL.DAT names, a name with no file left out, the switches (Never / Always / as the user chose), and the new files date
moving only when the packet was made.  Private copy of the sample BBS.   usage: qwkextratest.py <build dir> <work dir>"""
import json, os, shutil, struct, subprocess, sys, time, zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
srcra = os.path.join(repo, 'bbs', 'bbsc', 'ra')
srcmko = os.path.join(repo, 'bbs', 'bbsc', 'mkqwk', 'config.mko')
if not (os.path.isdir(srcra) and os.path.exists(srcmko)) or not shutil.which('zip'):
    print('skip: no sample BBS, no sample config.mko or no zip'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
cfg = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(srcra), cfg, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'users.mko')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(cfg)
assert cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
                      lambda s: (cfg + '/').encode() + s[len((srcra + '/').encode()):] if s.startswith((srcra + '/').encode()) else s) >= 1
txt = cfg + '/txt/'                       # the text directory of the BBS (language 1 .. 10): the screens are looked for here
os.makedirs(txt)
cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/bbsc/myth/txtfiles/').encode(), lambda s: txt.encode())
outdir, udir, tdir = tmp + '/out', tmp + '/users', tmp + '/tmp'
for d in (outdir, udir, tdir):
    os.makedirs(d)
env = dict(os.environ, MK=cfg, TOSSATTACH=tmp + '/attach')
os.makedirs(tmp + '/attach', exist_ok=True)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'qwk extras: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


def run(prog, *a):
    return subprocess.run([os.path.join(build, prog)] + list(a), capture_output=True, text=True, env=env, encoding='latin-1')


# ---- the file areas: one area of ours with a files.bbs; the sample's areas are replaced (a roundtrip through the JSON configuration)
fdir = tmp + '/fa/'
os.makedirs(fdir)
for n, age in (('FRESH.ZIP', 2 * 86400), ('ALSONEW.ZIP', 2 * 86400), ('ANCIENT.ZIP', 40 * 365 * 86400)):   # DOS style names: the list is matched to the files in upper case
    p = fdir + n
    open(p, 'wb').write(b'x' * 1500)
    t = time.time() - age
    os.utime(p, (t, t))
open(fdir + 'files.bbs', 'w').write('FRESH.ZIP        A new file with a description that is long enough to be wrapped onto a second line of the list\n'
                                    'ALSONEW.ZIP       Another new one\nANCIENT.ZIP       Old\n')
cj = tmp + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True, input='', text=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
sec = lambda lv: {'Level': lv, 'Flags': 0}
dj['files'] = {'1': {'Name': 'Extras area', 'ShortName': 'Extras', 'FilePath': fdir, 'ViewSec': sec(0), 'DLSec': sec(0), 'ULSec': sec(255), 'PFileSec': sec(255), 'Attr': 0, 'Select': ''}}
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True, input='', text=True)

# ---- the screens and bulletins (an .asc for all, an .ans for the hello screen: the caller's terminal decides which is taken)
for n in ('hello', 'news', 'bye', 'bulla', 'bullb', 'nfhead'):
    open(txt + n + '.asc', 'w').write('%s ASCII screen\n' % n.upper())
open(txt + 'hello.ans', 'w').write('HELLO ANSI screen\n')

# ---- config.mko: the paths and ZIP made for this machine, the screens and bulletins named, the switches
d = bytearray(open(srcmko, 'rb').read())
PACKERS, TEMP = 203, 3063


def put(off, text, n):
    d[off:off + n + 1] = bytes([len(text)]) + text.encode() + bytes(n - len(text))


put(PACKERS + 143 * 1 + 1, 'zip -q -j', 70)
put(PACKERS + 143 * 1 + 72, 'unzip -o -q', 70)
put(TEMP, tdir, 80)
put(TEMP + 81, udir, 80)
o = TEMP + 81 + 81 + 2 + 600 + 4 + 2 + 2 + 1 + 1 + 2 + 1 + 56
put(o, tmp + '/screens', 80)
QATTR = TEMP + 81 + 81                                      # Attr of the door (qaQwke = 8: QWKE long names, and TOREADER.EXT)
NEWF, SCR, BULL = 60, 61, 62                              # NewFiles, Screens, Bulletins (0 no, 1 yes, 3 ask: the user's switch decides)
put(77, 'hello', 8); put(86, 'news', 8); put(95, 'bye', 8)
put(104, 'bulla', 8); put(113, 'bullb', 8); put(122, 'nobull', 8)       # the third has no file
put(194, 'nfhead', 8)


def config(newf, scr, bull, qwke=False):
    d[NEWF], d[SCR], d[BULL] = newf, scr, bull
    a = int.from_bytes(d[QATTR:QATTR + 2], 'little')
    d[QATTR:QATTR + 2] = ((a | 8) if qwke else (a & ~8)).to_bytes(2, 'little')
    open(outdir + '/config.mko', 'wb').write(d)


rec = bytearray(843)
rec[0] = 8; rec[1:9] = b'Mark May'
rec[36:40] = (1).to_bytes(4, 'little')
rec[40:43] = struct.pack('<HB', 6, 1)
o = 40 + 600
rec[o + 4:o + 6] = (500).to_bytes(2, 'little')
rec[o + 6:o + 8] = (100).to_bytes(2, 'little')
rec[o + 8] = ord('Z'); rec[o + 9] = ord('Z')
rec[o + 12] = 2
QUA_OWN, QUA_NEWFILE, QUA_SCREENS, QUA_BULL = 16, 0, 0, 0                # filled below from the constants of the door
UATTR = o + 10


def user(attr):
    rec[UATTR:UATTR + 2] = attr.to_bytes(2, 'little')
    open(udir + '/users.mko', 'wb').write(rec)


def packet(*extra):
    for f in os.listdir(outdir):
        if f.lower().endswith('.qwk'):
            os.remove(os.path.join(outdir, f))
    r = subprocess.run([os.path.join(build, 'mkqwk'), '-LMark_May'], capture_output=True, text=True, env=env, cwd=outdir, encoding='latin-1', timeout=60, stdin=subprocess.DEVNULL)
    pk = [f for f in os.listdir(outdir) if f.lower().endswith('.qwk')]
    z = zipfile.ZipFile(os.path.join(outdir, pk[0])) if pk else None
    return r, z


def names(z):
    return sorted(n.lower() for n in z.namelist()) if z else []


run('tosssetup', tmp + '/in', tmp + '/outb', tmp + '/un')
os.makedirs(tmp + '/in', exist_ok=True)
run('tossmake')
# the attribute bits of the user (MKQwk.Inc: qua constants): read them from the source so that the test follows them
inc = open(os.path.join(repo, 'src', 'MKQwk.Inc'), encoding='latin-1').read()
import re
bits = {m.group(1): int(m.group(2)) for m in re.finditer(r'\b(qua\w+)\s*=\s*(\d+)', inc)}
QUA_OWN, QUA_NEWFILE, QUA_SCREENS, QUA_BULL = bits['quaOwnMsgs'], bits['quaNewFile'], bits['quaScreens'], bits['quaBulletin']

# 1. Always (1) for all three: in every packet, whatever the user chose
config(1, 1, 1)
user(QUA_OWN)
r, z = packet()
n = names(z)
check('switches "Always": the packet has the hello, news and bye screens, two bulletins (BLT-1, BLT-2) and the new files list',
      z and {'news.asc', 'bye.asc', 'blt-1.asc', 'blt-2.asc', 'newfiles.dat'} <= set(n) and ('hello.ans' in n or 'hello.asc' in n), (n, r.stdout[-300:]))
check('... the bulletin with no file ("nobull") is left out (no BLT-3), nothing else is added', z and not [x for x in n if x.startswith(('nobull', 'blt-3'))], n)
if z:
    check('the bulletins have the contents of the screens (BLT-1 = bulla, BLT-2 = bullb)', z.read('blt-1.asc').decode('latin-1').startswith('BULLA') and z.read('blt-2.asc').decode('latin-1').startswith('BULLB'))
    check('without QWKE there is no TOREADER.EXT', 'toreader.ext' not in n, n)
if z:
    ctl = z.read([x for x in z.namelist() if x.lower() == 'control.dat'][0]).decode('latin-1').split('\n')
    hello = [x for x in n if x.startswith('hello.')][0]
    check('CONTROL.DAT names the screen files that are really there (%s, news.asc, bye.asc)' % hello, hello in [x.strip().lower() for x in ctl] and 'news.asc' in [x.strip().lower() for x in ctl]
          and 'bye.asc' in [x.strip().lower() for x in ctl], ctl[-30:])
    check('the contents are the screens as the BBS has them', z.read([x for x in z.namelist() if x.lower() == 'news.asc'][0]).decode('latin-1').startswith('NEWS ASCII screen'))
    nf = z.read([x for x in z.namelist() if x.lower() == 'newfiles.dat'][0]).decode('latin-1')
    check('the new files list: the heading screen, then the area, the new files with size and description (wrapped), a count',
          nf.startswith('NFHEAD ASCII screen') and 'Extras area' in nf and 'FRESH.ZIP' in nf and 'ALSONEW.ZIP' in nf and ' 1,500 ' in nf and 'New Files containing' in nf, nf)
    check('... not the file that is older than the user\'s new files date', 'ANCIENT.ZIP' not in nf, nf)
    check('... the long description is wrapped under the name (a continuation line starts with blanks)', any(l.startswith(' ' * 32) for l in nf.split('\n')), nf)
    check('the messages are still in the packet', 'messages.dat' in n and 'control.dat' in n, n)

# 1b. with QWKE (the door's switch): TOREADER.EXT, the BULL lines for the bulletins, the AREA line of conference 6
config(1, 1, 1, qwke=True)
user(QUA_OWN)
run('postmsg', '6', 'Poster', 'All', 'for the reader', 'text')
r, z = packet()
n = names(z)
tr = z.read('toreader.ext').decode('latin-1').split('\n') if z and 'toreader.ext' in n else []
check('QWKE on: TOREADER.EXT is in the packet', 'toreader.ext' in n, n)
area = [l for l in tr if l.startswith('AREA 6 ')]
check('... an AREA line for conference 6 (the one with messages): a for all, w for his own messages, the area flags (echomail: E)',
      len(area) == 1 and area[0].split(' ')[2].startswith('aw') and 'E' in area[0].split(' ')[2], tr)
check('... BULL lines for the two bulletins, as BLT-1 / BLT-2 with the names of the settings', 'BULL blt-1.asc bulla' in tr and 'BULL blt-2.asc bullb' in tr, tr)
check('... no AREA line for a conference with no messages in the packet', len([l for l in tr if l.startswith('AREA ')]) == 1, tr)

# 2. Never (0): none of them, whatever the user chose
config(0, 0, 0)
user(QUA_OWN | QUA_NEWFILE | QUA_SCREENS | QUA_BULL)
run('postmsg', '6', 'Poster', 'All', 'another one', 'text')
r, z = packet()
n = names(z)
check('switches "Never": no screens, bulletins or list, although the user asked', z and not any(x.startswith(('hello', 'news', 'bye', 'blt-', 'newfiles', 'toreader')) for x in n), n)

# 3. Ask (3): the user decides
config(3, 3, 3)
user(QUA_OWN)
run('postmsg', '6', 'Poster', 'All', 'a third', 'text')
r, z = packet()
n = names(z)
check('switches "ask", the user said no: none of them', z and not any(x.startswith(('news', 'bye', 'blt-', 'newfiles')) for x in n), n)
user(QUA_OWN | QUA_SCREENS)
run('postmsg', '6', 'Poster', 'All', 'a fourth', 'text')
r, z = packet()
n = names(z)
check('... the user said screens only: the screens, no bulletins, no list', z and 'news.asc' in n and 'bye.asc' in n and 'blt-1.asc' not in n and 'newfiles.dat' not in n, n)
user(QUA_OWN | QUA_BULL | QUA_NEWFILE)
run('postmsg', '6', 'Poster', 'All', 'a fifth', 'text')
r, z = packet()
n = names(z)
check('... bulletins and the list only', z and 'blt-1.asc' in n and 'blt-2.asc' in n and 'newfiles.dat' in n and 'news.asc' not in n, n)

# 4. the new files date moved when a packet with the list was made: a second list is empty (nothing uploaded since today)
config(1, 0, 0)
user(QUA_OWN)
run('postmsg', '6', 'Poster', 'All', 'a sixth', 'text')
r, z = packet()
n = names(z)
nf = z.read([x for x in z.namelist() if x.lower() == 'newfiles.dat'][0]).decode('latin-1') if z and 'newfiles.dat' in n else ''
check('the new files date moved with the earlier packet (to today): the list is empty now (0 new files)', '0 New Files containing' in nf and 'FRESH.ZIP' not in nf and ('since ' + time.strftime('%m-%d-%y')) in nf, nf)

# 5. TODOOR.EXT in a reply packet (QWKE): AREA D drops the conference, AREA a takes it, AREA p / g its mode, RESET moves the pointer;
#    lines for what MK does not have are said to be ignored
board = d[1:1 + d[0]].decode('latin-1').strip().upper()
repdir = tmp + '/rep'
os.makedirs(repdir, exist_ok=True)


def reply(lines):
    """a REP with an empty MSG (the reader's header block only) and a TODOOR.EXT; mkqwk -R takes it; returns what the door said"""
    for f in os.listdir(repdir):
        os.remove(os.path.join(repdir, f))
    shutil.copy(outdir + '/config.mko', repdir + '/config.mko')
    with zipfile.ZipFile(repdir + '/' + board + '.REP', 'w') as zz:
        zz.writestr(board + '.MSG', board.ljust(128).encode('latin-1'))
        zz.writestr('TODOOR.EXT', '\r\n'.join(lines) + '\r\n')
    r = subprocess.run([os.path.join(build, 'mkqwk'), '-RMark_May'], capture_output=True, text=True, env=env, cwd=repdir, encoding='latin-1', timeout=60, stdin=subprocess.DEVNULL)
    return r.stdout


config(0, 0, 0)
user(QUA_OWN)
run('postmsg', '6', 'Poster', 'All', 'before the drop', 'text')
out = reply(['AREA 6 D', 'AREA 7 D', 'KEYWORD olms', 'FILTER hacking', 'TWIT Death Wizard', 'REQUEST bob.zip', 'FILE x.zip a file', 'ATTACH y.zip 1'])
r, z = packet()
n = names(z)
check('... the next packet has nothing of conference 6 (dropped)', z is None or ('006.ndx' not in n and b'before the drop' not in z.read([x for x in z.namelist() if x.lower() == 'messages.dat'][0])), n)
out = reply(['AREA 6 a'])
r, z = packet()
n = names(z)
check('... the next packet has its messages again, from the last read pointer on', z and '006.ndx' in n, n)
out = reply(['RESET 6'])
r, z = packet()
n = names(z)
check('... the pointer is at the start of the message base: the packet has the old messages again',
      z and b'before the drop' in z.read([x for x in z.namelist() if x.lower() == 'messages.dat'][0]), n)
run('postmsg', '6', 'Poster', 'All', 'the last one', 'text')
out = reply(['RESET 6 1'])
r, z = packet()
n = names(z)
body = z.read([x for x in z.namelist() if x.lower() == 'messages.dat'][0]) if z and 'messages.dat' in n else b''
check('RESET 6 1: back one message from the end: only the last message of the base is in the packet (not the one before)', b'before the drop' not in body and b'the last one' in body, len(body))
out = reply(['AREA 6 p'])

# AREA 6 p: personal mail only: the message to the caller is in the packet, the one to All is not
reply(['AREA 6 p'])
run('postmsg', '6', 'Poster', 'All', 'to everybody', 'text')
run('postmsg', '6', 'Poster', 'Mark May', 'to the caller', 'text')
r, z = packet()
body = z.read([x for x in z.namelist() if x.lower() == 'messages.dat'][0]) if z and 'messages.dat' in names(z) else b''
check('AREA 6 p: personal mail only: the message to the caller is in the packet, the one to All is not', b'to the caller' in body and b'to everybody' not in body, len(body))
reply(['AREA 6 g'])
run('postmsg', '6', 'Poster', 'All', 'to everybody again', 'text')
r, z = packet()
body = z.read([x for x in z.namelist() if x.lower() == 'messages.dat'][0]) if z and 'messages.dat' in names(z) else b''
check('AREA 6 g: personal and to All: the message to All is in the packet', b'to everybody again' in body, len(body))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
