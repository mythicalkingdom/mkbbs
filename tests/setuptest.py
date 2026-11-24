#!/usr/bin/env python3
"""mksetup: makes a BBS that mk can run: the folder, the configuration (read back with mkcfgcvt), the language file, two local message areas (Merlin), a file area with an example file, the sample door, the
menu and the screens; refuses a folder that has a configuration; then the real mk (mk -L on a pty, started from another directory) takes a new caller through registration to the menu, reads a message
area, lists the files, and says goodbye with the screen.   usage: setuptest.py <build dir> <work dir>"""
import hashlib, json, os, pty, re, select, shutil, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
if not os.path.exists(build + '/mksetup') or not os.path.exists(repo + '/lang/AMERICAN.lc'):
    print('skip: no mksetup or language files'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mksetup: ' + name + ('' if ok else '  ' + str(info)[-700:]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
sys.path.insert(0, here)
import cfgpatch
tmp = cfgpatch.short_dir()
B = tmp + '/bbs'            # a short path: the configuration holds file area paths in 50 characters
cwd = work + '/cwd'
os.makedirs(cwd)


def setup(*a, stdin=None):
    return subprocess.run([build + '/mksetup', '-L', repo + '/lang'] + list(a), capture_output=True, text=True, input=stdin)


r = setup('-d', B, '-n', 'Test BBS', '-s', 'Test Sysop', '-y')
check('mksetup -y makes the BBS: exit 0, and says how to try it', r.returncode == 0 and 'mk -L' in r.stdout, r.stdout + r.stderr)
need = ['config.mk', 'messages.mk', 'files.mk', 'american.lc', 'mkmenu.lc', 'limits.ctl', 'newuser.q-a', 'menus/top.mnu', 'txtfiles/welcome.asc', 'txtfiles/goodbye.asc', 'txtfiles/newuser1.asc',
        'files/area01/readme.txt', 'files/area01/files.bbs', 'msgs/gen.mer', 'msgs/sys.mer', 'users.bbs', 'node1']
check('the folders and files are there', all(os.path.exists(B + '/' + n) for n in need), [n for n in need if not os.path.exists(B + '/' + n)])
check('the sample door is there (the Pascal game)', os.path.exists(B + '/games/cowsandbulls.pas'))
check('the menu is whole records of 167 bytes (a header and 19 items)', os.path.getsize(B + '/menus/top.mnu') == 167 * 20, os.path.getsize(B + '/menus/top.mnu'))
check('the screens are one short line', open(B + '/txtfiles/welcome.asc').read().strip() == 'Welcome to Test BBS' and open(B + '/txtfiles/goodbye.asc').read().strip() == 'Thank you for visiting Test BBS')
check('the example file and its list', 'files.bbs' not in open(B + '/files/area01/files.bbs').read().split()[0] and open(B + '/files/area01/files.bbs').read().startswith('readme.txt'))

# the configuration, read back
cj = work + '/cj'
os.makedirs(cj)
r = setup('-d', work + '/' + 'a' * 60, '-y')
check('a folder name that is too long for the configuration is refused with the reason', r.returncode == 1 and 'too long' in r.stderr, r.stderr)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=dict(os.environ, MK=B, MKJSON=cj), check=True, capture_output=True)
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
c = d['config']
check('the configuration: name, sysop, language, the paths of the folder', c['SystemName'] == 'Test BBS' and c['SysopName'] == 'Test Sysop' and c['LangFile'][0] == 'american' and c['MsgPath'][0] == B + '/msgs/'
      and c['MenuPath'][0] == B + '/menus/' and c['TxtPath'][0] == B + '/txtfiles/', {k: c.get(k) for k in ('SystemName', 'SysopName', 'LangFile', 'MsgPath')})
m = d['messages']
ks = sorted(m, key=int)
named = [k for k in ks if m[k]['Name']]
check('two message areas: General Messages and Comments to the Sysop, Merlin bases, local only', [m[k]['Name'] for k in named] == ['General Messages', 'Comments to the Sysop'] and all(m[k]['MsgBaseType'] == 'M' and m[k]['MsgType'] == 0 for k in named), [(m[k]['Name'], m[k]['MsgBaseType']) for k in named])
check('no purge by age or count in them', all(m[k]['DaysKept'] == 0 and m[k]['RcvdDays'] == 0 and m[k]['MsgsKept'] == 0 for k in named))
f = d['files']
fk = [k for k in sorted(f, key=int) if f[k]['Name']]
check('one file area: Example Files in files/area01', len(fk) == 1 and f[fk[0]]['FilePath'] == B + '/files/area01/', [(f[k]['Name'], f[k]['FilePath']) for k in fk])

