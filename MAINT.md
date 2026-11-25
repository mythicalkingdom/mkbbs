# Message base maintenance: `mkmaint`

The message areas have limits that `mkconfig` stores (Messages: **Days kept**, **Messages kept**, **Received days**).  Nothing applied them: the bases only grew.  `mkmaint` applies them.

```
mkmaint [-c config dir] [-n] [-p] [-x] [-a area] [-v] [-q]
   -c   the configuration directory, instead of MK in the environment
   -n   a dry run: says what would be purged, changes nothing
   -p   pack the Hudson and JAM bases afterwards (see Packing)
   -x   with -p: remove the .prepack copies at the end
   -a   only this area (its number)
   -v   each message that goes, and why
   -q   only the areas where something goes, and the total
```

`MK` names the configuration directory, as for `mk`.  It prints a line for each area that has a limit:

```
area 183 T Pascal: 70 message(s), would purge 70 (70 by age, 0 read, 0 over the limit)
area 6 FIDO-MK: 12 message(s), purged 3 (2 by age, 1 read, 0 over the limit), 2 kept for sending or unread
```

**The rules**, for each area that has at least one limit (0 = not used):

* a message **older than Days kept** goes;
* a message that has been **read** and is older than **Received days** goes;
* when the area holds **more than Messages kept**, the oldest of what is left go (by message number, the order they came in) until it fits.

**What never goes**, whatever its age or the limits (the line says how many were kept for this):

* **unread private mail** (a private message that its addressee has not read);
* a message **waiting to be sent**: a local echomail message that the tosser has not scanned yet, a local netmail that has not been sent.

The age is the date in the message (month-day-year); a message whose date cannot be read is not purged for its age (it still counts for Messages kept).  A purge by count never goes below what is
held: if there are more held messages than the limit, the limit is not reached.

**How.**  The messages are deleted through the message object of the kind of base (Hudson, Squish, JAM, Fido `*.msg`, Synchronet ...), so all kinds follow the same rules.  Deleting marks a message deleted
and takes it out of the indexes; the space it took in the files is given back by **packing** (`-p`, below).  Last-read pointers of callers are not changed: a pointer behind the first message
that is left simply finds the next one.  The tosser's scan marks (`mktoss -R`) notice that the base changed and look again from the start where they must.

## Packing Hudson bases (`-p`)

A deleted Hudson message keeps its header, its place in the indexes and its text records: the files only grow, and a base that has used 65280 text records cannot take another message.  With `-p`, after the
purge, every Hudson base (a directory with `msghdr.bbs`, `msgtxt.bbs`, `msgidx.bbs`, `msgtoidx.bbs` and `msginfo.bbs`) that holds **deleted messages** is packed, whether or not this run deleted them (callers and
sysops delete messages, too):

* the deleted messages leave the five files, the text records of the others move up, `msginfo.bbs` is made again (the number of active messages, in all and for each area; the low number);
* **message numbers do not change**, nor does the high number (a number is never used again): last-read pointers of callers and reply links stay valid;
* `echomail.bbs` and `netmail.bbs` (the lists of messages that wait to be exported, written for other tossers) follow the messages to their new places; entries of deleted messages go;
* the base is **locked** for the time it takes (a second or two for a base of a few megabytes): a caller or the tosser who writes meanwhile waits;
* before the files are written again they are copied to `name.prepack` (one generation, until the next pack); `-x` removes the copies at the end.  If a pack fails in the middle, the message says so and the `.prepack`
  files are the base as it was: copy them back over the files.
* the files are written **in place** (cut and written again, they stay the same files), so a program that has them open is not left with a deleted file; but a caller who is in the middle of reading a message
  while the base is packed may see a wrong one until the next message he opens, so run it when few are on (an event in the small hours).
* `-n -p` says which bases would be packed and how many deleted messages each holds.

### JAM bases

A JAM base (`name.jhr`, `.jdt`, `.jdx`, `.jlr`) is packed the same way, keeping the **numbers of the messages** (a JAM message number is its place in the index):
* the headers and texts of deleted messages leave `.jhr` and `.jdt`; the text of each message that stays moves up;
* in `.jdx` the empty entries at the **start** go (the number of the first message in the base header moves up by as many); the ones in the middle and at the end stay, as empty entries, so that no number is used again;
* the active count and the modification counter of the base header are made again; the last-read file `.jlr` is not touched (the numbers did not change);
* the same lock, the same `name.prepack` copies, the same `-x`.

Not yet: the Synchronet and Fido `*.msg` kinds (a Squish base reuses the room itself).

**When.**  Make an event (`mkconfig` > Events, action *Command*): `/usr/bin/mkmaint -c /bbs/ra -q`, or use cron:

