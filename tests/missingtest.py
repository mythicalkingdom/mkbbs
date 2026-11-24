#!/usr/bin/env python3
"""mk writes in the BBS log whenever it cannot load a language file, a menu, a screen or a questionnaire.  The real mk over telnet on a private copy of the sample BBS and
of its menus: the language files are taken away for one call; then menu items for a menu, a screen, a screen with hot keys and a questionnaire that are not there.
usage: missingtest.py <work dir>"""
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
ign = lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)]
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=ign)
cfgpatch.fix_sample(ra)
shutil.copytree(cfgpatch.snapshot(srcmenus), menus, ignore=ign)
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))
logf = cfgpatch.log_file(ra)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'missing files: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def until(s, needle, secs=8):
    s.settimeout(0.2)
    b = b''
    mores = 0
    end = time.time() + secs
    while time.time() < end and needle not in strip(b):
        try:
            d = s.recv(4096)
            if not d:
                break
            b += d
            if b'\x1b[6n' in d:
                s.sendall(b'\x1b[1;1R')
            if strip(b).count(b'More? (Y)es (N)o (C)ontinuous?') > mores:
                mores += 1
                s.sendall(b'c')
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


def listener(port):
    cfg = {'mk': repo + '/build/mk', 'rundir': os.path.join(work, 'run%d' % port), 'logfile': os.path.join(work, 'listen%d.log' % port), 'workdir': ra, 'nodes': '1-2',
           'ports': [{'port': port, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
    json.dump(cfg, open(os.path.join(work, 'l%d.json' % port), 'w'))
    return subprocess.Popen([repo + '/build/mklisten', '-c', os.path.join(work, 'l%d.json' % port)], stdout=subprocess.DEVNULL)


def logtext():
    return open(logf, encoding='latin-1').read() if os.path.exists(logf) else ''


# 1. no language files at all: the caller connects and goes away again
for f in os.listdir(ra):
    if f.lower().endswith('.lc'):
        os.remove(os.path.join(ra, f))
lst = listener(24671)
try:
    time.sleep(1.5)
    c = conn(24671)
    until(c, b'zzzz', 4)
    c.close()
    time.sleep(1.5)
finally:
    lst.terminate(); lst.wait()
log = logtext()
check('a language file that is not there: the log says which one and why', re.search(r'Language file \S*american\.lc could not be loaded \(not found\)', log), log[-400:])

# 2. the language files back, and menu items that name things that are not there
sample_ra = cfgpatch.snapshot(src)
for f in os.listdir(sample_ra):
    if f.lower().endswith('.lc'):
        shutil.copy(os.path.join(sample_ra, f), os.path.join(ra, f))
if os.path.exists(logf):
    open(logf, 'w').close()
path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
used = {chr(d[i * REC + 7 + 1 + 75]).upper() for i in range(1, len(d) // REC) if d[i * REC] != 0}
free = [k for k in 'WXYZ123456789ABCDEFGHJKLNOPQRSTUV=' if k not in used]
items = [('menu', 4, 'nomenuhere'), ('screen', 5, 'noscreenhere'), ('hot', 40, 'nohotscreen'), ('quest', 12, 'noquesthere')]
keys = {}
slot = 1
for name, cmd, data in items:
    while slot * REC < len(d) and d[slot * REC] != 0:
        slot += 1
    if (slot + 1) * REC > len(d):
        d += bytes((slot + 1) * REC - len(d))
    k = free.pop(0)
    r = bytearray(REC)
    r[0] = cmd
    prompt = ('MISS ' + name).encode()
    r[7] = len(prompt); r[8:8 + len(prompt)] = prompt
    r[7 + 76] = ord(k)
    dd = data.encode()
    r[84] = len(dd); r[85:85 + len(dd)] = dd
    r[REC - 2] = 15; r[REC - 1] = 0
    d[slot * REC:(slot + 1) * REC] = r
    keys[name] = k
    slot += 1
open(path, 'wb').write(d)
lst = listener(24672)
try:
    time.sleep(1.5)
    c = conn(24672)
    until(c, b'language choice', 10)
    time.sleep(1.5); c.sendall(b'\r')
    until(c, b'last name: ', 10); time.sleep(2.5)
    c.sendall(b'Mark May\r'); until(c, b'assword'); time.sleep(0.5); c.sendall(b'windows\r')
    x = b''
    for _ in range(8):
        x = until(c, b'zzzz', 3)
        if b'continue' in x or b'Enter' in x:
            c.sendall(b'\r')
        else:
            break
    check('the caller is logged in to the menu', b'Command >' in x, x[-200:])
    for name in ('screen', 'hot', 'quest', 'menu', 'menu'):
        c.sendall(keys[name].encode())
        x = until(c, b'zzzz', 3)
        if b'Press' in x or b'continue' in x:
            c.sendall(b'\r')
        until(c, b'zzzz', 1.5)
        if name == 'menu':
            c.sendall(b'\r'); until(c, b'zzzz', 1)
    c.close()
    time.sleep(1.5)
finally:
    lst.terminate(); lst.wait()
log = logtext()
check('a menu item names a screen that is not there: the log has the file it looked for', re.search(r'Screen \S*noscreenhere\S* could not be displayed \(not found\)', log), log[-600:])
check('a screen with hot keys: the same', re.search(r'Screen \S*nohotscreen\S* could not be displayed \(not found\)', log), log[-600:])
check('a questionnaire that is not there', re.search(r'Questionnaire \S*noquesthere\.q-a could not be loaded \(not found\)', log), log[-600:])
check('a menu that is not there: the log says where it looked', re.search(r'Menu nomenuhere\.mnu could not be loaded \(not found; looked in \S+', log), log[-600:])
check('the same message is written once in a call (the menu key was pressed twice)', len(re.findall(r'Menu nomenuhere', log)) == 1, log[-600:])
check('nothing is said about files that are there (no complaint about the menu or the language file of this call)', 'Language file' not in log and 'Menu top' not in log, log[-400:])
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
