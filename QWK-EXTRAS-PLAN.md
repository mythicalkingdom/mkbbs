# QWK extras: plan

Status: **plan only** (2026-11-21).  Nothing is built.  Items marked *(proposal)* are for the sysop to confirm; items marked *(verify)* rest on
descriptions of the QWK / QWKE formats that I could only read in part and must be checked against the spec text before they are built.

"Extras" are what a QWK packet can carry besides the messages: the welcome, news and goodbye screens, bulletins, the list of new files, and
the QWKE files `TOREADER.EXT` / `TODOOR.EXT`.  They matter for **callers who take their mail with an offline reader** (the QWK door of the
BBS, `mk -Q` and the offline menu).  They are of little use between systems (a QWK network node does not read bulletins), so a user with the
**QWK Node** flag gets none of them unless the sysop asks.

## Where we are

* The packet is made by `QwkOffObj` (`MKOffQwk.pas`, shared by the door and the network pass): `MESSAGES.DAT`, the `.NDX` index files,
  `PERSONAL.NDX`, `CONTROL.DAT` and `DOOR.ID` for users that have the control switch; QWKE long names (the `To:` / `From:` / `Subject:` lines
  of the message text) both ways; control messages (`ADD`, `DROP`, `RESET` ... to `MK` / `SBBS`) are taken from reply packets, and a node
  can send them now (see `NETWORKING.md`).
* **The switches exist but nothing reads them when a packet is made.**  A user can answer "Include new files list", "Include welcome/bye
  screens" and "Include bulletins" (prompts 521 to 523, menu commands 159 to 161, `QCfg.NewFiles` / `Screens` / `Bulletins`, the user
  attributes `quaNewFile`, `quaScreens`, `quaBulletin`, `quaNewBull` in the user editor and in `CfgQwk.pas`), and the answers are kept, but no
  file is added to the packet.
* `CONTROL.DAT` already names `welcome.ans`, `news.ans` and `goodbye.ans` (lines the readers expect), and the files are not in the packet.
* The BBS has what is needed to fill the packet: the screens (`BbsDisplay.DisplayBbsFile('welcome')` and the others, chosen by the caller's
  graphics: `.ans`, `.asc`, `.avt`), menu command 6 (bulletin = a display file named in the menu item), and a new files search
  (`DoNewFiles` in `MKCFile.pas`: the files uploaded since a date, in the areas the caller may see).
* Nothing is done with `TOREADER.EXT`, `TODOOR.EXT`, or any extra file in a packet that arrives.

## What to build

### 1. The welcome, news and goodbye screens *(small)*

* The files `CONTROL.DAT` names are put in the packet when the user has "include screens": the BBS screens `welcome`, `news` and `goodbye`, the
  version the user's terminal gets (ANSI, ASCII or AVATAR, as `DisplayBbsFile` chooses), saved with the names `CONTROL.DAT` gives.
* *(proposal)* Only when a screen is **newer than the user's last packet** (the readers show them every time, and a news screen that did not
  change is noise); a setting makes it "always".
* A missing screen is left out and its line in `CONTROL.DAT` stays (readers cope with a missing file).

### 2. The list of new files *(medium)*

* With "include new files" the packet gets a text list of the files uploaded **since the user's new files date**, from the areas the user may
  list, in the layout of the BBS's own new files list.  *(verify)* The usual name is `NEWFILES.DAT`; the readers that show it take it as a
  plain text file.
* The user's new files date moves on only when the packet was made and kept (as the last read pointers do), so a packet that is lost can be
  made again with the same list.
* A limit (lines or bytes, a setting) stops a first packet from carrying every file of the BBS: past the limit the list says how many were left
  out.  Areas with "Allow file requests" are not special here.
* Needs the new files code of `MKCFile.pas` split from the screen (a function that writes to a file, used by both).

### 3. Bulletins *(medium)*

* MK has no bulletin list of its own: a bulletin is a menu command 6 with the name of a display file.  *(proposal)* The bulletins of a packet are
  **the files named by command 6 items in the menus** (scanned once when the packet is made, the main menu first), or, when the sysop wants
  to choose, a list in a text file (`bulletins.txt`: one display file name a line, the title after it).  Which one is a question below.
