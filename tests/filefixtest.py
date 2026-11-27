#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""FileFix (mktoss): a netmail to FileFix / FileMgr from an echo system links and unlinks file echoes (fileecho.mk), lists them, asks the hub;
the password is the FileFix one, or the Areafix one when none is set; groups limit what a system sees.  Private copy of the sample BBS.
usage: filefixtest.py <build dir> <work dir>"""
import json, os, re, shutil, struct, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
srcra = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(srcra):
    print('skip: no sample BBS'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
cfg = tmp + '/r'
inb, outb, unsec = tmp + '/in', tmp + '/out', tmp + '/un'
for d in (inb, outb, unsec):
    os.makedirs(d)
shutil.copytree(cfgpatch.snapshot(srcra), cfg, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(cfg)
# the message bases of the sample are in the sample BBS itself: the copy must have its own, or the replies of the tosser land in the real ones
assert cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
                      lambda s: (cfg + '/').encode() + s[len((srcra + '/').encode()):] if s.startswith((srcra + '/').encode()) else s) >= 1
env = dict(os.environ, MK=cfg)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'filefix: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


def run(prog, *a):
    return subprocess.run([os.path.join(build, prog)] + list(a), capture_output=True, text=True, env=env, encoding='latin-1')


run('tosssetup', inb, outb, unsec)
cj = tmp + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)


def load():
    subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True, input='', text=True)
    return json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))


def save(d):
    json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
    subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True, input='', text=True)


# the file echoes.  System 1 (1:110/100): Areafix password "secret", no FileFix password.  System 2 (1:110/200): Areafix password "pw2", FileFix
# password "fixpw2", group A.
d = load()
fe = d['fileecho']
fe['Area'] = {'1': {'Tag': 'FSX_GEN', 'Desc': 'General files', 'FileArea': 1, 'EchoTo': 2, 'Hub': 1},
              '2': {'Tag': 'FSX_GROUPA', 'Desc': 'Only group A', 'FileArea': 1, 'Groups': 1},
              '3': {'Tag': 'FSX_GROUPB', 'Desc': 'Only group B', 'FileArea': 1, 'Groups': 2},
              '4': {'Tag': 'FSX_FROM2', 'Desc': 'Comes from system 2', 'FileArea': 1, 'Hub': 2},
              '5': {'Tag': 'FSX_UP', 'Desc': 'Asked for from system 2', 'FileArea': 0, 'Hub': 2},
              '6': {'Tag': 'FSX_PASS', 'Desc': 'Pass-through', 'FileArea': 0, 'EchoTo': 2, 'Hub': 1},
              '7': {'Tag': 'FSX_OPEN', 'Desc': 'Open to every system', 'FileArea': 1}}
fe['Sys'] = {'2': {'FixPwd': 'fixpw2', 'Groups': 1}}
save(d)
mk = cfg + '/mailer.mk'
if os.path.exists(mk):
    f = bytearray(open(mk, 'rb').read()); f[2] |= 128; open(mk, 'wb').write(f)


def pkt(n, orig, text, subj, to='FileFix', frm='Remote Sysop', msgorig=None):
    """a packet (type 2) with one netmail for us (1:110/290) from orig = (zone, net, node)"""
    z, net, node = orig
    mz, mnet, mnode = msgorig or orig
    body = b'\x01INTL 1:110/290 %d:%d/%d\r' % (mz, mnet, mnode) + text.replace('\n', '\r').encode('latin-1') + b'\r'
    msg = struct.pack('<7H', 2, mnode, 290, mnet, 110, 0, 0) + b'22 Nov 26  12:00:00\x00' + to.encode() + b'\x00' + frm.encode() + b'\x00' + subj.encode() + b'\x00' + body + b'\x00'
    hdr = struct.pack('<12H', node, 290, 2026, 10, 22, 12, 0, 0, 0, 2, net, 110) + struct.pack('<BB8s', 0, 0, b'pktpw2' if node == 200 else b'') + struct.pack('<HHHHBBHHHHH', z, 1, 0, 0x0100, 0, 0, 1, z, 1, 0, 0) + bytes(4)
    assert len(hdr) == 58, len(hdr)
    open('%s/%04dfff.pkt' % (inb, n), 'wb').write(hdr + msg + b'\x00\x00')


def toss():
    r = run('mktoss', '-t', '-f')
    return r.stdout


def area4():
    return run('tossdump', '4').stdout


def answers(dest, kind='FileFix response'):
    """the netmails of the tosser to a system, in order: (header, text with | for the line ends)"""
    out = []
    for m in area4().split('\nmsg '):
        if 'dest=%s' % dest in m and 'subj=%s' % kind in m:
            h, _, t = m.partition('\ntext ')
            out.append((h, t))
    return out


def fecfg():
    return load()['fileecho']


# 1. a request from system 2: list, query, link, unlink, one it may not have, one that is not there
pkt(1, (1, 110, 200), '%LIST\n%QUERY\n+FSX_GROUPA\n-FSX_GEN\n+FSX_GROUPB\n+NO_SUCH\n', 'fixpw2')
out = toss()
check('the request is dealt with (counted as a request) and not stored for the sysop', 'FileFix request from 1:110/200: 6 command(s)' in out and '1 areafix' in out, out[-500:])
resp = answers('1:110/200')
check('the answer is a netmail from FileFix to the name that asked, to system 2', len(resp) == 1 and 'from=FileFix to=Remote Sysop' in resp[0][0], resp)
t = resp[0][1] if resp else ''
lst, qry = t.split('File echoes you have:')[0], t.split('File echoes you have:')[-1]
check('%LIST: the echoes system 2 may have: general, group A, the pass-through one and the open one; not group B, not the one that comes from system 2',
      all(x in lst for x in ('FSX_GEN', 'FSX_GROUPA', 'FSX_PASS', 'FSX_OPEN')) and 'FSX_GROUPB' not in lst and 'FSX_FROM2' not in lst and '(* = linked)' in lst, t)
check('%QUERY: it has FSX_GEN and FSX_PASS (marked *), nothing else', '* FSX_GEN' in qry and '* FSX_PASS' in qry and '* FSX_OPEN' not in qry.split('+FSX_GROUPA')[0], repr(t))
check('+FSX_GROUPA linked, -FSX_GEN unlinked, +FSX_GROUPB not available to it, +NO_SUCH no such file echo',
      '+FSX_GROUPA: linked' in t and '-FSX_GEN: unlinked' in t and '+FSX_GROUPB: not available to you' in t and '+NO_SUCH: no such file echo' in t, repr(t))
f = fecfg()
check('fileecho.mk was saved: group A is linked to system 2 (bit 2), general is not any more, the pass-through one still is',
      f['Area']['2']['EchoTo'] == 2 and f['Area']['1']['EchoTo'] == 0 and f['Area']['6']['EchoTo'] == 2 and f['Area']['3']['EchoTo'] == 0, f['Area'])
check('... and nothing else of the file changed (the passwords, the groups)', f['Sys']['2']['FixPwd'] == 'fixpw2' and f['Sys']['2']['Groups'] == 1 and f['Area']['1']['Tag'] == 'FSX_GEN')

# 2. a wrong password: nothing changes, the answer says so
pkt(2, (1, 110, 200), '+FSX_GEN\n', 'pw2')                  # the Areafix password of system 2 is not its FileFix password
out = toss()
check('a wrong password (system 2 has a FileFix password: the Areafix one does not do): logged, nothing changed', 'FileFix request from 1:110/200: wrong password' in out and fecfg()['Area']['1']['EchoTo'] == 0, out[-300:])
check('... and the answer is a password error', len(answers('1:110/200', 'FileFix: password error')) == 1)

# 3. system 1 has no FileFix password: its Areafix password does; the name FileMgr is the same
pkt(3, (1, 110, 100), '%QUERY\n+FSX_OPEN\n+FSX_GEN\n', 'secret', to='FileMgr')
out = toss()
r1 = answers('1:110/100')
check('a system with no FileFix password uses its Areafix password; FileMgr is FileFix too', 'FileFix request from 1:110/100: 3 command(s)' in out and len(r1) == 1, out[-300:])
check('... it linked FSX_OPEN (bit 1); FSX_GEN is the echo it is the hub of: not available to it', fecfg()['Area']['7']['EchoTo'] == 1 and r1 and '+FSX_OPEN: linked' in r1[0][1] and '+FSX_GEN: not available to you' in r1[0][1], r1)

# 4. an echo that comes from a hub: the first downlink makes us ask the hub (system 2) for it, with the hub's FileFix password as the subject
pkt(4, (1, 110, 100), '+FSX_UP\n', 'secret')
out = toss()
hubreq = [m for m in area4().split('\nmsg ') if 'to=FileFix' in m and 'subj=fixpw2' in m and 'text +FSX_UP|' in m]
check('a file echo with a hub: the first system that takes it makes us ask the hub (system 2): a netmail to FileFix there, the subject is its FileFix password, the text +FSX_UP',
      'file echo FSX_UP is asked for from the hub' in out and len(hubreq) == 1 and 'dest=1:110/200' in hubreq[0], out[-400:])
f = fecfg()
check('... the hub is linked to the echo too (bit 2), and system 1 (bit 1): 3', f['Area']['5']['EchoTo'] == 3, f['Area']['5'])
pkt(5, (1, 110, 100), '-FSX_UP\n', 'secret')
out = toss()
hubstop = [m for m in area4().split('\nmsg ') if 'to=FileFix' in m and 'text -FSX_UP|' in m]
check('the last system leaves the echo (it has no file area: pass-through): the hub is told to stop it (-FSX_UP), and unlinked', 'is no longer needed: the hub' in out and len(hubstop) == 1 and fecfg()['Area']['5']['EchoTo'] == 0, out[-300:])

# 5. a stranger (a request from a system that is not an echo system, passing through system 1): stored for the sysop, not answered
pkt(6, (1, 110, 100), '%LIST\n', 'whatever', msgorig=(5, 5, 5))
out = toss()
check('a FileFix request from a system that is not an echo system: stored for the sysop, said so', 'FileFix request from 5:5/5, which is not a system of ours' in out, out[-300:])

# 6. %HELP says what FileFix does; a command that is not known
pkt(7, (1, 110, 200), '%HELP\n%NONSENSE\n', 'fixpw2')
toss()
t = answers('1:110/200')[-1][1]
check('%HELP: what FileFix does, the tag of a file echo; an unknown % command is said not to be known', 'FileFix: a netmail to FileFix' in t and 'tag of a file echo' in t and '%NONSENSE: not a command that is known' in t, repr(t))

# 7. a bare tag links
pkt(8, (1, 110, 200), 'FSX_GEN\n', 'fixpw2')
toss()
check('a bare tag links the file echo (as in Areafix); FSX_GEN has system 1 as its hub, which is linked and asked for it: 3', fecfg()['Area']['1']['EchoTo'] == 3, fecfg()['Area']['1'])

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
