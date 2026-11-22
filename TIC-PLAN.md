# TIC file echoes: plan

Status (2026-11-22): **phases 1 (the configuration), 2 (`MKTic.pas`), 3 (tossing), 4 (passing on), 5 (`mkhatch`) and 6 (FileFix) are built**; the rest is plan.  Items marked *(verify)* need the text of the specification
before any code is written (the same way the QWKE specification was read before `TOREADER.EXT` was done).

## Decided 2026-11-22

1. **File names** are kept as the TIC gives them (`File`), whatever their case; they are looked for without regard to case.
2. **Same name, different CRC** is processed as a new file: it is accepted, the file of that name in the area is replaced by it and its `files.bbs` line is
   changed (it is not refused and no `.001` copy is kept).  The same name *and* CRC is a duplicate.
3. **Pass-through echoes** (no file area of our own) are in the first version.
4. **FileFix** has its own names (`FileFix`, `FileMgr`) and its own password for each system; when that password is blank the Areafix password of
   the system is used (and the Areafix names are accepted too).
5. **A check command**: a setting of File Echo Options, run for each file before it is accepted (`%F` = the file, `%T` = the TIC); an exit status other than 0, or no
   answer in the time limit, refuses the file to `badtic/`.  An echo can switch it off (*No check command*).
6. **The pass-through spool is limited**: days a file waits for a system (`PassDays`, default 14) and the most it may hold (`PassMaxMB`, 0 = no limit, the oldest go first).
7. Any FTN network; the sysop's FSX systems are for testing.

## Phase 6 (done): FileFix

