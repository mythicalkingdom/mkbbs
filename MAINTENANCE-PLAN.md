# Housekeeping: plan (test fixture, message base maintenance, backup, statistics)

Status (2026-11-23): **1 (the test fixture) and 3 (backup) are built; 2 (`mkmaint`): the purge and the Hudson pack are built** (`MAINT.md`; JAM pack still to do); 4 (statistics) and the user and file housekeeping (`mkuserpurge`, `mkfilecheck`) are built; the statistics: the call record and `mkstats` (`STATS.md`); the `mkmon` screen (S) is built; the display codes for callers' screens are left.  Your answers to the questions: never purge unread private mail; Squish and `*.msg` bases get `DaysKept` / `RcvdDays` too; file areas only with a switch and backups in `<BBS dir>/backup/`; one `.bak` generation; statistics for the sysop only (later: display codes callers' screens can embed); backup first.

The four pieces, in the order they are done:

1. **The test fixture** *(done)*.
2. **Message base maintenance**: `mkmaint`, which applies what the areas already say (days and number of messages kept, days a read message is kept).
3. **Backup and restore**: `mkbackup`.
4. **Statistics**: calls, minutes, transfers, per day / month / node / port.

## 1. The test fixture (done)

* `tests/fixture.py make` (build.sh does it at its start) copies the parts of the sample BBS that tests use -- `bbs/bbsc/ra` (the configuration), the menus, the node list,
  the mkqwk configuration -- to `build/fixture/`, leaving out what belongs to the running system (`mkbink.conf`, and `events.mk` / `fileecho.mk`, which the tests start without).
  Every test copies from there (`cfgpatch.snapshot(path)`), never from the live directory, so a BBS that is in use (its mailer, a sysop saving something) cannot disturb a run.
* `fixture.py verify` ends a build: it says FAIL when the snapshot changed (a test wrote into it) or when the live sample's configuration files (`config.mk`, `messages.mk`,
  `files.mk`, `echocfg.mk`, `mailer.mk`, `events.mk`, `fileecho.mk`) are not what they were at the start.  Editing the live sample while a build runs is reported too (a build
  takes about 7 minutes).
* The mkconfig edit tests that were shell lines in `build.sh` are `tests/cfgedittest.py` now, on short private copies with their paths patched: a save cannot reach the sample.
* What this does **not** do: the paths inside `config.mk` still name the live sample, so a test that forgets to patch them still reaches it; the end of the build then says so.

## 2. Message base maintenance: `mkmaint`

What exists: each message area has `DaysKept`, `MsgsKept` and `RcvdDays` (mkconfig edits them, they are in `bbsconfig.json`), and Squish bases enforce a count when a message is
written.  Nothing purges Hudson, JAM, Synchronet or `*.msg` bases, and nothing packs them: deleted messages keep their room, the bases only grow.

Proposal:

```
mkmaint [-n] [-a <area>] [-p] [-v]     -n dry run (says what would go, changes nothing)  -a one area  -p pack too  -v each message
```

* **Purge** each area by its own settings: a message older than `DaysKept` goes, a read message older than `RcvdDays` goes, and the oldest go while there are more than `MsgsKept`.
  An area with 0 for a setting does not use it.  The purge goes through the common message object (`DeleteMsg`), so every format works the same way.
* **Safe by default**: a message that is not yet exported (echomail waiting to be scanned) or is a netmail that is not sent is never purged; private mail that is unread is kept;
  the Fido high-water mark and each user's last read pointer are left correct (a pointer behind the first message that is left moves up).  A dry run first, always.
* **Pack** (`-p`): Hudson (the real gain: `msgtxt.bbs`, `msghdr.bbs`, the indexes and `msginfo.bbs` rewritten without the deleted messages, in one pass with a backup of the old
  files until the new ones are in), then JAM; Squish packs itself, `*.msg` has nothing to pack.  Hudson is first because 104 of the 122 areas of the sample are Hudson.
* **Runs from an event** (an event with the command `mkmaint`) while the BBS is quiet; a lock keeps `mk`, `mktoss` and the others out of an area while it is packed.
* Report: a line per area (kept, purged, bytes returned), a total, the log.
* Phases: (a) purge with the dry run and the safety rules, tests on copies; (b) Hudson pack; (c) JAM pack; (d) event and docs.

## 3. Backup and restore: `mkbackup`

```
mkbackup [-c config] [-o directory] [-k N]     make a backup, keep the last N
mkbackup -l <file>                             list what a backup holds
mkbackup -r <file> [-n] [-f] [what]            restore (a dry run first; -f replaces files that are there)
```

