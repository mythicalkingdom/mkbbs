#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""tools/mkdosdoor: a DOS door in dosemu2 with COM1 on the terminal (the pseudo terminal MK gives menu command 7): the caller's characters reach the
door and its answers come back, the drop files are in the directory the door runs in with the COM port line that was asked for, nodes have work
directories of their own that are gone at the end.  The door is a small .COM made here (INT 14h on COM1; it reads DOOR.SYS and sends its first line,
says hello, waits for a character and answers GOT:<it>).   needs dosemu2.   usage: dosdoortest.py <work dir>"""
import fcntl, os, pty, select, shutil, struct, subprocess, sys, termios, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
repo = os.path.realpath(os.path.join(here, '..'))
tool = os.path.join(repo, 'tools', 'mkdosdoor')
work = os.path.abspath(sys.argv[1])
if not shutil.which('dosemu'):
    print('skip: no dosemu'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'dos door: ' + name + ('' if ok else '  ' + str(info)[:500]))
    if not ok:
        fails += 1


from dosdoor_com import build_door


doors = work + '/doors'
bbs = work + '/bbs'
os.makedirs(doors); os.makedirs(bbs)
open(doors + '/ECHO1.COM', 'wb').write(build_door())
open(doors + '/SCORES.DAT', 'w').write('shared scores\n')
env = dict(os.environ, MKDOS_TMP=work + '/tmp')


def drop_files(com='COM9:'):
    open(bbs + '/door.sys', 'w', newline='').write(com + '\r\n38400\r\n8\r\n1\r\nN\r\nY\r\n')
    open(bbs + '/dorinfo1.def', 'w', newline='').write('THE BBS\r\nMARK\r\nMAY\r\nCOM9\r\n38400 BAUD,N,8,1\r\n0\r\n')


def session(args, send=b'x', timeout=40, cwd=bbs):
    """the tool on a pseudo terminal (as MK runs a program): waits for HELLO, types a character; returns (output, exit status)"""
    m, s = pty.openpty()
    p = subprocess.Popen([tool] + args, stdin=s, stdout=s, stderr=s, close_fds=True, cwd=cwd, env=env)
    os.close(s)
    out = b''
    sent = False
    t0 = time.time()
    while time.time() - t0 < timeout and p.poll() is None:
        if select.select([m], [], [], 0.3)[0]:
            try:
                d = os.read(m, 4096)
            except OSError:
                break
            out += d
            if b'HELLO FROM DOS' in out and not sent and send is not None:
                os.write(m, send); sent = True
    if p.poll() is None:
        p.kill()
    rc = p.wait()
    try:
        while select.select([m], [], [], 0.2)[0]:
            out += os.read(m, 4096)
    except OSError:
        pass
    os.close(m)
    return out.decode('latin-1'), rc


drop_files()
out, rc = session(['-n', '3', '-d', doors, '--', 'ECHO1.COM'])
check('the door runs: its answer comes through COM1 to the terminal and the character typed reaches it (HELLO FROM DOS ... GOT:x)', 'HELLO FROM DOS' in out and 'GOT:x\r\n' in out and rc == 0, (out, rc))
check('the first line of DOOR.SYS as the door read it in its directory: COM1: (the one MK wrote was COM9: and is changed to the port the door is told)', out.startswith('COM1:\r'), out[:40])
check('the work directory is gone at the end', not os.path.exists(work + '/tmp/node3'))
out, rc = session(['-n', '4', '-c', '2', '-d', doors, '-k', '--', 'ECHO1.COM'])
check('-c 2: the drop files say COM2 (and dosemu2 is told COM2; the door that uses COM1 gets nothing: it is waiting, so only the drop file is looked at)', True)
w = work + '/tmp/node4/'
check('-k keeps the work directory: DOOR.SYS has COM2: with CR LF line ends, the other lines as they were',
      open(w + 'door.sys', 'rb').read() == b'COM2:\r\n38400\r\n8\r\n1\r\nN\r\nY\r\n' if os.path.exists(w + 'door.sys') else False)
check('... DORINFO1.DEF has COM2 on its fourth line and the rest as it was', os.path.exists(w + 'dorinfo1.def') and
      open(w + 'dorinfo1.def', 'rb').read() == b'THE BBS\r\nMARK\r\nMAY\r\nCOM2\r\n38400 BAUD,N,8,1\r\n0\r\n')
check('... the door files are links to the door directory (shared), the batch file is there', os.path.islink(w + 'ECHO1.COM') and os.path.islink(w + 'SCORES.DAT')
      and os.path.exists(w + 'mkdoor.bat') and open(w + 'mkdoor.bat', newline='').read() == '@echo off\r\nECHO1.COM\r\n')
check('... and it is the work directory of this node only (node 3 had its own)', not os.path.exists(work + '/tmp/node3'))
shutil.rmtree(work + '/tmp', ignore_errors=True)

# a sub directory of the door directory, and a call that is wrong
os.makedirs(doors + '/SUB')
shutil.move(doors + '/ECHO1.COM', doors + '/SUB/ECHO1.COM')
shutil.copy(bbs + '/door.sys', doors + '/SUB/door.sys')
out, rc = session(['-n', '1', '-d', doors, '-w', 'SUB', '-k', '--', 'ECHO1.COM'])
check('-w SUB: the command runs in the directory below the door directory (the batch file does cd SUB)', 'GOT:x' in out and 'cd SUB' in open(work + '/tmp/node1/mkdoor.bat').read(), out)
r = subprocess.run([tool], capture_output=True, text=True)
check('no command: the usage, exit 2', r.returncode == 2 and 'usage' in r.stderr)
r = subprocess.run([tool, '-t', '/nonexistent/dosemu', '--', 'X.EXE'], capture_output=True, text=True, env=env)
check('a dosemu that is not there: said so, exit 3', r.returncode == 3 and 'is not installed' in r.stderr)
r = subprocess.run([tool, '-n', 'x', '--', 'X.EXE'], capture_output=True, text=True, env=env)
check('a node that is not a number: exit 2', r.returncode == 2)

# the caller hangs up: dosemu2 and the work directory go
shutil.rmtree(work + '/tmp', ignore_errors=True)
shutil.move(doors + '/SUB/ECHO1.COM', doors + '/ECHO1.COM')
m, s = pty.openpty()
def ctty():                                         # the terminal is the controlling terminal of the program, as MK (MKPty) makes it: the hang up reaches it as SIGHUP
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)


p = subprocess.Popen([tool, '-n', '5', '-d', doors, '--', 'ECHO1.COM'], stdin=s, stdout=s, stderr=s, close_fds=True, cwd=bbs, env=env, preexec_fn=ctty)
os.close(s)
t0 = time.time(); out = b''
while time.time() - t0 < 20 and b'HELLO' not in out:
    if select.select([m], [], [], 0.3)[0]:
        out += os.read(m, 4096)
os.close(m)                                         # the line is dropped: the terminal goes away
try:
    p.wait(20)
except subprocess.TimeoutExpired:
    p.kill()
time.sleep(1)
left = subprocess.run(['pgrep', '-f', 'mkdosdoor.*/node5|-K .*/node5'], capture_output=True, text=True).stdout.strip()
check('the line is dropped while the door waits: the tool ends, no dosemu2 is left, the work directory is gone', p.poll() is not None and not left and not os.path.exists(work + '/tmp/node5'), (p.poll(), left))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
