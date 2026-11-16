# The tosser (mktoss)

One program, `mktoss`, for echomail and netmail processing (decided 2026-11-16).  It uses what is already
there: the message-area objects (`MKOpen`, `MKMsgAbs` and the bases), `MKMsgPkt` for packets, `MKDupe`, and the
EchoMail settings of `mkconfig` (echo systems, echo areas, archivers).  mkbink stays ignorant of all this.

## What the configuration already says (EchoCfg.Mk, Config.Mk)

* `EchoSys[1..32]`: address, archiver (1 LZH 2 ZIP 3 ARC 4 ZOO 5 DWC 6 ARJ 7 HYP), networks (bitmap, for areafix),
  flavour (`esImm/esCrash/esNormal/esHold`), areafix password.
* `EchoArea[1..500]` (indexed by *message area number*): tag, `EchoTo` (bitmap of the systems that get the area),
  options keep/hide path, keep/hide seen-by, pass-through, hub (the system we get it from).
* inbound / outbound directories, maximum packet size, archiver command lines (`GetUnPackCmdLine`, `GetPackCmdLine`
  = the program and options; mktoss adds the archive name, working in the work directory).
* `Mailer.Mk` (our addition): `UnsecureIn` (inbound of callers without a password), `OnInbound` (command mkbink runs
  after a session that received files), `HookTimeout`.

## Decisions

* One program: toss, then (later) areafix, scan, pack.  Called by mkbink's `on-inbound` hook and by hand / cron.
* Outgoing packets and bundles reach the BSO outbound through `mkbink queue` (only mkbink knows the BSO layout).
* The unsecure inbound is not tossed (counted and logged only).
* Names of files that come from outside (`*.pkt`, bundles `*.mo?` ...) are matched on the extension without regard to
  case (the mailer stores them as the remote sent them); everything we make is lower case.

## Phases

1. **Toss (done)**: `src/MKToss.pas`.  Bundles (found by signature: ZIP, ARJ, LZH, ZOO, ARC) are unpacked with the
   configured unpacker, packets read with MKMsgPkt.  Only from systems in the echo systems list.  Echomail: area by
   tag (not case sensitive), the sending system must be linked to the area (`EchoTo`), duplicates (CRC of tag + MSGID,
   else tag + from + to + subject + date; `dupe.mk` in the inbound, 14 days), pass-through areas are not stored.
   Stored with MSGID / PID etc. as ^A kludges, SEEN-BY and PATH per the area's keep / hide options.  Netmail goes to the
   first netmail area (for us, or for another address: stored not-sent for the scanner).  What cannot be tossed goes to
   `bad.pkt`, a bad packet or bundle is renamed `.bad`, what was tossed is deleted.  Tests: `tests/tosstest.py`
   (packets made with MessagePacket.js, private copy of the sample BBS, Hudson areas).
2. **Forward, scan, pack (done)**: tossed echomail that other systems are linked to (`EchoTo`) and pass-through mail is
   written to per-system outgoing packets (PATH with our address, SEEN-BY with the linked systems); local messages
   (`IsEchoed`: new, not exported) in echo areas are scanned, tear / origin from the area, exported messages are marked
   (`SetEcho(False)` + `ReWriteHdr`); netmail not sent and not for us is exported (route to the destination or the hub).
   Packets go into bundles with the system's archiver (`GetPackCmdLine`) when over the packet size or archiver set, then
   `mkbink queue -O <bso> -t <addr> -F <flavour>`; mkbink is told with RESCAN.  Needs `IsHold` (done) for hold flavour.
   As built: `ForwardEcho` (tossed and pass-through echomail goes to the other linked systems, not back to the sender or to
   a system already in SEEN-BY; SEEN-BY gets us and the destinations, PATH gets us), `ScanEchoArea` (a message is to be
   exported when it is local, echoed (`SetEcho(True)`) and not sent; afterwards `SetSent(True)` + `SetEcho(False)` +
   `ReWriteHdr`; tear / origin come from the BBS; a MSGID of ours is made and registered as a duplicate),
   `ScanNetArea` (not sent, not for us: direct to the system, to the boss of a point, else by netmail routing (below);
   crash / hold as the message says, else the system's flavour, or the route's; a Via line when it only passes through), `PackAll` (the packets of the spool, `out/mktoss/s<system><flavour><aka>_<n>.pkt`, one per system,
   flavour and AKA of the area, a new one over the maximum packet size, packed with the system's archiver into
   `<hex of the address difference>.<day><n>`, or kept as a packet; then `mkbink queue -O <outbound> -Z <zone> -t <addr>
   -F <flavour> -x`).  Options: `-t` toss only, `-s` scan only, `-b mkbink`.  Tests: `tests/tosstest.py` (outbound checked
   with a built ../mkbink), `tests/scanflagstest.pas` (the flags the scanner reads in JAM, Squish, Merlin).
   Not done: a high-water mark (every run reads every message of every echo area), packet passwords, `.req`.
