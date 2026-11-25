#!/usr/bin/env python3
"""Menu command 172 with the real dosemu2: a DOS door (a small .COM made by dosdoor_com: INT 14h on COM1; it sends the first line of DOOR.SYS, says hello, waits for a character and
answers) run for a caller over telnet in the real mk: the answer comes through COM1, the character typed reaches the door, the drop files are in its directory,
the work directory goes at the end and when the caller hangs up, old work directories are removed.   needs dosemu2.   usage: dosdoorcmdtest.py <work dir>"""
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
if not shutil.which('dosemu'):
    print('skip: no dosemu'); sys.exit(0)
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





sys.path.insert(0, here)
from dosdoor_com import build_door
doors = tmp + '/doors'
os.makedirs(doors + '/lord')
open(doors + '/lord/ECHO1.COM', 'wb').write(build_door())
open(doors + '/lord/SCORES.DAT', 'w').write('shared scores\n')
workbase = tmp + '/dw'
os.makedirs(workbase)
old = workbase + '/node9'                      # a work directory of a call that ended badly, two days ago
os.makedirs(old)
open(old + '/junk', 'w').write('x')
t2 = time.time() - 2 * 86400
os.utime(old, (t2, t2))
open(ra + '/doors.cfg', 'w').write("""[global]
tmp = %s

[lord]
type = dos
dir = %s/lord
command = ECHO1.COM
dropfiles = dorinfo1.def door.sys
""" % (workbase, doors))
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
open(path, 'wb').write(d)
cfg = {'mk': repo + '/build/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': 24775, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = subprocess.Popen([repo + '/build/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'real dosemu2 door: ' + name + ('' if ok else '  ' + str(info)[-600:]))
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
    for round_ in (1, 2):
        c = conn(24775)
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
        check('call %d: logged in to the menu' % round_, b'Command >' in seen, seen[-200:])
        c.sendall(b'5')
        t = until(c, b'HELLO FROM DOS', 30)
        if round_ == 1:
            check('the door runs in dosemu2: its answer comes through COM1 to the caller', b'HELLO FROM DOS' in t, t[-300:])
            check('the first line of DOOR.SYS as the door read it: COM1:', b'COM1:' in t, t[-300:])
            check('the door runs in the sandbox (dosemu2 under bwrap: the wrapper script of the node is there)', os.path.exists(workbase + '/sandbox-node1.sh'), os.listdir(workbase))
            check('the work directory of the node is there while the door runs, the old one of a bad call is gone', os.path.isdir(workbase + '/node1') and not os.path.exists(old), os.listdir(workbase))
            c.sendall(b'x')
            t = until(c, b'GOT:x', 10)
            check('the character typed reaches the door (GOT:x)', b'GOT:x' in t, t[-300:])
            t += until(c, b'Command >', 20)
            check('the menu comes back when the door ends', b'Command >' in t, t[-200:])
            time.sleep(0.5)
            check('the work directory is gone, the shared scores file of the door is as it was', not os.path.exists(workbase + '/node1') and open(doors + '/lord/SCORES.DAT').read() == 'shared scores\n', os.listdir(workbase))
            c.close()
            time.sleep(2)
        else:
            check('a second call runs the door again', b'HELLO FROM DOS' in t, t[-300:])
            c.close()                                 # the caller hangs up while the door waits for a character
            time.sleep(6)
            left = subprocess.run(['pgrep', '-f', '--', '-K ' + workbase], capture_output=True, text=True).stdout.strip()
            check('the caller hangs up while the door waits: no dosemu2 is left and the work directory is gone', not left and not os.path.exists(workbase + '/node1'), (left, os.listdir(workbase)))
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
