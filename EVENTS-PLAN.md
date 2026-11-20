# Events: plan (events.mk, the scheduler in mklisten)

Status: **plan only** (2026-11-20).  Nothing is built.  The sysop's decisions of 2026-11-20 are marked *(decided)*; items marked
*(proposal)* are still for the sysop to confirm.

## Where we are

* `config.mk` holds 30 events (`EventType`, `Struct.MK`): status (deleted / enabled / disabled), time `HH:MM`, errorlevel, days
  (bit mask, Sunday = bit 1), forced (normal / forced / delayable), last run (`String[8]`).  19 bytes each, no spare room, and the
  array sits in the middle of a fixed record, so it cannot grow.
* `mkconfig` edits them (`CfgEvent.pas`); `MKCfgAbs` has the getters and setters; `mkcfgcvt`, `CCvt` and the JSON form carry
  them.  RA, QuickBBS and SuperBBS keep their own event records (RA: `events.ra`).
* **Nothing runs them.**  The DOS system relied on the front-end mailer, which exited with the errorlevel at the event time and a
  batch file did the work.  `mk -T<min>` ("minutes to the next event") is parsed into `TimeToEvent` and never used.
  `mkbink` schedules its own calls and does not use events.

## What we want

A scheduler in `mklisten` that runs the configured events, and room in the event for **what to do**: a type and a command line.
The old fields keep their meaning (time, days, status, forced); the errorlevel stays for anyone who still uses it.

## The file: events.mk *(proposal)*

A new optional file next to `mailer.mk`, found like it (`FindBbsFile`), loaded when present, a missing or shorter file keeps the
defaults (every event "no action": today's behaviour).  Not in `config.mk`, so no size or offset changes there and no other tool
that reads `config.mk` is touched.  Same index as the config's events (1..30).

```
EventsCfgType = Record
  Version: Word;                        {EventsCfgVersion = 1}
  Ev: Array[1..30] of EventExtType;
  End;

EventExtType = Record                   {150 bytes; 30 of them ~ 4.5 KB}
  Action: Byte;                         {0 none, 1 command, 4 mailer poll, 5 mailer hold, 6 mailer free ... see below}
  Flags: Word;                          {bit 0 exclusive (below), bit 1 log the output of the command, ...}
  Late: Byte;                           {what to do with an occurrence that was missed (below): 0 skip, 1 within LateMin, 2 run, 3 run per miss}
  LateMin: Word;                        {minutes of grace for Late = 1 (default 10)}
  LateMax: Byte;                        {most runs for Late = 3 (default 5), so a long outage does not start dozens}
  Cmd: String[100];                     {command line, or the address for the mailer actions}
  TimeoutMin: Word;                     {killed after this many minutes, 0 = 60}
  Reserved: Array[1..40] of Byte;
  End;
```

**What the daemon remembers is not in this file** *(changed at the start of phase 1)*: a daemon must know when an event last
ran (so it does not run twice and a restart does not repeat it), but `mkconfig` saves every configuration file from its own copy,
so a field that `mklisten` wrote into `events.mk` would be overwritten by an old value the next time the sysop saves.  The run state
(`LastDueU`: the last occurrence dealt with; `LastRunU`: the last start; `LastResult`: the exit code, -1 = not run or killed) goes into
**`events.run`** in the BBS directory, written by `mklisten` only (temp file and rename), read by `mkmon`.  `events.mk` is the sysop's
definition; `events.run` is state, may be deleted (then nothing counts as missed) and is not part of the JSON configuration.

JSON (`MKCfgJs`, `genjsoncfg.py`, `tests/jsoncfgtest.py`): a fifth section `"events"` next to `"mailer"`; `CCvt` copies it between
MK forms; for RA / QuickBBS / SuperBBS the getters answer 0 / '' and the editor hides the fields (as for hashed passwords).

## Actions *(decided: the command and the mailer actions; hub pass later)*

| Action | Does | Cmd |
|---|---|---|
| 0 none | nothing but the errorlevel script, if the errorlevel is set | - |
| 1 command | runs the program, no shell, `MK` in its environment; output to the log | command line |
| 4 mailer poll | `POLL <addr>` or `POLL *` through the mailer control socket | address or `*` |
| 5 / 6 mailer hold / free | `HOLD` / `FREE` of a link, or of all: mail hours (a "zone mail hour") | address or `*` |
| 3 hub pass | the QWK hub pass (roadmap items 2 and 7); the settings are in the **hub section** of the QWK configuration, the event only names the hub *(decided)* | hub name |

The mailer actions need no new code in mkbink (the control socket already has them).  Toss, maintenance and the like are commands
(`mktoss`, `mknodeidx` ...), no special types.

## The errorlevel script *(decided)*

The errorlevel of an event is what the DOS front end exited with so that the batch file could act on it.  Here an event whose
errorlevel is not 0 runs the script **`events.sh` in the BBS directory** (the directory of the configuration; the name is lower case,
fixed) with the arguments `<errorlevel> <event number>`, and `MK`, `MKEVENT`, `MKERRORLEVEL` in the environment; the script does what
the old batch file did, typically a `case "$1" in ...`.  It runs after the event's action (or alone when the action is "none"), in the
same slot (so an exclusive event stays exclusive through it), killed by the event's timeout.  It is run directly (it needs the execute bit
and a `#!` line; a script that is missing or not executable is logged once per start of `mklisten`, not at every event).  No shell is
involved in finding it; what the script does is the sysop's own.

