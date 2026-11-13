#!/usr/bin/env python3
"""Translate an Object Professional entry-screen unit (CFGxxx.PAS) to a CfgForm unit.
usage: cfgconv.py original/CFGGEN.PAS src/CfgGen.pas"""
import re, sys

def split_args(s):
    out = []; d = 0; q = False; cur = ''
    for c in s:
        if c == "'":
            q = not q
        if not q:
            if c in '([': d += 1
            elif c in ')]': d -= 1
            elif c == ',' and d == 0:
                out.append(cur.strip()); cur = ''; continue
        cur += c
    if cur.strip(): out.append(cur.strip())
    return out

def balanced(t, i):
    """t[i] is just after '(' ; return index of the matching ')'"""
    d = 1; q = False
    while i < len(t):
        c = t[i]
        if c == "'": q = not q
        elif not q:
            if c == '(': d += 1
            elif c == ')':
                d -= 1
                if d == 0: return i
        i += 1
    raise ValueError('unbalanced')

def mask_width(m):
    mm = re.match(r"CharStr\(\s*'.'\s*,\s*(\d+)\s*\)", m, re.I)
    if mm: return int(mm.group(1))
    if m.startswith("'") and m.endswith("'"): return len(m) - 2
    return 0

def hint_of(prompt):
    p = prompt
    m = re.match(r"^'(.*)'$", p)
    if m:
        s = m.group(1).rstrip(': ')
        return "'" + s + "'"
    return "''"

