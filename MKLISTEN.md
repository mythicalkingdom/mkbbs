# mklisten: overview and setup

`mklisten` is the front door of an MK BBS on Linux.  It listens on TCP ports and starts one `mk` for each caller.  It
also runs the sysop monitor, the Fido mailer and a few helpers.  It replaces the modem, the FOSSIL and the
DOS multitasker of the original system: a caller is a network connection, and `mk` talks to it on standard input
and output.

The full list of settings is in the header of `src/MKListen.pas` and in `mklisten.example.json`.  This document is the
overview and the steps to set it up.

## What it does

* **Callers.**  Each accepted connection gets the next free **node** number and its own `mk` process:

  ```
  mk -N<node> -S<type> [-B<baud>] [-H] -A<address> [extra words from "args"]
  ```

  Nothing is shared between callers except the files on disk.  When the connection ends so does that `mk`.  If no
  node is free the caller is sent the `busy` text and disconnected.
* **Port types.**

  | `type` | Caller | Notes |
  |---|---|---|
  | `telnet` | a Telnet client | negotiation handled, terminal type seen (it decides the character set with `"charset": "auto"`) |
  | `raw` | a plain TCP stream | for programs and simple terminals |
  | `ws` | a web socket (a browser terminal) | text is UTF-8; for `wss://` use `"tls": true` or put `stunnel` in front |
  | `qwk` | a QWK network system or script | `mk -Q`: `Login:`, `Password:`, then `QWK:` with D, U, B, Q; only users with the QWK Node flag may enter |
  | `sysop` | the sysop, not a caller | opens the monitor `mkmon` (see below) |
  | `api` | a program or script of the sysop | the read only JSON API: `mkapi` answers one HTTP request per connection (`API-PLAN.md`); needs a token (`mkapitoken`); on `127.0.0.1` by default, TLS (`"tls": true`) for any other address, `"insecure": true` to say you know; bad tokens count for the login guard |

  Any caller port can also have `"qwk": true` to give its callers the QWK login.
* **Limits.**  `nodes` are the node numbers handed out (`"1-8"`, one number, or a list), `maxperip` is how many callers one
  address may have on a port.  Both can be set globally and per port.
* **Emulated speed.**  `baud` slows the connection down to a modem speed (0 = full speed), for atmosphere or for old
  door programs that expect it.
* **Sysop monitor.**  A `sysop` port gives `mkmon` to whoever connects (and knows the password).  It lists the nodes with
  their user, activity, address and start time, and lets the sysop watch (snoop), type into, disconnect, or give or take
  time from a node.  With `localnode` set, the **L** key logs the sysop in locally (`mk -L`) on a node of their own.
* **The mailer.**  With a `mailer` section, `mklisten` makes the settings for the binkp mailer `mkbink`, starts it,
  restarts it if it dies, tells it when the settings changed, and runs the Fido tosser `mktoss` (see `NETWORKING.md`).
* **Running as a service.**  It binds the ports and then gives up root (`user`, `group`), writes a log and a pid file,
  and can run as a daemon or under systemd.

## Setup

### 1. Build and install

```
make
sudo make install
```

`make install` puts the programs in `/usr/local/bin`, creates `/etc/mkbbs/mklisten.json` from the example (when it is
not there already), creates the `mkbbs` user and the log directory, and installs the systemd unit.  Variables for
other places: `PREFIX`, `BINDIR`, `SYSCONFDIR`, `LOGDIR`, `MKUSER`, `DESTDIR`, `SYSTEMD=no`.  If the `mkbink` project is in
`../mkbink` it is built and installed too.

### 2. Prepare the BBS directory

The BBS configuration directory (the one with `config.mk` and the message and user files) must belong to the user the
listener runs as, so that every `mk` can write to it.  Every program finds the BBS through the environment variable
`MK`; `mklisten` sets it for each caller from the port's `"config"`.

### 3. Write the configuration

Copy `mklisten.example.json` to `/etc/mkbbs/mklisten.json` (mode 600, it holds a password) and change the paths.  A
small setup:

```json
{
  "mk": "/usr/local/bin/mk",
  "user": "mkbbs",
  "group": "mkbbs",
  "logfile": "/var/log/mkbbs/mklisten.log",
  "workdir": "/bbs/ra",
  "nodes": "1-8",
  "maxperip": 3,
  "busy": "All lines are busy.",
  "localnode": 9,
  "ports": [
    { "port": 2323, "type": "telnet", "baud": 38400, "charset": "auto", "config": "/bbs/ra" },
    { "port": 2325, "type": "ws", "config": "/bbs/ra" },
    { "port": 2327, "type": "qwk", "config": "/bbs/ra" },
    { "port": 2330, "type": "sysop", "bind": "127.0.0.1", "password": "change-me", "config": "/bbs/ra" }
  ]
}
```

