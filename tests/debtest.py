#!/usr/bin/env python3
"""The Debian package (packaging/mkdeb.sh): it is built, has the right fields and files, the maintainer scripts are valid shell, lintian finds no errors (when it is
there), and the programs inside it run (the package is unpacked, not installed: no root needed).   usage: debtest.py <build dir> <work dir>"""
import glob, json, os, re, shutil, subprocess, sys

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
if not shutil.which('dpkg-deb'):
    print('skip: no dpkg-deb'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'deb: ' + name + ('' if ok else '  ' + str(info)[:500]))
    if not ok:
        fails += 1


for f in glob.glob(repo + '/build/mkbbs_*.deb'):
    os.remove(f)
r = subprocess.run([repo + '/packaging/mkdeb.sh'], capture_output=True, text=True, cwd=repo, env=dict(os.environ, VERSION='0.2+test'))
debs = glob.glob(repo + '/build/mkbbs_0.2+test_*.deb')
check('packaging/mkdeb.sh builds the package', r.returncode == 0 and len(debs) == 1, r.stdout + r.stderr)
if not debs:
    print('failures: %d' % fails); sys.exit(1)
deb = debs[0]
info = subprocess.run(['dpkg-deb', '-f', deb], capture_output=True, text=True).stdout
check('control: name, version, architecture, depends on libc6 and adduser, recommends libssl and stunnel', 'Package: mkbbs' in info and 'Version: 0.2+test' in info and 'Architecture: ' in info
      and 'libc6' in info and 'adduser' in info and 'libssl3' in info and 'stunnel4' in info, info)
check('the maintainer line has no private mail address', '@users.noreply.github.com' in info or os.environ.get('DEB_MAINTAINER'), info)
lst = subprocess.run(['dpkg-deb', '-c', deb], capture_output=True, text=True).stdout
want = ['usr/bin/mk', 'usr/bin/mklisten', 'usr/bin/mkconfig', 'usr/bin/mkbbsssh', 'usr/bin/mkdosdoor', 'usr/lib/systemd/system/mklisten.service', 'usr/lib/sysusers.d/mkbbs.conf',
        'usr/share/mkbbs/hubs/synchronet.scr', 'usr/share/mkbbs/lang/AMERICAN.lc', 'usr/share/mkbbs/ssh/sshd_config', 'usr/share/doc/mkbbs/GETTING-STARTED.md',
        'usr/share/doc/mkbbs/examples/mklisten.example.json', 'usr/share/doc/mkbbs/copyright']
missing = [w for w in want if ' ./' + w not in lst]
check('the files that make a BBS are in it (programs, unit, user, hub profiles, language files, SSH templates, documentation)', not missing, missing)
check('everything belongs to root; nothing is in /etc or /var (postinst makes the configuration and the log directory)', 'mmay' not in lst and ' ./etc/mkbbs/' not in lst and ' ./var/' not in lst, lst[:300])
x = work + '/x'
shutil.rmtree(work, ignore_errors=True)
os.makedirs(x)
subprocess.run(['dpkg-deb', '-x', deb, x], check=True)
ctl = work + '/c'
os.makedirs(ctl)
subprocess.run(['dpkg-deb', '-e', deb, ctl], check=True)
for s in ('postinst', 'prerm', 'postrm'):
    p = ctl + '/' + s
    rr = subprocess.run(['sh', '-n', p], capture_output=True, text=True)
    check('maintainer script %s: valid shell, executable' % s, rr.returncode == 0 and os.access(p, os.X_OK), rr.stderr)
check('the unit points at /usr/bin and the example in the documentation', 'ExecStart=/usr/bin/mklisten' in open(x + '/usr/lib/systemd/system/mklisten.service').read()
      and 'file:/usr/share/doc/mkbbs/examples/mklisten.example.json' in open(x + '/usr/lib/systemd/system/mklisten.service').read())
# the programs run from the unpacked package; the configuration is made the way postinst makes it
ex = x + '/usr/share/doc/mkbbs/examples/mklisten.example.json'
cfg = work + '/mklisten.json'
t = open(ex).read().replace('"change-me"', '"a-real-password"').replace('/usr/local/bin/mk', x + '/usr/bin/mk')
open(cfg, 'w').write(t)
rr = subprocess.run([x + '/usr/bin/mklisten', '-t', '-c', cfg], capture_output=True, text=True)
check('mklisten from the package checks its configuration (-t)', rr.returncode == 0 and 'ok' in rr.stdout, rr.stdout + rr.stderr)
sed = subprocess.run(['sed', '-e', 's|"/usr/local/bin/mk"|"/usr/bin/mk"|', '-e', '/"logfile"/a\\  "rundir": "/run/mkbbs",', ex], capture_output=True, text=True).stdout
check('the sed of postinst gives valid JSON with the packaged path and the run directory', json.loads(sed)['mk'] == '/usr/bin/mk' and json.loads(sed)['rundir'] == '/run/mkbbs')
rr = subprocess.run([x + '/usr/bin/mklc'], capture_output=True, text=True)
check('another program of the package starts (mklc without arguments only says what it needs)', rr.returncode not in (126, 127), rr.returncode)
if shutil.which('lintian'):
    rr = subprocess.run(['lintian', '--no-tag-display-limit', deb], capture_output=True, text=True)
    errs = [l for l in rr.stdout.splitlines() if l.startswith('E:')]
    check('lintian finds no errors', not errs, errs[:5])
else:
    print('skip: no lintian')
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