* **What it holds**: the BBS configuration directory (every `.mk` file, `bbsconfig.json` made fresh from them, the user files, `mkbink.conf`, the maps and ledgers of the QWK
  networks, `taglines`, `*.lc`), the message bases and file lists of the areas named in the configuration, and optionally the file areas themselves (large: a switch).
  Not the logs, the spool, the temporary directories or the node files.
* **Consistent while the BBS runs**: it takes the same lock as `mkmaint` for each message base while it copies it; the configuration files are copied as they are (they are
  written whole).  A backup records what it copied and the sizes, so a restore can tell a damaged one.
* **Format**: one `tar.gz` per backup (`mkbbs-<id>-<date>.tar.gz` and a `.sha256`), readable with ordinary tools; a restore needs nothing but the archive.
* **Config history**: `mkconfig` and the tools that save the configuration keep the previous version of every `.mk` file they replace (`name.mk.bak`, one generation), so a wrong
  save can be undone by hand; this is the piece that would have saved the mailer settings.
* Restore is conservative: nothing is replaced without `-f`, a dry run lists what would change, and the restore refuses while `mklisten` runs for that BBS unless told to.
* Runs from an event; `-k` removes the older ones.
* Phases: (a) the `.bak` generation in the save routines; (b) the archive of configuration and users with list and verify; (c) the message bases with the lock; (d) restore; (e) events and docs.

## 4. Statistics

What exists: `mk.log` (lines such as `> 17-Nov 21:14:12 MKMK Mark May on-line at 38400 BPS`, `Offline Reason`), the system statistics record (`SysStats`), the `mklisten` log
(nodes, ports, addresses), the transfer lines of the file code.

Proposal: a **statistics file** the BBS writes itself (one line per call when it ends: start, end, node, port type, user, address, bytes up and down, files up and down, messages
posted and read, why it ended), so nothing has to be guessed from text logs; and a report tool.

```
mkstats [-d day | -m month | -y year] [-by node|port|user|hour|day] [-top N] [-csv]
```

* Reports: calls and minutes per day / month, per node and port type (telnet, raw, ws, ssh), busiest hours, top callers (calls, time, uploads, downloads), new users, failed log-ons
  (from the login guard), average call length.
* `mkmon` gets a statistics screen (today and this month).  Callers can see a short "system statistics" screen if the sysop wants (a display file made by `mkstats`).
* The file is plain text (tab separated, one file per month, `stats/YYYY-MM.tsv`), so other tools can read it; old months are kept.
* Phases: (a) the call record written by `mk` at the end of a call; (b) `mkstats` reports and CSV; (c) the `mkmon` screen; (d) the display file for callers; (e) docs.

## Questions

1. **Purge rules**: besides never touching unexported echomail and unsent netmail, should unread private mail ever be purged (after a long time)?  Proposal: never.
2. **Purge and Squish / `*.msg`**: they have their own counting (Squish enforces the count at write time); apply `DaysKept` / `RcvdDays` to them too through `DeleteMsg`?  Proposal: yes.
3. **Backup contents**: file areas included only with a switch (proposal), or never?  Where do backups go by default (`<BBS dir>/backup/`, or a path you name)?
4. **Config history**: one `.bak` generation per file (proposal), or a few (dated copies in a `history/` directory, the last 10)?
5. **Statistics for callers**: a statistics screen that callers see, or only for the sysop?  Which numbers are fine to show (calls, minutes, top uploaders)?
6. **Order**: 2 (mkmaint) before 3 (backup), so that backup can use the same lock?  Or backup first, since a purge is a good thing to have a backup before?  Proposal: **backup first**.

## Future ideas (not planned yet)

