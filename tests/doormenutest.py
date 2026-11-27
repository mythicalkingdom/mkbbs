#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Menu command 007 (run an external program / door) in the real mk, over telnet, on a private copy of the sample BBS and of
its menus.  usage: doormenutest.py <work dir>"""
import sys, json, os, re, shutil, socket, subprocess, sys, time, zipfile

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

# the programs (menu command 007 runs an external program: the data is the command line)
os.makedirs(ra + '/games', exist_ok=True)   # the sample BBS may have one already
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
    qput(0, 'MythKing', 8)                                   # the same board id as config.mk: one reply packet for both
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
    # offline mail inside mk (menu commands 156 and 157) needs only config.mk: an external protocol "send | receive", the packer
    # commands for this machine, and area 6 forced into the offline mail of every caller
    open(ra + '/snd.sh', 'w').write('#!/bin/sh\ncp "$1" %s/sent.qwk\nexit 0\n' % ra)
    os.chmod(ra + '/snd.sh', 0o755)
    cj = os.path.join(work, 'cj'); os.makedirs(cj)
    envj = dict(os.environ, MK=ra, MKJSON=cj)
    subprocess.run([repo + '/build/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
    dj = json.load(open(os.path.join(cj, 'bbsconfig.json'), encoding='utf-8'))
    cc = dj['config']
    cc['ExtProt'][0] = {'Key': 'R', 'Attr': 3, 'Name': 'TestProt', 'CmdLine': ra + '/snd.sh %F | ' + ra + '/rcv.sh'}
    cc['ExtPack'][1]['PCmdLine'] = 'zip -q -j'
    cc['ExtPack'][1]['UCmdLine'] = 'unzip -o -q'
    dj['messages']['6']['Permit'] |= 1024
    cc['OffAttr'] |= 128                                     # QWKE long names in the packets (oaQwke)
    # the extras of a packet (Messages > Offline in mkconfig; the door's config.mko has nothing to do with it): screens, bulletins, the new files list
    cc['OffAttr'] |= 2 | 8 | 32                              # forced: new files list, screens, bulletins
    cc['OffScrns'] = ['hello', 'news', 'bye', 'nfhead', '']
    cc['OffBulls'] = ['bulla', 'nobull'] + [''] * 8
    os.makedirs(ra + '/txt', exist_ok=True)
    for i in range(len(cc['TxtPath'])):
        cc['TxtPath'][i] = ra + '/txt/'
    for nm in ('hello', 'news', 'bye', 'bulla', 'nfhead'):
        open(ra + '/txt/' + nm + '.asc', 'w').write(nm.upper() + ' screen of mk\n')
    json.dump(dj, open(os.path.join(cj, 'bbsconfig.json'), 'w', encoding='utf-8'), ensure_ascii=False)
    subprocess.run([repo + '/build/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
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
# a program runs in the directory of its node (node1 below the BBS directory): what it writes without a path is there
shutil.rmtree(ra + '/node1', ignore_errors=True)     # the sample has the node directories of its DOS days (with another config.mko in node1)
os.makedirs(ra + '/node1')
for _n in ('aa.mko', 'bb.mko', 'noext'):
    open(ra + '/node1/' + _n, 'w').write('x')
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
free = [k for k in 'WXYZ' if k not in used] + [k for k in '1234567' if k not in used] + [k for k in 'ABCDEFGHJKLNOPQRSTUV890' if k not in used] + [k for k in '=' if k not in used]   # more keys when the sample menu has many items
# a DOS door through mkdosdoor and dosemu2 (when it is installed): COM1 of the door is the terminal MK gives the program of command 7
have_dos = bool(shutil.which('dosemu'))
if have_dos:
    from dosdoor_com import build_door
    os.makedirs(ra + '/dosdoors', exist_ok=True)
    os.symlink(repo + '/tools/mkdosdoor', ra + '/mkdosdoor')        # the menu data holds 75 characters: a short name, found in the BBS directory
    open(ra + '/dosdoors/ECHO1.COM', 'wb').write(build_door())
    os.environ['MKDOS_TMP'] = work + '/dostmp'
items = [('bare', 'echo hello-bare')] + ([] if have_dos else [('abs', '/bin/echo hello-abs')]) + [('script', './door.sh *N *B *F'), ('script2', 'door.sh *N'), ('dos path', 'games\\door2.sh'), ('input', './lineread.sh'), ('tty', './tty.sh'), ('raw', './tty.sh *S'), ('rawkey', './rawkey.sh'), ('hang', './hang.sh'), ('glob', '/bin/echo *.mko'), ('glob2', '/bin/echo noex*.* zz*.*'), ('qwk', repo + '/build/mkqwk'), ('qwkul', repo + '/build/mkqwk -U'), ('qwkin', '#156'), ('qwkout', '#157'), ('setprot', '#153'), ('missing', 'nope-door-xyz')] + ([('dosdoor', './mkdosdoor -n *N -d ' + ra + '/dosdoors *D -- ECHO1.COM')] if have_dos else [])
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
OFFRULES = [(b'Choose transfer protocol ?', b'R'), (b'Choose archive packer ?', b'Z'), (b'Choose Offline Mail Type', b'Q'),
            (b'Maximum messages per packet?', b'100\r'), (b'Maximum messages per message area?', b'50\r'),
            (b'new files list included', b'n'), (b'bulletins included', b'n'), (b'screens included', b'n'),
            (b'want each packet', b'n'), (b'Flag messages as read', b'n'), (b'Receive your own messages', b'y'),
            (b'Search all areas for your mail', b'n'), (b'even with zero messages', b'n')]


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'door menu: ' + name)
    if not ok:
        fails += 1


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


def drive(s, rules, stop, secs=20):
    """answers the prompts of the offline mail set-up (a caller's first use): rules = [(prompt, answer)], until stop is seen"""
    buf = b''
    end = time.time() + secs
    s.settimeout(0.3)
    while time.time() < end:
        try:
            x = s.recv(4096)
        except socket.timeout:
            x = b''
        buf += x
        t = strip(buf)
        if stop in t:
            return t
        if not x:
            for pat, ans in rules:
                if pat in t:
                    s.sendall(ans)
                    buf = b''
                    break
    return strip(buf)


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


def show(b):
    return b[-200:].decode('latin-1').replace('\r', '\\r').replace('\n', '\\n')


try:
    c = conn(24661)
    c.sendall(bytes([255, 251, 0, 255, 253, 0]))                      # IAC WILL BINARY, IAC DO BINARY: a caller that can take a file
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
    if not have_dos:      # (the DOS door below is started by a full path: the sample menu has no more free keys)
        b = run_item('abs', b'hello-abs')
        check('a full path', b'hello-abs' in b and b'Command >' in b)
    b = run_item('script', b'DOOR node=')
    check('a program in the BBS directory (./door.sh): *N node, *B baud, *F first name; the drop files were written',
          b'DOOR node=1 baud=38400 user=Mark' in b and b'door.sys' in b and b'dorinfo1.def' in b and b'Command >' in b)
    check('the drop files are in the directory of the node (node1 below the BBS directory, the program runs there) and not in the BBS directory itself',
          all(os.path.exists(ra + '/node1/' + f) and time.time() - os.path.getmtime(ra + '/node1/' + f) < 300 for f in ('dorinfo1.def', 'exitinfo.bbs'))
          and all(not os.path.exists(ra + '/' + f) or time.time() - os.path.getmtime(ra + '/' + f) > 300 for f in ('dorinfo1.def', 'exitinfo.bbs')))      # (the sample has old ones; door.sys is only written with *D in the data)
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
    if have_dos:
        c.sendall(keys['dosdoor'].encode())
        b = until(c, b'HELLO FROM DOS', 25)
        c.sendall(b'x')
        b += until(c, b'GOT:x', 10)
        b += until(c, b'Command >', 10)
        check('a DOS door (mkdosdoor, dosemu2): it reads DOOR.SYS from the node directory (COM1:), says hello, gets the character the caller types and answers',
              b'COM1:' in b)
        check('... through the pseudo terminal of command 7, the program found in the BBS directory and made a full path (the directory changes to that of the node): HELLO FROM DOS and GOT:x reach the caller, and the menu is back', b'HELLO FROM DOS' in b and b'GOT:x' in b and b'Command >' in b)
        check('... the drop file the door read was the node\'s own (node1), made by MK', os.path.exists(ra + '/node1/door.sys') and time.time() - os.path.getmtime(ra + '/node1/door.sys') < 300)
    b = run_item('glob', b'bb.mko')
    check('a * or ? in the arguments is expanded (there is no shell), sorted: echo *.mko', b'aa.mko bb.mko' in b and b'*.mko' not in b)
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
        b = drive(c, OFFRULES, b'reply file', 40)
        check('menu command 156 (the upload inside mk, no mkqwk) asks whether there is a reply file', b'reply file' in b)
        c.sendall(b'y')
        b1 = until(c, b'message(s) posted', 12)
        c.sendall(b'\r')
        b = b1 + until(c, b'Command >', 8)
        check('... receives and unpacks the packet, posts the 2 messages for area 6 (this user may write there), refuses conference 999, and returns to the menu', b'Uncompressing file' in b1 and b'Access denied! 999' in b1 and b'2 message(s) posted' in b1 and b'Command >' in b)
        dump = subprocess.run([repo + '/build/tossdump', '6'], capture_output=True, text=True, env=dict(os.environ, MK=ra), encoding='latin-1').stdout
        check('... and area 6 now has the replies, in the name of the caller', 'Reply via REP' in dump and 'Second reply' in dump)
        # menu command 157: the packet for the caller (area 6 is forced into everybody's offline mail), packed and sent
        c.sendall(keys['qwkout'].encode())
        b = until(c, b'Command >', 40)
        while b'More?' in b[-60:]:                      # a long list of areas is paged: continuous
            c.sendall(b'c')
            b += until(c, b'Command >', 40)
        sent = ra + '/sent.qwk'
        check('menu command 157 (the download inside mk) packs the packet and sends it with the protocol of the caller', os.path.exists(sent) and b'Begin transfer now' in b and b'Command >' in b)
        pk = os.path.join(work, 'pk'); os.makedirs(pk)
        names = []
        if os.path.exists(sent):
            z = zipfile.ZipFile(sent)
            names = [n.lower() for n in z.namelist()]
            z.extractall(pk)
        check('... it holds messages.dat, control.dat, door.id and the index of conference 6', all(n in names for n in ('messages.dat', 'control.dat', 'door.id', '006.ndx')))
        pdump = subprocess.run([repo + '/build/qwkmsgtest', 'dump', pk + '/messages.dat'], capture_output=True, text=True, encoding='latin-1').stdout
        check('... the replies are in it (the caller\'s own messages: he asked for them) in conference 6', 'Reply via REP' in pdump and 'conf=6' in pdump)
        check('... the screens, the bulletin (BLT-1; the one with no file is left out), the new files list and TOREADER.EXT are in it: mk needs only config.mk',
              all(n in names for n in ('hello.asc', 'news.asc', 'bye.asc', 'blt-1.asc', 'newfiles.dat', 'toreader.ext')) and 'blt-2.asc' not in names)
        nfl = open(pk + '/newfiles.dat', encoding='latin-1').read() if os.path.exists(pk + '/newfiles.dat') else ''
        check('... the new files list starts with the heading screen of Messages > Offline (New Files Head)', nfl.startswith('NFHEAD screen of mk'))
        ctl = open(pk + '/control.dat', encoding='latin-1').read().split('\n') if os.path.exists(pk + '/control.dat') else []
        check('... control.dat has the board id of config.mk', len(ctl) > 4 and ctl[4].endswith('MythKing'))
        c.sendall(keys['qwkout'].encode())
        b = until(c, b'continue', 40)
        check('a second download has nothing new: the last read pointers went on', b'No messages found' in b)
        c.sendall(b'\r')
        check('... and the menu is back', b'Command >' in until(c, b'Command >', 8))
    if have_qwk and shutil.which('sz') and shutil.which('rz'):
        # the built-in Zmodem (MKProt) over the telnet session, against the real sz / rz
        c.sendall(keys['setprot'].encode())
        b = drive(c, [(b'Choose transfer protocol ?', b'Z')], b'Command >', 20)
        check('menu command 153: the caller chooses Zmodem (an internal protocol)', b'Command >' in b)
        subprocess.run([repo + '/build/qwkmsgtest', 'reply', ra + '/rep2.msg', '6', 'MythKing', ' B'], check=True, capture_output=True)
        with zipfile.ZipFile(ra + '/Reply B.zip', 'w') as z:
            z.write(ra + '/rep2.msg', 'MYTHKING.MSG')
        os.remove(ra + '/rep2.msg')
        c.sendall(keys['qwkin'].encode())
        b = until(c, b'reply file', 8)
        c.sendall(b'y')
        b = until(c, b'Begin transfer now', 8)
        rc = bridge(c, ['sz', '-b', ra + '/Reply B.zip'], ra)
        b = until(c, b'message(s) posted', 20)
        c.sendall(b'\r')
        b += until(c, b'Command >', 8)
        check('reply upload with the built-in Zmodem: sz sends "Reply B.zip" (a name with a blank), it is unpacked and posted', rc == 0 and b'2 message(s) posted' in b and b'Command >' in b)
        dump = subprocess.run([repo + '/build/tossdump', '6'], capture_output=True, text=True, env=dict(os.environ, MK=ra), encoding='latin-1').stdout
        check('... the new messages are in area 6', 'Reply via REP B' in dump and 'Second reply B' in dump)
        rzdir = os.path.join(work, 'rz'); os.makedirs(rzdir)
        c.sendall(keys['qwkout'].encode())
        until(c, b'Begin transfer now', 40)
        rc = bridge(c, ['rz', '-b'], rzdir)
        b = until(c, b'Command >', 20)
        got = [f for f in os.listdir(rzdir)]
        check('download with the built-in Zmodem: rz receives the packet, the menu is back', rc == 0 and len(got) == 1 and b'Command >' in b)
        if got:
            z = zipfile.ZipFile(os.path.join(rzdir, got[0]))
            z.extractall(os.path.join(rzdir, 'x'))
            pd = subprocess.run([repo + '/build/qwkmsgtest', 'dump', os.path.join(rzdir, 'x', 'messages.dat')], capture_output=True, text=True, encoding='latin-1').stdout
            check('... the packet is a QWK packet with the new messages (the binary survived the telnet session)', 'Reply via REP B' in pd and 'Second reply B' in pd and 'Reply via REP\n' not in pd.replace('Reply via REP B', ''))
    if have_qwk and shutil.which('sb') and shutil.which('rb'):
        # the same with Ymodem (batch: names in block 0), the caller chooses it with command 153
        c.sendall(keys['setprot'].encode())
        b = drive(c, [(b'Choose transfer protocol ?', b'Y')], b'Command >', 20)
        check('menu command 153: the caller chooses Ymodem', b'Command >' in b)
        subprocess.run([repo + '/build/qwkmsgtest', 'reply', ra + '/rep3.msg', '6', 'MythKing', ' C'], check=True, capture_output=True)
        with zipfile.ZipFile(ra + '/replyc.zip', 'w') as z:
            z.write(ra + '/rep3.msg', 'MYTHKING.MSG')
        os.remove(ra + '/rep3.msg')
        c.sendall(keys['qwkin'].encode())
        until(c, b'reply file', 8)
        c.sendall(b'y')
        until(c, b'Begin transfer now', 8)
        rc = bridge(c, ['sb', '-b', ra + '/replyc.zip'], ra)
        b = until(c, b'message(s) posted', 20)
        c.sendall(b'\r')
        b += until(c, b'Command >', 8)
        check('reply upload with the built-in Ymodem: sb sends it, it is unpacked and posted', rc == 0 and b'2 message(s) posted' in b and b'Command >' in b)
        rbdir = os.path.join(work, 'rb'); os.makedirs(rbdir)
        c.sendall(keys['qwkout'].encode())
        until(c, b'Begin transfer now', 40)
        rc = bridge(c, ['rb', '-b'], rbdir)
        b = until(c, b'Command >', 20)
        got = os.listdir(rbdir)
        ok = False
        if len(got) == 1:
            pd = subprocess.run(['unzip', '-p', os.path.join(rbdir, got[0]), 'messages.dat'], capture_output=True)
            with open(os.path.join(rbdir, 'm.dat'), 'wb') as fh:
                fh.write(pd.stdout)
            pdump = subprocess.run([repo + '/build/qwkmsgtest', 'dump', os.path.join(rbdir, 'm.dat')], capture_output=True, text=True, encoding='latin-1').stdout
            ok = 'Reply via REP C' in pdump and 'Second reply C' in pdump
        check('download with the built-in Ymodem: rb receives the packet (a QWK packet with the new messages), the menu is back', rc == 0 and ok and b'Command >' in b)
    c.sendall(keys['rawkey'].encode())
    time.sleep(1.0)
    c.sendall(b'q')
    b = until(c, b'key=', 5) + until(c, b'Command >', 5)
    check('a program that sets the terminal to raw mode gets a key without Enter (and the terminal is sane again after it)', b'key=q' in b and b'Command >' in b)
    c.sendall(keys['hang'].encode())
    check('a program that waits', b'started' in until(c, b'started', 5))
    time.sleep(0.5)
    hp = ra + '/node1/hang.pid'
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
    if b'More?' in b[-60:]:                          # the pager of a screen that is long now
        c.sendall(b'c')
        b += until(c, b'ress', 6)
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
