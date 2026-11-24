# Message base maintenance: `mkmaint`

The message areas have limits that `mkconfig` stores (Messages: **Days kept**, **Messages kept**, **Received days**).  Nothing applied them: the bases only grew.  `mkmaint` applies them.

```
mkmaint [-c config dir] [-n] [-a area] [-v] [-q]
   -c   the configuration directory, instead of MK in the environment
   -n   a dry run: says what would be purged, changes nothing
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
and takes it out of the indexes; the space it took in the files is given back by packing (not yet part of `mkmaint`).  Last-read pointers of callers are not changed: a pointer behind the first message
that is left simply finds the next one.  The tosser's scan marks (`mktoss -R`) notice that the base changed and look again from the start where they must.

**When.**  Make an event (`mkconfig` > Events, action *Command*): `/usr/bin/mkmaint -c /bbs/ra -q`, or use cron:

```
15 4 * * *   MK=/bbs/ra /usr/bin/mkmaint -q
```

Run `mkbackup` first (`BACKUP.md`) the first time, and `mkmaint -n` to see what a first purge would do: a base that has never been purged can hold a lot.

**Test aid.**  `MKMAINT_TODAY=yyyy-mm-dd` takes another day for today (the tests use it); do not set it on a live system.

**Exit codes:** 0 done, 1 not usable (options, no configuration, no such area), 2 an area's base could not be opened.