* **A setup wizard and a configuration checker** (asked for 2026-11-23): a first-run wizard (`mkconfig` or a `mksetup`) that makes a working BBS directory step by step -- paths, the sysop account, the
  language files and menus from `/usr/share/mkbbs`, a first message and file area, `mklisten.json` with the ports the sysop wants (plain, TLS, SSH), the systemd unit -- and a **checker**
  (`mkcheck`) that reads an existing configuration and reports what is wrong or missing before callers find it: paths that do not exist or that the listener user cannot write, language
  files, menus and screens named but not there, message bases that cannot be opened, areas with no `conf` line for a network, a mailer link without a password, ports that are already
  in use, a TLS certificate that is unreadable or about to expire, an expired or missing sysop password, a login guard that would block the sysop's own address.  The checker is the smaller piece
  and is useful alone (it can run from an event and from the package's `postinst`); the wizard can then use it for its last step.
  **Built (2026-11-24):** `mksetup` (`SETUP.md`, `SETUP-PLAN.md`) and a first `mkcheck` (`SETUP.md`: folders, language, menus item by item, the files a new caller needs, message bases opened, file area
  folders, user files in step, the sysop account, the listener with `mklisten -t`).  **Not yet in `mkcheck`:** network areas without a link, a mailer link without a password, ports already in use, a TLS
  certificate that cannot be read or is about to expire, the listener user's write access, the login guard against the sysop's own address, an event that runs a command that is not there.
* The JSON API is built (`API.md`).  Native packaging for other systems, Windows, ban lists remain (see the roadmap notes).
* **To do (added 2026-11-25, in the order of the list; none started):**
  1. **`DOOR32.SYS`**: the drop file that modern doors want (with the socket / handle of the caller's connection), next to `DOOR.SYS` and `DORINFO1.DEF` (`DOS-DOORS.md`, command 7).
  2. **IPv6** (`IPV6-PLAN.md`): built, with `mkbink` (the listener, the hub clients, the mailer and the nodelist lookup); full build still to run.
  3. **Upload handling** (built: `UPLOAD-PLAN.md`, `UPLOADS.md`): after an upload a test (`unzip -t`, an antivirus command), `FILE_ID.DIZ` as the description, reject or quarantine, a log line; settings per file area.
  4. **`/v1/metrics`** (built: `src/MKApiMetrics.pas`, scope `metrics`, `API.md`; `sd_notify` and the watchdog for `mklisten`: `src/MKSdNotify.pas`, `Type=notify`, `tests/sdnotifytest.py`) in the JSON API (Prometheus text: calls, nodes in use, failed log-ons, the mailer, events) and a systemd watchdog / `sd_notify` for `mklisten`.
  5. **Message base converter** (`mkmsgconv`, built: `MSGCONV-PLAN.md`): Hudson, JAM, Merlin, Squish and `*.msg` into one another (the DOS-era Hudson bases of the sample are the reason), numbers and dates kept, a dry run.
  6. **Door sandbox**: run command 7 programs (and `mkdosdoor`) in a restricted environment (for example `bubblewrap`: no network, a private `/tmp`, the node directory and the door directory only).
  7. **Optional multi-node chat** (built: `MCHAT-PLAN.md`, `CHAT.md`; off by default): a chat room across nodes and a message from the sysop to every node (`mkmon`), switched on per BBS.
* **To explore (added 2026-11-26; ideas only, nothing decided or started):**
  1. **`mkconnect`**: a QModem-like terminal / telnet program: a dialing directory, ANSI / CP437 and the other terminal types, the file-transfer protocols the BBS has (Zmodem, Ymodem, Xmodem), capture to a file, scripts.  It shares the session code that exists (`MKComClient`: TCP and Telnet in client mode, `MKProt`).  Questions: full-screen text interface (Free Vision, as `mkconfig` and `mkmon`) or plain terminal; which scripting language (the BASIC / Pascal interpreters?); is it only for callers or also the sysop's tool for hub scripts.
  2. **A `jsexec`-like way to run `mkbasic` and `mkpascal` programs on their own** (planned, not started: `MHOST-PLAN.md`: one host dispatcher, extensions in the BBS, hooks, `mk -x script` outside it), outside a caller's session: from an event, from a shell or from the listener, with access to the BBS (users, message bases, file areas, the node list, the chat room) the way Synchronet's `jsexec` and its JS object model give; this would also be the basis for BASIC / Pascal doors that keep running without a caller.  Questions: which of the BBS objects the interpreters get and with what permissions (the door sandbox applies), the run-time limits, how a script is started by `mklisten`'s events.
  3. **Packaging `mkdraw` and `mkcat` separately**: the ANSI / CP437 drawing program and the file viewer are useful to people who run no BBS.  Their own packages (a `.deb` with only the program, its documentation and its own settings; no `mkbbs` user, no systemd unit), possibly their own repository and release numbers.  Questions: what of `MKDraw` / `MKCat` depends on the BBS units (the configuration, the language files), and how the shared code is kept in step with this repository.
  Still open from before: ban lists, the remaining `mkcheck` checks, the API's writes (run an event, poll a link, disconnect a node), the `self:` calls of callers, logrotate and a JSON-lines log.
