# mkbbs message bases: handoff

Paste this into the Claude Code session (or save it as notes in `~/mkbbs`). It summarizes the message-base backends built so far.

## Conventions every backend follows
- ES modules, Node 22. One file per base type, `class MessageXxx extends MessageAbstract` (`import { MessageAbstract } from "./MessageAbstract.js"`).
- Reads go through `BufferedFile` (`openExistingFile(path,"r")`, `seekFile`, `blockRead`, `fileSize`, `closeFile`), serialized with an internal `_withIo` chain. Writes use `node:fs`.
- Writers take a POSIX byte-range lock via a pluggable `locker` option: `createFcntlLocker` (needs the `koffi` npm package), `createPythonLocker` (python3 helper that holds the lock in its own process) or `createDefaultLocker` (koffi, else python). All opens and closes of the lock file run under a per-base `withMutex(key, fn)`, because closing any fd on a file drops the process's fcntl locks.
- Failed writes are rolled back. Inconsistent bases are refused for writes, with warnings in `warnings`.
- Text is returned with CRLF line breaks and kludges in `message.kludges`. Encoding options: `cp437` (default for DOS-era formats), `latin1`, `utf8`, `auto`. Unmappable characters are written as `?`.
- `startNewMessage()` resets `this.message`, then you set fields and call `writeMessage()`. `lastWriteWarnings` lists what was truncated or dropped.
- File-name case rule: check lowercase first, then uppercase, and create lowercase. Names are all-upper or all-lower, never mixed.
- Stable ids: `stableIdKind()`, `getStableId()`, `seekStableId()`. The default kind is "number". Squish uses "umsgid", Merlin uses "msgid", BlueWave uses "area/number" unless an area is set, and EZYCom numbers are positions and renumber on an external pack.
- Every writable backend has `createMessageBase()`. Synchronet and MessagePacket were added last. The user added it to `MessageAbstract.js` themselves.

## Files delivered (all in the scratchpad `out/` folder)
| Backend | Read | Write | Test |
|---|---|---|---|
| MessageSynchronet | yes | yes (not the mail base) | test-write.mjs, test-stableid.mjs, verify-crc.js |
| MessagePacket (FTN .PKT type 2/2+) | yes | yes | test-packet.mjs (new, create + basic round trip only) |
| MessageFido (`*.MSG`) | yes | yes | test-fido.mjs |
| MessageJAM | yes | yes | test-jam.mjs |
| MessageSquish | yes | yes | test-squish.mjs |
| MessageHudson (QuickBBS/RemoteAccess) | yes | yes | test-hudson.mjs (in t5) |
| MessagePCBoard | yes | yes | test-pcb.mjs |
| MessageQWK (MESSAGES.DAT and REP) | yes | yes | test-qwk.mjs |
| MessageMerlin | yes | yes | test-merlin.mjs, merlin-fsck.mjs |
| MessageEzycom (from MKMSGEZY.PAS) | yes | yes | test-ezycom.mjs |
| MessageBlueWave (INF/MIX/FTI/DAT, from MKOFFBWV.PAS) | yes | yes | test-bluewave.mjs |
| MessageWildcat3 (Wildcat 3.x, B-Tree Filer) | yes | no | test-wildcat3.mjs |

Also: `BufferedFile.js` (with a fix) and `MessageAbstract.js` (stable-id methods added).

## Decisions and caveats
- **Synchronet:** the writer follows the SMB v1.21 spec and has not been checked against smblib. Test on a copy and open the result with Synchronet or `chksmb`. `createMessageBase()` writes a 32-byte status header, empty `.sdt` and `.sid`, and empty `.sda` and `.sha` unless `hyperAlloc: true`. The `max_crcs`, `max_msgs`, `max_age` and `attr` offsets in that header are from the spec and not verified. The `MessageSynchronet.js` originally uploaded is an older 609-line version. The delivered one is 1175 lines.
- **EZYCom:** locks the area's MsgCount word. The MsgFast index is appended O_APPEND and is non-fatal. Not verified against a real base.
- **BlueWave:** the date written is `YY Mon DD  HH:MM:SS` (confirmed from `MKString.FormattedDate`: NNN is the month name). It also reads `DD Mon YY` and ISO forms, and option `dateStyle` ('mk', 'ftn', 'iso') resolves ambiguous dates. The two-digit-year pivot is 80, as in `MKString`. The `.UPL` reply packet is not handled. `NumPers` only grows when `message.toYou` is set or the To name is in `userNames`. A message into an area in the middle of the `.FTI` rewrites the `.FTI` and `.MIX`. `deleteMessage` leaves the text in the `.DAT`. Not verified against a real packet.
- **Wildcat 3:** the scan reads the `.DAT` only. A reviewed patch adding read-only index support (`checkIndexes()`, `indexFindNumber()`, `indexYours()`, `packUserName` and the Filer index reader) is at `scratchpad/wc3review/MessageWildcat3.js` with its test. It passes, but it is not merged into `out/`.
- **Wildcat 3 writing (review verdict):** feasible only for 3.5-format bases, by writing the `.DAT` with rollback and then regenerating all six `.IX` files to a temp file and renaming. It is unsafe while any Wildcat node has the base open, and the `.DIA` lock and flag protocol is untestable here. 3.0 bases would stay read-only because the key 4 build rule isn't in the kit. `PackUserName` is in the kit (`BTREEL.PAS`): 6-bit packing, 19 bytes. Run `checkIndexes()` on a real base first.
- **Not covered yet:** WWIV (the most worth adding), ProBoard, Telegard/Renegade/Mystic/Oblivion2, Spitfire/Searchlight/TriBBS/Opus-CBCS, SOUP and Blue Wave reply packets, Wildcat 4/5. Those suggestions come from memory, not from checked specs.

## Open items
- Merge the Wildcat 3 index patch into `MessageWildcat3.js`, or leave it separate.
- Optional: a default-address option for EZYCom address parsing (MKGLOBT style).
- A real sample of an EZYCom base, a BlueWave packet or a Wildcat-written base would let me verify those formats.
