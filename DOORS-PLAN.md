# Doors: a DOS door command in `mk`, `DOOR32.SYS`, and a door sandbox (plan, 2026-11-25)

Three pieces of one subject, in the order they depend on each other: **A** a menu command that runs DOS doors without `tools/mkdosdoor`, **B** `DOOR32.SYS` for
native doors, **C** a sandbox for every door.  Today (`DOS-DOORS.md`, `src/MKShell.pas` `TypeSeven`) command 7 runs any program on a pseudo terminal in `node<N>` and writes
`DORINFO1.DEF`, `DOOR.SYS` (`*D`) and `CALLINFO.BBS` (`*W`); a DOS door goes through the shell script `tools/mkdosdoor` (dosemu2, a work directory of links, drop files copied with the COM port
line changed, `mkdoor.bat`), and the whole call has to fit the 75 characters of the menu data field.

## A. The DOS door command

**A new menu command** (the next free number; `mkmenu` and `mkcheck` learn it): the data field is a **door name**, e.g. `lord`.  Everything else comes from a door file.

**The door file**, `doors.cfg` in the BBS directory (plain text, `[name]` blocks, like `mkbink.conf`; not in `config.mk`, so there is no `MKCfgMK` / `MKCfgJs` pair to keep in step):

```
[lord]
type      = dos                 # dos (dosemu2) | native (a Linux program, as command 7)
dir       = /bbs/doors/lord     # the door's directory (DOS doors: linked into the work directory of the call)
command   = START.BAT           # what is run there (DOS style for dos); *N *D etc. as in command 7
subdir    =                     # run in this directory below dir (-w of mkdosdoor)
com       = 1                   # the COM port the door is told (default 1)
dropfiles = door.sys dorinfo1.def callinfo.bbs door32.sys   # which drop files; default: dorinfo1.def door.sys
freeze    = no                  # time does not run while the door does (*!)
sandbox   = default             # see C
```

* The old `mkdosdoor` call keeps working (command 7 does not change); the new command is the way that fits in the data field, can be checked by `mkcheck` (door directory there, the command file there, dosemu2 installed, the drop files named exist as names) and
  edited in one place.  An unknown door name is told to the caller ("this door is not available") and logged.
* **In Pascal, in `mk`** (new unit `MKDosDoor.pas` called from `MKShell`): the work directory of the call (`$MKDOS_TMP` or `/tmp/mkdosdoor-<uid>/node<N>`, made new, cleaned at the end and when it is old),
  the links of the door's files (`symlink` per file; directories as directories), the drop files copied with the COM port line changed (line 1 of `DOOR.SYS`, line 4 of `DORINFO1.DEF`, CR LF), `mkdoor.bat`,
  then `dosemu -dumb -quiet -K <work> -I 'serial { virtual com N }' -E mkdoor.bat` on the pseudo terminal that command 7 already makes.  The hang-up, time and idle limits are command 7's own;
  on a hang-up `mk` stops dosemu2 itself (TERM, then KILL after 4 s, the process group), which the script did with traps.
* `tools/mkdosdoor` stays one release as it is (documented as "old way"), then goes; `DOS-DOORS.md` is rewritten around `doors.cfg`.
* **Not changed:** dosemu2 stays a requirement (nothing of the emulation moves into `mk`); FOSSIL drivers are loaded by the door's own batch file.

**Phases**
1. `doors.cfg` reader (`MKDoorCfg.pas`), the new command, the work directory and drop files, a fake `dosemu` (a script that records its arguments, the work directory and the drop files and echoes characters) for a test that needs no dosemu2; `mkdraw`/`mkmenu` entry, `mkcheck` rules.
2. The real dosemu2 test (`tests/dosdoortest.py` extended, skipped without dosemu2): characters both ways, the COM port in the drop files, two nodes do not meet, hang-up leaves no dosemu2, old work directories removed.
3. Docs (`DOS-DOORS.md`, `MKBBS.md`, mkmenu command list), `mkdosdoor` marked old.

## B. `DOOR32.SYS`

The format: eleven lines (CR LF): comm type (0 local, 1 serial, 2 telnet), **the handle**, baud rate, BBS software name and version, user record number, real name, handle (alias), security level, minutes left, emulation (0 ASCII, 1 ANSI),
node number.  It sits next to the others: `WriteDoor32` in `MKShell`, `*3` (the next free letter of command 7) or `door32.sys` in `dropfiles` of A.

**The one real question is the handle.**  A Windows door gets a socket handle; a Linux door gets a file descriptor number.  What `mk` can give:

| how the caller is connected | what to write |
|---|---|
| door run with `*S` (raw: the door gets `mk`'s standard input / output, which `mklisten` made the caller's connection) | comm type 2, handle = **the descriptor of the connection** (0; `mk` also leaves a duplicate open at a number that is told, so the door can close 0/1/2) |
| a pseudo terminal (the default of command 7) | comm type 0 (local), handle 0 (the door reads and writes its standard input / output as every terminal door does) |
| TLS, SSH, WebSocket in front of `mk` | the connection reaches `mk` as a plain stream (`mklisten`, `stunnel`, `mkbbsssh` do the encryption), so as above |

