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


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'mkfreq: ' + name)
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

# refusals
r, s, n = ask('1:110/290', 'secure', ['../etc/passwd', 'a/b.zip', '.hidden', 'x\\y.zip', 'bad.zip +599634000', 'other.zip -599634000'])
check('names with slashes, a leading dot, backslashes: refused; update requests: not supported, said so',
      s == [] and sum('not a file name' in x for x in n) == 4 and sum('update requests' in x for x in n) == 2)

# the note for the netmail (Tell by netmail): only when something could not be sent
notes = lambda: sorted(os.listdir(outb + '/mktoss/freq')) if os.path.isdir(outb + '/mktoss/freq') else []
shutil.rmtree(outb + '/mktoss/freq', ignore_errors=True)
r, s, n = ask('1:110/290', 'secure', ['this.arc'])
check('nothing to report: no note for the requester', notes() == [])
r, s, n = ask('1:110/290', 'secure', ['this.arc', 'nothere.zip', 'hidden.zip'])
nf = notes()
body = open(outb + '/mktoss/freq/' + nf[0], encoding='latin-1').read() if len(nf) == 1 else ''
check('something not sent: a note for mktoss to post as a netmail to the requester (TO, SUBJECT, the refusals, how many files go)',
      len(nf) == 1 and nf[0].endswith('.note') and body.startswith('TO 1:110/290\nSUBJECT Your file request to ') and 'Not sent:' in body
      and 'nothere.zip: not found' in body and 'hidden.zip: not found' in body and '1 file(s) are sent to you apart from these.' in body and 'this.arc:' not in body)

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
