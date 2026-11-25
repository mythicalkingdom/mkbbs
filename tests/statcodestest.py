#!/usr/bin/env python3
"""Statistics display codes ^T<period><item> (in a prompt: \t and the two letters) in the real mk, over telnet, on a private copy of the sample BBS with statistics lines of known days: the numbers are worked out
here from the lines.   usage: statcodestest.py <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
work = os.path.abspath(sys.argv[1])
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
srcmenus = os.path.join(repo, 'bbs', 'bbsc', 'myth', 'menus')
if not (os.path.isdir(src) and os.path.isdir(srcmenus)):
    print('skip: no sample BBS'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
menus = tmp + '/m'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(ra)
shutil.copytree(cfgpatch.snapshot(srcmenus), menus, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
txt = tmp + '/t'
os.makedirs(txt)
maps = {(src + '/').encode(): (ra + '/').encode(), (srcmenus + '/').encode(): (menus + '/').encode(), (repo + '/bbs/bbsc/myth/txtfiles/').encode(): (txt + '/').encode()}
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: maps.get(s, s))



import datetime
today = datetime.date.today()
names = ['Ann', 'Bob', 'Mark May']
# (days ago, user, result, secs, ul, dl, ulk, dlk, msgs, hour)
rows = [(0, 'Ann', 'ok', 600, 1, 2, 10, 20, 3, 14), (0, 'Bob', 'ok', 300, 0, 1, 0, 5, 0, 14), (0, 'Mark May', 'ok', 120, 0, 1, 0, 7, 1, 9), (0, '', 'failed', 20, 0, 0, 0, 0, 0, 3), (0, '', 'nologon', 1, 0, 0, 0, 0, 0, 3),
        (3, 'Ann', 'ok', 60, 0, 1, 0, 1, 0, 14), (3, 'Mark May', 'ok', 240, 2, 0, 30, 0, 2, 14), (40, 'Bob', 'ok', 100, 0, 0, 0, 0, 0, 20), (400, 'Ann', 'ok', 3000, 5, 5, 50, 50, 5, 14)]
os.makedirs(ra + '/stats', exist_ok=True)
files = {}
for (ago, user, res, secs, ul, dl, ulk, dlk, msgs, hour) in rows:
    d = today - datetime.timedelta(days=ago)
    start = int(datetime.datetime(d.year, d.month, d.day, hour, 0, 0).timestamp())
    files.setdefault(d.strftime('%Y-%m'), []).append('\t'.join(map(str, [start, start + secs, d.isoformat(), 1, 'telnet', 'telnet', 2323, '192.0.2.1', user, res, secs, ul, dl, ulk, dlk, msgs, ''])) + '\n')
for m, ls in files.items():
    open(ra + '/stats/%s.tsv' % m, 'w').write('#mkstats 1\n' + ''.join(ls))
ok_rows = [dict(ago=r[0], user=r[1], secs=r[3], ul=r[4], dl=r[5], ulk=r[6], dlk=r[7], msgs=r[8], hour=r[9], date=today - datetime.timedelta(days=r[0])) for r in rows if r[2] == 'ok']


def inp(per, r):
    d = r['date']
    return {'T': r['ago'] == 0, 'W': 0 <= r['ago'] < 7, 'M': (d.year, d.month) == (today.year, today.month), 'Y': d.year == today.year, 'A': True}[per]


def num(n):
    return '{:,}'.format(n)


def expect(per, item):
    rs = [r for r in ok_rows if inp(per, r)]
    if item.islower():
        rs = [r for r in rs if r['user'].lower() == 'mark may']
    I = item.upper()
    if I == 'C': return num(len(rs))
    if I == 'M': return num(sum(r['secs'] for r in rs) // 60)
    if I == 'A': return num((sum(r['secs'] for r in rs) // 60) // len(rs)) if rs else '0'
    if I == 'D': return num(sum(r['dl'] for r in rs))
    if I == 'K': return num(sum(r['dlk'] for r in rs))
    if I == 'P': return num(sum(r['ul'] for r in rs))
    if I == 'Q': return num(sum(r['ulk'] for r in rs))
    if I == 'G': return num(sum(r['msgs'] for r in rs))
    if I == 'U': return num(len({r['user'].lower() for r in rs if r['user']}))
    if I == 'H':
        hs = {}
        for r in rs:
            hs[r['hour']] = hs.get(r['hour'], 0) + 1
        return '%02d:00' % max(sorted(hs), key=lambda h: hs[h]) if hs else '-'


combos = ['TC', 'WC', 'MC', 'YC', 'AC', 'TU', 'MU', 'AU', 'TM', 'MM', 'AM', 'TA', 'AA', 'TD', 'MD', 'TK', 'WK', 'TP', 'AP', 'TQ', 'AQ', 'TG', 'MG', 'AG', 'TH', 'AH', 'Tc', 'Wc', 'Ac', 'Tm', 'Am', 'Ad', 'Ak', 'Ag', 'Ap']
path = None
for f in os.listdir(menus):
    if f.lower() == 'realtop.mnu':
        path = os.path.join(menus, f)
d = bytearray(open(path, 'rb').read())
REC = 167
slot = 1
cells = ['[%02d:\\t%s]' % (i, c) for i, c in enumerate(combos)] + ['[X1:\\tXC]', '[X3:\\tTh]', '[X4:\\tTZ]']
prompts = [''.join(cells[i:i + 7]) for i in range(0, len(cells), 7)]
for p in prompts:
    while slot * REC < len(d) and d[slot * REC + 7] != 0:
        slot += 1
    if (slot + 1) * REC > len(d):
        d += bytes((slot + 1) * REC - len(d))
    assert slot <= 50, 'the menu is full'
    r = bytearray(REC)
    pb = p.encode()
    r[7] = len(pb); r[8:8 + len(pb)] = pb
    r[7 + 76] = ord(' ')
    r[REC - 2] = 7
    d[slot * REC:(slot + 1) * REC] = r
    slot += 1
# a screen with the codes in it (a file with the control character ^T), shown by a menu item (command 5, key 4)
open(txt + '/statscr.asc', 'wb').write(b'CALLS-TODAY=\x14TC CALLS-MONTH=\x14MC YOURS=\x14Mc BUSIEST=\x14MH END\r\n')
while slot * REC < len(d) and d[slot * REC + 7] != 0:
    slot += 1
if (slot + 1) * REC > len(d):
    d += bytes((slot + 1) * REC - len(d))
r = bytearray(REC)
r[0] = 5
r[7] = 5; r[8:13] = b'SCRN4'
r[7 + 76] = ord('4')
r[84] = 7; r[85:92] = b'statscr'
r[REC - 2] = 7
d[slot * REC:(slot + 1) * REC] = r
open(path, 'wb').write(d)
cfg = {'mk': repo + '/build/mk', 'rundir': os.path.join(work, 'run'), 'logfile': os.path.join(work, 'listen.log'),
       'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': 24773, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra}]}
json.dump(cfg, open(os.path.join(work, 'listen.json'), 'w'))
lst = subprocess.Popen([repo + '/build/mklisten', '-c', os.path.join(work, 'listen.json')], stdout=subprocess.DEVNULL)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'stat codes: ' + name + ('' if ok else '  ' + str(info)[-600:]))
    if not ok:
        fails += 1


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def until(s, needle, secs=8):
    s.settimeout(0.2)
    b = b''
    end = time.time() + secs
    while time.time() < end and needle not in strip(b):
        try:
            x = s.recv(4096)
            if not x:
                break
            b += x
            if b'\x1b[6n' in x:
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


try:
    c = conn(24773)
    until(c, b'language choice', 10); time.sleep(1.5); c.sendall(b'\r')
    until(c, b'last name: ', 10); time.sleep(2.5)
    c.sendall(b'Mark May\r'); until(c, b'assword'); time.sleep(0.5); c.sendall(b'windows\r')
    seen = b''
    for _ in range(8):
        x = until(c, b'zzzz', 3)
        seen += x
        if b'continue' in x or b'Enter' in x:
            c.sendall(b'\r')
        else:
            break
    t = seen.decode('latin-1')
    check('caller logged in to the menu', 'Command >' in t, t[-200:])
    bad = []
    for i, cb in enumerate(combos):
        m = re.search(r'\[%02d:(.*?)\]' % i, t)
        want = expect(cb[0], cb[1])
        if not m or m.group(1) != want:
            bad.append((cb, m.group(1) if m else None, want))
    check('every period and item: the number the lines add up to (%d codes: system and the caller, T W M Y A, commas)' % len(combos), not bad, bad[:6])
    check('own statistics are the caller\'s only (Mark May: 2 calls today and in the week...)', re.search(r'\[%02d:(.*?)\]' % combos.index('Tc'), t).group(1) == '1' and re.search(r'\[%02d:(.*?)\]' % combos.index('Wc'), t).group(1) == '2')
    x1 = re.search(r'\[X1:(.*?)\]', t)
    x3 = re.search(r'\[X3:(.*?)\]', t)
    x4 = re.search(r'\[X4:(.*?)\]', t)
    check('a wrong period letter, a wrong item letter and the system-only items in lower case show nothing (and swallow their letters)', x1 and x1.group(1) == '' and x3 and x3.group(1) == '' and x4 and x4.group(1) == '', (x1 and x1.group(1), x3 and x3.group(1), x4 and x4.group(1)))
    c.sendall(b'4')
    scr = until(c, b'END', 6).decode('latin-1')
    want_m = expect('M', 'C'); want_t = expect('T', 'C'); want_y = expect('M', 'c'); want_h = expect('M', 'H')
    check('a SCREEN with the codes in it (an .asc file with the control character ^T) shows the numbers', 'CALLS-TODAY=%s CALLS-MONTH=%s YOURS=%s BUSIEST=%s END' % (want_t, want_m, want_y, want_h) in scr, scr[-300:])
    check('failed log-ons and calls without a log-on are not counted anywhere', expect('A', 'C') == num(len(ok_rows)) and re.search(r'\[%02d:(.*?)\]' % combos.index('AC'), t).group(1) == num(len(ok_rows)))
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
