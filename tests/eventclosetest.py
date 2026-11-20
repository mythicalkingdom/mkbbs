#!/usr/bin/env python3
"""A caller of the real mk (sample BBS, private copy, mklisten) who logs on shortly before an exclusive event is told when the BBS
closes and his call is cut to that (mk -T); the sysop's time adjustments still work.   usage: eventclosetest.py <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'event close: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(src, ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
env = dict(os.environ, MK=ra)
# an exclusive event 20 minutes from now (the clock of mklisten shows 03:00:00, the event is at 03:20)
cj = os.path.join(work, 'cj'); os.makedirs(cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=dict(env, MKJSON=cj), capture_output=True, input='', text=True)
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
ev = {'1': {'Status': 1, 'Time': '03:20', 'ErrorLvl': 0, 'Days': 127, 'Forced': 0, 'LastRun': ''}}
d['config']['Events'] = ev
x = dict(d['events']['Ev']['1'])
x.update({'Action': 1, 'Flags': 1, 'Cmd': '/bin/true'})
d['events']['Ev'] = {'1': x}
json.dump(d, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'))
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=dict(env, MKJSON=cj), capture_output=True, input='', text=True)

_lt = time.localtime()
today = int(time.mktime((_lt.tm_year, _lt.tm_mon, _lt.tm_mday, 0, 0, 0, 0, 0, -1)))
cfg = {'mk': build + '/mk', 'mkmon': build + '/mkmon', 'rundir': tmp + '/run', 'logfile': work + '/listen.log', 'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': 24651, 'type': 'telnet', 'bind': '127.0.0.1', 'config': ra},
                 {'port': 24652, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'pw', 'config': ra}],
       'events': {'config': ra, 'mkevents': build + '/mkevents', 'interval': 1, 'clock': today + 3 * 3600}}
json.dump(cfg, open(work + '/listen.json', 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)


def until(s, needle, secs=8):
    s.settimeout(0.2)
    b = b''
    end = time.time() + secs
    while time.time() < end and needle not in b:
        try:
            dd = s.recv(4096)
            if not dd:
                break
            b += dd
            if b'\x1b[6n' in dd:
                s.sendall(b'\x1b[1;1R')
        except socket.timeout:
            pass
    return b


def strip(b):
    return re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', b)


def conn(port):
    for _ in range(50):
        try:
            return socket.create_connection(('127.0.0.1', port))
        except OSError:
            time.sleep(0.1)
    raise SystemExit('cannot connect')


try:
    time.sleep(2)
    c = conn(24651)
    seen = b''
    seen += until(c, b'language choice', 10); time.sleep(1.5); c.sendall(b'\r')
    seen += until(c, b'last name: ', 10); time.sleep(2.5)
    c.sendall(b'Mark May\r'); seen += until(c, b'assword'); time.sleep(0.5); c.sendall(b'windows\r')
    for _ in range(8):
        x = until(c, b'zzzz', 3)
        seen += x
        if b'continue' in x or b'Enter' in x:
            c.sendall(b'\r')
        else:
            break
    t = strip(seen)
    m = re.search(rb'closes for maintenance in (\d+) minute\(s\)', t)
    check('the caller is told the BBS closes in 20 minutes', m is not None and m.group(1) in (b'19', b'20'), t[-300:])
    rem = re.search(rb'(\d+) Minutes Remaining', t)
    check('the caller\'s own prompt shows about 20 minutes remaining (the cap, not the hour of the user)', rem is not None and 18 <= int(rem.group(1)) <= 20, t[-300:])
    mon = conn(24652)
    until(mon, b'Password: ', 3); mon.sendall(b'pw\r'); until(mon, b'Q quit', 5)
    mon.sendall(b'1\r'); until(mon, b'zzzz', 2.5)
    mon.sendall(b'\x01+')
    check('the sysop can still add time', b'Added 5 min' in until(mon, b'left', 4))
    c.close()
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
