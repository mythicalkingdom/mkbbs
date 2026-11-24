#!/usr/bin/env python3
"""mkcfgcvt: the Remote Access configuration of the sample BBS converted to the MK format must load and
list the same message areas; QuickBBS and SuperBBS files are written.  The sample itself must not change.
usage: cvttest.py <build dir> <work dir>"""
import glob, hashlib, os, shutil, subprocess, sys

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sample = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(sample):
    print('skip: no sample BBS'); sys.exit(0)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkcfgcvt: ' + name)
    if not ok:
        fails += 1


def snapshot():
    return {f: hashlib.md5(open(f, 'rb').read()).hexdigest() for f in glob.glob(os.path.join(sample, '*')) if os.path.isfile(f) and os.access(f, os.R_OK)}


before = snapshot()
shutil.rmtree(work, ignore_errors=True)
inp, out, outq, outs = [os.path.join(work, d) for d in ('in', 'out', 'quick', 'sbbs')]
os.makedirs(work)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch
shutil.copytree(cfgpatch.snapshot(sample), inp, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(inp)
for d in (out, outq, outs):
    os.makedirs(d)


def run(prog, *args, stdin='', **env):
    e = {'PATH': os.environ['PATH']}
    e.update(env)
    return subprocess.run([os.path.join(build, prog)] + list(args), env=e, capture_output=True, text=True, input=stdin)


r = run('mkcfgcvt')
check('no arguments: syntax help', r.returncode == 3 and 'InputType OutputType' in r.stdout)
r = run('mkcfgcvt', '9', '1')
check('wrong type: syntax help', r.returncode == 3)
r = run('mkcfgcvt', '2', '1', RA=os.path.join(work, 'nothere'), MK=out)
check('no configuration to read: error', r.returncode == 1 and 'loading config' in r.stdout)

r = run('mkcfgcvt', '2', '1', RA=inp, MK=out)
check('Remote Access to MK completed', r.returncode == 0 and 'Conversion completed' in r.stdout)
names = {os.path.basename(f).lower(): os.path.getsize(f) for f in glob.glob(os.path.join(out, '*'))}
want = {n: os.path.getsize(os.path.join(sample, n)) for n in ('config.mk', 'echocfg.mk', 'files.mk', 'messages.mk')}
want['mailer.mk'] = 12600            # new: the mailer settings, written with the defaults
want['events.mk'] = 4502             # new: what the events do, written with the defaults
want['fileecho.mk'] = 33024          # new: the file echoes (TIC), written with the defaults
check('the four MK files have the sizes of the real ones, mailer.mk, events.mk and fileecho.mk the sizes of their records: %s' % names, names == want)
ra = os.path.join(work, 'ra.txt')
mk = os.path.join(work, 'mk.txt')
r1 = run('mklistmsgarea', ra, RA=inp)
r2 = run('mklistmsgarea', mk, MK=out)
la = open(ra, encoding='latin-1').read().split('\n')[:-1] if os.path.exists(ra) else []
lm = open(mk, encoding='latin-1').read().split('\n')[:-1] if os.path.exists(mk) else []
check('converted MK configuration loads and lists %d areas' % (len(lm) // 3), r1.returncode == 0 and r2.returncode == 0 and len(lm) > 0)
check('short names and names are the same as in the RA configuration',
      [l for i, l in enumerate(la) if i % 3] == [l for i, l in enumerate(lm) if i % 3])

def hashes(d):
    return {f: hashlib.md5(open(os.path.join(d, f), 'rb').read()).hexdigest() for f in os.listdir(d)}


# converting again into the same directory: the files that exist are listed and need a yes
h = hashes(out)
os.utime(os.path.join(out, 'config.mk'), (1, 1))   # a mark to see a rewrite
r = run('mkcfgcvt', '2', '1', RA=inp, MK=out, stdin='n\n')
check('existing files: listed and asked', r.returncode == 4 and 'would be overwritten' in r.stdout and 'config.mk' in r.stdout
      and 'Nothing was written' in r.stdout)
check('answer n: nothing was written', os.path.getmtime(os.path.join(out, 'config.mk')) == 1)
r = run('mkcfgcvt', '2', '1', RA=inp, MK=out, stdin='')
check('no answer (end of input) counts as no', r.returncode == 4)
r = run('mkcfgcvt', '2', '1', RA=inp, MK=out, stdin='y\n')
check('answer y: overwritten', r.returncode == 0 and 'Conversion completed' in r.stdout and hashes(out) == h)
os.utime(os.path.join(out, 'config.mk'), (1, 1))
r = run('mkcfgcvt', '-y', '2', '1', RA=inp, MK=out)
check('-y: no question', r.returncode == 0 and 'overwritten' not in r.stdout and 'Conversion completed' in r.stdout)

r = run('mkcfgcvt', '2', '3', RA=inp, QUICK=outq)
check('Remote Access to QuickBBS: files written', r.returncode == 0 and len(os.listdir(outq)) >= 3)
r = run('mkcfgcvt', '2', '4', RA=inp, SBBS=outs)
check('Remote Access to SuperBBS: files written', r.returncode == 0 and len(os.listdir(outs)) >= 3)
check('the sample BBS was not touched', snapshot() == before)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
