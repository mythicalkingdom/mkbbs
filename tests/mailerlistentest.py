#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""mklisten runs the mailer: mkbinkcfg when the BBS configuration changes, mkbink started / told to read its settings /
stopped / restarted, and gone when mklisten is.  Done with small fake programs; then once with the real mkbink and
mkbinkcfg when the mkbink project is built next to this one.   usage: mailerlistentest.py <work dir>"""
import os, shutil, signal, socket, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.realpath(os.path.join(here, '..'))
mklisten = os.path.join(repo, 'build', 'mklisten')
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0
procs = []


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mailer supervision: ' + name)
    if not ok:
        fails += 1


def wait(cond, secs=12):
    end = time.time() + secs
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.1)
    return cond()


def read(p):
    try:
        return open(p).read()
    except OSError:
        return ''


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


# ---------------------------------------------------------------- the fakes
cfgdir = os.path.join(work, 'bbs')
os.makedirs(cfgdir)
for n in ('config.mk', 'echocfg.mk', 'mailer.mk'):
    open(os.path.join(cfgdir, n), 'w').write('x')
ctl = os.path.join(work, 'ctl')           # on | off | fail
setf = os.path.join(work, 'settings.txt')  # what the fake mkbinkcfg writes
binklog = os.path.join(work, 'bink.log')
cfglog = os.path.join(work, 'cfg.log')
settings = os.path.join(cfgdir, 'mkbink.conf')
fakebink = os.path.join(work, 'mkbink')
fakecfg = os.path.join(work, 'mkbinkcfg')
faketoss = os.path.join(work, 'mktoss')
tosslog = os.path.join(work, 'toss.log')
open(faketoss, 'w').write('''#!/bin/sh
echo "toss MK=$MK $*" >> "$FAKELOG/toss.log"
exit 3
''')
os.chmod(faketoss, 0o755)
open(fakebink, 'w').write('''#!/bin/sh
echo "start $$ $*" >> "$FAKELOG/bink.log"
echo "env MK=$MK" >> "$FAKELOG/bink.log"
trap 'echo HUP >> "$FAKELOG/bink.log"' HUP
trap 'echo TERM >> "$FAKELOG/bink.log"; exit 0' TERM
while true; do sleep 0.1; done
''')
open(fakecfg, 'w').write('''#!/bin/sh
# usage: mkbinkcfg -q -o file     (MK is the configuration directory)
echo "run MK=$MK $*" >> "$FAKELOG/cfg.log"
case "$(cat "$FAKELOG/ctl")" in
  off)  exit 3;;
  fail) echo "mkbinkcfg: no main address" >&2; exit 1;;
esac
if ! cmp -s "$FAKELOG/settings.txt" "$3"; then cp "$FAKELOG/settings.txt" "$3.new" && mv "$3.new" "$3"; fi
exit 0
''')
os.chmod(fakebink, 0o755)
os.chmod(fakecfg, 0o755)


def config(path, mailer, port, extra=None):
    import json
    c = {'mk': '/bin/true', 'logfile': os.path.join(work, path + '.log'), 'workdir': work, 'nodes': '1-2',
         'ports': [{'port': port, 'type': 'telnet', 'bind': '127.0.0.1', 'config': cfgdir}], 'mailer': mailer}
    if extra:
        c.update(extra)
    p = os.path.join(work, path + '.json')
    json.dump(c, open(p, 'w'))
    return p


def touch(name, text):
    open(os.path.join(cfgdir, name), 'w').write(text)


def count(text, word):
    return text.count(word)


mailer = {'config': cfgdir, 'mkbink': fakebink, 'mkbinkcfg': fakecfg, 'mktoss': faketoss, 'scan': 1, 'interval': 1, 'restart': 1}
c = config('l1', mailer, 24681)
r = subprocess.run([mklisten, '-t', '-c', c], capture_output=True, text=True)
check('-t shows the mailer programs, the settings file and the tosser scan', r.returncode == 0 and 'mailer:' in r.stdout and
      fakebink in r.stdout and fakecfg in r.stdout and settings in r.stdout and 'NOT FOUND' not in r.stdout
      and 'tosser scan every 1 s: %s' % faketoss in r.stdout)
bad = config('bad', {'mkbink': fakebink}, 24682)
r = subprocess.run([mklisten, '-t', '-c', bad], capture_output=True, text=True)
check('a mailer section without "config" is an error', r.returncode == 2 and '"config"' in r.stderr)
bad = config('bad', {'config': cfgdir, 'colour': 'red'}, 24682)
r = subprocess.run([mklisten, '-t', '-c', bad], capture_output=True, text=True)
check('an unknown key in the mailer section is an error', r.returncode == 2 and 'colour' in r.stderr)

env = dict(os.environ, FAKELOG=work)
open(ctl, 'w').write('off')
open(setf, 'w').write('version 1\naddress 1:1/1\n')
lst = subprocess.Popen([mklisten, '-c', c], env=env, stdout=subprocess.DEVNULL)
procs.append(lst)
ll = os.path.join(work, 'l1.log')
check('mailer switched off in the configuration: not started, and said so',
      wait(lambda: 'not enabled in the BBS configuration' in read(ll)) and not os.path.exists(binklog))
check('... mkbinkcfg was run with the configuration directory and -o <settings>',
      'MK=%s -q -o %s' % (cfgdir, settings) in read(cfglog))
n_cfg = count(read(cfglog), 'run ')
time.sleep(2.5)
check('... and not run again while the configuration is unchanged (interval 1 s)', count(read(cfglog), 'run ') == n_cfg)

# ---- on: start
open(ctl, 'w').write('on')
lst.send_signal(signal.SIGHUP)
check('SIGHUP + mailer on: mkbink started with "run -f <settings>"',
      wait(lambda: 'run -f %s' % settings in read(binklog)) and 'mailer started' in read(ll))
pid1 = int(read(binklog).split()[1])
check('... settings file made', read(settings) == read(setf))
check('... mkbink has MK = the BBS configuration in its environment (its hook and mktoss need it)', 'env MK=%s' % cfgdir in read(binklog))
check('the tosser scan: "mktoss -s -q" is run while the mailer runs, with MK set (it says "not switched on", exit 3: no complaint)',
      wait(lambda: 'toss MK=%s -s -q' % cfgdir in read(tosslog)))
check('... and again, every second', wait(lambda: count(read(tosslog), 'toss ') >= 3))

# ---- changed configuration: HUP
open(setf, 'w').write('version 1\naddress 1:1/1\nlink 1:2/2\n')
touch('mailer.mk', 'xx')
check('a changed mailer.mk: mkbinkcfg run, mkbink told (HUP)', wait(lambda: count(read(binklog), 'HUP') == 1) and 'settings changed' in read(ll))
time.sleep(2.5)
check('... only once while nothing else changes', count(read(binklog), 'HUP') == 1)
touch('mailer.mk', 'xx')            # rewritten with the same text: mkbinkcfg finds nothing to change
time.sleep(0.1)
touch('echocfg.mk', 'yyy')
time.sleep(2.5)
check('a touched file but identical settings: mkbinkcfg runs, mkbink is not disturbed', count(read(binklog), 'HUP') == 1)
lst.send_signal(signal.SIGHUP)
check('SIGHUP: mkbink reads its settings again', wait(lambda: count(read(binklog), 'HUP') == 2) and 'reread' in read(ll))

# ---- the mailer dies: restart with growing delay
os.kill(pid1, signal.SIGKILL)
check('mkbink killed: logged and restarted after 1 s',
      wait(lambda: count(read(binklog), 'start ') == 2) and 'mailer ended (signal 9)' in read(ll) and 'again in 1 seconds' in read(ll))
pid2 = int(read(binklog).strip().splitlines()[-1].split()[1]) if False else [int(l.split()[1]) for l in read(binklog).splitlines() if l.startswith('start')][-1]
os.kill(pid2, signal.SIGKILL)
check('killed again at once: the delay doubles (2 s)', wait(lambda: 'again in 2 seconds' in read(ll)) and wait(lambda: count(read(binklog), 'start ') == 3, 15))
pid3 = [int(l.split()[1]) for l in read(binklog).splitlines() if l.startswith('start')][-1]

# ---- mkbinkcfg fails: the mailer keeps running
open(ctl, 'w').write('fail')
touch('config.mk', 'zzzz')
check('mkbinkcfg failing: logged, mkbink keeps running', wait(lambda: 'mkbinkcfg failed (1)' in read(ll)) and
      'keeps its old settings' in read(ll) and alive(pid3))
check('... the message of mkbinkcfg is in the log', 'no main address' in read(ll))

# ---- switched off: stopped, not restarted
open(ctl, 'w').write('off')
touch('config.mk', 'zzzzz')
check('the mailer switched off: mkbink is told to stop (TERM) and is gone',
      wait(lambda: 'TERM' in read(binklog)) and wait(lambda: not alive(pid3)) and 'switched off, stopping mkbink' in read(ll))
n = count(read(binklog), 'start ')
time.sleep(3)
check('... and not started again', count(read(binklog), 'start ') == n)

n_toss = count(read(tosslog), 'toss ')
time.sleep(2.5)
check('the scan does not run while the mailer is off', count(read(tosslog), 'toss ') <= n_toss + 1)

# ---- on again, then mklisten stops: mkbink stops with it
open(ctl, 'w').write('on')
touch('config.mk', 'zzzzzz')
check('switched on again: started', wait(lambda: count(read(binklog), 'start ') == n + 1))
pid4 = [int(l.split()[1]) for l in read(binklog).splitlines() if l.startswith('start')][-1]
terms = count(read(binklog), 'TERM')
lst.send_signal(signal.SIGTERM)
check('mklisten stopped (SIGTERM): exits 0', wait(lambda: lst.poll() is not None, 20) and lst.returncode == 0)
check('... the mailer was told to stop and is gone', count(read(binklog), 'TERM') == terms + 1 and not alive(pid4) and 'stopping the mailer' in read(ll))

# ---- mklisten is killed: the mailer goes too
open(binklog, 'w').write('')
lst = subprocess.Popen([mklisten, '-c', c], env=env, stdout=subprocess.DEVNULL)
procs.append(lst)
check('started again: mkbink runs', wait(lambda: 'start ' in read(binklog)))
pid5 = int(read(binklog).split()[1])
lst.kill()
lst.wait()
check('mklisten killed (SIGKILL): the mailer goes with it', wait(lambda: not alive(pid5), 5))

# ---- no mailer section: nothing changes
plain = {'mk': '/bin/true', 'logfile': os.path.join(work, 'p.log'), 'nodes': '1-2',
         'ports': [{'port': 24683, 'type': 'telnet', 'bind': '127.0.0.1', 'config': cfgdir}]}
import json
json.dump(plain, open(os.path.join(work, 'p.json'), 'w'))
r = subprocess.run([mklisten, '-t', '-c', os.path.join(work, 'p.json')], capture_output=True, text=True)
check('no "mailer" section: as before', r.returncode == 0 and 'mailer' not in r.stdout)

# ---------------------------------------------------------------- the real programs
mkbink = os.environ.get('MKBINK', os.path.join(repo, '..', 'mkbink', 'build', 'mkbink'))
binkcfg = os.path.join(repo, 'build', 'mkbinkcfg')
sample = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if os.path.exists(mkbink) and os.path.exists(binkcfg) and os.path.isdir(sample):
    real = os.path.join(work, 'real')
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch
    shutil.copytree(cfgpatch.snapshot(sample), real, ignore=lambda d, names: [n for n in names if n.lower().startswith(('mkbink.conf', 'mailer.mk'))])
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import cfgpatch; cfgpatch.fix_sample(real)
    ec = os.path.join(real, 'echocfg.mk')
    d = bytearray(open(ec, 'rb').read())
    for off, text in ((0, 'files/in'), (51, 'mail/out')):          # InBoundFiles, OutBoundFiles: String[50]
        d[off:off + 51] = bytes([len(text)]) + text.encode() + bytes(50 - len(text))
    open(ec, 'wb').write(d)

    stamp = [0]

    def mailer_mk(enabled, port):
        h = bytearray(184 + 64 * 178 + 1024)
        h[0:2] = (1).to_bytes(2, 'little'); h[2:4] = (3 if enabled else 2).to_bytes(2, 'little'); h[4:6] = port.to_bytes(2, 'little')
        h[47] = 8; h[48] = 1
        for off, v in ((49, 120), (51, 60), (53, 3600), (55, 30)):
            h[off:off + 2] = v.to_bytes(2, 'little')
        p = os.path.join(real, 'mailer.mk')
        open(p, 'wb').write(h)
        stamp[0] += 10                                         # every change gets its own time (the listener compares size and
        t = time.time() + 5 + stamp[0]                         # time, with the 2 second resolution of a DOS time: all the files have
        os.utime(p, (t, t))                                    # the same size here), and one that is newer than anything else

    mailer_mk(False, 24691)
    rc = config('real', {'config': real, 'mkbink': mkbink, 'mkbinkcfg': binkcfg, 'interval': 1, 'restart': 1,
                         'logfile': os.path.join(work, 'real-bink.log')}, 24684)
    lst = subprocess.Popen([mklisten, '-c', rc], stdout=subprocess.DEVNULL)
    procs.append(lst)
    rl = os.path.join(work, 'real.log')

    def listening(port):
        try:
            socket.create_connection(('127.0.0.1', port), 0.5).close()
            return True
        except OSError:
            return False

    check('real tools, mailer off: not started', wait(lambda: 'not enabled' in read(rl)) and not listening(24691))
    mailer_mk(True, 24691)
    check('Mailer switched on in the configuration: mkbink starts and listens on its port', wait(lambda: listening(24691), 15))
    check('... its own log file has the mailer messages', wait(lambda: 'Mailer running' in read(os.path.join(work, 'real-bink.log'))))
    mailer_mk(True, 24692)
    check('port changed: mkbink is told and says it needs a restart', wait(lambda: 'used after a restart' in read(os.path.join(work, 'real-bink.log')), 15))
    mailer_mk(False, 24691)
    check('switched off again: mkbink stops, the port closes', wait(lambda: not listening(24691), 15))
    lst.send_signal(signal.SIGTERM)
    check('mklisten stops cleanly', wait(lambda: lst.poll() is not None, 20) and lst.returncode == 0)
else:
    print('skip: the real mkbink / mkbinkcfg are not built')

for p in procs:
    if p.poll() is None:
        p.kill()
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
