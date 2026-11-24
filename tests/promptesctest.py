#!/usr/bin/env python3
"""Backslash codes in menu prompts (\\n a line break, \\f<c> and \\k<c> the display codes, \\\\ a backslash) in the real mk, over telnet, on a private copy of the sample BBS
and of its menus: the top menu gets prompt-only items (type 0).   usage: promptesctest.py <work dir>"""
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
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))


path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
prompts = ['ESC1 LINE1\\nLINE2', 'ESC2 BS=\\\\ END', 'ESC3 NAME=\\fA|', 'ESC4 AREA=\\kZ AT=@ MSG=\\kY BT=`', 'ESC5 raw \\q end \\', 'ESC6 \\f', 'ESC7 [\\kO] min']
slot = 1
for p in prompts:
    while slot * REC < len(d) and d[slot * REC] != 0:
        slot += 1
    # a record is empty when its type, key, prompt are 0 ... type 0 items have a prompt: look for the first record with no prompt
    while slot * REC < len(d) and d[slot * REC + 7] != 0:
        slot += 1
    assert slot <= 50, 'the menu is full'
    if (slot + 1) * REC > len(d):
        d += bytes((slot + 1) * REC - len(d))
    r = bytearray(REC)
    r[0] = 0
    pb = p.encode()
    r[7] = len(pb); r[8:8 + len(pb)] = pb
    r[7 + 76] = ord(' ')
    r[REC - 2] = 7; r[REC - 1] = 0
    d[slot * REC:(slot + 1) * REC] = r
    slot += 1
open(path, 'wb').write(d)

cfg = {'mk': repo + '/build/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': 24771, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = subprocess.Popen([repo + '/build/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)

fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'prompt escapes: ' + name + ('' if ok else '  ' + str(info)[-600:]))
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


try:
    c = conn(24771)
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
    t = seen.decode('latin-1')
    check('caller logged in to the menu', 'Command >' in t, t[-200:])
    check('\\n is a line break: LINE1 and LINE2 are on two lines', 'ESC1 LINE1\r\nLINE2' in t, t[-700:])
    check('\\\\ is a backslash', 'ESC2 BS=\\ END' in t, t[-700:])
    check('\\fA is the name of the caller (the user code ^FA)', 'ESC3 NAME=Mark May|' in t, t[-700:])
    m = re.search(r'ESC4 AREA=(.*?) AT=(.*?) MSG=(.*?) BT=(.*?)\r', t)
    check('\\kZ and \\kY are the current file and message area, the same as @ and the backtick', bool(m) and m.group(1) == m.group(2) and m.group(3) != '' and m.group(3) == m.group(4), (m.groups() if m else t[-700:]))
    check('another backslash stays as it is (\\q, a backslash at the end)', 'ESC5 raw \\q end \\' in t, t[-700:])
    check('\\f at the end of the text stays as it is', 'ESC6 \\f' in t, t[-700:])
    m = re.search(r'ESC7 \[(\d+)\] min', t)
    check('\\kO is the number of minutes left', bool(m) and int(m.group(1)) > 0, t[-700:])
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
