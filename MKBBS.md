# MK BBS

MK is a bulletin board system (BBS) written by Mark May for DOS (Mythical Kingdom Tech BBS) and now running on
Linux, built with Free Pascal.  This document describes the BBS itself: what a caller sees, how it is put together,
the files it uses, the programs of the toolkit, and how to run it.  For setting up networking see `NETWORKING.md`, for
the listener `MKLISTEN.md`, and for the Fido tosser `TOSSER.md`.  `GETTING-STARTED.md` shows how the pieces fit.

## What a caller gets

* **Logon and users.**  Login by name and password, new user questionnaire, per-user security level and flags, time
  limits, and a user record with the settings a caller can change.
* **Menus and screens.**  Every menu is a text file (`*.mnu`) of commands, each with a key, a security requirement and
  an argument.  Screens are ANSI, AVATAR or plain ASCII files.  The text of every prompt comes from a language file
  (`*.lc`), so a BBS can have several languages.
* **Message areas.**  Read, scan, reply, post, quote, search; private and public areas; netmail, echomail and QWK
  conferences.  Message bases of many kinds are supported side by side: Hudson, Squish, JAM, Fido `*.MSG`, Merlin,
  Ezycom, PCBoard, Synchronet (SMB), and a QWK message file.
* **File areas and transfers.**  File lists and searches, upload and download with built-in Zmodem, Ymodem,
  Ymodem-G and Xmodem (no external program needed), and external protocol command lines if you want them.
* **Offline mail.**  A user can take new mail with them as a QWK packet (also QWKE with long names, Bluewave, text)
  and upload replies.
* **Doors.**  Menu command 7 runs a program with the caller's connection and writes the drop files (`DOOR.SYS`,
  `DORINFO1.DEF`, `CALLINFO.BBS`); on Linux a program can run on a pseudo terminal (with a terminal type and size that
  match the caller) or get the connection directly.  Commands 169 and 170 run a BASIC or a Pascal program inside the
  BBS for the caller, locked to its own directory.
* **Chat, paging, bulletins, questionnaires, events.**  As the menus are set up.
* **Terminals.**  ANSI and AVATAR; text is CP437 and is shown as UTF-8 to terminals that want it (decided by the terminal
  type, or set on the port).  Callers can come by Telnet, plain TCP or a web socket.

## How it is built

```
caller --- mklisten --- mk (one process per caller) --- files on disk
              |                  |
              |                  +-- message bases, user file, file lists, configuration
              +-- mkmon (sysop monitor), mkbink (mailer), mktoss (tosser)
```

