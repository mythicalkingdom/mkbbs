#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Menu command 173 (upload files, UPLOAD-PLAN.md) in the real mk, over telnet, on a private copy of the sample BBS: the built-in Zmodem and Ymodem receive a
file (sz / sb of lrzsz) into a file area, the name is made safe, the caller describes it, it is listed in files.bbs, the caller is credited and gets the time back;
a name that is in the area is refused; an area that does not allow uploads (or the caller's level is too low) says so.   usage: uploadtest.py <build dir> <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
srcmenus = os.path.join(repo, 'bbs', 'bbsc', 'myth', 'menus')
if not (os.path.isdir(src) and os.path.isdir(srcmenus)) or not shutil.which('sz') or not shutil.which('sb') or not os.path.exists(build + '/mk'):
    print('skip: no sample BBS (or no sz / sb)'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
menus = tmp + '/m'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
shutil.copytree(cfgpatch.snapshot(srcmenus), menus, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'upload: ' + name + ('' if ok else '  ' + str(info)[-400:]))
    if not ok:
        fails += 1


# three file areas of our own: 1 takes uploads, 2 does not (Attr 1 = faNoUL), 3 wants a level nobody here has
cj = os.path.join(work, 'cj'); os.makedirs(cj)
envj = dict(os.environ, MK=ra, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
dj = json.load(open(os.path.join(cj, 'bbsconfig.json'), encoding='utf-8'))
os.makedirs(ra + '/temp', exist_ok=True)
dj['config']['TempPath'] = ra + '/temp/'         # the sample's own temp directory is not ours
AREAS = {}
for n, (nm, attr, lvl) in {1: ('Uploads', 0, 0), 2: ('Closed', 1, 0), 3: ('High', 0, 60000)}.items():
    d = ra + '/ul%d/' % n
    os.makedirs(d, exist_ok=True)
    AREAS[n] = d
    dj['files'][str(n)] = {'Name': nm, 'ShortName': nm, 'FilePath': d, 'ViewSec': {'Level': 0, 'Flags': 0}, 'DLSec': {'Level': 0, 'Flags': 0},
                           'ULSec': {'Level': lvl, 'Flags': 0}, 'PFileSec': {'Level': 0, 'Flags': 0}, 'Attr': attr, 'Select': ''}
json.dump(dj, open(os.path.join(cj, 'bbsconfig.json'), 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)

# the top menu: one item for each case
path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
used = {chr(d[i * REC + 7 + 1 + 75]).upper() for i in range(1, len(d) // REC) if d[i * REC] != 0}
free = [k for k in 'WXYZ' if k not in used] + [k for k in '1234567' if k not in used] + [k for k in 'ABCDEFGHJKLNOPQRSTUV890' if k not in used]
keys = {}
slot = 1
for name, data in [('cur', ''), ('a1', '1'), ('a2', '2'), ('a3', '3')]:
    while slot * REC < len(d) and d[slot * REC] != 0:
        slot += 1
    if (slot + 1) * REC > len(d):
        d += bytes((slot + 1) * REC - len(d))
    k = free.pop(0)
    r = bytearray(REC)
    r[0] = 173
    prompt = ('UPL ' + name).encode()
    r[7] = len(prompt); r[8:8 + len(prompt)] = prompt
    r[7 + 76] = ord(k)
    dd = data.encode()
    r[84] = len(dd); r[85:85 + len(dd)] = dd
    r[REC - 2] = 15; r[REC - 1] = 0
    d[slot * REC:(slot + 1) * REC] = r
    keys[name] = k
    slot += 1
open(path, 'wb').write(d)

# an upload hook (extensions.cfg [hooks], MHOST-PLAN.md phase 3): a BASIC script that writes what it was told in the log
os.makedirs(ra + '/scripts', exist_ok=True)
open(ra + '/scripts/uphook.bas', 'w').write('10 X = VAL(HOST$("log.write upload hook: event=" + HOST$("arg 1") + " area=" + HOST$("arg 3") + " file=" + HOST$("arg 4") + " size=" + HOST$("arg 5")))\n')
open(ra + '/extensions.cfg', 'w').write('[uphook]\nfile = scripts/uphook.bas\ncaps = log:write\n[hooks]\nupload = uphook\n')
cfg = {'mk': build + '/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-2', 'ports': [{'port': 24671, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)


def show(b):
    return b[-300:].decode('latin-1').replace('\r', '\\r').replace('\n', '\\n')


def bridge(c, argv, cwd, secs=90):
    """an lrzsz program (sz / rz) works on the telnet session: what it writes goes to the caller's socket with 255 doubled,
    what the socket brings (255 255 = data 255) goes to its input.  Returns when the program has ended."""
    import select
    p = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    iac = False
    end = time.time() + secs
    c.settimeout(None)
    out_open = True
    while time.time() < end and out_open:
        r, _, _ = select.select([c, p.stdout], [], [], 0.2)
        if c in r:
            d = c.recv(65536)
            if not d:
                break
            data = bytearray()
            for b in d:
                if iac:
                    iac = False
                    if b == 255:
                        data.append(255)
                    continue                        # a command byte: ignored (the options were answered at the start)
                if b == 255:
                    iac = True
                else:
                    data.append(b)
            try:
                p.stdin.write(bytes(data)); p.stdin.flush()
            except (BrokenPipeError, OSError):
                pass
        if p.stdout in r:
            d = os.read(p.stdout.fileno(), 65536)
            if not d:
                out_open = False
            else:
                c.sendall(d.replace(b'\xff', b'\xff\xff'))
    try:
        p.stdin.close()
    except OSError:
        pass
    try:
        p.wait(timeout=10)
    except subprocess.TimeoutExpired:
        p.kill()
    return p.returncode



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
            if strip(b).count(b'More? (Y)es (N)o (C)ontinuous?') > mores:      # a long screen is paged (the sample menu has many items): continuous
                mores += 1
                s.sendall(b'c')
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




def send_line(c, text, wait=b': '):
    c.sendall(text.encode() + b'\r')


def upload(c, key, files, tool, answers):
    """key of the menu item, the files sz/sb sends, the lines the caller types as descriptions for each file that is accepted"""
    c.sendall(keys[key].encode())
    b = until(c, b'Choose transfer protocol ?', 8)
    c.sendall(b'Z' if tool[0] == 'sz' else b'Y')
    b += until(c, b'upload with your terminal', 8)
    rc = bridge(c, tool + files, work, 60)
    return rc, b


try:
    c = conn(24671)
    c.sendall(bytes([255, 251, 0, 255, 253, 0]))
    raw = b''
    c.settimeout(0.2)
    end = time.time() + 10
    while time.time() < end and b'language choice' not in strip(raw):
        try:
            d = c.recv(4096)
            if not d:
                break
            raw += d
            if b'\x1b[6n' in d:
                c.sendall(b'\x1b[1;1R')
        except socket.timeout:
            pass
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
    check('caller logged in to the menu', b'Command >' in x, show(x))

    # a file with a name that needs cleaning, by Zmodem into area 1
    f1 = os.path.join(work, 'my file#1.txt')
    open(f1, 'w').write('hello upload\n' * 100)
    rc, b = upload(c, 'a1', [f1], ['sz', '-b'], [])
    b += until(c, b'Describe', 20)
    check('Zmodem: the file is received and the caller is asked to describe it', rc == 0 and b'Describe my_file_1.txt' in b, (rc, show(b)))
    c.sendall(b'A test file\r'); until(c, b': ', 4)
    c.sendall(b'second line\r'); until(c, b': ', 4)
    c.sendall(b'\r')
    b = until(c, b'Press (Enter) to continue', 10)
    check('... accepted: the report names the file (and the time given back, when the transfer took a second)', b'Received: my_file_1.txt (1300)' in b, show(b))
    c.sendall(b'\r')
    b = until(c, b'Command >', 8)
    check('... the menu is back', b'Command >' in b, show(b))
    p1 = AREAS[1] + 'my_file_1.txt'
    check('... the file is in the area under the safe name', os.path.exists(p1) and os.path.getsize(p1) == 1300)
    lst1 = open(AREAS[1] + 'files.bbs', encoding='latin-1').read() if os.path.exists(AREAS[1] + 'files.bbs') else ''
    check('... files.bbs has the name, the description and the second line under it', lst1 == 'my_file_1.txt A test file\n             second line\n', repr(lst1))
    check('... nothing is left in the work directories', os.listdir(ra + '/temp') == [])

    # the same name again: refused, the area is not changed
    rc, b = upload(c, 'a1', [f1], ['sz', '-b'], [])
    b += until(c, b'Command >', 25) if b'Command >' not in b else b''
    b += until(c, b'ress', 5)
    check('the same name again is refused (the file in the area stays)', b'was refused: my_file_1.txt' in b and open(p1).read() == 'hello upload\n' * 100, show(b))
    c.sendall(b'\r'); until(c, b'Command >', 8)

    # Ymodem, two files in a batch, the second with an empty description
    f2 = os.path.join(work, 'a.zip'); f3 = os.path.join(work, '.hidden file')
    open(f2, 'wb').write(os.urandom(5000)); open(f3, 'w').write('dot\n')
    rc, b = upload(c, 'a1', [f2, f3], ['sb', '-b'], [])
    b += until(c, b'Describe', 20)
    check('Ymodem: a batch of two, the first is asked about', rc == 0 and b'Describe' in b, (rc, show(b)))
    c.sendall(b'\r')                                  # no description for the first
    b = until(c, b'Describe', 10)
    c.sendall(b'dot file\r'); until(c, b': ', 4); c.sendall(b'\r')
    b += until(c, b'Press (Enter) to continue', 10)
    c.sendall(b'\r'); until(c, b'Command >', 8)
    names = sorted(os.listdir(AREAS[1]))
    check('... both are in the area (the leading dot is gone, the blank is _)', 'a.zip' in names and 'hidden_file' in names, names)
    lst1 = open(AREAS[1] + 'files.bbs', encoding='latin-1').read()
    check('... an empty description is listed as (no description)', 'a.zip' in lst1 and '(no description)' in lst1 and 'dot file' in lst1, repr(lst1))

    # an area that does not allow uploads, one that is above the caller
    for key, area in (('a2', 2), ('a3', 3)):
        c.sendall(keys[key].encode())
        b = until(c, b'not allowed', 8)
        check('area %d: "Uploads are not allowed in this area"' % area, b'Uploads are not allowed in this area.' in b, show(b))
        c.sendall(b'\r'); until(c, b'Command >', 8)
        check('... nothing was written there', os.listdir(AREAS[area]) == [])

    # ---- phase 2: uploads.cfg: the commands of the sysop (fake tools: shell scripts)
    tools = ra + '/tools'
    os.makedirs(tools)
    def tool(name, body):
        open(tools + '/' + name, 'w').write('#!/bin/sh\n' + body)
        os.chmod(tools + '/' + name, 0o755)
    tool('test.sh', 'if grep -aq BAD "$1"; then echo "bad archive: $1"; exit 2; fi\nexit 0\n')
    tool('scan.sh', 'if grep -aq EICAR "$1"; then echo "$1: Eicar-Test FOUND"; exit 1; fi\nif grep -aq SCANERR "$1"; then echo "scanner broke"; exit 50; fi\n'
                    'if grep -aq HANG "$1"; then sleep 20; fi\nexit 0\n')
    tool('diz.sh', 'grep -a "^DIZ:" "$1" | sed "s/^DIZ://"\n')
    tool('probe.sh', '[ -e "$1" ] || { echo "cannot see $1"; exit 3; }\n[ ! -e %s ] || { echo "sees the BBS directory"; exit 4; }\nexit 0\n' % (ra + '/config.mk'))
    qdir = ra + '/q'
    GLOBAL = '[global]\nquarantine = %s\ntimeout = 2\nscan = %s/scan.sh %%f\nrobind = %s\n[type txt]\ntest = %s/test.sh %%f\n[type dz]\ndiz = %s/diz.sh %%f\n' % (qdir, tools, tools, tools, tools)
    def setcfg(text):
        open(ra + '/uploads.cfg', 'w').write(text)

    def up(name, content, desc=(), key='a1'):
        f = os.path.join(work, name)
        open(f, 'wb').write(content)
        c.sendall(keys[key].encode())
        until(c, b'Choose transfer protocol ?', 8)
        c.sendall(b'Z')
        until(c, b'upload with your terminal', 8)
        bridge(c, ['sz', '-b', f], work, 60)
        text = b''
        answered = False
        end = time.time() + 40
        while time.time() < end and b'Press (Enter) to continue' not in text:
            text += until(c, b'zzzz', 1)
            if b'Describe' in text and not answered:
                answered = True
                for l in desc:
                    time.sleep(0.3); c.sendall(l.encode() + b'\r')
                time.sleep(0.3); c.sendall(b'\r')
        c.sendall(b'\r')
        until(c, b'Command >', 8)
        return text.decode('latin-1')

    def in_area(n):
        return os.path.exists(AREAS[1] + n)
    def quarantined(n):
        return os.path.isdir(qdir) and any(f.endswith('-' + n) for f in os.listdir(qdir))
    def listed(n):
        return n in open(AREAS[1] + 'files.bbs', encoding='latin-1').read()

    setcfg(GLOBAL)
    t = up('good.txt', b'fine\n' * 50, ['A good one'])
    check('a file that passes the test and the scanner is accepted', 'Received: good.txt' in t and in_area('good.txt') and listed('good.txt'), t[-300:])
    t = up('bad.txt', b'BAD stuff\n' * 50)
    check('a file that fails its test is refused with the first line of what the test printed', 'was refused: bad.txt' in t and 'failed its test: bad archive: bad.txt' in t and not in_area('bad.txt'), t[-300:])
    check('... it is in the quarantine with a .why note', quarantined('bad.txt'))
    why = [f for f in os.listdir(qdir) if f.endswith('bad.txt.why')]
    wtxt = open(qdir + '/' + why[0]).read() if why else ''
    check('... the note says who, where and why', 'caller:  Mark May' in wtxt and 'area:    1' in wtxt and 'bad archive' in wtxt, wtxt)
    t = up('virus.bin', b'xx EICAR xx\n' * 20)
    check('the scanner found something: refused, quarantined', 'the scanner found something: virus.bin: Eicar-Test FOUND' in t and quarantined('virus.bin') and not in_area('virus.bin'), t[-300:])
    t = up('err.bin', b'SCANERR\n' * 20)
    check('a scanner that fails: refused (scanfail = refuse)', 'could not be checked' in t and not in_area('err.bin') and quarantined('err.bin'), t[-300:])
    setcfg(GLOBAL.replace('timeout = 2\n', 'timeout = 2\nscanfail = accept\n'))
    t = up('err2.bin', b'SCANERR\n' * 20, ['accepted anyway'])
    check('... scanfail = accept takes it', 'Received: err2.bin' in t and in_area('err2.bin'), t[-300:])
    setcfg(GLOBAL)
    t0 = time.time()
    t = up('hang.bin', b'HANG\n' * 20)
    check('a scanner that does not end is killed at the time limit and the file is refused', 'could not be checked' in t and not in_area('hang.bin') and time.time() - t0 < 15, (time.time() - t0, t[-300:]))
    t = up('pic.dz', b'DIZ:Line one of the diz\nDIZ:   line two\nDIZ:\nDIZ:\n' + b'x' * 100)
    check('FILE_ID.DIZ is the description: no question asked', 'Describe' not in t and 'Description taken from the archive: pic.dz' in t and in_area('pic.dz'), t[-300:])
    ltxt = open(AREAS[1] + 'files.bbs', encoding='latin-1').read()
    check('... listed with its lines', 'pic.dz' in ltxt and 'Line one of the diz\n' in ltxt and '             line two\n' in ltxt, repr(ltxt[-200:]))
    setcfg(GLOBAL.replace('quarantine = %s\n' % qdir, 'quarantine =\n'))
    n_q = len(os.listdir(qdir))
    t = up('bad2.txt', b'BAD\n' * 20)
    check('quarantine = (empty): the refused file is deleted', 'failed its test' in t and len(os.listdir(qdir)) == n_q and not in_area('bad2.txt'), t[-300:])
    setcfg(GLOBAL + '[area 1]\nmaxsize = 1\n')
    t = up('big.dat', b'z' * 3000)
    check('[area 1] maxsize: a file over the limit is refused', 'it is too large, the limit (KB): 1' in t and not in_area('big.dat'), t[-300:])
    setcfg(GLOBAL + '[area 1]\nask = always\n')
    t = up('ask.dz', b'DIZ:from the archive\n' + b'x' * 100, ['caller text'])
    ltxt = open(AREAS[1] + 'files.bbs', encoding='latin-1').read()
    check('ask = always: the caller is asked and what he types is used', 'Describe ask.dz' in t and 'ask.dz       caller text' in ltxt, t[-300:])
    t = up('ask2.dz', b'DIZ:fallback\n' + b'x' * 100, [])
    ltxt = open(AREAS[1] + 'files.bbs', encoding='latin-1').read()
    check('... an empty answer takes the DIZ', 'ask2.dz      fallback' in ltxt, t[-300:])
    setcfg(GLOBAL + '[area 1]\nask = never\n')
    t = up('never.txt', b'ok\n' * 10)
    ltxt = open(AREAS[1] + 'files.bbs', encoding='latin-1').read()
    check('ask = never: no question, "(no description)"', 'Describe' not in t and 'never.txt' in ltxt and '(no description)' in ltxt.split('never.txt')[1], t[-300:])
    setcfg('[type xyz]\ntest = nosuchtool-xyz %f\n')
    t = up('noprog.xyz', b'q' * 100, ['no tool'])
    check('a test program that is not installed is skipped (the file is accepted, the log says it once)', 'Received: noprog.xyz' in t and in_area('noprog.xyz'), t[-300:])
    setcfg('[global]\nminfree = 999999999\n')
    c.sendall(keys['a1'].encode())
    b = until(c, b'not enough free disk space', 8)
    check('minfree: not enough free space: told before the transfer', b'There is not enough free disk space' in b, show(b))
    c.sendall(b'\r'); until(c, b'Command >', 8)
    if shutil.which('bwrap'):
        setcfg('[global]\nrobind = %s\n[type prb]\ntest = %s/probe.sh %%f\n' % (tools, tools))
        t = up('a.prb', b'p' * 100, ['probe'])
        check('the test runs in the sandbox: it sees the file and not the BBS directory', 'Received: a.prb' in t, t[-300:])
        setcfg('[global]\nsandbox = off\n[type prb]\ntest = %s/probe.sh %%f\n' % tools)
        t = up('b.prb', b'p' * 100, ['probe'])
        check('... with sandbox = off the same test sees the BBS directory and refuses', 'sees the BBS directory' in t and not in_area('b.prb'), t[-300:])
    time.sleep(0.5)
finally:
    lst.terminate()
    lst.wait()

log = ''
if os.path.exists(cfgpatch.log_file(ra)):
    log = open(cfgpatch.log_file(ra), encoding='latin-1').read()
check('the upload hook ran for each accepted file (event, area, name, size) and not for the refused one', 'Ext uphook: upload hook: event=upload area=1 file=my_file_1.txt size=1300' in log and log.count('Ext uphook: upload hook:') >= 1 and 'file=a.zip size=5000' in log, log[-800:])
check('the log has the uploads and the refusal', 'Upload: my_file_1.txt (1300 bytes) in area 1 by Mark May' in log and 'Upload refused (name in use): my_file_1.txt' in log, log[-600:])
if fails:
    print('LOG', log[-1500:])
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
