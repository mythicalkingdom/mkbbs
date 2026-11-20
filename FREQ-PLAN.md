# FTN file requests (FREQ): plan

Status: **built except the deferred parts** (2026-11-19): phases 1-8 done, see the notes at the phases.  Update requests (`+time` / `-time`) were added afterwards (all three sides).  Not done: sending the answer in the same session that brought the request (needs a second batch in mkbink's session engine).  Written 2026-11-19.  Decisions marked *(decided)* come from the discussion with the
sysop; the rest are proposals to confirm.

File requests let one system ask another for files by name.  Two directions:

* **Receive side** (we answer a request): a remote system sends us a `.req` file; we find the files it may have and send
  them.
* **Send side** (we ask): a netmail with the file-request flag is turned into a `.req` file for the remote system; the
  files come back in the ordinary inbound.

Two repositories are involved: **mkbink** (the binkp mailer, separate repo) and **mk-fpc** (this one: `mktoss`, the
configuration, a new hook utility).  They talk through files and one hook command, as they already do for `on-inbound`.

## The format (FTS-0006)

* The request file is plain text, one request per line:

  ```
  this.arc !that
  nodelist.*
  ```

  `name` or `name !password`: a single space, `!`, the password (**6 characters or fewer**), then CR.  Wildcards `*` and `?`
  are part of the name.  The password is *transaction level*: it goes with that request, as opposed to the session password
  of the binkp login.
* Its name is the destination's net and node in hex, `.REQ`: for 12/2 it is `000C0002.REQ`.  In the BSO outbound it sits
  with the `.flo`/`.clo` files of that node (in the zone's and point's directory where they apply).
* **Update requests** (the rest of the line format, from the spec text the sysop supplied 2026-11-19): a name may be followed
  by a sign and a time, `+` or `-` and a UNIX-style decimal number of seconds (UTC).  `+` asks for the files that match the name
  and are **newer** than that time; `-` for the files that match and are dated **up to and including** it.  The sign is
  required.  Complete action line:

  ```
  <filename>[<space>!<password>][<space><+/-><time>]<cr>        e.g.   NEWOPUS.* +599634000
  ```

  (The spec's example says 1 January 1989 00:00 on the East Coast and "GMT+06"; 599634000 is 05:00 UTC, which is 00:00 at
  GMT-5.  The number is what counts: seconds since 1970-01-01 UTC.)
  **Done after the first version** *(2026-11-19)*; the text below was the plan for it.  Written first: only `name [!password]`.  When it is added: the
  send side takes `+time` / `-time` tokens after the name (and password) in the netmail subject and in `mkbink queue -R`
  (`-time` must not be read as an option there); the receive side passes the sign and time to the hook as part of the request
  line, and `mkfreq` compares the file dates.  A line with a sign and time that the first version does not understand is
  **answered with a NOTE** ("update requests are not supported"), not treated as a plain name.
* Be strict in what we write (the spec ends a line with CR; we write CR LF, because readers that use ReadLn need the LF and
  the others skip it; names as given; no password over 6 characters) and liberal in what we read
  (lines end in CR, LF or CRLF; names are not case sensitive; ignore what follows a name or password that we do not
  understand).

## Send side: a netmail becomes a `.req`

In `mktoss` (mk-fpc), at the point where `ScanNetArea` decides what to do with a message that is not sent and not for us.

1. A netmail with the **file request attribute** (`IsFileReq`, already read and stored by the tosser) addressed to a system
   we can reach is not packed.  Its subject is parsed: names are blank separated; a token that starts with `!` is the
   password of the name before it.  `THIS.ARC !THAT NODELIST.*` gives the two lines above.
2. The lines are appended to the node's `.req` in the BSO outbound (created if missing; names the node already has are not
   written twice).  The file is written through the same lock and naming rules as `mkbink queue`: **the BSO layout stays
   known to mkbink only**, so the write is a new `mkbink queue -R` (request) call, not a direct file write by `mktoss`.
3. The message is marked **sent** (and killed when it has Kill/Sent), exactly as for a message that was packed.  A log line
   says what was requested from whom.
4. Refusals, all logged and the message left unsent so the sysop sees it: a password longer than 6 characters, no name in
   the subject, a destination we have no route or link for, a name longer than the limit.
5. The call: the flavour of the message (immediate, crash, normal, hold, direct) decides, as for other mail.  Mailer
   behaviour on `.req` is below.
6. The answer arrives as ordinary files in the inbound.  They are not specially tossed (they are not packets): the sysop
   gets them as with any file sent to us.  *Optional later:* a "requested files" directory, and a netmail to the sysop when
   files that match an earlier request arrive.

## Receive side

### In mkbink (separate repository)

* **Receiving a `.req`.**  A `.req` that arrives in a session (binkp sends it as an ordinary file) is not a file for the
  inbound: it is a request.  It is read when the file is complete and the session still runs.
