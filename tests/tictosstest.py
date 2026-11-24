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
mkbink = os.environ.get('MKBINK', os.path.join(repo, '..', 'mkbink', 'build', 'mkbink'))
have_bink = os.path.exists(mkbink)
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
# the paths in config.mk lead to the sample: point them at the copy, or a file that is only in the sample (fileecho.mk, events.mk ...) would be found through them
cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
               lambda p: (cfg + '/').encode() + p[len((srcra + '/').encode()):] if p.startswith((srcra + '/').encode()) else p)
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
fe['Area'] = {'1': {'Tag': 'FSX_GEN', 'Desc': 'General', 'FileArea': 1, 'EchoTo': 2, 'Hub': 1, 'Groups': 0, 'Attr': 1},
              '2': {'Tag': 'FSX_NOCK', 'FileArea': 2, 'EchoTo': 1, 'Hub': 0, 'Attr': 2},
              '3': {'Tag': 'FSX_PASS', 'FileArea': 0, 'EchoTo': 2, 'Hub': 1},
              '6': {'Tag': 'FSX_NOBODY', 'FileArea': 0, 'EchoTo': 1, 'Hub': 1},
              '4': {'Tag': 'FSX_FROM2', 'FileArea': 1, 'EchoTo': 0, 'Hub': 2},
              '5': {'Tag': 'FSX_BADAREA', 'FileArea': 77, 'EchoTo': 1, 'Hub': 1}}
fe['Sys'] = {'1': {'TicPwd': 'tic1'}, '2': {'TicPwd': 'pw2tic'}}
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
    r = run('mktoss', '-t', '-f', '-b', mkbink) if have_bink else run('mktoss', '-t', '-f')
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

# 8. passing on: needs the real mkbink (mkbink queue)
def flo():
    """the entries of the BSO outbound of the systems: {file name: [lines]}"""
    r = {}
    for root, dirs, files in os.walk(outb):
        for f in files:
            if f.lower().endswith('lo'):
                r[f] = open(os.path.join(root, f), encoding='latin-1').read().split()
    return r


def new_entries(before, after):
    return {f: [x for x in v if x not in before.get(f, [])] for f, v in after.items() if [x for x in v if x not in before.get(f, [])]}