Rules:

* The file is one JSON object, no comments.  Keys that start with `_` are ignored, so use them for notes.
* `port` is required for each port.  A port starts from the global `nodes` and `maxperip`.
* `config` is the same as `"env": {"MK": "..."}`; `env` adds other variables; `args` adds words to the `mk` command line
  (for example `["-L", "-X"]`).
* `label` names what a port is for in the statistics (`STATS.md`): `"label": "ssh"` on the port that `mkbbsssh` connects to; without it the label is the type of the port (`telnet-tls` for a TLS port).
* `bind` limits a port to an address (default all IPv4 addresses).  Keep the `sysop` port on `127.0.0.1`.
* `localnode` must not be one of the nodes of any port (the listener refuses to start otherwise).
* A `sysop` `password` is the text itself, or `sha1:` followed by the lower case hex digest.  To make one:
  `printf %s 'secret' | sha1sum`.

### 4. Check it

```
mklisten -c /etc/mkbbs/mklisten.json -t
```

`-t` reads the file, reports any error and exits without starting anything.

### 5. Start it

* **By hand** (foreground, logs to the terminal): `mklisten -f -c /etc/mkbbs/mklisten.json`
* **As a daemon:** `mklisten -d -c ...`
* **Under systemd:**

  ```
  sudo systemctl enable --now mklisten
  sudo systemctl reload mklisten      # SIGHUP: the mailer reads its settings again
  journalctl -u mklisten -f
  ```

  The unit gives the process `CAP_NET_BIND_SERVICE` so ports below 1024 work without root, and uses
  `KillMode=process` so that **stopping or restarting the listener does not hang up callers**: they are processes of
  their own and carry on until they log off.

### 6. Try it

```
telnet localhost 2323          # a caller
telnet 127.0.0.1 2330          # the sysop monitor (asks for the password)
```

Callers over a network from outside: open the port in the firewall, and encrypt it (TLS: two ways, below).

## Optional parts

### Encrypted connections (telnets, wss): two ways

Both give the same to a caller (an encrypted Telnet, or `wss://` for a browser terminal) and to the BBS (the real address of the caller, so `maxperip`, the login guard,
the log and `mkmon` work).  A port uses one of them.

**Way 1: native TLS, no other program.**  `mklisten` and `mk` use the OpenSSL library (`libssl`, version 3 or 1.1) of the system, loaded only when it is wanted:

```
"tls": { "cert": "/etc/ssl/mkbbs/fullchain.pem", "key": "/etc/ssl/mkbbs/privkey.pem" },
"ports": [
  { "port": 992,  "type": "telnet", "tls": true, "charset": "auto", "config": "/bbs/ra" },
  { "port": 2333, "type": "ws",     "tls": true, "config": "/bbs/ra" }
]
```

* The certificate is a PEM file with the chain (Let's Encrypt's `fullchain.pem`), the key a PEM file **without a pass phrase**; both must be readable by the user `mklisten`
  runs as (the `user` setting; for Let's Encrypt give a group access to the files, or copy them with a deploy hook).  TLS 1.2 and up.
* Each call reads the files again, so a **renewed certificate is used by the next caller** with no reload or restart.
* `mklisten` checks the libraries, the files and that the key belongs to the certificate when it starts (as the user it runs as).  If something is wrong **that port is not opened,
  the log says why, and the other ports run** (without libssl the BBS works as before, only the TLS ports are missing).  `mklisten -t` says the same without starting.
* A caller that does not speak TLS is dropped; the refusal texts of `mklisten` (busy, blocked) are plain text, before the handshake, so a TLS caller sees a failed handshake then.
* A sysop port cannot be TLS (it is on `127.0.0.1`: use an ssh tunnel), and `"tls"` and `"proxy"` do not go together.

**Way 2: `stunnel` in front** (the front end does the TLS, the BBS needs no library): stunnel passes the connection on with a PROXY header, so the real address of the caller is kept:

```
stunnel:   [mkbbs-wss]  accept = 443  connect = 127.0.0.1:2325
                        cert = ...  key = ...  protocol = proxy
mklisten:  { "port": 2325, "type": "ws", "bind": "127.0.0.1", "proxy": true, "config": "/bbs/ra" }
```

`"proxy": true` needs `"bind": "127.0.0.1"`.  Choose this one when you already run stunnel (or nginx / haproxy with the PROXY protocol) for other services, want one place for all
the certificates and cipher settings, or do not want the OpenSSL libraries used by the BBS programs.  `mklisten.example.json` has an example of each.

### Sysop monitor from elsewhere

The `sysop` port should only listen on `127.0.0.1`.  From another machine use an SSH tunnel:

```
ssh -L 2330:127.0.0.1:2330 you@bbs.example.com
telnet 127.0.0.1 2330
```

To let `mkmon` see the nodes the listener keeps a run directory (`rundir`, default `/tmp/mklisten-<uid>`; the installed
configuration uses `/run/mkbbs`) with `node<N>.info` (written by the listener) and `node<N>.snoop` (the Unix socket that
each `mk` opens).  In the monitor, **L** runs a local login on `localnode`.

### QWK network door

A `qwk` port is the door for other QWK systems that call you (see `NETWORKING.md`).  Give it its own port, so the
normal ports are not affected.

### The Fido mailer

```json
"mailer": {
  "config": "/bbs/ra",
  "scan": 300
}
```

* `mkbinkcfg` writes the mailer's settings from the BBS configuration (`mkconfig`: EchoMail > Mailer, Mailer Links and
  Options) at the start and whenever `config.mk`, `echocfg.mk`, `mailer.mk` or `bbsconfig.json` change, or when SIGHUP
  arrives.
