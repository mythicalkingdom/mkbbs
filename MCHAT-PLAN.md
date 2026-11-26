# Multi-node chat (plan, 2026-11-25)

Callers on different nodes can talk to each other in one room.  **It is off unless the sysop turns it on**: a BBS that never opens `Multi-node chat` in `mkconfig` has no chat room, the menu command (174) says it is not available, and nothing in the
BBS reads or writes a chat file.  Moderation is the reason for the care: every line is logged with the user and the node, the sysop can watch the room live and mute or remove a caller, and the abuse controls are settings, not code.

## Decisions (2026-11-25, the user's answers)

1. **The settings are part of the BBS configuration**: a new record file `chat.mk` (like `events.mk` and `fileecho.mk`: one fixed record, optional, defaults when it is missing) and a `"chat"` object in `bbsconfig.json`; edited in `mkconfig`.  `Enabled` is **off** in the defaults.
2. **Scope of the first version:** one room, `/who`, `/msg` (private line to a node or user), `/ignore`, `/me`, `/help`, `/quit`, and a **message from the sysop to every node** (`mkmon`).  No channels.
3. **Moderation by default:** everything logged, the sysop can watch the room and kick / mute from `mkmon`; the flood limit and the word filter exist and are settings (the flood limit is on once chat is on, the word filter only when a file is named).

## The settings (`ChatCfgType`, `chat.mk`)

| setting | default | meaning |
|---|---|---|
| `Enabled` | **off** | the switch |
| `MinLevel` | 0 | the lowest security level that may join (new users are at the level the sysop gave them: raise this to keep them out) |
| `RoomName` | `Chat` | shown to the callers |
| `MaxLine` | 160 | characters in a line; longer is cut |
| `FloodLines` / `FloodSecs` / `MuteMinutes` | 5 / 10 / 2 | more lines than that in that time: the caller is muted for that long (0 lines: no limit) |
| `History` | 10 | lines of the room a caller sees when joining |
| `Private` | on | `/msg` allowed |
| `ShowHandle` | on | the handle is shown instead of the name when the user has one |
| `WordFile` | none | a text file with a word (or phrase) on each line; `WordAction`: mask it with `*` or refuse the line |
| `LogChat` | on | `chat.log` in the log directory: time, node, user, text; private lines too (the sysop's rule: the log is the evidence) |
| `MaxMinutes` | 0 | minutes a caller may spend in the room each call (0: no limit) |

A banned list (`chatban.lst`, one user name each) is kept by `mkmon` (the sysop's "remove from chat" makes the entry); a banned caller is told the room is closed to them.

## How it works

* The room is a **spool directory** in the run directory (`chat/`): `room.log` is append-only, one line per event (`seq`, time, node, user, kind, text; written in one `write` with `O_APPEND`, so lines of several nodes do not mix).  Every node in the room remembers the file offset it has read up to and reads what is new while it waits for the caller's next key.  Presence is a file per node (`chat/in<N>`: user, since, pid; stale ones are found by the pid).  Nothing is pushed into the screen of a caller who is not in the room.
* Menu command **174 Multi-node chat** (data: none) runs the room for the caller (`MKChat.pas`): header, the last `History` lines, then a line editor that prints incoming lines above the line being typed.  A caller leaves with `/quit` or Esc; hanging up leaves it.
* The **sysop's message to all nodes** (`mkmon`: a key on the node list): sent to each node's snoop socket as a new frame and shown to the caller at the next safe point (the prompt), whatever they are doing; it does not need chat to be on for the callers, but is off with the rest when `Enabled` is off ("a message from the sysop" is also the way the sysop warns the room).
* **Moderation (`mkmon`):** a screen with the room live (and the sysop can type into it: lines marked as from the sysop), `M node` mute for minutes, `K node` remove from the room, `B` ban (writes `chatban.lst`).  Commands go to the nodes through a file `chat/ctl` that every node reads together with the room.
* **`mkcheck`** says whether chat is on, and when it is: the log file writable, the word file there, `chatban.lst` readable.

**Status:** phase 1 is built: `ChatCfgType` (`MKGlobT`, 139 bytes), `chat.mk` in `MKCfgMK` and `MKRCfgMK` (read by `mk`), the `"chat"` object in `MKCfgJs` (generator run), the copies in `MKCfgCvt` / `CCvt`, `mkconfig` > Chat (`CfgChat.pas`), `mkcheck` (off / on, log folder, word file, level 0), tests in `jsoncfgtest`, `cvttest`, `checktest`.  

**Phase 2 is built:** `MKChatCore.pas` (the room: `chat/room.log` and `chat/in<N>` in the run directory, flood limit, word filter, ban list, `chat.log`) and `MKChat.pas` (the caller's side: line editor, `/who /msg /me /ignore /help /quit`, history, escape sequences swallowed, Esc does not leave), menu command 174 (`MKCmd`, `MKMENU.TXT`, prompts 558-583), `mkcheck` for a chat item with chat off, `tests/mchattest.py` (two telnet nodes) in `build.sh`.  

**Phase 3 is built:** the sysop's side.  Everything goes through files, so a node takes it up when it next looks: `chat/ctl` (mute / unmute / kick for a node), `X` and `N` lines in `room.log` (a line of the sysop, a notice), `sysopmsg.log` of the run directory (a message to every node: `MKDoor` shows it at the next `InputChr`, the room shows it as a line; it works with chat off), `chatban.lst`.  `mkchatctl` (who, log, say, notice, announce, mute, unmute, kick, ban, unban, bans) and the chat screen of `mkmon` (key H: the room live with private lines, who is in; M U K B T N A) use the same functions (`MKChatCore`).  The presence file has the real name as a fourth line (a ban is by the real name and the handle).  `CHAT.md`, README, `tests/mchattest.py` (the sysop part, over telnet with a sysop port).

## Phases

1. **The settings:** `ChatCfgType` (`MKGlobT`), `chat.mk` and the JSON object in `MKCfgMK` / `MKCfgJs` (generator, copy in `MKCfgCvt`, `CCvt`), `GetChat` / `SetChat` / `HasChat`, the `mkconfig` screen, `mkcheck`, tests (`jsoncfgtest`, defaults off).
2. **The room:** `MKChat.pas` (spool, presence, line editor, commands, flood, filter, log), menu command 174 and its prompts, `mchattest.py` with two nodes over telnet.
3. **The sysop:** the broadcast, the moderation screen of `mkmon`, `chatban.lst`, `CHAT.md`, README, MKBBS, `build.sh`.
