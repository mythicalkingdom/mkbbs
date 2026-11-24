#!/usr/bin/env python3
"""A file echo, the whole way: a hub (a plain mkbink, 1:110/100) sends a file and its TIC to the BBS (1:110/290, mkbink with mktoss as its
on-inbound command, started as mklisten starts it); the tosser stores the file in the file area (files.bbs, the date), passes it on to
a second system (a plain mkbink, 1:110/200) that the BBS calls, with a TIC of its own; then the BBS hatches a file (mkhatch) that goes to the
second system too.  needs ../mkbink/build/mkbink.   usage: ticroundtrip.py <build dir> <work dir>"""
import json, os, re, shutil, signal, subprocess, sys, time, zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
srcra = os.path.join(repo, 'bbs', 'bbsc', 'ra')
mkbink = os.environ.get('MKBINK', os.path.join(repo, '..', 'mkbink', 'build', 'mkbink'))
if not os.path.isdir(srcra) or not os.path.exists(mkbink):
    print('skip: no sample BBS or no mkbink'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
cfg = tmp + '/r'
inb, outb, unsec = tmp + '/in', tmp + '/out', tmp + '/un'
a_dir, c_dir = work + '/a', work + '/c'
area = tmp + '/fa/'
for d in (inb, outb, unsec, a_dir + '/in', a_dir + '/out', c_dir + '/in', c_dir + '/out', area):
    os.makedirs(d)
shutil.copytree(cfgpatch.snapshot(srcra), cfg, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)
                                                 or f.lower().endswith(('.pwbak', '.old'))])
cfgpatch.fix_sample(cfg)
assert cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
                      lambda s: (cfg + '/').encode() + s[len((srcra + '/').encode()):] if s.startswith((srcra + '/').encode()) else s) >= 1
env = dict(os.environ, MK=cfg, PATH=os.path.dirname(os.path.abspath(mkbink)) + ':' + os.environ['PATH'])
fails = 0
procs = []


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'tic round trip: ' + name + ('' if ok else '  ' + str(info)[:400]))
    if not ok:
        fails += 1


def run(prog, *a, **kw):
    return subprocess.run([os.path.join(build, prog)] + list(a), capture_output=True, text=True, env=env, encoding='latin-1', **kw)


def wait(cond, secs=40):
    end = time.time() + secs
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.2)
    return cond()


PORT_B, PORT_A, PORT_C = 24811, 24812, 24813
check('the BBS is made ready (tosser on, mailer on)', run('tosssetup', inb, outb, unsec, str(PORT_B)).returncode == 0)
cj = work + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
sec = lambda lv, fl=0: {'Level': lv, 'Flags': fl}
dj['files'] = {'1': {'Name': 'Round trip', 'ShortName': 'RT', 'FilePath': area, 'ViewSec': sec(0), 'DLSec': sec(0), 'ULSec': sec(255), 'PFileSec': sec(255), 'Attr': 0, 'Select': ''}}
dj['fileecho']['Area'] = {'1': {'Tag': 'FSX_RT', 'Desc': 'Round trip echo', 'FileArea': 1, 'EchoTo': 2, 'Hub': 1}}      # from system 1 (the hub), to system 2
dj['fileecho']['Sys'] = {'1': {'TicPwd': 'ticA'}, '2': {'TicPwd': 'ticC'}}
mc = dj['mailer']
mc['ScanInterval'] = 1
mc['RetryMin'] = 1
mc['RetryMax'] = 2
mc['Links']['1'].update({'Host': '127.0.0.1', 'Port': PORT_A, 'Password': 'hubpw'})
mc['Links']['2'] = {'Addr': {'Zone': 1, 'Net': 110, 'Node': 200, 'Point': 0}, 'Name': 'Second', 'Host': '127.0.0.1', 'Port': PORT_C, 'Password': 'cpw', 'Flags': 0, 'PollMin': 60,
                    'UseAka': 0, 'ReqSec': sec(0), 'ReqAttr': 0}
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
conf = cfg + '/mkbink.conf'
r = run('mkbinkcfg', '-o', conf)
check('mkbinkcfg: the tosser is the on-inbound command', r.returncode == 0 and ('on-inbound %s' % os.path.join(build, 'mktoss')) in open(conf).read())
blog = open(work + '/b.log', 'wb')
b = subprocess.Popen([mkbink, 'run', '-f', conf], env=env, stdout=blog, stderr=subprocess.STDOUT)
procs.append(b)
check('the mailer of the BBS runs', wait(lambda: b'Mailer running' in open(work + '/b.log', 'rb').read(), 10))

# the second system (1:110/200): a plain mkbink that the BBS calls
open(c_dir + '/c.conf', 'w').write('version 1\naddress 1:110/200\ninbound %s/in\nbso %s/out\nzone 1\nport %d\nbind 127.0.0.1\nscan-interval 1\nretry-min 1\nretry-max 2\n'
                                   'link 1:110/290\n  host 127.0.0.1\n  port %d\n  password cpw\n' % (c_dir, c_dir, PORT_C, PORT_B))
os.chmod(c_dir + '/c.conf', 0o600)
c = subprocess.Popen([mkbink, 'run', '-f', c_dir + '/c.conf'], stdout=open(work + '/c.log', 'wb'), stderr=subprocess.STDOUT)
procs.append(c)
# the hub (1:110/100): sends the file and its TIC to the BBS
open(a_dir + '/a.conf', 'w').write('version 1\naddress 1:110/100\ninbound %s/in\nbso %s/out\nzone 1\nport %d\nbind 127.0.0.1\nscan-interval 1\nretry-min 1\nretry-max 2\n'
                                   'link 1:110/290\n  host 127.0.0.1\n  port %d\n  password hubpw\n' % (a_dir, a_dir, PORT_A, PORT_B))