* `mkbink` is started while the mailer is switched on in `mkconfig`.  When the settings change it gets SIGHUP (it reads
  them again; no call is cut off).  When the mailer is switched off, or the listener stops, `mkbink` is stopped.
* A mailer that dies is started again after `restart` seconds (default 5, doubled while it keeps dying, at most 300).
* `scan` runs `mktoss -s -q` that often so that messages the BBS wrote are packed and given to the mailer.  After a
  session that received mail the mailer runs `mktoss` itself.  `mktoss` does nothing unless the tosser is on
  (`EchoMail > Mailer > Tosser` in `mkconfig`).
* Other keys: `mkbink`, `mkbinkcfg`, `mktoss` (program paths; default next to `mk`), `settings`, `logfile`, `interval`.
* Whatever happens to the listener, even SIGKILL, takes `mkbink` with it.

### Behind a front end (TLS, SSH)

A port with `"proxy": true` (and `"bind": "127.0.0.1"`) is for a front end that puts a PROXY header first on the connection (stunnel with `protocol = proxy`, `mkbbsssh`).
`mklisten` looks at that header before it uses a node, so `maxperip`, the login guard, the log and `mkmon` have the caller's **real address**.  SSH: `SSH.md`.

### The login guard

`mklisten` can keep an address out that fails to log on again and again (guessing names and passwords), before it uses a node:

The guard is **on by default**: 5 failed log-ons from one address within 10 minutes keep that address out for **one hour**.  Nothing has to be written for that; a section changes it:

```
"loginguard": { "fails": 5,                   failed log-ons from one address that block it (0 = off); default 5
                "window": 600,                within this many seconds; default 600
                "block": 3600,                and the address is refused for this many seconds; default 3600 (an hour)
                "allow": ["127.0.0.1", "::1"],   addresses and nets that are never counted or blocked (the default is the machine itself)
                "message": "Too many failed log-ons from this address. Please try again later." }
```

`"allow"` takes single addresses and IPv4 nets (`"10.0.0.0/8"`); naming it **replaces** the default list, so keep `127.0.0.1` in it when you want the machine itself exempt.  Put your own
network (the address you log on from) in it, or you can lock yourself out for an hour; a restart of `mklisten` also clears the blocks.  `mklisten -t` says what is in force.

A caller who did not get in (wrong passwords, too many tries at the name; **not** one who has gone away: a port scan or a dropped connection) makes `mk` end with the errorlevel **88**; `mklisten` counts that
for the address of the connection (not for the sysop port; behind a front end it is the real address from the PROXY header).  The address
that reaches `fails` within `window` is refused (the message, no node) for `block` seconds and the log says so (`loginguard: 1.2.3.4 is blocked
for 3600 seconds after 5 failed log-ons`, `refused 1.2.3.4: blocked after failed log-ons`).  The counts and the blocks are in memory: a restart clears them.
This is separate from the lock on the account (`PASSWORDS.md`: Lock After Failures), which follows the user name whatever the address.

### Events

The events of the BBS (`mkconfig`: Events) are run by `mklisten` at their times.  Each event has a time, the days it runs, a status
(enabled / disabled), and, in `events.mk`, what it does (see `EVENTS-PLAN.md`):

* **Action:** *Command* (a program and its arguments, no shell, at most 100 characters; put longer ones in a script), *Mailer poll /
  hold / free* of a link or `*` (every link), which talk to the mailer through its control socket, or *Hub pass* (the command is the
  id of the hub: `mk -G<id>` is run; a pass that fails with 5, 6 or 7 is tried again as its map file says, see `NETWORKING.md`).