# not over an existing configuration
h0 = hashlib.sha1(open(B + '/config.mk', 'rb').read()).hexdigest()
r = setup('-d', B, '-y')
check('a folder that has a configuration is refused: exit 2, nothing changed', r.returncode == 2 and 'configuration already' in r.stderr and hashlib.sha1(open(B + '/config.mk', 'rb').read()).hexdigest() == h0, r.stderr)
r = setup('-d', tmp + '/x', '-l', 'klingon', '-y')
check('a language that is not there: exit 1', r.returncode == 1 and not os.path.exists(tmp + '/x/config.mk'), r.stderr)
r = setup('-d', tmp + '/eng', '-l', 'english', '-y')
check('-l english: english.lc and the language in the configuration', r.returncode == 0 and os.path.exists(tmp + '/eng/english.lc') and not os.path.exists(tmp + '/eng/american.lc'), r.stdout + r.stderr)
r = setup(stdin=tmp + '/ask\nAsk BBS\nAsk Sysop\nenglish\n')
check('without -y the questions are asked (folder, name, sysop, language)', r.returncode == 0 and os.path.exists(tmp + '/ask/config.mk') and 'Ask BBS' in open(tmp + '/ask/txtfiles/welcome.asc').read(), r.stdout + r.stderr)


# a caller, through the real mk on a pty, started from another directory
class Term:
    def __init__(self, bbs, cwd):
        self.buf = b''
        pid, self.fd = pty.fork()
        if pid == 0:
            os.chdir(cwd)
            os.environ.update(MK=bbs, TERM='xterm')
            os.execv(build + '/mk', ['mk', '-L'])
        self.pid = pid

    def drain(self, t):
        end = time.time() + t
        while time.time() < end:
            r, _, _ = select.select([self.fd], [], [], 0.1)
            if r:
                try:
                    self.buf += os.read(self.fd, 65536)
                except OSError:
                    return

    def settle(self, quiet=0.6, limit=6):
        end = time.time() + limit
        last = len(self.buf)
        stable = time.time()
        while time.time() < end and time.time() - stable < quiet:
            self.drain(0.1)
            if len(self.buf) != last:
                last = len(self.buf)
                stable = time.time()

    def send(self, s, t=1.3):
        self.settle()
        for _ in range(4):                       # a page is waiting: More? (Y)es (N)o (C)ontinuous?
            if self.text().rstrip().endswith('Continuous?'):
                os.write(self.fd, b'C')
                self.settle()
        os.write(self.fd, s.encode())
        self.drain(t)

    def text(self):
        return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', self.buf).decode('latin-1')


t = Term(B, cwd)
t.drain(3)
for k in ('Test User\r', 'Y\r', 'Dayton OH\r', 'N\r', 'N\r', '\r', '\r', '\r', '513-555-1234\r', '513-555-1234\r', '01/01/80\r', 'M\r', 'secret1\r', 'secret1\r', 'Y\r', '\r', '\r', '\r'):
    t.send(k)
s = t.text()
check('a new caller is registered (name, city, phones, password) without an error from the questionnaire', 'Command >' in s and 'Error in Questionaire' not in s and 'Time Limit Exceeded' not in s, s[-500:])
check('the welcome and the registration screens are shown', 'Welcome, new caller' in s and 'Welcome to Test BBS' in s)
check('the menu: the title, the current areas (names from \\kY and \\kZ), the items in two columns', 'Main menu' in s and 'Messages: General Messages   Files: Example Files' in s and '(R)ead messages                 (P)ost a message' in s, s[-900:])
t.send('R')
s = t.text()
check('R reads the first message area (a new caller starts in area 1)', 'Reading message area 1 - General Messages' in s and 'security to read' not in s, s[-300:])
t.send('Q')
t.send('F')
s = t.text()
check('F lists the files of the area: the example file with its description', 'readme.txt' in s and 'An example file' in s, s[-1500:])
t.send('\r')
t.send('G')
s = t.text()
check('G says goodbye with the screen', 'Thank you for visiting Test BBS' in s, s[-300:])
t.drain(1.5)
try:
    os.waitpid(t.pid, os.WNOHANG)
except OSError:
    pass
check('nothing was written in the directory mk was started from but the exitinfo of the node (the data files are in the BBS folder)', set(os.listdir(cwd)) <= {'exitinfo.bbs'}, os.listdir(cwd))
check('the user file in the BBS folder has the one caller', os.path.getsize(B + '/users.bbs') == 158 and os.path.getsize(B + '/extusers.bbs') == 614, (os.path.getsize(B + '/users.bbs'), os.path.getsize(B + '/extusers.bbs')))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
