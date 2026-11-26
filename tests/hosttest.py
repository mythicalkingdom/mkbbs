#!/usr/bin/env python3
"""mk -x script: BASIC and Pascal programs of the sysop use the BBS through HOST$ / HostCall (MHOST-PLAN.md phase 1): the objects (system, users, message and file areas,
messages, nodes, events, chat, statistics, log), the capabilities of extensions.cfg and -C, the script node, the time limit, arguments, errors.
usage: hosttest.py <build dir> <work dir>"""
import json, os, re, shutil, subprocess, sys, time

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

build, work = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
repo = os.path.realpath(os.path.join(here, '..'))
if not os.path.exists(build + '/mk') or not os.path.exists(build + '/mksetup') or not os.path.exists(build + '/msgput'):
    print('skip: no mk / mksetup'); sys.exit(0)
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
tmp = cfgpatch.short_dir()
B = tmp + '/bbs'
RUN = tmp + '/run'
os.makedirs(RUN)
fails = 0


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'host: ' + name + ('' if ok else '  ' + str(info)[-500:]))
    if not ok:
        fails += 1


r = subprocess.run([build + '/mksetup', '-L', repo + '/lang', '-d', B, '-n', 'Host BBS', '-s', 'Host Sysop', '-u', '-p', 'sysop1', '-y'], capture_output=True, text=True)
assert r.returncode == 0, r.stdout + r.stderr
if not (shutil.which('true')):
    sys.exit(0)
MID = 'M' + B + '/msgs/gen.mer'
def put(*a):
    subprocess.run([build + '/msgput'] + [x if isinstance(x, bytes) else x.encode() for x in a], check=True)
put('add', MID, 'Alice', 'All', 'Hello world', '0', 'line one|second line|third')
put('add', MID, 'Bob', 'Carol', 'A secret', '1', 'for your eyes only')
put('add', MID, 'Carol', 'Alice', 'Re: Hello world', '0', 'a reply')
os.makedirs(B + '/scripts')


def script(name, text):
    open(B + '/scripts/' + name, 'w').write(text)
    return 'scripts/' + name


def mkx(*a, secs=40, env=None):
    e = dict(os.environ, MK=B + '/', MKRUN=RUN)
    e.update(env or {})
    r = subprocess.run([build + '/mk', '-x'] + list(a), cwd=B, env=e, capture_output=True, text=True, timeout=secs, input='')
    return r


def log():
    p = B + '/mk.log'
    return open(p, encoding='latin-1').read() if os.path.exists(p) else ''


# ---- BASIC
s = script('a.bas', '''10 N$ = HOST$("system.info")
20 PRINT "count="; N$
30 PRINT "bbs="; HOST$("field 1 bbs")
40 PRINT "head="; HOST$("line 0")
50 PRINT "args="; HOST$("argc"); ","; HOST$("arg 0"); ","; HOST$("arg 1"); ","; HOST$("arg 2")
60 PRINT "areas="; HOST$("msg.areas")
70 PRINT "area1="; HOST$("field 1 name")
80 PRINT "msgs="; HOST$("msg.list 1")
90 FOR I = 1 TO VAL(HOST$("count"))
100 PRINT "m"; I; "="; HOST$("field " + STR$(I) + " from"); "|"; HOST$("field " + STR$(I) + " subject")
110 NEXT I
120 PRINT "read="; HOST$("msg.read 1 1")
130 PRINT "subj="; HOST$("field 1 subject"); "|"; HOST$("field 1 from")
140 PRINT "text="; HOST$("msg.text 1 1")
150 FOR I = 1 TO VAL(HOST$("count"))
160 PRINT "t"; I; "="; HOST$("line " + STR$(I))
170 NEXT I
180 PRINT "user="; HOST$("=user.get 0")
190 PRINT "byname="; HOST$("field 1 name")
200 PRINT "nodes="; HOST$("node.list")
210 PRINT "nodeuser="; HOST$("field 1 user"); "|"; HOST$("field 1 type"); "|"; HOST$("field 1 node")
220 PRINT "files="; HOST$("file.areas")
230 PRINT "chat="; HOST$("chat.who")
240 PRINT "ev="; HOST$("events.list")
250 PRINT "stat="; HOST$("stats.total")
260 PRINT "log="; HOST$("log.write hello from basic")
''')
r = mkx('-x', s, 'one', 'two') if False else mkx(s, 'one', 'two')
o = r.stdout
check('BASIC: system.info is one record, field by name, the header line', r.returncode == 0 and 'count= 1' in o.replace('count=1', 'count= 1') and 'bbs=Host BBS' in o and 'head=bbs\tsoftware\ttime\tbbs_path\trun_path' in o, (r.returncode, o, r.stderr))
check('BASIC: arg 0 is the script, argc and the arguments', 'args= 2 ,scripts/a.bas,one,two' in o.replace('args=2,', 'args= 2 ,') or 'args=2,scripts/a.bas,one,two' in o, o)
check('BASIC: msg.areas lists the areas, a field of a record', 'areas=2' in o.replace(' ', '') and 'area1=General Messages' in o, o)
check('BASIC: msg.list gives the public messages (the private one is left out)', 'msgs=2' in o.replace(' ', '') and 'from=' not in o and 'm 1 =Alice|Hello world' in o and 'm 2 =Carol|Re: Hello world' in o, o)
check('BASIC: msg.read is the header, msg.text the lines of the body', 'subj=Hello world|Alice' in o and 't 1 =line one' in o, o)
check('BASIC: user.get by number (from 0) gives the sysop', 'Host Sysop' in o.split('user=')[1].split('\n')[0], o)
check('BASIC: the script is on the node list as a script node (101), type script, a name with the script', 'nodeuser=script a|script|101' in o, o)
check('BASIC: files, chat (nobody), events, statistics all answer', 'files=1' in o.replace(' ', '') and 'chat=0' in o.replace(' ', '') and 'ev=' in o and 'stat=1' in o.replace(' ', ''), o)
check('BASIC: log.write puts a line in the BBS log', 'Ext a: hello from basic' in log(), log()[-300:])
check('the node file of the script is gone when it ends', not [f for f in os.listdir(RUN) if f.startswith('node101')], os.listdir(RUN))