A netmail for us to `FileFix`, `FileMgr` or `FileManager` from an echo system is dealt with by the same code as Areafix (`ProcessAreafix` of `MKToss.pas`, now with a *Files* switch), on
the file echoes of `fileecho.mk`: `%LIST` (the echoes the system may have), `%QUERY` (linked: marked `*`), `%UNLINKED`, `%HELP`, `+TAG`, `-TAG`, a bare `TAG`, `*` and `?` in names, processing
stops at a `---` line.  **The password** in the subject is the FileFix password of the system (File Echo Systems), **or its Areafix password when that is blank**; a system that has a
FileFix password is not served with the Areafix one.  A file echo is available to a system when it has a tag, does not come from that system (it is its hub), and is open to everyone (no
groups) or shares a group with it.  The answer is a netmail from FileFix to the name that asked (`FileFix response`, or `FileFix: password error`); `fileecho.mk` is saved by itself
(`SaveFileEcho`); as with Areafix, the first downlink of an echo that has a hub links the hub and makes us ask it (`+TAG`, the subject is the hub's FileFix password), and the last
downlink of a pass-through echo (no file area) makes us tell the hub to stop (`-TAG`).  A request from a system that is not an echo system is stored for the sysop.  The names are the
only names: there is no setting for them (the Areafix names stay Areafix's).  Test: `tests/filefixtest.py` (packets made by the test itself; it patches the message base paths of the
sample so that the replies go into its own copy).

## Phase 5 (done): `mkhatch`

`mkhatch -a <TAG> [-d desc] [-l long line]... [-r replaces] [-m magic] [-x] [-b mkbink] [-q] file ...` (`src/MKHatch.pas`, the work is `TicHatch` in `MKTicToss.pas`, the same passing-on code
as the tosser's).  For each file: it is copied into the file area of the echo (moved with `-x`; the file keeps its date; one with that name that is there is replaced, the files `-r`
names go, a file that is already in the area is only listed again) with a line in `files.bbs`, and a TIC (`Created by mkhatch`, our address as `Origin`, the description lines, `Replaces`,
`Magic`, size, CRC, date) and the file go to each system of *Echo To* through the mailer.  A pass-through echo is not stored, only passed on (with `-x` the source is deleted
afterwards).  The default description is the name of the file.  It takes the lock of `mktoss` (`mktoss.lock` in the inbound) so that it does not run at the same time as the tosser.
Exit status 0 done, 1 wrong call or no configuration, 2 a file could not be hatched (the reason on stderr).  It can run from an event (`command`).  `mktoss` and `mkhatch` share
`MKBinkQ.pas` (`mkbink queue`, the flavour of a system).  Tests: `tests/tictosstest.py`.

## Phase 4 (done): passing on and pass-through

After a file is stored (or, for a pass-through echo, instead of storing it) `MKTicToss` passes it on to each system the echo goes to (*Echo To*), except the system it came from, the
ones in its `Seenby` lines or `Path`, and ourselves.  For each one: a directory of its own in the spool (`<outbound>/mktoss/tic/`, or *Pass-thru spool* of File Echo Options) named
`<system>-<seconds>-<number>`, a hard link to the file in it (a copy across disks), and a new TIC: `From` is our address, `To` the system, `Pw` its TIC password (blank when none),
`Created` `by mktoss`, `Path` the old lines and ours (`address seconds date UTC mktoss`), `Seenby` the old lines, ours and the systems that get it now; everything else (`Origin`, `Desc`,
`Ldesc`, `Crc`, `Replaces`, `Magic`, unknown lines) as it came.  Both go to the mailer with `mkbink queue` in the flavour of the system, **the file first, the TIC after it**, both
deleted after they were sent (so the area keeps its file).  A pass-through echo with no system left to pass it to is dropped (said so).  The spool is cleaned at every run: a
directory with nothing left in it goes, one older than *Pass-thru days* (14 by default) goes, and while the spool is over *Pass-thru MB* the oldest go first (the numbers count every
link as a file).  The `feKeepPath` switch of phase 1 was taken out: the old `Path` and `Seenby` lines are always kept.  The summary line of `mktoss` now says how many were passed on,
passed through and dropped.  Tests: `tests/tictosstest.py` (with the mkbink of the neighbouring project: the entries of the BSO outbound, the hard link, the TIC of system 2, the
`Seenby` rule, pass-through, nobody to pass to, the spool limits).

## Phase 3 (done): tossing a TIC

`src/MKTicToss.pas`, called by `mktoss` after the packets (and only with the tosser switched on, as the mail is).  For each `*.tic` of the **secure** inbound, in this order:
the TIC has File, Area, Size and Crc; its file is in the inbound (any case; when it has not come the TIC waits, and is bad after a day); `From` is an echo system and, when that
system has a TIC password, `Pw` is it (a system with none set is not asked: set one); `Area` is one of our file echoes and the system is its hub or the echo goes to it; our own
address is not in `Path`; the file has the size and CRC of the TIC; it is not a duplicate (`ticdupe.dat` in the inbound, 30 days: echo, name, CRC); the check command accepts it
(`timeout <seconds> sh -c "<command>"`, `%F` and `%T` quoted; any status but 0, or the time limit, refuses it; an echo can skip it).  What fails goes with its file to `badtic/` in
the inbound (a name that is there already gets the time added) and the log says why.  What passes: the file with that name that is in the area (another CRC) is replaced, the files
`Replaces` names go too when the echo allows it, the file is moved (copied and deleted across disks) under the name the TIC gives, gets the date of the TIC, and `files.bbs`
gets a line with the description and the `Ldesc` lines under it (the old lines of replaced files, and their long descriptions, are taken out; the file is written new and renamed).
A file area with no directory is bad; a directory that is not there makes the TIC wait.  **A pass-through echo is only passed on (phase 4).**
The summary line of `mktoss` ends with `; N tic tossed, N bad tic, N tic duplicate(s), N tic waiting` when there were TICs.  Test: `tests/tictosstest.py`.

## Phase 2 (done): `MKTic.pas`

* **The text of FSC-0087 could not be read** (ftsc.org did not answer; the copies found are of other documents), so the unit follows what the common tossers write and read.
  What is certain from other sources: `Crc` is 8 hexadecimal digits (CRC-32), `Replaces` is a file name (no path) of the echo, `Desc` is one line (at most 80 characters),
  `Ldesc` lines add to it, `Pw` is never passed on, and a forwarding system adds itself to both `Path` and `Seenby`.  **To be checked against real TICs** (the sysop's FSX
  systems): the `Path` line layout (written as `address seconds date UTC program`), the `Date` field (seconds since 1970; a text date is kept as it is), upper or lower case of
  the `Crc` digits (written upper case, read in any case), `Fullname`, and whether a TIC may carry `Seenby` lines in the `zone:net/node` form only.  Please send a `.tic` from FSX when
  one is there: it goes in `tests/` as a sample.
* **What it does:** `TicParse` (CR LF or LF, keywords in any case, a comment line, unknown keywords kept whole), `TicCheck` (File, Area, Size, Crc), `TicWrite`, `TicFileCrc` (CRC and size
  of a file), `TicCrcStr` / `TicHexCrc`, `TicDateStr` (UTC), `TicAddPath` / `TicAddSeen` / `TicInPath` / `TicInSeen` (no duplicates; the oldest `Path` line goes when there are too many),
  `TicSameAddr` (a `.0` point, case and `@domain` do not matter), `TicMatchName` (`*` and `?` for `Replaces`).
* **Test:** `tests/tictest.pas` (the CRC-32 check value `CBF43926` of "123456789", a leap day, the last second of a year, a TIC written by another tosser, the round trip).

## Phase 1 (done): what is in the configuration

* **`fileecho.mk`**: one record of 33024 bytes (`FileEchoCfgType` in `MKGlobT.pas`): version; `CheckCmd`, `CheckTimeout`, `SpoolPath`, `PassDays`, `PassMaxMB`, flags; 32 systems
  (`TicPwd`, `FixPwd`, `Groups`: the same numbers as the echo systems); 300 echoes (`Tag`, `Desc`, `FileArea`, `EchoTo`, `Hub`, `Groups`, `Attr`: `feReplaces`,
  `feNoCheck`).  Groups are the letters A to Z (bit 0 = A): an echo with no group is open to every system, one with groups only to the systems that have one
  of them.  A missing file means the defaults (no echoes, a 60 second check, 14 days).
* **Access:** `Config^.HasFileEcho`, `GetFileEcho`, `SetFileEcho` (`MKCfgAbs`, `MKCfgMK`), and `"fileecho"` in `bbsconfig.json` (`MKCfgJs`, `CfgJson.Inc` from `tools/genjsoncfg.py`,
  `mkcfgcvt`).
* **`mkconfig`**: EchoMail > File Echoes (the list, a form with *Echo To...* and *Groups...*), File Echo Options, File Echo Systems (the passwords are shown as stars).
* **Tests:** `tests/jsoncfgtest.py` and `tests/cvttest.py` (the file and the JSON round trip), `tests/fileechoedittest.py` (the pages and the record).


A *file echo* is the file counterpart of an echomail area: a file that is hatched in one system is passed from system to system, each one
keeping a copy in its file area.  A file travels with a small text file, the **TIC** (`*.tic`), that names the echo (`Area`), the file, its
size and CRC, a description, the systems it has been through (`Path`, `Seenby`) and a password.  The mailer only moves the files; what is
needed here is the part that reads the TIC, checks it, puts the file in a file area, and passes it on.

## What there is

* The mailer (`mkbink`) receives files into the inbound directory and runs the tosser (`mktoss`) after a session, so a `*.tic` and its file
  arrive where the mail packets do (secure inbound for a system with a password, the unsecure inbound for a stranger: not tossed).
* `mktoss` knows the echo systems (32 of them: address, archiver, flavour, areafix password, packet password, networks), has the Areafix
  engine (`+AREA`, `-AREA`, `%LIST` ...; answers by netmail), a duplicate check, `QueueFile` (a file for a system into the BSO outbound with
  flavour and a delete / truncate action) and finds an inbound file by name without regard to case (`FindInInbound`).
* The file areas (`files.mk`: 300 areas with a name, a short name, a path, security levels, attributes) are listed from a `files.bbs` in the
  area's directory (name, size, date, description with long description lines).  `mkfreq` and the new files list (also in offline packets) read
  those.  There is no upload code in MK: the file lists are kept by the sysop or by programs, so **the TIC tosser is the first thing that adds
  to `files.bbs` by itself**.
* `Crc32`, `MKFile` (copy, move, dates), the JSON configuration (`bbsconfig.json`, `mkcfgcvt`) and the `mkconfig` screens are all there to be
  used for the new records.

## What to build

### 1. The configuration of file echoes *(medium)*

* **A new record file**, `fileecho.mk` (like `echocfg.mk`; mirrored in the JSON file as `"fileecho"` and in `mkcfgcvt`, with the `MKCfgMK` /
  `MKCfgJs` parity the other records have): for each file echo (300, one for each file area)
  * `Tag` (40 characters, the echo name as the network knows it), the **file area** it goes to (1..300, or 0 = *pass-through*: no copy is
    kept for the BBS, the file is only passed on), a `Hub` (the system we get it from), `EchoTo` (a 32 bit mask of the echo systems that
    get it, as `EchoAreaType.EchoTo`), flags (*keep the TIC path*, *replaces allowed*, *pass-through*), and the groups it belongs to.
  * For each echo system, a **TIC password** (`Pw`, 8 characters as the standard has it) and a **FileFix password**; they go in the expansion
    room of `mailer.mk` as the packet passwords did (`PktPwd`), or in `fileecho.mk` itself *(proposal: `fileecho.mk`, so `mailer.mk` stays
    as it is)*.
* **`mkconfig` > EchoMail > File Echoes**: the list of echoes (tag, area, hub), a form for one (with *Echo To...* as the message area form has it),
  the passwords on the system form.  **`mkbinkcfg` does not change**: TIC is not the mailer's business.
* Tests: the JSON round trip (`jsoncfgtest`), the screens (`mailertest` style).

### 2. The TIC reader and writer: `MKTic.pas` *(small)*

* Parse a `.tic` (lines `Keyword value`, case of the keyword not significant, unknown keywords kept and passed on as they are), write one.
  Fields to cover *(verify against FSC-0087 and the common practice before coding)*: `Area`, `Areadesc`, `Origin`, `From`, `To`, `File`,
  `Fullname` (long name), `Replaces`, `Desc`, `Ldesc` (one or more), `Size`, `Date`, `Created`, `Crc`, `Magic`, `Path`, `Seenby`, `Pw`, `Release`.
* A unit test on made-up TIC files (every field, long lines, missing fields, DOS and Unix line ends, a file name with blanks).

### 3. Tossing a TIC: `mktoss` *(large)*

For each `*.tic` in the **secure** inbound, after the packets (so the order of mail and files in a session does not matter):

1. **Checks**, in this order, each one with its own words in the log and the TIC and its file going to `badtic/` in the inbound directory (not
   deleted: the sysop looks) *(proposal)*: the file named by the TIC is in the inbound (found without regard to case, `FindInInbound`; a TIC
   whose file has not come yet waits for the next run, for up to a day, then it is *bad*); the sender is a system of the echo systems list;
   the `Pw` is the system's TIC password; the `Area` is a file echo that this system is allowed to send (it is its hub, or one of the
   systems the echo is linked to); `Size` and `Crc` are those of the file; the file is not a duplicate (area + name + CRC kept in a
   `ticdupe.dat` for some days, like the message dupe file); we are not in the `Path` already (a loop).
