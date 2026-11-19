#!/usr/bin/env python3
"""The client session (MKComClient) against the real thing: mklisten with a "qwk" port starts mk -Q; clientxfer logs in
(Login:, Password:, QWK:), downloads the packet and uploads a reply packet with the Zmodem of MKProt through the Telnet
client session.  Private copy of the sample BBS.  usage: clientxfertest.py <build dir> <work dir>"""
import json, os, shutil, subprocess, sys, time, zipfile

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src) or not shutil.which('zip') or not shutil.which('unzip') or not os.path.exists(build + '/clientxfer'):
    print('skip: no sample BBS (or no zip/unzip)'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'client transfer: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(src, ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
env = dict(os.environ, MK=ra)
cj = os.path.join(work, 'cj'); os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
dj['config']['ExtPack'][1]['PCmdLine'] = 'zip -q -j'
dj['config']['ExtPack'][1]['UCmdLine'] = 'unzip -o -q'
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
board = 'MythKing'
for t in (['tosssetup', tmp + '/in', tmp + '/outb', tmp + '/un'], ['tossmake']):
    if t[0] == 'tossmake':
        os.makedirs(tmp + '/in', exist_ok=True)
    subprocess.run([build + '/' + t[0]] + t[1:], env=env, capture_output=True, text=True)
# the node: Mark May, password NODEPW, protocol Z (the internal Zmodem)
r = subprocess.run([build + '/netsetup', 'Mark May', '6'], env=dict(env, NETPWD='NODEPW', NETPROT='Z'), capture_output=True, text=True)
check('the node user is set up', 'ok' in r.stdout)
subprocess.run([build + '/qwkmsgtest', 'reply', ra + '/reply.msg', '6', board, ' via client'], check=True, capture_output=True)
xfer = work + '/x'
os.makedirs(xfer)
with zipfile.ZipFile(xfer + '/up.rep', 'w') as z:
    z.write(ra + '/reply.msg', board.upper() + '.MSG')


def dump(n):
    return subprocess.run([build + '/tossdump', str(n)], env=env, capture_output=True, text=True, encoding='latin-1').stdout


before = dump(6)
port = 24690 + os.getpid() % 200
cfg = {'mk': build + '/mk', 'rundir': work + '/run', 'logfile': work + '/listen.log', 'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': port, 'type': 'qwk', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(work + '/listen.json', 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)
time.sleep(1)
try:
    p = subprocess.run([build + '/clientxfer', '127.0.0.1', str(port), 'Mark May', 'nodepw', xfer], capture_output=True, text=True, timeout=120)
    out = p.stdout
finally:
    lst.terminate()
    lst.wait()
check('it logs in (Login:, Password:, QWK:)', 'logged in' in out, out)
check('Zmodem download through the client session', 'download ok' in out, out)
qs = [f for f in os.listdir(xfer) if f.lower().endswith('.qwk')]
d = xfer + '/' + qs[0] if qs else xfer + '/none'
names = []
if os.path.exists(d):
    try:
        names = [n.lower() for n in zipfile.ZipFile(d).namelist()]
    except zipfile.BadZipFile:
        pass
check('... the packet arrives under the name the sender gave (<boardid>.qwk), a ZIP with messages.dat', 'messages.dat' in names and qs == [board.lower() + '.qwk'], (os.listdir(xfer), names))
check('Zmodem upload through the client session', 'upload ok' in out, out)
check('... the reply packet was posted', dump(6) != before)
check('the call ends cleanly', 'done' in out, out)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
