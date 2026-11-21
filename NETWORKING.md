# MK networking: overview and setup

MK exchanges messages with other systems in two ways: **Fido** (FTN: echomail and netmail in packets, moved by a
mailer) and **QWK** (offline mail packets, `.QWK` down and `.REP` up, moved by a transfer or by a script).  Both
write into and read from the same message areas of the BBS, so a message area can be a local area, a Fido echo, a QWK
conference, or more than one of these.

This document is the overview; steps for each kind follow.  Details of the tosser are in `TOSSER.md`, and the header
of `src/MKQwkNet.pas` has the full description of the QWK pass.

## The pieces

| Piece | What it does |
|---|---|
| `mkconfig` | All settings: message areas, EchoMail (systems, areas, archivers, mailer, routing), transfer protocols, packers. Every setting is also in the JSON form of the configuration (`bbsconfig.json`, see `mkcfgcvt`). |
| `mk` | The BBS.  Also does the QWK network work: `mk -G<id>` (a pass with a remote QWK system), `mk -Q` (the login a remote QWK system uses when it calls us). |
| `mklisten` | Listens on ports and starts `mk` for each caller.  A port of type `"qwk"` is the door for QWK systems; the `"mailer"` section runs the Fido mailer. |
| `mkbink` | The binkp mailer (a separate program).  Calls and answers Fido systems and keeps the BSO outbound. |
| `mkbinkcfg` | Makes the mailer's settings from the BBS configuration. |
| `mktoss` | The Fido tosser: toss incoming mail into the areas, scan new local messages, pack them, hand them to the mailer, answer areafix requests, turn file request netmail into `.req` files. |
| `mkfreq` | Answers file requests: `mkbink` runs it for each `.req` that arrives (security profile, file areas, magic names, passwords, limits). |
| `mkqwk` | The older offline mail door for users (not needed for networking; `mk` does not depend on it). |

Which BBS a program works on comes from the environment variable `MK` (the directory of the configuration), for
every program.

### How a message travels

```
Fido:  area <-> mktoss <-> packets/bundles <-> mkbink (binkp) <-> other systems
QWK:   area <-> mk -G <-> .QWK / .REP <-> (mk -Q door, or mk calling a hub) <-> other systems
```

* **Fido** is peer to peer: each system is linked to the echoes it wants, mail is passed along (SEEN-BY and PATH
  keep it from going round in circles), and netmail is routed.
* **QWK** is hub and node: a node is a *user* of the hub.  What the hub packs for it is what that user has chosen for
  offline mail, and the last read pointers of that user say what was sent already.  The node sends its new messages
  up in a reply packet.

### What both sides do for you

* Duplicates are dropped (Fido: MSGID or a checksum, 14 days; QWK: a `.dup` file per system).
* A message is exported only once.  Fido messages are marked sent; QWK uses the last read pointers.
* Messages that were just imported are not sent back to where they came from.

## Common first steps

1. Install the programs (`make install`) and point `MK` at the BBS configuration directory.
2. In `mkconfig`, set up the message areas you want to network (a message area is of any base type: Hudson,
   Squish, JAM, Fido `*.MSG`, Merlin ...).
3. Run `mklisten -c yourfile.json -t` to check the configuration (`mklisten.example.json` is a starting point), then run
   it, or install the systemd unit (`mklisten.service.in`).

---

## Setting up QWK networking

There are two directions.  You can be the **hub** (other systems call you or fetch from you) or the **node** (you
call a hub, such as a Synchronet BBS), or both with different systems.

### A. Be a hub for a QWK system

1. **Create the node's user.**  Add a user record named with the QWK id of the system (this is its login name), give it
   a password, and switch on **QWK Node** in the user editor.  A new node gets `CONTROL.DAT` and `DOOR.ID` in its
   packets by default.
2. **Security.**  Give it a security level and flags that can read the areas it is to get.
3. **Offline areas.**  The areas must be allowed for offline mail (area option *Offline*; a *forced* offline area
   cannot be dropped).  The node's subscription is its offline area choice: set it by logging in as that user, or let
   the node set it itself with control messages (below).
