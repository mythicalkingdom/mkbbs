# Getting started: `mksetup`

`mksetup` makes a new BBS that `mk` can run at once, so that you can look at it and decide what to change.  It only **makes**: a folder that has a configuration is never touched (exit 2).

```
mksetup [-d dir] [-n "BBS name"] [-s "Sysop name"] [-l american|english] [-L language dir] [-y]
```

Without `-y` it asks for the folder (default `/opt/bbs`), the name of the BBS, the name of the sysop and the language, for each that was not given as an option.  With `-y` what is not given is the default
(`/opt/bbs`, "My BBS", "Sysop", american).  The folder is made when it is not there; it must not have a configuration (`config.mk`, `messages.mk`, `files.mk`, `bbsconfig.json`).  The name of the folder is limited
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
| **the rest** | `newuser.q-a` (the questionnaire of a new caller, only a thank-you line), `limits.ctl` (time and download limits by level), the empty data files (`users.bbs`, `extusers.bbs`, ... so that `mk` keeps them in the folder and not in the directory it was started from), and `node1`, `mail`, `attach`, `sem`, `nodelist`, `tmp` |

Everything is an ordinary file of the BBS: change the settings with `mkconfig`, the menus with `mkmenu`, the screens with `mkdraw` (`.asc` text or `.ans` art), the users with `mkusered`.

## Then

```
MK=/opt/bbs mk -L              # log in at the console; the first caller registers (name, city, phones, birth date, password)
MK=/opt/bbs mkusered           # raise the first user to sysop (security level 110)
MK=/opt/bbs mkconfig           # names, areas, security, protocols ...
mklisten -c /etc/mkbbs/mklisten.json   # let callers in (MKLISTEN.md): the ports, and "config": "/opt/bbs"
```

A new caller starts in the first message area and the first file area (a caller used to start in area 0, which nobody may use).  `mksetup` does not make the `mklisten` configuration or a sysop account yet; both are
in `SETUP-PLAN.md` for later.
