#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mklisten and systemd's sd_notify: READY=1 once the ports are open, WATCHDOG=1 heartbeats at a third of WATCHDOG_USEC (also while a slow tool is waited for),
STATUS= lines, STOPPING=1 at SIGTERM; nothing when NOTIFY_SOCKET is not set or WATCHDOG_PID names another process.
usage: sdnotifytest.py <mklisten> <fakemk> <work dir>"""
import json, os, shutil, signal, socket, subprocess, sys, time

mklisten, fakemk, work = [os.path.abspath(a) for a in sys.argv[1:4]]
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'sdnotify: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


run = os.path.join(work, 'run')
os.makedirs(run)
cfg = {'mk': fakemk, 'logfile': os.path.join(work, 'l.log'), 'rundir': run,
       'ports': [{'port': 24671, 'type': 'telnet', 'nodes': '1-2', 'bind': '127.0.0.1', 'config': '/nonexistent'}]}
json.dump(cfg, open(os.path.join(work, 'l.json'), 'w'))


def session(env_extra, secs, notify=True, abstract=False):
    """mklisten for `secs` seconds with a notify socket; returns the datagrams (with their times) and the exit code"""
    path = os.path.join(work, 'notify.sock')
    if os.path.exists(path):
        os.unlink(path)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    s.bind('\0mknotify%d' % os.getpid() if abstract else path)
    s.settimeout(0.2)
    env = dict(os.environ)
    for k in ('NOTIFY_SOCKET', 'WATCHDOG_USEC', 'WATCHDOG_PID'):
        env.pop(k, None)
    if notify:
        env['NOTIFY_SOCKET'] = ('@mknotify%d' % os.getpid()) if abstract else path
    env.update(env_extra)
    p = subprocess.Popen([mklisten, '-f', '-c', os.path.join(work, 'l.json')], env=env, stdout=subprocess.DEVNULL)
    got, t0 = [], time.time()
    stopped = False
    while time.time() - t0 < secs + 3:
        if time.time() - t0 >= secs and not stopped:
            p.send_signal(signal.SIGTERM)
            stopped = True
        try:
            got.append((time.time() - t0, s.recv(1000).decode()))
        except socket.timeout:
            if stopped and p.poll() is not None:
                break
    if p.poll() is None:
        p.kill()
    rc = p.wait()
    s.close()
    return got, rc


got, rc = session({'WATCHDOG_USEC': '3000000'}, 6)
msgs = [m for _, m in got]
check('READY=1 comes first, with a STATUS line', msgs and msgs[0].startswith('READY=1') and 'STATUS=' in msgs[0], msgs[:3])
beats = [t for t, m in got if m == 'WATCHDOG=1']
check('heartbeats at a third of WATCHDOG_USEC (3 s: about one a second, at least 4 in 6 s, none more than 2 s apart)',
      len(beats) >= 4 and all(b - a < 2 for a, b in zip(beats, beats[1:])), beats)
check('STOPPING=1 at SIGTERM, the exit code 0', 'STOPPING=1' in msgs and rc == 0, (msgs[-3:], rc))

got, rc = session({}, 3)
msgs = [m for _, m in got]
check('no WATCHDOG_USEC: READY and STATUS only, no heartbeat', msgs and msgs[0].startswith('READY=1') and 'WATCHDOG=1' not in msgs, msgs)

got, rc = session({'WATCHDOG_USEC': '3000000', 'WATCHDOG_PID': '1'}, 3)
msgs = [m for _, m in got]
check('WATCHDOG_PID of another process: READY, no heartbeat', msgs and msgs[0].startswith('READY=1') and 'WATCHDOG=1' not in msgs, msgs)

got, rc = session({'WATCHDOG_USEC': '3000000'}, 3, abstract=True)
msgs = [m for _, m in got]
check('an abstract socket (@name) works too', msgs and msgs[0].startswith('READY=1') and 'WATCHDOG=1' in msgs, msgs)

got, rc = session({}, 2, notify=False)
check('no NOTIFY_SOCKET: runs and stops as before', got == [] and rc == 0, (got, rc))

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
