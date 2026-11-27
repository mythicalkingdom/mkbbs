# mkconnect: a terminal program for BBSs (plan, 2026-11-26)

A dialing directory and a terminal for calling bulletin board systems over the network, in the spirit of QModem for DOS: pick a system from a list, connect, get the screens as they were drawn, send and receive files, run a login script, keep a log.  It runs in an ordinary text terminal (a Linux console, an xterm, an SSH session) and is
part of this repository like `mkdraw` and `mkcat`.

## Decisions (2026-11-26)

1. **Pass-through first.**  What the BBS sends is converted (CP437 to UTF-8, the colour guard of the BBS) and written to the user's own terminal, which does the emulation.  The program owns one row, the bottom row, for a status bar.  A built-in emulator with a screen buffer and scrollback may come later; the data path is kept apart so that it can.
2. **SSH through the system `ssh`.**  No SSH code of ours: the program runs `ssh` on a pseudo terminal and passes its bytes the same way.
3. **Scripts are `MKHubScr` scripts** (expect / send / try / when / upload / download / variables; the language of the QWK hub passes).  No BASIC or Pascal in this program.
4. **A simple text user interface like `mkedit` and `mklist`**, not Free Vision: the `Video` unit's cell buffer, a raw keyboard reader with Shift / Alt / Ctrl keys, pull-down menus on Esc, a status line, F1 for the key list.
5. **The name.**  Checked 2026-11-26: no Debian package and no command called `mkconnect` here, nothing named so on PyPI or npm.  GitHub has a few small unrelated projects with the name (`MKConnect-gui` and `Megakuul/MKConnect`, SSH tools; `mkconnect-python`, a Python library for Mould King bluetooth bricks), so a web search is noisy, but nothing that a package or a
   command can collide with.  The alternatives I looked at were no better (`mkterm`, `mkcall` and `mkphone` have more GitHub projects; `mkdial` is free but says less).

## What it is made of

| piece | from |
|---|---|
| the screen and the keys of the dialer | `uScreen` (Video cell buffer), `uKeys` (raw keyboard, modifiers, Esc timeout, bracketed paste) of `../mkedit` and `../mklist`, copied (the two projects keep their own copies already) and renamed `MKTui*` here; CP437 mapping with `MKCp437` |
| the connection | `MKComClient.ConnectTcp` (TCP and Telnet in client mode: binary, SGA, terminal type, window size, IPv6, every address of a name tried) |
| CP437 to UTF-8 and back | `MKCp437`, the colour guard `MKSgr`, the key translation of `MKKbd` (what is typed on a UTF-8 terminal is sent to the BBS as CP437) |
| file transfers | `MKProt` (Zmodem, Ymodem, Xmodem and 1K, G; `ProtKeepInput`) through the session |
| scripts | `MKHubScr` |
| the bottom status bar over live output | the scroll region way of `mkmon` |
| **new** | the phone book, the dialer screen, the call loop, a **TLS client session** (`MKTls` has the server side only; `MKFtp` and `MKHttp` already load the OpenSSL client functions) for `telnets`, the `ssh` child on a pty |

## How it works

* **The dialer** (the screen of the program): a list of systems with name, host and port, kind (telnet, telnets, raw, ssh), character set (CP437, UTF-8), script, calls and the last call.  Enter dials, A adds, E edits, D deletes, F finds, M marks several for **multi-dial** (they are tried in turn, with a pause and a count, until one answers), S sorts, Esc opens the menus, F1 the keys, Alt-X leaves.
* **A call** leaves the cell screen, puts the terminal in raw mode and runs the loop: bytes from the network go through the Telnet filter, then the character conversion, to the terminal; keys go the other way (arrow keys and F keys as the ANSI codes a BBS expects, typed text as CP437).  The window size told to the BBS is the terminal's, less the status row, and is told again when it changes.
  The status bar has the name, the time on line, the character set, a `capture` mark and the progress of a transfer.