def convert(src, dst):
    t = open(src, encoding='latin-1').read().replace('\r', '').replace('\x1a', '')
    notes = []
    uname = re.search(r'(?im)^\s*Unit\s+(\w+)', t).group(1)
    newname = 'Cfg' + uname[3:].capitalize() if uname.upper().startswith('CFG') else uname
    # interface procedures
    iface = t[:re.search(r'(?im)^\s*Implementation', t).start()]
    ipr = re.findall(r'(?im)^\s*((?:Procedure|Function)\s+[^\n;]*;)', iface)
    impl = t[re.search(r'(?im)^\s*Implementation', t).end():]
    # unit uses -> keep non-Op units
    um = re.search(r'(?is)\buses\b(.*?);', impl)
    uses = [u.strip() for u in um.group(1).split(',')]
    keep = [u for u in uses if not re.match(r'(?i)^(Op\w+|Dos|CfgYN|OpEntry|MKColor|CfgSec2x)$', u)]
    # types
    tm = re.search(r'(?is)^\s*Type\b.*?(?=^\s*(?:Var|const|\{\$F\+\}|procedure|function)\b)', impl, re.M)
    types = tm.group(0).rstrip() + '\n' if tm else ''
    # unit var section
    vm = re.search(r'(?is)^\s*Var\b(.*?)(?=^\s*(?:\{\$F\+\}|procedure|function|const|Type)\b)', impl, re.M)
    vlines = []
    if vm:
        for line in vm.group(1).split('\n'):
            ls = line.strip()
            if not ls: continue
            if re.match(r'(?i)^(ES|Status)\s*:', ls) or ls.startswith('{'): continue
            vlines.append('  ' + ls)
    scrolling = bool(re.search(r'ScrollingEntryScreen', impl))
    # PostEdit AddBackSlash
    dirs = set(re.sub(r'\s+', '', x) for x in re.findall(r'AddBackSlash\(\s*([^)]*?)\s*\)', impl))
    # PreEdit special
    special = {}
    for m in re.finditer(r"(?i)(id\w+)\s*:\s*(GetSecurity|GetColor)\(\s*([^,]+?)\s*,\s*ESP\s*,\s*\w+\s*,\s*('[^']*')\s*\)", impl):
        special[m.group(1)] = (m.group(2), re.sub(r'\s+', '', m.group(3)), m.group(4))
    # window, header
    im = re.search(r'(?is)function\s+InitEntryScreen.*?\n\s*begin\b(.*?)InitEntryScreen\s*:=\s*RawError', impl)
    body = im.group(1)
    win = re.search(r'InitCustom\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)', body)
    x1, y1, x2, y2 = map(int, win.groups()) if win else (0, 0, 0, 0)
    hm = re.search(r'AddHeader\(\s*(.*?)\s*,\s*heTC\s*\)', body, re.S)
    title = hm.group(1) if hm else "''"
    if re.match(r"^'\[\s*(.*?)\s*\]'$", title):
        title = "'" + re.match(r"^'\[\s*(.*?)\s*\]'$", title).group(1) + "'"
    # fields in order
    idorder = re.findall(r'(?m)^\s*(id\w+)\s*=', impl)
    calls = []
    cur_id = None
    pos = 0
    padzero = False
    for m in re.finditer(r'(\{id\w+:\})|(\b(Add\w+Field)\s*\()|(UserSet1\s*:=[^;]*;)|(esFieldOptionsOn\(([^)]*)\))|(SetPadChar\(\x27(.)\x27\))', body):
        if m.group(1): cur_id = m.group(1)[1:-2]; continue
        if m.group(7): padzero = (m.group(8) == '0'); continue
        if m.group(3):
            end = balanced(body, m.end())
            args = split_args(body[m.end():end])
            calls.append((m.group(3), args, cur_id, padzero))
            cur_id = None
        elif m.group(4):
            notes.append('UserSet1: ' + m.group(4))
        elif m.group(5) and 'ForceUpper' in m.group(6):
            notes.append('efForceUpper used')
    nf = [c for c in calls if c[0] != 'AddTextField']
    if len(idorder) == len(nf):
        calls = [(k, a, (idorder[nf.index((k, a, f, z))] if k != 'AddTextField' else f), z) for (k, a, f, z) in calls]
    else:
        notes.append('id count %d != fields %d (comments used)' % (len(idorder), len(nf)))
    lines = []
    extra_uses = set()
    maxrow = 0
    for kind, a, fid, zpad in calls:
        def emit_at(pr, pc, fr, fc):
            return 'F.At(%s, %s, %s, %s);' % (pr, pc, fr, fc)
        if kind == 'AddTextField':
            lines.append('F.At(%s, %s, 0, 0);' % (a[1], a[2]))
            lines.append('F.AddText(%s);' % a[0])
            continue
        if kind == 'AddStringField':
            prompt, pr, pc, mask, fr, fc, ln, hi, var = a[:9]
            w = mask_width(mask)
            lines.append(emit_at(pr, pc, fr, fc))
            try:
                if w and int(ln) != w: lines.append('F.Show(%d);' % w)
            except ValueError: pass
            if re.sub(r'\s+', '', var) in dirs:
                lines.append('F.AddDir(%s, %s, %s, %s);' % (prompt, var, ln, hint_of(prompt)))
            else:
                if re.fullmatch(r"'[01xX\-]+'", mask) and mask not in ("'XXXX'",) and not set(mask.strip("'")) <= {'X'}:
                    notes.append('string mask %s on %s' % (mask, prompt))
                lines.append('F.AddString(%s, %s, %s, %s);' % (prompt, var, ln, hint_of(prompt)))
        elif kind in ('AddByteField', 'AddNumericByteField', 'AddWordField', 'AddLongField'):
            prompt, pr, pc, mask, fr, fc, hi, mn, mx, var = a[:10]
            size = {'AddByteField': 1, 'AddNumericByteField': 1, 'AddWordField': 2, 'AddLongField': 4}[kind]
            lines.append(emit_at(pr, pc, fr, fc))
            if zpad: lines.append('F.ZeroPad(%d);' % len(mask.strip("'")))
            if mask.strip("'").upper() and set(mask.strip("'").upper()) == {'K'}:
                lines.append('F.AddHex(%s, %s, %d, %s);' % (prompt, var, size, hint_of(prompt)))
            else:
                lines.append('F.AddNumber(%s, %s, %d, %s, %s, %s);' % (prompt, var, size, mn, mx, hint_of(prompt)))
        elif kind == 'AddYesNoField':
            prompt, pr, pc, mask, fr, fc, hi, var = a[:8]
            lines.append(emit_at(pr, pc, fr, fc))
            lines.append('F.AddYesNo(%s, %s, %s);' % (prompt, var, hint_of(prompt)))
        elif kind == 'AddCharField':
            prompt, pr, pc, mask, fr, fc, hi, mn, mx, var = a[:10]
            lines.append(emit_at(pr, pc, fr, fc))
            lines.append('F.AddChar(%s, %s, %s);' % (prompt, var, hint_of(prompt)))
        else:
            notes.append('UNHANDLED ' + kind)
            continue
        if fid and fid in special:
            fn, v, ttl = special[fid]
            if fn == 'GetSecurity':
                lines.append('F.OnF2(EditSecurity, @%s, %s);' % (v, ttl)); extra_uses.add('CfgSec2')
            else:
                lines.append('F.OnF2(PickColor, @%s, %s);' % (v, ttl)); extra_uses.add('CfgColor')
    # the Do procedure(s): the ones named in the interface
    procs = []
    for decl in ipr:
        name = re.match(r'(?i)(?:Procedure|Function)\s+(\w+)', decl).group(1)
        ms = [m for m in re.finditer(r'(?im)^\s*Procedure\s+%s\b[^\n]*\n' % name, impl)]
        if not ms: notes.append('no body for ' + name); continue
        m = ms[-1]
        end = re.search(r'(?m)^  End;\s*$', impl[m.end():])
        pbody = impl[m.end():m.end() + end.end()]
        procs.append((name, decl, pbody))
    out = []
    out.append('Unit %s;   {Converted from %s for Free Vision}\n\n{$I MKB.Def}\n\nInterface\n\n' % (newname, uname))
    for decl in ipr: out.append(decl + '\n')
    out.append('\nImplementation\n\n')
    u = ['MKString', 'MKGlobT', 'MKCfgAbs', 'CfgForm'] + [x for x in keep if x.lower() not in ('mkstring', 'mkglobt', 'mkcfgabs', 'cfgform')] + sorted(extra_uses)
    seen = []
    for x in u:
        if x.lower() not in [s.lower() for s in seen]: seen.append(x)
    out.append('Uses ' + ', '.join(seen) + ';\n\n')
    if types: out.append(types + '\n')
    if vlines:
        out.append('Var\n' + '\n'.join(vlines) + '\n\n')
    for name, decl, pbody in procs:
        # split var section and statements
        vm2 = re.match(r'(?is)\s*Var\b(.*?)\n\s*Begin\b(.*)\n\s*End;\s*$', pbody)
        if vm2:
            lvars = vm2.group(1).strip('\n'); stm = vm2.group(2)
        else:
            bm = re.match(r'(?is)\s*Begin\b(.*)\n\s*End;\s*$', pbody)
            lvars = ''; stm = bm.group(1)
        # remove mouse/status blocks
        stm = re.sub(r'(?is)\s*if\s+MouseInstalled\s+then.*?\n\s*end;', '', stm, count=1)
        stm = re.sub(r'(?is)\s*Status\s*:=\s*InitEntryScreen[^;]*;\s*if\s+Status\s*<>\s*0\s+then\s+begin.*?end;', '', stm, count=1)
        stm = re.sub(r'(?i)\s*HideMouse;', '', stm)
        sp = re.search(r'(?i)\s*ES\.Process;\s*', stm)
        if not sp:
            notes.append('no ES.Process in ' + name)
            pre, post = stm, ''
        else:
            pre = stm[:sp.start()]
            rest = stm[sp.end():]
            rest = re.sub(r'(?i)\s*ES\.Erase;', '', rest)
            rest = re.sub(r'(?i)\s*ES\.Done;', '', rest)
            post = rest
        out.append(decl.replace('Procedure', 'Procedure', 1).rstrip(';') + ';\n')
        out.append('  Var\n    F: CfgFormObj;\n' + ('\n'.join('  ' + l if not l.startswith('    ') else l for l in lvars.split('\n')) + '\n' if lvars else ''))
        out.append('\n  Begin\n')
        out.append(pre.strip('\n') + '\n')
        out.append('  F.Init(%s);\n' % title)
        if x2: out.append('  F.Window(%d, %d, %d, %d);\n' % (x1, y1, x2, y2))
        for l in lines: out.append('  ' + l + '\n')
        out.append('  If F.Execute Then\n    Begin\n')
        out.append('\n'.join(('  ' + l if l.strip() else l) for l in post.strip('\n').split('\n')) + '\n')
        out.append('    End;\n')
        # dispose UR kept in post? ensure
        out.append('  End;\n\n\n')
    out.append('End.\n')
    text = ''.join(out)
    # Dispose(UR) must run whether or not the form was accepted: move it after the If block
    if re.search(r'(?i)^\s*Dispose\(UR\);', text, re.M):
        text = re.sub(r'(?im)^(\s*)Dispose\(UR\);\n(\s*End;\n)(\s*End;)', r'\2\1Dispose(UR);\n\3', text)
    open(dst, 'w', encoding='latin-1', newline='\n').write(text)
    return notes, scrolling

if __name__ == '__main__':
    n, s = convert(sys.argv[1], sys.argv[2])
    print(sys.argv[1], '->', sys.argv[2], 'notes:', n, 'SCROLLING' if s else '')
