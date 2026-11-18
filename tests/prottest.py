#!/usr/bin/env python3
"""MKProt against the real lrzsz (sz / rz, sx / rx, sb / rb) over a socketpair, both directions, for Zmodem, Xmodem (checksum
and CRC), 1k-Xmodem and Ymodem; Ymodem-G and 1k-Xmodem-G (lrzsz has none) between two MKProt; data that a text filter would damage:
every byte value, CR LF, CR NUL, IAC IAC, a few hundred KB.   usage: prottest.py <build dir> <work dir>"""
import os, shutil, subprocess, sys

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
if not all(shutil.which(x) for x in ('sz', 'rz', 'sx', 'rx', 'sb', 'rb')):
    print('skip: no lrzsz'); sys.exit(0)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'prot: ' + name)
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
data = bytes(range(256)) * 40 + b'\r\n' * 500 + b'\r\0' * 500 + b'\xff\xff' * 500 + b'\r\r\n\n\0\0' * 300 + os.urandom(100000)
open(work + '/data.bin', 'wb').write(data)
open(work + '/Data.Bin', 'wb').write(data)


def run(mode, proto, src, dest):
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest)
    try:
        return subprocess.run([build + '/prottest', mode, proto, src, dest], capture_output=True, text=True, timeout=60).stdout
    except subprocess.TimeoutExpired:
        return 'timeout'


def same(path, pad):
    """the file is the data; Xmodem has no size: the last block is filled with ^Z"""
    if not os.path.exists(path):
        return False
    got = open(path, 'rb').read()
    if pad:
        return got[:len(data)] == data and set(got[len(data):]) <= {0x1a} and len(got) - len(data) < pad
    return got == data


names = {'z': 'Zmodem', 'x': 'Xmodem (checksum)', 'c': 'Xmodem (CRC)', 'k': '1k-Xmodem', 'y': 'Ymodem', 'e': 'Xmodem, the receiver sees damaged blocks'}
for pr in ('z', 'x', 'c', 'k', 'e', 'y'):
    d = work + '/peer_' + pr
    out = run('send', pr, work + '/data.bin', d)
    got = {'z': 'data.bin', 'y': 'data.bin'}.get(pr, 'x.out')
    pad = 0 if pr in ('z', 'y') else (1024 if pr == 'k' else 128)
    check('send %s to the real receiver: ok, error 0, peer exit 0, the file is the same' % names[pr],
          'result send ok=TRUE error=0' in out and 'peer exit=0' in out and same(d + '/' + got, pad))
for pr in ('z', 'x', 'k', 'y'):
    d = work + '/recv_' + pr
    out = run('recv', pr, work + '/Data.Bin', d)
    got = {'z': 'Data.Bin', 'y': 'Data.Bin'}.get(pr, 'rx.bin')
    pad = 0 if pr in ('z', 'y') else 128
    check('receive %s from the real sender: ok, 1 file, the file is the same%s' % (names[pr], ', name with its case' if pr in ('z', 'y') else ''),
          'result recv ok=TRUE files=1' in out and 'peer exit=0' in out and same(d + '/' + got, pad))
for pr, nm in (('x', 'Xmodem'), ('k', '1k-Xmodem'), ('y', 'Ymodem'), ('g', 'Ymodem-G'), ('q', '1k-Xmodem-G')):
    d = work + '/pair_' + pr
    out = run('pair', pr, work + '/data.bin', d)
    got = {'y': 'data.bin', 'g': 'data.bin'}.get(pr, 'pair.bin')
    pad = 0 if pr in ('y', 'g') else (1024 if pr in ('k', 'q') else 128)
    check('%s between two MKProt: both ends ok, the file is the same' % nm, 'result send ok=TRUE error=0' in out and 'peer exit=0' in out and same(d + '/' + got, pad))
# a sender name like "..hidden" is made safe
shutil.copy(work + '/data.bin', work + '/..hidden')
out = run('recv', 'z', work + '/..hidden', work + '/safe')
check('a sender name like "..hidden" is made safe (no leading dots) and stays in the directory (Zmodem)', 'ok=TRUE' in out and os.path.exists(work + '/safe/hidden'))
out = run('recv', 'y', work + '/..hidden', work + '/safe2')
check('... and in Ymodem', 'ok=TRUE' in out and os.path.exists(work + '/safe2/hidden'))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