# errors and capabilities
s = script('e.bas', '10 PRINT HOST$("nonsense")\n')
r = mkx(s)
check('BASIC: an unknown command is a BASIC error with the text, exit 1', r.returncode == 1 and 'unknown command nonsense' in r.stdout, (r.returncode, r.stdout))
s = script('c.bas', '10 PRINT HOST$("user.list")\n')
r = mkx('-C', 'nodes:read', s)
check('BASIC: -C narrows the capabilities: a user call is refused (not allowed, needs users:read), logged', r.returncode == 1 and 'not allowed: user.list needs users:read' in r.stdout and 'Ext c: refused: not allowed: user.list needs users:read' in log(), (r.stdout, log()[-300:]))
r = mkx(s)
check('a script in no entry has every read capability', r.returncode == 0 and r.stdout.strip() == '1', r.stdout)
open(B + '/extensions.cfg', 'w').write('# the extensions\n[who]\nfile = scripts/c.bas\ncaps = nodes:read\ndesc = test\n[all]\nfile = scripts/a.bas\ncaps = *\n')
r = mkx(s)
check('extensions.cfg: the entry of the script gives its capabilities (only nodes:read: refused)', r.returncode == 1 and 'not allowed' in r.stdout and 'Ext who: refused' in log(), (r.stdout, log()[-200:]))
open(B + '/extensions.cfg', 'w').write('[who]\nfile = scripts/c.bas\ncaps = users:read\n')
r = mkx(s)
check('... and with users:read it runs', r.returncode == 0 and r.stdout.strip() == '1', r.stdout)
os.remove(B + '/extensions.cfg')

# the time limit
s = script('loop.bas', '10 GOTO 10\n')
t0 = time.time()
r = mkx('-T', '2', s)
check('a program that never ends is stopped by -T 2 (exit 1)', r.returncode == 1 and time.time() - t0 < 15, (r.returncode, time.time() - t0, r.stdout))

