#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""A caller who is online when an exclusive event is waiting for the callers is told (the real mk, mklisten): a plain event only says it, a forced
one with "warn" gives the minutes and disconnects after them.   usage: eventwarntest.py <work dir>"""
import json, os, re, shutil, socket, subprocess, sys, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
FORCED = int(sys.argv[2]) if len(sys.argv) > 2 else 0
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'event warn: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
env = dict(os.environ, MK=ra)
# an exclusive event 20 minutes from now (the clock of mklisten shows 03:00:00, the event is at 03:20)
cj = os.path.join(work, 'cj'); os.makedirs(cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=dict(env, MKJSON=cj), capture_output=True, input='', text=True)
d = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
ev = {'1': {'Status': 1, 'Time': '12:00', 'ErrorLvl': 0, 'Days': 127, 'Forced': FORCED, 'LastRun': ''}}
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
       'events': {'config': ra, 'mkevents': build + '/mkevents', 'interval': 1, 'clock': today + 3 * 3600, 'warn': 1 if FORCED else 0}}
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


def login():
    """a caller of the BBS (language 1, the default): what he saw up to the menu"""
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
    return c, strip(seen)


try:
    time.sleep(2)
    c, t = login()
    open(tmp + '/run/events.cmd', 'w').write('RUN 1\n')
    if not FORCED:
        b = strip(until(c, b'finish and log off', 12))
        check('the event is run by the sysop and waits for the caller: he is told to finish and log off', b'about to close for maintenance. Please finish and log off.' in b, b[-300:])
        c.close()
    else:
        b = strip(until(c, b'minute(s): this call ends then', 12))
        check('a forced event with "warn": the caller is told he has 1 minute (the call ends then)', re.search(rb'closes for maintenance in 1 minute\(s\)', b) is not None, b[-300:])
        c.settimeout(0.3)
        time.sleep(8)
        try:
            alive = c.send(b' ') > 0
        except OSError:
            alive = False
        check('... he is not disconnected at once', alive)
        gone = False
        end = time.time() + 90
        while time.time() < end and not gone:
            try:
                d = c.recv(4096)
                if not d:
                    gone = True
            except socket.timeout:
                pass
            except OSError:
                gone = True
        check('... and is disconnected after the minute', gone)
        c.close()
finally:
    lst.terminate()
    lst.wait()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
