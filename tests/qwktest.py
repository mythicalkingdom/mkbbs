#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mkqwk in local mode (-L): the QWK packet of a user's new mail, on a private copy of the sample BBS.
The user's settings are in users.mko (area 6 on, QWK, ZIP), the messages in area 6 are the two local ones tossmake writes.
usage: qwktest.py <build dir> <work dir>"""
import os, shutil, struct, subprocess, sys, zipfile

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
outdir = tmp + '/out'            # where the packet goes (the current directory of mkqwk)
udir = tmp + '/users'
tdir = tmp + '/tmp'
for d in (outdir, udir, tdir):
    os.makedirs(d)
env = dict(os.environ, MK=cfg, TOSSATTACH=tmp + '/attach')
os.makedirs(tmp + '/attach', exist_ok=True)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'qwk: ' + name)
    if not ok:
        fails += 1


# ---- config.mko: the paths and the ZIP packer made for this machine (the sample has DOS paths and programs)
d = bytearray(open(srcmko, 'rb').read())
PACKERS = 203
TEMP = 3063


def put(off, text, n):
    d[off:off + n + 1] = bytes([len(text)]) + text.encode() + bytes(n - len(text))


put(PACKERS + 143 * 1 + 1, 'zip -q -j', 70)           # packer 2 (ZIP): pack command
put(PACKERS + 143 * 1 + 72, 'unzip -o -q', 70)
put(TEMP, tdir, 80)
put(TEMP + 81, udir, 80)
o = TEMP + 81 + 81 + 2 + 600 + 4 + 2 + 2 + 1 + 1 + 2 + 1 + 56      # ScreenPath
put(o, tmp + '/screens', 80)
open(outdir + '/config.mko', 'wb').write(d)

# ---- users.mko: Mark May, area 6 on, QWK, ZIP
rec = bytearray(843)
rec[0] = 8; rec[1:9] = b'Mark May'
rec[36:40] = (1).to_bytes(4, 'little')                   # LastUsed
rec[40:43] = struct.pack('<HB', 6, 1)                    # UserConfs[1]: area 6, qctOn
o = 40 + 600
rec[o:o + 4] = bytes(4)                                  # NetStat
rec[o + 4:o + 6] = (500).to_bytes(2, 'little')           # MaxMsgs
rec[o + 6:o + 8] = (100).to_bytes(2, 'little')           # MaxConfMsgs
rec[o + 8] = ord('Z')                                    # Protocol
rec[o + 9] = ord('Z')                                    # Packer (ZIP)
rec[o + 10:o + 12] = (0).to_bytes(2, 'little')           # Attr
rec[o + 12] = 2                                          # MailType qmtQwk
open(udir + '/users.mko', 'wb').write(rec)                # Attr 0: the caller does not get his own messages


def run(prog, *a, **kw):
    return subprocess.run([os.path.join(build, prog)] + list(a), capture_output=True, text=True, env=env, encoding='latin-1', **kw)


r = run('tosssetup', tmp + '/in', tmp + '/outb', tmp + '/un')
os.makedirs(tmp + '/in', exist_ok=True)
r = run('tossmake')
check('two local messages are in area 6 (written like the BBS editor does)', r.returncode == 0)
# the two messages are from the caller himself: without "receive own messages" there is nothing for him
r = subprocess.run([os.path.join(build, 'mkqwk'), '-LMark_May'], capture_output=True, text=True, env=env, cwd=outdir, encoding='latin-1', timeout=60, stdin=subprocess.DEVNULL)
check('his own messages are not in his packet (no packet is made)', r.returncode == 0 and not [f for f in os.listdir(outdir) if f.lower().endswith('.qwk')])
rec[o + 10:o + 12] = (16).to_bytes(2, 'little')          # Attr: quaOwnMsgs
open(udir + '/users.mko', 'wb').write(rec)
r = subprocess.run([os.path.join(build, 'mkqwk'), '-LMark_May'], capture_output=True, text=True, env=env, cwd=outdir, encoding='latin-1', timeout=60, stdin=subprocess.DEVNULL)
print(r.stdout[-800:], r.stderr[-300:])
check('mkqwk -LMark_May runs (exit 0)', r.returncode == 0)
check('it says what it is (local mode banner)', 'MKQwk Offline Maildoor' in r.stdout)
pk = [f for f in os.listdir(outdir) if f.lower().endswith('.qwk')]
check('the packet is made in the current directory (BOARDID.qwk)', len(pk) == 1)
if pk:
    z = zipfile.ZipFile(os.path.join(outdir, pk[0]))
    names = sorted(n.lower() for n in z.namelist())
    check('it is a ZIP with control.dat and messages.dat', 'control.dat' in names and 'messages.dat' in names)
    ctl = z.read([n for n in z.namelist() if n.lower() == 'control.dat'][0]).decode('latin-1')
    msgs = z.read([n for n in z.namelist() if n.lower() == 'messages.dat'][0])
    check('control.dat names the BBS and the user', 'MARK MAY' in ctl.upper() and 'MYTHICAL' in ctl.upper())
    check('messages.dat holds the two messages of area 6 (128 byte blocks: header + text)', len(msgs) > 128 * 3 and b'local echo message' in msgs
          and b'local, not to be exported' in msgs)
# a second run: the last read pointer moved, there is nothing new
for f in pk:
    os.remove(os.path.join(outdir, f))
r = subprocess.run([os.path.join(build, 'mkqwk'), '-LMark_May'], capture_output=True, text=True, env=env, cwd=outdir, encoding='latin-1', timeout=60, stdin=subprocess.DEVNULL)
pk2 = [f for f in os.listdir(outdir) if f.lower().endswith('.qwk')]
if pk2:
    z = zipfile.ZipFile(os.path.join(outdir, pk2[0]))
    msgs2 = z.read([n for n in z.namelist() if n.lower() == 'messages.dat'][0]) if any(n.lower() == 'messages.dat' for n in z.namelist()) else b''
    check('a second run: nothing new (the last read pointer was moved)', b'local echo message' not in msgs2)
else:
    check('a second run: nothing new (no packet, or an empty one)', True)

# ---- the replies: a REP (a ZIP with BOARDID.MSG) for area 6, uploaded the local way (mkqwk -R: BOARDID.rep in the current directory)
board = d[1:1 + d[0]].decode('latin-1').strip()
repdir = tmp + '/rep'
os.makedirs(repdir)
shutil.copy(outdir + '/config.mko', repdir + '/config.mko')
r = run('qwkmsgtest', 'reply', repdir + '/' + board.upper() + '.MSG', '6', board)
check('the reply packet is made (3 messages, 2 in conference 6)', r.returncode == 0 and os.path.exists(repdir + '/' + board.upper() + '.MSG'))
with zipfile.ZipFile(repdir + '/' + board.upper() + '.REP', 'w') as z:
    z.write(repdir + '/' + board.upper() + '.MSG', board.upper() + '.MSG')
os.remove(repdir + '/' + board.upper() + '.MSG')
before = run('tossdump', '6').stdout
r = subprocess.run([os.path.join(build, 'mkqwk'), '-RMark_May'], capture_output=True, text=True, env=env, cwd=repdir, encoding='latin-1', timeout=60, stdin=subprocess.DEVNULL)
print(r.stdout[-600:], r.stderr[-300:])
check('mkqwk -RMark_May runs (exit 0)', r.returncode == 0)
after = run('tossdump', '6').stdout
check('the messages of conference 6 are in area 6 now',
      'subj=Reply via REP' in after and 'subj=Second reply' in after and 'reply line one|reply line two' in after and 'subj=Reply via REP' not in before)
check('... from the user (the sample forces the log-in name), to All / Sysop, echo and local flags like the BBS editor sets them',
      'from=Mark May to=All subj=Reply via REP' in after and 'from=Mark May to=Sysop subj=Second reply' in after and after.count('echo=TRUE') >= 3)
check('... with the tear and origin lines of the area', 'reply line two|--- MK Bbs v0.2| * Origin:' in after)
check('... the message of conference 999 (no such area, no area for bad messages) was not posted', 'Lost one' not in after)
check('the duplicate file is in the user directory', os.path.exists(udir + '/qwkdupe.dat'))
# the same packet again: duplicates, nothing new
r = subprocess.run([os.path.join(build, 'mkqwk'), '-RMark_May'], capture_output=True, text=True, env=env, cwd=repdir, encoding='latin-1', timeout=60, stdin=subprocess.DEVNULL)
after2 = run('tossdump', '6').stdout
check('the same reply packet again posts nothing (duplicates)', after2 == after)
os.remove(repdir + '/' + board.upper() + '.REP')
r = subprocess.run([os.path.join(build, 'mkqwk'), '-RMark_May'], capture_output=True, text=True, env=env, cwd=repdir, encoding='latin-1', timeout=60, stdin=subprocess.DEVNULL)
check('without a reply packet: says so, exit 0', r.returncode == 0)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
