#!/usr/bin/env python3
"""The whole way in: a mkbink calls the mkbink of the BBS (started as mklisten starts it, MK in its environment), the
packet arrives in the inbound, the command mkbinkcfg wrote (on-inbound = mktoss) tosses it into the area.
needs ../mkbink/build/mkbink.   usage: tosshooktest.py <build dir> <work dir>"""
import os, shutil, signal, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
srcra = os.path.join(repo, 'bbs', 'bbsc', 'ra')
mkbink = os.environ.get('MKBINK', os.path.join(repo, '..', 'mkbink', 'build', 'mkbink'))
if not os.path.isdir(srcra) or not os.path.exists(mkbink) or subprocess.run(['node', '--version'], capture_output=True).returncode != 0:
    print('skip: no sample BBS, no node or no mkbink'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
cfg = tmp + '/r'
inb, outb, unsec = tmp + '/in', tmp + '/out', tmp + '/un'
a_dir = work + '/a'
for d in (inb, outb, unsec, a_dir + '/in', a_dir + '/out'):
    os.makedirs(d)
shutil.copytree(srcra, cfg, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(cfg)
assert cfgpatch.patch(os.path.join(cfg, 'config.mk'), (repo + '/bbs/').encode(),
                      lambda s: (cfg + '/').encode() + s[len((srcra + '/').encode()):] if s.startswith((srcra + '/').encode()) else s) >= 1
env = dict(os.environ, MK=cfg)
fails = 0
procs = []


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'hook: ' + name)
    if not ok:
        fails += 1


def run(prog, *a, **kw):
    return subprocess.run([os.path.join(build, prog)] + list(a), capture_output=True, text=True, env=env, encoding='latin-1', **kw)


def wait(cond, secs=20):
    end = time.time() + secs
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.2)
    return cond()


PORT_B, PORT_A = 24791, 24792
check('the configuration is made ready (tosser on, mailer on, one link: the hub)', run('tosssetup', inb, outb, unsec, str(PORT_B)).returncode == 0)
conf = cfg + '/mkbink.conf'
r = run('mkbinkcfg', '-o', conf)
settings = open(conf).read() if os.path.exists(conf) else ''
check('mkbinkcfg writes on-inbound = mktoss (the tosser is on, no command set)', r.returncode == 0 and ('on-inbound %s' % os.path.join(build, 'mktoss')) in settings)

# our mailer, started like mklisten does it: MK in the environment
blog = open(work + '/b.log', 'wb')
b = subprocess.Popen([mkbink, 'run', '-f', conf], env=env, stdout=blog, stderr=subprocess.STDOUT)
procs.append(b)
check('the mailer of the BBS runs', wait(lambda: b'Mailer running' in open(work + '/b.log', 'rb').read(), 10))

# the hub: a second mkbink with a packet for us
r = subprocess.run(['node', os.path.join(here, 'tosspkts.mjs'), work], capture_output=True, text=True)
pkt = work + '/0001aaaa.pkt'
check('a packet from the hub (made with MessagePacket.js)', r.returncode == 0 and os.path.exists(pkt))
for f in os.listdir(work):                      # only the first packet goes: the others are for the other tests
    if f.endswith('.pkt') and f != '0001aaaa.pkt':
        os.remove(os.path.join(work, f))
subprocess.run([mkbink, 'queue', '-O', a_dir + '/out', '-Z', '1', '-t', '1:110/290', '-x', pkt], check=True, capture_output=True)
open(a_dir + '/a.conf', 'w').write('version 1\naddress 1:110/100\ninbound %s/in\nbso %s/out\nzone 1\nport %d\nbind 127.0.0.1\n'
                                   'scan-interval 1\nretry-min 1\nretry-max 2\nlink 1:110/290\n  host 127.0.0.1\n  port %d\n  password hubpw\n'
                                   % (a_dir, a_dir, PORT_A, PORT_B))
os.chmod(a_dir + '/a.conf', 0o600)
alog = open(work + '/a.log', 'wb')
a = subprocess.Popen([mkbink, 'run', '-f', a_dir + '/a.conf'], stdout=alog, stderr=subprocess.STDOUT)
procs.append(a)


def blogtext():
    return open(work + '/b.log', 'rb').read().decode('latin-1')


check('the hub calls, the packet arrives in the inbound (secure: the link has a password)', wait(lambda: 'Received 0001aaaa.pkt' in blogtext()))
check('the mailer runs the tosser (the hook) and it tosses the mail', wait(lambda: 'mktoss done: ' in blogtext(), 30))
t = blogtext()
check('... its output is in the mailer log ([hook] lines), with the summary', '[hook] ' in t and '3 tossed, 2 netmail, 1 passed through, 1 duplicates, 2 bad' in t and 'tossed MK' in t)
check('... the packet is gone from the inbound', wait(lambda: not os.path.exists(inb + '/0001aaaa.pkt'), 5))
d = run('tossdump', '6', '10').stdout
check('the mail is in the areas: MK has the first, second and third message of that packet, BBS the one without MSGID',
      d.count('from=Remote User') >= 3 and 'subj=first mail' in d and 'subj=no msgid' in d)
check('the netmail for us is in the netmail area', 'subj=netmail for us' in run('tossdump', '4').stdout)

for p in procs:
    p.send_signal(signal.SIGTERM)
for p in procs:
    try:
        p.wait(10)
    except subprocess.TimeoutExpired:
        p.kill()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
