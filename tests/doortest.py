#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Menu command 172 (a door of doors.cfg) in the real mk, over telnet, on a private copy of the sample BBS, with a fake dosemu (a script that records what it was given and
acts as a door on its terminal) and a native door.   usage: doortest.py <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
work = os.path.abspath(sys.argv[1])
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
srcmenus = os.path.join(repo, 'bbs', 'bbsc', 'myth', 'menus')
if not (os.path.isdir(src) and os.path.isdir(srcmenus)):
    print('skip: no sample BBS'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
menus = tmp + '/m'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(ra)
shutil.copytree(cfgpatch.snapshot(srcmenus), menus, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
txt = tmp + '/t'
os.makedirs(txt)
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode(), (repo + '/bbs/bbsc/myth/txtfiles/').encode(): (txt + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))




# the fake dosemu and the doors
log = tmp + '/log'
os.makedirs(log)
fake = tmp + '/fakedosemu'
open(fake, 'w').write("""#!/bin/sh
LOG=%s
rm -f $LOG/*
for a in "$@"; do echo "[$a]"; done > $LOG/args
pwd > $LOG/pwd
while [ $# -gt 0 ]; do case "$1" in -K) K=$2; shift 2;; *) shift;; esac; done
echo "$K" > $LOG/work
ls "$K" > $LOG/names
[ -L "$K/LORD.EXE" ] && echo link > $LOG/link
[ -L "$K/sub/DATA.DAT" ] && echo sublink > $LOG/sublink
cp "$K/mkdoor.bat" $LOG/bat
cp "$K/dorinfo1.def" $LOG/dorinfo
[ -f "$K/door.sys" ] && cp "$K/door.sys" $LOG/doorsys
printf 'FAKEDOS READY\\r\\n'
read x
printf 'GOT:%%s\\r\\n' "$x"
""" % log)
os.chmod(fake, 0o755)
doors = tmp + '/doors'
os.makedirs(doors + '/lord/sub')
os.makedirs(doors + '/natv')
open(doors + '/lord/LORD.EXE', 'w').write('x')
open(doors + '/lord/sub/DATA.DAT', 'w').write('d')
open(doors + '/natv/hello.sh', 'w').write('#!/bin/sh\necho "NATIVE:$(basename $PWD) $(ls door.sys callinfo.bbs 2>&1 | tr "\\n" " ")"\n')
os.chmod(doors + '/natv/hello.sh', 0o755)
os.makedirs(doors + '/n32')
open(doors + '/n32/d32.sh', 'w').write('#!/bin/sh\necho "D32-BEGIN"\ncat -v door32.sys\necho "D32-END"\n')
os.chmod(doors + '/n32/d32.sh', 0o755)
workbase = tmp + '/dw'


def write_cfg(dosemu=fake):
    open(ra + '/doors.cfg', 'w').write("""# test doors
[global]
dosemu = %s
tmp = %s

[lord]
type = dos
dir = %s/lord
command = LORD.EXE *N    # the node
subdir = sub
com = 2
sandbox = off
dropfiles = dorinfo1.def door.sys

[natv]
type = native
dir = %s/natv
command = hello.sh
dropfiles = door.sys
sandbox = off
[d32]
type = native
dir = %s/n32
command = d32.sh
dropfiles = door32.sys
sandbox = off
[d32raw]
type = native
dir = %s/n32
command = d32.sh
dropfiles = door32.sys
raw = yes
sandbox = off
[nodir]
type = dos
dir = /nonexistent/dir
command = X.EXE
""" % (dosemu, workbase, doors, doors, doors, doors))


write_cfg()
path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
slot = 1


def add_item(typ, key, prompt, data=''):
    global slot, d
    while slot * REC < len(d) and d[slot * REC + 7] != 0:
        slot += 1
    if (slot + 1) * REC > len(d):
        d += bytes((slot + 1) * REC - len(d))
    r = bytearray(REC)
    r[0] = typ
    pb = prompt.encode()
    r[7] = len(pb); r[8:8 + len(pb)] = pb
    r[83] = ord(key)
    db = data.encode()
    r[84] = len(db); r[85:85 + len(db)] = db
    r[REC - 2] = 7
    d[slot * REC:(slot + 1) * REC] = r
    slot += 1


add_item(172, '5', 'DOOR-LORD', 'lord')
add_item(172, '6', 'DOOR-NONE', 'nosuchdoor')
add_item(172, '7', 'DOOR-NATV', 'natv')
add_item(172, '8', 'DOOR-NODIR', 'nodir')
add_item(172, '9', 'DOOR-D32', 'd32')
add_item(172, 'A', 'DOOR-D32RAW', 'd32raw')
open(path, 'wb').write(d)
cfg = {'mk': repo + '/build/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': 24774, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = subprocess.Popen([repo + '/build/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'door command: ' + name + ('' if ok else '  ' + str(info)[-600:]))
    if not ok:
        fails += 1


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def until(s, needle, secs=8):
    s.settimeout(0.2)
    b = b''
    end = time.time() + secs
    while time.time() < end and needle not in strip(b):
        try:
            x = s.recv(4096)
            if not x:
                break
            b += x
            if b'\x1b[6n' in x:
                s.sendall(b'\x1b[1;1R')
        except socket.timeout:
            pass
    return strip(b)


def conn(port):
    for _ in range(50):
        try:
            return socket.create_connection(('127.0.0.1', port))
        except OSError:
            time.sleep(0.1)
    raise SystemExit('cannot connect')


def rd(n):
    try:
        return open(log + '/' + n, 'rb').read().decode('latin-1')
    except OSError:
        return None


try:
    c = conn(24774)
    until(c, b'language choice', 10); time.sleep(1.5); c.sendall(b'\r')
    until(c, b'last name: ', 10); time.sleep(2.5)
    c.sendall(b'Mark May\r'); until(c, b'assword'); time.sleep(0.5); c.sendall(b'windows\r')
    seen = b''
    for _ in range(8):
        x = until(c, b'zzzz', 3)
        seen += x
        if b'continue' in x or b'Enter' in x:
            c.sendall(b'\r')
        else:
            break
    check('caller logged in to the menu', b'Command >' in seen, seen[-200:])

    # a DOS door
    c.sendall(b'5')
    t = until(c, b'FAKEDOS READY', 12)
    check('a DOS door runs (the fake dosemu answers on the caller\'s terminal)', b'FAKEDOS READY' in t, t[-300:])
    c.sendall(b'hello\r')
    t = until(c, b'GOT:hello', 6)
    check('what the caller types reaches the door', b'GOT:hello' in t, t[-300:])
    t += until(c, b'Command >', 8)
    check('the menu comes back when the door ends', b'Command >' in t, t[-200:])
    args = (rd('args') or '').split('\n')
    work_dir = (rd('work') or '').strip()
    check('dosemu is called with -dumb -quiet, -K <work directory>, the COM port of the door and the batch file',
          '[-dumb]' in args and '[-quiet]' in args and '[-K]' in args and ('[%s]' % work_dir) in args and '[-I]' in args and '[serial { virtual com 2 }]' in args and '[-E]' in args and '[mkdoor.bat]' in args and work_dir == workbase + '/node1', (args, work_dir))
    check('the work directory has the door\'s files as links (also below the directories)', rd('link') == 'link\n' and rd('sublink') == 'sublink\n', (rd('link'), rd('sublink')))
    di = (rd('dorinfo') or '').split('\r\n')
    check('DORINFO1.DEF has the COM port of the door in line 4, CR LF line ends', len(di) > 5 and di[3] == 'COM2' and '\n' not in ''.join(di), di[:6])
    ds = (rd('doorsys') or '').split('\r\n')
    check('DOOR.SYS has COM2: in line 1', len(ds) > 5 and ds[0] == 'COM2:' and 'MARK' in (rd('doorsys') or '').upper(), ds[:4])
    names = (rd('names') or '').split()
    check('only the drop files the door names are there (no CALLINFO.BBS), and mkdoor.bat', 'callinfo.bbs' not in names and 'door.sys' in names and 'dorinfo1.def' in names and 'mkdoor.bat' in names, names)
    check('mkdoor.bat: cd into the subdirectory, then the command with *N the node', rd('bat') == '@echo off\r\ncd sub\r\nLORD.EXE 1\r\n', repr(rd('bat')))
    check('dosemu runs in the directory of the node', (rd('pwd') or '').strip().endswith('/node1'), rd('pwd'))
    check('the work directory is gone after the call, the door\'s own files are not touched', not os.path.exists(work_dir) and os.path.exists(doors + '/lord/LORD.EXE') and os.path.exists(doors + '/lord/sub/DATA.DAT'))

    # not there
    c.sendall(b'6')
    t = until(c, b'not available', 6)
    check('a door that is not in doors.cfg: "This door is not available"', b'This door is not available' in t, t[-200:])
    c.sendall(b'\r'); until(c, b'Command >', 6)
    c.sendall(b'8')
    t = until(c, b'not available', 6)
    check('a door whose directory is not there: not available', b'This door is not available' in t, t[-200:])
    c.sendall(b'\r'); until(c, b'Command >', 6)

    # native
    c.sendall(b'7')
    t = until(c, b'NATIVE:', 8)
    t += until(c, b'Command >', 6)
    check('a native door runs as command 7 does: in the node directory, with DOOR.SYS (and no CALLINFO.BBS)', b'NATIVE:node1' in t and b'door.sys' in t and b'No such file' in t, t[-300:])

    # DOOR32.SYS
    def d32(key):
        c.sendall(key)
        t = until(c, b'D32-END', 8)
        until(c, b'Command >', 6)
        m = re.search(rb'D32-BEGIN\r?\n(.*?)D32-END', t, re.S)
        d32.raw = m.group(1) if m else b''
        return [l.rstrip(b'^M').decode('latin-1') for l in m.group(1).replace(b'\r', b'').split(b'\n') if l] if m else None
    L = d32(b'9')
    check('DOOR32.SYS: 11 lines, CR LF, in the node directory (pseudo terminal: comm type 0, handle 0)', L is not None and len(L) == 11 and L[0] == '0' and L[1] == '0', L)
    check('... baud, software, user record, name, handle, level, minutes left, ANSI, node', L is not None and L[3].startswith('Mythical Kingdom Bbs') and L[5] == 'Mark May' and L[6] and L[7].isdigit() and L[8].isdigit() and L[9] in ('0', '1') and L[10] == '1', L)
    check('... the line ends are CR LF', d32.raw.count(b'^M') == 11, d32.raw)
    L = d32(b'A')
    check('DOOR32.SYS of a raw door (*S) over telnet: comm type 2 (a socket), handle 0', L is not None and len(L) == 11 and L[0] == '2' and L[1] == '0', L)

    # dosemu not installed
    write_cfg('/nonexistent/dosemu')
    c.sendall(b'5')
    t = until(c, b'not available', 6)
    check('dosemu not there: the door is not available (the file is read at every call)', b'This door is not available' in t, t[-200:])
    c.sendall(b'\r'); until(c, b'Command >', 6)
    c.close()
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
