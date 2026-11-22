#!/usr/bin/env python3
"""Tossing TIC files (mktoss, MKTicToss): the file goes to the file area of the echo with a line in files.bbs and its date; what is wrong goes
to badtic/ with the reason in the log; duplicates, a changed file of the same name, Replaces, the check command, a TIC that waits for its
file, pass-through.  Private copy of the sample BBS.   usage: tictosstest.py <build dir> <work dir>"""
import json, os, re, shutil, subprocess, sys, time, zlib
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
shutil.copytree(srcra, cfg, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(cfg)
env = dict(os.environ, MK=cfg)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'tic toss: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


def run(prog, *a):
    return subprocess.run([os.path.join(build, prog)] + list(a), capture_output=True, text=True, env=env, encoding='latin-1')


run('tosssetup', inb, outb, unsec)
# ---- the configuration: file areas 1 (FSX_GEN: hub = system 1, replaces allowed) and 2 (FSX_NOCK: no check command), pass-through echo,
#      an echo that comes from system 2 only; system 1 has the TIC password "tic1", system 2 none
area1, area2 = tmp + '/fa1/', tmp + '/fa2/'
os.makedirs(area1); os.makedirs(area2)
cj = tmp + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True, input='', text=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
sec = lambda lv: {'Level': lv, 'Flags': 0}
dj['files'] = {str(n): {'Name': 'Area %d' % n, 'ShortName': 'A%d' % n, 'FilePath': p, 'ViewSec': sec(0), 'DLSec': sec(0), 'ULSec': sec(255), 'PFileSec': sec(255), 'Attr': 0, 'Select': ''}
               for n, p in ((1, area1), (2, area2))}
fe = dj['fileecho']
fe['Area'] = {'1': {'Tag': 'FSX_GEN', 'Desc': 'General', 'FileArea': 1, 'EchoTo': 0, 'Hub': 1, 'Groups': 0, 'Attr': 1},
              '2': {'Tag': 'FSX_NOCK', 'FileArea': 2, 'EchoTo': 1, 'Hub': 0, 'Attr': 2},
              '3': {'Tag': 'FSX_PASS', 'FileArea': 0, 'EchoTo': 1, 'Hub': 1},
              '4': {'Tag': 'FSX_FROM2', 'FileArea': 1, 'EchoTo': 0, 'Hub': 2},
              '5': {'Tag': 'FSX_BADAREA', 'FileArea': 77, 'EchoTo': 1, 'Hub': 1}}
fe['Sys'] = {'1': {'TicPwd': 'tic1'}}
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True, input='', text=True)
# the mailer settings: the tosser on
mk = cfg + '/mailer.mk'
if os.path.exists(mk):
    f = bytearray(open(mk, 'rb').read()); f[2] |= 128; open(mk, 'wb').write(f)


def setcheck(cmd):
    d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
    d['fileecho']['CheckCmd'] = cmd
    json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
    subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True, input='', text=True)


def tic(name, data, area='FSX_GEN', frm='1:110/100', pw='tic1', crc=None, size=None, extra='', fname=None, desc='A file', ldesc=('long one', 'long two'), date=1000000000, write_file=True):
    """a file and its TIC in the inbound"""
    fname = fname or name
    if write_file:
        open(os.path.join(inb, name if fname == name else fname), 'wb').write(data)
    c = zlib.crc32(data) & 0xFFFFFFFF if crc is None else crc
    t = 'Area %s\r\nOrigin 1:110/100\r\nFrom %s\r\nTo 1:110/290\r\nFile %s\r\nSize %d\r\nDate %d\r\nDesc %s\r\n' % (area, frm, fname, len(data) if size is None else size, date, desc)
    for l in ldesc:
        t += 'Ldesc %s\r\n' % l
    t += 'Crc %08X\r\nPath 1:110/100 %d x UTC test\r\n%sSeenby 1:110/100\r\nPw %s\r\n' % (c, date, extra, pw)
    ticname = os.path.splitext(name)[0] + '.tic'
    open(os.path.join(inb, ticname), 'w', newline='').write(t)
    return ticname


