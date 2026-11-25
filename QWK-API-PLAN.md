# QWK packets over the JSON API: plan

Status (2026-11-25): **plan agreed; phases 1 and 2 built** (phase 2: `MKQwkApi.pas`, `OfflineBuildPacket` in `MKOfflin.pas`, `GET /v1/qwk`, the packet with `HEAD`, the acknowledgement with compare-and-set, the ledger, expiry, the lock, the size limit; `tests/qwkapitest.py`; `HEAD` on the packet path makes the waiting packet like `GET`, it cannot know the size without making it; expired packets are dropped lazily at the node's next request, `mkmaint` does not touch them) and phase 1 (`mkapi`: methods per path, request bodies to a spool file, 413/411/408/100-continue, streamed binary answers, the log line with the bytes; `mkapitoken`: the `qwk` scopes need `-u`, the `"qwk"` limits of `apitokens.json` kept and shown by `mkapitoken limits`; `tests/apibodytest.py`).  The open points below are decided: `204` for nothing new, 7 days / 10 MB / 5 MB, an acknowledgement of an id that was acknowledged recently is `200` with `"already": true`, `HEAD` on the packet path reports without building.  Decisions of the sysop: nodes get only the conferences they subscribe to; the download is **two steps** (packet, then acknowledgement); there is a **maximum packet size**; `mk -G` gets an
**`http` transport** in the same piece of work.  This is the first use of the token field `user` and of the reserved `self:` idea (`API-PLAN.md`); it is also the first thing in the API that **changes** something, so it
has its own scopes and its own care.

## What it is

A QWK node (a BBS that takes its packet and leaves its reply: `NETWORKING.md` A and B) can do the exchange with **two HTTPS requests** instead of a scripted Telnet session, and an MK system can be a hub for it (the
`mklisten` port of the type `api`) or call one (`mk -G` with `transport https`).  Everything that makes the packet and posts the reply is the code that exists (`MKOffDL`, `MKOffQwk`, `MKOffXfer`, the import of `MKQwkImp`,
the user record's offline areas and last-read pointers); the API is a new door to it, not a second implementation.

## The identity

* A token **bound to a QWK node's user** (`mkapitoken add node5 -s qwk,qwk:reply -u "Node Five" -f 203.0.113.0/24`).  The user must have the **QWK Node** flag and not be deleted; a token that names no user, or a user
  who is not a QWK node, gets 403 on every `/v1/qwk` path.  Scopes: **`qwk`** (the packet, the acknowledgement, the node's settings) and **`qwk:reply`** (uploading a reply packet), so a node that only receives has no way to
  post.  `*` covers them.  A list of addresses (`-f`) is recommended.
* The API acts **as that user**: the areas it gets are the user's **offline area choice**, and its read and write access (security level, flags) decide what it may read and post, exactly as for `mk -Q`.  The user's
  packer settings and packet type (QWK or QWKE) are used.

## The paths

| | scope | |
|---|---|---|
| `GET /v1/qwk` | `qwk` | the node's settings: its BBS id, the conferences it gets (number, name), packet type, the maximum sizes, whether a packet is waiting (id, size, since) |
| `GET /v1/qwk/packet` | `qwk` | **step 1.**  Builds `<BBSID>.QWK` from the messages the node has not had.  `200`, `application/zip`, `Content-Length`, `Content-Disposition: attachment; filename="<BBSID>.QWK"`, `X-QWK-Packet: <id>`, `X-QWK-Messages: <n>`, `X-QWK-SHA256: <hex>`.  Nothing is marked as sent.  **`204`** (`X-QWK-Packet: none`) when there is nothing new.  A packet that is already waiting (not acknowledged) is **sent again, the same** (same id and content) unless `?rebuild=1` throws it away and builds a new one |
| `POST /v1/qwk/packet/<id>/ack` | `qwk` | **step 2.**  The node has the file: the last-read pointers move, the waiting packet is deleted.  `{"acknowledged": true, "messages": n}`.  An id that is not the waiting one: `404`; a packet that **expired**: `410` |
| `PUT /v1/qwk/reply` | `qwk:reply` | the body is the reply packet (`<BBSID>.REP`, a ZIP; `Content-Type: application/zip`; at most the reply limit).  The messages are posted into the areas (as the node, so its write access applies), its control messages (`ADD`, `DROP`, `RESET`, `CONTROL ON/OFF` ...) are carried out.  `200` with `{"status": "imported", "areas": [{"conference": 12, "area": 3, "posted": 4, "refused": 0, "reason": ""}], "commands": [...]}`; the same packet again: `{"status": "duplicate"}` |

Errors are the JSON errors of the API (`400` bad packet, `401`, `403`, `404`, `409`, `410`, `413` too big, `415` not a ZIP), plus `423 Locked` when another request of the same node is running.

## The two steps in detail

* **State** in `<BBS dir>/qwkapi/<user>/`: `waiting.QWK` and `waiting.state` (the id, the time, the message count, the SHA-256, and for each area the last-read value **before** and the value that the packet leads to).  One waiting packet
  for each node.  A lock file (`flock`) makes the requests of one node one at a time; message bases are locked as `OffExport` already does.
* **Acknowledgement is compare-and-set.**  The pointers move only when the node's last-read value is still the one in `waiting.state` (the `before` value): if the node also fetched by Telnet (`mk -Q`) or a sysop reset
  it in the meantime, the acknowledgement answers `409 {"error": "the node's pointers changed since the packet was made"}`, **changes nothing** and the packet is dropped, so a pointer never goes back.
* **Expiry:** a waiting packet that is not acknowledged within `keep_days` (default 7) is deleted at the next request of the node (and by `mkmaint`, a line in `MAINT.md`); its acknowledgement is `410`.
* **Size:** the packet is built with the **limit** (`max_packet`, default 10 MB, and the user's own packet limit: the smaller).  What does not fit stays for the next packet: the pointers of an acknowledged
  packet are only those of the messages that went.  The reply limit `max_reply` is 5 MB.

## The reply, once

* The body goes to a spool file as it arrives (the size is checked against `Content-Length` and as it is read: `413` as soon as it is over the limit), its **SHA-1 goes in a ledger** (`reply.ledger`, hash, time, status).
* The same SHA-1 again is `duplicate` and posts nothing, **also after a crash**: the ledger line is written (`started`) **before** the import and changed (`done`) after it.  A retry of a hash that is `started` but not `done`
  answers `409` ("an earlier upload of this packet did not finish: see the log"), because posting twice is worse than asking the sysop.
* The unpacking and the import are `OffUnpackReply` and the import of the QWK reply code; the packer is the user's.  A packet whose BBS id is not the node's is refused (`400`).

## What `mkapi` needs (phase 1)

* **Request bodies:** `Content-Length` (no chunked), a limit for each path, an idle timeout (60 s with no byte) and a total (10 minutes), the body written to a file and not kept in memory.  Version 1 paths still refuse a body.
* **Methods per path:** each path says which it takes (`GET`/`HEAD`, `POST`, `PUT`); anything else is `405` with `Allow`.  The read-only paths do not change.
* **Binary answers streamed from a file** (`Content-Length`, a `Range`-less plain copy; `HEAD` gives the headers).
* **Audit:** every writing request is a log line with the token id, the node, the path, the size and the answer (`api: node5 203.0.113.9 PUT /v1/qwk/reply 200 bytes=18234 posted=4`).
* The tokens: `-s qwk` and `qwk:reply` need `-u` (refused otherwise), `mkapitoken list` shows the user, the check of the QWK Node flag is made at every request (flag removed = access gone at once).
* Limits in `apitokens.json`: `"qwk": {"max_packet": 10485760, "max_reply": 5242880, "keep_days": 7}` (the defaults), not in `mklisten.json`.

## The `http` transport of `mk -G` (phase 4)

`mk -G<id>` with `hub https://host:2341` (or `http://` for loopback), `token <text>` or `token-env NAME` (never in a file that goes into a repository; the map file is mode 600 as for the FTP password), `tls-verify` / `ca-file` as for
`ftps`.  The order is the one of the other transports (`HUBS.md`): the reply packet and the packet are exchanged, and **the acknowledgement is sent only after the packet has been posted and the pointers saved** on our side, so a
failure between the two leaves the hub with the packet waiting (the next pass gets it again).  `204` is "nothing new".  The refusals of the reply (`status` of the answer, the per-area `reason`) feed `reply-error` / `reply-ok`
and the exit codes (`5`, `6`, `7` retries as now).  `-D` names the requests and sends none.  A small HTTP/1.1 client unit (plain and TLS through `MKTls`, bodies to and from files, the timeouts) is the new code.

## Tests

* **`mkapi`**: a body over the limit (`413`), a body that stops (`408`/closed), a wrong `Content-Length`, a method a path does not take (`405` with `Allow`), a binary answer byte for byte, `HEAD`.
* **The service**, on a private BBS with a node user (QWK Node flag, offline areas chosen, messages made with `msgput`): the packet has the messages (MESSAGES.DAT and the index files, the BBS id, the right conferences); the same
  `GET` again is the same packet; without an acknowledgement nothing moves; the acknowledgement moves the pointers and the next `GET` is `204`; a node whose pointer changed meanwhile gets `409` and nothing goes back; an expired packet is
  `410`; `?rebuild=1`; the size limit leaves the rest for the next packet; a user that is not a QWK node, a token without `-u`, a missing scope: `403`; two requests at the same time: one is `423`.
* **The reply**: a packet made with `qwkmsgtest` posts into the areas, the same packet is `duplicate`, a packet over the limit is `413`, something that is not a ZIP is `415`, a packet for another BBS id is `400`, a node without write access gets
  its refusal per area, the control messages work, a crash between the ledger line and the end (a test hook) leaves `409` on the retry.
* **The round trip**: two private BBSs, one with an `api` port and a node user, the other calling it with `mk -G` and `transport https` (TLS with the test certificate): the messages arrive, the pointers follow, a failure
  after the download and before the acknowledgement is repaired by the next pass, a refused reply is reported.

## Phases

1. `mkapi`: bodies, methods per path, streamed binary answers, the audit line, the tokens (`qwk` scopes need `-u`); tests of the machinery with a trivial test path.
2. The service unit (`MKQwkApi`): the node check, `GET /v1/qwk`, the packet and the acknowledgement with the state, the lock, the compare-and-set, expiry; tests.
3. The reply: spool, ledger, unpack, import, the answer; tests.
4. The HTTP client unit and the `http`/`https` transport of `mk -G`; the round-trip test.
5. Docs (`API.md`, `NETWORKING.md` A (a node can also use the API), `HUBS.md`, `MAINT.md` for the expiry), a note for `curl` scripts (a small example that takes a packet and acknowledges it).

## Open points (all four decided as proposed, 2026-11-24)

1. **`204` for "nothing new"** (a node script has to know it) rather than an empty packet?  (Proposal: `204`.)
2. **Seven days** to acknowledge before the packet expires, **10 MB** and **5 MB** as the defaults: right?
3. A node that has **no waiting packet and asks for the acknowledgement** of an id it had before (a lost answer): `404` (nothing waiting) or `200 {"acknowledged": true, "already": true}`?  (Proposal: `200` with `already`, for ids that were acknowledged in the last `keep_days`, so a retry of a lost answer is harmless.)
4. Do you want **`GET /v1/qwk/packet` to answer `HEAD`** (size and message count without building the file)?  (Proposal: yes, it builds nothing and says what would be built.)
