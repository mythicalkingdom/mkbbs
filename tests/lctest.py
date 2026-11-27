#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""MKLC: every sample *.LC of the original folder is turned back into text, compiled again and must
come out byte for byte the same.   usage: lctest.py <mklc> <work dir>"""
import glob, os, shutil, struct, subprocess, sys

mklc, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
here = os.path.dirname(os.path.abspath(__file__))
orig = os.path.join(here, '..', 'original')
os.makedirs(work, exist_ok=True)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mklc: ' + name)
    if not ok:
        fails += 1


def decompile(data):
    """HighLine, then a word per line (1 based position of the text), texts = length byte, chars, 0"""
    high = struct.unpack_from('<H', data, 0)[0]
    lines = []
    for n in range(1, high + 1):
        pos = struct.unpack_from('<H', data, 2 * n)[0]
        if pos:
            ln = data[pos - 1]
            lines.append((pos, n, data[pos:pos + ln]))
    lines.sort()                       # the order of the texts in the file = the order of the source
    return [(n, text) for pos, n, text in lines]


files = sorted(glob.glob(os.path.join(orig, '*.LC')))
check('there are sample language files (%d)' % len(files), len(files) > 0)
for f in files:
    data = open(f, 'rb').read()
    lines = decompile(data)
    name = os.path.basename(f)[:-3]
    src = os.path.join(work, name + '.TXT')
    with open(src, 'wb') as t:
        t.write(b'; ' + name.encode() + b'\r\n')                   # a comment line is ignored
        for n, text in lines:
            t.write(str(n).encode() + b' ' + text + b'\r\n')
    out = os.path.join(work, name + '.lc')
    if os.path.exists(out):
        os.remove(out)
    r = subprocess.run([mklc, src], capture_output=True, text=True)
    same = os.path.exists(out) and open(out, 'rb').read() == data
    check('%s: %d texts, compiled again = the original (%d bytes)' % (name, len(lines), len(data)),
          r.returncode == 0 and same)

# the author's own sources (tests/lang/NAME.TXT, copies of his files) compile to exactly his NAME.LC
for f in files:
    name = os.path.basename(f)[:-3]
    txt = os.path.join(here, 'lang', name + '.TXT')
    if not os.path.exists(txt):
        continue
    d2 = os.path.join(work, 'src_' + name)
    os.makedirs(d2, exist_ok=True)
    shutil.copy(txt, d2)
    r = subprocess.run([mklc, os.path.join(d2, name + '.TXT')], capture_output=True, text=True)
    out = os.path.join(d2, name + '.lc')
    check('%s.TXT (his source) compiles to his %s.LC' % (name, name),
          r.returncode == 0 and os.path.exists(out) and open(out, 'rb').read() == open(f, 'rb').read())
for name in ('MKUPACK', 'VT100'):                      # sources without a compiled file here
    txt = os.path.join(here, 'lang', name + '.TXT')
    if os.path.exists(txt):
        d2 = os.path.join(work, 'src_' + name)
        os.makedirs(d2, exist_ok=True)
        shutil.copy(txt, d2)
        r = subprocess.run([mklc, os.path.join(d2, name + '.TXT')], capture_output=True, text=True)
        check('%s.TXT compiles without errors' % name, r.returncode == 0)

# errors: no argument, a missing file, a wrong line number is reported and left out
r = subprocess.run([mklc], capture_output=True, text=True)
check('no argument: syntax message', r.returncode == 10 and 'Proper syntax' in r.stdout)
r = subprocess.run([mklc, os.path.join(work, 'nothere.txt')], capture_output=True, text=True)
check('missing file', r.returncode == 10 and 'Does not exist' in r.stdout)
bad = os.path.join(work, 'bad.txt')
open(bad, 'w').write('1 First\nx Second\n3 Third\n')
r = subprocess.run([mklc, bad], capture_output=True, text=True)
d = open(os.path.join(work, 'bad.lc'), 'rb').read() if os.path.exists(os.path.join(work, 'bad.lc')) else b''
lines = dict(decompile(d)) if d else {}
check('wrong line number: reported, others compiled', r.returncode == 14 and lines.get(1) == b'First' and lines.get(3) == b'Third' and 2 not in lines)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