# the script node: all in use
s = script('wait.bas', '10 INPUT A$\n20 PRINT "got "; A$\n')
e = dict(os.environ, MK=B + '/', MKRUN=RUN, MKSCRIPTNODES='105-105')
p = subprocess.Popen([build + '/mk', '-x', s], cwd=B, env=e, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
time.sleep(2)
check('a running script has its node file', os.path.exists(RUN + '/node105.info') and 'type=script' in open(RUN + '/node105.info').read())
r = mkx(script('quick.bas', '10 PRINT "x"\n'), env={'MKSCRIPTNODES': '105-105'})
check('no free script node: refused, exit 2, a message', r.returncode == 2 and 'every script node is in use' in r.stderr, (r.returncode, r.stderr))
p.stdin.write('typed\n'); p.stdin.close(); p.wait(timeout=20)
check('a script reads standard input (INPUT) and ends', 'got typed' in p.stdout.read(), '')
check('... and gives its node back', not os.path.exists(RUN + '/node105.info'))
open(RUN + '/node105.info', 'w').write('node=105\npid=2999999\nport=0\ntype=script\n')
r = mkx(script('quick.bas', '10 PRINT "x"\n'), env={'MKSCRIPTNODES': '105-105'})
check('a node file of a script that is gone is taken over', r.returncode == 0 and r.stdout.strip() == 'x', (r.stdout, r.stderr))

# not a script, not there
r = mkx('scripts/nothere.bas')
check('a script that is not there: exit 2 and says so', r.returncode == 2 and 'is not there' in r.stderr, r.stderr)
open(B + '/scripts/x.txt', 'w').write('hi')
r = mkx('scripts/x.txt')
check('a file that is no .bas or .pas: exit 2', r.returncode == 2 and '.bas' in r.stderr, r.stderr)

# ---- Pascal
s = script('p.pas', '''program p;
var s, t: string; n, i, code: integer;
begin
  Val(HostCall('msg.list 1'), n, code);
  writeln('msgs=', n);
  for i := 1 to n do
    writeln('m', i, '=', HostCall('field ' + chr(48 + i) + ' from'), '|', HostCall('field ' + chr(48 + i) + ' subject'));
  writeln('argc=', ParamCount, ' ', ParamStr(1), ' ', HostCall('arg 1'), ' ', HostCall('argc'));
  writeln('user=', HostCall('=user.get "Host Sysop"'));
  writeln('node=', HostCall('=node.list'));
  Val(HostCall('msg.text 1 1'), n, code);
  for i := 1 to n do writeln('t', i, '=', HostCall('line ' + chr(48 + i)));
  writeln('log=', HostCall('log.write hello from pascal'));
  writeln(HostCall('user.list'));
  writeln(HostCall('field 1 nosuchfield'));
end.
''')
r = mkx(s, 'a1')
o = r.stdout
check('Pascal: messages, fields, arguments (ParamStr and arg), a user by name, the script node', 'msgs=2' in o and 'm1=Alice|Hello world' in o and 'm2=Carol|Re: Hello world' in o and 'argc=1 a1 a1 1' in o and 'user=0\tHost Sysop' in o and 'node=101\tscript p' in o, (r.returncode, o, r.stderr))
check('Pascal: the text of a message by lines, the log', 't1=line one' in o and 'Ext p: hello from pascal' in log(), (o, log()[-200:]))
check('Pascal: a field that is not there is a run-time error (300) with the text, exit 1', r.returncode == 1 and 'Runtime error 300: Host call failed: no such field nosuchfield' in o, (r.returncode, o))
r = mkx('-C', 'log:write', s, 'a1')
check('Pascal: -C narrows it: refused', 'not allowed' in r.stdout and r.returncode == 1, r.stdout)
s = script('ploop.pas', 'program l; begin while true do; end.\n')
t0 = time.time()
r = mkx('-T', '2', s)
check('Pascal: a program that never ends is stopped by -T 2', r.returncode == 1 and time.time() - t0 < 15, (r.returncode, time.time() - t0, r.stdout))
# help and host.list come from the registry (HostReg)
s = script('h.bas', '10 N = VAL(HOST$("help"))\n20 PRINT N; HOST$("line 1"); "|"; HOST$("line " + STR$(N))\n30 PRINT HOST$("host.list"); HOST$("field 1 description")\n')
r = mkx(s)
check('help lists the commands of the BBS; host.list names the provider (the BBS is the default one)', r.returncode == 0 and 'system.info' in r.stdout and 'log.write' in r.stdout and ' 1 the BBS' in r.stdout.replace('1the BBS', ' 1 the BBS').replace('1 the BBS', ' 1 the BBS'), r.stdout)
# the wrappers of ext/: mkbbs.pas for Pascal, the DEF FN lines for BASIC, and the examples
for f in os.listdir(repo + '/ext'):
    shutil.copy(repo + '/ext/' + f, B + '/scripts/' + f)
r = mkx('scripts/who.pas')
check('ext/who.pas (unit mkbbs next to it): the node list through Query and Field', r.returncode == 0 and 'Nodes in use: 1' in r.stdout and '101 script who' in r.stdout, (r.returncode, r.stdout, r.stderr))
r = mkx('scripts/who.bas')
check('ext/who.bas (DEF FN lines): the same through FNQ and FNF$', r.returncode == 0 and 'Nodes in use: 1' in r.stdout.replace('  ', ' ') and '101 script who' in r.stdout, (r.returncode, r.stdout, r.stderr))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
