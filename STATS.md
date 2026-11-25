# Statistics

`mk` writes **one line for each call** when the call ends; `mkstats` makes reports from them.  The statistics are for the sysop, and the sysop can **show numbers from them to callers** in any screen or menu prompt with the `^T` display codes (below); a caller sees nothing of them otherwise.

## What is written

`<BBS directory>/stats/YYYY-MM.tsv`, one file for each month, tab separated.  The first lines name the fields:

| Field | Meaning |
|---|---|
| `start`, `end` | seconds since 1970 (UTC); `date` is the local day of the start |
| `node` | the node the call was on |
| `type` | the kind of session: `telnet`, `raw`, `ws`, `std` (a terminal or inetd), `local` |
| `label`, `port` | what the port is for, and its number: the **`"label"`** of the port in `mklisten.json` (default: its type, `telnet-tls` for a TLS port, `sysop`), for example `"label": "ssh"` on the port that `mkbbsssh` connects to, so that SSH calls can be told apart |
| `addr` | the address of the caller (the real one behind a front end) |
| `user` | the name, empty when nobody logged on |
| `result` | `ok` (logged on and off), `failed` (the log-on failed: wrong passwords, too many tries at the name: the calls that `loginguard` counts), `nologin` (the caller went before a name was accepted: a port scan, a changed mind) |
| `secs` | how long the connection lasted |
| `ulfiles`, `dlfiles`, `ulk`, `dlk`, `msgs` | files and kilobytes uploaded and downloaded and messages posted during the call (from the counters of the user) |
| `reason` | why the call ended (the code of the user object; 0 while the user was ok) |

The line is written with one write on a file opened for appending, so calls that end together do not mix their lines.  A statistics directory that cannot be written is skipped: it never disturbs a call.
The files are plain text: read them with anything, keep them as long as you like, copy them away.  The directory is in the backup (`BACKUP.md`) because it is in the configuration directory.

A caller who has gone before the BBS is through with the log-on is **no longer a failed log-on** (the call ended with the errorlevel 88 before): a port scan or a dropped connection does not count against the
address in `loginguard` and is `nologin` here.

## For callers: the `^T` display codes

A screen (`mkdraw`: Bbs Screen Code, the statistics are at the end of the list) or a menu prompt can hold a code that `mk` replaces by a number out of these files when it is shown, like `^F` (the caller) and
`^K` (the system) (`MKBBS.md`).  The code is **`^T`, a period letter and an item letter**; in a menu prompt, where control characters cannot be typed, it is `\t` and the same two letters (`Calls this month: \tMC`).

| period | | item | | |
|---|---|---|---|---|
| `T` today | `W` the last 7 days (today included) | `C` calls (log-ons) | `M` minutes on line | `A` average minutes of a call |
| `M` this month | `Y` this year | `D` files downloaded | `K` K downloaded | `P` files uploaded |
| `A` everything on record | | `Q` K uploaded | `G` messages posted | `U` different callers, `H` the busiest hour (`14:00`) |

**Upper case is the whole system, lower case is the caller himself** (only his own calls: `\tMc` is "your calls this month", `\tAm` "your minutes in all"); `U` and `H` are for the system only.  Numbers have thousands
separators (`1,904`).  Only **calls that got in** count (a failed log-on or a call without one is in none of the numbers), and a call that is still going is not yet in them.  A combination that is not one shows
nothing (and both its letters are used up).  Examples: `Callers today: \tTU  this month: \tMU  busiest hour: \tMH` and `You have called \tMc times this month, \tMm minutes.`

The files are read once for each call of a caller and only as far as the period needs (the month for `T`, `W`, `M`; the year for `Y`; all of them for `A`), so a screen full of codes costs one read.  What a caller can see is
only sums of the whole system and his own numbers: never another caller's name or figures.

## In the monitor

`mkmon` (the sysop monitor, `MKLISTEN.md`) has a statistics screen: **S** in the node list.  It shows the calls of **today** (T), the last **week** (W), the **month** (M) or the **year** (Y): the totals,
a bar for each hour of the day, and the last calls (time, node, port label, user, result, minutes; failed log-ons in red).  It is read from the files above (the monitor must have been started with the
configuration directory, which the sysop port of `mklisten` does), and is read again every 5 seconds.

## `mkstats`

```
mkstats [-c config dir] [-m YYYY-MM | -d YYYY-MM-DD | -y YYYY | -a] [-by day|hour|node|label|port|user|result|type] [-top N] [-csv]
```

`MK` names the configuration directory, or `-c` does.  The period is this month unless you say otherwise.

```
$ mkstats -m 2026-11
Calls in 2026-11 (1 file(s))
  Calls            214   (162 log-ons, 9 failed log-ons, 43 without a log-on)
  Callers          21 different
  Time on-line     1,904.5 minutes by callers who logged on (11.8 per call, the longest 74.0)
  Uploads          14 file(s), 5,120 K
  Downloads        63 file(s), 31,744 K
  Messages posted  88
  Busiest hour     21:00 (31 calls)
  Busiest day      2026-11-14 (19 calls)
```

`-by` adds a table with a line for each day, hour of the day, node, port label, port, user, result or kind of session (`-top N` for the first N lines: users, labels, ports, results and types are sorted
busiest first).  `-csv` writes the table, or the totals, as comma separated values for a spreadsheet.  Exit 1 when there is nothing to report.

## When it counts

* Written by `mk` itself, also for a call that was only a connection (`nologin`).  Network passes (`mk -G`) and the other tools are not calls and write nothing.
* A call that `mk` loses (it is killed, the machine stops) writes nothing: the statistics are what ended normally.