2. **The file goes to the file area**: moved (not copied) from the inbound to the area's directory.  A `Replaces` name (wildcards `*` and `?`)
   removes the old file and its line in `files.bbs` first, only when the echo allows it.  A file with the name of one that is already there
   is a **duplicate name**, not a duplicate file: *(proposal)* it is stored under the same name with the old one renamed to `name.001`
   style, or refused to `badtic/`; the sysop chooses in the echo's flags.  The file gets the date of `Date` (or `Created`).
3. **`files.bbs`**: a line with the name and the description (`Desc`, the `Ldesc` lines as continuation lines in the layout the BBS already
   reads), added to the area's list; written under a lock, with a temporary file and a rename (the BBS reads it at any time).
4. **Passing it on**: for each system linked to the echo, except the sender and the ones in `Seenby`, a new TIC: our address added to `Path`
   (with the date), the echo systems that get it added to `Seenby`, `Pw` of that system, `Origin` and `From` kept as they were, `To` the
   system.  The TIC and the file are queued for the system with `mkbink queue` (`QueueFile`) in the flavour of the system (the file first and
   the TIC after it; the TIC is deleted after it was sent, the file stays in the area).  A **pass-through** echo keeps the file in a spool
   directory until every system it was queued for has it (one hard link for each, deleted after it was sent).
