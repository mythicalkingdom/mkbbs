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
   profile   synchronet               # a profile file NAME.scr or one built in (synchronet, mk; mk -G -P lists);  or  script  MYHUB.scr
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
   **Control commands for the hub (subscribe, drop, set pointers).**  The node side of the control messages above: what you want the hub
to do goes up in the next reply packet.  Queue a command with `mk -G<id> -X"ADD 4029 -50"` (up to 10 `-X`; they are queued and sent by that
pass), or write one command a line in `<id>.ctl` next to the map file (`;` or `#` starts a comment):

```
ADD 4029 -50         subscribe to conference 4029 and send the last 50 messages (or a message number, or mm/dd/yy)
DROP 1003            unsubscribe
RESET 4029 -100      set the pointer of one conference         RESETALL -20   ... of all of them
CTRL-A STRIP         the hub takes the colour codes out         CONTROL ON, TZ ON, VIA ON, MSGID ON, NDX ON, OWN ON, MAIL ALL ...
```

The commands that are about one conference give its number as the hub numbers it, first.  They are sent as messages **to `SBBS`** (the name
Synchronet and MK both answer to; `control-to NAME` in the map file changes it) with the command as the subject, in the conference the command is
about; the commands that are about no conference go in the first conference of the map file.  A reply packet is made even when no message is new.
The commands are taken out of the file when the hub has the packet; a refused packet (exit 7) keeps them with it.  A command that is not valid is
not sent, said so, and the pass ends with exit code 8 (the others went).  `mk -G<id> -D` lists what would be sent.  Tested against an MK hub; the format is the
one of Synchronet's QWK remote commands, but a real Synchronet hub has not been tried.

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

**Profiles are files.**  `profile NAME` is the file `NAME.scr` (a script like the one above) found in this order: next to the map file, the `hubs`
directory of the BBS, `/usr/local/share/mkbbs/hubs`, `/usr/share/mkbbs/hubs` (`make install` puts `synchronet.scr` and `mk.scr` in the first of
the system ones); the two profiles built into the program are the fallback when no file has the name.  So a new hub is a text file that you can write,
test and share, with no new build.  `mk -G -P` lists the profiles that are found with the software and version each was checked with, and
`mk -G -P<name>` shows one (`mk -G -Psynchronet > mysynch.scr` makes a copy to start from).  The comment lines at the top of a profile may say

```
# software: Synchronet (the QWK: menu of a user)
# checked: Synchronet 3.19 (login, D, U, the hang up prompt)
# reply-error: invalid conference
# reply-ok: ...
```