```
15 4 * * *   MK=/bbs/ra /usr/bin/mkmaint -q
```

Run `mkbackup` first (`BACKUP.md`) the first time, and `mkmaint -n` to see what a first purge would do: a base that has never been purged can hold a lot.

**Test aid.**  `MKMAINT_TODAY=yyyy-mm-dd` takes another day for today (the tests use it); do not set it on a live system.

**Exit codes:** 0 done, 1 not usable (options, no configuration, no such area), 2 an area's base could not be opened.

# Users: `mkuserpurge`

```
mkuserpurge [-c config dir] -d DAYS [-u DAYS] [-s LEVEL] [-k file] [-w DAYS] [-n] [-v] [-q]
```

Marks the users **deleted** who have not called for more than `-d` days.  The records stay in the user file (nothing is renumbered, so last-read pointers and everything that counts users by position
stay right); `mkusered` shows them as deleted and the sysop can take the mark off (Delete in the editor), a deleted user cannot log on.  Without `-d` nothing is purged.

* `-u DAYS`: a user who registered and never called again (no call is recorded) is purged when he registered more than this many days ago (default: the same as `-d`).
* **Never purged:** a user who is already deleted, with **Do not purge** set in the editor, a **QWK network node**, a name in the keep file (`-k`, default `keepusers.txt` in the BBS directory when it is there:
  one name a line, `;` begins a comment, any case), a user with the security level of `-s` or more.  A user whose dates cannot be read is not purged.
* `-n` a dry run (who would go), `-v` each user, `-q` the summary only.
* **`-w DAYS` is the warning list:** only a list, nothing is changed: the users who would be purged within the next DAYS days, with the days to go.  Use it to write to them first.
* `MKPURGE_TODAY=yyyy-mm-dd` takes another day for today (a test aid).  Exit codes: 0 done, 1 not usable.

# The QWK state of the API: `qwkapi/`

When a QWK node takes its packet through the JSON API (`API.md`) the BBS keeps, for each node, in `<BBS dir>/qwkapi/<user>/`:

| file | what |
|---|---|
| `waiting.qwk`, `waiting.state` | the packet that has not been acknowledged yet, and how far the node's pointers go with it; **a packet that waits longer than `keep_days` (default 7) is dropped at the node's next request** (nothing else removes it; `mkmaint` does not touch this folder) |
| `acked.log` | the ids of packets that were acknowledged, expired or dropped (a lost answer to an acknowledgement is harmless); lines older than `keep_days` + 1 days are removed whenever the file is written |
| `reply.ledger` | the SHA-1 of every reply packet that was posted (`done`) or is being posted (`started`); lines older than `max(30, 4 * keep_days)` days are removed |
| `.lock` | the lock of the node's requests |

**A `started` line that stays** means the BBS stopped (a crash, a kill, a power cut) in the middle of posting a reply packet.  The node's retry of that packet is answered `409` and **nothing is posted again**: look at the
area and the log (`api: <token> ... PUT /v1/qwk/reply`), and when you know what was posted, delete that line of `reply.ledger` to let the packet through (or let the node send it again as a new packet).  A node's
state is **not** part of a backup of the user files alone: `mkbackup` holds the whole BBS folder, `qwkapi/` with it.  To forget a node completely, delete its folder (and revoke its token: `mkapitoken revoke`).

# Packing users: `mkuserpack`

```
mkuserpack [-c config dir] [-n] [-f] [-q] [-a | -L]
```

Takes the users marked **deleted** (by `mkuserpurge` or the editor) out of `users.bbs` and `extusers.bbs` (the same records, the others keep their order) and makes `usersidx.bbs` again, so the numbers of the
users behind them move up.  **Run it as an exclusive event** (nobody on, nobody coming); it refuses (exit 3) while a `mk` or `mklisten` of this BBS is running, `-f` packs anyway.  `-n` is a dry run.  Each file changed
is first copied to `name.prepack`; take an `mkbackup` before the first time.  Only MK user files are handled.

