# SPDX-License-Identifier: GPL-3.0-or-later
"""A small FTP server for tests: plain or explicit FTPS (AUTH TLS, PBSZ, PROT P), passive mode, USER/PASS, TYPE, EPSV/PASV, RETR, STOR, DELE, QUIT.
Files are in a directory (no sub-directories needed: paths are taken as they are below it).  It records what happened in .log (a list of strings),
whether the data connection resumed the TLS session of the control connection (.resumed list), and what was stored."""
import os, socket, ssl, threading


class FakeFtp:
    def __init__(self, root, port, user='lion', password='pw', certfile=None, keyfile=None, require_reuse=False, host='127.0.0.1'):
        self.root, self.port, self.user, self.password = root, port, user, password
        self.cert, self.key, self.require_reuse = certfile, keyfile, require_reuse
        self.log, self.resumed = [], []
        self.host = host
        self.srv = socket.socket(socket.AF_INET6 if ':' in host else socket.AF_INET); self.srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.srv.bind((host, port)); self.srv.listen(5)
        self.ctx = None
        if certfile:
            self.ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            self.ctx.load_cert_chain(certfile, keyfile)
        threading.Thread(target=self.accept, daemon=True).start()

    def close(self):
        try:
            self.srv.shutdown(socket.SHUT_RDWR)       # ends the accept in the thread
        except OSError:
            pass
        try:
            self.srv.close()
        except OSError:
            pass

    def accept(self):
        while True:
            try:
                c, _ = self.srv.accept()
            except OSError:
                return
            threading.Thread(target=self.session, args=(c,), daemon=True).start()

    def session(self, c):
        ctl = c
        f = None
        user_ok = logged = False
        prot_p = False
        pasv = None
        reply = lambda s: ctl.sendall((s + '\r\n').encode())
        buf = b''
        try:
            reply('220 fake ftp ready')
            while True:
                while b'\n' not in buf:
                    d = ctl.recv(4096)
                    if not d:
                        return
                    buf += d
                line, buf = buf.split(b'\n', 1)
                line = line.decode('latin-1').strip()
                cmd, _, arg = line.partition(' ')
                cmd = cmd.upper()
                self.log.append(cmd + (' ' + arg if cmd not in ('PASS',) else ' ****'))
                if cmd == 'AUTH' and self.ctx:
                    reply('234 go ahead')
                    ctl = self.ctx.wrap_socket(ctl, server_side=True)
                    reply = lambda s: ctl.sendall((s + '\r\n').encode())
                elif cmd == 'AUTH':
                    reply('502 no tls')
                elif cmd == 'PBSZ':
                    reply('200 ok')
                elif cmd == 'PROT':
                    prot_p = arg.upper() == 'P'
                    reply('200 ok')
                elif cmd == 'USER':
                    user_ok = arg == self.user
                    reply('331 password please')
                elif cmd == 'PASS':
                    logged = user_ok and arg == self.password
                    reply('230 in' if logged else '530 Login incorrect')
                elif cmd == 'TYPE':
                    reply('200 type')
                elif cmd in ('EPSV', 'PASV'):
                    if pasv:
                        pasv.close()
                    pasv = socket.socket(socket.AF_INET6 if ':' in self.host else socket.AF_INET); pasv.bind((self.host, 0)); pasv.listen(1)
                    p = pasv.getsockname()[1]
                    if cmd == 'EPSV':
                        reply('229 Entering Extended Passive Mode (|||%d|)' % p)
                    else:
                        reply('227 Entering Passive Mode (10,9,9,9,%d,%d)' % (p // 256, p % 256))
                elif cmd in ('RETR', 'STOR') and not logged:
                    reply('530 log in first')
                elif cmd == 'RETR':
                    path = os.path.join(self.root, arg)
                    if not os.path.isfile(path):
                        reply('550 No such file')
                        continue
                    reply('150 sending')
                    d, _ = pasv.accept()
                    d = self.wrap(d, prot_p, ctl)
                    d.sendall(open(path, 'rb').read())
                    d.close()
                    reply('226 Transfer complete')
                elif cmd == 'STOR':
                    reply('150 go on')
                    d, _ = pasv.accept()
                    d = self.wrap(d, prot_p, ctl)
                    data = b''
                    while True:
                        x = d.recv(65536)
                        if not x:
                            break
                        data += x
                    d.close()
                    open(os.path.join(self.root, arg), 'wb').write(data)
                    reply('226 Transfer complete: %s stored, thank you' % arg)
                elif cmd == 'DELE':
                    path = os.path.join(self.root, arg)
                    if os.path.isfile(path):
                        os.remove(path); reply('250 deleted')
                    else:
                        reply('550 no such file')
                elif cmd == 'QUIT':
                    reply('221 bye')
                    return
                else:
                    reply('502 not here')
        except (OSError, ssl.SSLError) as e:
            self.log.append('error %r' % (e,))
        finally:
            try:
                ctl.close()
            except OSError:
                pass

    def wrap(self, d, prot_p, ctl):
        if not (self.ctx and prot_p):
            return d
        if self.require_reuse:
            d = self.ctx.wrap_socket(d, server_side=True)
        else:
            d = self.ctx.wrap_socket(d, server_side=True)
        self.resumed.append(bool(d.session_reused))
        return d
