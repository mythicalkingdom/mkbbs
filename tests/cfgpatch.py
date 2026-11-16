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
