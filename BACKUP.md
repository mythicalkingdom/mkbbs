# Backup and restore

`mkbackup` makes a backup of the BBS in one file, while the BBS is running, and restores it.  The configuration files also keep a copy of what they replace.

## The copy that every save keeps (`.bak`)

Every program that saves the MK configuration (`mkconfig`, `mkcfgcvt`, the tools that write `events.mk`, `fileecho.mk`, `mailer.mk` ...) first copies the file it is about to replace
to `<name>.bak` (`config.mk.bak`, `messages.mk.bak` ...): **one generation**, kept next to the file.  A save that changes nothing leaves the `.bak` alone, so it is always the
version from before the last real change.  To undo a wrong save, copy the `.bak` back over the file (with `mklisten` and the BBS stopped, or between calls).

## `mkbackup`

```
mkbackup [-c config dir] [-o directory] [-k N] [-a] [-q]   make a backup
mkbackup -l archive                            list what it holds
mkbackup -t archive                            test it: every file is read and its checksum compared with the manifest
mkbackup -r archive [-n] [-f] [-C root]        restore it
```

`MK` names the configuration directory, as for `mk` (`MK=/bbs/ra mkbackup`), or `-c /bbs/ra` does (the program starts again with `MK` set).

**What a backup holds**
* the configuration directory with everything below it: the `.mk` files, the user files, the QWK network maps and ledgers, the language files, the node and echo lists ...;
* the menu and screen directories of the configuration;
* the message bases of all the areas (Hudson, Squish, JAM, Fido `*.msg`, Synchronet, MK-Merlin), wherever they are;
* the `files.bbs` of the file areas, and with **`-a`** the file areas themselves (large).

**What it leaves out:** logs, the spool and the inbound and outbound directories of the mailer, the node directories (`node1` ...), `temp` directories, `*.lock`, `*.tmp`, and the backup
directory itself.

**While the BBS runs.**  Each message base is locked while its files are copied, so a caller or the tosser cannot write in the middle of one; the lock lasts for the copy of that base
(seconds).  The other files are copied as they are (they are written whole).

**The archive** is `mkbbs-<name>-<date>-<time>.tar.gz` in `<configuration directory>/backup/` (or the directory of `-o`), readable only by its owner (it holds passwords).  It is an ordinary
`tar.gz`: `tar tzf` lists it, any program opens it.  Names inside are the full paths of the files; the last entry, `MKBACKUP.MANIFEST`, has the size and a SHA-1 checksum of each file.
`-k N` keeps the N newest archives of that BBS and removes the older ones.

**Testing.**  `mkbackup -t archive` reads the whole archive and compares each file with the manifest: a damaged or cut-off archive is found (exit 3).  Do it after a backup that matters,
and before a restore (a restore does it itself first and does nothing when it fails).

**Restoring**
* `-n` only says what would happen: `would restore` (the file is missing), `kept (differs; -f replaces it)`, and a summary.  Nothing is written.
* Without `-f` a file that is there and **differs** is kept as it is; a file that is missing is restored; one that is the same is left alone.
* With `-f` a file that differs is replaced, and the old one is kept as `<name>.pre-restore`.
* `-C root` puts everything below `root` instead of in the places it came from: restore into a new directory, look, and move things yourself.
* A restore in place is **refused** while a `mklisten` or `mk` is running on that BBS (it has the configuration directory as its directory or as `MK`) unless `-f` is given.  Only the processes
  that can be looked at count: run it as `root` or as the user of the BBS.  A dry run and `-C` are always allowed.
* Each file is written next to its place under a temporary name and then renamed, so a file is never half written.

**Exit codes:** 0 done, 1 not usable (options, no configuration, an archive that cannot be opened), 2 the archive could not be written or a file could not be saved, 3 the test found something
wrong, 4 the restore was refused.

## A backup every night

An event of the BBS runs a command at a time (`mkconfig` > Events, the action "Command"): `/usr/bin/mkbackup -c /bbs/ra -q -k 7 -o /var/backups/mkbbs` (the user the listener runs as must be
able to write the directory).  A cron job does it as well:

```
30 3 * * *   MK=/bbs/ra /usr/bin/mkbackup -q -k 7 -o /var/backups/mkbbs
```

Copy the archives to another machine: a backup on the same disk is only a protection against a wrong edit, not against the disk.

## What is not covered
* The file areas, unless `-a`.  The mailer's spool and the files that wait there.
* A running mail session of `mkbink` writes its own files; a backup in the middle of one has what was written so far (the spool is left out anyway).
* Message base kinds other than the ones above (Ezycom, PCBoard): named in the output, not held.
