#!/usr/bin/env python3
# Runs build/mkconfig in a pseudo terminal, sends keys and prints the final screen as text.
# usage: CFGDIR=<bbs config dir> cfgshot.py KEYS...      (\x1b = ESC, \r = Enter, \t = Tab)
# e.g.   cfgshot.py '\x1bg' '\x1b[B' '\r'              opens General > Bbs Paths
import pty,os,time,select,struct,fcntl,termios,sys,re
keys=[a.encode().decode('unicode_escape').encode('latin-1') for a in sys.argv[1:]]
env={'TERM':'xterm','LANG':'C.UTF-8','LC_ALL':'C.UTF-8','MK':os.environ.get('CFGDIR','/tmp/claude-1000/racopy'),'PATH':os.environ['PATH']}
PROG=os.environ.get('CFGPROG','mkconfig'); CWD=os.environ.get('CFGCWD','.'); HERE=os.path.dirname(os.path.abspath(__file__))
pid,fd=pty.fork()
if pid==0:
    os.environ.clear(); os.environ.update(env); os.chdir(CWD); os.execv(os.path.join(HERE,'..','build',PROG),[PROG])
fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack('HHHH',int(os.environ.get('CFGROWS','25')),int(os.environ.get('CFGCOLS','80')),0,0))
def drain(t):
    buf=b''; end=time.time()+t
    while time.time()<end:
        r,_,_=select.select([fd],[],[],0.1)
        if r:
            try: d=os.read(fd,65536)
            except OSError: break
            if not d: break
            buf+=d
    return buf
data=drain(1.2)
for k in keys:
    os.write(fd,k); data+=drain(float(os.environ.get('CFGDELAY','0.5')))
H,W=int(os.environ.get('CFGROWS','25')),int(os.environ.get('CFGCOLS','80'))
g=[[' ']*W for _ in range(H)]; cy=cx=0
s=data.decode('utf-8','replace')
i=0
while i<len(s):
    c=s[i]
    if c=='\x1b':
        m=re.match(r'\x1b\[([0-9;?]*)([A-Za-z])',s[i:])
        if m:
            p=m.group(1); f=m.group(2); a=[int(x) if x.isdigit() else 0 for x in p.replace('?','').split(';')] if p else []
            n=lambda d=1: (a[0] if a and a[0] else d)
            if f in 'Hf': cy=min(H-1,(a[0] if a and a[0] else 1)-1); cx=min(W-1,(a[1] if len(a)>1 and a[1] else 1)-1)
            elif f=='A': cy=max(0,cy-n())
            elif f=='B': cy=min(H-1,cy+n())
            elif f=='C': cx=min(W-1,cx+n())
            elif f=='D': cx=max(0,cx-n())
            elif f=='J':
                if (a[0] if a else 0)==2:
                    g=[[' ']*W for _ in range(H)]
            elif f=='K':
                for x in range(cx,W): g[cy][x]=' '
            i+=m.end(); continue
        m=re.match(r'\x1b[()][0-9A-Za-z]|\x1b[=>78]|\x1b\][^\x07]*\x07',s[i:])
        if m: i+=m.end(); continue
        i+=1; continue
    if c=='\r': cx=0
    elif c=='\n': cy=min(H-1,cy+1)
    elif c=='\b': cx=max(0,cx-1)
    elif c>=' ':
        g[cy][cx]=c; cx+=1
        if cx>=W: cx=W-1
    i+=1
shade=os.environ.get('SHADE','.')
for row in g: print(''.join(row).replace('░',shade).rstrip())
try: os.write(fd,b'\x1bx'); time.sleep(0.2); os.kill(pid,9)
except Exception: pass
