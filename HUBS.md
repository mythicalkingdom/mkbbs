# QWK hubs: reference

How `mk -G<id>` talks to a hub, what each setting does, and what has been checked against what.  The how-to is in `NETWORKING.md`, section B; this file is the
reference and the status.  (The work was planned in `QWK-HUB-PLAN.md`.)

## Which way to reach a hub

| `transport` | The hub is reached by | Use it when | What you write |
|---|---|---|---|
| *(none)*, with `hub host:port` | a Telnet call and a **script** (a profile) that logs in and runs the hub's QWK menu; Zmodem, Ymodem or Xmodem is done by MK | the hub is a BBS with a QWK menu (Synchronet, another MK ...) | `profile NAME` or `script FILE`, `login`, `password`, `protocol` |
| `ftp` / `ftps` | FTP or explicit-TLS FTP, by MK itself | the hub keeps `<id>.qwk` and takes `<id>.rep` by FTP | `get` / `put` remote names, `login`, `password` |
| `exec` | **programs of yours** (`get`, `put`) run without a shell | anything else: SFTP, HTTP, rsync, a mail gate ... | `get` / `put` command lines |
| *(no `hub`)* | something else moves the files | cron, a script or `mkbink` puts `<id>.QWK` in `inbound` and takes `<id>.REP` from `outbound` | `inbound`, `outbound` |

All of them share the rest: the reply packet is made from the new messages of the areas the hub user is subscribed to, the packet of the hub is posted (duplicates are
skipped, what came from the hub is never sent back), pointers are kept, a refused reply packet stays for the next pass, and the exit code tells the result.

## The map file `<id>.map`

Found in the BBS directory (the id exactly as given to `mk -G`).  Words on a line; `;` or `#` begins a comment (so a `get` / `put` command line cannot hold either).  Keep it
private (`chmod 600`): it has the password.

| Key | Value | Default | Meaning |
|---|---|---|---|
| `inbound` | directory | the directory `mk` was started in | where `<id>.QWK` arrives (and is posted from) |
| `outbound` | directory | the same | where `<id>.REP` is made |
| `user` | name | the id | the user record that is the bookkeeping for the hub (QWK Node flag) |
| `conf` | `<hub number> <area>` | | conference *n* of the hub is message area *a* here; an area with no line is not sent, a conference with none is not posted |
| `hub` | `host[:port]` | port 23 (21 for `ftp` / `ftps`) | the hub to call |
| `transport` | `ftp`, `ftps`, `exec` | Telnet | how the files move (see above) |
| `profile` | name | | Telnet: the script `NAME.scr` (the directories are listed under *Profiles*), else a built-in one: `synchronet`, `mk` |
| `script` | file | | Telnet: a script of your own (relative to the map file) instead of a profile |
| `login`, `password` | text | | the account at the hub (the password is never written to a transcript or on a command line) |
| `protocol` | `Z` `Y` `G` `X` | `Z` | Telnet: the transfer protocol (and the key the hub is told) |
| `transcript` | file | `<id>.hub.log` next to the map file | what was said (the password as stars) |
| `get`, `put` | **ftp / ftps:** the remote file names; **exec:** a command line | ftp: `%id%.qwk`, `%id%.rep` | `%id%` is the id; exec also `%qwk%` `%rep%` `%login%` `%host%` `%port%` |
| `nothing` | number | 3 | exec: the exit status of `get` that means "nothing new" |
| `exec-timeout` | seconds | 600 | exec: a program that runs longer is killed |
| `ftp-delete` | `yes` / `no` | no | ftp: delete the packet at the hub after it was fetched |
| `ftp-timeout` | seconds | 60 | ftp: seconds without a byte before giving up |
| `tls-ca` | file | the system's CAs | ftps: the CA (or the certificate itself) that is trusted |
| `tls-verify` | `yes` / `no` | yes | ftps: no turns the checking of the certificate (and of its name) off |
| `reply-error`, `reply-ok` | text | from the profile header | what the hub says after the reply packet; up to 8 of each |
| `strip-ctrla` | `yes` / `no` | no | take Synchronet's Ctrl-A codes out of the messages |
| `control-to` | name | `SBBS` | whom the control messages (ADD, DROP ...) are for |
| `retries`, `retry`, `retry-max`, `onfail` | | 3, 300, 3600, none | what `mklisten` does when a scheduled pass fails with 5, 6 or 7 |

## Profiles

A profile is a script (`MKHubScr`: `expect`, `send`, `upload`, `download`, `when` ...) in a file `NAME.scr`, found in: the directory of the map file, the `hubs` directory
of the BBS, `/usr/local/share/mkbbs/hubs`, `/usr/share/mkbbs/hubs`; the two built into the program (`synchronet`, `mk`) are the fallback.  `make install` installs
`hubs/*.scr`.  Comment lines at the top say what the profile is: `# software:`, `# checked:`, and optionally `# reply-error:` / `# reply-ok:` (used when the map file has none).
`mk -G -P` lists them, `mk -G -P<name>` shows one.  A profile is written from a transcript (`-K`) and tested with a recording (`-F`).