os.chmod(a_dir + '/a.conf', 0o600)
data = b'The file of the round trip, hatched at the hub. ' * 40
open(a_dir + '/ROUND.ZIP', 'wb').write(data)
crc = zlib.crc32(data) & 0xFFFFFFFF
tic = ('Created by test hub\r\nArea FSX_RT\r\nAreadesc Round trip echo\r\nOrigin 1:110/100\r\nFrom 1:110/100\r\nTo 1:110/290\r\nFile ROUND.ZIP\r\nSize %d\r\nDate 1000000000\r\n'
       'Desc The round trip file\r\nLdesc a line of the long description\r\nCrc %08X\r\nPath 1:110/100 1000000000 Sun Sep 09 01:46:40 2001 UTC hub\r\nSeenby 1:110/100\r\nPw ticA\r\n'
       % (len(data), crc))
open(a_dir + '/ROUND.tic', 'w', newline='').write(tic)
for f in ('ROUND.ZIP', 'ROUND.tic'):
    subprocess.run([mkbink, 'queue', '-O', a_dir + '/out', '-Z', '1', '-t', '1:110/290', a_dir + '/' + f], check=True, capture_output=True)
a = subprocess.Popen([mkbink, 'run', '-f', a_dir + '/a.conf'], stdout=open(work + '/a.log', 'wb'), stderr=subprocess.STDOUT)
procs.append(a)
try:
    check('the BBS tosses the TIC (the on-inbound command): the file is in the area with the date of the TIC',
          wait(lambda: os.path.exists(area + 'ROUND.ZIP'), 60) and open(area + 'ROUND.ZIP', 'rb').read() == data and int(os.path.getmtime(area + 'ROUND.ZIP')) == 1000000000,
          open(work + '/b.log', 'rb').read().decode('latin-1')[-800:])
    lst = open(area + 'files.bbs', encoding='latin-1').read() if os.path.exists(area + 'files.bbs') else ''
    check('files.bbs has its line and the long description', re.search(r'^ROUND\.ZIP +The round trip file\n +a line of the long description\n', lst, re.M), lst)
    check('the inbound of the BBS is clean (the TIC and the file are gone, no badtic)', wait(lambda: not [f for f in os.listdir(inb) if f.upper().startswith('ROUND')], 10) and not os.path.isdir(inb + '/badtic'))
    got, gtic = c_dir + '/in/ROUND.ZIP', c_dir + '/in/'
    check('the BBS passes it on: the file reaches the second system (the BBS called it)', wait(lambda: os.path.exists(got), 60) and open(got, 'rb').read() == data,
          open(work + '/b.log', 'rb').read().decode('latin-1')[-800:])
    tics = lambda: [f for f in os.listdir(c_dir + '/in') if f.lower().endswith('.tic')]
    check('... with a TIC', wait(lambda: len(tics()) >= 1, 30), os.listdir(c_dir + '/in'))
    t = open(c_dir + '/in/' + tics()[0], encoding='latin-1').read() if tics() else ''
    check('the TIC for the second system: from the BBS, to 1:110/200, its password, the old Path line and ours, Seenby, the same CRC and description',
          'From 1:110/290' in t and 'To 1:110/200' in t and 'Pw ticC' in t and 'Path 1:110/100 1000000000' in t and 'Path 1:110/290 ' in t and 'Seenby 1:110/100' in t
          and 'Seenby 1:110/200' in t and ('Crc %08X' % crc) in t and 'Desc The round trip file' in t and 'Ldesc a line of the long description' in t and 'Area FSX_RT' in t, repr(t))
    check('the spool of the BBS is empty again (what was sent was deleted)', wait(lambda: not [d for d in os.listdir(outb + '/mktoss/tic') if os.listdir(outb + '/mktoss/tic/' + d)] if os.path.isdir(outb + '/mktoss/tic') else True, 30))

    # a file hatched at the BBS goes the same way
    hdata = b'hatched at the BBS'
    open(tmp + '/HATCHED.ZIP', 'wb').write(hdata)
    r = subprocess.run([os.path.join(build, 'mkhatch'), '-a', 'FSX_RT', '-d', 'hatched here', '-b', mkbink, tmp + '/HATCHED.ZIP'], capture_output=True, text=True, env=env)
    check('mkhatch: the file is stored and queued for the second system', r.returncode == 0 and os.path.exists(area + 'HATCHED.ZIP') and 'hatched here' in open(area + 'files.bbs').read(), r.stdout + r.stderr)
    check('... and reaches the second system', wait(lambda: os.path.exists(c_dir + '/in/HATCHED.ZIP') and open(c_dir + '/in/HATCHED.ZIP', 'rb').read() == hdata, 60))
    tics2 = [f for f in os.listdir(c_dir + '/in') if f.lower().endswith('.tic') and 'Created by mkhatch' in open(c_dir + '/in/' + f, encoding='latin-1').read()]
    check('... with a TIC made by mkhatch', len(tics2) == 1)
    bl = open(work + '/b.log', 'rb').read().decode('latin-1')
    check('the passwords are not in the log of the mailer', 'ticA' not in bl and 'ticC' not in bl)
finally:
    for p in procs:
        if p.poll() is None:
            p.send_signal(signal.SIGTERM)
    time.sleep(1)
    for p in procs:
        if p.poll() is None:
            p.kill()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
