#!/usr/bin/env python3
"""Mailer settings: the mkconfig pages (Mailer, Mailer Links) save mailer.mk, and mkbinkcfg turns the configuration into
the settings file of mkbink (checked with "mkbink check" when the mkbink project is built next to this one).
usage: mailertest.py <work dir>"""
import os, shutil, stat, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
work = os.path.abspath(sys.argv[1])
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
cfg = cfgpatch.short_dir() + '/r'
shutil.copytree(src, cfg, ignore=lambda d, names: [n for n in names if n.lower().startswith(('mkbink.conf', 'mailer.mk'))])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(cfg)
# the paths in config.mk lead to the sample: point them at the copy, or a file that is only in the sample (a
# mailer.mk made by hand there) would be found, and saved over, through them
cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
               lambda p: (cfg + '/').encode() + p[len((src + '/').encode()):] if p.startswith((src + '/').encode()) else p)
guard = {f: os.stat(os.path.join(src, f)).st_mtime_ns for f in os.listdir(src) if f.lower() in ('mailer.mk', 'mkbink.conf', 'echocfg.mk', 'config.mk')}
# the sample may have been configured by hand (mailer on, echo paths): start from one without
for f in os.listdir(cfg):
    if f.lower() in ('mailer.mk', 'mkbink.conf'):
        os.remove(os.path.join(cfg, f))
    if f.lower() == 'echocfg.mk':
        d = bytearray(open(os.path.join(cfg, f), 'rb').read())
        d[0:102] = bytes(102)                      # InBoundFiles, OutBoundFiles: String[50] each
        open(os.path.join(cfg, f), 'wb').write(d)
binkcfg = os.path.join(repo, 'build', 'mkbinkcfg')
mkbink = os.environ.get('MKBINK', os.path.join(repo, '..', 'mkbink', 'build', 'mkbink'))
env = dict(os.environ, MK=cfg)
fails = 0

# the record: mailer.mk is MailerCfgType, 1 KB of expansion at the end
SIZE, LINKS, LINK = 12600, 184, 178


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mailer: ' + name)
    if not ok:
        fails += 1


def tool(*args):
    r = subprocess.run([binkcfg] + list(args), capture_output=True, text=True, env=env)
    return r.returncode, r.stdout, r.stderr


def screen(*keys):
    e = dict(env, CFGDIR=cfg, CFGDELAY='0.25')
    r = subprocess.run([sys.executable, os.path.join(here, 'cfgshot.py')] + list(keys), capture_output=True, text=True, env=e)
    return r.stdout


mailer = os.path.join(cfg, 'mailer.mk')

# ---- the echo paths (EchoMail Options): relative to the BBS directory
check('the sample has no echo paths: mkbinkcfg refuses', tool('-n')[0] == 1)
screen('\\x1bc', 'o', 'files/in', '\\t', 'mail/out', '\\r', '\\x1bx', 'y')

# ---- no mailer.mk: defaults, mailer not enabled
rc, out, err = tool('-n')
check('no mailer.mk: the defaults (listen yes, port 24554, retry 60/3600)',
      rc == 0 and 'listen yes' in out and 'port 24554' in out and 'retry-min 60' in out and 'retry-max 3600' in out)
check('... the BBS address, name, sysop and the echo paths (relative ones from the BBS directory) come from the BBS configuration',
      out.count('address ') >= 1 and 'sysname ' in out and 'sysop ' in out and
      ('inbound %s/files/in' % cfg) in out and ('bso %s/mail/out' % cfg) in out)
rc, out, err = tool()
check('not enabled: exit 3, nothing written', rc == 3 and not os.path.exists(os.path.join(cfg, 'mkbink.conf')))

# ---- mkconfig: enable the mailer, set two links, save
s = screen('\x1bc'.encode().decode('latin-1') if False else '\\x1bc', 'm')
check('EchoMail > Mailer shows the settings page', 'Mailer enabled' in s and 'Retry after' in s and 'Accept unknown' in s)
s = screen('\\x1bc', 'l')
check('EchoMail > Mailer Links shows 64 numbered entries', '(unused)' in s and 'Mailer Links' in s)
keys = ['\\x1bc', 'm', ' ', '\\t' * 10, 'fidonet', '\\r',                       # enabled, domain
        '\\x1bc', 'l', '\\r', '1', '\\t', '110', '\\t', '100', '\\t', '\\t', 'Test Hub', '\\t', '127.0.0.1', '\\t', '24602', '\\t', '15',
        '\\t', '\\t', 'secret', '\\r',                                          # link 1
        '\\x1b[B', '\\r', '1', '\\t', '110', '\\t', '200', '\\t', '\\t', 'Down Link', '\\t', '\\t', '\\t', '\\t', '\\t', 'p2', '\\t', ' ', '\\r',  # link 2: answer only
        '\\x1b', '\\x1bx', 'y']
screen(*keys)
check('mailer.mk was written with the pinned size (%d: record + 1 KB expansion)' % SIZE,
      os.path.exists(mailer) and os.path.getsize(mailer) == SIZE)
