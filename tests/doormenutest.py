#!/usr/bin/env python3
"""Menu command 007 (run an external program / door) in the real mk, over telnet, on a private copy of the sample BBS and of
its menus.  usage: doormenutest.py <work dir>"""
import sys, json, os, re, shutil, socket, subprocess, sys, time

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
open(ra + '/noext', 'w').write('x')
# the offline mail door (mkqwk): its settings with this machine's paths, one user record
import struct
if os.path.exists(repo + '/bbs/bbsc/mkqwk/config.mko') and os.path.exists(repo + '/build/mkqwk'):
    q = bytearray(open(repo + '/bbs/bbsc/mkqwk/config.mko', 'rb').read())
    def qput(off, text, n):
        q[off:off + n + 1] = bytes([len(text)]) + text.encode() + bytes(n - len(text))
    qput(203 + 143 * 1 + 1, 'zip -q -j', 70)                 # packer 2 (ZIP) and its unpacker, for this machine
    qput(203 + 143 * 1 + 72, 'unzip -o -q', 70)
    qput(203 + 1430 + 72, ra + '/rcv.sh', 70)                # protocol 1 (Zmodem): the receive program is a script that drops a reply packet
    board = q[1:1 + q[0]].decode('latin-1').strip()
    qput(3063, ra + '/qtmp', 80)
    qput(3063 + 81, ra + '/qusers', 80)
    os.makedirs(ra + '/qtmp'); os.makedirs(ra + '/qusers')
    open(ra + '/config.mko', 'wb').write(q)
    rec = bytearray(843)
    rec[0] = 8; rec[1:9] = b'Mark May'
    rec[36:40] = (1).to_bytes(4, 'little')
    rec[640 + 8] = ord('Z'); rec[640 + 9] = ord('Z'); rec[640 + 12] = 2
    rec[640 + 4:640 + 6] = (500).to_bytes(2, 'little'); rec[640 + 6:640 + 8] = (100).to_bytes(2, 'little')
    open(ra + '/qusers/users.mko', 'wb').write(rec)
    have_qwk = True
    # the reply packet a caller would upload: <BOARDID>.REP, a ZIP with <BOARDID>.MSG (2 messages for area 6, 1 for an unknown conference)
    import zipfile
    subprocess.run([repo + '/build/qwkmsgtest', 'reply', ra + '/reply.msg', '6', board], check=True, capture_output=True)
    with zipfile.ZipFile(ra + '/reply.zip', 'w') as z:
        z.write(ra + '/reply.msg', board.upper() + '.MSG')
    os.remove(ra + '/reply.msg')
    # the "protocol": drops the file in the current directory (the work directory of the door) under a name an unpacker could take for an option
    open(ra + '/rcv.sh', 'w').write('#!/bin/sh\ncp %s/reply.zip ./-evil.rep\nexit 0\n' % ra)
    os.chmod(ra + '/rcv.sh', 0o755)
else:
    have_qwk = False
script(ra + '/lineread.sh', 'printf "name? "\nread x\necho "got:$x"\n')
script(ra + '/rawkey.sh', 'stty raw -echo\nk=$(dd bs=1 count=1 2>/dev/null)\nstty sane\necho "key=$k"\n')
script(ra + '/hang.sh', 'echo $$ > hang.pid\necho started\nexec sleep 60\n')
script(ra + '/tty.sh', 'tty\necho "TERM=$TERM COLUMNS=$COLUMNS LINES=$LINES"\nstty size\n')