3. **Areafix and packet passwords (done)**: netmail to Areafix / AreaMgr (our address) with the system's password (`EchoSys.PWD`) as subject.
   Commands `%LIST %QUERY %UNLINKED %HELP +TAG -TAG` (see original/AREAFIX.TXT), changes `EchoTo` bits in EchoCfg.Mk,
   answer is a netmail back.  Which areas a system may see: `Networks` bitmap against the area's net status.  Requests
   to the hub for areas we do not have yet (the `Hub` field).
   As built: `ProcessAreafix` (called from `TossNetmail` for netmail to us with the name Areafix, AreaMgr or AreaManager,
   the request is consumed, the answer is `PostNetmail` into the netmail area: private, kill/sent, local, so `ScanNetArea`
   sends it in the same run).  Sender = the system of the netmail's origin (or the boss of a point); the subject must be the
   system's areafix password (`EchoSys.PWD`, now labelled "Areafix pwd" in mkconfig).  Commands `%LIST %QUERY %UNLINKED
   %HELP`, `+AREA`, `-AREA`, a bare `AREA` (links), `*` and `?` in names, processing stops at a `---` line.  An area is
   available to a system when it has a tag, does not come from that system (its Hub), and, if the area is restricted to
   networks (Message Areas > Networks), the system has one of them (Network Security).  `AfterChange`: for an area with a
   Hub, the hub is linked and sent `+TAG` when the first other system takes the area, and for a pass-through area
   unlinked and sent `-TAG` when the last one leaves (the request is a netmail to Areafix at the hub with the hub's
   password).  The changes are saved with `MKCfgObj.SaveEchoCfg` (echocfg.mk only).
   Packet passwords: `Mailer.Mk` `PktPwd[1..32]` (8 characters each, from the expansion room; mkconfig: EchoMail > Systems >
   a system > "Packet pwd").  A system that has one must send it in the packet header (else the packet is renamed .bad),
   our packets to it carry it.  Systems without one: no check.
   Tests: `tests/tosstest.py` (areafix requests from MessagePacket.js: right and wrong password, a sender that is not ours,
   a wrong packet password, links changed, the answers and the hub request read from the real outbound),
   `tests/mailertest.py` (the mkconfig page saves the packet password).
4. **Integration (done)**:
   * `Mailer > Tosser` (mkconfig, flag `mcTosser` = 128 in `Mailer.Mk`) switches the tosser on.  `mktoss` does nothing (exit 3,
     says so unless `-q`) while it is off, `-f` overrides; so cron, the mailer's hook and mklisten's scan can call it all the time.
   * `mkbinkcfg` writes `on-inbound <mktoss>` (the one next to mkbinkcfg) when the tosser is on and "After mail comes" is blank;
     a command set there wins.  mkbink runs it after every session that received files (its output, the summary line included,
     is in the mailer's log, so it shows in mkmon's mailer screen).  mktoss ignores the file names the hook passes and tosses
     the whole (secure) inbound.
   * mklisten starts mkbink with `MK=<the BBS configuration>` in its environment (the hook and mktoss need it) and, with
     `"scan": <seconds>` in the `"mailer"` section, runs `mktoss -s -q` that often while the mailer runs (the messages the BBS
     wrote are packed and queued; mkbink sees them at its next look at the outbound).  `"mktoss"` names the program.
   * One mktoss at a time: a lock on `mktoss.lock` in the inbound (the second waits).
   * Tests: `tests/tosshooktest.py` (a real mkbink calls the mkbink of the BBS, the hook tosses the packet into the area),
     `tests/mailerlistentest.py` (scan, MK in the environment), `tests/mailertest.py` (the switch, on-inbound), `tests/tosstest.py`
     (switch, file names, lock).
5. **Netmail routing and file attach (done)**:
   * `Mailer.Mk` `Routes[1..12]` (`RouteType`: patterns, via system, flavour; from the expansion room, 56 bytes left; mkconfig:
     EchoMail > Routing).  The first route whose patterns fit wins; patterns are blank separated `zone:net/node.point`, every
     part `*` or left out, `!` in front = not (`1:120/* !1:120/9`); a system in the echo systems list (or its point) is always
     sent to directly first.  No route: the message stays unsent and `mktoss` says so (there is no fallback to the first system
     any more).  A route's flavour (immediate, crash, normal, hold, direct) overrides the message's.
   * File attach: the subject names the files (blank / comma separated; `^` delete after sent, `#` truncate, else keep; no path =
     the file attach directory).  All files must be there (else the netmail waits, logged); they are queued with `mkbink queue
     [-x | -T]` (new `-T` in mkbink: `#file` in the flow file), the packet's subject is the plain names.  Incoming: the files the
     mailer received are moved from the inbound to the attach directory under the subject's name (case-insensitive match, a number
     is added when the name is taken); transit mail gets `^` in the stored subject so the file is removed after it was sent on.
   * Fixes made on the way: mktoss.ser (message ids and raw packet names never repeat, also between runs in the same second;
     the old names could collide); `{$I+}` in `Log` had switched I/O checking on for the rest of the program.
   * Tests: `tests/tosstest.py` (routes, no route, `!`; three attached files with their actions, a missing file, files that
     arrive, transit), `tests/mailertest.py` (the Routing page saves).
6. Later: file echoes (TIC), `%PAUSE`, `%RESCAN`, a high-water mark for the scan, `.req` file requests.

## Known fixes made on the way

* The tosser's own `bad.pkt` was in the inbound directory, so the next run tossed it again (and made the same bad mail
  again); it is `bad/bad.pkt` now.
* `SetEchoToMailType` or-ed the new flavour into the old one (`and 7`, should be `and Not 7`), so a system could never go
  from Hold to a lower flavour in mkconfig (and `Default.pas` makes every system Hold).  Fixed in `MKCfgMK`.
* `GetMsgAddr` read `Addr[0]` for an area without an AKA chosen; it uses the main address now.
* Hudson `IsEchoed` only knew the flag of a message being written; it reads the "unexported echomail" bit now and
  `SetEcho` changes the bit of a message that was read (so `ReWriteHdr` can clear it).
* `eaPassThru` was `$16` in the DOS source (`STRUCT.MK`), which also matched the hide-path and keep-seen-by bits, so an
  area with either of those read as pass-through.  It is `$10` now (a value written by the old code still reads as
  pass-through).
