# Message base converter: `mkmsgconv` (plan, 2026-11-25)

Today a message area has one kind of base for good: Hudson, Squish, JAM, Fido `*.MSG`, Merlin or Synchronet (SMB) (the area's *base type* in `mkconfig`; Ezycom and PCBoard are read-only kinds the message object also knows).  Moving an area to another kind means
writing its messages again by hand.  The sample BBS is the reason: 104 of its 122 areas are Hudson bases from the DOS days, a format with a ceiling (65 280 text records, 200 areas, one set of files for all) that
JAM, Squish and Merlin do not have.  `mkmsgconv` copies an area into a new base of another kind, checks the copy, and (when asked) switches the area over.

## What it does

```
mkmsgconv [-c config dir] -a <area>[,<area>|<from>-<to>] | -k <type>   which areas: numbers, or every area of a kind (H S F J M Y)
          -t <type>                    the new kind: H S F J M Y
          [-d <file id>]               where the new base is (default: the file id of the area, or area<N> when it has none), below the message path of the area
          [-n]                         dry run: what would be copied, what would not fit, nothing is written
          [-s]                         after the copy checked out: switch the area in the configuration to the new kind (the old files stay)
          [-m]                         keep the number map (old new) next to the new base
          [-f] [-v] [-q]              force (callers on line, a non-empty destination ...), each message, only the summary
```

* **The old base is never changed.**  The new base is written beside it; the old one stays until the sysop removes it.  A destination that already holds messages is refused (`-f` appends: for a Hudson board that is shared by several areas, where
  the board number is the area number and the path is the common one).
* **What is copied**, through the common message object (`MKMsgAbs`), so every kind reads and writes the same way: from, to, subject, date and time, origin and destination addresses, cost, the flags (private, received, local, crash, kill/sent, sent, file attach, request
  receipt / audit, return receipt, file request, hold, echo), the **text exactly as stored** (kludge lines `^A...`, hard line ends, the tear and origin lines), the reply link and the see-also links.  Deleted messages are left out.
* **Numbers:** the new base numbers the messages from 1 in the order of the old numbers (a JAM or Squish base has no gaps; deleted messages go).  The map (old → new) is used for the **reply and see-also links** (written again after the last message is in) and
  for the **last-read pointer of every caller** (the highest new number at or below the old pointer; the user number is the record in `users.bbs`, as for `mkuserpack`).  `-m` keeps the map for doors and other tools.
* **What a kind cannot hold** is counted in the dry run and in the report ("Hudson has no origin address: 31 messages", "a Hudson subject is 72 characters: 2 cut"), never silently lost without a line; `-n` is the way to see it before anything is written.
* **Checked:** after the copy the new base is read again and compared with the old one message by message (fields and text), and the counts must agree; nothing is switched when it does not.
* **Safe by default:** it refuses while callers are on line (`useron.bbs`) or the listener runs an exclusive event (use `-f`); refuses an area with **messages waiting to be sent** (unsent netmail, echomail the tosser has not scanned: run `mktoss` first), as `mkmaint` never purges them;
  takes the lock of the old base while it reads.  The tosser's scan mark of a converted echo area is set to the new top (the converted messages are old news).
* **`-s`** changes the area's base type and file id in `config.mk` and `bbsconfig.json` together (the configuration is saved the way `mkconfig` does, so the JSON mirror follows), after the check.  Without `-s` the report says what to set in `mkconfig`.
* **Many areas:** `-k H -t J` converts every Hudson area, one base each (`area<N>` files in the area's path), prints a line for each and a total; one that fails does not stop the others.

## Not in the first version

Squish and JAM index details such as JAM's per-message `Replies` chains are rebuilt by the writer; **message ids** (`MSGID`) and reply kludges stay in the text as they are, so echomail threading by id still works.  Conversion between
areas of different names (merging two areas into one base) is a copy with `-f` into an existing base, which the tool allows but does not try to be clever about.  Ezycom and PCBoard bases can be read as a source (`-k E`, `-k B`) but are not written.

## Phases

1. **The engine** (`MKMsgConv.pas`) and `mkmsgconv -a <area> -t <type> [-d id] [-n] [-v]`: the destination id by the rules of the configuration, copy of all fields and text, the number map, reply links, the second read and compare, the report of what a kind cannot hold; tests: a base of each kind made with `msgput`, converted to
   every other kind and compared with `tossdump`/a dump of the messages, the round trip H → J → S → F → M → Y → H gives the same messages, deleted messages stay out, a destination with messages is refused.
2. **The callers and the tosser:** the last-read pointers through the map for every kind, the scan mark, the refusals (callers on line, messages waiting to be sent, an exclusive event), `-m`; tests with `setlr` and `merlr` pointers and a waiting echomail message.
3. **`-s` and many areas** (`-k`, ranges), the configuration saved with its JSON mirror, `mkcheck` (an area whose base is not the kind it names), documents (`MAINT.md`, `MKBBS.md`, README), `build.sh`.

## Decisions (2026-11-25)

1. The old base is never changed; `-s` only switches the configuration.  2. Renumber from 1, with the map.  3. An area with messages waiting to be sent is refused until `mktoss` has taken them.  4. A converted Hudson area leaves its messages in the shared files until a `mkmaint -p` pack.

The **dry run** converts into a scratch directory below `/tmp` (removed afterwards) and compares, so what a kind cannot hold is counted exactly, not guessed.

## Questions (answered above)

1. **Never change the old base** (proposal), and switch the area only with `-s`?  Or should `-s` also move the old files to a `*.old` name?
2. **Numbers:** renumber from 1 with the map (proposal), or keep the old numbers where the new kind allows (Hudson, JAM and Squish can hold gaps as deleted records) so that pointers and echomail high-water marks stay valid without a map?  Keeping them wastes a little space and is exact; renumbering is tidy.
3. **Messages waiting to be sent:** refuse the area until `mktoss` has taken them (proposal), or copy them with their "unsent" state?
4. **Hudson to anything:** the 104 Hudson areas share one set of files; converting one area leaves its messages in the shared files (they go away with a Hudson pack when the area no longer points to them: `mkmaint -p`).  OK?
