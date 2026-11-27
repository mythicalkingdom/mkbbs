# Uploads: menu command 173 and `uploads.cfg`

A caller uploads files into a file area with menu command **173**.  Before a file is listed it can be tested, scanned for viruses and described from its `FILE_ID.DIZ`; a file that fails goes to a quarantine directory.  Everything here is set by the sysop in one plain text file, `uploads.cfg`, in the BBS directory.  Without the file uploads are accepted as they are and the caller describes each one.

## The menu command

Add an item of type **173 Upload files** to a menu (`mkmenu`).  Its data is:

| data | meaning |
|---|---|
| (empty) | the caller's current file area |
| `7` | file area 7 |

An area takes uploads when the caller's level reaches its *UL Security*, *Allow Uploads* is on and the area has a folder (`mkconfig`, File Areas).  For **uploads that wait for the sysop** make an upload-only area (nobody may download from it) and point the menu item at it by number; the sysop moves the files on.

The caller picks the protocol (built-in Zmodem, Ymodem, Ymodem-G, Xmodem, or an external one of `mkconfig`), sends the files, and is asked to describe each one.  What happens to each file:

1. **Name:** only `A-Z a-z 0-9 . _ - +` stay, anything else becomes `_`, a leading dot goes, at most 64 characters.  A name that is in the area already (any case) is refused.
2. **Size**, **test**, **scanner** (below).  Refused: deleted or quarantined, the caller sees why and is told.
3. **Description:** `FILE_ID.DIZ` from the archive, or the caller's own (up to 10 lines).
4. **Accepted:** moved into the area, added to `files.bbs` (the name, blanks up to column 14, the description; more lines indented by 13), the caller's upload count and K are credited, **the seconds of the transfer are given back as time**, and a line goes to the log.

## `uploads.cfg`

Blocks in brackets, `name = value` lines, `#` starts a comment (as in `doors.cfg`).

```
[global]
quarantine = /opt/bbs/quarantine    # refused files go here with a .why note; empty = delete (default: quarantine in the BBS directory)
sandbox    = on                     # tests and scanner run in bubblewrap: no network, a private /tmp, the file read only
timeout    = 120                    # seconds for each command; it is killed after that
minfree    = 50                     # MB that must stay free on the disk of the area (checked before the transfer)
maxsize    = 0                      # KB, the largest file (0 = no limit)
scan       = clamscan --no-summary %f   # every file; empty = no scanner
scanfail   = refuse                 # refuse | accept: a scanner that is missing, times out or fails
ask        = dizfirst               # dizfirst | always | never  (see below)
robind     = /var/lib/clamav        # more directories the sandbox shows (read only); bind = writable

[type zip jar]                      # by extension, lower case
test = unzip -tqq %f
diz  = unzip -p -C %f FILE_ID.DIZ

[type 7z]
test = 7z t -bd %f

[area 3]                            # one file area: scan, maxsize, minfree, ask, quarantine
scan =
maxsize = 4096
```

* `%f` is the file's (clean) name, `%d` the directory it is in; the command runs there.  A command is a program and its arguments, not a shell line: write a small script when you need pipes.
* **Test:** exit 0 means good; anything else refuses the file, and the first line the test printed is shown to the caller.  A test program that is **not installed** is skipped (logged once).
* **Scanner:** exit **0** clean, **1** found (the file is refused), anything else means the scanner failed.  `scanfail = refuse` (the default) then refuses the file ("it could not be checked"), `accept` lets it through.  A scanner that is not installed counts as failed; `mkcheck` warns.
* **ask:** `dizfirst`: the DIZ is the description and the caller is asked only when there is none; `always`: the caller is asked (an empty answer takes the DIZ); `never`: the DIZ, else "(no description)".
* **The sandbox** needs `bubblewrap`.  Without it (or with `sandbox = off`) the commands run with the rights of the BBS user and `mkcheck` says so.  A tool outside `/usr` (a ClamAV database, a program in `/opt`) must be named in `robind`.  The programs also see the `[sandbox]` binds of `doors.cfg`.
* The file is read at every upload: changes count at once.

### ClamAV

```
apt install clamav            # the database: sudo freshclam
```
```
[global]
scan   = clamscan --no-summary --infected %f
robind = /var/lib/clamav
timeout = 180
```
`clamscan` loads its database for every file, which takes seconds.  For a busy board run `clamd` and use `scan = clamdscan --no-summary --fdpass %f` with `robind` for the socket's directory (`/run/clamav`) and `sandbox = off` if `clamdscan` cannot reach it from the sandbox.

## Checking and logs

`mkcheck` looks at the upload menu items (the area exists and takes uploads) and at `uploads.cfg`: lines it does not understand, programs that are not there, `bind` / `robind` directories, the quarantine directory, a sandbox that does not work.

The log has `Upload: name (bytes) in area N by caller` for each accepted file and `Upload refused: name by caller in area N: reason` for the others.  The quarantine holds `<date>-<name>` and `<date>-<name>.why` (caller, area, time, reason, and what the command printed); clean it with a cron job, for example `find /opt/bbs/quarantine -mtime +30 -delete`.

Design notes: [`UPLOAD-PLAN.md`](UPLOAD-PLAN.md).


## File lists: files.bbs and PCBoard DIR files

The list files command (menu command 31) shows the list of an area with the size and date of the files.  The list is `files.bbs` in the folder of the area,
the list file that the area names in the configuration, or, when the data of the menu item is `<folder> <list file>`, that file in that folder.
It can also be a **PCBoard DIR file**, as PCBFiler makes them (the format of its documentation):

* a primary line: the file name, the size (flush right in column 20, no commas), the date from column 24 as `MM-DD-YY` (`DD-MMM-YY` with a time is read too) and the
  description from column 34; the size and the date are those of the list, so the file need not be in the folder;
* a secondary line (more description): a space first and a vertical bar `|` somewhere; the bar is not shown;
* a line that starts with `%` names a file that is shown there (an include file; DOS back slashes are turned into slashes);
* anything else (headers, footers, rules) is shown as it is; `@Xhh` colour codes are taken out.

The reading is by words and not by columns, so a list that is a few columns off is still taken.  A list with primary lines is a DIR file: its other lines are text,
not files.  The API (`/v1` file lists) reads the descriptions from both kinds.  New uploads are added to `files.bbs` as before.