* Added as `BLT-<n>` plus the extension of the version the user's terminal gets *(verify the naming the readers expect)*; `quaNewBull` ("only
  new bulletins") means only those changed since the last packet.
* A bulletin that has a security level on its menu item is added only when the user meets it.

### 4. `TOREADER.EXT` (QWKE) *(medium; verify the spec first)*

* The door writes `TOREADER.EXT`: **`AREA <conference> <flags>`** lines that tell the reader what a conference is and what the user may do in it,
  and the settings lines (`KEYWORD`, `FILTER`, `TWIT` ...) when the door has such settings.  From what I could read: flags are letters, case
  matters, a reader ignores the ones it does not know, and Synchronet writes it when QWKE is on (its area flags include ones for echomail,
  internet and local areas).  *(verify: the full list of flag letters and the syntax of every line before writing a line of it)*
* Source of the flags in MK: the area type (echomail, netmail, local), read-only, private only or public only, anonymous allowed (the
  message area options), and the user's security (an area the user cannot post in is read only).
* Written only for users whose reader asked for QWKE (the user's QWKE setting, which already decides the long names).

### 5. `TODOOR.EXT` (QWKE), in the reply packet *(medium; verify first)*

* A reader may send settings in `TODOOR.EXT` of the `.REP` (the same keys the door told it in `TOREADER.EXT`, for example the filter, and
  area choices).  Today the file is ignored.  *(proposal)* Take the lines that match what the door understands (area subscribe or drop,
  `ALIAS`-like settings if the spec has them) and apply them as the control messages do (`ImpControl`), and log the others as ignored.
* Nothing from the file is trusted beyond what a control message may do (the user's own subscriptions and pointers).

### 6. Settings and the sysop's side

* Sysop switches (`mkconfig`: the QWK network / offline page) for each extra: screens, new files (with the limit), bulletins, `TOREADER.EXT`;
  the user switches that exist stay the way to choose per user.  A QWK Node user gets none of them by default.
* JSON and `mkcfgcvt` follow every configuration change (a new field in the record or the expansion room, `genjsoncfg.py`, `jsoncfgtest`).

## Phases

1. **Screens**: the files in the packet, "newer than the last packet" (needs the date of the last packet per user: where it is kept, see
   questions), the sysop switch, tests.
2. **New files list**: the function that writes the list, the limit, the new files date moved after the packet is kept, tests.
3. **Bulletins**: finding them, the names, the security, only-new, tests.
4. **`TOREADER.EXT`**: first read the spec text (the Synchronet wiki `ref:qwk`, the QWKE text and the Synchronet source that writes and reads
   it), then the writer and the tests (areas of each type).
5. **`TODOOR.EXT`**: the reader, mapped onto the control messages, tests with a made-up REP.
6. **Docs** (`NETWORKING.md` for the offline mail section, `MKBBS.md`) and the status of this plan.

Every phase ends with its tests (`tests/qwktest.py` makes a packet and looks inside; new checks for each extra: the file is there with the
right content, it is left out when the switch is off or the user is a node, the dates and pointers move only when the packet is kept), then
the full build, as usual.

## Questions for the sysop

1. **Bulletins:** are they the files of the menu items of command 6 (proposal), or do you want a list you keep (`bulletins.txt`)?
2. **Screens:** only when changed since the last packet (proposal), or every packet?
3. **New files list:** the layout of the BBS's own new files list, with a limit of how many lines (a default of 500)?
4. **Which readers matter to you** (Synchronet's own, MultiMail, SLMR, others)?  It decides how far `TOREADER.EXT` and `TODOOR.EXT` are
   worth it, and what the names must be.
5. Should the **network passes** ever ask a hub for its bulletins and new files (and store them)?  Proposal: no.

## Sources to read before phases 3 to 5

* Synchronet wiki, QWK: <https://wiki.synchro.net/ref:qwk> and its remote commands page <https://wiki.synchro.net/ref:qwk_cmds>.
* The Synchronet commit that adds `TOREADER.EXT` and reads `TODOOR.EXT`: <https://gitlab.synchro.net/main/sbbs/-/commit/c9f6aaa541e7ef93052e730083eae3f200035ec2>.
* The QWKE specification text (a copy in the `jamjam` crate documentation was not reachable when this was written).
