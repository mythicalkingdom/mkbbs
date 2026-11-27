# SPDX-License-Identifier: GPL-3.0-or-later
"""Helpers for the tests that run a program on a private copy of the sample BBS.

The paths in the binary configuration (config.mk) are Pascal strings in fixed size fields, so a path can be
replaced only by one that is not longer: patch() writes the new text in place and pads with zeros (the file
keeps its size and every later field stays where it is).  short_dir() makes a short temporary directory
(/tmp/mXXXXXXXX) for the copy, removed at exit."""
import atexit, shutil, tempfile


def short_dir():
    d = tempfile.mkdtemp(prefix='m', dir='/tmp')
    atexit.register(shutil.rmtree, d, True)
    return d


def patch(cfg_path, root, fn):
    """Every length-prefixed string of the file that starts with root is replaced by fn(old), in place."""
    d = bytearray(open(cfg_path, 'rb').read())
    i = n = 0
    while i < len(d) - 3:
        L = d[i]
        s = bytes(d[i + 1:i + 1 + L])
        if L > 0 and s.startswith(root):
            new = fn(s)
            assert len(new) <= len(s), 'the path %r is longer than %r' % (new, s)
            d[i] = len(new)
            d[i + 1:i + 1 + len(s)] = new + b'\0' * (len(s) - len(new))
            i += 1 + len(s)
            n += 1
        else:
            i += 1
    open(cfg_path, 'wb').write(d)
    return n


def fix_sample(cfg_dir):
    """The sample BBS has DOS-era names inside config.mk: the language file is "PROMPTS".  Names that come from the
    configuration are used exactly as written and the files are lower case, so a private copy gets the lower case name."""
    import os
    p = os.path.join(cfg_dir, 'config.mk')
    if os.path.exists(p):
        patch(p, b'PROMPTS', lambda s: s.lower())
        # the log of a real system is somewhere else (/var/log/...): a private copy logs next to its directory, in <parent>/l
        # (when that path fits in the field; read it with log_file())
        newlog = log_file(cfg_dir).encode()
        patch(p, b'/var/log/', lambda s: newlog if len(newlog) <= len(s) else s)


def log_file(cfg_dir):
    """Where the BBS log of the private copy in cfg_dir is written (see fix_sample)"""
    import os
    return os.path.join(os.path.dirname(os.path.abspath(cfg_dir)), 'l')


def snapshot(path):
    """The place to copy a part of the sample BBS from: the snapshot of the fixture (tests/fixture.py) for the live sample directory, the menus, the node list
    and the mkqwk configuration, the path itself for anything else.  The snapshot is made when it is not there (build.sh makes it at its start)."""
    import os, sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import fixture
    real = os.path.realpath(path)
    for name in fixture.PARTS:
        if real == os.path.realpath(fixture.live(name)):
            fixture.ensure()
            return fixture.fix(name)
    return path
