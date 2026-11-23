# SSH for the BBS

Callers can log on over SSH: `ssh bbs@your.host` and the BBS asks for the caller's own login and password as for any other line.  The SSH layer lets the
account `bbs` in **without a password** (the BBS does the real login), so there is nothing to type at the SSH level.  MK has no SSH code of its own: an SSH
daemon does the encryption, and a small program, `mkbbsssh`, is what the account runs.

```
ssh client  <-- encrypted -->  sshd / dropbear (account bbs, no password)  -->  mkbbsssh  <-- Telnet on 127.0.0.1, PROXY header -->  mklisten  -->  mk
```

* `mkbbsssh` (the shell of the account `bbs`) connects to a port of `mklisten` on the same machine, first sends a PROXY header with the caller's real address
  (from `SSH_CONNECTION`), then speaks Telnet as a terminal: the **terminal type** (`TERM`), the **window size** and **new sizes** when the window changes.  The
  terminal of the SSH session is made raw: the BBS does the echo.
* `mklisten` takes it as any other line: a node, `maxperip`, the login guard (it counts failed log-ons by the real address), events, `mkmon`, the log.
* **Two daemons are supported:** a second **OpenSSH** (the default: its own configuration, PAM service and port; the system's `sshd` is not touched) or
  **Dropbear**.  Use one of them.

## Set up

1. **The port of `mklisten`** (`mklisten.json`), behind the front end only:

   ```
   { "port": 2327, "type": "telnet", "bind": "127.0.0.1", "proxy": true, "charset": "auto", "config": "/bbs/ra" }
   ```

   `"proxy": true` needs `"bind": "127.0.0.1"`.  `"charset": "auto"` makes UTF-8 for a terminal that wants it (SSH terminals do).
2. **`mkbbsssh` and its setting.**  `make install` puts `mkbbsssh` in the bin directory and the files below in `/usr/local/share/mkbbs/ssh/`.  Copy `mkbbsssh.conf` to
   `/etc/mkbbs/mkbbsssh.conf` and make `port` the one of step 1.
3. **The account `bbs`** (root).  It has no home, no rights, and the shell is `mkbbsssh`; whatever the SSH daemon is asked to run, the account can only do this:

   ```
   useradd --system --no-create-home --home-dir /nonexistent --shell /usr/local/bin/mkbbsssh bbs
   echo /usr/local/bin/mkbbsssh >> /etc/shells          # Dropbear wants the shell to be listed
   ```

   **Do not use the account that owns the BBS** (`mkbbs`): `mkbbsssh` needs no files, only a connection to a local port.  A shell of `/bin/false` does not work: both
   daemons run the command through the shell of the account.
4. **The host key**, once: `mkdir -p /etc/mkbbs/ssh && ssh-keygen -t ed25519 -N '' -f /etc/mkbbs/ssh/ssh_host_ed25519_key` (Dropbear: `dropbearkey -t
   ed25519 -f /etc/mkbbs/ssh/dropbear_ed25519_host_key`, or `-R` in its command line makes it).
5. **The port 22 question.**  Callers type `ssh bbs@host`, so the BBS wants port 22.  Either move the system's own `sshd` to another port (and use `ssh -p ... host`
   yourself), or give the BBS another port (`Port 2222` below) and callers use `ssh -p 2222 bbs@host`.  Do not put both on port 22.

### OpenSSH (a second daemon)

Files in `contrib/ssh/` (installed in `/usr/local/share/mkbbs/ssh/`):

| File | Goes to |
|---|---|
| `sshd_config` | `/etc/mkbbs/sshd_config` (edit `Port`) |
| `mkbbs-ssh.pam` | `/etc/pam.d/mkbbs-ssh` (only this daemon uses it: `PAMServiceName mkbbs-ssh`) |
| `mkbbs-sshd.service` | `/etc/systemd/system/mkbbs-sshd.service`, then `systemctl enable --now mkbbs-sshd` |

The login without a password is OpenSSH's `none` method, which is used for "password-less accounts when `PermitEmptyPasswords` is enabled" (`man sshd_config`):
the PAM file lets any password through (`pam_permit`), so a client that sends `none` is in at once and one that insists on a password is let in too.  Only the
account `bbs` can use this daemon (`AllowUsers bbs`), forwarding is off, and the command is `mkbbsssh`.  The password of the account stays locked (`useradd` makes
it so): it is no way in for any other service.  **Test it on your system** (`ssh bbs@host` should come to the BBS "Language choice" with no password question).

### Dropbear

`mkbbs-dropbear.service` starts Dropbear with `-B` (blank password logins), `-G bbs` (only the group `bbs`), `-c /usr/local/bin/mkbbsssh` and no forwarding.  Dropbear has
no PAM: with `-B` the account needs an **empty** password field, `passwd -d bbs`.  That is safe here because the shell of the account is `mkbbsssh`, but it is a
weaker arrangement than OpenSSH with its own PAM file, and any other service that uses the password database would let the empty password in at the
console.  Dropbear is the choice for a small system that has no OpenSSH.

## What a caller sees and what is lost

* The SSH username has to be `bbs` (a real account).  A caller who types their BBS name as the SSH username is refused.  A server that accepts any name needs its
  own SSH server code (not done).
* A caller whose window changes: the new size reaches the BBS.
* A caller who drops the line: the daemon ends `mkbbsssh`, the connection to `mklisten` closes, the BBS sees a hang up.
* `mkbbsssh` says "The BBS is not available now" when `mklisten` is not running.

## Tests

`tests/sshtest.py` runs a real `ssh` client through an OpenSSH daemon and through Dropbear (both as the test user, key login, with `mkbbsssh` as the forced
command) to a real `mklisten` and the sample BBS, and checks the language prompt, the real address in the PROXY header (the one `mklisten` uses), a window
change, the refusal when the BBS is down, and that `-c command` is ignored.  The password-less login itself (PAM `pam_permit`, Dropbear `-B`) needs root and an
account and is not tested there.