`reply-error` and `reply-ok` there are used when the map file has none of its own (the map file's lines win).  A profile that is not found is
exit 6 and the message says where it looked.

### A hub reached by programs: `transport exec`

For a hub that is not a Telnet menu (FTP, SFTP, HTTP, rsync ...) the map file names two programs, and MK moves the files with them:

```
hub        ftp.example.com:21               # the name the programs get (MK_HUB_HOST); no call is made
transport  exec
login      lion
password   secret
get        /usr/local/bin/qwk-get.sh %id% %qwk%     # fetch the packet: write it as %qwk%
put        /usr/local/bin/qwk-put.sh %id% %rep%     # send the reply packet %rep%
nothing    3                                        # exit status of get: nothing new (default 3; not an error)
exec-timeout 600                                    # seconds before a program is stopped (default 600)
```

* The programs are run **without a shell**, with the words of the line as their arguments; a word can be in "quotes".  `%id%`, `%qwk%` (the full name
  where `get` writes the packet), `%rep%` (the reply packet, named `<id>.REP`), `%login%`, `%host%` and `%port%` are replaced.  A program name
  with no `/` is looked for in `PATH`, one with a relative path is relative to the directory of the map file (which is the working directory).
* **The password is not on the command line** (`ps` shows it): it is in the environment as `MK_HUB_PASSWORD`, with `MK_HUB_LOGIN`, `MK_HUB_HOST`,
  `MK_HUB_PORT`, `MK_HUB_ID`, `MK_HUB_QWK` and `MK_HUB_REP`.
* **Exit status:** `get`: 0 done (a packet at `%qwk%`; none: "nothing new"), the `nothing` status = nothing new, anything else = failed.  `put`: 0 =
  the hub took the reply packet (it is deleted), anything else = failed and the packet stays for the next pass.  A program that does not end in
  `exec-timeout` seconds is killed with what it started.  A failure is exit 5 of `mk -G`, so the `retries` of the events (EVENTS-PLAN.md) apply.
* What the programs print (output and errors) is written to the transcript (`<id>.hub.log`, the password replaced by stars) and what `put` prints is
  what `reply-error` / `reply-ok` look at, as for a Telnet hub.  With only `get` or only `put` the other half is left to somebody else.
* `mk -G<id> -D` says what the programs are and runs neither.

Recipes (the programs are yours; these are the shape):

```sh
#!/bin/sh   # qwk-get.sh <id> <packet>: FTP with curl; the hub keeps the packet until it is deleted there
curl -sS --fail -u "$MK_HUB_LOGIN:$MK_HUB_PASSWORD" -o "$2" "ftp://$MK_HUB_HOST/qwk/$1.qwk" || exit 3      # 3: not there = nothing new
curl -sS -u "$MK_HUB_LOGIN:$MK_HUB_PASSWORD" -Q "-DELE qwk/$1.qwk" "ftp://$MK_HUB_HOST/" -o /dev/null
```

```sh
#!/bin/sh   # qwk-put.sh <id> <reply packet>
curl -sS --fail -u "$MK_HUB_LOGIN:$MK_HUB_PASSWORD" -T "$2" "ftp://$MK_HUB_HOST/qwk/" && echo "reply packet sent"
```

For SFTP use `sftp -b` with a key (no password in the environment), for HTTP `curl -F`.

### A hub reached by FTP: `transport ftp` and `ftps`

When the hub offers its packets by FTP, MK has a client of its own (no `curl` needed): log in, fetch one file, send one file, optionally delete one.

```
hub        ftp.example.com:21          # the port is 21 when it is left out
transport  ftp                         # ftp, or ftps = explicit TLS (AUTH TLS, PROT P)
login      lion
password   secret
get        qwk/%id%.qwk                # the remote name of the packet (default %id%.qwk)
put        qwk/%id%.rep                # the remote name of the reply packet (default %id%.rep)
ftp-delete yes                         # delete the packet at the hub after it was fetched (default no)
ftp-timeout 60                         # seconds without a byte before it is given up (default 60)
tls-ca     /etc/mkbbs/hub-ca.pem       # ftps: the CA (or the certificate itself) that is trusted; default: the CAs of the system
tls-verify yes                         # ftps: no turns the checking of the certificate off (default yes)
```

* Passive mode only (EPSV, then PASV), binary, IPv4.  `get` / `put` are the remote **names** here (with `%id%`); with `transport exec` they are programs.
* A packet that is not at the hub (550) is "nothing new", not an error.  A hub that keeps the packet until somebody deletes it needs `ftp-delete yes` (or a hub that
  makes a new one each time), or the same packet is fetched again by each pass.  The messages that came before are not posted twice (the duplicate ledger), but it is
  wasted time.
* **FTPS** uses the OpenSSL libraries of the system (`libssl.so.3` or `.1.1`, loaded when it is wanted: without them only plain FTP works).  The certificate must be
  valid (the CAs of the system, or `tls-ca`) **and be for the name in the `hub` line** (so use a name, not an address, or `tls-verify no`).  The data connection reuses the
  TLS session of the control connection.  Nothing is sent without TLS: a server that does not do AUTH TLS is a failure.  Implicit FTPS (port 990) is not supported.
* Exit codes and what is written to the transcript are as for `exec`: 5 the FTP failed, 7 the hub did not accept the reply packet (`reply-error` / `reply-ok` look at the
  last reply of the server, for example `226 Transfer complete`); the transcript (`<id>.hub.log`) has the FTP dialogue with the password as stars.
* SFTP (SSH) is not built in: use `transport exec` with `sftp -b` and a key.

### Writing a profile: `-K` (talk) and `-F` (replay)

* `mk -G<id> -K` calls the hub of the map file (`hub host:port`) and gives you its keyboard and screen: you log in and go through the menus by hand.  What the hub
  says (cleaned of colour codes) and what you type are written to the transcript (`<id>.hub.log`, or `transcript` in the map file) in the format that `MKHubScr` reads:
  `<< ` lines are the hub, `>> ` lines are what was sent (up to the Enter key, or the key the hub answered), `-- ` lines are steps.  The password of the map file is
  written as stars even when you type it.  **Ctrl-]** ends the call, **Ctrl-U** asks for a file name and sends it (Zmodem or the `protocol` of the map file), and when the
  hub starts a Zmodem send it is received (into `<id>.talk/`).  When the input is a pipe, its end ends the call.  This is the transcript that a profile is written from.
