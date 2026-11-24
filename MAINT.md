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
