# Scripts that use the BBS: `mk -x`

A BASIC or Pascal program of yours can ask the BBS questions: who is on line, what is in a message area, what a user's record says.  It does this with one call, `HOST$("...")` in BASIC and `HostCall('...')` in Pascal, and runs with no caller: from a shell, from cron,
from an event.  (Scripts inside the BBS for callers, hooks and writes are the next phases: `MHOST-PLAN.md`.)  This is not a door: a door is a program that runs on a caller's terminal and knows nothing of the BBS; a script is given the BBS piece by piece, and only what you allow.

```
mk -x [-C "capabilities"] [-T seconds] script.bas|script.pas [arguments]
```

`MK` names the BBS directory as for every program; `MKRUN` (the listener's run directory) is needed for the node list.  The script is looked for as given, then in the BBS directory.  Its output goes to standard output, `INPUT` / `ReadLn` read standard input.
The exit code is 0 when the program ended, 1 when it ended with an error or a limit, 2 when it could not be started.

**It is a node.**  A script runs on a *script node*, a number from `MKSCRIPTNODES` (default `101-108`, so it never takes a caller's node): it has a node file in the run directory and a line in `useron.bbs`, so it is on the node list and in `mkmon`
as `script <name>`.  When every script node is in use `mk -x` stops with exit code 2.  A script that is stopped by `kill -9` leaves a node file; the next script takes the number over.

## What it may do: capabilities

| capability | commands |
|---|---|
| (none needed) | `system.info`, `line`, `field`, `meta`, `count`, `arg`, `argc`, `help` |
| `users:read` | `user.list`, `user.get` |
| `msgs:read` | `msg.areas`, `msg.list`, `msg.read`, `msg.text` (public messages) |
| `msgs:private` | with `msgs:read`: private messages too |
| `files:read` | `file.areas`, `file.list` |
| `nodes:read` | `node.list` |
| `events:read` | `events.list` |
| `stats:read` | `stats.total`, `stats.by`, `calls.list` |
| `chat:read` | `chat.who`, `chat.log` |
| `log:write` | `log.write` (a line in the BBS log, marked `Ext <name>:`) |

`*` is all of them.  A call outside the list is a run-time error ("not allowed: user.list needs users:read") and a line in the log.  The capabilities of a script are:

1. `-C "list"` on the command line, when given;
2. else the entry of the script in `extensions.cfg` (below);
3. else **every read capability**: you ran it by hand.

`extensions.cfg` (plain text in the BBS directory, like `uploads.cfg`):

```
# a block for each extension
[who]
file    = scripts/who.bas          # relative to the BBS directory
caps    = nodes:read users:read    # blanks or commas
timeout = 30                       # seconds of run time (default 60, 0 = no limit)
desc    = who is on line           # for you
level   = 100                      # for the menu command and hooks, a later phase
```

`mkcheck` reads it: a file that is not there, an unknown capability or setting.

## How a call works

Both languages have strings of 255 characters, so a command does not hand back its answer: it **keeps it** and tells you **how many lines** it has.  You then ask for the lines.

```
n = HOST$("msg.list 1 20")        the number of messages (area 1, at most 20); the answer is kept
HOST$("line 0")                   the names of the fields, separated by TAB
HOST$("line 1")                   record 1: the values in the same order
HOST$("field 1 subject")          one value of record 1, by the name of the field (any case)
HOST$("meta next")                a value of the whole answer (the number to start the next page at)
HOST$("=user.get 0")              with = in front: the first record (or the one value) comes back directly
HOST$("arg 1")  HOST$("argc")     the arguments after the script's name (arg 0 is the script)
```

An answer that is a table has a first line of field names and then one line for each record; the text of a message (`msg.text`) is plain lines of at most 250 characters.  A value has no TAB or line end in it, a boolean is 1 or 0, nothing is empty, a list is joined with commas.
The text is UTF-8.  Commands take words separated by blanks, `"Mark May"` in quotes is one word.  A user's **number is its place in the user file, from 0**.

| command | what |
|---|---|
| `system.info` | the BBS: `bbs`, `software`, `time`, `bbs_path`, `run_path` |
| `user.list [limit] [after] [text]` | users (`number name handle city level calls first_call last_call upload_files ...`); `meta next` is where the next page starts |
| `user.get <number or "name">` | one user |
| `msg.areas` | the message areas |
| `msg.list <area> [limit] [after] [text]` | message headers (the number to start after, a search in subject, from and to) |
| `msg.read <area> <number>` | the header of a message; `msg.text <area> <number>` its body, line by line |
| `file.areas`, `file.list <area> [limit] [after] [text]` | the file areas, the files of one |
| `node.list` | who is on line (callers and script nodes): `node user activity type address since ...` |
| `events.list` | the events `mklisten` runs |
| `stats.total [from] [to]`, `stats.by <day\|hour\|node\|label\|port\|user\|result\|type> [from] [to]`, `calls.list [limit] [since]` | the statistics and the last calls (what `/v1/stats` and `/v1/calls` of the API say) |
| `chat.who`, `chat.log [n]` | the multi-node chat room (`CHAT.md`) |
| `log.write <text>` | a line in the BBS log |

The data comes from the same functions as the JSON API (`API.md`), so a script and the API see the same BBS.

## Examples

`ext/` of the source (and `/usr/share/doc/mkbbs/examples/ext` of the package) has `who.bas` and `who.pas`, the unit `mkbbs.pas` (copy it next to a Pascal script: `uses mkbbs;` gives `Query`, `Field`, `Line`, `Meta`, `Value`, `Arg`, `LogLine`) and `hostfn.bas` (`DEF FN` lines for BASIC:
`FNQ(cmd$)`, `FNF$(n, name$)`, `FNL$(n)`, `FNV$(cmd$)`).

```
10 N = VAL(HOST$("msg.list 1 10"))
20 FOR I = 1 TO N
30 PRINT HOST$("field " + MID$(STR$(I), 2) + " from"); ": "; HOST$("field " + MID$(STR$(I), 2) + " subject")
40 NEXT I
```

```pascal
uses mkbbs;
var i: integer;
begin
  for i := 1 to Query('msg.list 1 10') do
    writeln(Field(i, 'from'), ': ', Field(i, 'subject'));
end.
```

The interpreters are the ones of `mkbasic` and `mkpascal`: no files but the script's own folder, no shell, run-time limits (`-T`).  Run from `mklisten` as an event action, a script is just a command: `mk -x /path/script.bas`.