* `mk -G<id> -F<transcript>` runs the script of the map file (`profile` or `script`) against a recording, no call: it gives the script what the hub said, in order, and
  waits for the script to send what was sent in the recording (the stars match any password).  Exit 0 and "the same way" when the script did the whole recording;
  exit 6 and what differed (what the script sent, or waited for, or "the recording goes on") when not; the replay is written in `<id>.replay.log`.  A transcript that
  somebody sent in is a test for a profile this way, and a profile that was changed can be checked against all the recordings it has to keep working with.

### Conference numbers: `-I`, `-J`, `-W`

The `conf` lines are the numbers of the hub's conferences, which are in `CONTROL.DAT` of its packet.  Two reports read the packet that is in the inbound directory (or
the one the last pass kept as `<id>.qwk.old`); they **do not call the hub** (asking for a packet makes the hub move its pointers) and change nothing:

* `mk -G<id> -I` lists the conferences of the packet with number and name, says which message area each one is here (or that it has no `conf` line), and names
  `conf` lines that the packet does not have.
* `mk -G<id> -J` suggests `conf` lines for the conferences that have none, by comparing the hub's names with the names and short names of the message areas that have
  no `conf` line yet (letters and digits only, case does not matter): an exact match is a `conf` line, a name that contains the other is a line with `;` in front
  to look at first.  `-J -W` adds them to the map file (appended, the existing lines are not touched).

(`-L` and `-M` already mean local mode and the mail-type switch of `mk`, hence `-I` and `-J`.)

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
2. **Areas.**  `Messages > Areas`: create a message area for each echo you carry and a *netmail* area (the **Type**).  Give an echo area its
   **Area** tag, its origin and the **Address** (AKA) it uses.
3. **Echo systems.**  `EchoMail > Systems`: add each system you exchange mail with.  For each system set:
   * its address;
   * the **archiver** it takes (ZIP is the usual choice);
   * the **flavour** (immediate, crash, normal, hold);
   * the **areafix password** and, if you agreed one, the **packet password**;
   * the networks it may see (for areafix).
4. **Link systems to areas.**  In the same area form: **Echo To...** chooses the systems that get the echo, **Hub** is the system you get it
   from, and **Fido Options...** has pass-through and keep or hide path and seen-by.
5. **Archivers and paths.**  `General > Packers` has the pack and unpack command lines; `EchoMail > Options` has
   the inbound, outbound and the maximum packet size.  `General > Bbs Paths` has the file attach
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