spool = outb + '/mktoss/tic/'
if have_bink:
    before = flo()
    data = b'a file to be passed on'
    tic('FWD.ZIP', data, extra='Seenby 1:110/55\r\n')
    out = toss()
    nw = new_entries(before, flo())
    ent = [x for v in nw.values() for x in v]
    check('a file of an echo that goes to system 2: tossed, passed on to 1:110/200, said so', 'tossed FWD.ZIP' in out and 'passed on to 1:110/200' in out, out[-400:])
    paths = [x.lstrip('^#') for x in ent]
    fpath = [p for p in paths if p.endswith('FWD.ZIP')]
    tpath = [p for p in paths if p.endswith('.tic')]
    check('the mailer got the file first and then the TIC, both to be deleted after they were sent (^)', len(ent) == 2 and ent[0].startswith('^') and ent[0].endswith('FWD.ZIP') and ent[1].startswith('^') and ent[1].endswith('.tic'), ent)
    check('... and the file in the spool is a hard link of the file in the area (one copy on the disk)',
          fpath and os.path.exists(fpath[0]) and os.stat(fpath[0]).st_ino == os.stat(area1 + 'FWD.ZIP').st_ino and os.stat(area1 + 'FWD.ZIP').st_nlink == 2)
    t = open(tpath[0], encoding='latin-1').read() if tpath and os.path.exists(tpath[0]) else ''
    check('the TIC for system 2: from us (1:110/290), to 1:110/200, its password, the file, size, CRC, the description',
          'From 1:110/290' in t and 'To 1:110/200' in t and 'Pw pw2tic' in t and 'File FWD.ZIP' in t and ('Size %d' % len(data)) in t and ('Crc %08X' % (zlib.crc32(data) & 0xFFFFFFFF)) in t and 'Desc A file' in t, t)
    check('... Origin kept, our Path line after the one that was there, Seenby for the ones that had it, for us and for system 2',
          'Origin 1:110/100' in t and re.search(r'Path 1:110/100 .*\nPath 1:110/290 \d+ \w{3} \w{3} \d\d \d\d:\d\d:\d\d \d{4} UTC mktoss', t)
          and 'Seenby 1:110/100' in t and 'Seenby 1:110/55' in t and 'Seenby 1:110/290' in t and 'Seenby 1:110/200' in t, repr(t))
    # a system in the Seenby lines does not get it again
    before = flo()
    tic('SEEN.ZIP', b'seen by system 2', extra='Seenby 1:110/200\r\n')
    out = toss()
    check('a system that is in the Seenby lines is not sent the file again', 'tossed SEEN.ZIP' in out and not new_entries(before, flo()) and 'passed on to' not in out, out[-300:])
    # pass-through: no copy in the area, passed on, the inbound is clean
    before = flo()
    t = tic('PASS.ZIP', b'pass me on', area='FSX_PASS')
    out = toss()
    nw = new_entries(before, flo())
    check('a pass-through echo: passed on to system 2, no copy kept (not in any area), gone from the inbound', 'passed through PASS.ZIP' in out and 'passed on to 1:110/200' in out
          and sum(len(v) for v in nw.values()) == 2 and not os.path.exists(inb + '/PASS.ZIP') and not os.path.exists(inb + '/' + t)
          and not os.path.exists(area1 + 'PASS.ZIP') and not os.path.exists(area2 + 'PASS.ZIP'), (nw, flo()))
    check('... the file waits in the spool for the mailer', any(os.path.exists(x.lstrip('^#')) for v in nw.values() for x in v if x.endswith('PASS.ZIP')))
    # nobody to pass it to
    t = tic('NOBODY.ZIP', b'nowhere to go', area='FSX_NOBODY')
    before = flo()
    out = toss()
    check('a pass-through echo that goes only to the system it came from: dropped, said so, the inbound is clean', 'no system to pass it on to, dropped' in out and not new_entries(before, flo())
          and not os.path.exists(inb + '/NOBODY.ZIP') and not os.path.exists(inb + '/' + t), out[-300:])
    check('the summary counts what was passed on and through', re.search(r'\d+ tic passed on, \d+ passed through, \d+ dropped', out) is not None, out[-300:])
    # the spool: files that wait too long, and the limit in MB
    now = int(time.time())
    for name, age, size in (('02-%d-901' % (now - 20 * 86400), 'OLD.BIN', 10), ('02-%d-902' % (now - 100), 'MID.BIN', 700 * 1024), ('02-%d-903' % (now - 50), 'NEW.BIN', 700 * 1024)):
        pass
    os.makedirs(spool + '02-%d-901' % (now - 20 * 86400), exist_ok=True)
    open(spool + '02-%d-901/OLD.BIN' % (now - 20 * 86400), 'wb').write(b'x' * 10)
    os.makedirs(spool + '02-%d-902' % (now - 100), exist_ok=True)
    open(spool + '02-%d-902/MID.BIN' % (now - 100), 'wb').write(b'x' * 700 * 1024)
    os.makedirs(spool + '02-%d-903' % (now - 50), exist_ok=True)
    open(spool + '02-%d-903/NEW.BIN' % (now - 50), 'wb').write(b'x' * 700 * 1024)
    os.makedirs(spool + '02-%d-904' % (now - 10), exist_ok=True)         # nothing in it: its files were sent
    out = toss()
    check('the spool: a directory that waited more than 14 days (PassDays) is dropped, an empty one goes', 'waited more than 14 days: dropped' in out and not os.path.exists(spool + '02-%d-901' % (now - 20 * 86400))
          and not os.path.exists(spool + '02-%d-904' % (now - 10)), out[-300:])
    d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8')); d['fileecho']['PassMaxMB'] = 1
    json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
    subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True, input='', text=True)
    out = toss()
    check('the spool over its limit (PassMaxMB 1): the oldest directory goes first, the newer stays',
          'spool over 1 MB' in out and not os.path.exists(spool + '02-%d-902' % (now - 100)) and os.path.exists(spool + '02-%d-903/NEW.BIN' % (now - 50)), out[-300:])
    # ---- mkhatch: a file of ours into an echo
    srcd = tmp + '/hatch/'
    os.makedirs(srcd)

    def hatch(*args):
        return subprocess.run([os.path.join(build, 'mkhatch')] + list(args) + ['-b', mkbink], capture_output=True, text=True, env=env, encoding='latin-1')

    open(srcd + 'HATCH.ZIP', 'wb').write(b'a hatched file')
    os.utime(srcd + 'HATCH.ZIP', (1100000000, 1100000000))
    before = flo()
    r = hatch('-a', 'fsx_gen', '-d', 'hatched here', '-l', 'long one', '-l', 'long two', '-r', 'KEEPNOT*.ZIP', '-m', 'HATCHME', srcd + 'HATCH.ZIP')
    ent = [x for v in new_entries(before, flo()).values() for x in v]
    check('mkhatch: exit 0, says how many systems get the file (the echo is found whatever the case of its tag)', r.returncode == 0 and '1 system(s) get it' in r.stdout, r.stdout + r.stderr)
    check('the file is copied into the area (the source stays), with the date of the source, and listed with its descriptions',
          open(area1 + 'HATCH.ZIP', 'rb').read() == b'a hatched file' and os.path.exists(srcd + 'HATCH.ZIP') and int(os.path.getmtime(area1 + 'HATCH.ZIP')) == 1100000000
          and re.search(r'^HATCH\.ZIP +hatched here\n +long one\n +long two\n', lst(area1), re.M), lst(area1))
    tp = [x.lstrip('^#') for x in ent if x.endswith('.tic')]
    t = open(tp[0], encoding='latin-1').read() if tp and os.path.exists(tp[0]) else ''
    check('a TIC and the file are queued for system 2, the file first', len(ent) == 2 and ent[0].endswith('HATCH.ZIP') and ent[1].endswith('.tic'), ent)
    check('the TIC: Created by mkhatch, our address as Origin and From, To system 2, the Desc and Ldesc lines, Replaces, Magic, size, CRC, date of the file',
          'Created by mkhatch' in t and 'Origin 1:110/290' in t and 'From 1:110/290' in t and 'To 1:110/200' in t and 'Desc hatched here' in t and 'Ldesc long one' in t and 'Ldesc long two' in t
          and 'Replaces KEEPNOT*.ZIP' in t and 'Magic HATCHME' in t and 'Size 14' in t and ('Crc %08X' % (zlib.crc32(b'a hatched file') & 0xFFFFFFFF)) in t and 'Date 1100000000' in t, repr(t))
    check('... Path with only our line, Seenby us and system 2, the password of system 2',
          len(re.findall(r'^Path ', t, re.M)) == 1 and 'Path 1:110/290 ' in t and 'Seenby 1:110/290' in t and 'Seenby 1:110/200' in t and 'Pw pw2tic' in t, repr(t))
    # the same name again: the old file and its line are replaced, -x moves the file
    open(srcd + 'HATCH.ZIP', 'wb').write(b'the second version of the hatched file')
    r = hatch('-a', 'FSX_GEN', '-x', '-q', '-d', 'second version', srcd + 'HATCH.ZIP')
    check('hatching a file with a name that is there: replaced, one line in files.bbs with the new description, -x moved the source',
          r.returncode == 0 and r.stdout == '' and open(area1 + 'HATCH.ZIP', 'rb').read() == b'the second version of the hatched file' and lst(area1).count('HATCH.ZIP') == 1
          and 'hatched here' not in lst(area1) and not os.path.exists(srcd + 'HATCH.ZIP'), (r.returncode, r.stdout, r.stderr, lst(area1)))
    # a file that is already in the area is only listed and passed on
    r = hatch('-a', 'FSX_GEN', '-d', 'already there', area1 + 'KEEP.ZIP')
    check('a file that is already in the area: no copy of itself, listed again with the new description', r.returncode == 0 and os.path.exists(area1 + 'KEEP.ZIP') and lst(area1).count('KEEP.ZIP') == 1 and 'already there' in lst(area1), lst(area1) + r.stderr)
    # a pass-through echo: not stored, -x deletes the source after it was queued
    open(srcd + 'THRU.ZIP', 'wb').write(b'through')
    before = flo()
    r = hatch('-a', 'FSX_PASS', '-x', srcd + 'THRU.ZIP')
    nw = new_entries(before, flo())
    check('a pass-through echo: queued for system 2, not stored in any area, the source (-x) is deleted',
          r.returncode == 0 and 'pass-through echo' in r.stdout and sum(len(v) for v in nw.values()) == 2 and not os.path.exists(area1 + 'THRU.ZIP') and not os.path.exists(srcd + 'THRU.ZIP')
          and any(os.path.exists(x.lstrip('^#')) for v in nw.values() for x in v if x.endswith('THRU.ZIP')), r.stdout + r.stderr)
    # errors
    r = hatch('-a', 'NO_SUCH_ECHO', srcd + 'x')
    check('an echo that is not ours: exit 2, said so', r.returncode == 2 and 'is not one of ours' in r.stderr, r.stderr)
    r = hatch('-a', 'FSX_GEN', srcd + 'nothere.zip')
    check('a file that is not there: exit 2', r.returncode == 2 and 'is not there' in r.stderr, r.stderr)
    r = subprocess.run([os.path.join(build, 'mkhatch')], capture_output=True, text=True, env=env)
    check('no echo and no file: the usage, exit 1', r.returncode == 1 and 'Usage: mkhatch' in r.stderr)
    r = hatch('-a', 'FSX_BADAREA', srcd + 'x')
    check('an echo whose file area is not defined: exit 2, said so', r.returncode == 2, r.stderr)
else:
    print('skip: no mkbink, passing on is not checked')

# 9. a TIC that is not a TIC
open(inb + '/junk.tic', 'w').write('this is not a tic file\n')
out = toss()
check('a file with the name of a TIC and nothing in it: bad (no File line)', 'no File line' in out and os.path.exists(inb + '/badtic/junk.tic'), out)

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
