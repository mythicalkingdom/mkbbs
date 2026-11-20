#!/usr/bin/env python3
"""mklisten runs the events: commands at their times, the errorlevel script events.sh, the mailer actions, days and status, the
four ways to handle a missed event, exclusive events (callers refused, waited for, forced off) and the events.run file.
A clock offset in the "events" section makes it quick; the time zone is the machine's.   usage: eventlistentest.py <work dir>"""
import json, os, shutil, socket, subprocess, sys, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import cfgpatch

repo = os.path.realpath(os.path.join(here, '..'))
build = os.path.join(repo, 'build')
sample = os.path.join(repo, 'bbs', 'bbsc', 'ra')
if not (os.path.isdir(sample) and os.path.exists(os.path.join(build, 'mkevents'))):
    print('skip: no sample BBS or no mkevents'); sys.exit(0)
work = os.path.abspath(sys.argv[1])
shutil.rmtree(work, ignore_errors=True)
os.makedirs(work)
fails = 0
procs = []


def check(name, ok, info=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + 'events: ' + name + ('' if ok else '  ' + str(info)))
    if not ok:
        fails += 1


def wait(cond, secs=15):
    end = time.time() + secs
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.1)
    return cond()


def read(p):
    try:
        return open(p).read()
    except OSError:
        return ''


tool_env = {'PATH': os.environ['PATH']}
_lt = time.localtime()
today = int(time.mktime((_lt.tm_year, _lt.tm_mon, _lt.tm_mday, 0, 0, 0, 0, 0, -1)))      # 00:00 local time today as a UNIX time
sunday_based_weekday = (_lt.tm_wday + 1) % 7                                              # 0 = Sunday, as the bit mask


def make_cfg(name, events):
    """A configuration directory (private copy of the sample) whose events are `events`: {n: dict}; the others are deleted"""
    d = os.path.join(cfgpatch.short_dir(), 'c')
    shutil.copytree(sample, d, ignore=lambda a, n: [f for f in n if f.lower().startswith(('mkbink.conf', 'events.mk', 'events.run')) or
                                                    not os.access(os.path.join(a, f), os.R_OK)])
    j = os.path.join(work, name + '-json')
    os.makedirs(j)
    r = subprocess.run([os.path.join(build, 'mkcfgcvt'), '-y', '1', '5'], env=dict(tool_env, MK=d, MKJSON=j), capture_output=True, text=True, input='')
    data = json.load(open(os.path.join(j, 'bbsconfig.json'), encoding='utf-8'))
    ev, ext = {}, {}
    base = data['events']['Ev']['1']
    for n, e in events.items():
        ev[str(n)] = {'Status': e.get('status', 1), 'Time': e.get('time', '03:00'), 'ErrorLvl': e.get('el', 0), 'Days': e.get('days', 127),
                      'Forced': e.get('forced', 0), 'LastRun': ''}
        x = dict(base)
        x.update({'Action': e.get('action', 0), 'Flags': e.get('flags', 0), 'Late': e.get('late', 1), 'LateMin': e.get('latemin', 10),
                  'LateMax': e.get('latemax', 5), 'Cmd': e.get('cmd', ''), 'TimeoutMin': e.get('timeout', 0)})
        ext[str(n)] = x
    data['config']['Events'] = ev
    for k in list(data['events']['Ev'].keys()):
        data['events']['Ev'].pop(k)
    data['events']['Ev'].update(ext)
    # the events that were not given are deleted (the sample has some)
    json.dump(data, open(os.path.join(j, 'bbsconfig.json'), 'w', encoding='utf-8'))
    out = os.path.join(cfgpatch.short_dir(), 'o')
    os.makedirs(out)
    r = subprocess.run([os.path.join(build, 'mkcfgcvt'), '-y', '5', '1'], env=dict(tool_env, MK=out, MKJSON=j), capture_output=True, text=True, input='')
    assert r.returncode == 0, r.stdout + r.stderr
    return out


mk_script = os.path.join(work, 'fakemk')
open(mk_script, 'w').write('#!/bin/sh\nexec cat > /dev/null\n')      # a caller: lives until the connection closes
os.chmod(mk_script, 0o755)
n_port = [24920]


