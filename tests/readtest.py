#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""MKRead through a pseudo terminal on a private copy of the sample BBS:
read a Squish message, then reply into the local Hudson area and check the base grew.
usage: readtest.py <work dir>   (needs bbs/bbsc/ra, i.e. the sample BBS)"""
import json, os, subprocess, sys, shutil

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch
root = os.path.join(here, '..')
work = os.path.abspath(sys.argv[1])
src = os.path.join(root, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
dst = cfgpatch.short_dir() + '/r'      # a short path: the configuration holds it in a fixed size field
shutil.copytree(cfgpatch.snapshot(src), dst, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(dst)
# point the message base directory of the Hudson areas at the private copy and every other
# directory of the sample BBS at a place that does not exist: the test must never write
# into the real sample bases
p = os.path.join(dst, 'config.mk')
root = os.path.realpath(os.path.join(root, 'bbs')).encode() + b'/'
ra = os.path.realpath(src).encode() + b'/'
new = dst.encode() + b'/'
cfgpatch.patch(p, root, lambda s: new if s == ra else b'/nonexistent/' + s[len(root):])
# the areas by name, not by number: the one that is read is "T Pascal" of the sample (it has Squish-style test messages in the Hudson base), the reply goes into
# the first local Hudson area; the position in the list of areas for the reply is the area number (the list has a row for every number, named or not)
jd = os.path.join(os.path.dirname(dst), 'j')
os.makedirs(jd, exist_ok=True)
subprocess.run([os.path.join(here, '..', 'build', 'mkcfgcvt'), '-y', '1', '5'], env=dict(os.environ, MK=dst, MKJSON=jd), capture_output=True, check=True)
areas = {int(k): v for k, v in json.load(open(os.path.join(jd, 'bbsconfig.json'), encoding='utf-8'))['messages'].items()}
read_area = [n for n, a in areas.items() if a['Name'] == 'T Pascal' and a['MsgBaseType'] == 'H'][0]
reply_area = min(n for n, a in areas.items() if a['MsgBaseType'] == 'H' and a['MsgType'] == 0 and a['Name'])
print('areas: read %d %s, reply in %d %s' % (read_area, areas[read_area]['Name'], reply_area, areas[reply_area]['Name']))
env = dict(os.environ, CFGPROG='mkread', CFGCWD=dst, CFGDIR=dst, CFGDELAY='0.8', CFGARGS='-A%d' % read_area)
shot = os.path.join(here, 'cfgshot.py')


def run(*keys):
    r = subprocess.run([sys.executable, shot] + list(keys), env=env, capture_output=True, text=True)
    return r.stdout


run('\r')                                     # first run: accept the default settings (writes MKRead.Cfg)
sizes = lambda: {f: os.path.getsize(os.path.join(dst, f)) for f in ('msgidx.bbs', 'msghdr.bbs', 'msgtxt.bbs')}
size0 = sizes()
text0 = open(os.path.join(dst, 'msgtxt.bbs'), 'rb').read().count(b'reply from the test')   # (earlier runs of this test left copies in the sample)
s = run()                                      # -A<n> opens that area at once
ok1 = 'Area: %d %s' % (read_area, areas[read_area]['Name']) in s and 'From: Patrick' in s
print('ok  ' if ok1 else 'FAIL', 'mkread: a message is displayed')
# r: the list of areas for the reply (it opens at the area that is being read); Page Up to the top (area 1: Home does not move it), one Down for each
# row after the first, Enter takes it
run('r', *(['\\x1b[5~'] * (read_area // 10 + 3)), *(['\\x1b[B'] * (reply_area - 1)), '\\r', '\\r', '\\r', 'n', 'reply from the test\\r', '\\x1b', 'y', 'y')
size1 = sizes()
text = open(os.path.join(dst, 'msgtxt.bbs'), 'rb').read()
ok2 = size1['msgidx.bbs'] == size0['msgidx.bbs'] + 3 and size1['msghdr.bbs'] > size0['msghdr.bbs'] and size1['msgtxt.bbs'] > size0['msgtxt.bbs']
print('ok  ' if ok2 else 'FAIL', 'mkread: a reply was written to the Hudson base: index, header and text files grew (%s -> %s)' % (size0, size1))
ok3 = text.count(b'reply from the test') == text0 + 1
print('ok  ' if ok3 else 'FAIL', 'mkread: the text of the reply is in the base')
hdr = open(os.path.join(dst, 'msghdr.bbs'), 'rb').read()[-187:]          # the header of the new message: the board (the area number) is the byte at 26
print('ok  ' if hdr[26] == reply_area else 'FAIL', 'mkread: the reply is in the area that was picked by name (board %d, wanted %d: %s)' % (hdr[26], reply_area, areas[reply_area]['Name']))
sys.exit(0 if (ok1 and ok2 and ok3 and hdr[26] == reply_area) else 1)
