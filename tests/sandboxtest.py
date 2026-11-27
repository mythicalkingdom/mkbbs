#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The door sandbox (bubblewrap) in the real mk over telnet: a native door that probes its surroundings runs with sandbox default (no network, no /home, a /tmp of its own, only its
node and door directories, a pid space of its own), off (sees everything), net (the network stays); menu command 7 with command7 = default; bwrap missing: the door is not run.
needs bwrap.   usage: sandboxtest.py <work dir>"""
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
if not shutil.which('bwrap'):
    print('skip: no bwrap'); sys.exit(0)
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





import threading
lsock = socket.socket(); lsock.bind(('127.0.0.1', 0)); lsock.listen(5)
port = lsock.getsockname()[1]
def acceptor():
    while True:
        try:
            x, _ = lsock.accept(); x.close()
        except OSError:
            return
threading.Thread(target=acceptor, daemon=True).start()

doors = tmp + '/doors'
os.makedirs(doors + '/probe')
secret = ra + '/secret.txt'
open(secret, 'w').write('TOP-SECRET\n')
open('/tmp/sbxmark-%d' % os.getpid(), 'w').write('x')
open(doors + '/probe/p.sh', 'w').write("""#!/bin/sh
echo "PWD:$(basename $PWD)"
echo "HOMEDIR:$(ls /home >/dev/null 2>&1 && echo THERE || echo GONE)"
echo "SECRET:$(cat %s 2>/dev/null || echo GONE)"
echo "TMPMARK:$(ls /tmp/sbxmark-%d >/dev/null 2>&1 && echo THERE || echo GONE)"
touch /tmp/inner-%d && echo "TMPW:ok"
touch ./nodefile && echo "NODEW:ok"
touch %s/probe/doorfile && echo "DOORW:ok"
(bash -c 'exec 3<>/dev/tcp/127.0.0.1/%d' 2>/dev/null && echo "NET:connected") || echo "NET:blocked"
echo "PS:$(ps -e | wc -l)"
echo "DONE"
""" % (secret, os.getpid(), os.getpid(), doors, port))
os.chmod(doors + '/probe/p.sh', 0o755)
os.makedirs(tmp + '/o')
shutil.copy(doors + '/probe/p.sh', tmp + '/o/outside.sh')
os.chmod(tmp + '/o/outside.sh', 0o755)


def write_cfg(prog='', cmd7='off'):
    open(ra + '/doors.cfg', 'w').write("""[sandbox]
%s
command7 = %s

[sbx]
type = native
dir = %s/probe
command = p.sh
sandbox = default
[sbxoff]
type = native
dir = %s/probe
command = p.sh
sandbox = off
[sbxnet]
type = native
dir = %s/probe
command = p.sh
sandbox = net
""" % (('program = ' + prog) if prog else '', cmd7, doors, doors, doors))


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


add_item(172, '5', 'DOOR-SBX', 'sbx')
add_item(172, '6', 'DOOR-OFF', 'sbxoff')
add_item(172, '7', 'DOOR-NET', 'sbxnet')
add_item(7, '8', 'RUN-SEVEN', tmp + '/o/outside.sh')
open(path, 'wb').write(d)
cfg = {'mk': repo + '/build/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': 24776, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = subprocess.Popen([repo + '/build/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'sandbox: ' + name + ('' if ok else '  ' + str(info)[-600:]))
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




def probe(c, key):
    c.sendall(key)
    t = until(c, b'DONE', 12)
    until(c, b'Command >', 8)
    if b'DONE' not in t:
        return None
    return dict(l.split(':', 1) for l in t.replace(b'\r', b'').decode('latin-1').split('\n') if re.match(r'^[A-Z]+:', l))


try:
    c = conn(24776)
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

    r = probe(c, b'5')
    check('sandbox default: the door runs, in the node directory', r is not None and r.get('PWD') == 'node1', r)
    check('... /home is not there, a file of the BBS outside the door directories is not there', r and r['HOMEDIR'] == 'GONE' and r['SECRET'] == 'GONE' and 'TOP-SECRET' not in r['SECRET'], r)
    check('... /tmp is its own (a file of the real /tmp is not there; it can write its own)', r and r['TMPMARK'] == 'GONE' and r.get('TMPW') == 'ok' and not os.path.exists('/tmp/inner-%d' % os.getpid()), r)
    check('... the node directory and the door directory are writable', r and r.get('NODEW') == 'ok' and r.get('DOORW') == 'ok' and os.path.exists(ra + '/node1/nodefile') and os.path.exists(doors + '/probe/doorfile'), r)
    check('... no network (a listener on 127.0.0.1 cannot be reached)', r and r.get('NET') == 'blocked', r)
    check('... a process space of its own (few processes)', r and r.get('PS', '99').strip().isdigit() and int(r['PS']) < 10, r)

    r = probe(c, b'6')
    check('sandbox off: sees /home, the secret file, the real /tmp, the network', r and r['SECRET'] != 'GONE' and 'TOP-SECRET' in r['SECRET'] and r['TMPMARK'] == 'THERE' and r.get('NET') == 'connected', r)
    r = probe(c, b'7')
    check('sandbox net: the network stays, the rest is closed', r and r.get('NET') == 'connected' and r['SECRET'] == 'GONE' and r['TMPMARK'] == 'GONE', r)

    # menu command 7: off by default, the sandbox with command7 = default
    r = probe(c, b'8')
    check('menu command 7 is not sandboxed by default', r and 'TOP-SECRET' in r['SECRET'] and r.get('NET') == 'connected', r)
    write_cfg(cmd7='default')
    r = probe(c, b'8')
    check('command7 = default: menu command 7 runs in the sandbox (the program\'s directory is bound)', r and r['SECRET'] == 'GONE' and r.get('NET') == 'blocked' and r.get('PWD') == 'node1', r)

    # bwrap missing: the door is not run
    write_cfg(prog='/nonexistent/bwrap', cmd7='default')
    c.sendall(b'5')
    t = until(c, b'not available', 8)
    check('no working bwrap: the door is not run (not available), nothing of it ran', b'This door is not available' in t and b'DONE' not in t, t[-200:])
    c.sendall(b'\r'); until(c, b'Command >', 6)
    c.sendall(b'8')
    t = until(c, b'could not be run', 8)
    check('... and menu command 7 with command7 = default is not run either (the caller is told)', b'could not be run' in t and b'DONE' not in t, t[-200:])
    c.sendall(b'\r'); until(c, b'Command >', 6)
    c.sendall(b'6')
    t = until(c, b'DONE', 10)
    check('... a door with sandbox = off still runs', b'DONE' in t, t[-200:])
    c.close()
finally:
    lst.terminate()
    lst.wait()
    lsock.close()
    try:
        os.remove('/tmp/sbxmark-%d' % os.getpid())
    except OSError:
        pass
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
