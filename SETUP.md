# Getting started: `mksetup`

`mksetup` makes a new BBS that `mk` can run at once, so that you can look at it and decide what to change.  It only **makes**: a folder that has a configuration is never touched (exit 2).

```
mksetup [-d dir] [-n "BBS name"] [-s "Sysop name"] [-l american|english] [-L language dir] [-u] [-p password] [-N] [-y]
```

Without `-y` it asks for the folder (default `/opt/bbs`), the name of the BBS, the name of the sysop and the language, for each that was not given as an option, then whether to make the sysop account and
`mklisten.json`.  With `-y` what is not given is the default (`/opt/bbs`, "My BBS", "Sysop", american, no account, `mklisten.json` made).  `-u` makes the **account of the sysop** and `-p password` gives its password
(4 to 15 characters; without it one is made up); `-N` leaves `mklisten.json` out.  The folder is made when it is not there; it must not have a configuration (`config.mk`, `messages.mk`, `files.mk`, `bbsconfig.json`).  The name of the folder is limited
(the configuration holds the path of a file area in 50 characters): `/opt/bbs/files/area01/` is fine, a long one is refused with the reason.

## What it makes

| | |
|---|---|
| **the configuration** | `config.mk`, `messages.mk`, `files.mk` and the others, from the defaults of `mkconfig` with: the names, the paths of the folder, the language, new callers at security level 10, zip and unzip as the packers |
| **the language** | `american.lc` (or `english.lc`) and `mkmenu.lc` copied from the compiled files (`-L dir`, else next to the programs, `/usr/local/share/mkbbs/lang`, `/usr/share/mkbbs/lang`) |
| **two message areas** | **General Messages** and **Comments to the Sysop**, both local, Merlin bases (`msgs/gen.mer`, `msgs/sys.mer`), nothing purged by age or count |
| **a file area** | **Example Files** in `files/area01/` with one short file (`readme.txt`) and its `files.bbs` |
| **a sample door** | `games/cowsandbulls.pas`, the Pascal game, on menu key B (command 170) |
| **the menu** | `menus/top.mnu`: read, post, jump, mail, file list, download, upload, file area, users, who is on, time statistics, page the sysop, the game, version, goodbye; the title and the current areas use `\kY` and `\kZ` (`MKBBS.md`, Menu items) |
| **the screens** | `txtfiles/welcome.asc`, `goodbye.asc` and `newuser1.asc`: one short line each (`Welcome to <name>`, `Thank you for visiting <name>` ...) |
| **the sysop account** (`-u`, `-p`) | a user with the sysop's name and security level 110, written the way `mk` writes a caller (`users.bbs`, `extusers.bbs`, `usersidx.bbs`; the password hashed if the configuration says so): the sysop logs on at once instead of registering |
| **`mklisten.json`** (unless `-N`) | the listener configuration, mode 600: `mk` and the folder, nodes 1-4, a telnet port **2323** and the sysop monitor on **127.0.0.1:2330** with a made-up password (shown once; the file keeps its sha1), logs in `logs/mklisten.log` |
| **the rest** | `newuser.q-a` (the questionnaire of a new caller, only a thank-you line), `limits.ctl` (time and download limits by level), the empty data files (`users.bbs`, `extusers.bbs`, ... so that `mk` keeps them in the folder and not in the directory it was started from), and `node1`, `mail`, `attach`, `sem`, `nodelist`, `tmp` |

Everything is an ordinary file of the BBS: change the settings with `mkconfig`, the menus with `mkmenu`, the screens with `mkdraw` (`.asc` text or `.ans` art), the users with `mkusered`.

## Then

```
MK=/opt/bbs mk -L              # log in at the console; the sysop (with -u), or the first caller who registers (name, city, phones, birth date, password)
MK=/opt/bbs mkusered           # without -u: raise the first user to sysop (security level 110)
MK=/opt/bbs mkconfig           # names, areas, security, protocols ...
mklisten -c /opt/bbs/mklisten.json -t  # check the listener configuration, then without -t to let callers in (MKLISTEN.md); change the ports there
```

A new caller starts in the first message area and the first file area (a caller used to start in area 0, which nobody may use).  A data file that belongs in the BBS folder (`users.bbs`, `timelog.bbs` ...) is
made there by `mk`, whatever directory it was started from; only the `exitinfo.bbs` of the node is made in the node's own directory.
