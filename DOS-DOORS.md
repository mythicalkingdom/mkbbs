# DOS doors on Linux (dosemu2)

Menu command 7 runs a program for the caller and gives it the drop files (`DORINFO1.DEF`, and `DOOR.SYS` / `CALLINFO.BBS` with `*D` / `*W` in the data).  **Every node has a directory of its own for this:** `node<N>` below the BBS directory (made when it is first needed; the sample BBS has `node1` and `node2` from its DOS days): MK writes the drop files and `EXITINFO.BBS` there and runs the program there, so two callers never share a drop file, and what a program writes without a path is that node's.  A **DOS door** needs a DOS to
run in: `tools/mkdosdoor` starts it in **dosemu2** with the door's COM port connected to the terminal that MK gives the program (a pseudo terminal;
MK passes what the caller types to it and what the door sends back to the caller, with the telnet handling, the time and idle limits and the
hang-up as for any program).  No other part of MK is involved.

```
door  <-- COM1 (FOSSIL, INT 14h or the UART) -->  dosemu2  <-- standard input / output = the pseudo terminal -->  MK  <--> the caller
```

## Set up

1. Install dosemu2 (`dosemu`).  Check by hand that a door of yours runs in it (a FOSSIL driver such as X00 or BNU, loaded in the batch file the door
   is started with, if the door wants a FOSSIL).
2. Put the door in a directory of its own, e.g. `/bbs/doors/lord/`.
3. A menu item of command 7 (`mkmenu`), the data:

   ```
   /usr/local/bin/mkdosdoor -n *N -d /bbs/doors/lord -- LORD.EXE
   ```

   `*N` is the node; put `*D` before the `--` when the door wants `DOOR.SYS` (MK takes it out of the command line).  The command after `--` is DOS's, as you would type it in the door's directory (`BNU /L0:... & LORD.EXE` does not work: a
   batch file of the door that does what is needed is better: `-- START.BAT`).

`make install` puts `mkdosdoor` in the bin directory next to the other programs.

## What it does

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

`tests/dosdoortest.py` makes a small door (a `.COM`, INT 14h on COM1: it sends the first line of `DOOR.SYS`, says hello, waits for a character and
answers) and runs the tool on a pseudo terminal: the characters go both ways, the drop files have the right COM port, nodes do not meet, `-w` and `-k`,
the wrong calls, and the hang-up (the program is stopped, no dosemu2 is left).  It is skipped when dosemu2 is not there.