5. The TIC and its file leave the inbound; the log line says what happened (area, file, size, the systems it was passed to).

Order and failure: a TIC that cannot be finished (disk full, an outbound that cannot be written) stays in the inbound and the run says so, as
the mail packets do; `mktoss -f` / the tosser switch / the lock / `-q` work as they do now.

### 4. Hatching: `mkhatch` *(small)*

`mkhatch -a <TAG> [-d <description>] [-r <replaces>] <file>` makes the TIC for a file the sysop puts in a file echo: the file is copied
to the area (when there is one) with a `files.bbs` line, and a TIC and the file are queued for each system the echo goes to.  The same code as
passing on (step 4 above), with us as `Origin`.  It can be run by hand, from an event (`command`) or by another program (a door that takes
uploads, later).

### 5. FileFix *(medium)*

Netmail to `FileFix` / `FileMgr` / `FileScan` from an echo system with its FileFix password: `+TAG`, `-TAG`, `%LIST`, `%QUERY`,
`%UNLINKED`, `%HELP`, as the Areafix has them.  *(proposal)* share the Areafix engine: the names to recognise become a parameter
(`IsAreafixName` today), the link masks, the answers and the `AfterChange` (a hub that has to be asked) are the same with the file echo
records instead of the message ones.  Groups limit what a system may see and link to.

