#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""events.mk (what the events do: EventsCfgType): written by hand here, read by the MK configuration, carried through the JSON
configuration and back byte for byte; a configuration without the file gets the defaults.  Private copies of the sample BBS.
usage: eventscfgtest.py <build dir> <work dir>"""
import json, os, shutil, struct, subprocess, sys

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sample = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(sample):
    print('skip: no sample BBS'); sys.exit(0)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'events.mk: ' + name)
    if not ok:
        fails += 1


def run(prog, *args, **env):
    e = {'PATH': os.environ['PATH']}
    e.update(env)
    return subprocess.run([os.path.join(build, prog)] + list(args), env=e, capture_output=True, text=True, input='', encoding='latin-1')


def rec(action=0, flags=0, late=1, late_min=10, late_max=5, cmd='', timeout=0):
    c = cmd.encode('cp437')
    return struct.pack('<BHBHB', action, flags, late, late_min, late_max) + bytes([len(c)]) + c + bytes(100 - len(c)) + \
        struct.pack('<H', timeout) + bytes(40)


assert len(rec()) == 150
shutil.rmtree(work, ignore_errors=True)
inp, jdir, mk2, nofile, jdir2 = [os.path.join(work, d) for d in ('in', 'json', 'mk2', 'nofile', 'json2')]
os.makedirs(work)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch
inp = cfgpatch.short_dir() + '/in'                     # short paths: the configuration holds them in fixed size fields
nofile = cfgpatch.short_dir() + '/no'
ign = lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'events.mk')) or not os.access(os.path.join(d, f), os.R_OK)]
shutil.copytree(cfgpatch.snapshot(sample), inp, ignore=ign)
shutil.copytree(cfgpatch.snapshot(sample), nofile, ignore=ign)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch
# the paths in config.mk lead to the sample: point them at the copy, or a file that is only in the sample (fileecho.mk, events.mk ...) is found through them
for _d in (inp, nofile):
    cfgpatch.patch(os.path.join(_d, 'config.mk'), (repo + '/bbs/').encode(),
                   lambda p, _d=_d: (_d + '/').encode() + p[len((sample + '/').encode()):] if p.startswith((sample + '/').encode()) else p)
for d in (jdir, mk2, jdir2):
    os.makedirs(d)

recs = [rec(1, 3, 3, 15, 7, 'echo hi there', 30), rec(4, 0, 0, 10, 5, '1:110/100')] + [rec() for _ in range(28)]
data = struct.pack('<H', 1) + b''.join(recs)
open(os.path.join(inp, 'events.mk'), 'wb').write(data)
check('the file is 2 + 30 * 150 bytes', len(data) == 4502)

r = run('mkcfgcvt', '-y', '1', '5', MK=inp, MKJSON=jdir)
check('MK to JSON completed', r.returncode == 0 and 'Conversion completed' in r.stdout)
d = json.load(open(os.path.join(jdir, 'bbsconfig.json'), encoding='utf-8'))
ev = d.get('events', {})
check('JSON has an "events" section with the version and 30 events', ev.get('Version') == 1 and len(ev.get('Ev', [])) == 30)
e1, e2, e3 = ev['Ev']['1'], ev['Ev']['2'], ev['Ev']['3']
check('event 1: command, exclusive + log, per miss (3), 15 minutes, at most 7, timeout 30, the command line',
      (e1['Action'], e1['Flags'], e1['Late'], e1['LateMin'], e1['LateMax'], e1['TimeoutMin'], e1['Cmd']) == (1, 3, 3, 15, 7, 30, 'echo hi there'))
check('event 2: mailer poll of an address, skip', (e2['Action'], e2['Late'], e2['Cmd']) == (4, 0, '1:110/100'))
check('the others keep the defaults (10 minutes grace, 5 runs)', (e3['Action'], e3['Late'], e3['LateMin'], e3['LateMax'], e3['Cmd']) == (0, 1, 10, 5, ''))

r = run('mkcfgcvt', '-y', '5', '1', MK=mk2, MKJSON=jdir)
check('JSON to MK completed', r.returncode == 0 and 'Conversion completed' in r.stdout)
back = open(os.path.join(mk2, 'events.mk'), 'rb').read() if os.path.exists(os.path.join(mk2, 'events.mk')) else b''
check('events.mk comes back byte for byte', back == data)
r = run('mkcfgcvt', '-y', '1', '5', MK=mk2, MKJSON=jdir2)
check('and the JSON of that is the same file again', r.returncode == 0 and
      open(os.path.join(jdir, 'bbsconfig.json'), 'rb').read() == open(os.path.join(jdir2, 'bbsconfig.json'), 'rb').read())

# a configuration made before events.mk existed: the defaults, and the file appears when it is saved
os.makedirs(os.path.join(work, 'jn')); os.makedirs(os.path.join(work, 'mk3'))
r = run('mkcfgcvt', '-y', '1', '5', MK=nofile, MKJSON=os.path.join(work, 'jn'))
d = json.load(open(os.path.join(work, 'jn', 'bbsconfig.json'), encoding='utf-8'))
ev = list(d.get('events', {}).get('Ev', {}).values())
check('no events.mk: every event has the defaults',
      r.returncode == 0 and len(ev) == 30 and all((e['Action'], e['Late'], e['LateMin'], e['LateMax'], e['Cmd']) == (0, 1, 10, 5, '') for e in ev))
r = run('mkcfgcvt', '-y', '5', '1', MK=os.path.join(work, 'mk3'), MKJSON=os.path.join(work, 'jn'))
check('... and a file of the right size is written', os.path.exists(os.path.join(work, 'mk3', 'events.mk')) and
      os.path.getsize(os.path.join(work, 'mk3', 'events.mk')) == 4502)

# a short or unknown file does not break the configuration
open(os.path.join(nofile, 'events.mk'), 'wb').write(struct.pack('<H', 1) + rec(1, 0, 2, 3, 4, 'x'))
os.makedirs(os.path.join(work, 'js')); 
r = run('mkcfgcvt', '-y', '1', '5', MK=nofile, MKJSON=os.path.join(work, 'js'))
d = json.load(open(os.path.join(work, 'js', 'bbsconfig.json'), encoding='utf-8')) if r.returncode == 0 else {'events': {'Ev': {'1': {}, '2': {}}}}
ev = [d['events']['Ev']['1'], d['events']['Ev']['2']]
check('a file with only the first event: that one is read, the rest keep the defaults',
      r.returncode == 0 and ev[0].get('Cmd') == 'x' and ev[0].get('Late') == 2 and ev[1].get('Late') == 1 and ev[1].get('LateMin') == 10)

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
