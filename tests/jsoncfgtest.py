#!/usr/bin/env python3
"""The MK configuration in one JSON file (MKCfgJs): mkcfgcvt 1 -> 5 -> 1 -> 5 gives the same file, the programs find the
file with the MKJSON environment variable (a directory or the file), text is UTF-8 in the file and CP437 in the .mk
files.  Works on private copies: the sample BBS must not change.
usage: jsoncfgtest.py <build dir> <work dir>"""
import glob, hashlib, json, os, shutil, subprocess, sys

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sample = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not os.path.isdir(sample):
    print('skip: no sample BBS'); sys.exit(0)
fails = 0


def check(name, ok):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'jsoncfg: ' + name)
    if not ok:
        fails += 1


def snapshot():
    return {f: hashlib.md5(open(f, 'rb').read()).hexdigest() for f in glob.glob(os.path.join(sample, '*')) if os.path.isfile(f) and os.access(f, os.R_OK)}


def run(prog, *args, **env):
    e = {'PATH': os.environ['PATH']}
    e.update(env)
    return subprocess.run([os.path.join(build, prog)] + list(args), env=e, capture_output=True, text=True, input='', encoding='latin-1')


before = snapshot()
shutil.rmtree(work, ignore_errors=True)
inp, jdir, mk2, j2dir, mk3 = [os.path.join(work, d) for d in ('in', 'json', 'mk2', 'json2', 'mk3')]
os.makedirs(work)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch
inp = cfgpatch.short_dir() + '/in'                     # a short path: the configuration holds it in a fixed size field
shutil.copytree(cfgpatch.snapshot(sample), inp, ignore=lambda d, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'mailer.mk', 'events.mk', 'fileecho.mk')) or not os.access(os.path.join(d, f), os.R_OK)])
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cfgpatch
# the paths in config.mk lead to the sample: point them at the copy, or a file that is only in the sample (fileecho.mk, events.mk ...) is found through them
for _d in (inp,):
    cfgpatch.patch(os.path.join(_d, 'config.mk'), (repo + '/bbs/').encode(),
                   lambda p, _d=_d: (_d + '/').encode() + p[len((sample + '/').encode()):] if p.startswith((sample + '/').encode()) else p)
for d in (jdir, mk2, j2dir, mk3):
    os.makedirs(d)
shutil.copy(os.path.join(sample, 'mailer.mk'), inp) if os.access(os.path.join(sample, 'mailer.mk'), os.R_OK) else None

r = run('mkcfgcvt', '-y', '1', '5', MK=inp, MKJSON=jdir)
check('MK to JSON (MKJSON is a directory) completed', r.returncode == 0 and 'Conversion completed' in r.stdout)
jf = os.path.join(jdir, 'bbsconfig.json')
check('bbsconfig.json is there', os.path.exists(jf))
d = json.load(open(jf, encoding='utf-8'))
check('sections: version, config, messages, files, echo, mailer, events, fileecho', all(k in d for k in ('version', 'config', 'messages', 'files', 'echo', 'mailer', 'events', 'fileecho')) and d['version'] == 1)
check('fileecho has the defaults of a BBS with no file echoes (a 60 second check, 14 days of spool)', d['fileecho'].get('CheckTimeout') == 60 and d['fileecho'].get('PassDays') == 14 and not d['fileecho'].get('Area'))
check('config has the field names and the sysop', d['config'].get('SysopName') == 'Mark May' and 'ExitEL' in d['config'])
check('only message and file areas in use are written, named by number',
      0 < len(d['messages']) < 500 and all(k.isdigit() and v['Name'] for k, v in d['messages'].items()) and all(v['Name'] for v in d['files'].values()))

# a program that finds the configuration with MKJSON only (no MK): the same message areas as with the .mk files
a = os.path.join(work, 'a.txt'); b = os.path.join(work, 'b.txt')
r1 = run('mklistmsgarea', a, MK=inp)
r2 = run('mklistmsgarea', b, MKJSON=jdir)
ta = open(a, encoding='latin-1').read() if os.path.exists(a) else None
tb = open(b, encoding='latin-1').read() if os.path.exists(b) else None
check('mklistmsgarea with only MKJSON lists the same areas as with MK (%d bytes)' % len(ta or ''), ta is not None and ta == tb and len(ta) > 100)