* **If it was missed** (`mklisten` was down at the time): *Skip*, run *Within N minutes* (default 10), *Run* once however late, or *Run per
  miss* (once for each time it was missed, at most "Most runs", default 5).  What `mklisten` remembers is in `events.run` in the
  BBS directory; delete it and nothing counts as missed.
* **Errorlevel:** when it is not 0, the script `events.sh` in the BBS directory is run after the action, with the errorlevel, the event
  number and the result of the action as arguments (`MKEVENT`, `MKERRORLEVEL`, `MKRESULT` are set too).  It needs the execute bit and a `#!`
  line, and it does what the batch file of the DOS front end did, for example `case "$1" in 5) mktoss ;; esac`.
* **Exclusive:** for work that needs the BBS quiet (packing the message base or the users).  From the moment it is due, new callers are
  refused with the "closed" text; it starts when the callers have left (a *Forced* event disconnects them: the K of the monitor, then
  SIGTERM after 15 seconds) and nothing else runs while it does.  Other events may run at the same time (`parallel`, default 4); the same event
  never overlaps itself.  The sysop monitor port is not closed.
* **Callers before an exclusive event:** a caller who logs on within 24 hours before one is started with `mk -T<minutes>`: the call is cut
  to end when the event is due ("The BBS closes for maintenance in N minute(s)" at the login, and the minutes remaining show it).
  With `"lead": 10` new callers are refused that many minutes before the event instead of when it is due.  Callers already on
  are cut by the same limit, so a *Forced* event usually finds the BBS empty.  A caller who is on when an exclusive event starts to wait (run
  now from `mkmon`, or late) is told too: "The BBS is about to close for maintenance. Please finish and log off." (prompt 536) and nothing else
  changes; for a *Forced* event, `"warn": 5` gives the callers that many minutes first ("The BBS closes for maintenance in 5 minute(s): this
  call ends then", the call is cut to it) before they are disconnected (default 0: at once, as before).  The login message is in the language files, prompts 534
  and 535 (the text before and after the number of minutes) and 536 (the plain warning); `lang/AMERICAN.TXT` and `lang/ENGLISH.TXT` have them in English (they are
  the sample files with the two lines added; `make lang` compiles them to `lang/AMERICAN.lc` and `ENGLISH.lc`, to be copied to the BBS
  directory as `american.lc` and `english.lc`).  A language file without them gives the English text built in.

```
"events": { "config": "/bbs/ra",                    the BBS configuration directory (default: the mailer's)
            "mkevents": "/usr/local/bin/mkevents",  (default: next to mk)
            "parallel": 4,                          events that may run at once
            "interval": 30,                         seconds between looks for a changed configuration
            "lead": 10,                             minutes before an exclusive event when new callers are refused (0 = when it is due)
            "warn": 5,                              minutes a forced exclusive event gives the callers who are on (0 = none: they are disconnected at once)
            "closed": "Closed for maintenance." }   what a refused caller sees
```

* **The monitor:** `E` in the node list of `mkmon` shows the events (time, days, what, state, next and last run, and a `!` for an
  exclusive one); `R` then `Y` runs the chosen event now.  `mklisten` writes `events.info` in its run directory for this and reads
  `events.cmd` from it.

Times are the wall clock of the machine.  `mkevents` prints the events as `mklisten` reads them.

## Signals

| Signal | Effect |
|---|---|
| SIGTERM, SIGINT | stop the listener (and the mailer); connected callers keep running |
| SIGHUP | the mailer reads its settings again |

## Troubleshooting

* **`-t` reports an error:** it names the key and where it is.  Check the commas and quotes.
* **"All lines are busy" with free lines:** the node range is too small, or `maxperip` is reached for that address.
* **The port does not open:** another program has it; or a port below 1024 without `CAP_NET_BIND_SERVICE` (use the
  systemd unit, or a high port and a firewall redirect).
* **The caller sees garbled box characters:** set `"charset": "auto"` (UTF-8 terminals get CP437 converted) or `"cp437"` for
  terminals that show DOS characters as sent.
* **`mk` cannot write its files:** the BBS directory does not belong to the user the listener runs as (`user` / `group`).
* **The mailer does not start:** it is switched off in `mkconfig`, `mkbink` is not installed (`make install MKBINK=<dir>`),
  or the program path is wrong.  Look in the mailer's log file.
* **The sysop monitor shows no nodes:** the run directory is not writable, or each `mk` was not given `MKRUN`.  Use the
  installed `rundir` setting.
