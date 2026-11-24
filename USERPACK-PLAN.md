# User packer: plan

Status (2026-11-24): **phases 1-3 built** (`mkuserpack`, `usermap.txt`, the last-read step for Hudson, Squish, Fido, JAM, Merlin, Synchronet with `usermap.state`, tests); phase 4 built (docs in `MAINT.md`: the event recipe, a note for door authors).  **Done.**  `mkuserpurge` marks users deleted and leaves the records where they are (`MAINT.md`).  This plan is for taking the deleted records out of the user files, **keeping a map from the old user
numbers to the new ones** so that everything that holds a user number can be brought along.  The question that came first is in `MAINT.md` and the notes below: what holds the number.

## What holds a user number

| Where | What happens | Handled by |
|---|---|---|
| `users.bbs`, `extusers.bbs` | the position of the record is the number | the pack (the same records go from both, in the same order) |
| `usersidx.bbs`, `usersxi.bbs` | the name indexes: name -> record number | **rebuilt** from the new `users.bbs`, not shifted *(check the format of `usersxi.bbs` first)* |
| `exitinfo.bbs`, `door.sys`, `dorinfo1.def`, `*R` | made again for every call | nothing: the pack runs when nobody is on |
| the last-read data of the message bases (Hudson `lastread.bbs`, and the other kinds' own files) | persistent, keyed by number | **the lastread step** (below), driven by the map |
| the files of **doors** (scores, saves) | keyed by the number the door was given | **not ours**: the **map file** is left for the doors' own tools |
| users known by name (`mkqwk`'s `users.mko`, network maps, statistics) | the name | nothing |

## The pieces

**1. `mkuserpack`**: the pack.  Removes only users marked **deleted** (what `mkuserpurge` and the editor make), writes `users.bbs` and `extusers.bbs` again without them (same order, so the others
keep their order), rebuilds the two indexes, and writes the **map**.  `-n` is a dry run (how many go, the map's size, what would be refused).  It refuses while somebody is on (the `useron.bbs` list and the `mk` processes of the BBS)
unless forced, keeps `name.prepack` copies of every file it writes, and does nothing when no record is deleted.

**2. The map**: `usermap.txt` in the BBS directory, **left there after the pack for the doors**, and a dated copy (`usermap.YYYYMMDD-HHMMSS.txt`; the older ones are kept).  One line for each user that was there:
`old<TAB>new<TAB>name`, with `-` as the new number for a user who was removed.  A header says when, how many records before and after, and the version of the format.  Plain text on purpose: a door's
tool, a script or `awk` can use it; the doors are theirs to convert, but they get a complete, trustworthy table.

**3. The lastread step** (`mkuserpack -L`, a separate run): applies the map to the last-read data of every message base of the configuration.  It is **separate from the pack and can be run again**: it reads the newest
map, remembers in `usermap.state` which bases are done (and for which map), and skips them next time, so a stop in the middle costs nothing.  Hudson first (`lastread.bbs`: a block for each user, moved to its new place,
the blocks of removed users dropped).  The other kinds (JAM, Fido `*.msg`, Squish, Synchronet) are done one at a time **after their code has been read**; a base of a kind that is not handled yet is **listed and left alone**
(and the step ends with exit 2), so nothing is changed that is not understood.

**4. As an event.**  An exclusive event (callers are asked to leave, new ones are refused) with the commands `mkuserpack -c /bbs/ra` and then `mkuserpack -L -c /bbs/ra`, or one command that does both (`mkuserpack -a`).  Run
`mkbackup` first (the docs say so, and the dry run says it again).

## Tests (private copy of the sample BBS)

* purge some users, `mkuserpack -n` says how many; the real pack: the user file and `extusers.bbs` have the same records without the deleted ones, in order; **the indexes find every remaining user by name** (the editor's search /
  the logon); the number of records is right everywhere.
* the map: every old number appears once, removed users have `-`, the new numbers are 0..n-1 in order; the dated copy and `usermap.txt` agree; a second pack makes no map (nothing to do).
* the lastread step: the pointers of a user who moved are at his new number, those of a removed user are gone, a second run changes nothing, a base of an unhandled kind is listed and exit is 2.
* it refuses with a caller on (a fake `mk` process, as in the backup test), and `-n` writes nothing.

## Phases

1. `mkuserpack`: the user files, the indexes, the map, the dry run, the refusal; tests.
2. The lastread step for Hudson; `usermap.state`; tests.
3. The other base kinds, one by one, each after reading how it keeps the number (JAM `.jlr` has the number and a name CRC).
4. Docs (`MAINT.md`, the event recipe, a note for door authors about `usermap.txt`).

## Decisions (sysop, 2026-11-24)

1. The map is `usermap.txt` in the BBS directory, with dated copies beside it: **yes**.
2. No option to remove only trailing deleted users: **not needed**.
3. No minimum interval: how often the pack runs is up to the event schedule.