* `mk` talks to the caller on its standard input and output.  There is no modem layer: the connection is a *session*
  (Telnet, raw, web socket, or the sysop's own terminal).  `mklisten` accepts the connections and starts `mk`; you can
  also start `mk -L` at the console for a local login.
* **One process per caller.**  Nothing is shared between callers except the files, which are locked while written.
* **Names are exact.**  File names the programs make themselves are lower case (`config.mk`, `users.bbs`, `top.mnu`,
  `welcome`, ...).  A name that comes from the configuration, a menu, the command line or the environment is used as
  written.  If a BBS from the DOS days has mixed-case references, `mklower` makes them lower case.
* **The BBS is found through the environment.**  `MK` is the directory of the configuration (`RA`, `QUICK` and `SBBS`
  name a Remote Access, QuickBBS or SuperBBS configuration instead, and are read the same way).  `MKJSON` points to a
  configuration kept in one JSON file.

### Configuration files (MK format)

| File | Holds |
|---|---|
| `config.mk` | the main configuration: names, paths, security, protocols, packers, languages, defaults |
| `messages.mk` | the message areas |
| `files.mk` | the file areas |
| `echocfg.mk` | Fido echo systems and echo areas |
| `mailer.mk` | mailer settings, links, routes |
| `bbsconfig.json` | the whole configuration in one JSON file (optional; every setting has a place in it) |
| `users.bbs`, `lastread.bbs`, `userson.bbs` ... | users, last read pointers, who is online |
| `*.mnu`, `*.lc`, screens | menus, language files, display files |

`mkcfgcvt` converts a configuration between the formats: MK (1), Remote Access (2), QuickBBS (3), SuperBBS (4) and MK as
one JSON file (5).  Between 1 and 5 nothing is lost.

## The programs

| Program | Purpose |
|---|---|
| `mk` | the BBS itself; also the QWK network pass (`-G`) and the QWK login (`-Q`) |
| `mklisten` | accepts callers, starts `mk`; runs the sysop monitor and the mailer (`MKLISTEN.md`) |
| `mkmon` | sysop monitor: nodes, who is on, watch, type into, disconnect, add or take time |
| `mkconfig` | the configuration editor (full screen) |
| `mkmenu` | menu editor for `*.mnu` files |
| `mkusered` | user editor |
| `mkread` | the message reader for the sysop, local |
| `mkdraw` | screen editor for ANSI, AVATAR and ASCII screens |
| `mklc` | language compiler: `mklc english.txt` makes `english.lc` |
| `mkcat` | show a CP437 screen or log on a terminal |
| `mklist` | list the message areas to a text file |
| `mknodeidx`, `mknodelist` | build the nodelist index, look an address up |
| `mkcfgcvt`, `mklower` | convert a configuration, make references lower case |
| `mkbinkcfg`, `mktoss` | the Fido mailer settings and the tosser (`NETWORKING.md`, `TOSSER.md`) |
| `mkqwk`, `mkqwkcfg` | the older offline mail door and its configuration |

The programs that edit (`mkconfig`, `mkmenu`, `mkusered`, `mkdraw`, `mkqwkcfg`) use a full screen text interface with a menu
bar (Alt-key shortcuts, `F1` for help, `Esc` to leave).

## mk command line

`mk` is normally started by `mklisten`, which gives each caller its own options.  By hand:

| Option | Meaning |
|---|---|
| `-L` | local login at the console |
| `-N<n>` | node number |
| `-S<type>` | session type (`telnet`, `raw`, `ws`, or none for standard I/O) |
| `-B<baud>` | emulate that line speed (0 = full speed) |
| `-A<address>` | the caller's address (for the log) |
| `-H` | a PROXY header comes first (behind `stunnel`) |
| `-U<set>` | character set of the caller: `AUTO`, `CP437`, `UTF8` |
| `-Q` | the QWK network login (`Login:`, `Password:`, `QWK:`) |
| `-G<id>` | a pass with the QWK network system `<id>`, no caller |
| `-C<port>`, `-E<level>`, `-P`, `-R`, `-T<min>`, `-V`, `-Z<baud>` | as in the DOS version: port, exit level, log to printer, reload, minutes to the next event, 80x25, forced baud |

## Setting up a BBS in short

1. Build and install (`make`, `sudo make install`).  Needs Free Pascal 3.2.2.
2. Make a directory for the BBS and give it to the user the BBS runs as (the install makes a `mkbbs` user).
3. Run `mkconfig` with `MK` set to that directory (`MK=/bbs/ra mkconfig`) and set the names, paths, security levels, message
   areas, file areas, protocols and language files.
4. Edit the menus (`mkmenu`) and screens (`mkdraw`), or start from a sample BBS (they come as DOS-style data; `mklower`
   makes the references lower case).  Compile language text with `mklc`.
5. Set up `mklisten` and start it (`MKLISTEN.md`).
6. Log in at the console to check: `MK=/bbs/ra mk -L`.  The first user to register can be raised to sysop with `mkusered`.

## Doors and extensions

* **Programs:** menu command 7 (`*N` node, `*D` DOOR.SYS, `*F`/`*L` names, `*T` minutes left, `*S` give the program the
  caller's connection itself, and others).  Without `*S` the program runs on a pseudo terminal.
* **BASIC and Pascal:** commands 169 and 170 run a program for the caller inside a sandbox (`games/` has an example).
* **Network doors:** a port of type `qwk` (`MKLISTEN.md`) is the entrance for QWK network systems.

## Testing

`./build.sh` builds everything and runs the test suite (over 500 checks, about 11 minutes); `make test` does the same.
`./build.sh --build-only` builds without the tests.  Programs are tested through pseudo terminals and on private copies
of the sample BBS, never on the sample itself.

## Documents

| Document | About |
|---|---|
| `GETTING-STARTED.md` | how it all fits together, in what order to set things up |
| `MKBBS.md` | this document |
| `MKLISTEN.md` | the listener: ports, nodes, monitor, mailer, systemd |
| `NETWORKING.md` | QWK and Fido networking set-up |
| `TOSSER.md` | the Fido tosser in detail |
