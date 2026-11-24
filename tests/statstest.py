#!/usr/bin/env python3
"""The statistics: mk writes a line for each call when it ends (<BBS directory>/stats/YYYY-MM.tsv: a call with a log-on, one with a failed log-on, one that went before a name), and
mkstats reports on them.  Real mk over telnet behind mklisten on a private copy of the sample BBS; and mkstats on made-up files.   usage: statstest.py <build dir> <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
live = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(live) or not os.path.exists(build + '/mkstats'):
    print('skip: no sample BBS or mkstats'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'statistics: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(live), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
srcmenus = os.path.join(repo, 'bbs', 'bbsc', 'myth', 'menus')
menus = tmp + '/m'
shutil.copytree(cfgpatch.snapshot(srcmenus), menus, ignore=lambda d, n: [f for f in n if not os.access(os.path.join(d, f), os.R_OK)])
maps = {(live + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))
for f in os.listdir(ra):
    if f == 'stats':
        shutil.rmtree(ra + '/stats')
env = dict(os.environ, MK=ra)


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def until(s, needle, secs=8):
    s.settimeout(0.2)
    b = b''
    end = time.time() + secs
    while time.time() < end and needle not in strip(b):
        try:
            d = s.recv(4096)
            if not d:
                break
            b += d
            if b'\x1b[6n' in d:
                s.sendall(b'\x1b[1;1R')
        except socket.timeout:
            pass
    return strip(b)


def conn(port):
    for _ in range(50):
        try:
            return socket.create_connection(('127.0.0.1', port))
        except OSError:
            time.sleep(0.1)
    raise SystemExit('cannot connect')


PORT = 24681
cfg = {'mk': build + '/mk', 'rundir': work + '/run', 'logfile': work + '/listen.log', 'workdir': ra, 'nodes': '1-3',
       'loginguard': {'fails': 0},
       'ports': [{'port': PORT, 'type': 'telnet', 'bind': '127.0.0.1', 'label': 'front-door', 'config': ra}]}
json.dump(cfg, open(work + '/listen.json', 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)


def login(pw, then=None):
    c = conn(PORT)
    until(c, b'language choice', 10)
    time.sleep(1.5); c.sendall(b'\r')
    until(c, b'last name: ', 10); time.sleep(2.5)
    c.sendall(b'Mark May\r'); until(c, b'assword')
    ok = False
    for p in pw:
        time.sleep(0.5)
        c.sendall(p.encode() + b'\r')
        x = until(c, b'zzzz', 3)
        if b'Minutes Remaining' in x or b'Command >' in x or b'continue' in x:
            ok = True
            break
    if ok:
        for _ in range(6):
            if then is None:
                break
            c.sendall(b'\r')
            x = until(c, b'Command >', 3)
            if b'Command >' in x:
                break
        if then:
            then(c)
    c.close()
    return ok


def lines():
    fs = sorted(f for f in os.listdir(ra + '/stats')) if os.path.isdir(ra + '/stats') else []
    out = []
    for f in fs:
        out += [l.split('\t') for l in open(ra + '/stats/' + f).read().split('\n') if l and not l.startswith('#')]
    return fs, out


try:
    time.sleep(2)
    t0 = int(time.time())
    # a caller who goes before a name
    c = conn(PORT); until(c, b'language choice', 10); c.close()
    time.sleep(3)
    # a failed log-on
    login(['bad1', 'bad2', 'bad3'])
    time.sleep(3)
    # a good call that sends the BBS's "goodbye"
    ok = login(['windows'], then=lambda c: (c.sendall(b'g'), until(c, b'zzzz', 2)))
    time.sleep(3)
    fs, rows = lines()
finally:
    lst.terminate()
    lst.wait()
check('a file for the month, named YYYY-MM.tsv, with the field names on its first lines', len(fs) == 1 and re.match(r'\d{4}-\d\d\.tsv$', fs[0]) and open(ra + '/stats/' + fs[0]).read().startswith('#mkstats 1\n#start\t'), fs)
check('one line for each call: three', len(rows) == 3 and all(len(r) == 17 for r in rows), rows)
res = [r[9] for r in rows]
check('the results: nologin, failed, ok, in the order the calls ended', res == ['nologin', 'failed', 'ok'], res)
r0, r1, r2 = (rows + [[''] * 17] * 3)[:3]
check('the call that went before a name has no user; the failed log-on and the good call have the name', r0[8] == '' and r1[8] == 'Mark May' and r2[8] == 'Mark May', [r[8] for r in rows])
check('node, type, label and port of the connection, the address of the caller', r2[3] in ('1', '2', '3') and r2[4] == 'telnet' and r2[5] == 'front-door' and r2[6] == str(PORT) and r2[7] == '127.0.0.1', r2)
check('start and end are seconds since 1970 close to now, secs is the difference, date is today', all(int(r[0]) >= t0 - 5 and int(r[1]) >= int(r[0]) and int(r[10]) == int(r[1]) - int(r[0]) for r in rows) and r2[2] == time.strftime('%Y-%m-%d'), r2)
check('a good call lasted a few seconds at least, with no transfers or messages', int(r2[10]) >= 3 and r2[11:16] == ['0', '0', '0', '0', '0'], r2)

# mkstats on this
r = subprocess.run([build + '/mkstats', '-m', time.strftime('%Y-%m')], env=env, capture_output=True, text=True)
check('mkstats: the totals say 3 calls, 1 log-on, 1 failed, 1 without a log-on, 1 caller', r.returncode == 0 and re.search(r'Calls\s+3\s+\(1 log-ons, 1 failed log-ons, 1 without a log-on\)', r.stdout) and re.search(r'Callers\s+1 different', r.stdout), r.stdout + r.stderr)
r = subprocess.run([build + '/mkstats', '-by', 'label', '-csv'], env=env, capture_output=True, text=True)
check('-by label -csv: the label of the port, three calls', r.returncode == 0 and r.stdout.splitlines()[0].startswith('label,calls') and '"front-door",3,1,1,1' in r.stdout, r.stdout)

# made-up files: a month with known numbers
d = work + '/mk2'
os.makedirs(d + '/stats')
base = int(time.mktime((2026, 3, 10, 21, 0, 0, 0, 0, -1)))
data = [('Alice', 'ok', 600, 0, 2, 0, 300, 3, 1, 'telnet', 2323, 0), ('Bob', 'ok', 1200, 1, 0, 50, 0, 1, 2, 'ssh', 2328, 0), ('Alice', 'ok', 300, 0, 0, 0, 0, 0, 1, 'telnet', 2323, 1),
        ('', 'nologin', 2, 0, 0, 0, 0, 0, 3, 'telnet', 2323, 1), ('Mallory', 'failed', 20, 0, 0, 0, 0, 0, 4, 'telnet', 2323, 2)]
out = ['#mkstats 1']
for i, (u, rs, secs, ul, dl, ulk, dlk, msgs, node, lab, port, day) in enumerate(data):
    st = base + day * 86400 + i * 3600
    out.append('\t'.join(map(str, [st, st + secs, time.strftime('%Y-%m-%d', time.localtime(st)), node, 'telnet', lab, port, '10.0.0.%d' % i, u, rs, secs, ul, dl, ulk, dlk, msgs, 0])))
open(d + '/stats/2026-03.tsv', 'w').write('\n'.join(out) + '\n')
e2 = dict(env, MK=d)
r = subprocess.run([build + '/mkstats', '-m', '2026-03'], env=e2, capture_output=True, text=True)
check('totals of a made-up month: calls, callers, minutes (600+1200+300 s = 35.0), uploads, downloads, messages',
      re.search(r'Calls\s+5', r.stdout) and re.search(r'Callers\s+2 different', r.stdout) and '35.0 minutes' in r.stdout and re.search(r'Uploads\s+1 file\(s\), 50 K', r.stdout)
      and re.search(r'Downloads\s+2 file\(s\), 300 K', r.stdout) and re.search(r'Messages posted\s+4', r.stdout), r.stdout)
r = subprocess.run([build + '/mkstats', '-m', '2026-03', '-by', 'user', '-top', '2'], env=e2, capture_output=True, text=True)
lines_ = [l for l in r.stdout.splitlines() if l.startswith(('Alice', 'Bob', '(nobody)', 'Mallory'))]
check('-by user -top 2: the busiest first (Alice 2 calls), two lines and "(n more)"', lines_ and lines_[0].startswith('Alice') and len(lines_) == 2 and 'more)' in r.stdout, r.stdout)
r = subprocess.run([build + '/mkstats', '-m', '2026-03', '-by', 'day'], env=e2, capture_output=True, text=True)
check('-by day: one line for each day with its calls (the hours of the made-up calls go over midnight: four days)', len([l for l in r.stdout.splitlines() if re.match(r'2026-03-1\d ', l)]) == 4, r.stdout)
r = subprocess.run([build + '/mkstats', '-d', '2026-03-10'], env=e2, capture_output=True, text=True)
check('-d one day: only its calls (2)', re.search(r'Calls\s+2\s', r.stdout), r.stdout)
r = subprocess.run([build + '/mkstats', '-y', '2025'], env=e2, capture_output=True, text=True)
check('a period without statistics: exit 1 and says so', r.returncode == 1 and 'no statistics' in r.stderr, (r.returncode, r.stderr))
r = subprocess.run([build + '/mkstats', '-by', 'colour'], env=e2, capture_output=True, text=True)
check('a bad -by: exit 1', r.returncode == 1, r.stderr)
r = subprocess.run([build + '/mkstats', '-a'], env={'PATH': os.environ['PATH']}, capture_output=True, text=True)
check('no configuration: exit 1', r.returncode == 1 and 'No configuration' in r.stderr, r.stderr)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
