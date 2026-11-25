# DOS doors on Linux (dosemu2)

Menu command 7 runs a program for the caller and gives it the drop files (`DORINFO1.DEF`, and `DOOR.SYS` / `CALLINFO.BBS` with `*D` / `*W` in the data).  **Every node has a directory of its own for this:** `node<N>` below the BBS directory (made when it is first needed; the sample BBS has `node1` and `node2` from its DOS days): MK writes the drop files and `EXITINFO.BBS` there and runs the program there, so two callers never share a drop file, and what a program writes without a path is that node's.  A **DOS door** needs a DOS to
run in: **menu command 172** (a door of `doors.cfg`) starts it in **dosemu2** with the door's COM port connected to the terminal that MK gives the program (a pseudo terminal;
MK passes what the caller types to it and what the door sends back to the caller, with the telnet handling, the time and idle limits and the
hang-up as for any program).  The door is named in the menu item and described in `doors.cfg`, so the 75 characters of the menu data are enough, `mkcheck` can look at it, and
everything is done inside `mk`: **no script is needed** (`tools/mkdosdoor` is the old way, below).  Command 7 still runs any program; the same command 172 also runs native Linux doors.

```
door  <-- COM1 (FOSSIL, INT 14h or the UART) -->  dosemu2  <-- standard input / output = the pseudo terminal -->  MK  <--> the caller
```

## Set up (command 172 and doors.cfg)

1. Install dosemu2 (`dosemu`).  Check by hand that a door of yours runs in it (a FOSSIL driver such as X00 or BNU, loaded in the batch file the door
   is started with, if the door wants a FOSSIL).
2. Put the door in a directory of its own, e.g. `/bbs/doors/lord/`.
3. Describe it in **`doors.cfg`** in the BBS directory (a text file; it is read at every call, so an edit is live at once):

   ```
   [global]                          # optional
   dosemu = /usr/bin/dosemu          # default: dosemu on the PATH (the environment MKDOS_DOSEMU says the same)
   tmp    = /var/tmp/mkdosdoor       # where the work directories are made (default /tmp/mkdosdoor-<uid>; MKDOS_TMP)

   [lord]
   type      = dos                   # dos (dosemu2) | native (a Linux program, run as command 7 does)
   dir       = /bbs/doors/lord       # the door's directory
   command   = START.BAT             # what is run there, DOS style; *N is the node, ** a star
   subdir    =                       # dos: run in this directory below dir
   com       = 1                     # dos: the COM port number the door is told (1 to 9)
   dropfiles = dorinfo1.def door.sys # which drop files: dorinfo1.def door.sys callinfo.bbs (default: dorinfo1.def door.sys)
   freeze    = no                    # yes: the time of the caller does not run while the door does
   sandbox   = default               # default | off | net: read, not used yet (DOORS-PLAN.md C)
   bind      = /bbs/doors/scores     # more directories for the sandbox (any number of lines): read, not used yet
   robind    = /bbs/files
   ```

   A `#` after a space starts a comment.  A door that runs a Linux program has `type = native`: its `command` is looked for in `dir` first, then as command 7 does; `door.sys`, `callinfo.bbs` and `freeze` in
   its block become `*D`, `*W` and `*!` of command 7.
4. A menu item (`mkmenu`) of **type 172, "Run a door (doors.cfg)"** (in the group External & Misc); its data is the name of the door: `lord`.
5. `mkcheck` looks at every such item: the door is in `doors.cfg`, its directory and command are there (DOS names in any case), dosemu2 is installed, and lines of `doors.cfg` it does not understand are reported with their number.

A door that cannot be started (not in `doors.cfg`, no directory, no dosemu2) is **not available**: the caller is told so, and the reason is in the log (`Door lord not run: ...`).

## What command 172 does for a DOS door

