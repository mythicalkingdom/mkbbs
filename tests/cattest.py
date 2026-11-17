#!/usr/bin/env python3
"""mkcat: CP437 text to the terminal.  usage: cattest.py <build dir> <work dir>"""
import os, pty, shutil, subprocess, sys

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
f = os.path.join(work, 't.txt')
open(f, 'wb').write(b'a\xb0\xdb\x82 \x1b[1mX\x1b[0m\r\n\x1azzz')
g = os.path.join(work, 'g.txt')   # resets: plain, with a foreground, with a background, with both, a colour without reset
open(g, 'wb').write(b'\x1b[0mA\x1b[mB\x1b[0;31mC\x1b[0;41mD\x1b[0;31;41mE\x1b[1;33mF\x1b[0;1;42;36mG')
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkcat: ' + name)
    if not ok:
        fails += 1


def run(*args, term=None, tty=False):
    env = {'PATH': os.environ['PATH']}
    if term:
        env['TERM'] = term
    cmd = [os.path.join(build, 'mkcat')] + list(args)
    if not tty:
        return subprocess.run(cmd, env=env, capture_output=True)
    m, s = pty.openpty()
    p = subprocess.Popen(cmd, env=env, stdout=s, stderr=subprocess.PIPE)
    os.close(s)
    p.wait()
    out = b''
    try:
        while True:
            c = os.read(m, 4096)
            if not c:
                break
            out += c
    except OSError:
        pass
    os.close(m)
    return subprocess.CompletedProcess(cmd, p.returncode, out.replace(b'\r\r\n', b'\r\n'), b'')


G0 = b'\x1b[37;40m'            # the DOS colours at the start (only where the text is UTF-8)
U = G0 + 'a░█é \x1b[1mX\x1b[0m\x1b[37;40m\r\n'.encode()
C = b'a\xb0\xdb\x82 \x1b[1mX\x1b[0m\r\n'
check('to a pipe: UTF-8, ESC sequences as they are, ^Z ends the text', run(f).stdout == U)
check('-u: UTF-8', run('-u', f, term='ansi', tty=True).stdout == U)
check('-c: CP437 as it is', run('-c', f).stdout == C)
check('a terminal that wants CP437 (TERM=ansi): as it is', run(f, term='ansi', tty=True).stdout == C)
check('a UTF-8 terminal (TERM=xterm): UTF-8', run(f, term='xterm', tty=True).stdout == U)
check('an unknown terminal type: CP437 as it is', run(f, term='nonesuch', tty=True).stdout == C)
r = run(os.path.join(work, 'nothere'))
check('a file that cannot be read: exit 1', r.returncode == 1 and b'cannot read' in r.stderr)
check('no file name: usage, exit 3', run().returncode == 3 and run('-x', f).returncode == 3)
want = G0 + b'\x1b[0m\x1b[37;40mA\x1b[m\x1b[37;40mB\x1b[0;31m\x1b[40mC\x1b[0;41m\x1b[37mD\x1b[0;31;41mE\x1b[1;33mF\x1b[0;1;42;36mG'
check('UTF-8: after a colour reset the missing DOS colour is added (none / foreground only / background only / both / no reset)', run(g).stdout == want)
check('CP437 (-c): no guard, the text as it is', run('-c', g).stdout == open(g, 'rb').read())
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