**The map** is written first, to `usermap.txt` in the BBS directory (the last pack) and `usermap.YYYYMMDD-HHMMSS.txt` (kept): `old<TAB>new<TAB>name` for every user that was there, `-` as the new number for a user
who went, numbers from 0, `#` lines are comments.  **Doors that keep files by user number must be converted with it** (that is the door's own business: the map is there to make it possible).
**The last-read step** (`-L`, or `-a` = pack and step in one run, the way to run it in the event) applies the newest map to the last-read pointers of the message bases.  A Hudson `lastread.bbs` has a block
for each user number (the boards are inside the block), and **many areas share one file**: every file is moved **once**, whatever the number of areas, and `usermap.state` remembers which files are done for which map,
so running it again (or after a stop) moves nothing twice.  The old file is kept as `lastread.bbs.prepack`.  It refuses when `users.bbs` has more records than the pack left (users came after the pack: their new
numbers would be taken for old ones; `-f` overrides), and while a `mk` runs.  **Every kind of base the BBS has is handled**, each once per file: Hudson (`lastread.bbs`, a block of 400 bytes for each user), Squish (`<base>.sql`, a long for each user), Fido `*.msg` (`LastRead` in the
directory, a word for each user), JAM (`<base>.jlr`: records `[NameCrc, UserNum, LastRead, HighRead]`, the user number is changed and the records of users who went are dropped), Merlin (the pointers inside the
message file, moved through the base's own calls) and Synchronet (keeps no pointers).  A kind that is not known is listed as "NOT handled" and left alone (exit 2).

## Packing users in an event (the recipe)

1. **Once, before anything:** `mkbackup` the BBS, and `mkuserpack -n` to see what would go.  Put the users who must stay in `keepusers.txt` (`mkuserpurge`).
2. **A script**, for example `/bbs/bin/userhousekeeping.sh` (an event *Command* is a program with arguments and no shell, so a script does the steps):

   ```sh
   #!/bin/sh
   BBS=/bbs/ra
   mkbackup -c $BBS || exit 1                  # a backup first; stop if it fails
   mkuserpurge -c $BBS -d 365 -u 60 -q         # mark users deleted: no call for a year, never called for 60 days
   mkuserpack -c $BBS -a                       # take them out, move the last-read pointers (exit 2: a base kind was not handled)
   ```

3. **The event** (`mkconfig` > Events): the action *Command* `/bbs/bin/userhousekeeping.sh`, **Exclusive**, and *Forced* if callers should be asked to leave (with `"warn"` minutes in
   `mklisten.json`).  How often is the event's own schedule: weekly or monthly is plenty; there is no minimum between packs.  Set *If it was missed* to *Skip* or *Run* as you like.
4. **Afterwards** look at `usermap.txt` (how many went), and give the map to the authors of doors that keep files by user number.
   If the script's `mkuserpack` ends with 2 or 3, something was not done: run `mkuserpack -L` again after fixing it (it never moves a file twice).  `events.sh` gets the errorlevel.

## For the authors of doors

A door that keeps its own files by the user number it was given (`DOOR.SYS`, `DORINFO1.DEF`, the `*R` macro) must follow a pack.  After a pack `usermap.txt` in the BBS directory (and the dated copies,
`usermap.YYYYMMDD-HHMMSS.txt`, one for each pack) says for every old number what the new one is:

```
# usermap: user numbers before and after the pack of 2026-11-24 03:00:01
# format 1: old<TAB>new<TAB>name; "-" is a user who went; numbers start at 0
# records before: 1090  after: 18
0	0	Sysop
1	-	Some Old User
```

* Numbers start at 0 as in `users.bbs`.  A `-` means the user is gone: delete the door's data for him.
* The map is the only record of the old numbers: a door that is not converted before the **next** pack has to use both maps in order (the dated copies are kept).
* A door can check which pack it has converted by the first line of the map (`# usermap: ... of <date time>`).
* Plain text on purpose: `awk -F'\t' '$2 != "-" {print $1, $2}' usermap.txt` is a conversion table.

# File areas: `mkfilecheck`

```
mkfilecheck [-c config dir] [-a area] [-f] [-l] [-v] [-q]
```

Checks every file area against its list (`files.bbs` of the area) and says:

* **listed, not there**: the list names a file that is not in the directory;
* **there, not listed**: a file in the directory that the list does not have (`files.bbs`, hidden files, `.bak` and directories are not files of the area);
* **listed twice**;
* **case**: the list writes a name in another case than the file on the disk.  This one is a fault: the BBS uses names exactly as they are written, so the download would not find the file.

`-f` takes the lines of the missing files out of the list (with the description lines under them) and writes the names in the case of the files; `-l` adds a line `NAME  (not described)` for each file that is
there and not listed.  The list is written whole as a new file that replaces the old one; the old one is kept as `files.bbs.bak`.  Several areas that share a directory are checked once.
Exit codes: 0 nothing wrong (or all of it fixed), 1 not usable, 2 something is wrong and was left: so a cron job can mail the output when it is not 0.  `mkbackup` holds the lists (and `-a` the files).

(The duplicate list of the file echoes, `ticdupe.dat`, trims itself: entries older than 30 days go whenever a TIC is tossed.)