## The scheduler (mklisten) *(proposal)*

* A pure unit `MKEvent.pas`: `Due(Event, Now, LastRun, Late)`, "next run" and "minutes to the next event", with no I/O, so it is
  testable with any clock.  Local time (the sysop thinks in local time); days = the bit mask; `24:00` = midnight; an event is due
  when it is enabled, today is a day it runs, `Now >= time` and it has not run since that time today (`LastRunU` before it).
* **Missed events** *(decided: set per event, `Late`)*: an *occurrence* is one scheduled time (a day the event runs, at its time).
  When `mklisten` finds occurrences after `LastDueU` that have passed (it was down, or busy with an exclusive event), `Late` says:
  **0 skip** (they are marked dealt with, nothing runs); **1 within N minutes** (run once if the latest missed occurrence is no more than
  `LateMin` minutes ago, default 10, else skip); **2 run** (run once, however late); **3 run per miss** (run once for each missed
  occurrence, at most `LateMax`, default 5, one after the other; the cap is so that a month's outage does not start 30 passes).
  `LastDueU` moves to the latest occurrence either way, so nothing runs twice for one occurrence.  An event still running when its next
  occurrence falls due counts that occurrence as missed.
* One tick a minute.  Each event runs in a child process (`RunTool`, which exists: no shell, timeout, output into the log).
  **Overlap is set per event** *(decided)*: an event with the **exclusive** flag starts only when nothing else is running and nothing
  else starts while it runs (the others that fall due wait, in order, and are then handled by their `Late` setting if the wait was
  long); events without the flag may run at the same time as each other (at most 4 together, a number in the `events` object).
  The same event never overlaps itself.  A failure is logged (`Event 3 "toss" ended with 1`) and does not stop the others;
  `LastResult` keeps it for the monitor.
* `mklisten`'s JSON gets an `"events"` object (`config` = the BBS configuration directory, `late` = minutes; the mailer's
  directory is reused when it is absent).  No events object = no scheduler, as today.
* **Exclusive events and callers** (phase 3; the warning side in phase 5): events without the exclusive flag run alongside callers.  An
  exclusive event keeps new logins out while it waits and while it runs; *delayable* / *normal* wait for the callers to log off, *forced*
  tells them and ends their sessions at the time.  `mklisten` starts `mk` with `-T<minutes>` to the next forced or
  delayable event, which finally gives `TimeToEvent` its meaning: `mk` shortens a caller's time so that they are off before it.

