#!/usr/bin/env python3
"""Menu command 007 (run an external program / door) in the real mk, over telnet, on a private copy of the sample BBS and of
its menus.  usage: doormenutest.py <work dir>"""
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
shutil.copytree(src, ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(ra)
shutil.copytree(srcmenus, menus, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))

# the programs (menu command 007 runs an external program: the data is the command line)
os.makedirs(ra + '/games')
def script(path, text):
    open(path, 'w').write('#!/bin/sh\n' + text)
    os.chmod(path, 0o755)
script(ra + '/door.sh', 'echo "DOOR node=$1 baud=$2 user=$3"\nls dorinfo1.def door.sys 2>&1\nexit 0\n')
script(ra + '/games/door2.sh', 'echo "DOOR2 here"\n')
open(ra + '/door_in.sh', 'w').write('#!/bin/bash\nprintf "name? "\nIFS= read -r -d $\'\\r\' x\necho "got:$x"\n')
os.chmod(ra + '/door_in.sh', 0o755)


# the top menu: items for the programs in free slots (167 byte records, record 0 is the header)
path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
used = {chr(d[i * REC + 7 + 1 + 75]).upper() for i in range(1, len(d) // REC) if d[i * REC] != 0}
free = [k for k in 'WXYZ' if k not in used] + [k for k in '1234567' if k not in used] + [k for k in 'ABCDEFGHJKLNOPQRSTUV' if k not in used]
items = [('bare', 'echo hello-bare'), ('abs', '/bin/echo hello-abs'), ('script', './door.sh *N *B *F'), ('script2', 'door.sh *N'), ('dos path', 'games\\door2.sh'), ('input', './door_in.sh'), ('missing', 'nope-door-xyz')]
keys = {}
slot = 1
for name, data in items:
    while slot * REC < len(d) and d[slot * REC] != 0:
        slot += 1
    assert slot <= 50, 'the menu is full'
    if (slot + 1) * REC > len(d):
        d += bytes((slot + 1) * REC - len(d))
    k = free.pop(0)
    r = bytearray(REC)
    r[0] = 7
    prompt = ('DOOR ' + name).encode()
    r[7] = len(prompt); r[8:8 + len(prompt)] = prompt
    r[7 + 76] = ord(k)
    dd = data.encode()
    r[84] = len(dd); r[85:85 + len(dd)] = dd
    r[REC - 2] = 15; r[REC - 1] = 0
    d[slot * REC:(slot + 1) * REC] = r
    keys[name] = k
    slot += 1
open(path, 'wb').write(d)

cfg = {'mk': repo + '/build/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': 24661, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = subprocess.Popen([repo + '/build/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)

fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'door menu: ' + name)
    if not ok:
        fails += 1


def until(s, needle, secs=8):
    s.settimeout(0.2)
    b = b''
    end = time.time() + secs
    while time.time() < end and needle not in strip(b):
        try:
            d = s.recv(4096)
            if not d:
                break
            b += d
            if b'\x1b[6n' in d:
                s.sendall(b'\x1b[1;1R')
        except socket.timeout:
            pass
    return strip(b)


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def conn(port):
    for _ in range(50):
        try:
            return socket.create_connection(('127.0.0.1', port))
        except OSError:
            time.sleep(0.1)
    raise SystemExit('cannot connect')


def show(b):
    return b[-200:].decode('latin-1').replace('\r', '\\r').replace('\n', '\\n')


try:
    c = conn(24661)
    until(c, b'language choice', 10); time.sleep(1.5); c.sendall(b'\r')
    until(c, b'last name: ', 10); time.sleep(2.5)
    c.sendall(b'Mark May\r'); until(c, b'assword'); time.sleep(0.5); c.sendall(b'windows\r')
    x = b''
    for _ in range(8):
        x = until(c, b'zzzz', 3)
        if b'continue' in x or b'Enter' in x:
            c.sendall(b'\r')
        else:
            break
    check('caller logged in to the menu', b'Command >' in x)

    def run_item(name, marker, secs=6):
        c.sendall(keys[name].encode())
        b = until(c, marker, secs)
        return b + until(c, b'Command >', 5)

    b = run_item('bare', b'hello-bare')
    check('a command without a path is found in the path (echo)', b'hello-bare' in b and b'Command >' in b)
    b = run_item('abs', b'hello-abs')
    check('a full path', b'hello-abs' in b and b'Command >' in b)
    b = run_item('script', b'DOOR node=')
    check('a program in the BBS directory (./door.sh): *N node, *B baud, *F first name; the drop files were written',
          b'DOOR node=1 baud=38400 user=Mark' in b and b'door.sys' in b and b'dorinfo1.def' in b and b'Command >' in b)
    b = run_item('script2', b'DOOR node=')
    check('a name without a path is looked for in the BBS directory first (door.sh)', b'DOOR node=1' in b and b'Command >' in b)
    b = run_item('dos path', b'DOOR2 here')
    check('a path written the DOS way (games\\door2.sh) works', b'DOOR2 here' in b and b'Command >' in b)
    c.sendall(keys['input'].encode())
    check('the program reads what the caller types', b'name?' in until(c, b'name?', 6))
    c.sendall(b'Zed\r')
    b = until(c, b'got:', 6) + until(c, b'Command >', 5)
    check('... and its answer comes back, then the menu', b'got:Zed' in b and b'Command >' in b)
    c.sendall(keys['missing'].encode())
    b = until(c, b'ress', 6)
    check('a program that does not exist: the caller is told, not left with nothing', b'Error: nope-door-xyz could not be run' in b)
    c.sendall(b'\r')
    check('... and the menu is back', b'Command >' in until(c, b'Command >', 6))
    time.sleep(0.5)
finally:
    lst.terminate()
    lst.wait()

log = ''
for f in os.listdir(ra):
    if f.lower() == 'ra.log':
        log = open(os.path.join(ra, f), encoding='latin-1').read()
check('the log has the runs and the one that failed', 'DOS shell : echo hello-bare' in log and 'DOS shell : games\\door2.sh' in log
      and 'DOS shell failed (2) : nope-door-xyz' in log)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