def toss():
    r = run('mktoss', '-t', '-f')
    return r.stdout


def lst(area):
    p = area + 'files.bbs'
    return open(p, encoding='latin-1').read() if os.path.exists(p) else ''


setcheck('')
# 1. a good one: the case of the name is that of the TIC (the file in the inbound is in lower case)
data = b'first version of the file'
open(os.path.join(inb, 'sample.zip'), 'wb').write(data)
tic('SAMPLE.ZIP', data, write_file=False)
out = toss()
check('a good TIC: tossed, said so with the area and the size', 'tossed SAMPLE.ZIP (%d bytes) into file area 1 from FSX_GEN' % len(data) in out, out)
check('the file is in the area under the name of the TIC (SAMPLE.ZIP), not the case it came in', os.path.exists(area1 + 'SAMPLE.ZIP') and not os.path.exists(area1 + 'sample.zip')
      and open(area1 + 'SAMPLE.ZIP', 'rb').read() == data)
check('... with the date of the TIC (1000000000)', int(os.path.getmtime(area1 + 'SAMPLE.ZIP')) == 1000000000)
check('files.bbs has its line (name, description) and the long description under it', re.search(r'^SAMPLE\.ZIP +A file\n +long one\n +long two\n', lst(area1), re.M), lst(area1))
check('the TIC and the file are gone from the inbound; a duplicate list was made', not [f for f in os.listdir(inb) if f.lower() in ('sample.zip', 'sample.tic')] and os.path.exists(inb + '/ticdupe.dat'))
check('the summary says 1 tic tossed', '1 tic tossed, 0 bad tic' in out, out[-300:])

# 2. the same file again: a duplicate (same echo, name, CRC)
tic('SAMPLE.ZIP', data)
out = toss()
check('the same TIC and file again: a duplicate, removed, not stored twice', 'was tossed before: a duplicate' in out and lst(area1).count('SAMPLE.ZIP') == 1
      and not os.path.exists(inb + '/SAMPLE.ZIP') and not os.path.exists(inb + '/SAMPLE.tic'), out)

# 3. the same name, another CRC: a new file, it replaces the old one (and its line)
data2 = b'second version, longer than the first'
tic('SAMPLE.ZIP', data2, desc='A file, version 2', ldesc=())
out = toss()
check('the same name with another CRC is a new file: tossed, the old one said to be replaced', 'was there: replaced by the new one' in out and 'tossed SAMPLE.ZIP' in out, out)
check('... the area has the new content and one line (the new description) for it',
      open(area1 + 'SAMPLE.ZIP', 'rb').read() == data2 and lst(area1).count('SAMPLE.ZIP') == 1 and 'version 2' in lst(area1) and 'long one' not in lst(area1), lst(area1))

# 4. Replaces with a wildcard (the echo allows it): the old files and their lines go
for n in ('OLD1.ZIP', 'OLD2.ZIP', 'KEEP.ZIP'):
    open(area1 + n, 'wb').write(b'x')
open(area1 + 'files.bbs', 'a').write('OLD1.ZIP      old one\n              its long description\nOLD2.ZIP      old two\nKEEP.ZIP      stays\n')
tic('NEW.ZIP', b'brand new', extra='Replaces OLD*.ZIP\r\n', desc='the new one', ldesc=())
out = toss()
check('Replaces OLD*.ZIP: the matching files are gone, the others stay', not os.path.exists(area1 + 'OLD1.ZIP') and not os.path.exists(area1 + 'OLD2.ZIP')
      and os.path.exists(area1 + 'KEEP.ZIP') and os.path.exists(area1 + 'NEW.ZIP'), out)
check('... and so are their lines in files.bbs, with the long description; KEEP and the new one are listed',
      'OLD1' not in lst(area1) and 'OLD2' not in lst(area1) and 'its long description' not in lst(area1) and 'KEEP.ZIP' in lst(area1) and 'NEW.ZIP' in lst(area1), lst(area1))

