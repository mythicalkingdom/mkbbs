# Multi-node chat

Callers on different nodes can talk to each other in one room.  **It is off.**  A BBS that never turned it on has no chat room: the menu command says it is not available and nothing in the BBS reads or writes a chat file.  Chat is a place where callers can
write to each other without you reading it first, so it comes with the controls below; every line is logged, you can watch the room, and you can mute, remove or ban a caller at any time.

## Turning it on

1. `mkconfig` → **Chat**: set **Chat is on** and look at the rest (below).  The settings are in `chat.mk` (and in the `"chat"` object of `bbsconfig.json` when you keep the configuration as JSON).
2. Put the command **174 Multi-node chat** on a menu (`mkmenu`; the data is not used).  A menu with the item and chat off tells the caller "Multi-node chat is not available" (`mkcheck` warns about it).
3. `mkcheck` says whether chat is on and what it found: the log folder, the word file, a lowest level of 0.

Chat needs the listener (`mklisten`): the room is kept in the run directory, which only the listener's nodes share.  A caller who runs `mk` by hand has no room.

## The settings (mkconfig → Chat)

| setting | default | |
|---|---|---|
| Chat is on | **off** | the switch |
| Room name | Chat | what the callers see |
| Lowest level | 0 | the lowest security level that may join; raise it to keep new users out until you have looked at them |
| Line length | 160 | longer lines are cut |
| History lines | 10 | lines a caller sees when joining |
| Minutes per call | 0 | the most a caller may spend in the room each call (0: no limit) |
| Flood: lines / seconds / mute minutes | 5 / 10 / 2 | more lines than that in that time and the caller is muted for that long (0 lines: no limit) |
| Word file | none | a text file, one word or phrase on each line (`#` starts a comment); matched without regard to case |
| Word action | mask | mask the word with `*`, or refuse the whole line |
| Private /msg | on | private lines between callers (they are logged like the rest) |
| Show handles | on | a user's handle is shown instead of the name |
| Log every line | on | `chat.log` |

**What a caller can do:** type a line (it goes to the room), `/who`, `/msg N text` (a private line to node N or to a name), `/me text`, `/ignore N|name`, `/help`, `/quit`.  Control characters and escape sequences are removed from what is typed, so nobody can send
colours, screen clears or other terminal tricks to another caller; Esc does not leave the room, arrow keys do nothing.

## The log

`chat.log` is in the folder of the BBS log: the time, the node, the name and the text, **private lines too** (`n2 Ann -> n5 (private): ...`), joins and leaves, and what was done to a caller (muted, removed).  It is the evidence if a caller complains, so keep it; `logrotate` it like the BBS log.
Callers are not told that private lines are logged unless you say so in your rules: do.

## What you can do while it runs

**`mkmon`** (the sysop monitor): the key **H** shows the room live, private lines included, and who is in it.

| key | |
|---|---|
| Up / Down | choose a caller |
| M / U | mute (5 minutes) / let speak again |
| K | remove from the room (they may come back) |
| B | ban: remove, and put the name on `chatban.lst` |
| T | say a line in the room (shown as `[sysop] text`) |
| N | a notice in the room (`*** text`) |
| A | **a message to every node**, in the room or not: the callers see it at their next key wait |

**`mkchatctl`** does the same from a shell or a script: `mkchatctl who | log [N] | say text | notice text | announce text | mute node [minutes] | unmute node | kick node | ban node | unban name | bans`.  It finds the run directory in `MKRUN` (or `-r`) and the BBS directory in `MK` (or `-c`);
under systemd that is `mkchatctl -r /run/mkbbs -c /etc/mkbbs/bbs`.

`chatban.lst` (in the BBS directory) holds one name per line (`#` comments); a name there, in any case, cannot join.  Delete the line, or `mkchatctl unban`, to let the person back.

The message to every node does not need chat to be on: it is also the way to say "the BBS closes in ten minutes" to callers who are at the menus.  (For a closing time, an exclusive event does that by itself; see `MKLISTEN.md`.)

## How it works (for the curious)

The room is the directory `chat/` of the run directory: `room.log` (every event, one line each, written in one call so lines of different nodes never mix), one `in<N>` file for each node in the room, `ctl` for what the sysop tells a node.  Each node reads what is new while it waits for the
caller's next key; nothing is pushed into a caller's screen.  When nobody is in the room, an old `room.log` over 64 KB is started again at the next join (`chat.log` has the history).  Messages to every node are lines in `sysopmsg.log` of the run directory.  Design notes: `MCHAT-PLAN.md`.