d = open(mailer, 'rb').read()
check('flags: enabled + listen; domain "fidonet"', d[2] & 3 == 3 and b'fidonet' in d[:LINKS])
rc, out, err = tool('-n')
check('mkbinkcfg -n: link 1 with host, port, password, poll', 'link 1:110/100' in out and 'host 127.0.0.1' in out and
      'port 24602' in out and 'password secret' in out and 'poll 15' in out and 'name Test Hub' in out)
check('... link 2 answers only (no host, no call)', 'link 1:110/200' in out and 'answer-only yes' in out and 'password p2' in out)
check('... domain', 'domain fidonet' in out)

# ---- the file
rc, out, err = tool()
conf = os.path.join(cfg, 'mkbink.conf')
check('mkbinkcfg writes mkbink.conf (%s)' % out.strip().replace(cfg, '.'), rc == 0 and os.path.exists(conf))
check('... mode 600 (it holds passwords)', os.path.exists(conf) and stat.S_IMODE(os.stat(conf).st_mode) == 0o600)
m1 = os.stat(conf).st_mtime_ns
time.sleep(0.05)
rc, out, err = tool()
check('a second run leaves it alone (up to date)', rc == 0 and 'up to date' in out and os.stat(conf).st_mtime_ns == m1)
check('no .new file left', not os.path.exists(conf + '.new'))
rc, out, err = tool('-q')
check('-q says nothing', rc == 0 and out == '')
if os.path.exists(mkbink):
    r = subprocess.run([mkbink, 'check', '-f', conf], capture_output=True, text=True)
    check('mkbink check accepts the file (%s)' % r.stdout.strip().splitlines()[-1] if r.stdout.strip() else 'no output',
          r.returncode == 0 and 'ok: 2 link(s)' in r.stdout and 'warning' not in r.stdout)
else:
    print('skip mkbink check: %s not built' % mkbink)

# ---- an older / shorter / foreign mailer.mk
good = open(mailer, 'rb').read()
open(mailer, 'wb').write(good[:LINKS + LINK])          # made by an older version: only the first link is in it
rc, out, err = tool('-n')
check('a shorter file: what is in it is used, the rest keeps its defaults', rc == 0 and 'link 1:110/100' in out and 'link 1:110/200' not in out and 'retry-min 60' in out)
bad = bytearray(good); bad[0:2] = (99).to_bytes(2, 'little')
open(mailer, 'wb').write(bad)
rc, out, err = tool('-n')
check('a version we do not know is not used (defaults)', rc == 0 and 'link 1:' not in out)


def patched(fn):
    d = bytearray(good)
    fn(d)
    open(mailer, 'wb').write(d)


def put(d, off, text, size):
    d[off:off + size] = bytes([len(text)]) + text.encode() + bytes(size - 1 - len(text))


def addr(d, base, z, n, f, p=0):
    d[base:base + 8] = b''.join(v.to_bytes(2, 'little') for v in (z, n, f, p))


patched(lambda d: addr(d, LINKS + LINK, 1, 110, 100))
before = open(conf, 'rb').read()
rc2, out2, err2 = tool()
check('two links with one address: error, nothing written (exit 1)', rc2 == 1 and 'same address' in err2 and open(conf, 'rb').read() == before
      and not os.path.exists(conf + '.new'))
patched(lambda d: put(d, LINKS + 8 + 31 + 61 + 2, 'bad #word', 31))
rc, out, err = tool('-n')
check('a password with " #" is refused', rc == 1 and 'password' in err)
patched(lambda d: d.__setitem__(LINKS + 8 + 31 + 61 + 2 + 31 + 2 + 2, 7))
rc, out, err = tool('-n')
check('"our address" 7 that is not set is refused', rc == 1 and 'our address 7' in err)
patched(lambda d: d.__setitem__(LINKS + 8 + 31 + 61 + 2 + 31, 2))   # link 1 flags: disabled
rc, out, err = tool('-n')
check('a disabled link is left out', rc == 0 and 'link 1:110/100' not in out and 'link 1:110/200' in out)

# ---- phase 5: the no-password inbound and the command after mail comes (in the room taken from the expansion)
patched(lambda d: d.__setitem__(LINKS + 8 + 31 + 61 + 2 + 31, 0))   # link 1 enabled again
HOOK = LINKS + 64 * LINK                                             # UnsecureIn, OnInbound, HookTimeout follow the links
rc, out, err = tool('-n')
check('no hook set: no inbound-unsecure / on-inbound / hook-timeout lines', rc == 0 and 'inbound-unsecure' not in out and 'on-inbound' not in out and 'hook-timeout' not in out)
patched(lambda d: (put(d, HOOK, 'files/unsec', 61), put(d, HOOK + 61, '/usr/bin/toss -x', 101), d.__setitem__(slice(HOOK + 162, HOOK + 164), (45).to_bytes(2, 'little'))))
rc, out, err = tool('-n')
check('inbound-unsecure (relative to the BBS directory), on-inbound and hook-timeout are written',
      rc == 0 and ('inbound-unsecure %s/files/unsec' % cfg) in out and 'on-inbound /usr/bin/toss -x' in out and 'hook-timeout 45' in out)
check('the file stays the size it was', os.path.getsize(mailer) == SIZE)

check('the sample BBS itself was not touched', guard == {f: os.stat(os.path.join(src, f)).st_mtime_ns for f in guard})
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
