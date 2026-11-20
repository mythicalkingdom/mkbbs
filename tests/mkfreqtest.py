#!/usr/bin/env python3
"""mkfreq (the answer to an FTN file request): security profiles, file areas with "Allow file requests", magic names, passwords,
limits, refusals, on a private copy of the sample BBS.  usage: mkfreqtest.py <build dir> <work dir>"""
import json, os, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
src = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(src) or not os.path.exists(build + '/mkfreq'):
    print('skip: no sample BBS or no mkfreq'); sys.exit(0)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkfreq: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
ra = tmp + '/r'
shutil.copytree(src, ra, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk')) or not os.access(os.path.join(d, f), os.R_OK)
                                              or f.lower().endswith(('.pwbak', '.old'))])
cfgpatch.fix_sample(ra)
cfgpatch.patch(os.path.join(ra, 'config.mk'), (repo + '/bbs/').encode(), lambda s: (ra + '/').encode() if s == (src + '/').encode() else s)
env = dict(os.environ, MK=ra)

# the files
fa = tmp + '/fa'
for d, files in (('pub', {'this.arc': 100, 'readme.txt': 50, 'a1.zip': 10, 'a2.zip': 10, 'a3.zip': 10, 'a4.zip': 10, 'a5.zip': 10, 'big.zip': 2048}),
                 ('sec', {'secret.zip': 20}), ('nof', {'hidden.zip': 20}), ('flg', {'flagged.zip': 20}),
                 ('nl', {'nodelist.001': 30, 'nodelist.002': 31}), ('magic', {'private.zip': 40})):
    os.makedirs(fa + '/' + d)
    for n, size in files.items():
        open(fa + '/%s/%s' % (d, n), 'wb').write(bytes([65]) * size)
open(ra + '/magic.txt', 'w').write('; magic names\nNODELIST %s/nl/nodelist.*\nFILES @LIST\nSECRETS %s/magic/private.zip pw1\n' % (fa, fa))

# the configuration: four file areas, a mailer with file requests on, two links
cj = os.path.join(work, 'cj')
os.makedirs(cj)
envj = dict(env, MKJSON=cj)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj, check=True, capture_output=True)
dj = json.load(open(cj + '/bbsconfig.json', encoding='utf-8'))
sec = lambda lv, fl=0: {'Level': lv, 'Flags': fl}
for n, (name, path, attr, lv, fl) in {'201': ('Public', 'pub', 32, 10, 0), '202': ('Members', 'sec', 32, 120, 0), '203': ('No requests', 'nof', 0, 10, 0),
                                      '204': ('Flagged', 'flg', 32, 10, 4)}.items():
    dj['files'][n] = {'Name': name, 'ShortName': name[:8], 'FilePath': '%s/%s/' % (fa, path), 'ViewSec': sec(lv, fl), 'DLSec': sec(lv, fl),
                      'ULSec': sec(255), 'PFileSec': sec(255), 'Attr': attr, 'Select': ''}
mc = dj['mailer']
mc['Flags'] |= 64
mc['ReqSec'] = sec(50)
mc['ReqMagicFile'] = 'magic.txt'
mc['ReqMaxFiles'] = 4
mc['ReqMaxKb'] = 1
mc['ReqAttr'] = 2                      # tell the requester by netmail
def link(addr, reqlevel):
    return {'Addr': {'Zone': 1, 'Net': 110, 'Node': addr, 'Point': 0}, 'Name': 'Link %d' % addr, 'Host': '', 'Port': 0, 'Password': '', 'Flags': 0,
            'PollMin': 0, 'UseAka': 0, 'ReqSec': sec(reqlevel), 'ReqAttr': 0}


