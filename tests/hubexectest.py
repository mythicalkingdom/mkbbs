#!/usr/bin/env python3
"""mk -G<id> with "transport exec" in the map file (MKHubExec, MKQwkNet ExecPass) and profiles as files (-P, the search path, the header).  One private copy of
the sample BBS; get / put are small scripts.   usage: hubexectest.py <build dir> <work dir>"""
import json, os, re, shutil, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src) or not shutil.which('zip') or not shutil.which('unzip'):
    print('skip: no sample BBS (or no zip/unzip)'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'hub exec: ' + name + ('' if ok else '  ' + str(info)[:600]))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(src, ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
env = dict(os.environ, MK=ra)
cj = work + '/cj'; os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
dj['config']['ExtPack'][1]['PCmdLine'] = 'zip -q -j'
dj['config']['ExtPack'][1]['UCmdLine'] = 'unzip -o -q'
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
os.makedirs(tmp + '/in', exist_ok=True)
subprocess.run([build + '/tosssetup', tmp + '/in', tmp + '/outb', tmp + '/un'], env=env, capture_output=True, text=True)
subprocess.run([build + '/tossmake'], env=env, capture_output=True, text=True)
HUB = 'MythKing'
r = subprocess.run([build + '/netsetup', 'Chuck Ebenschweiger', '6'], env=env, capture_output=True, text=True)
check('the hub is a user of this BBS (QWK node flag, area 6)', 'ok' in r.stdout)
for d in ('in', 'out', 'sent', 'bin'):
    os.makedirs(ra + '/' + d, exist_ok=True)
mapf = ra + '/' + HUB + '.map'
tlog = ra + '/' + HUB + '.hub.log'
SECRET = 'sEcr3tPw'


def script(name, body):
    p = ra + '/bin/' + name
    open(p, 'w').write('#!/bin/sh\n' + body)
    os.chmod(p, 0o755)


def write_map(extra, get='get.sh', put='put.sh'):
    open(mapf, 'w').write('inbound %s/in\noutbound %s/out\nuser Chuck Ebenschweiger\nhub ftp.example.invalid:21\ntransport exec\nlogin lion\npassword %s\nconf 6 6\n'
                          % (ra, ra, SECRET) + ('get %s/bin/%s %%id%% %%qwk%%\n' % (ra, get) if get else '') + ('put %s/bin/%s %%id%% %%rep%%\n' % (ra, put) if put else '') + extra)


def post(n=1):
    for i in range(n):
        subprocess.run([build + '/postmsg', '6', 'Node Poster', 'All', 'Exec test %d' % time.time_ns(), 'written on the node'], env=env, capture_output=True, text=True)


def run(*args, timeout=120):
    return subprocess.run([build + '/mk', '-L', '-G' + HUB] + list(args), env=env, cwd=ra, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)


def clean():
    for d in ('in', 'out', 'sent'):
        for f in os.listdir(ra + '/' + d):
            os.remove(ra + '/' + d + '/' + f)
    for f in ('args', 'env', 'ran'):
        if os.path.exists(ra + '/' + f):
            os.remove(ra + '/' + f)


def reps():
    return [f for f in os.listdir(ra + '/out') if f.lower().endswith('.rep')]


import zipfile
os.makedirs(ra + '/fake', exist_ok=True)
with zipfile.ZipFile(ra + '/fake/' + HUB + '.QWK', 'w') as z:       # a packet without messages
    z.writestr('CONTROL.DAT', 'The Hub\r\nHub City\r\n555-1212\r\nSysop, Sysop\r\n0000,%s\r\n01-01-2026,00:00:00\r\nChuck Ebenschweiger\r\n\r\n0\r\n0\r\n1\r\n0\r\nGeneral\r\nHELLO\r\nNEWS\r\nGOODBYE\r\n' % HUB)
    z.writestr('MESSAGES.DAT', b'Produced by Qmail...Copyright (c) 1987 by Sparkware.  All Rights Reserved' + b' ' * (128 - 73))
GET_OK = 'echo "$@" > %s/args.get\ncp %s/fake/$1.QWK "$2"\necho "login $MK_HUB_LOGIN password $MK_HUB_PASSWORD"\nexit 0\n' % (ra, ra)
PUT_OK = 'echo "$@" > %s/args\nenv > %s/env\ncp "$2" %s/sent/\necho "226 Transfer complete"\nexit 0\n' % (ra, ra, ra)
script('get.sh', GET_OK)
script('put.sh', PUT_OK)

# 1. everything works
clean(); write_map(''); post()
p = run()
tl = open(tlog, encoding='latin-1').read() if os.path.exists(tlog) else ''
check('a pass: get fetched the packet (it is the inbound packet now, .old once read), put got the reply packet (exit status of mk = the packet: 0 or 4)',
      p.returncode in (0, 4) and 'Packet received: ' + HUB + '.qwk' in p.stderr and 'The reply packet was sent' in p.stderr, (p.returncode, p.stderr[-400:], p.stderr[-200:]))
check('the reply packet went to put and is gone from the outbound directory', os.listdir(ra + '/sent') == [HUB + '.REP'] and os.path.getsize(ra + '/sent/' + HUB + '.REP') > 0 and not reps(), (os.listdir(ra + '/sent'), reps()))
args = open(ra + '/args').read() if os.path.exists(ra + '/args') else ''
check('the arguments have %id% and %rep% replaced and no password', args.split()[0] == HUB and args.split()[1].endswith('/' + HUB + '.REP') and SECRET not in args, args)
envs = open(ra + '/env').read() if os.path.exists(ra + '/env') else ''
check('the environment has the password and the other settings (MK_HUB_PASSWORD, _LOGIN, _ID, _HOST, _REP)',
      'MK_HUB_PASSWORD=' + SECRET in envs and 'MK_HUB_LOGIN=lion' in envs and 'MK_HUB_ID=' + HUB in envs and 'MK_HUB_HOST=ftp.example.invalid' in envs and 'MK_HUB_REP=' in envs, envs[-300:])
check('the transcript shows both programs and what they said, the password is not in it', '== get:' in tl and '== put:' in tl and '226 Transfer complete' in tl and 'login lion password ********' in tl and SECRET not in tl, tl)
check('the password is not on any command line in the transcript or output', SECRET not in p.stderr)

# 2. nothing new (exit 3)
clean(); script('get.sh', 'exit 3\n'); post()
p = run()
check('get says nothing new (exit 3): not an error, exit 0, the reply packet still goes', p.returncode == 0 and 'Nothing new' in p.stderr and os.listdir(ra + '/sent') == [HUB + '.REP'] and not os.listdir(ra + '/in'), (p.returncode, p.stderr[-300:]))
clean(); script('get.sh', 'exit 0\n'); write_map('nothing 9\n'); post()
p = run()
check('get ends well and leaves no packet: told, exit 0', p.returncode == 0 and 'left no packet' in p.stderr, p.stderr[-300:])
clean(); script('get.sh', 'exit 9\n'); post()
p = run()
check('"nothing 9": exit status 9 is the nothing new', p.returncode == 0 and 'Nothing new' in p.stderr, (p.returncode, p.stderr[-300:]))

# 3. get fails
clean(); script('get.sh', 'echo "530 Login incorrect"; exit 1\n'); write_map(''); post()
p = run()
tl = open(tlog, encoding='latin-1').read()
check('get fails: exit 5 with its last words, put was done anyway', p.returncode == 5 and 'The get program failed: exit status 1: 530 Login incorrect' in p.stderr and os.listdir(ra + '/sent') == [HUB + '.REP'], (p.returncode, p.stderr[-400:]))
check('... the transcript has what it said', '530 Login incorrect' in tl and '== get ended: 1' in tl, tl)

# 4. put fails: the reply packet stays
clean(); script('get.sh', GET_OK); script('put.sh', 'echo "550 Permission denied"; exit 2\n'); post()
p = run()
check('put fails: exit 5, the reply packet stays in the outbound directory', p.returncode == 5 and 'The put program failed' in p.stderr and len(reps()) == 1, (p.returncode, p.stderr[-400:], reps()))
script('put.sh', PUT_OK)
p = run()
check('the next pass sends it (a reply packet that is waiting goes first)', p.returncode in (0, 4) and os.listdir(ra + '/sent') == [HUB + '.REP'] and not reps(), (p.returncode, p.stderr[-300:]))

# 5. what put says: reply-error
clean(); script('put.sh', 'echo "Unpack failed: Invalid Conference 77"; exit 0\n'); write_map('reply-error invalid conference\n'); post()
p = run()
check('put exits 0 but says "Invalid Conference": reply-error applies as for a Telnet hub: exit 7, the reply packet stays', p.returncode == 7 and len(reps()) == 1 and 'did not accept' in p.stderr, (p.returncode, p.stderr[-300:], reps()))
script('put.sh', PUT_OK); write_map(''); run()

# 6. a hang: killed after exec-timeout
clean(); script('get.sh', 'sleep 60\n'); write_map('exec-timeout 2\n'); post()
t0 = time.time()
p = run()
check('a program that hangs is stopped after exec-timeout: exit 5, told', p.returncode == 5 and 'was stopped' in p.stderr and time.time() - t0 < 30, (p.returncode, p.stderr[-300:], time.time() - t0))

# 7. not there
clean(); write_map('', get='nonexistent.sh'); post()
p = run()
check('a program that is not there: exit 5, says so', p.returncode == 5 and 'no such file' in p.stderr, (p.returncode, p.stderr[-300:]))

# 8. only put (a hub that is fed by us and read by somebody else), only get
clean(); script('put.sh', PUT_OK); write_map('', get=None); post()
p = run()
check('only put in the map file: works (nothing is fetched)', p.returncode == 0 and os.listdir(ra + '/sent') == [HUB + '.REP'], (p.returncode, p.stderr[-300:]))
clean(); script('get.sh', GET_OK); write_map('', put=None); post()
p = run()
check('only get: the packet is fetched, the reply packet stays for whoever moves it', p.returncode in (0, 4) and 'Packet received' in p.stderr and len(reps()) == 1, (p.returncode, p.stderr[-300:], reps()))

# 9. dry run runs nothing
clean(); write_map(''); post(); script('get.sh', 'touch %s/ran\n' % ra); script('put.sh', 'touch %s/ran\n' % ra)
p = run('-D')
check('dry run: says the programs, runs none', p.returncode == 0 and 'transport exec' in p.stderr and 'get: ' in p.stderr and 'put: ' in p.stderr and not os.path.exists(ra + '/ran'), (p.returncode, p.stderr[-400:]))
script('get.sh', GET_OK); script('put.sh', PUT_OK)

# 10. profiles as files
os.makedirs(ra + '/hubs', exist_ok=True)
open(ra + '/hubs/mysoft.scr', 'w').write('# software: MySoft BBS 1.2\n# checked: MySoft 1.2 on 2026-11-23\n# reply-error: bad area\n# reply-ok: all done\ntimeout 5\nfail "from the file"\n')
p = subprocess.run([build + '/mk', '-G', '-P'], env=env, cwd=ra, capture_output=True, text=True, stdin=subprocess.DEVNULL)
check('-G -P lists the profiles: the file with its header, the built in two', 'mysoft' in p.stdout and 'MySoft BBS 1.2' in p.stdout and 'bad area' in p.stdout and 'synchronet' in p.stdout and 'built into the program' in p.stdout, p.stdout + p.stderr)
p = subprocess.run([build + '/mk', '-G', '-Pmysoft'], env=env, cwd=ra, capture_output=True, text=True, stdin=subprocess.DEVNULL)
check('-G -Pmysoft: shows its text', 'fail "from the file"' in p.stdout and 'hubs/mysoft.scr' in p.stdout, p.stdout + p.stderr)
p = subprocess.run([build + '/mk', '-G', '-Pnothere'], env=env, cwd=ra, capture_output=True, text=True, stdin=subprocess.DEVNULL)
check('-G -Pnothere: says where it looked', 'No profile nothere' in p.stderr and '/hubs/' in p.stderr, p.stderr)
# a hub on a Telnet menu that cannot be reached: the profile is loaded first
base = 'inbound %s/in\noutbound %s/out\nuser Chuck Ebenschweiger\nhub 127.0.0.1:1\nlogin lion\npassword x\nconf 6 6\n' % (ra, ra)
clean(); open(mapf, 'w').write(base + 'profile mysoft\n'); post()
p = run()
check('"profile mysoft" is found in the hubs directory of the BBS: the call is tried (not reached: exit 5)', p.returncode == 5 and 'No profile' not in p.stderr, (p.returncode, p.stderr[-300:]))
clean(); open(mapf, 'w').write(base + 'profile nothere\n'); post()
p = run()
check('a profile that is not found: exit 6, says where it looked', p.returncode == 6 and 'No profile nothere' in p.stderr and '/hubs/' in p.stderr and 'built in' in p.stderr, (p.returncode, p.stderr[-400:]))
shutil.copy(ra + '/hubs/mysoft.scr', ra + '/nothere.scr')   # next to the map file: found first
clean(); post()
p = run()
check('a file next to the map file is found (and before the other directories)', p.returncode == 5 and 'No profile' not in p.stderr, (p.returncode, p.stderr[-300:]))
os.remove(ra + '/nothere.scr')

# the files that are installed (hubs/*.scr) are the profiles that are built in: the same text
for n in ('mk', 'synchronet'):
    p = subprocess.run([build + '/mk', '-G', '-P' + n], env=env, cwd=ra, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    f = open(os.path.join(repo, 'hubs', n + '.scr')).read()
    check('hubs/%s.scr is the profile built into the program (regenerate: mk -G -P%s > hubs/%s.scr)' % (n, n, n), p.stdout == f, (len(p.stdout), len(f)))
# the header gives reply-error: a hub profile file with one, the map file with none: a Synchronet-like fake
# 12. the conferences of a packet: -I lists, -J suggests, -W writes
confs = [(100, 'LOCAL-General'), (101, 'Comments to Sysop'), (102, 'NC Mail'), (103, 'Zzz Unknown Echo')]
ctl = 'The Hub\r\nHub City\r\n555-1212\r\nSysop, Sysop\r\n0000,%s\r\n01-01-2026,00:00:00\r\nChuck Ebenschweiger\r\n\r\n0\r\n0\r\n%d\r\n' % (HUB, len(confs) - 1)
ctl += ''.join('%d\r\n%s\r\n' % c for c in confs)
clean(); write_map('')
for f in os.listdir(ra + '/in'):
    os.remove(ra + '/in/' + f)
with zipfile.ZipFile(ra + '/in/' + HUB + '.qwk', 'w') as z:
    z.writestr('CONTROL.DAT', ctl)
    z.writestr('MESSAGES.DAT', b'Produced by Qmail...Copyright (c) 1987 by Sparkware.  All Rights Reserved' + b' ' * (128 - 73))
mapbefore = open(mapf).read()
p = run('-I')
check('-I lists the conferences of the packet with number and name, the one that has a conf line says its area, the others say so',
      p.returncode == 0 and '4 conference(s)' in p.stdout and re.search(r'100\s+LOCAL-General\s+-  \(no conf line\)', p.stdout) and '103  Zzz Unknown Echo' in p.stdout, (p.returncode, p.stdout, p.stderr[-300:]))
check('-I: a conf line for a conference that is not in the packet is named', 'conf 6 6' in p.stdout, p.stdout)
check('-I changes nothing: the packet is still there, the map file is as it was, nothing is called', os.path.exists(ra + '/in/' + HUB + '.qwk') and open(mapf).read() == mapbefore)
p = run('-J')
check('-J: an exact name is a conf line (LOCAL-General = area 1, NC Mail = area 3), a part of a name is a line with ; in front (Comments to Sysop ? area 2), no match is left out',
      p.returncode == 0 and re.search(r'^conf 100 1 ', p.stdout, re.M) and re.search(r'^conf 102 3 ', p.stdout, re.M) and re.search(r'^; conf 101 2 ', p.stdout, re.M) and 'conf 103' not in p.stdout and 'Nothing is written' in p.stdout, (p.returncode, p.stdout))
check('... and nothing was written without -W', open(mapf).read() == mapbefore)
p = run('-J', '-W')
mp = open(mapf).read()
check('-J -W: the lines are added to the map file (the sure ones as conf lines, the unsure ones as comments)', p.returncode == 0 and re.search(r'^conf 100 1 ', mp, re.M) and re.search(r'^conf 102 3 ', mp, re.M) and re.search(r'^; conf 101 2 ', mp, re.M) and mp.startswith(mapbefore), (p.returncode, mp[-500:]))
p = run('-I')
check('-I again: the two now have their area', re.search(r'100\s+LOCAL-General\s+area 1 ', p.stdout) and re.search(r'102\s+NC Mail\s+area 3 ', p.stdout), p.stdout)
p = run('-J')
check('-J again: the mapped conferences and areas are not suggested again', not re.search(r'^conf 10[02] ', p.stdout, re.M), p.stdout)
os.rename(ra + '/in/' + HUB + '.qwk', ra + '/in/' + HUB + '.qwk.old')
p = run('-I')
check('the packet that the last pass kept (.qwk.old) is read when there is no new one', p.returncode == 0 and '4 conference(s)' in p.stdout, (p.returncode, p.stderr[-200:]))
os.remove(ra + '/in/' + HUB + '.qwk.old')
p = run('-I')
check('no packet at all: exit 9, says the hub is not called', p.returncode == 9 and 'not called' in p.stderr, (p.returncode, p.stderr[-300:]))

# 11. the header of a profile gives reply-error / reply-ok; the map file's own lines win. A scripted hub (the fake) needs a listener: see hubpasstest.
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
