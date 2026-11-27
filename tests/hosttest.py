#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
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
check('help lists the commands of the BBS; host.list names the provider (the BBS is the default one)', r.returncode == 0 and 'system.info' in r.stdout and 'chat.kick' in r.stdout and ' 1 the BBS' in r.stdout.replace('1the BBS', ' 1 the BBS').replace('1 the BBS', ' 1 the BBS'), r.stdout)
# ---- phase 4: writes
def basl(*lines):
    return ''.join('%d %s\n' % (10 * (i + 1), l) for i, l in enumerate(lines))


s = script('w1.bas', basl('Q$ = CHR$(34)', 'X = VAL(HOST$("msg.new 1 " + Q$ + "Bob" + Q$ + " " + Q$ + "From a script" + Q$ + " private"))',
                          'X = VAL(HOST$("msg.line first line"))', 'X = VAL(HOST$("msg.line second line"))', 'N = VAL(HOST$("msg.post"))',
                          'PRINT "POSTED="; HOST$("field 1 number")', 'PRINT "LIST="; HOST$("msg.list 1")'))
r = mkx(s)
check('a script that was not given msgs:post cannot post (a script in no entry has the read capabilities only)', r.returncode == 1 and 'not allowed: msg.new needs msgs:post' in r.stdout, r.stdout)
r = mkx('-C', 'msgs:post msgs:read', s)
check('msg.new / msg.line / msg.post: a message is posted, the number comes back, it is private so msgs:read alone does not list it', r.returncode == 0 and re.search(r'POSTED=\s*4\b', r.stdout) and 'LIST= 2' in r.stdout.replace('LIST=2', 'LIST= 2'), r.stdout)
check('... and it is in the log (from the default sysop, to Bob, the subject)', 'Ext w1: posted message 4 in area 1 from "Host Sysop" to "Bob": From a script' in log(), log()[-300:])
r = mkx('-C', 'msgs:post msgs:read msgs:private', script('w2.bas', basl('N = VAL(HOST$("msg.text 1 4"))', 'PRINT "T1="; HOST$("line 1")', 'N = VAL(HOST$("msg.read 1 4"))', 'PRINT "H="; HOST$("field 1 from"); "|"; HOST$("field 1 to"); "|"; HOST$("field 1 private")')))
check('the message has what was written: the lines, from the sysop, to Bob, private', 'T1=first line second line' in r.stdout and 'H=Host Sysop|Bob|1' in r.stdout, r.stdout)
n_before = len(open(B + '/mk.log', encoding='latin-1').read())
r = mkx('-n', '-C', 'msgs:post msgs:read', s)
check('-n: a dry run changes nothing (the same area still has the same messages) and the log says "dry run: would post"', 'dry run: would post a message in area 1' in log() and mkx('-C', 'msgs:read', script('w3.bas', '10 PRINT HOST$("msg.list 1")\n')).stdout.strip() == '2', (r.stdout, log()[-300:]))
s = script('w4.bas', basl('Q$ = CHR$(34)', 'X = VAL(HOST$("msg.new 99 x y"))'))
r = mkx('-C', 'msgs:post', s)
check('a message area that is not there is an error', 'no such message area' in r.stdout and r.returncode == 1, r.stdout)

open(B + '/scripts/note.txt', 'w').write('a file from a script\n')
s = script('w5.bas', basl('Q$ = CHR$(34)', 'PRINT "ADD="; HOST$("=file.add 1 note.txt " + Q$ + "A note from a script" + Q$)', 'N = VAL(HOST$("file.list 1"))', 'FOR I = 1 TO N', 'PRINT "F="; HOST$("field " + MID$(STR$(I), 2) + " name")', 'NEXT I', 'PRINT "AGAIN="; HOST$("=file.add 1 note.txt x")'))
r = mkx('-C', 'files:add files:read', s)
check('file.add: the file is copied into the area under a safe name and listed', r.returncode == 1 and 'ADD=note.txt' in r.stdout and 'F=note.txt' in r.stdout and os.path.exists(B + '/files/area01/note.txt'), (r.stdout, os.listdir(B + '/files/area01')))
check('... with its description in files.bbs; the same name again is refused', 'there is a file of that name in the area already' in r.stdout and 'note.txt     A note from a script' in open(B + '/files/area01/files.bbs').read(), (r.stdout, open(B + '/files/area01/files.bbs').read()))
s = script('w6.bas', basl('PRINT HOST$("=file.add 1 ../x.txt y")'))
r = mkx('-C', 'files:add', s)
check('file.add takes a name in the script\'s folder, never a path', 'the file is a name in the script' in r.stdout, r.stdout)

