# Statistics

`mk` writes **one line for each call** when the call ends; `mkstats` makes reports from them.  The statistics are for the sysop (a caller sees nothing of them; a way to show numbers in the
screens callers see is a later step: it would be new display codes that a screen can contain).

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
