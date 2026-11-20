#!/usr/bin/env python3
"""The event editor of mkconfig (Events): the new fields (action, command, late handling, exclusive, log, timeout) are shown,
saved in events.mk, and read back by the next run; the list shows what an event does.  Private copy of the sample BBS.
usage: eventsedittest.py <work dir>"""
import os, shutil, struct, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src):
    print('skip: no sample BBS'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
cfg = cfgpatch.short_dir() + '/r'
shutil.copytree(src, cfg, ignore=lambda d, names: [n for n in names if n.lower().startswith(('mkbink.conf', 'events.mk')) or
                                                   not os.access(os.path.join(d, n), os.R_OK)])
env = dict(os.environ, MK=cfg)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'event editor: ' + name)
    if not ok:
        fails += 1


def screen(*keys):
    e = dict(env, CFGDIR=cfg, CFGDELAY='0.25')
    r = subprocess.run([sys.executable, os.path.join(here, 'cfgshot.py')] + list(keys), capture_output=True, text=True, env=e)
    return r.stdout


s = screen('\\x1be', '\\r')
check('the form has the new fields', all(w in s for w in ('Action:', 'Command:', 'If it was missed:', 'Minutes late:', 'Most runs:', 'Exclusive:', 'Log output:', 'Timeout:')))
check('the defaults: no action, within minutes, 10 minutes, 5 runs',
      'Action: None' in s and 'Within minutes' in s and 'Minutes late:     10' in s and 'Most runs:  5' in s)

# event 1: enabled, 03:30, errorlevel 5, command "echo hi", run per miss, 15 minutes, at most 7, exclusive, log, timeout 30
keys = ['\\x1be', '\\r', ' ', '\\t', '3', '\\t', '30', '\\t', '5', '\\t', '\\t', '\\t',     # status, hour, minute, errorlevel, forced, days
        ' ', '\\t', 'echo hi', '\\t', ' ', ' ', '\\t', '15', '\\t', '7', '\\t', ' ', '\\t', ' ', '\\t', '30', '\\r',
        '\\x1b',                                                                   # the list
        '\\x1bx', 'y']
screen(*keys)
f = os.path.join(cfg, 'events.mk')
check('events.mk was written with the pinned size (2 + 30 * 150)', os.path.exists(f) and os.path.getsize(f) == 4502)
d = open(f, 'rb').read() if os.path.exists(f) else bytes(4502)
act, flags, late, lmin, lmax = struct.unpack('<BHBHB', d[2:9])
cmd = d[9 + 1:9 + 1 + d[9]]
tmo = struct.unpack('<H', d[9 + 101:9 + 103])[0]
check('event 1: command (1), exclusive + log (3)', (act, flags) == (1, 3))
check('... run per miss (3), 15 minutes, at most 7', (late, lmin, lmax) == (3, 15, 7))
check('... the command line and the timeout 30', (cmd, tmo) == (b'echo hi', 30))
check('event 2 was not touched (the defaults: within minutes, 10, 5)', struct.unpack('<BHBHB', d[2 + 150:2 + 150 + 7])[2:] == (1, 10, 5))
c = open(os.path.join(cfg, 'config.mk'), 'rb').read()
check('config.mk was saved too (the old fields are still in it)', len(c) > 1000)

s = screen('\\x1be')
check('the list shows the time, the level, what it does and exclusive',
      '03:30' in s and 'Level 5' in s and 'Run echo hi' in s and '(exclusive)' in s)
s = screen('\\x1be', '\\r')
check('the form shows it again after a new start', 'echo hi' in s and 'Run per miss' in s and 'Action: Command' in s and 'Event Time: 03:30' in s and '[X]' in s)

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
