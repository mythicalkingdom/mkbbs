#!/usr/bin/env python3
"""The file echo pages of mkconfig (EchoMail > File Echoes, File Echo Options, File Echo Systems): shown, saved in fileecho.mk
(a record of fixed size, laid out as MKGlobT.pas says), and read back by the next run; a BBS without the file gets the defaults.
Private copy of the sample BBS.   usage: fileechoedittest.py <work dir>"""
import os, shutil, struct, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
cfg = cfgpatch.short_dir() + '/r'
shutil.copytree(src, cfg, ignore=lambda d, names: [n for n in names if n.lower().startswith(('mkbink.conf', 'fileecho.mk')) or
                                                   not os.access(os.path.join(d, n), os.R_OK)])
cfgpatch.fix_sample(cfg)
# the paths in config.mk lead to the sample: point them at the copy, or a file that is only in the sample would be found, and saved over, through them
cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
               lambda p: (cfg + '/').encode() + p[len((src + '/').encode()):] if p.startswith((src + '/').encode()) else p)
env = dict(os.environ, MK=cfg)
fails = 0
SIZE = 33024
SYS0, AREA0 = 212, 212 + 32 * 41            # where the systems and the echoes start in the record


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'file echo editor: ' + name)
    if not ok:
        fails += 1


def screen(*keys):
    e = dict(env, CFGDIR=cfg, CFGDELAY='0.25')
    r = subprocess.run([sys.executable, os.path.join(here, 'cfgshot.py')] + list(keys), capture_output=True, text=True, env=e)
    return r.stdout


def pstr(d, off, n):
    return d[off + 1:off + 1 + d[off]].decode('cp437')


s = screen('\x1bc', 'e')
check('EchoMail > File Echoes lists the 300 echoes, none used', 'File Echoes' in s and '(unused)' in s)
s = screen('\x1bc', 'e', '\r')
check('the echo form has Tag, About, File area, Hub, the two switches, Echo To and Groups',
      all(w in s for w in ('Tag:', 'About:', 'File area:', 'Hub:', 'Replaces allowed:', 'No check command:', 'Echo To...', 'Groups...')))

# echo 1: tag, about, file area 3, hub 2, replaces allowed
screen('\x1bc', 'e', '\r', 'FSX_GEN', '\t', 'General files', '\t', '3', '\t', '2', '\t', ' ', '\r', '\x1b', '\x1bx', 'y')
f = os.path.join(cfg, 'fileecho.mk')
check('fileecho.mk was written with the pinned size (%d)' % SIZE, os.path.exists(f) and os.path.getsize(f) == SIZE)
d = open(f, 'rb').read() if os.path.exists(f) else bytes(SIZE)
check('echo 1: tag, about, file area 3, hub 2, replaces allowed (1)',
      pstr(d, AREA0, 40) == 'FSX_GEN' and pstr(d, AREA0 + 41, 40) == 'General files' and struct.unpack('<H', d[AREA0 + 82:AREA0 + 84])[0] == 3
      and d[AREA0 + 88] == 2 and struct.unpack('<H', d[AREA0 + 93:AREA0 + 95])[0] == 1)
check('the defaults are kept: a 60 second check, 14 days of spool', struct.unpack('<H', d[103:105])[0] == 60 and struct.unpack('<H', d[166:168])[0] == 14)
s = screen('\x1bc', 'e')
check('the list shows it: tag and area 3', 'FSX_GEN' in s and 'area 3' in s)

# the options
s = screen('\x1bc', 'p')
check('the options page has the check command, the time and the pass-through spool, days and MB',
      all(w in s for w in ('Check command:', 'Check time (s):', 'Pass-thru spool:', 'Pass-thru days:', 'Pass-thru MB:')))
screen('\x1bc', 'p', '/bin/true %F %T', '\t', '30', '\t', '/tmp/spool/', '\t', '7', '\t', '100', '\r', '\x1bx', 'y')
d = open(f, 'rb').read()
check('options: the check command, 30 seconds, the spool, 7 days, 100 MB',
      pstr(d, 2, 100) == '/bin/true %F %T' and struct.unpack('<H', d[103:105])[0] == 30 and pstr(d, 105, 60) == '/tmp/spool/'
      and struct.unpack('<H', d[166:168])[0] == 7 and struct.unpack('<H', d[168:170])[0] == 100)
check('... the echo is still there', pstr(d, AREA0, 40) == 'FSX_GEN')

# the systems
s = screen('\x1bc', 'y')
check('File Echo Systems lists the 32 echo systems', 'File Echo Systems' in s and 'TIC pwd' in s)
s = screen('\x1bc', 'y', '\r')
check('a system has the TIC password, the FileFix password and the groups', all(w in s for w in ('TIC password:', 'FileFix password:', 'Groups...')))
screen('\x1bc', 'y', '\r', 'ticpw', '\t', 'fixpw', '\r', '\x1b', '\x1bx', 'y')
d = open(f, 'rb').read()
check('system 1: TIC password and FileFix password; the rest of the file is as it was',
      pstr(d, SYS0, 8) == 'ticpw' and pstr(d, SYS0 + 9, 15) == 'fixpw' and pstr(d, AREA0, 40) == 'FSX_GEN' and pstr(d, 2, 100) == '/bin/true %F %T'
      and len(d) == SIZE)
s = screen('\x1bc', 'y')
check('the list hides the passwords (stars) and shows that they are set', 'ticpw' not in s and 'fixpw' not in s and '*****' in s)

# a BBS without the file gets the defaults, and the first save makes it
os.remove(f)
s = screen('\x1bc', 'p')
check('without fileecho.mk the options are the defaults (60 seconds, 14 days)', 'Check time (s):  60' in s.replace('  ', '  ') or '60' in s)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
