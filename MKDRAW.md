# mkdraw and mkcat

Two small text mode tools for the screens that bulletin board systems show to their callers.  They are part of the MK BBS, but they need no BBS: you can use them anywhere (the package `mkdraw` has just these two).

* **`mkdraw`** draws and edits an 80 x 23 screen: ANSI art, AVATAR, plain ASCII, or the Pascal source that writes a screen.  Every cell is one IBM PC (CP437) character with a colour attribute, as on a DOS machine.
  It runs in a text terminal of at least 80 x 25; a UTF-8 terminal shows the Unicode equivalents of the CP437 characters, and what you type or paste there is turned back into CP437.
* **`mkcat`** shows such a file (a screen, a message, a DOS log) on a terminal of today: it turns the CP437 characters into UTF-8 (or leaves them as they are for a BBS terminal such as SyncTERM) and keeps the colours of the art as drawn.

`man mkdraw` and `man mkcat` have the details; this page is the short version.

## mkdraw

```
mkdraw [-n] [file]
```

With a file name that file is loaded; without one the screen files (`*.a*`) of the current directory are listed to choose from (Esc starts with an empty screen).  **Esc** opens the fast menu with every command, **Alt-H** the help, **Alt-X** leaves.

| keys | |
|---|---|
| Alt-A, Alt-B, Alt-I, Alt-U, Alt-R | colour and attribute, blinking, intensity, the colour under the cursor, reverse |
| Alt-D | drawing mode: the arrow keys draw with a line set |
| Alt-C, Alt-M, Alt-F, Alt-Z, Alt-E | copy, move, attribute fill, clear, frame an area (choose its corners with the arrow keys and Enter; `L` takes the last area again) |
| Alt-V, Alt-Y, Alt-W | insert a line, delete a line, double image (2 x 2) |
| Alt-G, F1..F10 | a set of special characters (box drawing, shading, accents ...), and enter them (Alt-F1..F10 chooses set 1..10, Ctrl-F1..F5 set 11..15) |
| Ctrl-A..Ctrl-Z | enter that control code |
| Alt-P | pick a BBS screen code (the codes a BBS expands when it shows the screen) |
| Alt-L, Alt-S, Alt-T | load, save an area, save the whole screen |

**Saving.**  A name without an extension saves `name.asc`, `name.ans` and `name.avt`; `.ans`, `.avt`, `.pas` (or `.inc`: the Pascal source that writes the screen) save that kind only, anything else plain ASCII.
A saved ANSI file is made so that every colour reset (`ESC[0m`) also sets the foreground and the background (light gray on black, the DOS default), so that a terminal with its own default colours shows the art as it was drawn.  `-n` leaves the files as the original DOS program wrote them.

**The list of BBS screen codes** (`codes.mkd`, used by Alt-P): two lines for each code, the text shown and the code itself.  It is looked for in the current directory, in the folder named by `MK`, in `~/.config/mkdraw/`, then in `/usr/local/share/mkdraw/` and
`/usr/share/mkdraw/` (the package installs a list there).  Without any file a built-in list is used.

Exit codes: 0 done, 2 the terminal is smaller than 80 x 25, 3 a wrong command line.

## mkcat

```
mkcat [-u | -c] file
```

`-u` converts the characters 128..255 to UTF-8; `-c` writes the bytes as they are.  With neither, the choice depends on where the output goes: a terminal gets what its type wants (`TERM` xterm, linux, screen ... UTF-8; ansi, syncterm and unknown types CP437), a file or a pipe gets UTF-8.
Control characters and ANSI escape sequences go through unchanged; a `^Z` (the DOS end of file) ends the text.  Exit codes: 0 done, 1 the file could not be read, 3 a wrong command line.

```
mkcat welcome.ans
mkcat -u welcome.ans > welcome.txt
```

## Installing

The Debian package `mkdraw` has only these two programs, their manual pages and the example `codes.mkd`.  The package `mkbbs` has them too (it provides `mkdraw`, so the two cannot be installed together: install one or the other).
Building from source: `make` and `make install` (both programs, the manual pages in `PREFIX/share/man/man1`, the list in `PREFIX/share/mkdraw`), or `make deb-mkdraw` for the package.  The source needs Free Pascal 3.2 with the Free Vision units (`fp-units-fv` on Debian).
