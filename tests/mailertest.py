#!/usr/bin/env python3
"""Mailer settings: the mkconfig pages (Mailer, Mailer Links) save mailer.mk, and mkbinkcfg turns the configuration into
the settings file of mkbink (checked with "mkbink check" when the mkbink project is built next to this one).
usage: mailertest.py <work dir>"""
import os, re, shutil, stat, subprocess, sys, time

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
shutil.copytree(cfgpatch.snapshot(src), cfg, ignore=lambda d, names: [n for n in names if n.lower().startswith(('mkbink.conf', 'mailer.mk'))])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(cfg)
# the paths in config.mk lead to the sample: point them at the copy, or a file that is only in the sample (a
# mailer.mk made by hand there) would be found, and saved over, through them
cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
               lambda p: (cfg + '/').encode() + p[len((src + '/').encode()):] if p.startswith((src + '/').encode()) else p)
import hashlib
# what the sample holds, by content (the time of a file can change when the daemon that runs on the sample, or a person, saves the same settings again)
sample_state = lambda: {f: hashlib.sha256(open(os.path.join(src, f), 'rb').read()).hexdigest() for f in os.listdir(src) if f.lower() in ('mailer.mk', 'echocfg.mk', 'config.mk') and os.access(os.path.join(src, f), os.R_OK)}
guard = sample_state()
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

# netmail routing (EchoMail > Routing): the first route, saved after the packet passwords
s = screen('\\x1bc', 'r')
check('EchoMail > Routing shows the 12 routes', 'Netmail Routing' in s and s.count('(unused)') == 12)
screen('\\x1bc', 'r', '\\r', '2:*/*', '\\t', '1', '\\t', ' ', '\\r', '\\x1b', '\\x1bx', 'y')
d = open(mailer, 'rb').read()
RT = LINKS + 64 * LINK + 164 + 32 * 9
check('route 1 is saved in mailer.mk: addresses 2:*/*, via system 1, flavour Immediate (1); the file keeps its size',
      d[RT:RT + 6] == b'\x052:*/*' and d[RT + 41] == 1 and d[RT + 42] == 1 and len(d) == SIZE)

# the tosser switch on the Mailer page (the 20th field), and what mkbinkcfg does with it
s = screen('\\x1bc', 'm')
check('the Mailer page has "Tosser:"', 'Tosser:' in s)
screen('\\x1bc', 'm', '\\t' * 19, ' ', '\\r', '\\x1bx', 'y')
d = open(mailer, 'rb').read()
check('switching it on in mkconfig sets the tosser flag (128) in mailer.mk', d[2] & 128 == 128 and d[2] & 3 == 3 and len(d) == SIZE)
d = bytearray(d)
d[2] &= ~128                                  # the tests that follow start with the tosser off
open(mailer, 'wb').write(d)

# the packet password of an echo system (EchoMail > Systems > a system), kept in mailer.mk after the hook fields
s = screen('\\x1bc', '\\r', '\\r')
check('EchoMail > Systems > System 1 has "Areafix pwd:" and "Packet pwd:"', 'Areafix pwd:' in s and 'Packet pwd:' in s)
screen('\\x1bc', '\\r', '\\r', '\\t' * 9, 'abc', '\\r', '\\x1b', '\\x1bx', 'y')
d = open(mailer, 'rb').read()
check('the packet password of system 1 is saved in mailer.mk (after the hook fields), the file keeps its size',
      d[LINKS + 64 * LINK + 164:LINKS + 64 * LINK + 168] == b'\x03abc' and len(d) == SIZE)

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

# ---- multiple batches: offered unless the Mailer page says no (bit 256 of the flags)
patched(lambda d: d.__setitem__(3, d[3] & ~1))
rc, out, err = tool('-n')
check('multiple batches: on by default (a file with the bit clear): multi-batch yes', rc == 0 and 'multi-batch yes' in out and 'multi-batch no' not in out)
patched(lambda d: d.__setitem__(3, d[3] | 1))
rc, out, err = tool('-n')
check('multiple batches: switched off in the Mailer page: multi-batch no', rc == 0 and 'multi-batch no' in out)
patched(lambda d: d.__setitem__(3, d[3] & ~1))
s = screen('\x1bc', 'm')
check('the Mailer page has "Multi batch:"', 'Multi batch:' in s)
screen('\x1bc', 'm', '\t' * 20, ' ', '\r', '\x1bx', 'y')
d = open(mailer, 'rb').read()
check('switching Multi batch off in mkconfig sets bit 256 in mailer.mk and keeps the size', d[3] & 1 == 1 and len(d) == SIZE)
patched(lambda d: d.__setitem__(3, d[3] & ~1))