### 6. Integration

* **Files listed**: a file that is added shows in the BBS file list, the new files list of the offline packets (`newfiles.dat`) and `mkfreq`
  (the area's *Allow file requests* decides) without any change, since `files.bbs` and the file date are what they read.
* **`mkmon`**: the mailer screen could count the TICs tossed and the ones in `badtic/` *(later)*.
* **Events**: nothing new; `mktoss` runs after a session as it does now, and an event can run `mkhatch`.
* **Docs**: `TOSSER.md` (the item that now says "later: file echoes (TIC)"), `NETWORKING.md` (a section: how to join a file echo),
  `MKBBS.md`.
* **Tests** (`tests/tictest.py`, and one lane of `build.sh`): the TIC parser, a tossed file (the area, `files.bbs`, the date, the CRC), a
  wrong password, a wrong size / CRC, an echo the sender may not send, a duplicate, a loop in `Path`, a `Replaces` with a wildcard, passing
  on (the TIC for each system: `Path`, `Seenby`, `Pw`; the sender and the `Seenby` systems left out), pass-through, `badtic/`, `mkhatch`,
  FileFix (add, remove, list, a wrong password), a round trip between two MK systems (like `freqroundtrip.py`).

## Phases

1. Configuration: `fileecho.mk`, JSON, `mkcfgcvt`, `mkconfig` screens, tests.  **Done.**
2. `MKTic.pas` and its unit test.  **Done.**
3. Tossing without passing on (checks, the file into the area, `files.bbs`, `badtic/`, the dupe file), tests.  **Done.**
4. Passing on and pass-through (the outgoing TIC, the queue, `Path` / `Seenby`), tests.  **Done.**
5. `mkhatch`.  **Done.**
6. FileFix.  **Done.**
7. Docs, the round trip test, the full build.

## Questions for the sysop

1. **File names on disk:** keep the name the TIC gives (`File`), or make it lower case?  *(proposal: as the TIC gives it: DOS style names come in upper case and the
   list matches them in upper case today; a "lower case" flag for the echo later.)*
2. **A file with the name of one that is there** (not a duplicate by CRC): replace, keep both (`.001`), or refuse to `badtic/`?
3. **Pass-through echoes** (no area of our own): wanted from the first version, or later?
4. **A separate FileFix** (own names, own passwords) or the same netmail address and password as the Areafix?  *(proposal: own names, own password
   field, same engine)*
5. **A check command** (a virus scanner, a size or type filter) that is run on each file before it is accepted: wanted, as a setting of the echo?
6. **Old files:** should a file echo have a limit (days or files kept, as message areas have) so that the area does not grow for ever?
7. **Which networks** will it be used on first (FidoNet file echoes, fsxNet, others)?  Their rules for passwords, `Path` and `Seenby` decide the
   details of step 3.

## Sources to read before phase 2

* FSC-0087 (the TIC format) and the practice of the common tossers (Fidogate / hpt / FileFix on Synchronet, Mystic's `mutil`, Allfix, FastEcho's
  `FEF` for the file echo names): fields, the order of lines, `Path` and `Seenby` line formats, how `Replaces` is written, `Magic`.
* The Synchronet source for the TIC (`sbbsecho` writes and reads them) as a second reading of the same format.
