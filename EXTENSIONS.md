# Scripts that use the BBS: `mk -x`

A BASIC or Pascal program of yours can ask the BBS questions: who is on line, what is in a message area, what a user's record says.  It does this with one call, `HOST$("...")` in BASIC and `HostCall('...')` in Pascal, and runs with no caller: from a shell, from cron,
from an event.  (Scripts for callers, inside the BBS, are the menu command 175 and the hooks, below.)  This is not a door: a door is a program that runs on a caller's terminal and knows nothing of the BBS; a script is given the BBS piece by piece, and only what you allow.

```
mk -x [-n] [-C "capabilities"] [-T seconds] [-R run dir] script.bas|script.pas [arguments]
```

`MK` names the BBS directory as for every program; `MKRUN` (the listener's run directory) is needed for the node list.  The script is looked for as given, then in the BBS directory.  Its output goes to standard output, `INPUT` / `ReadLn` read standard input.
The exit code is 0 when the program ended, 1 when it ended with an error or a limit, 2 when it could not be started.

**It is a node.**  A script runs on a *script node*, a number from `MKSCRIPTNODES` (default `101-108`, so it never takes a caller's node): it has a node file in the run directory and a line in `useron.bbs`, so it is on the node list and in `mkmon`
as `script <name>`.  When every script node is in use `mk -x` stops with exit code 2.  A script that is stopped by `kill -9` leaves a node file; the next script takes the number over.

## An extension for callers: menu command 175

Give a program a name in `extensions.cfg` (below), then put the menu command **175 Run an extension** on a menu (`mkmenu`); the item's data is the **name** of the extension (never a path), then arguments:

```
who
scores top 10
```

The program runs **for the caller** as menu commands 169 and 170 do (their terminal, Ctrl-C, the interpreters' limits, locked), and it can ask the BBS as a script does, with the capabilities of its entry.  It also has the commands of the session:

| command | what | capability |
|---|---|---|
| `bbs.user` | the caller: `name handle city level time_left calls ansi screen_length` | `session:read` |
| `bbs.node` | `node baud address` | `session:read` |
| `bbs.file <name>` | shows a text file of the BBS (the screens of the `txtfiles` folder, as a menu item does) | `session:control` |
| `bbs.pause` | "Press Enter" | `session:control` |
| `bbs.hangup` | ends the call | `session:control` |

A caller whose security level is under the `level` of the entry is told that it is not available to them, and so is one who picks a name that is not in `extensions.cfg` (and the log says why).  The run stops after the `timeout` of the entry (default 60 seconds of run time, not counting the time spent waiting for a
key).  Text is CP437 in a session, as for the caller's terminal (in `mk -x` it is UTF-8).  `mkcheck` looks at the menu items: the name, the entry, the program.  Every run is in the log: `Ext <name>: run for <caller>`, refusals, and what `log.write` says.

## Hooks: extensions that run when something happens

Name extensions in a `[hooks]` block of `extensions.cfg` and they run at that point of a call, in the order written:

```
[hooks]
logon   = greeter tally       after a caller has logged on, before the first menu
logoff  = tally               at the end of the call (the caller is usually gone)
newuser = onboarding          after a new user registered
upload  = scan                after a file was accepted
newmsg  = notify              after a message was posted
menu    = banner              when a menu is entered (generic: every menu)
menu.main = ad                when the menu "main" is entered
```

A hook is an ordinary extension: the entry gives its program, capabilities, level and timeout, and it runs for the caller (the same terminal, the commands of the session).  What happens is its **arguments**, as for any program (`arg n`, `ParamStr(n)`):

| event | arg 1 | arg 2 | arg 3 | arg 4 | arg 5 |
|---|---|---|---|---|---|
| `logon` | `logon` | the user | level | node | times called |
| `logoff` | `logoff` | the user | why the call ended (the code of `mk`'s offline reason) | node | |
| `newuser` | `newuser` | the user | level | node | |
| `upload` | `upload` | the user | file area | file name (as stored) | size in bytes |
| `newmsg` | `newmsg` | the user | message area | message number | |
| `menu` | `menu` | the user | menu name | | |

(`arg 0` is the name of the extension.)  A hook **never stops the caller**: one whose entry has a higher `level` than the caller is skipped without a word; one whose program is not there, or that fails, or that takes longer than its `timeout`, is skipped and the log says
so (`Ext <name>: ...`); an error is not followed by "Press Enter".  What a hook prints is seen by the caller (a greeting is the usual use), so a hook that must be silent prints nothing.  A hook that calls `bbs.hangup` ends the call and the hooks after it do not run.
Hooks do not run hooks.  `mkcheck` reads the block: an unknown event, an extension that is not defined.

## Scripts from the listener's events

An event of `mklisten` (`mkconfig` > Events) whose action is a command can run a script: `/usr/bin/mk -x scripts/nightly.bas`.  The listener gives the command its run directory (`MKLISTENRUN`), so the script is on the node list and sees who is on line.

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
| `msgs:post` | `msg.new`, `msg.line`, `msg.post`, `msg.cancel`: write a message (below) |
| `users:write` | `user.set` (a defined list of fields of a user's record), `bbs.set` in a session |
| `files:add` | `file.add`: put a file of the script into a file area |
| `node:send`, `node:kick`, `node:time` | `node.send` a message to a node (0 = every node); `node.kick` hang up a node; `node.time` give or take minutes of a node; `bbs.addtime` in a session |
| `chat:say`, `chat:moderate` | `chat.say`; `chat.mute`, `chat.unmute`, `chat.kick` |
| `session:read`, `session:control` | the commands of a caller's session, in the BBS only (above); `mk -x` has no caller |

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

## Writes

A script that is in no entry gets the read capabilities only: **writes must be given** (`-C "msgs:post"`, or the `caps` of its entry).  A write goes through the code the BBS uses itself (the message base objects with their locks, the user file object, the node's own socket), is written in the log (`Ext <name>: posted message 12 in area 3 ...`) and
can be tried first with **`mk -x -n`**, a dry run in which nothing is changed and the log says `dry run: would ...`.

| command | what |
|---|---|
| `msg.new <area> "<to>" "<subject>" [private] [from "<name>"]` | starts a message (a local or an echo area; netmail needs an address and is not supported yet); the sender is the sysop (in `mk -x`) or the caller (in a session) unless `from` says otherwise |
| `msg.line <text>` | adds a line (at most 200 lines of 250 characters) |
| `msg.post` | writes it: the answer has the `number` the base gave it; an echo area gets the tear line and the origin as when a caller posts |
| `msg.cancel` | drops the message that was started |
| `file.add <area> <file> [description]` | copies a file **from the script's own folder** (a name, no path) into the folder of the file area under a safe name and lists it in `files.bbs`; a name that is there is refused |
| `user.set <number or "name"> <field> <value>` | `level`, `flags` (the number), `flagon` / `flagoff` (flag 1..32), `city`, `elapsed` (minutes used today), `credit` (netmail credit).  **Never the password.**  A user who is on line is refused (the change would be lost when the call ends); in a session the caller changes with `bbs.set <field> <value>` |
| `node.send <node> <text>` | a message to the caller of a node, shown at the next key wait; node 0 is every node |
| `node.kick <node>`, `node.time <node> <minutes>` | hang up a node, add or take minutes (1..255); the answer has the node's `reply`.  Not the node the program runs on (in a session: `bbs.hangup`, `bbs.addtime`) |
| `chat.say <text>`, `chat.mute <node> [minutes]`, `chat.unmute <node>`, `chat.kick <node>` | the sysop's side of the chat room (`CHAT.md`) |

```
10 Q$ = CHR$(34)
20 X = VAL(HOST$("msg.new 1 " + Q$ + "All" + Q$ + " " + Q$ + "Nightly report" + Q$))
30 X = VAL(HOST$("msg.line 12 calls today"))
40 N = VAL(HOST$("msg.post"))
50 PRINT "posted as message "; HOST$("field 1 number")
```

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

`HOST$("help")` lists every command (one line each) and `HOST$("host.list")` the **providers**.  The protocol above (`line`, `field`, `meta`, `=`, `arg`, `help`) is not the BBS's own: it belongs to the registry of host commands, `../mkhostreg-fpc` (`HostReg.pas`), that
`mkbasic` and `mkpascal` share.  The BBS is the registry's default provider; a program that embeds an interpreter can add providers under their own prefix (`Term.Hosts.Add('weather', ...)`), and a script then calls `weather.now` the same way and reads the answer with the same `line` and `field`.

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