# 5. what is wrong goes to badtic/ with the reason
def bad(label, why, **kw):
    n = kw.pop('name')
    t = tic(n, kw.pop('data', b'data of ' + n.encode()), **kw)
    out = toss()
    ok = why in out and os.path.exists(inb + '/badtic/' + t) and not os.path.exists(inb + '/' + t) and not os.path.exists(area1 + n) and not os.path.exists(area2 + n)
    check(label, ok, out[-300:])


bad('a wrong password: bad, said so', 'wrong password from 1:110/100', name='BADPW.ZIP', pw='nope')
bad('a system that is not an echo system: bad', 'that is not one of the echo systems', name='STRANGER.ZIP', frm='9:9/9')
bad('an echo that is not ours: bad', 'is not one of ours', name='NOECHO.ZIP', area='NO_SUCH_ECHO')
bad('an echo the sender may not send (system 2 is its hub, not system 1): bad', 'may not send FSX_FROM2', name='NOTHUB.ZIP', area='FSX_FROM2')
bad('a wrong CRC: bad, both CRCs in the log', 'the CRC is', name='BADCRC.ZIP', crc=0x12345678)
bad('a wrong size: bad', 'the size is', name='BADSIZE.ZIP', size=5)
bad('our own address in the Path (a loop): bad', 'a loop', name='LOOP.ZIP', extra='Path 1:110/290 1000000001 x UTC us\r\n')
bad('a file area that there is not: bad', 'file area 77, which is not defined', name='NOAREA.ZIP', area='FSX_BADAREA')

# 6. the check command: not 0 refuses, 0 accepts, the echo can skip it
setcheck('test -s %F')
tic('CHK_OK.ZIP', b'not empty')
out = toss()
check('the check command (test -s %F) accepts a file that is not empty', 'tossed CHK_OK.ZIP' in out and os.path.exists(area1 + 'CHK_OK.ZIP'), out)
setcheck('false %F %T')
bad('a check command that refuses: bad, with its status', 'refused by the check command (status 1)', name='CHK_NO.ZIP')
tic('NOCHECK.ZIP', b'never checked', area='FSX_NOCK')
out = toss()
check('an echo with "No check command" is not checked: tossed into its own area', 'tossed NOCHECK.ZIP' in out and os.path.exists(area2 + 'NOCHECK.ZIP'), out)
setcheck("sleep 5 && true %F")
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8')); d['fileecho']['CheckTimeout'] = 1
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True, input='', text=True)
bad('a check that takes longer than its time limit: refused (status 124)', 'refused by the check command (status 124)', name='SLOW.ZIP')
setcheck('')

# 7. a TIC whose file has not come: waits, then is bad after a day
t = tic('LATE.ZIP', b'late', write_file=False)
out = toss()
check('a TIC whose file has not come yet waits in the inbound, said so', 'has not come yet, waiting' in out and os.path.exists(inb + '/' + t), out)
old = time.time() - 2 * 86400
os.utime(inb + '/' + t, (old, old))
out = toss()
check('after a day it is bad: its file did not come', 'did not come' in out and os.path.exists(inb + '/badtic/' + t) and not os.path.exists(inb + '/' + t), out)
open(inb + '/LATE.ZIP', 'wb').write(b'late')

# 8. a pass-through echo is left alone for now
t = tic('PASS.ZIP', b'pass me on', area='FSX_PASS')
out = toss()
check('a pass-through echo: left in the inbound (passing on is the next step), said so', 'pass-through echo FSX_PASS is left in the inbound' in out and os.path.exists(inb + '/' + t)
      and os.path.exists(inb + '/PASS.ZIP'), out)
check('... and counted as waiting in the summary', re.search(r'tic waiting', out) is not None and re.search(r'[1-9]\d* tic waiting', out), out[-300:])

# 9. a TIC that is not a TIC
open(inb + '/junk.tic', 'w').write('this is not a tic file\n')
out = toss()
check('a file with the name of a TIC and nothing in it: bad (no File line)', 'no File line' in out and os.path.exists(inb + '/badtic/junk.tic'), out)

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
