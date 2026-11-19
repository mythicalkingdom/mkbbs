#!/usr/bin/env python3
"""mk -G<id> with a "hub" in the map file (MKQwkNet DoHub): two private copies of the sample BBS.  The hub is the first copy
(mklisten with a "qwk" port: mk -Q), the node is the second one: its pass logs in with the mk profile, sends its reply packet
(a local message), receives the packet of the hub and posts it, without anybody moving a file.
usage: hubpasstest.py <build dir> <work dir>"""
import json, os, shutil, subprocess, sys, time

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
    shutil.copytree(src, ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
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
port = 24800 + os.getpid() % 150
os.makedirs(node_ra + '/in'); os.makedirs(node_ra + '/out')
open(node_ra + '/' + hub_id + '.map', 'w').write(
    'inbound %s/in\noutbound %s/out\nuser Chuck Ebenschweiger\nhub 127.0.0.1:%d\nprofile mk\nlogin Mark May\npassword nodepw\nprotocol Z\nconf 6 6\n' % (node_ra, node_ra, port))
cfg = {'mk': build + '/mk', 'rundir': work + '/run', 'logfile': work + '/listen.log', 'workdir': hub_ra, 'nodes': '1-2',
       'ports': [{'port': port, 'type': 'qwk', 'bind': '127.0.0.1', 'config': hub_ra}]}
json.dump(cfg, open(work + '/listen.json', 'w'))
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
# a hub that is not there
open(node_ra + '/' + hub_id + '.map', 'a').write('hub 127.0.0.1:1\n')
p = subprocess.run([build + '/mk', '-L', '-G' + hub_id], env=node_env, cwd=node_ra, capture_output=True, text=True, timeout=240, stdin=subprocess.DEVNULL)
check('a hub that cannot be reached: exit 5', p.returncode == 5, p.returncode)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
