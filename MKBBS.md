# MK BBS

MK is a bulletin board system (BBS) written by Mark May for DOS (Mythical Kingdom Tech BBS) and now running on
Linux, built with Free Pascal.  This document describes the BBS itself: what a caller sees, how it is put together,
the files it uses, the programs of the toolkit, and how to run it.  For setting up networking see `NETWORKING.md`, for
the listener `MKLISTEN.md`, and for the Fido tosser `TOSSER.md`.  `GETTING-STARTED.md` shows how the pieces fit.

## What a caller gets

* **Logon and users.**  Login by name and password (kept plain, as in the DOS days, or as a hash: `PASSWORDS.md`), new user
  questionnaire, per-user security level and flags, time limits, and a user record with the settings a caller can change.
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
* **Chat, paging, bulletins, questionnaires.**  As the menus are set up.
* **Events.**  `mkconfig` > Events: a time, the days, and what it does (a command, a poll / hold / free of the mailer, a hub pass), what
  to do when it was missed, and whether it needs the BBS quiet (exclusive).  `mklisten` runs them (`MKLISTEN.md`), and `mkmon` shows them
  (E).  The old errorlevel runs the script `events.sh` in the BBS directory.  Details and the file (`events.mk`): `EVENTS-PLAN.md`.
* **Terminals.**  ANSI and AVATAR; text is CP437 and is shown as UTF-8 to terminals that want it (decided by the terminal
  type, or set on the port).  Callers can come by Telnet, plain TCP or a web socket.