**Strangers.**  `accept-unknown yes` (`mkconfig`: EchoMail > Mailer > Accept unknown) lets a system that is not in the links list call; give it
no password for an anonymous (unsecure) session, and turn on **Without a password** on `EchoMail > File Requests` so that it can ask for files, as the anonymous
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
offer *multiple batches* (the default; `EchoMail > Mailer > Multi batch` in `mkconfig`, `multi-batch` in the mailer's settings), the request is answered at the end of the batch that
brought it and the files go in the next batch of the same session.  Otherwise, or when you called the requester, they are sent when
the requester calls to pick them up; your mailer does not call it for them.  The netmail of "Tell by netmail" is hold mail and is
picked up the same way.

### Things that end up in `bad/bad.pkt`

Mail from a system that is not in your list, an echo whose tag you do not carry, a system that is not linked to that
echo, or a damaged packet.  The inbound directory has a `bad` folder for them; a damaged bundle is renamed `.bad`.
Mail in the *unsecure* inbound (callers without a password) is never tossed.

### File echoes (TIC)

A *file echo* is the file counterpart of an echo: a file hatched in one system is passed from system to system, each keeps a copy in its file area.  The file travels
with a small text file, the **TIC** (`name.tic`), that names the echo, the file, its size and CRC, a description, the systems it has been through and a password.  The mailer only
moves the two files into the inbound; `mktoss` (after every session, and from `mklisten`'s scan) does the rest.  Set it up with the pieces of Fido networking above (echo systems,
the mailer, the tosser switched on) and:

1. **A file area** for the echo (`Files > Areas`): a directory and a name.  The BBS lists it from `files.bbs` in that directory, which the tosser keeps.
2. **The echo systems' passwords.**  `EchoMail > File Echo Systems`: for each system the **TIC password** it sends in its TICs (it is checked; a system with none set is not asked for
   one, so set one), its **FileFix password** (blank = its Areafix password) and its **groups** (letters A to Z).
3. **The file echoes.**  `EchoMail > File Echoes`: the **tag** the network knows the echo by (not case sensitive), what it is, the **file area** (0 = *pass-through*: no copy is kept, the files
   are only passed on), the **hub** (the system you get it from, 1 to 32 as in Echo Systems), **Echo To...** (the systems that get the files) and **Groups...** (an echo with no group is open to
   every system, one with groups only to the systems that share a letter).  *Replaces allowed* lets a TIC name files it replaces (they are deleted); *No check command* skips the check.
4. **Options.**  `EchoMail > File Echo Options`: a **check command** run for each file before it is accepted (`%F` = the file, `%T` = the TIC; any exit status but 0, or no answer in the
   time limit, refuses the file: use a virus scanner or a file type filter), and the **pass-through spool**: where files wait for the systems that fetch them, for how many days
   (14 by default) and the most it may hold in MB (the oldest go first).

What happens to a file that comes in: its TIC is read and checked (the file is there, the sender is an echo system and its password is right, the echo is one of yours and the sender may send it,
the size and CRC are those of the file, you are not in its `Path` already, it was not tossed before, the check command accepts it).  What is wrong goes with its file to `badtic/` in the inbound,
and the log says why (`mktoss` writes it; mkmon's mailer screen shows the hook's output).  What is right is moved into the file area **under the name the TIC gives, in the case it gives**; a file of
that name that is there is replaced (another CRC makes it a new file), the files `Replaces` names go too when the echo allows it, the file gets the date of the TIC, and `files.bbs` gets a line and
the long description.  Then it is passed on: to each system the echo goes to, except the one it came from and the ones in its `Seenby` lines, a new TIC (your address, that system's password, your
line in `Path`, the systems that have it in `Seenby`) and the file go to the mailer, the file first.  They wait in the spool (a hard link: no second copy on the disk) and are deleted after they were sent.
A TIC whose file has not come waits up to a day.  TICs in the *unsecure* inbound are never tossed.

**Hatching** a file of your own: `mkhatch -a TAG [-d "description"] [-l "long line"]... [-r "OLD*.ZIP"] [-m magic] [-x] file ...` stores it in the file area of the echo (moved with `-x`), lists it, and
sends it and a TIC to every system the echo goes to.  It can run from an event.

**FileFix**: a netmail to `FileFix` (or `FileMgr`) from an echo system, its FileFix (or Areafix) password as the subject, one command to a line: `%LIST` the echoes it may have, `%QUERY` the ones it
has, `%UNLINKED`, `%HELP`, `+TAG` link, `-TAG` unlink, a bare `TAG` links, `*` and `?` in names.  The answer comes by netmail.  An echo that has a hub is asked for from the hub when its first
system takes it (and a pass-through echo is given up when the last leaves).  A request from a system that is not an echo system is kept for you.

Tests: `tests/tictest.pas`, `tictosstest.py`, `filefixtest.py`, `ticroundtrip.py` (a hub, the BBS and a second system, with the real mkbink).  Details and the design: `TIC-PLAN.md`.

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
