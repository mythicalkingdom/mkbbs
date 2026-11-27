#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The statistics screen of the sysop monitor (S in the node list): today, the week, the month, the year; totals, calls by hour, the last calls.  mklisten with a sysop port, a telnet
client with an 80x25 screen, statistics files that are made up.   usage: statsmontest.py <work dir>"""
import json, os, re, shutil, subprocess, sys, tempfile, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch
from termscreen import Term, wait

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
    print(('ok   ' if ok else 'FAIL ') + 'statistics screen: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
shutil.rmtree(ra + '/stats', ignore_errors=True)
run = tempfile.mkdtemp(prefix='r', dir='/tmp')
PORT = 24781
cfg = {'mk': build + '/mk', 'mkmon': build + '/mkmon', 'rundir': run, 'logfile': work + '/listen.log', 'workdir': ra, 'nodes': '1-2',
       'ports': [{'port': PORT, 'type': 'sysop', 'bind': '127.0.0.1', 'password': 'sesame', 'config': ra}]}
json.dump(cfg, open(work + '/l.json', 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/l.json'], stdout=subprocess.DEVNULL)


def login():
    t = Term(PORT)
    t.until(lambda: b'assword' in t.raw)
    t.send('sesame\r')
    t.until(lambda: 'MK sysop monitor' in t.screen())
    return t


try:
    time.sleep(1.5)
    t = login()
    check('the node list offers S for the statistics', 'S statistics' in t.screen(), t.screen())
    t.send('s')
    check('without statistics files: says so, with the directory', t.until(lambda: 'No statistics yet' in t.screen()) and '/stats' in t.screen(), t.screen())
    t.send('q')
    t.until(lambda: 'MK sysop monitor' in t.screen() and 'statistics:' not in t.screen())
    # statistics: today a few calls, some days back, last month
    now = time.time()
    lt = time.localtime(now)
    midnight = time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday, 0, 0, 0, 0, 0, -1))
    rows = []

    def add(day_back, hour, user, res, secs, node=1, lab='telnet', ul=0, dl=0, ulk=0, dlk=0, msgs=0):
        st = int(midnight - day_back * 86400 + hour * 3600 + 120)
        d = time.strftime('%Y-%m-%d', time.localtime(st))
        rows.append((d, '\t'.join(map(str, [st, st + secs, d, node, 'telnet', lab, 2323, '10.0.0.1', user, res, secs, ul, dl, ulk, dlk, msgs, 0]))))

    add(0, 1, 'Alice', 'ok', 600, ul=1, ulk=50, dl=2, dlk=300, msgs=3)
    add(0, 1, '', 'nologin', 2)
    add(0, 2, 'Bob', 'ok', 1200, node=2, lab='ssh', msgs=1)
    add(0, 2, 'Mallory', 'failed', 20, lab='ssh')
    add(3, 5, 'Carol', 'ok', 300)
    add(40, 9, 'Dave', 'ok', 100)
    byfile = {}
    for d, l in rows:
        byfile.setdefault(d[:7], []).append(l)
    os.makedirs(ra + '/stats')
    for m, ls in byfile.items():
        open(ra + '/stats/%s.tsv' % m, 'w').write('#mkstats 1\n#start\tend\n' + '\n'.join(ls) + '\n')
    t.send('s')
    ok = t.until(lambda: 'statistics: today' in t.screen() and 'Last calls' in t.screen())
    sc = t.screen()
    check('the screen opens on today: title, the totals box', ok and 'Calls by hour' in sc, sc)
    check('today: 4 calls, 2 log-ons, 1 failed, 1 without a log-on, 2 callers', re.search(r'Calls\s+4\b', sc) and re.search(r'Log-ons\s+2\b', sc) and re.search(r'Failed log-ons\s+1\b', sc)
          and re.search(r'No log-on\s+1\b', sc) and re.search(r'Callers\s+2\b', sc), sc)
    check('today: 30 minutes, the uploads and downloads, 4 messages', '30 min' in sc and re.search(r'Uploads\s+1 files, 50 K', sc) and re.search(r'Downloads\s+2 files, 300 K', sc) and re.search(r'Messages posted\s+4\b', sc), sc)
    check('the last calls: newest first, with node, port label, user, result', re.search(r'Mallory\s+failed', sc) and re.search(r'Alice\s+ok', sc) and re.search(r'\bssh\b', sc) and sc.index('Mallory') < sc.index('Alice'), sc)
    check('the keys are shown at the bottom', 'Today' in sc.splitlines()[-1] and 'Week' in sc.splitlines()[-1] and 'Month' in sc.splitlines()[-1] and 'Year' in sc.splitlines()[-1], sc.splitlines()[-1])
    t.send('w')
    check('W: the last 7 days: 5 calls (Carol 3 days ago), 3 callers', t.until(lambda: 'statistics: the last 7 days' in t.screen() and re.search(r'Calls\s+5\b', t.screen()) is not None) and re.search(r'Callers\s+3\b', t.screen()), t.screen())
    t.send('m')
    mo = t.until(lambda: 'statistics: this month' in t.screen())
    check('M: this month (the calls of today and 3 days ago, unless the month began in between)', mo and re.search(r'Calls\s+[456]\b', t.screen()) is not None, t.screen())
    t.send('y')
    check('Y: the year: all 6 calls (40 days ago is in this year unless the year began in between)', t.until(lambda: 'statistics: %d' % lt.tm_year in t.screen()) and re.search(r'Calls\s+[56]\b', t.screen()) is not None, t.screen())
    t.send('q')
    check('Q goes back to the node list', t.until(lambda: 'MK sysop monitor' in t.screen() and 'statistics:' not in t.screen()), t.screen())
finally:
    lst.terminate()
    lst.wait()
    shutil.rmtree(run, ignore_errors=True)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
