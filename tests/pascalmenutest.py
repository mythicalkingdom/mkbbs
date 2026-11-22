#!/usr/bin/env python3
"""Menu command 170 (run a Pascal program) in the real mk, over telnet, on a private copy of the sample BBS and of
its menus: the top menu gets items that run programs.  Whatever ends a program (normal end, error, Ctrl-C at an
readln, Ctrl-C in a loop, parameters after the path, a missing file) has to bring the caller back to the menu prompt.
usage: pascalmenutest.py <work dir>   (needs the sample BBS, build/mk and mklisten built with the Pascal interpreter)"""
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
if subprocess.run(['grep', '-q', 'Pascal program : ', os.path.join(repo, 'build', 'mk')]).returncode != 0:
    print('skip: mk was built without the Pascal interpreter'); sys.exit(0)
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

# the programs: in the BBS directory, one in a subdirectory (reached with a DOS style path)
os.makedirs(ra + '/games', exist_ok=True)
open(ra + '/quiz.pas', 'w').write("var n: string; x: integer;\nbegin\n  write('Your name? '); readln(n); writeln('Hello ', n);\n  write('Number? '); readln(x); writeln('double ', x * 2)\nend.\n")
open(ra + '/err.pas', 'w').write("begin\n  writeln('start');\n  x := 1\nend.\n")
open(ra + '/inp.pas', 'w').write("var s: string;\nbegin\n  write('Say? '); readln(s); writeln('never')\nend.\n")
open(ra + '/params.pas', 'w').write("begin\n  writeln('args ', ParamCount, ' ', ParamStr(1), ' ', ParamStr(2))\nend.\n")
open(ra + '/games/loop.pas', 'w').write("begin\n  while true do ;\nend.\n")

# the top menu: items for the programs in free slots (167 byte records, record 0 is the header)
path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
used = {chr(d[i * REC + 7 + 1 + 75]).upper() for i in range(1, len(d) // REC) if d[i * REC] != 0}
free = [k for k in 'WXYZ' if k not in used] + [k for k in '123456' if k not in used]
items = [('quiz.pas', 'quiz.pas'), ('err.pas', 'err.pas'), ('inp.pas', 'inp.pas'), ('loop.pas', 'games\\loop.pas'), ('params.pas', 'params.pas easy 10'), ('missing', 'nope.pas')]
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
    r[0] = 170
    prompt = ('PASCAL ' + name).encode()
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
    print(('ok   ' if ok else 'FAIL ') + 'pascal menu: ' + name)
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

    # a program with readln: a normal end, back at the menu with no Press Enter
    c.sendall(keys['quiz.pas'].encode())
    check('the program starts: its first prompt', b'Your name?' in until(c, b'Your name?', 6))
    c.sendall(b'Bob\r')
    check('echo and output', b'Hello Bob' in until(c, b'Hello Bob', 4))
    c.sendall(b'21\r')
    b = until(c, b'Command >', 6)
    check('answer 42, then the menu again', b'double 42' in b and b'Command >' in b)

    # a compile error: the message with the line, Press Enter, the menu
    c.sendall(keys['err.pas'].encode())
    b = until(c, b'ress', 6)
    check('a compile error shows its message and line, the program does not run', b'Error:' in b and b'line 3' in b and b'start' not in b)
    c.sendall(b'\r')
    check('after Enter the menu is back', b'Command >' in until(c, b'Command >', 6))

    # Ctrl-C while the program waits in readln
    c.sendall(keys['inp.pas'].encode())
    check('readln waits', b'Say?' in until(c, b'Say?', 6))
    c.sendall(b'\x03')
    b = until(c, b'ress', 6)
    check('Ctrl-C in readln: Program interrupted, the program does not go on', b'Program interrupted' in b and b'never' not in b)
    c.sendall(b'\r')
    check('... and the menu is back', b'Command >' in until(c, b'Command >', 6))

    # Ctrl-C in a loop that never waits, a path with a backslash into a subdirectory
    c.sendall(keys['loop.pas'].encode())
    time.sleep(1.0)
    c.sendall(b'\x03')
    b = until(c, b'interrupted', 6)
    check('Ctrl-C ends a loop (%s)' % show(b), b'Program interrupted at line' in b)
    b += until(c, b'ress', 4)
    c.sendall(b'\r')
    check('... and the menu is back', b'Command >' in until(c, b'Command >', 6))

    # parameters after the path
    c.sendall(keys['params.pas'].encode())
    b = until(c, b'Command >', 6)
    check('the words after the path are ParamStr(1), ParamStr(2)', b'args 2 easy 10' in b and b'Command >' in b)

    # a program that does not exist
    c.sendall(keys['missing'].encode())
    b = until(c, b'ress', 6)
    check('a missing program: Not Found', b'Error: nope.pas Not Found' in b)
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
if os.path.exists(cfgpatch.log_file(ra)):                  # the log goes next to the private copy (cfgpatch.fix_sample)
    log = open(cfgpatch.log_file(ra), encoding='latin-1').read()
check('the log has the runs', 'Pascal program : ' in log and 'Pascal ended (end)' in log and 'Pascal ended (break)' in log
      and 'Pascal compile error' in log and 'Pascal program not found : nope.pas' in log)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
