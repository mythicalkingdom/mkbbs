# Getting started: `mksetup` (plan)

Status (2026-11-24): **idea and plan, no code.**  Idea of the sysop: a small program that asks for the BBS folder (for example `/opt/bbs`) and makes a **usable default configuration, a minimal set of menus and a few
`.asc` screens**, so that `mk` runs at once (`MK=/opt/bbs mk -L`) while the sysop decides what to customise with `mkconfig`, `mkmenu`, `mkdraw` and `mkusered`.  It is not a tour of every setting: the point is a BBS that
works, small enough to read through, and every file it makes is one of the normal ones, so nothing needs to be unlearned.  (The `testmm` menu, prompts and type 0 lines, was the first sketch of a menu-driven
interface; the wizard is a separate program, a menu can come later.)  The configuration checker (`mkcheck`, Future ideas in `MAINTENANCE-PLAN.md`) is the other half: `mksetup` makes, `mkcheck` verifies.

## What it asks

1. **The BBS folder** (default `/opt/bbs`; it is made when it is not there).  It must be empty or not exist: `mksetup` **never overwrites** a configuration (`-f` only adds what is missing).
2. **The name of the BBS**, **the sysop's name**, the **language** (American or English: the language files that were installed in `/usr/share/mkbbs/lang`).
3. Optionally the **sysop account** (name, password) with the sysop's security level, so there is no need to be the first to register; and a **`mklisten.json`** with a telnet port and a sysop monitor port with a made-up
   password (shown once).  Both are yes/no questions; the default is no for the account (the first registered user can be raised with `mkusered`) and yes for `mklisten.json`.

Everything is also a command line option (`-d dir -n "Name" -s "Sysop" -l american --no-listen -y`), so a package or a script can run it without questions.

## What it makes

* **The directories** (owner and mode as the BBS user needs them): `menus/`, `txtfiles/` (the screens), `lang/` or the language files in the BBS directory as `mk` looks for them, `msgs/` (the message base),
  `files/uploads/`, `nodes/` (node directories as the configuration says), `stats/` and `logs`-path as set in the configuration.
* **The configuration**, from a built-in template of the JSON form (`bbsconfig.json`, the same code `mkcfgcvt` uses, so there is one definition of every field and `MKCfgMK` / `MKCfgJs` parity is kept): the names,
  the paths of the directories above, sensible security levels (new user, validated, sysop), time and download limits, the language, one node, the protocols, **two message areas** (a general one and "comments to
  the sysop"), **one file area** (uploads), one origin line, no network, no events.  Passwords plain or hashed as the installed default says (`PASSWORDS.md`).
* **The menus** (`*.mnu`), written by the program from a text template in its source (the `.mnu` file is binary records; the template lists key, command, prompt, data, security, colour): `top` (read mail, jump to
  an area, files, user list, time statistics, page the sysop, version, goodbye), and, if the first one gets long, `message` and `file`.  They use the prompt codes of `MKBBS.md` (a heading line of type 0,
  `^` highlights, `;` keeps the line, `@` and the backtick show the current areas) and the colours start at 07.
* **The screens** (`.asc`, plain text so that every terminal shows them): `welcome`, `newuser1` (the rules), `news`, `goodbye`, `bulletin` ... only the ones `mk` looks for (`MKBBS.md`), short and with the BBS
  name in them; the sysop replaces them with `mkdraw` art later.
* **Empty data files** the first run needs (user file, message base files, `useron.bbs`, `lastread.bbs`), made in the form the programs expect, so the first call does not begin with an error.

## What it checks at the end

It starts `mk -L` in test mode (or loads the configuration, the language file, every menu and screen the template named) and prints what it found, and the three or four commands that come next: `MK=/opt/bbs mk -L`, `mkusered`,
`mkconfig`, `mklisten -c /etc/mkbbs/mklisten.json`.  Exit 0 when the BBS can be started.

## Phases

1. **The template and the writer**: the JSON template, the directories, the empty data files, the language files; `mksetup -d dir -n name -s sysop -y` makes a BBS that `mk -L` loads; test: make one in a temporary
   directory, load it with every program that reads the configuration (`mkconfig`, `mkcheck`-like load, `mk` with a scripted logon over a pty).
2. **The menus and screens** (text template compiled into the program; test: the bytes of the `.mnu` files and a scripted caller that walks the top menu).
3. **The questions** (interactive, plain prompts: no Free Vision needed), the sysop account and `mklisten.json`, and the final check; test with scripted input.
4. **Docs and packaging**: `SETUP.md`, a line in `GETTING-STARTED.md`, the deb tells the sysop to run it.

## Questions for the sysop

1. The default folder: `/opt/bbs`, or `/var/lib/mkbbs` (what the package's user would own)?
2. The default message base for the two areas: Hudson (the format the sample uses) or JAM (the better-defined one)?
3. Should `mksetup` also **repair** (add the missing directories and files of an existing BBS), or only make a new one?  (Proposal: only make; the repair is the job of `mkcheck`.)
4. The name: `mksetup`, `mkinit`, or `mkstart`?