def start(name, cfg, clock_secs, port_nodes='1-4', extra=None, run=None, mk=None):
    """mklisten with the events of cfg, the clock showing today at clock_secs (seconds after 00:00 local time)"""
    run = run or os.path.join(cfgpatch.short_dir(), 'r')
    log = os.path.join(work, name + '.log')
    port = n_port[0]
    n_port[0] += 1
    ev = {'config': cfg, 'mkevents': os.path.join(build, 'mkevents'), 'interval': 1, 'clock': today + clock_secs, 'closed': 'Closed for maintenance.'}
    ev.update(extra or {})
    c = {'mk': mk or mk_script, 'rundir': run, 'logfile': log, 'nodes': port_nodes,
         'ports': [{'port': port, 'type': 'raw', 'bind': '127.0.0.1', 'config': cfg}], 'events': ev}
    cf = os.path.join(work, name + '.json')
    json.dump(c, open(cf, 'w'))
    p = subprocess.Popen([os.path.join(build, 'mklisten'), '-c', cf], env=tool_env, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    procs.append(p)
    wait(lambda: 'node files in' in read(log), 10)          # listening
    return p, log, port, run


def stop(p):
    p.terminate()
    try:
        p.wait(20)
    except subprocess.TimeoutExpired:
        p.kill()


def hms(h, m=0, s=0):
    return h * 3600 + m * 60 + s


def run_cmd(path, text):
    return "/bin/sh -c 'echo %s >> %s'" % (text, path)


try:
    # ---------------------------------------------------------------- on time, the errorlevel script, status, days, mailer
    out1 = os.path.join(work, 'out1')
    cfg = make_cfg('s1', {
        1: dict(action=1, cmd=run_cmd(out1, 'one'), flags=2),
        2: dict(action=0, el=7),
        3: dict(action=1, cmd='/bin/false', el=9),
        4: dict(action=4, cmd='*'),
        5: dict(status=2, action=1, cmd=run_cmd(out1, 'disabled')),
        6: dict(action=1, cmd=run_cmd(out1, 'wrongday'), days=127 ^ (1 << sunday_based_weekday)),
        7: dict(action=1, cmd=run_cmd(out1, 'quoted "a b" c')),
    })
    script = os.path.join(cfg, 'events.sh')
    open(script, 'w').write('#!/bin/sh\necho "$1 $2 $3 $MKEVENT $MKERRORLEVEL" >> %s/script.out\n' % work)
    os.chmod(script, 0o755)
    p, log, port, run = start('s1', cfg, hms(2, 59, 52))
    check('mklisten starts with an events section', p.poll() is None)
    check('an event at 03:00 runs on time (a command, no shell)', wait(lambda: 'one' in read(out1), 20))
    check('... the event is logged', 'events: starting event 1' in read(log))
    check('an event with an errorlevel and no action runs events.sh (7, event 2, result 0)',
          wait(lambda: '7 2 0 2 7' in read(os.path.join(work, 'script.out')), 10))
    check('the result of the action goes to events.sh as the third argument (event 3: false = 1)',
          wait(lambda: '9 3 1 3 9' in read(os.path.join(work, 'script.out')), 10))
    check('a disabled event does not run', 'disabled' not in read(out1))
    check('an event for other days does not run', 'wrongday' not in read(out1))
    check('quotes keep words together in a command', wait(lambda: 'quoted a b c' in read(out1), 5))
    check('the mailer action without a mailer: logged, result 1', wait(lambda: 'the mailer is not running' in read(log), 10))
    st = read(os.path.join(cfg, 'events.run'))
    check('events.run in the BBS directory: event 1 with the occurrence 03:00 as a UNIX time and result 0',
          any(l.split('\t')[:2] == ['1', str(today + hms(3, 0))] and l.split('\t')[3] == '0' for l in st.splitlines() if l and l[0] != '#'))
    check('... and event 3 with result 1', any(l.split('\t')[0] == '3' and l.split('\t')[3] == '1' for l in st.splitlines() if l and l[0] != '#'))
    time.sleep(2)
    check('an occurrence runs once (still one line "one")', read(out1).count('one\n') == 1)
    stop(p)
    check('mklisten stops', p.poll() is not None)

    # ---------------------------------------------------------------- missed events: the four ways
    outl = os.path.join(work, 'late.out')
    cfg = make_cfg('s2', {
        1: dict(action=1, cmd=run_cmd(outl, 'within'), late=1, latemin=10),
        2: dict(action=1, cmd=run_cmd(outl, 'skip'), late=0),
        3: dict(action=1, cmd=run_cmd(outl, 'permiss'), late=3, latemax=2),
        4: dict(action=1, cmd=run_cmd(outl, 'run'), late=2),
        5: dict(action=1, cmd=run_cmd(outl, 'toolate'), late=1, latemin=2),
    })
    with open(os.path.join(cfg, 'events.run'), 'w') as f:
        for n in (1, 2, 4, 5):
            f.write('%d\t%d\t0\t0\n' % (n, today - 86400 + hms(12)))               # yesterday noon
        f.write('3\t%d\t0\t0\n' % (today - 3 * 86400 + hms(12)))                  # three days ago: three occurrences missed
    p, log, port, run = start('s2', cfg, hms(3, 5))
    check('missed, within 10 minutes (5 late): runs', wait(lambda: 'within' in read(outl), 20))
    check('missed, run: runs once', wait(lambda: 'run\n' in read(outl), 10))
    check('missed, per miss: three occurrences, at most 2 runs', wait(lambda: read(outl).count('permiss') == 2, 15))
    time.sleep(2)
    t = read(outl)
    check('missed, skip: does not run', 'skip' not in t)
    check('missed, within 2 minutes but 5 late: does not run', 'toolate' not in t)
    check('nothing ran twice', t.count('within') == 1 and t.count('run\n') == 1 and t.count('permiss') == 2)
    stop(p)

    # ---------------------------------------------------------------- exclusive: waits for the callers, refuses new ones, runs alone
    outx = os.path.join(work, 'excl.out')
    xs = os.path.join(work, 'excl.sh')              # the command line of an event is at most 100 characters
    open(xs, 'w').write('#!/bin/sh\necho start >> "$1"; sleep 3; echo end >> "$1"\n')
    os.chmod(xs, 0o755)
    cfg = make_cfg('s3', {
        1: dict(action=1, cmd='%s %s' % (xs, outx), flags=1, late=2),
        2: dict(action=1, cmd=run_cmd(outx, 'other'), time='03:00'),
    })
    p, log, port, run = start('s3', cfg, hms(2, 59, 50))
    caller = socket.create_connection(('127.0.0.1', port), timeout=5)
    check('a caller gets in before the event', wait(lambda: 'node 1' in read(log), 5))
    check('the exclusive event waits for the caller (not started)', wait(lambda: ' is due' in read(log), 20) and 'start' not in read(outx))
    c2 = socket.create_connection(('127.0.0.1', port), timeout=5)
    c2.settimeout(5)
    try:
        data = c2.recv(200)
    except OSError:
        data = b''
    check('a new caller is refused with the message while the event waits', b'Closed for maintenance.' in data)
    c2.close()
    check('the other event (not exclusive) waits behind it', 'other' not in read(outx))
    caller.close()
    check('the caller leaves: the exclusive event starts', wait(lambda: 'start' in read(outx), 10))
    time.sleep(0.5)
    c3 = socket.create_connection(('127.0.0.1', port), timeout=5)
    c3.settimeout(5)
    try:
        data = c3.recv(200)
    except OSError:
        data = b''
    check('while it runs the BBS is closed', b'Closed for maintenance.' in data and 'end' not in read(outx))
    c3.close()
    check('it ends, then the next event runs', wait(lambda: 'end' in read(outx) and 'other' in read(outx), 15))
    check('the exclusive one ran alone (the other came after "end")', read(outx).index('end') < read(outx).index('other'))
    c4 = socket.create_connection(('127.0.0.1', port), timeout=5)
    check('after it the BBS is open again (a node is started)', wait(lambda: read(log).count('node 1') >= 2 or read(log).count('node 2') >= 1, 5))
    c4.close()
    stop(p)

    # ---------------------------------------------------------------- forced: the callers are disconnected
    outf = os.path.join(work, 'forced.out')
    cfg = make_cfg('s4', {1: dict(action=1, cmd=run_cmd(outf, 'forced'), flags=1, forced=1, late=2)})
    p, log, port, run = start('s4', cfg, hms(2, 59, 55))
    caller = socket.create_connection(('127.0.0.1', port), timeout=5)
    check('forced: the callers are disconnected', wait(lambda: 'is forced: disconnecting the callers' in read(log), 20))
    check('... and the event runs after the (SIGTERM, 15 s) disconnect', wait(lambda: 'forced' in read(outf), 30))
    caller.close()
    stop(p)
    # ---------------------------------------------------------------- the mailer actions through the control socket (a fake mailer)
    import threading
    rd = os.path.join(cfgpatch.short_dir(), 'r')
    os.makedirs(rd, mode=0o700)
    sockp = os.path.join(rd, 'mailer.sock')
    srv = socket.socket(socket.AF_UNIX)
    srv.bind(sockp)
    srv.listen(5)
    seen = []

    def serve():
        while True:
            try:
                c, _ = srv.accept()
            except OSError:
                return
            c.sendall(b'HELLO fake\nSTATE 1\nME\t1:1/1\nLINK 1:110/100\tHub A\nLINK 1:110/200\tHub B\nEND\n')
            buf = b''
            while True:
                try:
                    d = c.recv(1000)
                except OSError:
                    break
                if not d:
                    break
                buf += d
                while b'\n' in buf:
                    line, buf = buf.split(b'\n', 1)
                    seen.append(line.decode())
                    c.sendall(b'ACK done\n' if not line.endswith(b'9:9/9') else b'ERR no such link\n')
            c.close()
    threading.Thread(target=serve, daemon=True).start()
    cfg = make_cfg('s5', {
        1: dict(action=4, cmd='1:110/100'),
        2: dict(action=4, cmd='*'),
        3: dict(action=5, cmd='*'),
        4: dict(action=6, cmd='1:110/200'),
        5: dict(action=4, cmd='9:9/9'),
    })
    p, log, port, run = start('s5', cfg, hms(2, 59, 56), run=rd)
    check('mailer actions: POLL of an address, POLL *, HOLD of every link, FREE of one',
          wait(lambda: all(x in seen for x in ('POLL 1:110/100', 'POLL *', 'HOLD 1:110/100', 'HOLD 1:110/200', 'FREE 1:110/200')), 20))
    check('... an ERR from the mailer is the result of the event (logged, 1)', wait(lambda: 'event 5' in read(log) and 'ended (1)' in read(log), 10))
    check('... the others ended with 0', read(log).count('ended (0)') == 4)
    stop(p)
    srv.close()
    # ---------------------------------------------------------------- hub passes: mk -G<id>, tried again after a failure, onfail
    hubdir = os.path.join(work, 'hub')
    os.makedirs(hubdir)
    hubmk = os.path.join(work, 'hubmk')
    open(hubmk, 'w').write('#!/bin/sh\n'
                           'id=${1#-G}\n'
                           'd=%s\n'
                           'n=$(cat "$d/$id.count" 2>/dev/null || echo 0); n=$((n+1)); echo $n > "$d/$id.count"\n'
                           'echo "$(date +%%s) $id try $n" >> "$d/tries.out"\n'
                           'rc=$(sed -n "${n}p" "$d/$id.codes"); [ -z "$rc" ] && rc=$(tail -n 1 "$d/$id.codes")\n'
                           'exit $rc\n' % hubdir)
    os.chmod(hubmk, 0o755)
    for hid, codes in (('HUBA', '5\n6\n0\n'), ('HUBB', '5\n5\n'), ('HUBC', '1\n'), ('HUBD', '0\n')):
        open(os.path.join(hubdir, hid + '.codes'), 'w').write(codes)
    onfail = os.path.join(work, 'onfail.sh')
    open(onfail, 'w').write('#!/bin/sh\necho "$@" >> %s/onfail.out\n' % hubdir)
    os.chmod(onfail, 0o755)
    cfg = make_cfg('s6', {1: dict(action=3, cmd='HUBA'), 2: dict(action=3, cmd='HUBB', el=4), 3: dict(action=3, cmd='HUBC'),
                          4: dict(action=3, cmd='HUBD')})
    for hid, extra in (('HUBA', 'retry 1\nretry-max 2\nretries 3\nonfail %s\n' % onfail), ('HUBB', 'retry 1\nretries 1\nonfail %s\n' % onfail),
                       ('HUBC', 'retries 3\nretry 1\nonfail %s\n' % onfail), ('HUBD', 'retry 1\n')):
        open(os.path.join(cfg, hid + '.map'), 'w').write('; map\ninbound /tmp\n' + extra)
    script = os.path.join(cfg, 'events.sh')
    open(script, 'w').write('#!/bin/sh\necho "$@" >> %s/script.out\n' % hubdir)
    os.chmod(script, 0o755)
    p, log, port, run = start('s6', cfg, hms(2, 59, 55), mk=hubmk)
    check('hub pass: runs mk -G<id> (the id of the map file)', wait(lambda: 'HUBD try 1' in read(os.path.join(hubdir, 'tries.out')), 20))
    check('... a pass that works (0) is not repeated and gives no onfail', wait(lambda: 'ended (0)' in read(log), 5))
    check('failed with 5 then 6, then 0: tried again after 1 s and after 2 s (retry-max 2), three tries',
          wait(lambda: read(os.path.join(hubdir, 'HUBA.count')).strip() == '3', 20) and 'trying again in 1 seconds (try 2 of 4)' in read(log)
          and 'trying again in 2 seconds (try 3 of 4)' in read(log))
    check('... it worked in the end: no onfail for it', 'HUBA' not in read(os.path.join(hubdir, 'onfail.out')))
    check('retries 1 and 5, 5: two tries, then onfail with the id, the result and the number of tries',
          wait(lambda: 'HUBB 5 2' in read(os.path.join(hubdir, 'onfail.out')), 20) and read(os.path.join(hubdir, 'HUBB.count')).strip() == '2')
    check('a code that is not retried (1): one try, then onfail at once',
          wait(lambda: 'HUBC 1 1' in read(os.path.join(hubdir, 'onfail.out')), 5) and read(os.path.join(hubdir, 'HUBC.count')).strip() == '1')
    check('events.sh (errorlevel 4) is run once, after the last try, with the result 5: "4 2 5"',
          wait(lambda: read(os.path.join(hubdir, 'script.out')).strip() == '4 2 5', 10))
    time.sleep(1.5)
    check('nothing is tried again after the end', read(os.path.join(hubdir, 'HUBA.count')).strip() == '3' and read(os.path.join(hubdir, 'HUBB.count')).strip() == '2')
    stop(p)
    # ---------------------------------------------------------------- an exclusive event ahead: callers get -T, "lead" closes the BBS early
    argsmk = os.path.join(work, 'argsmk')
    argsout = os.path.join(work, 'args.out')
    open(argsmk, 'w').write('#!/bin/sh\necho "$@" >> %s\nexec cat > /dev/null\n' % argsout)
    os.chmod(argsmk, 0o755)
    cfg = make_cfg('s7', {1: dict(action=1, cmd='/bin/true', flags=1, time='03:30'), 2: dict(status=2, action=1, cmd='/bin/true', flags=1, time='03:05')})
    p, log, port, run = start('s7', cfg, hms(3, 0, 0), mk=argsmk)
    time.sleep(1.5)
    c1 = socket.create_connection(('127.0.0.1', port), timeout=5)
    check('a caller before an exclusive event (30 minutes ahead): mk is started with -T30 (a disabled event does not count)',
          wait(lambda: '-T30' in read(argsout) or '-T29' in read(argsout), 5), read(argsout))
    c1.close()
    stop(p)
    open(argsout, 'w').close()
    p, log, port, run = start('s7b', cfg, hms(3, 0, 0), mk=argsmk, extra={'lead': 40})
    time.sleep(1.5)
    c2 = socket.create_connection(('127.0.0.1', port), timeout=5)
    c2.settimeout(5)
    try:
        data = c2.recv(200)
    except OSError:
        data = b''
    check('"lead": 40 minutes: 30 minutes before the event a new caller is refused (closed), no mk started',
          b'Closed for maintenance.' in data and read(argsout) == '', (data, read(argsout)))
    c2.close()
    stop(p)
    open(argsout, 'w').close()
    p, log, port, run = start('s7c', cfg, hms(3, 0, 0), mk=argsmk, extra={'lead': 20})
    time.sleep(1.5)
    c3 = socket.create_connection(('127.0.0.1', port), timeout=5)
    check('"lead": 20 minutes: 30 minutes ahead the caller is still let in', wait(lambda: '-T' in read(argsout), 5), read(argsout))
    c3.close()
    stop(p)
finally:
    for q in procs:
        if q.poll() is None:
            q.kill()

print('failures: %d' % fails)
sys.exit(1 if fails else 0)