* A **work directory** for the call, `<tmp>/node<N>`, made new every time and deleted at the end (and when the caller drops the line; directories left by a call that ended badly are removed after a day).  The files
  of the door directory are **linked** into it (the files the door changes and that were there are the shared ones, as scores should be; what the door
  makes is new for this call), and it is the directory the door runs in (`C:`: dosemu2 is started on it).
* The **drop files** are written in the directory of the node as for command 7, and copied into the work directory with the COM port line changed to the door's `com`: the first
  line of `DOOR.SYS` (`COM2:`), the fourth of `DORINFO1.DEF` (`COM2`); the line ends are CR LF.  Only the files named in `dropfiles` are there.
* A batch file `mkdoor.bat` (`cd` into `subdir`, then the command) is run by `dosemu -dumb -quiet -K <work> -I 'serial { virtual com <N> }' -E mkdoor.bat` on the pseudo terminal.

## The old way: `tools/mkdosdoor`

The script does the same from a menu item of command 7 (data `/usr/local/bin/mkdosdoor -n *N -d /bbs/doors/lord -- LORD.EXE`; `*D` before the `--` for `DOOR.SYS`), with the 75 characters of the
menu data as its limit.  It stays for this release and is removed after it; use command 172 for new doors.  What the script does and its options:

`mkdosdoor [-n node] [-d doordir] [-w subdir] [-c comport] [-t dosemu] [-k] [--] DOSCOMMAND [arguments]`

* A **work directory** for the call, `/tmp/mkdosdoor-<uid>/node<N>` (`MKDOS_TMP` changes the place), made new every time and deleted at the end.  The files
  of the door directory are **linked** into it (the files the door changes and that were there are the shared ones, as scores should be; what the door
  makes is new for this call), and it is the directory the door runs in (`C:`: dosemu2 is started on it).
* The **drop files** that MK wrote in the node's directory (the current directory of the tool) are copied there, with the COM port line changed to the number of `-c` (default 1): the first
  line of `DOOR.SYS`, the fourth of `DORINFO1.DEF`; the line ends are CR LF.
* A batch file `mkdoor.bat` (`cd` into `-w`, then the command) is run by `dosemu -dumb -quiet -K <work> -I 'serial { virtual com <N> }' -E mkdoor.bat`.
* When the caller drops the line (SIGHUP) or MK stops the program, dosemu2 is stopped and the work directory goes.  Exit status: that of dosemu2; 2 a wrong
  call; 3 dosemu2 is not installed.  `-k` keeps the work directory (to look at what the door was given).

## Limits, and what to watch

* **The directory of the node** (`node<N>`) is the current directory of the program, so a relative path in the arguments of the menu item (`games/data`) is no
  longer relative to the BBS directory; the program itself is found as before (BBS directory first, then the path) and made a full path.  `mkqwk`, run from a menu,
  finds its `config.mko` in the directory of the node, or in the directory `MK` names.  Another work directory of a call is a place for what the node's programs keep.
* dosemu2 is **not a sandbox**: a door runs with the rights of the BBS user and can read what that user can.  Run the BBS as a user of its own.
* A door that wants **a real UART** (its own interrupt handler, not a FOSSIL or INT 14h) usually works on the emulated 16550 of dosemu2, but test each.
* File names: DOS sees the names as they are in the door directory; keep them upper or lower case consistently (dosemu2 matches without case).
* The first start of a call takes a second or two.

## Tests

`tests/doortest.py` (command 172 with a fake dosemu and a native door), `tests/dosdoorcmdtest.py` (command 172 through telnet with the real dosemu2: COM1, drop files, work directories, hang-up) and `tests/dosdoortest.py` (the old script) are in `build.sh`.  `tests/dosdoortest.py` makes a small door (a `.COM`, INT 14h on COM1: it sends the first line of `DOOR.SYS`, says hello, waits for a character and
answers) and runs the tool on a pseudo terminal: the characters go both ways, the drop files have the right COM port, nodes do not meet, `-w` and `-k`,
the wrong calls, and the hang-up (the program is stopped, no dosemu2 is left).  It is skipped when dosemu2 is not there.
