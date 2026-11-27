#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""A file request, the whole way in: a mkbink asks the mkbink of a BBS (settings made by mkbinkcfg, started like mklisten does it) for
files, with a password; mkbink hands the .req to mkfreq (on-freq), the the files go in a second batch of the same session,
what could not be sent is told in a netmail (hold mail: the asker picks it up with a call) (Tell by netmail: mkfreq's note, posted and sent by mktoss).
needs ../mkbink/build/mkbink.   usage: freqroundtrip.py <build dir> <work dir>"""
import json, os, shutil, signal, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
srcra = os.path.join(repo, 'bbs', 'bbsc', 'ra')
mkbink = os.environ.get('MKBINK', os.path.join(repo, '..', 'mkbink', 'build', 'mkbink'))
if not os.path.isdir(srcra) or not os.path.exists(mkbink) or not os.path.exists(build + '/mkfreq'):
    print('skip: no sample BBS, no mkbink or no mkfreq'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
cfg = tmp + '/r'
inb, outb, unsec = tmp + '/in', tmp + '/out', tmp + '/un'
a_dir = work + '/a'
for d in (inb, outb, unsec, a_dir + '/in', a_dir + '/out', tmp + '/files'):
    os.makedirs(d)
shutil.copytree(cfgpatch.snapshot(srcra), cfg, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)
                                                 or f.lower().endswith(('.pwbak', '.old'))])
cfgpatch.fix_sample(cfg)
assert cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
                      lambda s: (cfg + '/').encode() + s[len((srcra + '/').encode()):] if s.startswith((srcra + '/').encode()) else s) >= 1
env = dict(os.environ, MK=cfg)
fails = 0
procs = []


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'freq: ' + name)
    if not ok:
        fails += 1


def run(prog, *a, **kw):
    return subprocess.run([os.path.join(build, prog)] + list(a), capture_output=True, text=True, env=env, encoding='latin-1', **kw)


def wait(cond, secs=30):
    end = time.time() + secs
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.2)
    return cond()


PORT_B, PORT_A = 24891, 24892
check('the BBS is made ready (tosser on, mailer on)', run('tosssetup', inb, outb, unsec, str(PORT_B)).returncode == 0)

# the files and the settings of file requests (through the JSON form, as other tests do)
open(tmp + '/files/this.arc', 'wb').write(b'THIS ARC DATA')
open(tmp + '/files/other.zip', 'wb').write(b'OTHER')
cj = work + '/cj'
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
sec = lambda lv, fl=0: {'Level': lv, 'Flags': fl}
dj['files']['201'] = {'Name': 'Requests', 'ShortName': 'Req', 'FilePath': tmp + '/files/', 'ViewSec': sec(10), 'DLSec': sec(10), 'ULSec': sec(255),
                      'PFileSec': sec(255), 'Attr': 32, 'Select': ''}
mc = dj['mailer']
mc['Flags'] |= 64
mc['ReqAttr'] = 2
mc['ReqMaxFiles'] = 5
l1 = mc['Links']['1']
l1['Flags'] = 0                                    # not answer only: the BBS calls the system that asked, to bring the files
l1['Host'] = '127.0.0.1'
l1['Port'] = PORT_A
l1['ReqSec'] = sec(100)
mc['ReqMagicFile'] = 'magic.txt'
open(cfg + '/magic.txt', 'w').write('SECRETS %s/files/other.zip pw1\n' % tmp)
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)

conf = cfg + '/mkbink.conf'
r = run('mkbinkcfg', '-o', conf)
settings = open(conf).read() if os.path.exists(conf) else ''
check('mkbinkcfg writes freq yes, on-freq = mkfreq and the limit', r.returncode == 0 and 'freq yes' in settings
      and ('on-freq %s' % os.path.join(build, 'mkfreq')) in settings and 'freq-max-files 5' in settings)

blog = open(work + '/b.log', 'wb')
b = subprocess.Popen([mkbink, 'run', '-f', conf], env=env, stdout=blog, stderr=subprocess.STDOUT)
procs.append(b)
check('the mailer of the BBS runs', wait(lambda: b'Mailer running' in open(work + '/b.log', 'rb').read(), 10))

# the asker: a mkbink (1:110/100) that can be called by the BBS and calls it for its request
open(a_dir + '/a.conf', 'w').write('version 1\naddress 1:110/100\ninbound %s/in\nbso %s/out\nzone 1\nport %d\nbind 127.0.0.1\n'
                                   'scan-interval 1\nretry-min 1\nretry-max 2\nlink 1:110/290\n  host 127.0.0.1\n  port %d\n  password hubpw\n'
                                   % (a_dir, a_dir, PORT_A, PORT_B))
os.chmod(a_dir + '/a.conf', 0o600)
r = subprocess.run([mkbink, 'queue', '-O', a_dir + '/out', '-Z', '1', '-t', '1:110/290', '-R', 'this.arc', '!whtvr', '+1', 'SECRETS', '!pw1', 'nothere.zip'],
                   capture_output=True, text=True)
check('the asker queues its request (a password for a file that needs none, one for a magic name, a file that is not there)', r.returncode == 0)
alog = open(work + '/a.log', 'wb')
a = subprocess.Popen([mkbink, 'run', '-f', a_dir + '/a.conf'], stdout=alog, stderr=subprocess.STDOUT)
procs.append(a)
try:
    got = a_dir + '/in/this.arc'
    check('the request is answered: mkfreq ran and the files were queued', wait(lambda: b'2 file(s) queued' in open(work + '/b.log', 'rb').read(), 60))
    check('the files come to the asker in the next batch of the same session (both mailers offered multiple batches), without a second call',
          wait(lambda: os.path.exists(got) and os.path.exists(a_dir + '/in/other.zip'), 60)
          and open(got, 'rb').read() == b'THIS ARC DATA' and open(a_dir + '/in/other.zip', 'rb').read() == b'OTHER'
          and b'starting batch 2' in open(work + '/b.log', 'rb').read())
    bl = open(work + '/b.log', 'rb').read().decode('latin-1')
    check('the BBS log: the request came from 1:110/100 (secure), mkfreq answered it, the files were queued',
          'File request from 1:110/100' in bl and 'mkfreq: 1:110/100 (secure, level 100)' in bl and '2 file(s) queued' in bl)
    check('the passwords are not in the log', 'whtvr' not in bl and 'pw1' not in bl)
    check('the request file is not left in the inbound of the BBS', not [f for f in os.listdir(inb) if f.endswith(('.req', '.ans'))])

    # the netmail that says what was not sent: mkfreq's note, posted and sent by mktoss as hold mail.  The request file was answered
    # at the end of a batch and is not given to the on-inbound command, so the tosser is run here (as mklisten's scan does)
    check('mkfreq wrote a note (a file was not found)', 'a note for the requester is written' in bl)
    r = run('mktoss', '-s', '-f', '-b', mkbink)
    check('mktoss posts it as a netmail to the asker (hold mail) and the note is gone from the spool',
          'file request note for 1:110/100 posted as a netmail' in r.stdout
          and (not os.path.isdir(outb + '/mktoss/freq') or not os.listdir(outb + '/mktoss/freq')))
    open(a_dir + '/ping.txt', 'w').write('ping')
    subprocess.run([mkbink, 'queue', '-O', a_dir + '/out', '-Z', '1', '-t', '1:110/290', '-x', a_dir + '/ping.txt'], check=True, capture_output=True)

    def packet_text():
        for f in os.listdir(a_dir + '/in'):
            p = a_dir + '/in/' + f
            if f.endswith('.pkt') or f[-3:-1] in ('su', 'mo', 'tu', 'we', 'th', 'fr', 'sa'):
                d = open(p, 'rb').read()
                if d[:2] == b'PK':
                    d = subprocess.run(['unzip', '-p', p], capture_output=True).stdout
                return d
        return b''
    check('the netmail reaches the asker and says what was not sent', wait(lambda: b'nothere.zip: not found' in packet_text(), 40))
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
