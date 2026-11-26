# Upload handling (plan, 2026-11-25)

**What is there today:** callers can *download* (file lists, `DownLoadSpecial`, new files, offline mail packets) and send a QWK reply packet (command 156), but the menus have **no command for a caller to upload a file to a file area** at all.  The pieces exist: `ProtObj.Recv` (Zmodem, Ymodem, Xmodem receive,
used by `OfflineUL`), `User.UpdateForUL`, the per-area upload security (`GetFileULSecurity`, the `faNoUL` flag, `AllowUL` in `mkconfig`), the lists `files.bbs` (name, description lines; read by the list and by `mkfilecheck`), the bubblewrap sandbox of the doors (`MKSandbox`).  So "upload
handling" is the upload command **and** what happens to a file after it arrives.

## What it should do

* **Command 173, "Upload files"** (menu data: nothing = the caller's current file area, or an area number): checks the area (upload security level, not `faNoUL`, free disk space above a limit), asks for the protocol (`GetProtocol`), receives into an **incoming directory of the node** (`<tmp>/upl<node>`), never into the area, so a refused file is never visible.
* **Each file that arrives** goes through, in order:
  1. **name rules**: no path, no leading dot, characters `A-Z a-z 0-9 . _ - +` only (others replaced by `_`), the name exists in the area or its list already -> refused ("already there"); size over the area's limit -> refused.
  2. **tests** (`uploads.cfg`, below): a test command per file type (`unzip -tqq`, `7z t`, `tar tf`, `lha t` ...), then an optional **scanner** for every file (`clamscan --no-summary`, `clamdscan`; exit 0 clean, 1 found, other = scanner error).  Each runs in the **sandbox** (no network, a private `/tmp`, only the incoming file visible), with a time limit.
  3. **description**: `FILE_ID.DIZ` taken out of the archive (`unzip -p`, `7z e -so` ...), cut to 45 columns by 10 lines; no DIZ: the caller is asked for a description (a line, then more lines until an empty one); the caller may always replace it (`ask = always`).
  4. **accepted**: moved into the area directory, its description written into the list `files.bbs` (the same lines `mkfilecheck` and the list read), the caller credited (`UpdateForUL`: count, K), a log line, the transfer shown to the caller ("accepted", "n files, KB").  **Refused**: the file is deleted or kept in the **quarantine** directory with a `.why` note (the choice is in `uploads.cfg`), the caller sees why (the first line of the test's output, or the rule), no credit, a log line.
* **`uploads.cfg`** (an ini file next to `doors.cfg`, same syntax):

```
[global]
incoming   = /tmp/mkbbs-upl           # <incoming>/node<N>
quarantine = /opt/bbs/quarantine      # empty: refused files are deleted
sandbox    = on                       # the tests and the scanner run in bubblewrap (as doors)
timeout    = 120                      # seconds for each command
minfree    = 50                       # MB that must stay free on the disk of the area
scan       = clamscan --no-summary %f # every file (empty: none)
scanfail   = refuse                   # refuse | accept when the scanner itself fails (exit not 0 or 1)

[type zip]                            # by extension, lower case, several allowed: [type zip jar]
test = unzip -tqq %f
diz  = unzip -p -C %f FILE_ID.DIZ

[area 3]                              # per file area (number); anything not set here comes from [global]
scan = 
maxsize = 4096                        # KB, 0 = no limit
ask = always                          # description: dizfirst (default) | always | never (a DIZ or "(no description)")
```

  `%f` is the file name inside the sandbox, `%d` the directory.  A missing tool is not an error of the caller: it is logged once and the test is skipped (`mkcheck` warns about a command that is not there).
* **`mkcheck`** says what `uploads.cfg` would do: commands not installed, directories not writable, an area with uploads allowed and no test or scan configured (info).
* **Documents:** `UPLOADS.md` (the command, `uploads.cfg`, the recipe for ClamAV), `MKBBS.md`, `DOS-DOORS.md` reference for the sandbox; the menu text `lang/MKMENU.TXT`; the prompts in the language files.

**Phase 1 is built:** `src/MKUpload.pas` (command 173, menu text 173 / 429 in `MKMENU.TXT`, prompts 543-551 in the language files, with the English text as a fallback in the code), `tests/uploadtest.py` (Zmodem and Ymodem with `sz` / `sb` over Telnet: safe names, descriptions, `files.bbs`, a duplicate refused, an area that does not allow uploads, the log).  Found on the way: `GetProtocol(False)` never found a protocol (a dangling `else` in `MKCFile.pas`: only the "special" files choice worked); the sample's `TempPath` points into the live sample tree (the test sets its own).  Not yet: `uploads.cfg` (phase 2), the area size limit and free space, `mkcheck`.

**Phase 2 is built:** `src/MKUpCfg.pas` (`uploads.cfg`: `[global]`, `[type ext ...]`, `[area N]`; comments with `#` as in `doors.cfg`), the tests / scanner / DIZ / sandbox / quarantine / size and free-space limits in `MKUpload.pas`, `tests/uploadtest.py` (fake tools as shell scripts: pass, fail, scanner found, scanner broken with `scanfail` refuse and accept, a hanging scanner killed at the time limit, DIZ, `ask` always / never, `maxsize`, `minfree`, a missing program, the sandbox that does not see the BBS directory and the same test with `sandbox = off`).  `mkcheck` already checks the upload menu items and `uploads.cfg` (programs, robind / bind, quarantine directory, the sandbox, an area that is not there; `checktest.py`).  A scanner that is not installed refuses the file under `scanfail = refuse` (the safe default; `mkcheck` warns); a missing *test* program is skipped.  Left for phase 3: `UPLOADS.md`, the README line.

**Phase 3 is built:** `UPLOADS.md`, `MKBBS.md`, README, `build.sh` (uploadtest), `mkcheck`.

## Phases

1. **The command** (173): the checks, the protocol choice, receive into the incoming directory, name rules, move into the area, the description (ask the caller), `files.bbs`, the credit, the log; tests: an upload by Zmodem and Ymodem over a Telnet session of the test harness, the list shows the file, the user's counts, an upload refused for security level / `faNoUL` / an existing name.
2. **`uploads.cfg`**: tests by type, the scanner, DIZ, the sandbox, quarantine and the `.why` note, `ask`, size and free-space limits; tests with fake `test` and `scan` commands (shell scripts) that pass, fail, hang (time limit) and are missing.
3. **`mkcheck`, `UPLOADS.md`, the menu text, `build.sh`**.

## Questions

1. **A new file `uploads.cfg`** (proposal; the same style as `doors.cfg`), or settings in `mkconfig` per file area (more work: `mkconfig`, JSON mirror, `MKCfgMK`)?  The file is quick and sysop-editable; `mkconfig` could get a screen later.
2. **Refused files:** quarantine with a `.why` note (proposal), deleted at once, or either by a setting (the proposal above: set `quarantine` or leave it empty)?
3. **Tests and scanner in the bubblewrap sandbox** (proposal; with `sandbox = off` or no bwrap they run unwrapped, `mkcheck` warns)?
4. **The caller is credited** when the file is accepted: count and K only (proposal), or also time back (old BBSs gave the upload time back)?
5. **Hold for approval:** an area flag "uploads wait for the sysop" (the file goes into `<area>/new` until `mkfilecheck`-style approval) is **not** in this plan: leave for later?

## Decisions (2026-11-25)

1. `uploads.cfg`, plain text.  2. Quarantine is a setting; **the default is quarantine** (`quarantine` set in `[global]` by default to `<BBS dir>/quarantine`; empty = delete).  3. Tests and scanner are sandboxed.  4. **The upload time is given back** (the seconds the transfer took are added to the caller's time left).  5. No "wait for the sysop" flag: the sysop points the menu item's data at an upload-only area (a file area with downloads closed to callers).