# ---- the tosser as the command mkbink runs after mail arrives
patched(lambda d: d.__setitem__(2, d[2] | 128))
rc, out, err = tool('-n')
check('tosser on, no command: on-inbound is mktoss (next to mkbinkcfg)', rc == 0 and ('on-inbound %s' % os.path.join(repo, 'build', 'mktoss')) in out)
patched(lambda d: (d.__setitem__(2, d[2] | 128), put(d, HOOK + 61, '/usr/bin/mytosser -x', 101)))
rc, out, err = tool('-n')
check('tosser on and a command set: the command wins', rc == 0 and 'on-inbound /usr/bin/mytosser -x' in out and 'mktoss' not in out)
patched(lambda d: d.__setitem__(2, d[2] & ~128))
rc, out, err = tool('-n')
check('tosser off: no on-inbound', rc == 0 and 'on-inbound' not in out)

# ---- file requests (EchoMail > File Requests): the page saves, mkbinkcfg writes the keys for mkbink; the link and the file area have their fields
rc, out, err = tool('-n')
check('file requests off (the default): no freq lines', rc == 0 and 'freq' not in out)
s = screen('\x1bc', 'f')
check('EchoMail > File Requests shows the page', 'File Requests' in s and 'Answer file requests:' in s and 'Magic names file:' in s and 'File request security:' in s)
screen('\x1bc', 'f', ' ', '\t', ' ', '\t', ' ', '\t', '80', '\t', 'magic.txt', '\t', '7', '\t', '300', '\r', '\x1bx', 'y')
rc, out, err = tool('-n')
check('switched on with limits: mkbinkcfg writes freq yes, freq-unsecure yes, on-freq (mkfreq next to it), freq-max-files 7, freq-max-kb 300',
      rc == 0 and 'freq yes' in out and 'freq-unsecure yes' in out and ('on-freq %s' % os.path.join(repo, 'build', 'mkfreq')) in out
      and 'freq-max-files 7' in out and 'freq-max-kb 300' in out)
s = screen('\x1bc', 'f')
check('the page shows what was saved (user level 80, the magic names file, the limits)', 'magic.txt' in s and re.search(r'File request security:\s+80', s) is not None
      and re.search(r'Most files:\s+7', s) and re.search(r'Most KB:\s+300', s))
s = screen('\x1bc', 'l', '\r')
check('a link has "File request level"', 'File request level:' in s)
screen('\x1bc', 'm', '\t' * 19, ' ', '\r', '\x1bx', 'y')            # (nothing to do with requests: the page still saves)
patched(lambda d: d.__setitem__(2, d[2] & ~64))
rc, out, err = tool('-n')
check('switched off again: no freq lines', rc == 0 and 'freq' not in out)

s = screen('\x1bf', 'a', '\r')
check('a file area has "Allow file requests"', 'Allow file requests:' in s)
import json
def area_attr(n):
    cj = os.path.join(work, 'cjfa')
    shutil.rmtree(cj, ignore_errors=True)
    os.makedirs(cj)
    subprocess.run([os.path.join(repo, 'build', 'mkcfgcvt'), '-y', '1', '5'], env=dict(env, MKJSON=cj), check=True, capture_output=True)
    return json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))['files'][str(n)]['Attr']
before = area_attr(1)
screen('\x1bf', 'a', '\r', *(['\t'] * 13), ' ', '\r', '\x1b', '\x1bx', 'y')
check('... the box is saved in the area (bit 32 of Attr), the other bits are as they were', area_attr(1) == (before ^ 32))

check('the sample BBS itself was not touched (the content of its mailer.mk, echocfg.mk and config.mk)', guard == sample_state())
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