* **The hook.**  New settings key `on-freq <command>` (the sibling of `on-inbound`), written by `mkbinkcfg`.  mkbink runs it
  with the request, waits (`HookTimeout`), and takes its answer.  Interface below.
* **Answering.**  The files the hook names are queued for the requester and sent **in the same session** when it is still
  running (the outbound is looked at again, as binkd does), otherwise at the next call.  Files are sent the way queued files
  are: after the transfer they are kept, deleted, or truncated as the hook says (`^` / `#` in the flow line, as `mkbink queue`
  already does).
* **Sending a `.req`.**  A `.req` in the BSO outbound counts as mail waiting (so the mailer calls), and is sent as an ordinary
  file.  After the remote has it (M_GOT) it is removed from the outbound.  `mkbink queue -R -t ADDR name [!password] ...`
  appends request lines to the right `.req`.
* **Policy in the settings file:** `freq yes|no` (answer requests at all), `freq-unsecure yes|no` (answer sessions without a
  password; default no), and a size and count limit per session.  The limits are enforced by mkbink as well as by the hook:
  mkbink is the one that knows how much has been sent.
* **Not in scope:** binkd's M_GET-based requests, GZ/ND/NDA, anything but the `.req` of FTS-0006.

### The hook interface (the contract between the two repositories)

mkbink calls (arguments, not a shell line, so nothing is interpreted):

```
mkfreq <requester address> <secure|unsecure> <request file> <answer file>
```

* **Environment:** `MK` = the BBS configuration (mklisten already gives mkbink this).
* **Request file:** a copy of the `.req` as received.
* **Answer file** (written by the hook, one line per entry, tab separated):

  | Line | Meaning |
  |---|---|
  | `SEND<TAB>path` | send this file, keep it |
  | `SEND<TAB>path<TAB>^` | send it and delete it after (a file made for this request) |
  | `NOTE<TAB>text` | a line for the answer netmail: found, refused, why |

  Paths are absolute.  The hook never names a file outside the paths the BBS gives it.
* **Exit status:** 0 answered (also when nothing was found), 1 the hook failed (mkbink logs it and sends nothing), the
  session is never refused because of a hook failure.
* mkbink queues the `SEND` lines for the requester and passes the `NOTE` lines back for a netmail (below).
* **SRIF (FSC-0086)** is the standard answer-file layout used by many request processors.  It is *not* what is proposed
  here: our hook is ours.  Writing an SRIF translator later is possible if an existing processor is to be used.

### The hook utility: `mkfreq` (mk-fpc repository)

A separate program that uses the BBS's file area list, so mkbink stays ignorant of it:

1. **Who is asking.**  The requester's address is matched to the link (echo system / mailer link).  What it may have is a
   **security profile**: the link's own request security (`MailLinkType.ReqSec`, level and flags; level 0 means the global one)
   or the global **file request user** (`MailerCfgType.ReqSec`).  An unsecure session gets the profile only when the sysop
   allowed it, and in any case never the password-protected names.
2. **Magic names.**  `ReqMagicFile` names a text file of magic names and what they mean (`NODELIST  /bbs/nodelist/nodelist.*`
   with an optional password; `FILES` and `ALLFILES` are generated from the file areas).  A magic name wins over an area
   search.  Its password is the transaction password of the request line.
