# The list of all files and the file index: `mkfilelist`

`mkfilelist` makes a list of the files of the file areas for one **security profile** (a level and flags): a file that callers fetch (`ALLFILES.TXT`, `NEWFILES.TXT`), a list for a file
request, or a list for the sysop.  It also keeps the **index** of the file areas, a flat binary file that the BBS uses to find files and new files quickly.

## The list

```
mkfilelist [-c config dir] -l level [-f flags] [-a areas] [-n days] [-t text|dir|json] [-u] [-o file] [-N]
```

| option | |
| --- | --- |
| `-l LEVEL` | the level of the list.  An area is in it when **its view security and its download security** are both met by this level and these flags.  Areas have no other switch: what must not be listed is kept out by its security level or flag |
| `-f FLAGS` | the flags that the profile has: numbers 1 to 32, `-f 1,5,12` |
| `-a AREAS` | only these file areas: `1,3,5-7` |
| `-n DAYS` | only the files that are newer than this many days (by the date of the file): a list of new files |
| `-t FORMAT` | `text` (the default: for each area a header and a line for each file with name, size, date and description), `dir` (a PCBoard DIR file for each area, the area as a comment line), `json` |
| `-u` | text and dir in UTF-8 (the lists are in the DOS character set; json is always UTF-8) |
| `-o FILE` | write the list to this file (a new file, then renamed over the old one: a caller who fetches the list never gets half of it); without it the list goes to the screen |
| `-N` | without the index: the lists and folders are read |
| `-I` | make the index again for every area and say what it holds |
| `-S` | say what the index holds |

The files of an area are the files of its folder, described from its list: `files.bbs`, or, when the area has no `files.bbs`, a PCBoard DIR file (the list file the area names, or a file `DIR` in
the folder).  A file the list does not name is listed without a description; a name in the list that has no file is left out.  The files come by name, without regard to case.  An area
whose folder is not there is left out.

### Made by cron or an event

A list for a profile is made when its time comes and put into a file area, where callers download it like any file (and a file request fetches it by name):

```
# crontab: every night at 03:10, the lists for the public (level 10) and the members (level 100)
10 3 * * *  MK=/home/bbs/config mkfilelist -l 10  -o /home/bbs/files/lists/allpub.txt
15 3 * * *  MK=/home/bbs/config mkfilelist -l 100 -f 1 -o /home/bbs/files/lists/allmem.txt
20 3 * * *  MK=/home/bbs/config mkfilelist -l 100 -n 7 -o /home/bbs/files/lists/new7.txt
```

An event of `events.mk` (action 1, command) does the same: `mkfilelist -c /home/bbs/config -l 100 -o /home/bbs/files/lists/allmem.txt`.  Compress the list with the archiver of your choice in
the same job (`zip -q allmem.zip allmem.txt`).  The list that is made for a level only holds what that level may download, so the file area that holds it needs the same level.

## The index

`filelist.idx` in the BBS directory (or the file that `MKFILEIDX` names) holds, for every file area, the files by name with size, date and description.  It is a **cache**: the lists
(`files.bbs`, DIR files) stay what they are, so other programs and the sysop's editor keep working.  The layout is described in `src/MKFileIdx.pas` (flat, little endian as the machine writes it, no
other program or library is needed); the file is replaced as a whole, so a reader never sees half of it.

Each area has a stamp in the index: the folder and the list file it was made from, the time and size of the list file and the time of the folder.  When the stamp is not the one of the area now
(an upload, a TIC, a hatch, a script, an edited list, a file put into the folder) that area is read again the slow way and its block is written again; nothing has to tell the index about a change.
What it does not see is a file in the folder that was changed **in place** (the same name, new content): the time of the folder does not move.  `mkfilelist -I` (for example in the nightly job) makes it again.
Where the index cannot be written (no rights, a full disk) the areas are read the slow way each time; a missing or damaged index is made again.

Used by: `mkfilelist`, the file lists of the JSON API (`/v1/areas/files/<area>`), the new files commands of the BBS and of the offline mail door (QWK `NEWFILES.DAT`), the file lookup of the archive
viewing command, and the list that `mkfreq` makes for the magic name `@LIST`.  The text list commands of the BBS (menu command 31, the keyword search of the file lists) still read the lists, as they
show them line by line.

The new files commands now show the files by name (they used to show them in the order of the list), and only files that a list names.