* **Commands during a call** (QModem has them on Alt keys): an **attention key** (default `Ctrl-]`, as in telnet) opens a one line menu at the bottom; the common ones also have Alt keys (`Alt-H` hang up, `Alt-X` hang up and leave, `Alt-D` the dialer, `Alt-U` upload, `Alt-L` download, `Alt-C` capture on / off, `Alt-S` send a text file, `Alt-T` the character set).  An Alt key arrives as Esc and a letter: it counts when the two come together.
* **Transfers**: the protocol is chosen from the menu; a download that the BBS starts (the Zmodem start of the other end) is taken up **automatically**, as QModem did.  Files come into a download folder (setting, default `~/Downloads`), the progress is on the status bar, the result in the log.
* **Capture and log**: the text of a call goes to a file when capture is on (as the BBS sent it, or converted); every call is a line in a log with the time on line and the transfers.
* **Scripts**: an entry names an `MKHubScr` script, run after the connect (login name and password come from the entry as the variables `login` and `password`), or `mkconnect -s script host`.
* **The phone book** is a plain text file, `~/.config/mkconnect/phonebook`, blocks of `name = value` lines in the style of the other configuration files of this project (mode 600: it can hold a password, and the program says so when it is readable by others).
* **Command line**: `mkconnect [options] [host[:port] | entry]`, with `-t telnet|telnets|raw|ssh`, `-u` / `-c` the character set (as `mkcat`), `-s script`, `-b phonebook`.

## Phases

1. **The base:** the text UI units, the phone book, the dialer screen, a Telnet call in pass-through with the status bar, hang up, capture, the call log.  Tests: a fake Telnet BBS (a small server in Python, like the fakes of the hub tests), the program on a pty, an emulated terminal reading what it draws.
2. **Transfers:** Zmodem, Ymodem and Xmodem both ways with progress, automatic Zmodem start, the download folder.
3. **Scripts and the dial list:** `MKHubScr` on connect, multi-dial and redial.
4. **telnets and ssh:** the TLS client session, `ssh` on a pty (the entry names user, host, port and key as `ssh` takes them).
5. **Documents and package:** a man page, `MKCONNECT.md`, the package `mkconnect` (like `mkdraw`: static program, own `.deb`, also included in `mkbbs`) and the tests of `build.sh`.

## Answers (2026-11-26)

* **Attention key: `Ctrl-]`.**  A dedicated key sends the password of the system being called: **Alt-P** (the menu has P); **Alt-N** sends its login name.
* **The phone book is encrypted with a start password**, asked when the program starts (ChaCha20 with HMAC-SHA256, the key from PBKDF2-HMAC-SHA256; `MKConnCrypt.pas`, tested against RFC 8439).  An empty password leaves the file as plain text (mode 600) when the user chooses so at the first start.  The passwords of the systems are in the phone book.
* **Files** are in `~/.config/mkconnect` (the phone book and `calls.log`); `XDG_CONFIG_HOME` is honoured.

## Status

**Phase 1 is built:** `MKTuiCp` / `MKTuiScr` / `MKTuiKeys` (copied from mkedit), `MKConnCrypt` (the seal), `MKConnBook` (the phone book), `MKConnUi` (the dialing directory: list, form, find, sort, start password, help, Esc menu), `MKConnCall` (the call: pass-through with the CP437 to UTF-8 conversion and the colour guard, the status bar on the bottom row with a scroll region, Ctrl-], Alt keys, capture, the call log, the terminal's answers to the system's questions passed through), `MKConnect` (the program: `mkconnect`, `mkconnect host[:port]`, `mkconnect -e name`, `-t`, `-u`/`-c`, `-b`).  Tests: `conncrypttest`, `connbooktest`, `tests/connecttest.py` (a pty against a small Telnet BBS, with an emulated terminal).
Not yet: `telnets` and `ssh` (phase 4: the entry is accepted and the call says it is not in this version), transfers, scripts, multi-dial, the man page and the package.  The window size is told to the system when the call starts, not again when the terminal changes.

## Questions (answered above)

* The attention key: `Ctrl-]` (telnet's) as the default, or another?  It must be a key that a BBS never needs.
* A password in the phone book (file mode 600) or asked at each call?  Both, per entry?
* The log and the phone book in `~/.config/mkconnect` (and `~/.local/share` for the log), or all in one folder?
