#!/usr/bin/env python3
"""mk -G<id> with a "hub" in the map file (MKQwkNet DoHub): two private copies of the sample BBS.  The hub is the first copy
(mklisten with a "qwk" port: mk -Q), the node is the second one: its pass logs in with the mk profile, sends its reply packet
(a local message), receives the packet of the hub and posts it, without anybody moving a file.
usage: hubpasstest.py <build dir> <work dir>"""
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
    print(('ok   ' if ok else 'FAIL ') + 'hub pass: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


def setup(wk):
    os.makedirs(wk)
    tmp = cfgpatch.short_dir()
    ra = tmp + '/r'
    shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
    cfgpatch.fix_sample(ra)
    cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
    env = dict(os.environ, MK=ra)
    cj = os.path.join(wk, 'cj'); os.makedirs(cj)
    envj = dict(env, MKJSON=cj)
    subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
    dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
    dj['config']['ExtPack'][1]['PCmdLine'] = 'zip -q -j'
    dj['config']['ExtPack'][1]['UCmdLine'] = 'unzip -o -q'
    json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
    subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
    for t in (['tosssetup', tmp + '/in', tmp + '/outb', tmp + '/un'], ['tossmake']):
        if t[0] == 'tossmake':
            os.makedirs(tmp + '/in', exist_ok=True)
        subprocess.run([build + '/' + t[0]] + t[1:], env=env, capture_output=True, text=True)
    return ra, env


def dump(env, n):
    return subprocess.run([build + '/tossdump', str(n)], env=env, capture_output=True, text=True, encoding='latin-1').stdout


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
hub_ra, hub_env = setup(work + '/hub')
node_ra, node_env = setup(work + '/node')
# the hub: the caller is the user Mark May, a QWK node with the Zmodem of mk; the id of the hub is the board id of its config
r = subprocess.run([build + '/netsetup', 'Mark May', '6'], env=dict(hub_env, NETPWD='NODEPW', NETPROT='Z'), capture_output=True, text=True)
check('the user of the node at the hub is set up', 'ok' in r.stdout)
hub_id = subprocess.run([build + '/qwkmsgtest', 'boardid'], env=hub_env, capture_output=True, text=True).stdout.strip() if False else 'MythKing'
# a message of the hub for the node (written by the BBS editor: tossmake's echomail message is in area 6 already: it is the hub's)
subprocess.run([build + '/postmsg', '6', 'Hub Poster', 'All', 'Message from the hub', 'written on the hub'], env=hub_env, capture_output=True, text=True)
# the node: the hub is a user of it (QWK node, area 6), and a map file
r = subprocess.run([build + '/netsetup', 'Chuck Ebenschweiger', '6'], env=node_env, capture_output=True, text=True)
check('the hub is a user of the node (QWK node flag, area 6)', 'ok' in r.stdout)
subprocess.run([build + '/postmsg', '6', 'Node Poster', 'All', 'Message from the node', 'written on the node'], env=node_env, capture_output=True, text=True)
port = 25100 + os.getpid() % 300
os.makedirs(node_ra + '/in'); os.makedirs(node_ra + '/out')
open(node_ra + '/' + hub_id + '.map', 'w').write(
    'inbound %s/in\noutbound %s/out\nuser Chuck Ebenschweiger\nhub 127.0.0.1:%d\nprofile mk\nlogin Mark May\npassword nodepw\nprotocol Z\nconf 6 6\n' % (node_ra, node_ra, port))
cfg = {'mk': build + '/mk', 'rundir': work + '/run', 'logfile': work + '/listen.log', 'workdir': hub_ra, 'nodes': '1-2',
       'ports': [{'port': port, 'type': 'qwk', 'bind': '127.0.0.1', 'config': hub_ra}]}
json.dump(cfg, open(work + '/listen.json', 'w'))
# a dry run first: it says what would go, and changes nothing (the real pass below still finds the message, so no pointer moved)
p = subprocess.run([build + '/mk', '-L', '-G' + hub_id, '-D'], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
check('dry run (-D): exit 0, says it is a dry run and how many messages would go up from area 6',
      p.returncode == 0 and 'Dry run' in p.stderr and 'message(s) would go up' in p.stderr and 'area 6 ' in p.stderr, (p.returncode, p.stderr[-400:]))
dry1 = re.search(r'(\d+) message\(s\) would go up', p.stderr)
check('... nothing was made: no reply packet in the outbound directory, no transcript, nothing in the inbound directory',
      not os.listdir(node_ra + '/out') and not os.path.exists(node_ra + '/' + hub_id + '.hub.log') and not os.listdir(node_ra + '/in'),
      (os.listdir(node_ra + '/out'), os.listdir(node_ra + '/in')))
p = subprocess.run([build + '/mk', '-L', '-G' + hub_id, '-D'], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
dry2 = re.search(r'(\d+) message\(s\) would go up', p.stderr)
check('... and again: the same number (the pointer did not move)', dry1 and dry2 and dry1.group(1) == dry2.group(1) and int(dry1.group(1)) >= 1, p.stderr[-300:])
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)
time.sleep(1)
before_hub, before_node = dump(hub_env, 6), dump(node_env, 6)
try:
    p = subprocess.run([build + '/mk', '-L', '-G' + hub_id], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=240, stdin=subprocess.DEVNULL)
finally:
    lst.terminate()
    lst.wait()
check('mk -G%s with a hub: exit 0' % hub_id, p.returncode == 0, p.returncode)
log = open(node_ra + '/' + hub_id + '.hub.log').read() if os.path.exists(node_ra + '/' + hub_id + '.hub.log') else ''
check('the transcript of the call is next to the map file (password not in it)', '-- upload' in log and '-- download' in log and 'nodepw' not in log, log[-300:])
after_hub, after_node = dump(hub_env, 6), dump(node_env, 6)
shutil.copy(node_ra + '/' + hub_id + '.hub.log', work + '/first.hub.log')            # the recording of a real pass: the replay test below
check('the reply packet reached the hub: the message of the node is in its area 6', 'Message from the node' in after_hub and 'Message from the node' not in before_hub, after_hub[-300:])
check('the packet of the hub came and was posted: the node has the message of the hub', 'Message from the hub' in after_node and 'Message from the hub' not in before_node, after_node[-300:])
check('the reply packet is gone from the outbound directory, the packet is kept as .old', not os.listdir(node_ra + '/out') and os.path.exists(node_ra + '/in/' + hub_id + '.qwk.old'), (os.listdir(node_ra + '/out'), os.listdir(node_ra + '/in')))
# a second pass: nothing new on either side, nothing is posted twice
n1 = after_node.count('Message from the hub')
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)
time.sleep(1)
try:
    p = subprocess.run([build + '/mk', '-L', '-G' + hub_id], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=240, stdin=subprocess.DEVNULL)
finally:
    lst.terminate()
    lst.wait()
check('a second pass: exit 0, nothing is posted twice', p.returncode == 0 and dump(node_env, 6).count('Message from the hub') == n1 and dump(hub_env, 6).count('Message from the node') == 1, p.returncode)
# the hub says something after the reply packet: "reply-ok" / "reply-error" in the map file decide whether it was accepted
def pass_(extra_map):
    mp = node_ra + '/' + hub_id + '.map'
    base = open(mp).read().split('reply-')[0]
    open(mp, 'w').write(base + extra_map)
    l = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)
    time.sleep(1)
    try:
        return subprocess.run([build + '/mk', '-L', '-G' + hub_id], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=240, stdin=subprocess.DEVNULL)
    finally:
        l.terminate()
        l.wait()


