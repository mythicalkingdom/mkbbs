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
   `ScanNetArea` (not sent, not for us: direct to the system, to the boss of a point, else through the first system;
   crash / hold as the message says, else the system's flavour; a Via line when it only passes through; file attach is
   not handled yet), `PackAll` (the packets of the spool, `out/mktoss/s<system><flavour><aka>_<n>.pkt`, one per system,
   flavour and AKA of the area, a new one over the maximum packet size, packed with the system's archiver into
   `<hex of the address difference>.<day><n>`, or kept as a packet; then `mkbink queue -O <outbound> -Z <zone> -t <addr>
   -F <flavour> -x`).  Options: `-t` toss only, `-s` scan only, `-b mkbink`.  Tests: `tests/tosstest.py` (outbound checked
   with a built ../mkbink), `tests/scanflagstest.pas` (the flags the scanner reads in JAM, Squish, Merlin).
   Not done: a high-water mark (every run reads every message of every echo area), packet passwords, `.req`.
3. **Areafix**: netmail to Areafix / AreaMgr (our address) with the system's password (`EchoSys.PWD`) as subject.
   Commands `%LIST %QUERY %UNLINKED %HELP +TAG -TAG` (see original/AREAFIX.TXT), changes `EchoTo` bits in EchoCfg.Mk,
   answer is a netmail back.  Which areas a system may see: `Networks` bitmap against the area's net status.  Requests
   to the hub for areas we do not have yet (the `Hub` field).
4. **Integration**: mkbinkcfg sets `on-inbound` to mktoss when the tosser is enabled; mkmon shows the last toss; a
   setting in mkconfig for the tosser; RESCAN after a scan.
5. Later: netmail routing, file echoes (TIC), `%PAUSE`, `%RESCAN`.

## Known fixes made on the way

* `SetEchoToMailType` or-ed the new flavour into the old one (`and 7`, should be `and Not 7`), so a system could never go
  from Hold to a lower flavour in mkconfig (and `Default.pas` makes every system Hold).  Fixed in `MKCfgMK`.
* `GetMsgAddr` read `Addr[0]` for an area without an AKA chosen; it uses the main address now.
* Hudson `IsEchoed` only knew the flag of a message being written; it reads the "unexported echomail" bit now and
  `SetEcho` changes the bit of a message that was read (so `ReWriteHdr` can clear it).
* `eaPassThru` was `$16` in the DOS source (`STRUCT.MK`), which also matched the hide-path and keep-seen-by bits, so an
  area with either of those read as pass-through.  It is `$10` now (a value written by the old code still reads as
  pass-through).