# the top menu: items for the programs in free slots (167 byte records, record 0 is the header)
path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
used = {chr(d[i * REC + 7 + 1 + 75]).upper() for i in range(1, len(d) // REC) if d[i * REC] != 0}
free = [k for k in 'WXYZ' if k not in used] + [k for k in '1234567' if k not in used] + [k for k in 'ABCDEFGHJKLNOPQRSTUV890' if k not in used]
items = [('bare', 'echo hello-bare'), ('abs', '/bin/echo hello-abs'), ('script', './door.sh *N *B *F'), ('script2', 'door.sh *N'), ('dos path', 'games\\door2.sh'), ('input', './lineread.sh'), ('tty', './tty.sh'), ('raw', './tty.sh *S'), ('rawkey', './rawkey.sh'), ('hang', './hang.sh'), ('glob', '/bin/echo *.mko'), ('glob2', '/bin/echo noex*.* zz*.*'), ('qwk', repo + '/build/mkqwk'), ('qwkul', repo + '/build/mkqwk -U'), ('qwkin', '#156'), ('missing', 'nope-door-xyz')]
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
    if data.startswith('#'):                      # a menu command of mk itself
        r[0] = int(data[1:]); data = ''
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
    # what the caller gets first: the ANSI detection, then (the caller is ANSI) the screen is cleared, then the version lines
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
    ci, vi = raw.find(b'\x1b[2J'), raw.find(b'Version')
    check('a clear screen comes before the version and copyright lines', ci >= 0 and vi > ci)
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
    check('caller logged in to the menu', b'Command >' in x)

    def run_item(name, marker, secs=6):
        c.sendall(keys[name].encode())
        b = until(c, marker, secs)
        return b + until(c, b'Command >', 5)

    b = run_item('bare', b'hello-bare')
    check('a command without a path is found in the path (echo)', b'hello-bare' in b and b'Command >' in b)
    check('the terminal ends lines the way a caller needs: CR LF (the program wrote a plain LF)', b'hello-bare\r\n' in b)
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
    check('... a plain read gets the line (the caller\'s Enter is a CR), the typed text is echoed, the answer comes back, then the menu',
          b'Zed\r\ngot:Zed' in b and b'Command >' in b)
    c.sendall(bytes([255, 251, 31]))                                  # IAC WILL NAWS
    time.sleep(0.3)
    c.sendall(bytes([255, 250, 31, 0, 100, 0, 30, 255, 240]))         # IAC SB NAWS 100 30 IAC SE
    time.sleep(0.5)
    b = run_item('tty', b'TERM=')
    check('the program has a terminal: tty names it, TERM, COLUMNS, LINES and the window size are set (the caller reported 100 x 30)', b'/dev/pts/' in b and b'TERM=' in b and b'COLUMNS=100 LINES=30' in b and b'30 100' in b)
    b = run_item('raw', b'TERM=')
    check('*S: no terminal, the program gets the caller\'s connection itself (not a tty)', b'not a tty' in b and b'/dev/pts/' not in b)
    b = run_item('glob', b'users.mko')
    check('a * or ? in the arguments is expanded (there is no shell), sorted: echo *.mko', b'confs.mko users.mko' in b and b'*.mko' not in b)
    b = run_item('glob2', b'noext')
    check('a name ending in .* also fits a file without an extension (as in DOS); nothing fits: left as it is', b'noext' in b and b'zz*.*' in b)
    if have_qwk:
        c.sendall(keys['qwk'].encode())
        b = until(c, b'door program loads', 6) + until(c, b'Command >', 6)
        check('the offline mail door (mkqwk) runs from a menu: it asks for a command itself', b'Command >' in b and b'DOOR qwk' not in b)
        c.sendall(b'c')                                   # its configuration menu
        b = until(c, b'Command >', 5)
        c.sendall(b'q')                                   # ... and back
        b = until(c, b'Command >', 5)
        c.sendall(b'q')                                   # quit the door
        b = until(c, b'DOOR bare', 6) + until(c, b'Command >', 6)
        check('its menus work (configuration and back), Quit returns to the BBS menu', b'DOOR bare' in b and b'Command >' in b)
    if have_qwk:
        c.sendall(keys['qwkul'].encode())
        b = until(c, b'reply file', 8)
        check('the offline mail door (mkqwk -U) asks whether there is a reply file to upload', b'reply file' in b)
        c.sendall(b'y')
        b1 = until(c, b'message(s) posted', 12)
        c.sendall(b'\r')                                    # the Press Enter after the summary
        b = b1 + until(c, b'Command >', 8)
        check('it receives the packet (the "protocol" script) and unpacks it (a file name like -evil.rep is no option)', b'Begin transfer now' in b1 and b'Uncompressing file' in b1)
        check('the caller of this test has no write access in area 6 or 999: told so, nothing posted', b'Access denied! 6' in b1 and b'0 message(s) posted' in b1 and b'Command >' in b)
        dump = subprocess.run([repo + '/build/tossdump', '6'], capture_output=True, text=True, env=dict(os.environ, MK=ra), encoding='latin-1').stdout
        check('... and area 6 has none of the replies', 'Reply via REP' not in dump and 'Second reply' not in dump)
    if have_qwk:
        c.sendall(keys['qwkin'].encode())
        b = until(c, b'reply file', 8)
        check('menu command 156 (the upload inside mk, no mkqwk) asks whether there is a reply file', b'reply file' in b)
        c.sendall(b'y')
        b1 = until(c, b'message(s) posted', 12)
        c.sendall(b'\r')
        b = b1 + until(c, b'Command >', 8)
        check('... receives and unpacks the packet, posts the 2 messages for area 6 (this user may write there), refuses conference 999, and returns to the menu', b'Uncompressing file' in b1 and b'Access denied! 999' in b1 and b'2 message(s) posted' in b1 and b'Command >' in b)
        dump = subprocess.run([repo + '/build/tossdump', '6'], capture_output=True, text=True, env=dict(os.environ, MK=ra), encoding='latin-1').stdout
        check('... and area 6 now has the replies, in the name of the caller', 'Reply via REP' in dump and 'Second reply' in dump)
    c.sendall(keys['rawkey'].encode())
    time.sleep(1.0)
    c.sendall(b'q')
    b = until(c, b'key=', 5) + until(c, b'Command >', 5)
    check('a program that sets the terminal to raw mode gets a key without Enter (and the terminal is sane again after it)', b'key=q' in b and b'Command >' in b)
    c.sendall(keys['hang'].encode())
    check('a program that waits', b'started' in until(c, b'started', 5))
    time.sleep(0.5)
    hp = ra + '/hang.pid'
    pid = int(open(hp).read()) if os.path.exists(hp) else 0
    c.close()
    gone = False
    for _ in range(80):
        try:
            os.kill(pid, 0)
            time.sleep(0.1)
        except OSError:
            gone = True
            break
    check('the caller hangs up: the program is told (SIGHUP) and ends, it is not left running', pid > 0 and gone)
    c = conn(24661)
    until(c, b'language choice', 10); time.sleep(1.5); c.sendall(b'\r')
    until(c, b'last name: ', 10); time.sleep(2.5)
    c.sendall(b'Mark May\r'); until(c, b'assword'); time.sleep(0.5); c.sendall(b'windows\r')
    for _ in range(8):
        x = until(c, b'zzzz', 3)
        if b'continue' in x or b'Enter' in x:
            c.sendall(b'\r')
        else:
            break
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
if os.path.exists(cfgpatch.log_file(ra)):                  # the log goes next to the private copy (cfgpatch.fix_sample)
    log = open(cfgpatch.log_file(ra), encoding='latin-1').read()
check('the log has the runs and the one that failed', 'DOS shell : echo hello-bare' in log and 'DOS shell : games\\door2.sh' in log
      and 'DOS shell failed (2) : nope-door-xyz' in log)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
