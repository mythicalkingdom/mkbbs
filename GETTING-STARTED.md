# Getting started with MK

This is the map.  It says what MK is made of, how the parts fit together, and in what order to set them up.  Each
part has a document with the details; this one does not repeat them.

## The documents

| Read | When you want to |
|---|---|
| **`MKBBS.md`** | know what the BBS does, the files it uses, the programs, the `mk` options, doors |
| **`MKLISTEN.md`** | let callers in: ports (Telnet, raw, web socket, QWK, sysop), nodes, the sysop monitor, systemd, TLS |
| **`NETWORKING.md`** | join networks: QWK (as a hub or a node) and Fido |
| **`EVENTS-PLAN.md`** | schedule work: events that run commands, mailer polls and hub passes, maintenance that needs the BBS quiet |
| **`PASSWORDS.md`** | keep passwords plain or as hashes, and convert the user base |
| **`TOSSER.md`** | understand the Fido tosser: toss, scan, pack, areafix, routing, file attach |
| **`MAINT.md`** | purge old messages by the limits of the areas (`mkmaint`) |
| **`BACKUP.md`** | back the BBS up and restore it (`mkbackup`), and the `.bak` copies of the configuration files |
| `mklisten.example.json` | a starting configuration for the listener |

## How it fits together

```
                 callers: Telnet, raw TCP, web socket (wss through stunnel)
                                       |
                                   mklisten  --------- sysop: mkmon (watch, chat, kick)
                                       |
                        one  mk  per caller (menus, messages, files, doors)
                                       |
        +------------------------------+-------------------------------+
        |                              |                               |
   the BBS directory             QWK networking                   Fido networking
   (config, users, menus,        mk -Q  (door for systems         mkbink (binkp mailer)
    languages, message and        that call us)                    mktoss (tosser)
    file areas)                  mk -G  (a pass: call a hub)      both started by mklisten
```

* **The BBS directory** is the heart.  `MK=<directory>` tells every program where it is.  The configuration there says
  how everything works, and the editors (`mkconfig`, `mkmenu`, `mkusered`, `mkdraw`) change it.
* **`mk`** is the BBS for one caller.  It reads the configuration, the menus and the language file, and talks to the
  caller on standard input and output.
* **`mklisten`** gives it callers.  It also runs the sysop monitor and the Fido mailer, so one service runs the whole
  system.
* **Message areas are shared.**  The same area can be local, a Fido echo, and a QWK conference; the networks only move
  copies in and out.

## The path from nothing to a networked BBS

1. **Build and install.**  `make && sudo make install`.  Free Pascal 3.2.2 is needed.  (`MKBBS.md`)  On Debian and its relatives `make deb` makes a package
   (`build/mkbbs_<version>_<arch>.deb`, `sudo apt install ./build/mkbbs_*.deb`): the programs go to `/usr/bin`, the unit to the systemd directory, the language files and
   hub profiles to `/usr/share/mkbbs`, the user `mkbbs` and `/etc/mkbbs/mklisten.json` are made when it is installed, and nothing is started (`packaging/mkdeb.sh`).
2. **Make the BBS directory** and set `MK` to it.  Convert an existing Remote Access, QuickBBS or SuperBBS configuration
   with `mkcfgcvt`, or start from a sample and run `mklower` to make DOS-style names lower case.  (`MKBBS.md`)
3. **Configure** with `mkconfig`: the BBS name and paths, security levels, message areas, file areas, protocols, language
   files.  Put the language text through `mklc`.  (`MKBBS.md`)
4. **Menus and screens**: `mkmenu` and `mkdraw`.  Users: `mkusered`.  (`MKBBS.md`)
5. **Try it locally**: `MK=<dir> mk -L`.  Fix what the screens and the log tell you.
6. **Let callers in**: write `mklisten.json`, check it with `mklisten -t`, start it (or enable the systemd service).
   Connect with `telnet localhost 2323` and watch it with the sysop port.  (`MKLISTEN.md`)
7. **Join a network** when the BBS works on its own:
   * **QWK** (a hub like Synchronet, or private nodes): users with the QWK Node flag, a map file, `mk -G<id>` from cron.
   * **Fido**: your address and echo systems in `mkconfig`, then the mailer and the tosser switched on, run by
     `mklisten`.

   Both are in `NETWORKING.md`; the tosser in more depth is in `TOSSER.md`.
8. **Schedule the routine work** with events instead of cron: `mkconfig` > Events, with an `"events"` section in `mklisten.json`
   (`MKLISTEN.md`): the hub pass (`NETWORKING.md`), polls of the mailer, packing the message base (an *exclusive* event, which keeps callers
   out), your own commands.
9. **Run it**: make a service of `mklisten` (systemd unit installed by `make install`), keep the logs (`/var/log/mkbbs`),
   back up the BBS directory, and use `mkmon` to see who is on.

## A few things to know early

* **Names are exact.**  The programs write lower-case file names.  A DOS BBS often refers to names in upper or mixed case;
  after you copy it, run `mklower` and keep the case you use.
* **One process per caller.**  A crash of one caller does not touch another, and restarting `mklisten` does not hang up
  anybody.
* **Passwords can be hashed** (an option, MK configurations only; nothing is forced).  `mkpwconv -x` must be run once on a BBS
  that has an `extusers.bbs` from before: `mk` tells you.  See `PASSWORDS.md`.
* **The configuration can live in one JSON file** (`bbsconfig.json`, `mkcfgcvt` converts to and from it), handy for
  keeping it under version control.
* **No modem layer.**  A caller is a network connection.  Baud rates are only emulated (a port can slow the connection
  down), and the DOS FOSSIL is not needed.
* **Test on a copy.**  `./build.sh` tests on private copies of the sample BBS; do the same for changes of your own.

## Where to go next

* A first caller works: add a second port type (a web terminal) or the QWK door, from `MKLISTEN.md`.
* Mail is next: `NETWORKING.md` for QWK or Fido.
* Something goes wrong: each document ends with a troubleshooting section, and `mk` and `mklisten` have logs
  (`/var/log/mkbbs/`).
