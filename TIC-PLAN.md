# TIC file echoes: plan

Status (2026-11-22): **phase 1 (the configuration) is built**; the rest is plan.  Items marked *(verify)* need the text of the specification
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

## Phase 1 (done): what is in the configuration

* **`fileecho.mk`**: one record of 33024 bytes (`FileEchoCfgType` in `MKGlobT.pas`): version; `CheckCmd`, `CheckTimeout`, `SpoolPath`, `PassDays`, `PassMaxMB`, flags; 32 systems
  (`TicPwd`, `FixPwd`, `Groups`: the same numbers as the echo systems); 300 echoes (`Tag`, `Desc`, `FileArea`, `EchoTo`, `Hub`, `Groups`, `Attr`: `feReplaces`,
  `feNoCheck`, `feKeepPath`).  Groups are the letters A to Z (bit 0 = A): an echo with no group is open to every system, one with groups only to the systems that have one
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
2. `MKTic.pas` and its unit test.
3. Tossing without passing on (checks, the file into the area, `files.bbs`, `badtic/`, the dupe file), tests.
4. Passing on and pass-through (the outgoing TIC, the queue, `Path` / `Seenby`), tests.
5. `mkhatch`.
6. FileFix.
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