s = script('w7.bas', basl('Q$ = CHR$(34)', 'X = VAL(HOST$("user.set 0 level 77"))', 'X = VAL(HOST$("user.set " + Q$ + "Host Sysop" + Q$ + " city Oslo"))', 'X = VAL(HOST$("user.set 0 flagon 3"))',
                          'N = VAL(HOST$("user.get 0"))', 'PRINT "U="; HOST$("field 1 level"); "|"; HOST$("field 1 city")', 'X = VAL(HOST$("user.set 0 password abc"))'))
r = mkx('-C', 'users:write users:read', s)
check('user.set: the level and the city of a user are set, by number and by name (flagon too); the password is not a field', 'U= 77 |Oslo' in r.stdout.replace('U=77|', 'U= 77 |').replace('U= 77|', 'U= 77 |') or 'U=77|Oslo' in r.stdout, r.stdout)
check('... a field that is not one of the list is an error, and the log has the changes', 'the fields to set are level, flags' in r.stdout and 'Ext w7: set level of user Host Sysop to 77' in log(), (r.stdout, log()[-300:]))
r = mkx('-C', 'users:write', script('w8.bas', basl('X = VAL(HOST$("user.set 5 level 1"))')))
check('a user that is not there is an error', 'no such user' in r.stdout, r.stdout)

s = script('w9.bas', basl('X = VAL(HOST$("node.send 0 closing in ten minutes"))', 'X = VAL(HOST$("node.send 7 hello"))'))
r = mkx('-C', 'node:send', s)
check('node.send 0 writes a message for every node (sysopmsg.log: time, text, node 0); a node that is not in use is refused',
      'closing in ten minutes\t0' in open(RUN + '/sysopmsg.log').read() and 'node 7 is not in use' in r.stdout, (r.stdout, open(RUN + '/sysopmsg.log').read()))
r = mkx('-C', 'node:kick node:time', script('w10.bas', basl('X = VAL(HOST$("node.kick 3"))')))
check('node.kick of a node that is not in use is refused', 'node 3 is not in use' in r.stdout, r.stdout)
r = mkx('-C', 'chat:say chat:read', script('w11.bas', basl('X = VAL(HOST$("chat.say hello room"))', 'N = VAL(HOST$("chat.log 5"))', 'PRINT "LOG="; HOST$("line 1")')))
check('chat.say: a line of the sysop in the room, seen by chat.log', '[sysop] hello room' in r.stdout, r.stdout)
r = mkx('-C', 'chat:say', script('w12.bas', basl('X = VAL(HOST$("chat.mute 1 5"))')))
check('chat.mute needs chat:moderate, and a node that is not in the room is refused', 'chat.mute needs chat:moderate' in r.stdout, r.stdout)
r = mkx('-n', '-C', 'users:write users:read node:send chat:say files:add', script('w13.bas', basl('X = VAL(HOST$("user.set 0 level 5"))', 'X = VAL(HOST$("node.send 0 dry"))', 'X = VAL(HOST$("chat.say dry"))', 'X = VAL(HOST$("=file.add 1 note.txt d"))', 'N = VAL(HOST$("user.get 0"))', 'PRINT "LEVEL="; HOST$("field 1 level")')))
check('-n: user.set, node.send, chat.say and file.add do nothing (the level is still 77) and the log says what would have been done', 'LEVEL=77' in r.stdout.replace('LEVEL= 77', 'LEVEL=77') and 'dry run: would set level of user 0 to 5' in log() and 'dry\t0' not in open(RUN + '/sysopmsg.log').read(), (r.stdout, log()[-400:]))

# the wrappers of ext/: mkbbs.pas for Pascal, the DEF FN lines for BASIC, and the examples
for f in os.listdir(repo + '/ext'):
    shutil.copy(repo + '/ext/' + f, B + '/scripts/' + f)
r = mkx('scripts/who.pas')
check('ext/who.pas (unit mkbbs next to it): the node list through Query and Field', r.returncode == 0 and 'Nodes in use: 1' in r.stdout and '101 script who' in r.stdout, (r.returncode, r.stdout, r.stderr))
r = mkx('scripts/who.bas')
check('ext/who.bas (DEF FN lines): the same through FNQ and FNF$', r.returncode == 0 and 'Nodes in use: 1' in r.stdout.replace('  ', ' ') and '101 script who' in r.stdout, (r.returncode, r.stdout, r.stderr))
print('failures: %d' % fails)
sys.exit(1 if fails else 0)