mc['Links'] = {'1': link(290, 150), '2': link(291, 5)}
json.dump(dj, open(cj + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj, check=True, capture_output=True)
outb = tmp + '/outb'
os.makedirs(tmp + '/in')
subprocess.run([build + '/tosssetup', tmp + '/in', outb, tmp + '/un'], env=env, capture_output=True, text=True)


def ask(who, mode, lines, eol='\r'):
    req, ans = work + '/req', work + '/ans'
    open(req, 'wb').write((eol.join(lines) + eol).encode())
    if os.path.exists(ans):
        os.remove(ans)
    r = subprocess.run([build + '/mkfreq', who, mode, req, ans], env=env, capture_output=True, text=True)
    sends, notes = [], []
    if os.path.exists(ans):
        for l in open(ans, encoding='latin-1').read().split('\n'):
            p = l.split('\t')
            if p[0] == 'SEND':
                sends.append((p[1], p[2] if len(p) > 2 else ''))
            elif p[0] == 'NOTE':
                notes.append(p[1])
    return r, sends, notes


def names(sends):
    return sorted(os.path.basename(p) for p, _ in sends)


# a link with level 150 (CR line ends, as the spec says)
r, s, n = ask('1:110/290', 'secure', ['this.arc !whatever', 'SECRET.ZIP', 'hidden.zip', 'flagged.zip', 'nothere.zip'])
check('a link with a profile: a file of a file area that allows requests, and one it has the level for', names(s) == ['secret.zip', 'this.arc'] and r.returncode == 0)
check('... paths are absolute, the files are kept (no ^)', all(p.startswith('/') and a == '' for p, a in s))
check('... an area without the option, an area that needs a flag the profile lacks, and a file that is not there: not found',
      sorted(x.split(':')[0] for x in n) == ['flagged.zip', 'hidden.zip', 'nothere.zip'] and all('not found' in x for x in n))
check('the password given for an unprotected file is not written to the log (stdout), only stars', '!***' in r.stdout and 'whatever' not in r.stdout)

# the global request user (a system that is not a link): level 50, so no members area
r, s, n = ask('1:110/999', 'secure', ['*.arc', 'secret.zip'])
check('a system that is not a link gets the global file request user (level 50): the public area, not the members area',
      names(s) == ['this.arc'] and any('secret.zip' in x and 'not found' in x for x in n))
r, s, n = ask('1:110/291', 'secure', ['this.arc'])
check('a link whose profile is too low gets nothing from areas that need more', s == [] and any('not found' in x for x in n))

# wildcards, case, line ends
r, s, n = ask('1:110/290', 'secure', ['THIS.*', 'README.TXT'], eol='\n')
check('wildcards and upper case names (LF line ends)', names(s) == ['readme.txt', 'this.arc'])
r, s, n = ask('1:110/290', 'secure', ['readme.txt', 'this.arc'], eol='\r\n')
check('CR LF line ends', names(s) == ['readme.txt', 'this.arc'])

# limits: 4 files, 1 KB
r, s, n = ask('1:110/290', 'secure', ['a*.zip'])
check('at most 4 files for one request: four are sent, the rest said so', len(s) == 4 and any('at most 4 files' in x for x in n))
r, s, n = ask('1:110/290', 'secure', ['readme.txt', 'big.zip', 'this.arc'])
check('at most 1 KB: a file that does not fit is not sent and said so (the request goes on)', 'big.zip' not in names(s) and any('at most 1 KB' in x for x in n))

# magic names
r, s, n = ask('1:110/290', 'secure', ['NODELIST'])
check('a magic name with a wildcard path: the files', names(s) == ['nodelist.001', 'nodelist.002'])
r, s, n = ask('1:110/290', 'secure', ['FILES'])
lst = [p for p, a in s]
check('FILES (@LIST): a list made for the request, sent and deleted after (^)', len(s) == 1 and s[0][1] == '^' and lst[0].endswith('files.lst') and os.path.exists(lst[0]))
body = open(lst[0], encoding='latin-1').read()
check('... it lists the areas the profile may request and their files, and no others',
      'Public' in body and 'Members' in body and 'this.arc' in body and 'secret.zip' in body and 'No requests' not in body and 'Flagged' not in body
      and 'hidden.zip' not in body and 'flagged.zip' not in body)
r, s, n = ask('1:110/290', 'secure', ['SECRETS !pw1'])
check('a magic name with a password: the right one sends the file', names(s) == ['private.zip'])
r, s, n = ask('1:110/290', 'secure', ['SECRETS !wrong', 'SECRETS'])
check('... a wrong or missing one does not', s == [] and len(n) == 2 and all('password' in x for x in n))
r, s, n = ask('1:110/290', 'unsecure', ['SECRETS !pw1', 'this.arc'])
check('... and not in a session without a password, whatever is given; ordinary files go on', names(s) == ['this.arc'] and any('needs a session with a password' in x for x in n))
check('... no password is in the output', 'pw1' not in r.stdout and 'pw1' not in r.stderr)


# ---- the same through SRIF (mkfreq -S <srif file>): what binkd and other SRIF mailers run
def srif(aka, status, lines, env_extra=None):
    req, rsp, sf = work + '/sreq', work + '/srsp', work + '/srif'
    open(req, 'wb').write(('\r'.join(lines) + '\r').encode())
    if os.path.exists(rsp):
        os.remove(rsp)
    open(sf, 'w').write('Sysop Some Sysop\nAKA %s@fidonet\nAKA 1:1/1\nBaud 115200\nTime -1\nRequestList %s\nResponseList %s\nRemoteStatus %s\n'
                        'SystemStatus LISTED\n' % (aka, req, rsp, status))
    r = subprocess.run([build + '/mkfreq', '-S', sf], env=dict(env, **(env_extra or {})), capture_output=True, text=True)
    out = []
    if os.path.exists(rsp):
        out = [l for l in open(rsp, encoding='latin-1').read().split('\n') if l]
    return r, out


r, o = srif('1:110/290', 'PROTECTED', ['this.arc !whatever', 'SECRET.ZIP', 'hidden.zip', 'flagged.zip', 'nothere.zip'])
check('SRIF: the first AKA (the domain is dropped) is the requester: the link of level 150 gets its files', sorted(os.path.basename(l[1:]) for l in o) == ['secret.zip', 'this.arc'] and r.returncode == 0, (r.stdout, o))
check('... every line is "+" and an absolute path: nothing is marked for deleting, and there are no NOTE lines',
      all(l[0] == '+' and l[1] == '/' for l in o) and not any('NOTE' in l for l in o))
r, o = srif('1:110/290', 'PROTECTED', ['FILES'])
check('SRIF: FILES (@LIST): one line "=" and the path of the list (erased by the mailer after it was sent), the file exists',
      len(o) == 1 and o[0][0] == '=' and o[0].endswith('files.lst') and os.path.exists(o[0][1:]), o)
tmpd = work + '/mkbink-tmp'
os.makedirs(tmpd, exist_ok=True)
r, o = srif('1:110/290', 'PROTECTED', ['FILES'], {'MKBINK_TMP': tmpd})
check('... with MKBINK_TMP the list is made in that directory (the one place mkbink deletes from)', len(o) == 1 and o[0] == '=' + tmpd + '/files.lst' and os.path.exists(tmpd + '/files.lst'), o)
r, o = srif('1:110/290', 'UNPROTECTED', ['SECRETS !pw1', 'this.arc'])
check('SRIF: RemoteStatus UNPROTECTED is an unsecure session: a magic name with a password is refused, ordinary files go on',
      [os.path.basename(l[1:]) for l in o] == ['this.arc'], o)
r, o = srif('1:110/291', 'PROTECTED', ['this.arc', 'secret.zip'])
check('SRIF: another link, its own (lower) profile: only what it has the level for', [os.path.basename(l[1:]) for l in o] == ['this.arc'] or o == [], o)
r = subprocess.run([build + '/mkfreq', '-S', work + '/nonexistent.srif'], env=env, capture_output=True, text=True)
check('SRIF: a file that is not there: exit 1', r.returncode == 1)

# refusals
r, s, n = ask('1:110/290', 'secure', ['../etc/passwd', 'a/b.zip', '.hidden', 'x\\y.zip', '+5 first.zip'])
check('names with slashes, a leading dot, backslashes or a sign: refused', s == [] and sum('not a file name' in x for x in n) == 5)

# update requests: + = the files that match and are newer than the time, - = those dated up to and including it
for name, t in (('a1.zip', 1000000000), ('a2.zip', 1100000000), ('a3.zip', 1200000000), ('a4.zip', 1300000000), ('a5.zip', 1400000000)):
    os.utime(fa + '/pub/' + name, (t, t))
os.utime(fa + '/nl/nodelist.001', (1000, 1000))
os.utime(fa + '/nl/nodelist.002', (2000, 2000))
r, s, n = ask('1:110/290', 'secure', ['a?.zip +1050000000'])
check('update +: the files newer than the time', names(s) == ['a2.zip', 'a3.zip', 'a4.zip', 'a5.zip'] and n == [])
r, s, n = ask('1:110/290', 'secure', ['a?.zip +1100000000'])
check('... newer, not equal: a file dated exactly then is not sent', names(s) == ['a3.zip', 'a4.zip', 'a5.zip'])
r, s, n = ask('1:110/290', 'secure', ['a?.zip -1100000000'])
check('update -: the files up to and including the time (a file dated exactly then is sent)', names(s) == ['a1.zip', 'a2.zip'] and n == [])
r, s, n = ask('1:110/290', 'secure', ['a?.zip +9999999999', 'zzz.zip +5'])
check('nothing newer is no problem (no file, no note); a name that matches nothing is still "not found"',
      s == [] and len(n) == 1 and n[0].startswith('zzz.zip: not found') and 'nothing that fits the date' in r.stdout)
r, s, n = ask('1:110/290', 'secure', ['NODELIST +1500'])
check('a magic name takes the update request too', names(s) == ['nodelist.002'])
r, s, n = ask('1:110/290', 'secure', ['SECRETS !pw1 +5', 'this.arc !x -9999999999'])
check('a password and an update request together (password first)', names(s) == ['private.zip', 'this.arc'])
r, s, n = ask('1:110/290', 'secure', ['FILES +5'])
check('FILES (@LIST) is made whatever the request says', len(s) == 1 and s[0][1] == '^')
r, s, n = ask('1:110/290', 'secure', ['x.zip +12345678901', 'y.zip +12a', 'z.zip -'])
check('a bad update request is said so (no more than 10 digits)', s == [] and sum('not a sign and a time' in x for x in n) == 3)
r, s, n = ask('1:110/290', 'secure', ['readme.txt +5', 'this.arc'], eol='\r\n')
check('update requests and CR LF line ends', names(s) == ['readme.txt', 'this.arc'])

# the request that is not readable
r = subprocess.run([build + '/mkfreq', '1:110/290', 'secure', work + '/nothere', work + '/ans'], env=env, capture_output=True, text=True)
check('a request file that is not there: exit 1', r.returncode == 1)
# file requests switched off in the Mailer page
cj2 = os.path.join(work, 'cj2')
os.makedirs(cj2)
envj2 = dict(env, MKJSON=cj2)
subprocess.run([build + '/mkcfgcvt', '-y', '1', '5'], env=envj2, check=True, capture_output=True)
d2 = json.load(open(cj2 + '/bbsconfig.json', encoding='utf-8'))
d2['mailer']['Flags'] &= ~64
json.dump(d2, open(cj2 + '/bbsconfig.json', 'w', encoding='utf-8'), ensure_ascii=False)
subprocess.run([build + '/mkcfgcvt', '-y', '5', '1'], env=envj2, check=True, capture_output=True)
r, s, n = ask('1:110/290', 'secure', ['this.arc'])
check('file requests switched off: nothing is sent, a note says so', s == [] and any('not answered here' in x for x in n))

r = subprocess.run([build + '/mkfreq'], env=env, capture_output=True, text=True)
check('no arguments: usage, exit 1', r.returncode == 1 and 'Usage' in r.stdout)
print('failures:', fails)
sys.exit(1 if fails else 0)