## Phases

1. **events.mk and the configuration plumbing** (DONE 2026-11-20, uncommitted: `EventExtType` / `EventsCfgType` in MKGlobT, `CfgObj.HasEventExt/GetEventExt/SetEventExt`, `MKCfgObj` load / save / `MKEventsLoad`, JSON section `events`, `CCvt`, `MKCfgCvt`, `tests/eventscfgtest.py`): the records, load / save in `MKCfgMK`, getters and setters in `MKCfgAbs` and the
   MK classes (others answer 0 / ''), `SaveFileNames`, `CCvt`, JSON section and generator, `mkcfgcvt`.  Tests: round trip of the file,
   an old configuration without `events.mk`, JSON round trip, the other formats unaffected.
2. **mkconfig editor** (DONE 2026-11-20, uncommitted: `CfgEvent.pas`, `tests/eventsedittest.py`): Action (choice), Command, Timeout, Late (skip / within N minutes / run / run per miss, with minutes and maximum) and Exclusive on the event form, MK configurations only; the list shows
   the action.  Test with `cfgshot.py`.
3. **The scheduler** (DONE 2026-11-20, uncommitted: `MKEvent.pas`, `mkevents`, `mklisten` events section, `tests/eventtest.pas`, `tests/eventlistentest.py`; forced events disconnect with the K frame of the monitor then SIGTERM after 15 s, exclusive waits are bounded by the Late mode (Skip 1 minute, Within the grace, Run / Per miss never)): `MKEvent.pas` (with a test program over many clocks: days, midnight, `24:00`, each Late mode, the cap, restart, DST
   changes), `mklisten` ticks, the command and mailer actions, exclusive and overlapping events, the `events.sh` errorlevel script,
   `LastDueU` / `LastRunU` written, log lines.  For tests a hidden clock offset
   (`"events": {"clock": ...}` or an environment variable) so that a test does not wait for real time.
4. **Hub pass action** together with hub scheduling and failure handling (roadmap items 2 and 7): the hub section of the QWK
   configuration holds the settings (retry, back-off, what to do on failure); the event only names the hub and says "when".  Its own small plan before it is built.
5. **Warning the callers** of an exclusive event: `-T` for `mk` (a caller's time is cut so they are off before it), a message to the nodes before the time.
6. **mkmon**: an events screen (next run, last run, last result, run now), through a small control file or socket of `mklisten`.
7. **Docs**: `MKLISTEN.md` (the `events` object), `MKBBS.md`, `GETTING-STARTED.md` (a cron replacement note), this plan's status.

Every phase ends with its tests, then the full build, as usual.

## Decided 2026-11-20

1. First version: the command action and the mailer actions (poll, hold, free); hub pass later.
2. Missed events: per event (`Late`): skip, run within N minutes (default 10), run, or run once per missed occurrence (capped).
3. Overlap: per event, with an **exclusive** flag.
4. The errorlevel runs `events.sh` in the BBS directory with the errorlevel and the event number.
5. Hub pass settings live in the hub section of the QWK configuration.
6. Caps: 5 runs for "run per miss", 4 events together.  `events.sh` gets `<errorlevel> <event number> <exit code of the action>` (0 when there was no action).
7. **Exclusive stops BBS access.**  It is for maintenance that needs the BBS quiet (packing the message base or the user base): while an
   exclusive event runs, `mklisten` takes no logins (a caller is refused with a message), and the event does not start until the
   callers are gone: *delayable* and *normal* wait for them to log off (up to a limit, then the occurrence is handled by `Late`),
   *forced* (the old Forced field) tells them and ends their sessions at the event time.  This is in phase 3, not phase 5.

## Still open

* Nothing; the caps (5 runs per miss, 4 events together) and the third argument of `events.sh` are decided.
