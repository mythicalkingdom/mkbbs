# BBS objects for mkbasic and mkpascal: extensions, hooks and `mk -x` (plan, 2026-11-26)

The sysop can write programs in BASIC or Pascal that use the BBS itself: read users, message areas, file areas, the node list, and (in a later phase) write.  The model is Synchronet's `jsexec`: one object model, used inside
the BBS (with a caller on the other end) and outside it (with nobody).  **This is not the door command** (`172`, `7`): a door is a program that runs on the caller's terminal and knows nothing of the BBS; an extension is a program of the sysop that is *given* the BBS, piece by piece, by name.

## Decisions (2026-11-26, the user's answers)

1. **Sysop only.**  Extensions are the sysop's programs; nothing a caller uploads is ever an extension.
2. **Read first, write later** (phase 1 reads; writes are phase 4 and are wanted).
3. **Hooks are part of it** (a program that runs at a logon, a logoff, an upload, a new message ...).
4. **The external runner is `mk -x <script>`**: the real `mk` with no caller.  One program, one code path, nothing duplicated; the start-up time of `mk` does not matter for programs that run from an event or a shell.
5. **A script that runs unchanged in both places is nice, not required**: the session objects simply are not there outside the BBS (a call to one is a run-time error with a clear message).
6. **`mk -x` is a script node:** it has a node number, a node file and a line in `useron.bbs`, so it shows on the node list and in `mkmon` (the activity is the script's name).  It takes a number from a range kept for scripts (a setting, default after the caller nodes) so a script never uses a caller's node; when the range is full the script is refused with a message.
7. **Hook arguments are like command-line arguments:** the event's data comes as the program's parameters (`ParamStr` / `COMMAND$`-style), for example a logon hook gets the user number, the name and the node; the same words are in `mk -x script args` for a script started by hand.

## The shape

```
 BASIC program ----.                       .---- a caller's session (menu command, hook)  : session objects present
                   +--> HOST dispatcher ---+
 Pascal program ---'     (MKHost.pas)      '---- mk -x, no caller (events, shell, cron)  : session objects absent
```

* **One contract: a command name and arguments in, text out.**  `MKHost.pas` is the only place that knows what the BBS has.  `user.get 12`, `msg.areas`, `msg.list 3 100`, `file.list 2`, `node.who`, `system.info` ...  The text is plain: a scalar is one value; a
  list is one record per line, fields separated by TAB, the first line the field names (so a program finds a field by name and a new field never breaks an old program).  (Plain text is much easier for BASIC than JSON; the wrappers hide the format, so it can change.)
* **The interpreters stay BBS-agnostic.**  Each gets **one generic hook** and nothing else: `HOST$(cmd$)` in mkbasic (a function), `HostCall(cmd: string): string` in mkpascal (a predeclared function); the host sets a callback, with none set the call is an error.  The pretty names
  (`MsgAreas`, `UserName(n)` ... ) are wrappers over the hook: for Pascal a unit `mkbbs` written in Pascal and compiled in with the interpreter; for BASIC a small set of `DEF FN` lines the sysop can paste, or built-in helper functions (`HFIELD$(rec$, "name")`).
  This means two small changes in the other repositories (`../mkbasic-fpc`, `../mkpascal-fpc`), each buildable on its own as now.
* **Permission by capability**, as the API's token scopes: an extension is entered in `extensions.cfg` (plain text, like `uploads.cfg` and `doors.cfg`) with the capabilities it is given (`users:read`, `msgs:read`, `files:read`, `nodes:read`, `chat:read`; later `msgs:post`, `users:write`, `files:add`, `node:send`, `node:kick`,
  `node:time`, `chat:say`).  The dispatcher refuses a call outside the list, and the refusal is logged.  A program in `mk -x` runs with the capabilities of its own entry (or `-C list` on the command line, the sysop's own hand).
* **The interpreters are already locked down** (no files but the program's folder, no shell), so the capabilities are the whole story: no OS sandbox is needed for the in-process run, and the limits (run time, memory, output) are the ones the interpreters have plus a wall-clock limit per run.
* **Writes go through the code `mk` uses** (the message base objects with their locks, the user object, the spool files of the chat and the nodes), never raw file edits, and every write is a log line (`Ext: name post msg area 3 as "Ann"`).

## The objects (phase 1 reads; the Synchronet name where there is one)

| object | what | phase |
|---|---|---|
| `system` | BBS name, sysop, version, time, node count, totals, the run directory, statistics (calls today) | 1 |
| `user` (by number or name) | the user file record without the password: name, handle, city, level, flags, calls, uploads, downloads, times, last call | 1 |
| `msg_area` / message base | the areas; headers and text of an area (the public ones; private only with `msgs:private`); counts, the last-read pointer of a user | 1 |
| `file_area` | the areas; the files of an area with their descriptions and sizes | 1 |
| `node` | who is on line: node, user, what they do, since; (later: send, kick, add time) | 1 / 4 |
| `chat` | who is in the room, the last lines (later: say) | 1 / 4 |
| `config` | read-only values the program may need (paths of areas, the BBS directory), no secrets | 1 |
| `bbs` (session only) | the current caller: print is the terminal already; `bbs.user`, `bbs.node`, `bbs.menu`, show a text file, page the sysop, ask Y/N, hang up | 2 |
| `log` | write a line to the BBS log | 1 |
| `fs` | file I/O in the extension's own folder (the interpreters have it) | 1 |

**Status:** phase 1 is built: `MKHost.pas` (the dispatcher: a command stores its answer and returns the number of lines; `line`, `field`, `meta`, `=` read it, because both languages keep strings to 255 characters), `MKExtCfg.pas` (`extensions.cfg`), `MKScript.pas` (`mk -x`, the script node), `HOST$` in mkbasic (token `$FFA7`, `TBasicTerm.HostCall`) and `HostCall` in mkpascal (`TMKTerm.HostCall`, run-time error 300), the wrappers in `ext/`, `mkcheck`, `EXTENSIONS.md`, `tests/hosttest.py`.  The commands are in `EXTENSIONS.md`.  **The registry (2026-11-26):** the protocol and the answer store moved into a shared unit, `HostReg.pas` of the project `../mkhostreg-fpc` (providers with prefixes, a default provider, tables and text, `line` / `field` / `meta` / `=` / `arg` / `help` / `host.list`); `TBasicTerm.Hosts` and `TMKTerm.Hosts` give each interpreter's terminal one, so other programs and units can add commands without subclassing; `MKHost` is its default provider.  **Phase 2 is built:** menu command 175 (`MKExtRun.pas`: the data is a name in `extensions.cfg` and arguments; level, timeout, capabilities; `MKBasicRun` / `MKPascalRun` run the program for the caller with the host registry; the session commands `bbs.user`, `bbs.node`, `bbs.file`, `bbs.pause`, `bbs.hangup`; CP437 at the boundary), `mkcheck` for the items, `tests/exttest.py` over telnet.  **Phase 3 is built:** hooks (`[hooks]` in `extensions.cfg`: logon, logoff, newuser, upload, newmsg, menu and menu.<name>; `RunHooks` in `MKExtRun`, called from `MK.pas`, `MKLogOn`, `MKUpload`, `MKEnter`, `MKCmd`; the event data as arguments; level, timeout and capabilities of the entry; a failing or slow hook is logged and skipped), `mklisten` events that run `mk -x` (`MKLISTENRUN`, `mk -x -R`), `mkcheck` for the block, tests in `exttest.py`, `uploadtest.py` and `eventlistentest.py`.  The newuser and newmsg hooks are in the code but have no test of their own (both need a long dialog over telnet).

**Phase 4 is built:** the writes (`MKHostW.pas`; `MKHost`: `msg.new` / `msg.line` / `msg.post` / `msg.cancel`, `file.add`, `user.set` (never the password, never a user on line), `node.send` (per-node messages in `sysopmsg.log`), `node.kick`, `node.time`, `chat.say` / `mute` / `unmute` / `kick`; in a session `bbs.set` and `bbs.addtime`), the capabilities `msgs:post users:write files:add node:send node:kick node:time chat:say chat:moderate` (a script that is in no entry does not get them), `mk -x -n` dry run, a log line for every change; `MKFileList` is the part of `MKUpload` that both use.  Not in: netmail posting (needs an address), deleting, a user's password.

## Phases

1. **The host and `mk -x`:** `MKHost.pas` (the dispatcher, the capabilities, the read objects above), the hook in each interpreter (small commits in the two other repositories), `mk -x script.bas | script.pas [-C caps] [args]` (the kind by the extension; a mode of `mk` with no comm session, no node
   file, no `useron.bbs` entry, no user; output to standard output, input from standard input), `extensions.cfg` read by it, the log line of every run and refusal, `EXTENSIONS.md`, `mkcheck` (the entries, the files, the capabilities), tests (a BASIC and a Pascal program for each object, a refused capability, a run-time limit).
   Risk to look at first: how much of `mk`'s start-up assumes a caller (the local session `mk -L` suggests a null session is simple).
2. **Extensions inside the BBS:** the session objects, a new menu command (`175 Run an extension`; the data is the **name** in `extensions.cfg`, never a path, with a minimum level and the capabilities of the entry), the caller's terminal as in commands 169 / 170, the run limits (time, idle, carrier lost end it quietly),
   `mkcheck` for menu items, tests over telnet.
3. **Hooks:** entries `[hook logon]`, `logoff`, `upload` (after an accepted file), `newmsg` (after a post), `menu <name>` (when a menu is entered), `newuser`, run at that point inside `mk` with a time limit and the same capabilities; a hook that fails or is too slow is logged and skipped, it never stops the caller; the hook gets the
   event's data (the user, the file, the message) as its arguments.  The upload hook is the natural second home of what `uploads.cfg` does with external programs.  Also: `mklisten`'s events can run a script (`mk -x`) as an action.
4. **Writes:** `msgs:post`, `users:write` (a defined set of fields: level, flags, time bank; never the password), `files:add`, `node:send` / `node:kick` / `node:time` (the snoop commands and the spool files that `mkchatctl` uses), `chat:say`; `mk -x -n` dry run (writes are only logged); tests with a private copy of the sample BBS and the fixture check.

## Open

* The text format of results (plain TAB lists, as above, or JSON).
* The range of script node numbers: **done** (`"scriptnodes"` in `mklisten.json`, checked against the nodes of the ports, handed to `mk` as `MKSCRIPTNODES`).
* (Decided 2026-11-26: the results are plain tab-separated lines.)
