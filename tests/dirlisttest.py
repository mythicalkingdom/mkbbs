#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Menu command 31 (list files) in the real mk over telnet on a private copy of the sample BBS: a files.bbs list and a PCBoard DIR file (headers, primary lines with size and
date, secondary lines with a bar, an include file, @X codes) in the same folder, named in the data of the menu item.
usage: dirlisttest.py <build dir> <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
srcmenus = os.path.join(repo, 'bbs', 'bbsc', 'myth', 'menus')
if not (os.path.isdir(src) and os.path.isdir(srcmenus)) or not os.path.exists(build + '/mk'):
    print('skip: no sample BBS'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
menus = tmp + '/m'
ign = lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'chat.mk')) or not os.access(os.path.join(d, f), os.R_OK)]
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=ign)
cfgpatch.fix_sample(ra)
shutil.copytree(cfgpatch.snapshot(srcmenus), menus, ignore=ign)
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'dirlist: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


cj = os.path.join(work, 'cj'); os.makedirs(cj)
envj = dict(os.environ, MK=ra, MKJSON=cj)
os.makedirs(ra + '/temp', exist_ok=True)


def configure(chat):
    """the chat settings of the BBS (None: no chat.mk at all)"""
    subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
    dj = json.load(open(os.path.join(cj, 'bbsconfig.json'), encoding='utf-8'))
    dj['config']['TempPath'] = ra + '/temp/'
    if chat is not None:
        dj['chat'].update(chat)
    json.dump(dj, open(os.path.join(cj, 'bbsconfig.json'), 'w', encoding='utf-8'), ensure_ascii=False)
    subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def show(b):
    return b[-400:].decode('latin-1').replace('\r', '\\r').replace('\n', '\\n')


class Caller:
    def __init__(self):
        for _ in range(50):
            try:
                self.s = socket.create_connection(('127.0.0.1', 24691))
                break
            except OSError:
                time.sleep(0.1)
        self.s.sendall(bytes([255, 251, 0, 255, 253, 0]))
        self.buf = b''
        self.seen = b''
        self.until(b'language choice', 10)
        time.sleep(1.5); self.s.sendall(b'\r')
        self.until(b'last name: ', 10); time.sleep(2.5)
        self.s.sendall(b'Mark May\r'); self.until(b'assword'); time.sleep(0.5); self.s.sendall(b'windows\r')
        x = b''
        for _ in range(8):
            x = self.until(b'zzzz', 3)
            if b'continue' in x or b'Enter' in x:
                self.s.sendall(b'\r')
            else:
                break
        self.at_menu = b'Command >' in x

    def until(self, needle, secs=8):
        """read until the needle is in what came since the last call (returns everything of that time)"""
        self.s.settimeout(0.2)
        b = b''
        mores = 0
        end = time.time() + secs
        while time.time() < end and needle not in strip(b):
            try:
                d = self.s.recv(4096)
                if not d:
                    break
                b += d
                if b'\x1b[6n' in d:
                    self.s.sendall(b'\x1b[1;1R')
                if strip(b).count(b'More? (Y)es (N)o (C)ontinuous?') > mores:
                    mores += 1
                    self.s.sendall(b'c')
            except socket.timeout:
                pass
        self.seen += strip(b)
        return strip(b)

    def line(self, text):
        self.s.sendall(text.encode('latin-1') + b'\r')

    def close(self):
        self.s.close()


def start():
    global lst
    stop()
    lst = subprocess.Popen([build + '/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)
    time.sleep(1.5)


def stop():
    global lst
    if lst:
        lst.terminate(); lst.wait()
        lst = None
        time.sleep(0.5)




area = os.path.join(work, 'area')
os.makedirs(area)
open(area + '/README.TXT', 'w').write('x' * 100)
open(area + '/old.zip', 'w').write('y' * 5000)
open(area + '/files.bbs', 'w').write('README.TXT      The readme of the area\nold.zip         An old file from files.bbs\n')
open(area + '/disclaim.txt', 'w').write('This is the disclaimer file\n')
open(area + '/dir1', 'w').write(
    '=====[  PCBoard Program Files  ]=====\n'
    '\n'
    '%' + area + '/disclaim.txt\n'
    '\n'
    'PCBDEMO1.ZIP   315899  11-22-91  @X0EPCBoard Demo Disk #1\n'
    'OVLSIZE.ZIP      7986  11-25-91  Use to adjust the size of the overlay buf\n'
    '                               | in the VROOM OVERLAY version of PCBoard v\n'
    '                               | or v14.5a.\n'
    'PCBFILER.DOC    12345     15-NOV-93    00:00:00  \n'
    '\n'
    'The end of the list\n')

path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
used = {chr(d[i * REC + 7 + 1 + 75]).upper() for i in range(1, len(d) // REC) if d[i * REC] != 0}
free = [k for k in 'WXYZ1234567ABCDEFGHJKLNOPQRSTUV890' if k not in used]
keys = {}
slot = 1
for name, data in [('bbs', area), ('dir', area + ' dir1')]:
    while slot * REC < len(d) and d[slot * REC] != 0:
        slot += 1
    if (slot + 1) * REC > len(d):
        d += bytes((slot + 1) * REC - len(d))
    k = free.pop(0)
    r = bytearray(REC)
    r[0] = 31
    prompt = ('LIST ' + name).encode()
    r[7] = len(prompt); r[8:8 + len(prompt)] = prompt
    r[7 + 76] = ord(k)
    dd = data.encode()
    r[84] = len(dd); r[85:85 + len(dd)] = dd
    r[REC - 2] = 15; r[REC - 1] = 0
    d[slot * REC:(slot + 1) * REC] = r
    keys[name] = k
    slot += 1
open(path, 'wb').write(d)

cfg = {'mk': build + '/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-4', 'ports': [{'port': 24691, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = None
configure(None)

try:
    start()
    c = Caller()
    check('caller logged in', c.at_menu)
    c.s.sendall(keys['bbs'].encode())
    x = c.until(b'Press (Enter)', 10)
    check('files.bbs list: both files with their descriptions', b'The readme of the area' in x and b'An old file from files.bbs' in x, show(x))
    c.s.sendall(b'\r'); c.until(b'Command >', 8)
    c.s.sendall(keys['dir'].encode())
    x = c.until(b'Press (Enter)', 10)
    check('PCBoard DIR file: the header and the footer are shown', b'PCBoard Program Files' in x and b'The end of the list' in x, show(x))
    check('... the include file (%path) is shown, the line itself is not', b'This is the disclaimer file' in x and b'disclaim.txt' not in x, show(x))
    check('... a primary line: name, description with the @X code taken out', b'PCBDEMO1.ZIP' in x and b'PCBoard Demo Disk #1' in x and b'@X' not in x, show(x))
    check('... size and date of the list (the file is not in the folder)', b'315,899' in x or b'315899' in x, show(x))
    check('... secondary lines without the bar', b'in the VROOM OVERLAY' in x and b'or v14.5a.' in x and b'|' not in x, show(x))
    check('... the DD-MMM-YY line', b'PCBFILER.DOC' in x, show(x))
    c.s.sendall(b'\r'); y = c.until(b'Command >', 8)
    check('... at the menu again', b'Command >' in y, show(y))
    c.close()
finally:
    stop()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
