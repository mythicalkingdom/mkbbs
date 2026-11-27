#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The SSH front of the BBS: mkbbsssh (the shell of the account "bbs") between an SSH daemon and mklisten.  A real ssh client goes through a daemon that runs as the
test user (OpenSSH, and Dropbear when it is installed; key login, the password-less login needs root and is not tested here) and its forced command mkbbsssh to a
Telnet port of mklisten with "proxy": true and reaches the BBS (language choice, name prompt); the real address of the caller (SSH_CONNECTION) is the one
mklisten uses; a new window size does no harm; a refused connection says so.   usage: sshtest.py <work dir>"""
import fcntl, getpass, json, os, pty, select, shutil, signal, socket, struct, subprocess, sys, termios, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
sshd = shutil.which('sshd') or '/usr/sbin/sshd'
dropbear = shutil.which('dropbear') or ('/usr/sbin/dropbear' if os.path.exists('/usr/sbin/dropbear') else None)
if not os.path.isdir(src) or not shutil.which('ssh') or not os.path.exists(sshd) or not os.path.exists(build + '/mkbbsssh'):
    print('skip: no sample BBS, ssh, sshd or mkbbsssh'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'ssh front: ' + name + ('' if ok else '  ' + str(info)[:400]))
    if not ok:
        fails += 1


tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(cfgpatch.snapshot(src), ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
PORT_BBS, PORT_SSH, PORT_DB = 24851, 24852, 24853
cfg = {'mk': build + '/mk', 'mkmon': build + '/mkmon', 'rundir': tmp + '/run', 'logfile': work + '/listen.log', 'workdir': ra, 'nodes': '1-4',
       'ports': [{'port': PORT_BBS, 'type': 'telnet', 'bind': '127.0.0.1', 'proxy': True, 'config': ra}]}
json.dump(cfg, open(work + '/listen.json', 'w'))
lst = subprocess.Popen([build + '/mklisten', '-c', work + '/listen.json'], stdout=subprocess.DEVNULL)

# the key of the caller and the daemons: OpenSSH as this user
home = os.path.expanduser('~')
kd = home + '/.sshtest.%d' % os.getpid()                         # (Dropbear wants every directory above its files to be private to the user)
os.makedirs(kd, mode=0o700)
subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', kd + '/ck'], check=True)
subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', kd + '/hk'], check=True)
os.makedirs(kd + '/auth', mode=0o700)
shutil.copy(kd + '/ck.pub', kd + '/auth/authorized_keys')
os.chmod(kd + '/auth/authorized_keys', 0o600)
mkbbsssh = '%s/mkbbsssh -p %d' % (build, PORT_BBS)
open(kd + '/sshd_config', 'w').write('Port %d\nListenAddress 127.0.0.1\nHostKey %s/hk\nPidFile %s/sshd.pid\nAuthorizedKeysFile %s/auth/authorized_keys\n'
                                     'UsePAM no\nPasswordAuthentication no\nStrictModes no\nPermitTTY yes\nAllowTcpForwarding no\nX11Forwarding no\n'
                                     'ForceCommand %s\n' % (PORT_SSH, kd, kd, kd, mkbbsssh))
procs = [subprocess.Popen([sshd, '-D', '-e', '-f', kd + '/sshd_config'], stdout=subprocess.DEVNULL, stderr=open(work + '/sshd.log', 'w'))]
if dropbear:
    subprocess.run(['dropbearkey', '-t', 'ed25519', '-f', kd + '/dbhk'], capture_output=True)
    procs.append(subprocess.Popen([dropbear, '-F', '-E', '-p', '127.0.0.1:%d' % PORT_DB, '-r', kd + '/dbhk', '-D', kd + '/auth', '-s', '-j', '-k', '-c', mkbbsssh],
                                  stdout=subprocess.DEVNULL, stderr=open(work + '/dropbear.log', 'w')))


def ssh_session(port, steps, extra_env=None, resize=None, timeout=25):
    """an ssh client on a pty: steps = [(wait for, send)]; returns what came"""
    m, s = pty.openpty()
    fcntl.ioctl(s, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 100, 0, 0))
    p = subprocess.Popen(['ssh', '-tt', '-p', str(port), '-i', kd + '/ck', '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'BatchMode=yes', '-o', 'IdentitiesOnly=yes', '-o', 'IdentityAgent=none',
                          '-o', 'LogLevel=ERROR', '-l', getpass.getuser(), '127.0.0.1'], stdin=s, stdout=s, stderr=s, close_fds=True, env=dict(os.environ, TERM='xterm'))
    os.close(s)
    out = b''
    pos = 0
    t0 = time.time()
    for wait, send in steps:
        while wait.encode() not in out[pos:] and time.time() - t0 < timeout and p.poll() is None:
            if select.select([m], [], [], 0.2)[0]:
                try:
                    d = os.read(m, 4096)
                except OSError:
                    break
                if not d:
                    break
                out += d
                if b'\x1b[6n' in d:
                    os.write(m, b'\x1b[1;1R')
        if wait.encode() in out[pos:]:
            pos = out.index(wait.encode(), pos) + len(wait)
            if send == 'RESIZE':
                fcntl.ioctl(m, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 0, 0))
                p.send_signal(signal.SIGWINCH)
            elif send:
                time.sleep(0.5)
                os.write(m, send.encode())
    time.sleep(0.5)
    if p.poll() is None:
        p.kill()
    try:
        while select.select([m], [], [], 0.2)[0]:
            out += os.read(m, 4096)
    except OSError:
        pass
    os.close(m)
    return out.decode('latin-1')


time.sleep(2)
try:
    out = ssh_session(PORT_SSH, [('language choice', '\r'), ('last name: ', 'RESIZE'), ('last name: ', '')])
    check('OpenSSH: the BBS answers through ssh, mkbbsssh and mklisten (the language choice and the name prompt)', 'language choice' in out and 'last name: ' in out, out[-300:])
    log = open(work + '/listen.log').read()
    check('mklisten started a node for it (the address of the caller from SSH_CONNECTION: 127.0.0.1)', 'node 1 telnet:%d from 127.0.0.1' % PORT_BBS in log, log[-400:])
    # the address of the PROXY header is the one the listener uses (made-up SSH_CONNECTION, mkbbsssh run on a pty)
    m, s = pty.openpty()
    p = subprocess.Popen([build + '/mkbbsssh', '-p', str(PORT_BBS)], stdin=s, stdout=s, stderr=s, close_fds=True, env=dict(os.environ, SSH_CONNECTION='203.0.113.9 5555 127.0.0.1 22', TERM='ansi'))
    os.close(s)
    out2 = b''
    t0 = time.time()
    while b'language choice' not in out2 and time.time() - t0 < 15:
        if select.select([m], [], [], 0.3)[0]:
            out2 += os.read(m, 4096)
    p.kill()
    time.sleep(1)
    log = open(work + '/listen.log').read()
    check('a PROXY header with another address: mklisten has it for the node (from 203.0.113.9), the BBS answers', 'from 203.0.113.9' in log and b'language choice' in out2, log[-300:])
    r = subprocess.run([build + '/mkbbsssh', '-p', '1', '-h', '127.0.0.1'], capture_output=True, text=True, env=dict(os.environ, TERM='ansi'))
    check('the BBS is not there: the caller is told and mkbbsssh exits 1', r.returncode == 1 and 'not available' in r.stdout, (r.returncode, r.stdout, r.stderr))
    r = subprocess.run([build + '/mkbbsssh', '-c', 'ls', '-p', '1'], capture_output=True, text=True)
    check('a login shell is called with -c command: the command is ignored (no command is run)', r.returncode == 1 and 'ls' not in r.stdout)
    if dropbear:
        out = ssh_session(PORT_DB, [('language choice', '\r'), ('last name: ', '')])
        check('Dropbear: the same way (key login as this user; -c mkbbsssh)', 'language choice' in out and 'last name: ' in out, out[-300:])
    else:
        print('skip: no Dropbear')
finally:
    for p in procs:
        p.terminate()
    lst.terminate()
    lst.wait()
    shutil.rmtree(kd, ignore_errors=True)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