4. **Packer and protocol.**  Set the packer (ZIP) in the user record.  `mkconfig` holds the command lines of the packers
   and the transfer protocols (Zmodem, Ymodem, Ymodem-G, Xmodem).
5. **Open a door for it.**  In the `mklisten` configuration add a port of type `qwk`:

   ```json
   { "port": 2327, "type": "qwk", "config": "/bbs/ra" }
   ```

   The node telnets in and sees `Login:`, `Password:`, then `QWK:` with **D**ownload, **U**pload, **B**oth, **Q**uit.
   Only users with the QWK Node flag are let in.  The prompts are the same as Synchronet's, so scripts written for
   Synchronet work here.  Nothing is asked: the packet is `<BBSID>.QWK`, the reply is `<BBSID>.REP`.
6. **Import what the node sends.**  A reply packet that was uploaded is posted into the areas as it arrives.  Conference
   numbers in the packet are the area numbers.
7. **Control messages.**  The node can send a message **to `MK` or to `SBBS`** (both work) in its reply packet:

   | Subject / text | Does |
   |---|---|
   | `ADD [conf] [pointer \| -messages \| mm/dd/yy]` | subscribe to an area, optionally set the starting point |
   | `DROP [conf]` | unsubscribe |
   | `RESET` / `RESETALL` | send the area (all areas) again from a chosen point |
   | `CONTROL ON` / `CONTROL OFF` | with / without `CONTROL.DAT` and `DOOR.ID` |

   Other Synchronet commands (FREQ, FILES, ATTACH, CTRL-A, TZ, VIA, MSGID, NDX) are accepted and ignored.  `DOOR.ID`
   in the packet says `CONTROLNAME = MK` and lists what is supported.

### B. Be a node: call a hub

Do this on your system when you want to take mail from a hub.