3. **File areas.**  For a plain name or wildcard, each file area whose **"Allow file requests"** option is set, and whose
   security the profile satisfies, is searched (`files.mk` for the areas, the area's file list or directory for the files).
   Names are not case sensitive.  Offline, hidden and "new files only" areas are skipped.
4. **Passwords.**  A line `name !pw` is accepted for a name that is password protected only when `pw` matches (not case
   sensitive; passwords longer than 6 characters are compared in full on receive, so a remote that uses more still works).  A
   wrong or missing password for a protected name is a `NOTE`, not a file.
5. **Limits.**  `ReqMaxFiles` and `ReqMaxKb` (global, and per link where set) count what the hook returns for one request.  What
   is over the limit is not returned, with a `NOTE`.
6. **The answer.**  A `SEND` line per file; a `NOTE` line per request line that found nothing, was refused, or was cut off.
   A request that found nothing at all is still *answered* (a netmail saying so is the courtesy; see below).
7. **Logging.**  One line per request: who, what was asked, what was sent or refused.

### The answer netmail

When the hook returned `NOTE` lines, `mktoss` (or `mkfreq`, writing through the same message API) posts a **netmail to the
requester**: a short list of what was found and what was not, with the reasons.  Sent as an ordinary netmail by the tosser's
next scan.  This is optional per link (a setting), default on.

## Configuration changes (mk-fpc)

Everything lives in `Mailer.Mk` and the area records and is mirrored in `bbsconfig.json` (the standing rule).

* **Already there, reserved for this** (`Mailer.Mk`, `MKGlobT.pas`): the flag `mcFileReq` ("answer file requests"), the
  global `ReqSec` (request user), `ReqMagicFile`, `ReqMaxFiles`, `ReqMaxKb`, `ReqAttr`, and `ReqSec` per link.  The editing
  screens must be filled in (they exist as reserved fields only).
* **New:**
  * per **file area**: the option **"Allow file requests"** (a bit in the area's options; JSON mirrored).
  * `ReqAttr` bits: answer unsecure sessions; send the answer netmail; whether magic names may be asked by name only.
  * per link: a request password for the whole link, if the sysop wants one besides the per-name passwords (optional).
* `mkbinkcfg` writes `freq`, `freq-unsecure`, the limits and `on-freq <mkfreq>` into the settings file; the line is not written
  while the flag is off.  A hook given by hand in `Mailer.Mk` wins, as for `on-inbound`.
* `mklisten` needs nothing new: it already runs `mkbink` with `MK` set.

## Phases

1. **Spec and contract** (this document) and the settings keys in mkbink's links file format.  No behaviour yet.
2. **Send side first** (mkbink part done 2026-11-19, in the mkbink repo, not committed: `queue -R`, `.req` sent and removed, `tests/freqtest.py` 18 checks; the `mktoss` conversion of the netmail done 2026-11-19: `FileRequest` in `MKToss.pas`, `tests/tosstest.py` +6 checks; **phase 2 is complete**), because it can be tested end to end with what exists:
   `mkbink queue -R` (request lines, locking, no duplicates) → `mkbink` treats a waiting `.req` as mail and sends it →
   `mktoss` converts the netmail.  Test with two mkbink instances: the second one only logs what the `.req` said (a stub
   hook).
3. **Receive side in mkbink** (done 2026-11-19 in the mkbink repo, uncommitted: `freq`, `freq-unsecure`, `on-freq`, `freq-max-files`, `freq-max-kb`, `DoFreq`, `tests/freqtest.py` 29 checks; answers are queued as **hold mail** (decided 2026-11-19: the requester picks them up; we do not call for them), **not in the same session**: the engine has one batch per session, see mkbink `NOTES.md`): read the `.req`, run the hook, queue the answer, same-session sending, limits, policy keys.
   Test with a stub hook that returns fixed paths.
4. **`mkfreq`** (done: `src/MKFreq.pas`, `tests/mkfreqtest.py` 24 checks; the `faFreq` bit of the area, `GetFileFreq`): area search, magic names, security profile, passwords, limits, notes.  Test on the private copy of the sample
   BBS (its file areas), with all the refusal cases.
5. **Configuration screens and JSON** (done: `EchoMail > File Requests`, link field, area box, `mkbinkcfg` keys; JSON needed nothing new, the fields were in the records; `tests/mailertest.py`): for the reserved fields and the new bits; `mkbinkcfg` writes the keys; tests in the
   existing mailer config tests.
6. **Answer netmail** (done: `mkfreq` writes a note, `PostFreqNotes` in `mktoss` posts it; only when something was not sent): and the optional "requested files" notice.
7. **Round trip test** (done: `tests/freqroundtrip.py`): two MK systems; the first sends a netmail with the flag and a password; the second answers from its
   file area; the files arrive in the first one's inbound; the wrong password and an over-limit request give the right notes.
8. **Docs** (done: `NETWORKING.md`, `TOSSER.md`, `MKBBS.md`, mkbink `NOTES.md`): `NETWORKING.md` (a Fido file requests section), `TOSSER.md`, mkbink's `NOTES.md`.

## Tests (summary)

* `.req` writing: names, passwords (and the 7-character refusal), no duplicates, CR line ends, the right file name for
  zone, net, node, point.
* `.req` reading: CR, LF, CRLF; case; garbage after a name; a password with and without the right value.
* Policy: unsecure sessions, `freq no`, limits, a hook that fails, a hook that is too slow.
* `mkfreq`: every refusal reason; wildcards; magic names; areas that are hidden or not allowed; security level and flags.
* End to end: the round trip above.

## Open questions

1. **Same-session sending.**  Answered by looking at the code: the session has one batch (`TransferComplete`), so a second batch
   (binkd's way) has to be added to the protocol engine.  Left for later; the answer goes with the next call.
2. **Who writes the answer netmail**, `mktoss` or `mkfreq`?  Proposal: `mkfreq` writes a note file next to the answer and
   `mktoss` posts it, so only one program writes to the message bases.
3. **Per-name passwords for the files in an area:** is a password per *area* enough, or per file?  Proposal: per magic name and
   per area (a new field), not per file.
4. **What counts as "the same request"** for the no-duplicates rule on the send side: the same name and password in an
   unsent `.req` of that node.
5. **Attach-style outbound** (mkbink's FrontDoor-style mode): the netmail with the request flag is left alone today.  Leave
   it so: file requests are BSO only for now.
6. **Update requests** (`+time` / `-time`): done (mkbink `queue -R`, `mktoss` subject parsing, `mkfreq` file dates).