# the UTF-8 text of the file and the CP437 of the record file
d['config']['SystemName'] = 'Café ░ ñ'
d['config']['BadMsgArea'] = 6                 # offline replies that cannot go where they were meant
d['config']['BbsLocation'] = 'Zürich €'        # the euro sign has no CP437 code: a ?
d['fileecho']['CheckCmd'] = '/usr/bin/scan %F %T'
d['fileecho']['PassMaxMB'] = 300
d['fileecho']['Area'] = {'1': {'Tag': 'FSX_GEN', 'Desc': 'General files', 'FileArea': 3, 'EchoTo': 5, 'Hub': 1, 'Groups': 3, 'Attr': 1},
                         '300': {'Tag': 'PASS_ONLY', 'FileArea': 0, 'EchoTo': 2}}
d['fileecho']['Sys'] = {'1': {'TicPwd': 'tic1', 'FixPwd': 'fixpw', 'Groups': 7}, '32': {'TicPwd': 'last'}}
efile = os.path.join(work, 'edited.json')
json.dump(d, open(efile, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
r = run('mkcfgcvt', '-y', '5', '1', MK=mk2, MKJSON=efile)
check('JSON to MK (MKJSON is the file) completed', r.returncode == 0 and 'Conversion completed' in r.stdout)
cfgmk = open(os.path.join(mk2, 'config.mk'), 'rb').read()
check('the .mk file has the text in CP437', b'Caf\x82 \xb0 \xa4' in cfgmk and b'Z\x81rich ?' in cfgmk)
check('config.mk has the size of the sample (BadMsgArea took bytes of AddOn)', len(cfgmk) == os.path.getsize(os.path.join(sample, 'config.mk')))
check('all seven record files are written', sorted(os.listdir(mk2)) == ['config.mk', 'echocfg.mk', 'events.mk', 'fileecho.mk', 'files.mk', 'mailer.mk', 'messages.mk'])
r = run('mkcfgcvt', '-y', '1', '5', MK=mk2, MKJSON=j2dir)
d2 = json.load(open(os.path.join(j2dir, 'bbsconfig.json'), encoding='utf-8'))
fe = d2['fileecho']
check('the file echoes went through fileecho.mk and back: tag, area, mask, hub, groups, flags, the check command, the passwords of systems 1 and 32 (the last record)',
      fe['CheckCmd'] == '/usr/bin/scan %F %T' and fe['PassMaxMB'] == 300 and fe['Area']['1'] == d['fileecho']['Area']['1'] and fe['Area']['300']['Tag'] == 'PASS_ONLY'
      and fe['Sys']['1']['FixPwd'] == 'fixpw' and fe['Sys']['32']['TicPwd'] == 'last' and fe['Area']['300']['FileArea'] == 0)
fs = os.path.getsize(os.path.join(mk2, 'fileecho.mk'))
check('fileecho.mk is one record of fixed size (%d bytes)' % fs, fs > 30000)
check('BadMsgArea went through .mk and back', d2['config'].get('BadMsgArea') == 6 and 'BadMsgArea' in d['config'])
check('MK back to JSON: the UTF-8 text is back', d2['config']['SystemName'] == 'Café ░ ñ' and d2['config']['BbsLocation'] == 'Zürich ?')
d['config']['BbsLocation'] = 'Zürich ?'
d['fileecho'] = fe                      # the records written whole (every field)
check('MK to JSON to MK to JSON loses nothing (all sections the same)', d == d2)
r = run('mkcfgcvt', '-y', '5', '1', MK=mk3, MKJSON=j2dir)
check('... and the record files of the second round are the same as of the first', all(open(os.path.join(mk2, f), 'rb').read() == open(os.path.join(mk3, f), 'rb').read() for f in os.listdir(mk2)))

# a file that is not JSON, a missing file
bad = os.path.join(work, 'bad.json')
open(bad, 'w').write('{ this is not json')
r = run('mkcfgcvt', '-y', '5', '1', MK=os.path.join(work, 'mk4'), MKJSON=bad)
check('a file that is not JSON: error 2001', r.returncode == 1 and '2001' in r.stdout)
r = run('mkcfgcvt', '-y', '5', '1', MK=os.path.join(work, 'mk4'), MKJSON=os.path.join(work, 'nothere.json'))
check('a missing file: error 2', r.returncode == 1 and 'Error: 2 ' in r.stdout)

check('the sample BBS did not change', snapshot() == before)
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