Proposed: comm type and handle follow the table, the baud rate is the caller's (38400 when unknown), the emulation is the caller's ANSI setting.  `mkcheck` and the docs tell which doors need `*S`.  Doors that really need a *socket*
(`getpeername`, `send` on it) work with `*S` when the connection is a socket, which it is behind `mklisten`; behind SSH `mk` gets a pipe or pty, so such a door does not work there -- documented, not worked around.

**Phases**: 1 `WriteDoor32` + `*3`, tests on the file (`dropfilestest`: the lines for a known user, `*S` and pty variants) and a small native test door that reads it; 2 docs, `mkcheck` knows `door32.sys` as a drop file name.

## C. The sandbox

**Goal:** a door is somebody else's program, run with the rights of the BBS user.  Run it in a restricted environment: no network, a private `/tmp`, only the node directory and the door directory visible and writable,
the rest of the system read-only or absent.

**Tool: bubblewrap (`bwrap`)**, which is installed here (0.12.0, unprivileged user namespaces are on).  `mk` runs the door as `bwrap <options> -- <door>` in place of `<door>` (so it applies to command 7, the new door command and `mkdosdoor`):

```
bwrap --die-with-parent --unshare-net --unshare-pid --unshare-ipc --unshare-uts
      --ro-bind /usr /usr  --symlink usr/bin /bin  --symlink usr/lib /lib  --symlink usr/lib64 /lib64   (/etc/passwd-less: a small /etc: localtime, terminfo)
      --proc /proc  --dev /dev  --tmpfs /tmp
      --bind <node dir> <node dir>   --bind <door dir> <door dir>  --chdir <node dir>   (+ more --bind from doors.cfg)
```

**Settings** (in `doors.cfg`, `sandbox =`): `off` (as now), `default` (the above), `net` (the same with network, for doors that call out: IRC, InterBBS), and per door `bind = <path>` / `robind = <path>` lines for what a door needs
(a shared score directory, the file areas); a BBS-wide default in `[sandbox]` at the top of the file.  Command 7 items get it through one line `sandbox = on|off` in the `[sandbox]` block (command 7 has no door name).
* **Fallback:** without `bwrap`, or when it cannot make a namespace, the door **does not run** when `sandbox` is `default` / `net` (the caller is told it is not available and the sysop's log says why), and runs as before when `off`.  `mkcheck` tells which it is.
* **dosemu2 under bwrap** is the piece to try first: it needs `/dev/shm`, its own tree under `/usr`, and the low memory mapping (`vm.mmap_min_addr`); phase 1 of C is a feasibility run with the real `dosemu`.  If it cannot be made to work, a DOS door
  still gets the other restrictions with `--unshare-net` and a private `/tmp`, and the plan says so.
* **What it does not do:** no resource limits (CPU, memory) -- `ulimit`s / `prlimit` are a small next step -- and it is not a defence against a kernel exploit; the docs say "a sandbox, not a prison".
* The caller's connection (the pseudo terminal) is passed in as standard input / output as before; `--new-session` is **not** used (it takes the controlling terminal).  Curses doors are tested.

**Phases**: 1 feasibility (`bwrap` with a native door and with dosemu2 by hand, the options that work, written down), 2 `MKSandbox.pas` (building the command line from a door's settings, a check that `bwrap` is there and works) in command 7 and the door command, tests with a
native door that tries to see the network, `/home` and a file outside (they must fail) and writes in `/tmp` (not shared between nodes), 3 `mkcheck` and docs (`DOS-DOORS.md` "Limits": the sentence "not a sandbox" is replaced).

## Order and size

C needs A's door file (settings per door) and applies to everything; B is small and independent.  Proposal: **A phase 1-3, then B, then C** (C's dosemu2 feasibility run can come first, cheap, because it can change the shape of A's launch code).

## Questions

1. **The door file**: `doors.cfg` as above (plain text beside the BBS, readable by `mkcheck`), or entries in the menu / `mkconfig` like the other settings (more work: binary record, JSON mirror, an editor screen)?  Proposal: the text file; an editor can come later.
2. **Old `mkdosdoor`**: keep it for one release, then remove?  (Proposal: yes.)
3. **Sandbox default**: `default` for the new door command (a door that needs more is told so in its block), `off` for command 7 until the sysop turns it on?  Or on everywhere?  Proposal: on for the new command, off for command 7.
4. **No `bwrap`**: refuse to run a sandboxed door (proposal), or run it unsandboxed with a log line?
5. **Network for doors**: off by default, `net` per door?  (Proposal: yes.)
6. **`DOOR32.SYS` handle**: as in the table (descriptor with `*S`, local otherwise)?
