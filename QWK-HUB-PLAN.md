# QWK hub profiles: plan

Status (2026-11-23): **phases 1, 2, 3 and 4 are built** (3 as `-K` talk and `-F<transcript>` replay: `-T` and `-S` were taken) (4 as `-I` / `-J` / `-W`: `-L` and `-M` were taken, and the report reads the packet that is there instead of calling the hub) (profiles as files, `mk -G -P`, the `exec` transport; see NETWORKING.md; tests/hubexectest.py, build/hubexectest).  Phases 5, 6 and 7 are not.  Items marked *(verify)* need a transcript or the documentation of a real hub before any code is written;
items marked *(proposal)* are for the sysop to decide.

A *hub* is the system a QWK node calls to take its packet (`<id>.QWK`) and leave its reply packet (`<id>.REP`).  `mk -G<id>` does the exchange with the hub
(`NETWORKING.md`, section B).  How the files get to and from the hub is the part that differs from hub to hub, and it is what a **profile** is.

## Where we are

* `mk -G<id>` makes the reply packet, posts the packet of the hub, keeps the pointers and the duplicate ledger, handles refusals (`reply-error`, `reply-ok`),
  retries and failure (`mklisten` events: `retries`, `retry`, `onfail`), a dry run (`-D`), control messages (`-X`, `<id>.ctl`).  None of that depends on the hub.
* **One way to call a hub:** Telnet, then a script (`MKHubScr.pas`: expect, send, upload, download, variables, `when` rules) that logs in and runs the QWK menu of the
  hub's BBS software, with Zmodem / Ymodem / Xmodem moved by the built-in protocols.  The map file says `hub host:port`, `profile name` (or `script file`),
  `login`, `password`, `protocol`.
* **Two profiles**, built into the program (`HubProfile` in `MKHubScr.pas`): `synchronet` (checked against Synchronet 3.19: the `QWK:` menu, `D`, `U`, the
  "Hang up after transfer?" question; its refusal text is `Invalid Conference <n>`) and `mk` (another MK system, `mk -Q`).
* **Or no call at all:** without `hub` the files are moved by something else (a script, `mkbink`, cron) through the `inbound` and `outbound` directories.

What is missing: any hub that is not a Synchronet or an MK; a transport that is not a Telnet menu session; a way to write a new profile without guessing; and help
with the conference numbers (the `conf` lines are written by hand from `CONTROL.DAT`).

## What to build

### 1. Profiles as files *(small)*

* A profile is a script file `<name>.scr` found in, in this order: the directory of the map file, the `hubs` directory of the BBS directory, the system directory
  (`/usr/share/mkbbs/hubs`, installed by `make install`).  The two built-in ones are shipped as files there and kept in the program as the fallback, so nothing
  that works now stops working.
* A header of comments names the software and the version it was checked with, what the hub says on a refusal, and the `reply-error` / `reply-ok` that
  go with it (`# reply-error: invalid conference`): the map file may leave them out and take the ones of the profile.
* `mk -G -P` lists the profiles it finds with their headers.  A profile in the map file that is not found says where it looked.
* The point: a new hub is a new text file (one that a sysop can write, test and share) and not a new build of the program.

### 2. The `exec` transport *(medium; the most useful one)*

For hubs that are not reached by a Telnet menu: FTP, SFTP, HTTP(S), `rsync` ... without MK carrying a client for each.

```
transport  exec
get        /usr/local/bin/qwk-get.sh       # fetch the packet for the id: writes %inbound%/<id>.QWK, exits 0, or 3 when there is nothing new
put        /usr/local/bin/qwk-put.sh       # send %rep% (the reply packet); exits 0 when the hub took it
```

* The commands are run **without a shell**, with the words of the line as the arguments; `%id%`, `%qwk%` (the full name of the packet to make), `%rep%`,
  `%host%`, `%login%` are replaced.  The **password is not on the command line** (it would be in `ps`): it is in the environment as `MK_HUB_PASSWORD`, with
  `MK_HUB_LOGIN`, `MK_HUB_HOST`, `MK_HUB_ID`.
* Exit status: 0 done, `nothing` (a setting, default 3) = nothing new for us (not an error), anything else = failed (exit 5 of `mk -G`, so the events retry it).
  A time limit (`exec-timeout`, default 600 s) kills a command that hangs.
* The output of the commands goes into the transcript of the hub (`<id>.hub.log`) with the password left out; `reply-error` / `reply-ok` look at the output of `put`
  as they look at what a Telnet hub says.