1. **A user for the hub.**  Make a user record for the hub (any name; it is called the *system's id* below) and switch on
   **QWK Node**.  This user's offline area choice and last read pointers are the bookkeeping for the hub: **its read
   access decides which areas get sent**, so give it a security level and flags that can read the areas.  Set its
   packer (ZIP) and the packet limits.
2. **Create the areas** that the hub's conferences go into, and check that the hub user may read them.  Areas that are
   missing their message base are created on the first import (Merlin).
3. **The map file.**  Create `<id>.map` in the BBS directory (the id exactly as you will give it to `mk -G`).  Words on a
   line; `;` or `#` begins a comment:

   ```
   inbound   /var/spool/qwk/in        # where <id>.QWK arrives
   outbound  /var/spool/qwk/out       # where <id>.REP is made
   user      Hub User Name            # the user record (default: the id)

   hub       bbs.example.com:23       # call it by Telnet (leave out when files are moved by something else)
   profile   synchronet               # synchronet or mk;  or  script  MYHUB.scr  for one of your own
   login     MYLOGIN
   password  secret
   protocol  Z                        # Z Zmodem, Y Ymodem, G Ymodem-G, X Xmodem
   transcript MYHUB.log               # what was said (the password is not written)

   conf 4029 55                       # conference 4029 of the hub is message area 55 here
   conf 1003 56
   ```

   An area without a `conf` line is not sent; a conference without one is not posted.  Keep the file private
   (`chmod 600`: it has the password).
4. **Find the conference numbers.**  Call the hub once by hand, or look at `CONTROL.DAT` in a packet it made: it lists
   every conference with its number and name.
5. **Run a pass:**

   ```
   MK=/bbs/ra mk -G<id>
   ```

   The pass: makes the reply packet (new messages of the subscribed areas), logs in to the hub, sends the reply packet,
   downloads its packet, and posts it.  Duplicates are skipped.  The packet is kept as `<id>.QWK.old`; the reply file is
   deleted when the hub has it.
   **Look before you send:** `MK=/bbs/ra mk -G<id> -D` is a dry run.  It prints (on the error output) what the reply packet would
   hold, area by area and from which message number on, and whether a reply packet or a packet of the hub is waiting.  It makes no
   packet, moves no pointer, does not call the hub and writes no file of the BBS.  Do it before the first pass, and whenever you
   moved a last read pointer by hand: everything after a hub user's pointer goes up to the hub, including mail that was
   imported from it earlier if the pointer was left behind it.
6. **Schedule it** with cron or a systemd timer (every 15 or 30 minutes is typical).
7. **Exit codes** (for scripts): 0 done, 1 no map file, 2 the user is missing or is not a QWK node, 3 the reply packet
   could not be made, 4 the hub's packet could not be read, 5 the hub could not be reached, 6 the login or transfer
   failed, 7 the hub did not accept the reply packet (see below).
8. **Let the BBS schedule it** (instead of cron): in `mkconfig`, Events, make an event for the time (or times: one event
   each) with the action **Hub pass** and the id of the hub as the command, and run `mklisten` with an `"events"` section (see
   `MKLISTEN.md`).  A pass that fails with 5, 6 or 7 is tried again: the map file says how often and how soon:

   ```
   retries   3        # new tries after the first (default 3, 0 = none)
   retry     300      # seconds before the first new try, doubled each time (default 300)
   retry-max 3600     # ... at most this long between tries (default 3600)
   onfail    notify.sh   # run when it has failed for good: <id> <result> <tries>  (in the BBS directory, or a full path)
   ```

   What the hub says after it got the reply packet can show that it refused it (a sub-board that is not there, for
   example).  Look in the transcript for the text, and tell the map file:

   ```
   reply-error  not found      # any of these in what the hub said = refused (up to 8)
   reply-ok     unpacked       # when there are any, one of these has to be there
   ```

   **What came from the hub does not go back.**  The messages a pass posts from the hub's packet are written down in
   `<id>.imp` next to the map file (area, number, day).  They are left out of every reply packet, even when a last read pointer is
   put back behind them by hand (the dry run says how many it leaves out); entries are dropped after 60 days.  Without this a pointer that
   lags makes a gate send a newsgroup's own posts back to it.
   (A Synchronet hub says `Invalid Conference 9999` after it unpacks a reply packet with a message for a conference it does not have; with
   `profile synchronet` that is a `reply-error` by default.)
   **Colour codes of a Synchronet hub.**  The messages of a Synchronet hub can carry its Ctrl-A codes (`^Ah^Ac` ... for colours and attributes).
   Left alone, a line that starts with one is taken for a kludge line and is left out, and the codes inside a line show as odd characters in
   the reader.  `strip-ctrla yes` in the map file takes the Ctrl-A and the character after it out of every message that is posted from the hub's
   packet and keeps the lines that began with one; a real kludge line (`^AMSGID: ...`) is dealt with as before.  The default is `no`.
   A refused reply packet stays in the outbound directory (exit 7) and goes again with the next pass; nothing new is
   made before it has gone, so nothing is lost or sent twice.  With neither line nothing is checked.
9. **Check the transcript** `<id>.hub.log` (next to the map file, unless you named another) when something does not work.

If you move the files yourself (FTP, a different program) leave out the `hub` line: `mk -G<id>` then only reads
`<id>.QWK` from the inbound directory and writes `<id>.REP` to the outbound directory.

**If the hub is not Synchronet or MK**, write a script: a few lines of `expect` / `send` (see `MKHubScr` in `src/`):

```
timeout 30
expect "login:|user name"
sendln "%login%"
expect "password:"
sendln "%password%"
expect "main menu"
...
download
upload "%rep%"
```

### What to check on a Synchronet hub

* The sub-boards you want must be allowed for **QWK networking** (the sub's settings), and, if they come from another
  network (Usenet, DOVE-Net), the hub may need *gating between networks* switched on for them.
* Your user needs **post** access to a sub to have your messages accepted.
* To get older messages, set the hub-side pointer back: use the `P` menu in the QWK door at the hub, or an `ADD <conf>
  -<count>` control message from MK.

---

## Setting up Fido networking

Fido mail needs the mailer (`mkbink`) and the tosser (`mktoss`).  Netmail is routed; echomail is passed on through the
systems you link.

1. **Your address.**  In `mkconfig` set your main address (and AKAs) and your sysop name.
2. **Areas.**  In `mkconfig` create a message area for each echo you carry and a *netmail* area.  Give an echo area its
   **tag** (EchoMail), its tear line and origin, and the address (AKA) it uses.
3. **Echo systems.**  `EchoMail > Systems`: add each system you exchange mail with.  For each system set:
   * its address;
   * the **archiver** it takes (ZIP is the usual choice);
   * the **flavour** (immediate, crash, normal, hold);
   * the **areafix password** and, if you agreed one, the **packet password**;
   * the networks it may see (for areafix).
4. **Link systems to areas.**  `EchoMail > Areas`: for each echo choose the systems that get it (*Echo to*), and the
   **hub** (the system you get it from).  Options: keep or hide path and seen-by, pass-through.
5. **Archivers and paths.**  `EchoMail > Archivers` has the pack and unpack command lines; `EchoMail > Options` has
   the inbound, secure inbound, outbound, and the maximum packet size.  `General > Paths` has the file attach
   directory.
6. **Routing.**  `EchoMail > Routing`: the first route whose patterns fit wins, for example `1:120/* !1:120/9` via your
   uplink.  A system in your echo systems list is always sent to directly.  A route's flavour overrides the message's.
7. **Turn on the mailer and the tosser.**  `EchoMail > Mailer`: set the mailer's own settings (binkp, sessions,
   passwords for the systems you call), then switch on **Tosser**.  The tosser does nothing while it is off.
8. **Let `mklisten` run it.**

   ```json
   "mailer": { "config": "/bbs/ra", "scan": 300 }
   ```

   `mklisten` makes the mailer's settings with `mkbinkcfg`, starts `mkbink` while the mailer is on, runs `mktoss` after
   every session that received files, and every `scan` seconds runs a scan (`mktoss -s -q`) so that messages the BBS
   wrote are packed and queued.  Add `"mktoss"` to name the program if it is not found.
9. **Check by hand** at first:

   ```
   MK=/bbs/ra mktoss -f          # toss the inbound now (also when the tosser is off), then scan and pack
   MK=/bbs/ra mktoss -t -f       # toss only
   MK=/bbs/ra mktoss -s -f       # scan and pack only
   ```

   Exit 0 is fine, 2 means some mail could not be tossed or sent, 3 means the tosser is not switched on.
10. **Areafix.**  A downlink sends a netmail to `Areafix` (or `AreaMgr`) with its areafix password as the subject and
    commands in the text: `%LIST`, `%QUERY`, `%UNLINKED`, `%HELP`, `+AREA`, `-AREA` (`*` and `?` work).  Your answer is a
    netmail.  When you carry an area from a hub, the hub is asked for it when your first downlink takes it, and the
    request is withdrawn when the last one leaves (pass-through areas).

### File requests (FREQ)

File requests (FTS-0006) let one system ask another for files by name.  A request is a `.req` file with one line per request,
`name`, `name !password` (the password is 6 characters or fewer), and, after them, an **update request**: `+time` asks for the
files that match the name and are *newer* than the time, `-time` for those dated *up to and including* it (the time is UNIX
seconds, up to 10 digits; the dates are those of the files).  Example line: `NEWOPUS.* !pw +599634000`.  The plan and the
details are in `FREQ-PLAN.md`.

**Asking another system.**  Write a netmail to it with the file request option set (the netmail options of the editor) and
the names in the subject, blank separated, with `!password` and then `+time` or `-time` after the name they are for:
`THIS.ARC !THAT NODELIST.* +599634000`.  `mktoss`
turns it into the names of that system's `.req` in the BSO outbound and marks the netmail sent; the mailer calls the system, and
the files arrive in the inbound like any file.  This works for a system you call directly (in the echo systems list); a
request for a node behind a route goes out as an ordinary netmail.  A password of more than 6 characters, a password or a time before a
name, a password after the time, a time of more than 10 digits and an empty subject are refused: the netmail stays unsent and
the log says why.  (`mkbink queue -R name [!password] [+time|-time] ...` does the same from the command line.)

**From the sysop monitor.**  On the mailer screen of `mkmon`, **F** asks a system for files at once: the address (the chosen link at
first), a host (empty: the host of the link, else the nodelist's), a session password (empty: none, an unsecure session), the names
(`name [!password] [+time|-time]`, blank separated) and whether to call now.  The system need not be a link: its host is found in the
nodelist index (`mknodeidx`; IBN and INA flags; every nodelist in the index is searched and the zone number picks the list, so a network
with a zone of its own works next to Fidonet; two networks that use the same zone number cannot be told apart).  `mkbink` writes the
`.req`, calls, and the answer comes back in the same session when both sides offer multiple batches.

**Strangers.**  `accept-unknown yes` (mkconfig: Mailer > Accept unknown) lets a system that is not in the links list call; give it
no password for an anonymous (unsecure) session, and turn on "unsecure" on File Requests so that it can ask for files, as the anonymous
file requests of the BBS days.  What it may take is the same list as for everyone else: the areas with Allow file requests, the
unsecure security profile and the magic names.  What it sends goes to `inbound-unsecure`.  Without `accept-unknown`, mkbink refuses a
caller that is not a link ("Bad address").

**Answering requests.**

1. The mailer must be on (`EchoMail > Mailer`).
2. `EchoMail > File Requests`: switch **Answer file requests** on.  **File request security** is the security (level, flags with F2)
   of a system that has none of its own; level 0 with no flags means such systems get nothing.  **Without a password** also
   answers callers that did not use a session password (they never get password protected names).  **Tell by netmail** sends
   the requester a netmail that lists what could not be sent.  **Most files** and **Most KB** limit one request (0 = 20 files, no
   size limit).
3. `EchoMail > Mailer Links`: a link can have its own **File request level** (F2 for flags); 0 means the file request security.
4. `Files > Areas`: only the file areas with **Allow file requests** are searched, and only when the security of the system meets
   the area's *view* and *download* security.  A system gets what a caller with that security could download.
5. Magic names (optional): the **Magic names file** has lines `NAME path [password]` (`;` or `#` starts a comment).  The path can
   have `*` and `?` in its last part (`NODELIST /bbs/nodelist/nodelist.*`); `@LIST` (`FILES @LIST`) makes a list of the files the
   system may request.  A name with a password is only given in a session with a password and with `!password` after it.
6. Restart the mailer (`mklisten` writes the settings with `mkbinkcfg` and `mkbink` runs `mkfreq` for each request that arrives).

**Answering for another mailer (binkd and others, SRIF).**  `mkfreq -S <srif file>` is `mkfreq` for a mailer that speaks SRIF
(FSC-0086 / FSP-1040).  In `binkd.cfg` of that system, with the BBS configuration in `MK`:

```
exec "/usr/local/bin/mkfreq -S *S" *.req
```

The requester is the first AKA, `RemoteStatus PROTECTED` is a secure session, and the names found go to the response list with a `+` (keep the
file); only the list of a `@LIST` name is marked `=` (erase after it was sent), because the program made it.  You get everything `mkfreq` does
(file areas with Allow file requests, security profiles, magic names, passwords, update requests, limits); the netmail note of "Tell by netmail"
is made too.  A request processor must never be able to delete a file it only offers: with the SRIF `=` or `-` in front of a name the mailer erases it.

**When a file is not found,** the requester is only told "not found" (that way a refusal does not say what exists), but the log of `mkfreq`
(the `mkbink` log, or the screen when you run it by hand) says why: the areas it looked in, the areas that allow requests but whose view or download
security the system's level does not meet (with their levels), and the areas without "Allow file requests".  A new link's "File request level" and the
file areas' security are the usual causes: a system of level 1 only gets areas whose view and download security are 1 or less.

**A system that does not run MK at all.**  `mkfreq` needs only a configuration, and the configuration can be one JSON file: copy
`bbsconfig_mkfreq_example.json` to `/etc/mkfreq/bbsconfig.json`, list your folders as file areas (`"Attr": 32` = allow requests, absolute
`FilePath` with a slash at the end, the security of each area), set the request security (`mailer.ReqSec`, and per known system under `mailer.Links`),
and run it with `MKJSON=/etc/mkfreq mkfreq -S <srif file>`.  Nothing else of the BBS is needed.  The wrapper for binkd:

```sh
#!/bin/sh
MKJSON=/etc/mkfreq exec /usr/local/bin/mkfreq -S "$1"
```

**The mailer's side of that rule.**  `mkbink` obeys a delete mark of a request answer (`^`, or `=` / `-` of SRIF) only for a regular file directly in its
`freq-tmp` directory (`freq-tmp` in its settings, default `freq-tmp` in the inbound directory; `mkfreq` makes its lists there through `MKBINK_TMP`).
For any other file the mark is ignored, the file is sent and kept, and the log says so.  `mkbink` can also use any SRIF processor with
`on-freq-srif <command>` instead of `on-freq`.

What `mkfreq` does with a name (an update request filters the matches by their date; a request that finds nothing newer is no
problem and no note, only a name that matches nothing is "not found"): wildcards and upper case are fine; names with a slash, a backslash or a leading dot are refused;
a name that nothing matches is "not found" (the same words for a file the system may not have, so a refusal does not tell what
exists).  Passwords are never written to the log.  The files are queued for the requester as **hold mail**.  When both mailers
offer *multiple batches* (the default, `multi-batch` in the mailer's settings), the request is answered at the end of the batch that
brought it and the files go in the next batch of the same session.  Otherwise, or when you called the requester, they are sent when
the requester calls to pick them up; your mailer does not call it for them.  The netmail of "Tell by netmail" is hold mail and is
picked up the same way.

### Things that end up in `bad/bad.pkt`

Mail from a system that is not in your list, an echo whose tag you do not carry, a system that is not linked to that
echo, or a damaged packet.  The inbound directory has a `bad` folder for them; a damaged bundle is renamed `.bad`.
Mail in the *unsecure* inbound (callers without a password) is never tossed.

### File attaches

A netmail with the file attach flag names its files in the subject: `^name` deletes it after sending, `#name`
truncates it, no path means the file attach directory.  All files must be there or the netmail waits.  Files that arrive
go from the inbound to the attach directory under the name in the subject.

---

## Which one?

| | Fido | QWK |
|---|---|---|
| Topology | any to any, with echo links and routes | node to hub |
| Transport | binkp (`mkbink`) | Zmodem etc. over Telnet, or any file transfer |
| Programs | `mkbink`, `mktoss` | `mk -G`, `mk -Q`, `mklisten` |
| Passwords | session and packet passwords | user password |
| Control of areas | areafix | control messages (`ADD`, `DROP` ...) |
| Typical use | FidoNet, fsxNet, other FTNs | DOVE-Net, Synchronet hubs, small private networks |

## Troubleshooting

* **Nothing is sent to a QWK hub:** the hub user cannot read the area (security or flags), or the area has no `conf`
  line in the map file, or the last read pointer is already at the end.
* **A QWK pass ends with exit 5 or 6:** read `<id>.hub.log`; it shows each prompt the script waited for.
* **A packet is waiting and nothing new is taken:** `<id>.QWK` is still in the inbound; it could not be read.  Fix or
  remove it, then run the pass again.
* **Fido mail does not arrive in an area:** is the system in the list, linked to the area, and is the area's tag the
  same as in the packet (the case does not matter)?  Look at `bad/bad.pkt`.
* **Nothing happens from `mktoss`:** the Tosser switch is off (exit 3); use `-f` to test.