## The command line

All of them are `mk -G<id>` and some switch; nobody is on line.

| Switch | Does |
|---|---|
| *(none)* | one pass: reply packet, call or transfer, post the packet |
| `-D` | dry run: says what would be sent and what is waiting; changes and calls nothing (`transport exec` / `ftp`: names the programs or files, runs none) |
| `-X"ADD 4029 -50"` | queue a control command for the hub (up to 10; or lines in `<id>.ctl`) |
| `-K` | **talk**: call the hub with your keyboard and record the call as a transcript (Ctrl-] ends, Ctrl-U sends a file) |
| `-F<transcript>` | **replay**: run the script against a recording, no call; exit 0 when it goes the same way |
| `-I` | list the conferences of the packet that is in the inbound directory (or its `.old`), and what each is here |
| `-J` | suggest `conf` lines from the names of the areas (`-W` adds them to the map file) |
| `-G -P` | list the profiles (`-G -P<name>`: show one) |

## Exit codes

| | |
|---|---|
| 0 | done |
| 1 | no map file (or, with `-F`, no recording; with `-J -W`, the map file could not be written) |
| 2 | the hub user is missing or is not a QWK node |
| 3 | the reply packet could not be made |
| 4 | the hub's packet could not be read |
| 5 | the hub could not be reached, or an FTP / exec step failed |
| 6 | the script (login, transfer) failed, the profile is not found, or the replay did not go the same way |
| 7 | the hub did not accept the reply packet (`reply-error` / `reply-ok`); it stays and goes again |
| 8 | a control command was not valid (the others went) |
| 9 | `-I` / `-J`: there is no packet to read |

## Files a pass uses and makes

`<id>.map` (yours); `<id>.hub.log` (the transcript of the last call: Telnet `<<` / `>>` / `--` lines, or the FTP dialogue, or the output of the programs); `<id>.replay.log`
(the last `-F`); `<id>.talk/` (what `-K` received); `<id>.imp` (the messages posted from the hub, 60 days); `<id>.dup` (duplicates); `<id>.ctl` / `.ctl.out` (control commands);
`<id>.QWK` and `<id>.QWK.old`, `<id>.REP` in the inbound / outbound directories.

## What has been checked, and against what

| Part | Checked against | Not checked |
|---|---|---|
| Telnet call, profile `synchronet` | a **real Synchronet 3.19** hub: login, `D`, `U`, the hang up question, the refusal text `Invalid Conference <n>`, Zmodem both ways, Ctrl-A stripping | control messages (ADD, DROP ...) on a real Synchronet; other versions |
| Telnet call, profile `mk` | another MK system (tests: `hubpasstest`), Zmodem both ways; the transcript of that pass replays | |
| other BBS software (Mystic, Renegade, Wildcat, WWIV, Maximus ...) | nothing | no transcripts were available; write a profile with `-K` and test it with `-F` |
| `transport exec` | test scripts: success, nothing new, failure, hang (killed), missing program, `reply-error`, password only in the environment | a real FTP / SFTP / HTTP hub through your own scripts |
| `transport ftp` | a fake FTP server in the tests | a real FTP server |
| `transport ftps` | a fake server with TLS: certificate against a CA file, the name, session reuse, no TLS = refusal | a real FTPS server (OpenSSL 3 here); implicit FTPS (port 990) is not supported |
| `-K` talk, `-F` replay | a fake Telnet hub; the replay of a real MK pass (Zmodem steps) | a Zmodem transfer by hand in talk mode; a Synchronet recording |
| `-I` / `-J` / `-W` | a made-up packet and the sample BBS's area names | a real hub's `CONTROL.DAT` |
| hub names (DNS) | `localhost` | other names: a bug (the address was byte-swapped) was found and fixed in 2026-11 |

## Troubleshooting a pass

* **Exit 5:** Telnet: the hub did not answer (name, port, firewall).  FTP: the line `FTP with ... failed:` says why (login refused, TLS certificate not accepted, no AUTH TLS).  exec: the
  message names the program and its exit status or "was stopped".
* **Exit 6:** Telnet: the script stopped; the last `<<` lines of `<id>.hub.log` show what the hub said instead of what the script waited for.  Record the call with `-K` and replay it
  with `-F` while you change the profile.
* **Exit 7:** the reply packet was sent but the hub's answer matched `reply-error` (or lacked `reply-ok`).  Look at the end of the transcript.  The packet stays.
* **FTPS: "not for <name>":** the certificate names another host.  Use the name in the certificate in the `hub` line (an address is not a name), or `tls-verify no` for a hub you trust by
  other means.  **"not accepted":** give the CA with `tls-ca`.
* **The same packet is posted again and again by FTP:** the hub keeps it; use `ftp-delete yes`, or a hub that replaces it.
* **No conference numbers:** `mk -G<id> -I` after the first packet, then `-J` / `-J -W`.