* Recipes in the docs: Synchronet over FTP (`curl` / `lftp`), a hub with HTTP download, SFTP with `sftp -b`.  Tests: fake commands (scripts) that write a
  packet, take a reply, fail, hang, say "nothing new".

### 3. Writing a profile: a talk mode and a replay *(medium)*

* `mk -G<id> -T`: calls the hub and hands the keyboard to the sysop (a plain Telnet session with the telnet negotiation done), writing a transcript of both
  directions in the format `MKHubScr` already reads; Zmodem is detected, so a transfer can be tried by hand.  This gives the transcript that a new profile is written from.
* `mk -G<id> -S`: runs the profile against a transcript file as a fake hub (replay: the hub's lines come back when the script sends what was sent in the
  recording) so that a profile can be tested without calling anybody and a transcript that was sent in by someone else becomes a test.
* The existing fake hub of the tests (`tests/hubpasstest.py`) is moved to this replay, so each profile has a recorded transcript as its test.

### 4. Conference numbers *(small)*

* `mk -G<id> -L`: calls the hub (or reads the `<id>.QWK` that is there), lists the conferences of its `CONTROL.DAT` with number and name, and marks the ones that
  have a `conf` line.
* `mk -G<id> -M`: suggests `conf` lines by matching the names of the hub's conferences to the names and short names of our message areas (a proposal in the
  map file's syntax on the screen, not written unless `-W`).

### 5. Native FTP (and FTPS / SFTP) *(decide after the TLS and SSH study)*

The exec transport covers these first.  A built-in client is worth it when the sysop does not want `curl` or `lftp` around, or wants no password in the environment of
a child.  It needs sockets (there), passive mode, a data connection, and for FTPS a TLS library: it is one of the questions of the TLS / SSH exploration that
follows this plan, so it waits for that.  SFTP needs an SSH library and is the same question.

### 6. More Telnet profiles *(each needs a transcript: verify)*

Candidates, in the order the sysop's networks need them: Mystic, Renegade, Wildcat, WWIV, Maximus, Synchronet over rlogin or with its other menu.  For each: the
login prompts, the QWK menu keys, the protocol question, the "hang up after" question, what a refusal looks like, what "no new messages" looks like.  None can be
written from memory: the transcripts come from the sysop (mode `-T`).

### 7. Details that differ between hubs *(small, as they show)*

* The name the control messages go to (`SBBS` and `MK` today; other software has its own): a map file line `control-to`.
* Conference numbers above 255 and the QWKE long names: a hub that does not take them (`qwke no`, `conf-max`).
* The packet name (`<id>.QWK` or another), and a hub that wants the reply packet under another name.
* A hub that makes the packet in the background (the packet is there on the next call): "nothing yet" is not a failure.

### 8. Docs and tests

`NETWORKING.md` (section B: the transports, the profiles, the `exec` recipes), `HUBS.md` (what has been checked, with what software and version, and what is only
reported), the header of each profile.  Tests: the replay of each recorded transcript, the exec transport with fake commands, `-L` / `-M` on a packet, the
search order of the profiles.

## Phases

1. Profiles as files, the search path, `-P`, the built-in two as files (and the header settings).
2. The `exec` transport, its tests, the recipes (FTP with `curl` and `lftp`).
3. `-T` (talk) and `-S` (replay); the fake hub of `hubpasstest` on the replay.
4. `-L` and `-M`.
5. More Telnet profiles, one at a time, from transcripts.
6. Native FTP / FTPS / SFTP, if the exploration of TLS and SSH says it is worth it.
7. Docs, `HUBS.md`.

## Questions for the sysop

1. **Which hubs and networks matter?**  Your own Synchronet hub is the only one that is known to work.  Are there others you call (or want to), and what are they run
   on?  This decides what is written first.
2. **Which ways in?**  Telnet menu, FTP, something else (HTTPS, SFTP, e-mail)?  For a hub that offers FTP: is `curl` / `lftp` acceptable as a helper (the `exec`
   transport), or should the program do it itself?
3. **Secrets:** a password in the environment of a helper (`MK_HUB_PASSWORD`) is better than on the command line and worse than in the program: acceptable?
4. **Recording a session:** for a hub that does not have a profile, are you willing to make a transcript with `-T` (and send me the text, with the password
   left out)?  The profiles for other software cannot be made without them.
5. **Order:** the proposal is files first (1), then `exec` (2), then the tools to write profiles (3 and 4).  Native FTP waits for the TLS / SSH study.