**Offline mail extras.**  A packet of the offline mail door (`mkqwk`) or of the offline menu of `mk` can carry the BBS **screens** (welcome, news
and goodbye), **bulletins** (up to ten) and a **list of new files**, for the callers who ask for them (the user's offline settings) and as
the sysop allows.  The names are settings: `mkconfig` > Messages > Offline (Offline Mail Parameters: Allow / Force for each, the three screen names, ten bulletin
names and **New Files Head**, the screen above the new files list; this is all `mk` uses: it needs nothing of the door's `config.mko`) and, for the door (`mkqwkcfg`, which edits the door's own `config.mko`), *Screens* (the names and the heading screen of the new files list) and *Main Configuration* (*New Files / Screens / Bulletins* set to Never, Always or Ask).  A screen or bulletin is taken as the caller's terminal gets it online
(`.avt`, `.ans` or `.asc` in the text directory) and goes into every packet under its own name; `CONTROL.DAT` names the screen files that are
really there; bulletins are `BLT-1`, `BLT-2` ... (the readers' names); a name with no file is left out.  The new files list is `newfiles.dat`: the heading screen, then for each file area the caller may
list the files uploaded since the caller's new files date, laid out like the online list (name, date, size, description, long descriptions wrapped under
it), and a count (at most 1000 lines).  The caller's new files date moves to today only when the packet was made and kept.  A QWK network
node gets none of these, and a network pass never asks a hub for them.  (The file names of an area must be in upper case on disk: the list matches
the name in `files.bbs` in upper case.)  With QWKE long names the packet also has `TOREADER.EXT` (the QWKE file for the reader: the caller's alias, an `AREA` line with flags for each conference in the packet, a `BULL` line for each
bulletin).  A reader's reply packet may carry `TODOOR.EXT`: `AREA <conf> D` drops a conference, `a` / `p` / `g` take it (all, personal, personal and to All), and `RESET <conf> [n]` moves the last read pointer (no number: back to the start of the base).  The lines for things MK has no
such lists for (keywords, filters, twits) or takes no files for (attach, file, request) are ignored.  Details: `QWK-EXTRAS-PLAN.md`.

`mkusered` makes `users.bbs` when the BBS has none (the first user is saved, and a save that cannot write says so), and a new user gets the first
call, last call and new files date of today.

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
| `fileecho.mk` | file echoes (TIC): the echoes, the systems' TIC and FileFix passwords, the check command and the pass-through spool |
| `mailer.mk` | mailer settings, links, routes |
| `bbsconfig.json` | the whole configuration in one JSON file (optional; every setting has a place in it) |
| `users.bbs`, `extusers.bbs`, `lastread.bbs`, `useron.bbs` ... | users, their extended records (including a hashed password), last read pointers, who is online |
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
| `mklistmsgarea` | list the message areas to a text file |
| `mknodeidx`, `mknodelist` | build the nodelist index, look an address up |
| `mkcfgcvt`, `mklower` | convert a configuration, make references lower case |
| `mkbinkcfg`, `mktoss` | the Fido mailer settings and the tosser (`NETWORKING.md`, `TOSSER.md`) |
| `mkbackup` | a backup of the BBS in one `.tar.gz` (made while it runs), its list, test and restore (`BACKUP.md`) |
| `mkbbsssh` | the shell of the SSH account of the BBS: connects an SSH daemon to `mklisten` (`SSH.md`) |
| `mkhatch` | put files into a file echo (TIC): stored in the file area and sent to the systems the echo goes to |
| `mkqwk`, `mkqwkcfg` | the older offline mail door and its configuration (`config.mko`): kept for systems that do not run `mk`; nothing else in MK uses it |
| `mkfreq` | answers FTN file requests for `mkbink` (see `NETWORKING.md`) |
| `mkpwconv` | expands `extusers.bbs` (`-x`) and converts plain passwords to hashes (`-h`); see `PASSWORDS.md` |

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
| `-D` | with `-G`: a dry run, it says what would be sent and changes nothing |
| `-C<port>`, `-E<level>`, `-P`, `-R`, `-T<min>`, `-V`, `-Z<baud>` | as in the DOS version: port, exit level, log to printer, reload, minutes to the next exclusive event (`mklisten` sets it: the call ends then), 80x25, forced baud |

### Files that `mk` cannot load: the log says so

When `mk` cannot load one of these, a line goes into the BBS log (the file named in `mkconfig`, `/var/log/mkbbs/mk.log` in the installed setup), with the full name of what it looked for:

```
Language file /bbs/ra/american.lc could not be loaded (not found)
Menu nomenuhere.mnu could not be loaded (not found; looked in /bbs/menus/ and /bbs/menus/)
Screen /bbs/txt/noscreenhere.ans could not be displayed (not found)
Questionnaire /bbs/ra/noquesthere.q-a could not be loaded (not found)
```

* The reason is `not found`, `cannot be opened` or `cannot be read`.  A language file that is missing leaves the prompts empty, a menu leaves the caller without items: this is where to look first.
* The same line is written **once in a call** (a missing menu is asked for each time its key is pressed).
* **Screens:** only the ones a sysop *names* are reported: a menu item that shows a screen (commands 5, 40, 45) or a questionnaire that does.  The screens that `mk` tries on its own (`welcome`, `news`,
  `goodbye`, `sec<level>`, `birthday` ... most of them optional) are not, or every call would write a line for each.
* The global menu (`global.mnu`) is optional: it is reported only when it is there and cannot be read.

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
  caller's connection itself, and others).  Without `*S` the program runs on a pseudo terminal.  It runs in `node<N>` below the BBS
  directory, a directory of its own for each node, where the drop files and `EXITINFO.BBS` are written.
* **DOS doors:** `tools/mkdosdoor` runs them in dosemu2 with COM1 on the terminal of command 7 (`DOS-DOORS.md`).
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
| `PASSWORDS.md` | plain and hashed passwords: the setting, what changes, converting the user base |
| `TOSSER.md` | the Fido tosser in detail |
| `packaging/` | `mkdeb.sh` and the maintainer scripts of the Debian package (`make deb`) |
| `HUBS.md` | QWK hubs: every map file setting, switch and exit code, the transports (Telnet, FTP, FTPS, exec), what was checked against what |
| `hubs/*.scr` | QWK hub profiles (installed in `share/mkbbs/hubs`; `mk -G -P` lists them; NETWORKING.md) |
| `BACKUP.md` | backing up and restoring the BBS: what is held, `mkbackup`, the `.bak` of the configuration files, an event for it |
| `SSH.md` | SSH for callers: OpenSSH or Dropbear in front, `mkbbsssh`, no password at the SSH level |
| `DOS-DOORS.md` | DOS doors on Linux: dosemu2 and `mkdosdoor` |
| `TIC-PLAN.md` | file echoes (TIC): how they work, what each part does, the decisions |
