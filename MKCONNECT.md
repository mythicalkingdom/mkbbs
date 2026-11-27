# mkconnect: a terminal program for BBSs

`mkconnect` is a dialing directory and a terminal for calling bulletin board systems over the network, in the spirit of QModem for DOS.  It runs in an
ordinary text terminal (a Linux console, an xterm, an SSH session), needs no BBS and is a part of this repository like `mkdraw` and `mkcat`.

```
mkconnect                    the dialing directory
mkconnect bbs.example.org    a call to a system that is not in the phone book (port 23)
mkconnect -t ssh me@host     ssh through the system ssh
mkconnect -e "My BBS"        a call to a system of the phone book
```

## How it shows a system

`mkconnect` does not emulate a terminal.  The bytes of the system go to your terminal, with two changes: the DOS character set (CP437) is turned into
UTF-8 where the terminal wants it (`-u`, `-c`, or by `TERM`, as in `mkcat`), and a colour guard keeps the art as it was drawn (a reset that sets no colour
is followed by the missing DOS colour).  What you type goes the other way: arrow keys and F keys as the ANSI codes a BBS expects, typed text as CP437.
The bottom row is a status bar: name, host and port, time on line, character set, capture, and the progress of a transfer.  Telnet is spoken (echo,
binary, terminal type, window size; the size follows your window).

## The phone book

`~/.config/mkconnect/phonebook` (mode 600).  It is **sealed with a start password** asked when the program starts: PBKDF2-HMAC-SHA256 makes the keys,
ChaCha20 encrypts, HMAC-SHA256 checks; the file has no host and no password in the clear.  An empty password at the first start leaves it as plain text.
`P` in the dialing directory changes the password.  A call by host name (`mkconnect host`) does not touch it and asks nothing.

Each system has: name, host, port, kind (telnet, telnets, raw, ssh), character set (CP437 or UTF-8), the protocol offered first, login name,
password, script, SSH user and a note.  The password and login name are what **Alt-P** and **Alt-N** send during a call.

Dialing directory keys: Enter dial, A add, E edit, D delete, F or / find, S sort (name / last call), **Space mark, M multi-dial**, P password, F1 help,
Esc menu, Q or Alt-X leave.  Multi-dial tries the marked systems (or the selected one: a redial) in turn, with a pause (`-w`, 5 seconds) and a number of
rounds (`-r`, 3), showing why each try failed, until one answers; Esc stops.

## During a call

| key | does |
| --- | --- |
| `Ctrl-]` | the attention key: a menu on the bottom row (twice: sends Ctrl-] to the system) |
| `Alt-P` / `Alt-N` | send the password (and Enter) / the login name (and Enter) of this system |
| `Alt-U` / `Alt-L` | upload / download |
| `Alt-C` | capture on / off: the text of the call to `name-date.cap` in the current folder |
| `Alt-T` | the character set of the display |
| `Alt-H` / `Alt-D` / `Alt-X` | hang up / hang up and go to the dialing directory / hang up and leave |

An Alt key is Esc and a letter that arrive together.

### File transfers

Zmodem, Ymodem, Ymodem-G, Xmodem and Xmodem-1K, both ways, through the same code as the BBS.  `Alt-U` asks for the protocol (Enter takes the one of the
entry) and the files (names or wildcards, in one folder); `Alt-L` asks for the protocol and, for Xmodem, a name to save under.  **A Zmodem sender that the
system starts is taken up at once**.  Files come into the download folder (`-d`, else `~/Downloads`, else the current folder).  The progress is on the
bottom row; Esc or Ctrl-X cancels.

### Scripts

A script is an `MKHubScr` script (the language of the QWK hub passes, see HUBS.md): `expect`, `try`, `send`, `sendln`, `when`, `pause`, `upload`,
`download`, `set`, `if`, `log`, `fail`, `end`, `hangup`.  The variables `login`, `password`, `name`, `host` and `protocol` are set.  It runs after the connect
while the screen of the system is shown; Esc or Ctrl-X stops it.  The entry names it, or `-s script`; it is a file (a path, or in
`~/.config/mkconnect/scripts`) or a built in one (`synchronet`, `mk`).

```
timeout 10
expect "login:"
sendln "%login%"
expect "password:"
sendln "%password%"
when "Press any key" send "\r"
```

### telnets and ssh

`telnets` is Telnet inside TLS (TLS 1.2 and up; the OpenSSL libraries are loaded when needed).  **The certificate of the system is not checked**: a BBS
most often has a self-signed one, so the line cannot be read on the way but the system is not proven to be the one named.  `ssh` runs the system `ssh`
on a pseudo terminal (`-p port`, `user@host`); a password, a key phrase or a host key question is answered on the terminal, **Alt-P** sends the password of the
entry.  Keys and options of `ssh` come from your `~/.ssh/config`.

## Files

| file | |
| --- | --- |
| `~/.config/mkconnect/phonebook` | the dialing directory |
| `~/.config/mkconnect/scripts/` | scripts |
| `~/.config/mkconnect/calls.log` | a line for each call (system, address, time on line, bytes), transfer and script |

## Packages

The package `mkconnect` (`make deb-mkconnect`) holds the program, the manual page and this document and needs no BBS.  The package `mkbbs` includes the
same files (it provides, conflicts with and replaces `mkconnect`).