subprocess.run([build + '/postmsg', '6', 'Node Poster', 'All', 'Second from the node', 'written on the node'], env=node_env, capture_output=True, text=True)
p = pass_('reply-ok zzz-never-said\n')
reps = [f for f in os.listdir(node_ra + '/out') if f.lower().endswith('.rep')]
check('a hub that does not say what reply-ok wants: exit 7, the reply packet stays', p.returncode == 7 and reps, (p.returncode, reps, p.stdout[-300:]))
p = pass_('reply-error zzz-never-said\n')
reps = [f for f in os.listdir(node_ra + '/out') if f.lower().endswith('.rep')]
check('nothing of reply-error in what the hub says: accepted, exit 0, the reply packet is gone', p.returncode == 0 and not reps, (p.returncode, reps, p.stdout[-300:]))
# the messages that came from the hub are not sent back, even when the last read pointer is put behind them
led = node_ra + '/' + hub_id + '.imp'
check('the pass wrote down the messages it posted from the hub (MythKing.imp: area and number)', os.path.exists(led) and open(led).read().split()[:1] == ['6'] or os.path.exists(led) and '6 ' in open(led).read(), open(led).read() if os.path.exists(led) else None)
r = subprocess.run([build + '/setlr', 'Chuck Ebenschweiger', '6', '0'], env=node_env, capture_output=True, text=True)
p = subprocess.run([build + '/mk', '-L', '-G' + hub_id, '-D'], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
m1 = re.search(r'(\d+) message\(s\) would go up', p.stderr)
sk = re.search(r'(\d+) message\(s\) that came from the hub are not sent back', p.stderr)
check('pointer back at 0: the dry run leaves the messages of the hub out and says how many', m1 and sk and int(sk.group(1)) >= 1, p.stderr[-400:])
os.rename(led, led + '.off')
p = subprocess.run([build + '/mk', '-L', '-G' + hub_id, '-D'], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
m0 = re.search(r'(\d+) message\(s\) would go up', p.stderr)
check('without the file they would have gone: %s more' % (sk.group(1) if sk else '?'), m0 and m1 and sk and int(m0.group(1)) == int(m1.group(1)) + int(sk.group(1)), p.stderr[-300:])
os.rename(led + '.off', led)
open(led, 'a').write('6 4999 20200101\n')               # an entry from years ago
subprocess.run([build + '/mk', '-L', '-G' + hub_id, '-D'], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
check('an entry older than 60 days is dropped from the file, the others stay', '20200101' not in open(led).read() and '6 ' in open(led).read(), open(led).read())
# control commands for the hub (the node side of ADD / DROP ...): queued with -X or in <id>.ctl, sent as messages to SBBS, taken out when the hub has them
def pass_x(*extra, mapextra=''):
    mp = node_ra + '/' + hub_id + '.map'
    base = open(mp).read().split('reply-')[0]
    open(mp, 'w').write(base + mapextra)
    l = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)
    time.sleep(1)
    try:
        return subprocess.run([build + '/mk', '-L', '-G' + hub_id] + list(extra), env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=240, stdin=subprocess.DEVNULL)
    finally:
        l.terminate()
        l.wait()


ctl = node_ra + '/' + hub_id + '.ctl'
tlog = node_ra + '/' + hub_id + '.hub.log'
p = subprocess.run([build + '/mk', '-L', '-G' + hub_id, '-D', '-XDROP 6', '-XRESETALL -5'], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
check('dry run with -X: lists the control messages (to SBBS, the conference of the command, the command), queues nothing',
      p.returncode == 0 and 'control message to SBBS in conference 6: DROP 6' in p.stderr and 'conference 6: RESETALL -5' in p.stderr and not os.path.exists(ctl), p.stderr[-500:])
p = pass_x('-XDROP 6')
tl = open(tlog, encoding='latin-1').read() if os.path.exists(tlog) else ''
reps = [f for f in os.listdir(node_ra + '/out') if f.lower().endswith('.rep')]
check('-X"DROP 6": a reply packet is made although no message is new, the hub did it (DROP 6: done), nothing is left in the node\'s files',
      p.returncode == 0 and 'DROP 6: done' in tl and not os.path.exists(ctl) and not os.path.exists(ctl + '.out') and not reps, (p.returncode, tl[-300:], os.listdir(node_ra)))
open(ctl, 'w').write('; put the conference back\nADD 6\n\nCONTROL ON\n')
p = pass_x()
tl = open(tlog, encoding='latin-1').read()
check('<id>.ctl with comments and blank lines: ADD 6 and CONTROL ON reach the hub (done), the file is consumed',
      p.returncode == 0 and 'ADD 6: done' in tl and 'CONTROL: done' in tl and not os.path.exists(ctl) and not os.path.exists(ctl + '.out'), (p.returncode, tl[-400:]))
p = pass_x('-XFROB 1', '-XADD')
check('a command that is not valid, or ADD without a conference: exit 8, nothing queued, nothing sent', p.returncode == 8 and not os.path.exists(ctl), (p.returncode, p.stderr[-300:]))
open(ctl, 'w').write('CTRL-A STRIP\n')
p = pass_x(mapextra='reply-ok zzz-never-said\n')
reps = [f for f in os.listdir(node_ra + '/out') if f.lower().endswith('.rep')]
check('a reply packet the hub is taken not to have accepted (exit 7) keeps its commands (.ctl.out) as it keeps the packet',
      p.returncode == 7 and reps and os.path.exists(ctl + '.out') and not os.path.exists(ctl), (p.returncode, reps, os.listdir(node_ra)))
p = pass_x()
check('the next pass sends that packet, and then the commands are gone', p.returncode == 0 and not os.path.exists(ctl + '.out') and not [f for f in os.listdir(node_ra + '/out') if f.lower().endswith('.rep')],
      (p.returncode, os.listdir(node_ra), os.listdir(node_ra + '/out')))
# the recording of the first pass, replayed against the profile (no call): the same way
p = subprocess.run([build + '/mk', '-L', '-G' + hub_id, '-F' + work + '/first.hub.log'], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
check('the transcript of the first pass replays against the mk profile without a call (-F): the same way', p.returncode == 0 and 'the same way' in p.stdout, (p.returncode, p.stdout, p.stderr[-300:]))
# a hub that is not there
open(node_ra + '/' + hub_id + '.map', 'a').write('hub 127.0.0.1:1\n')
p = subprocess.run([build + '/mk', '-L', '-G' + hub_id], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=240, stdin=subprocess.DEVNULL)
check('a hub that cannot be reached: exit 5', p.returncode == 5, p.returncode)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
