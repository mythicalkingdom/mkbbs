# JSON API: plan

Status (2026-11-24): **phases 1 and 2 built** (`mkapi`: HTTP, TLS, tokens and scopes and every endpoint of the table below in `MKApiData.pas`; the `api` port type; `mkapitoken`; `tests/apitest.py`); phase 3 (`API.md`) to do.  Decisions: `users:private` is a reserved scope name; deleted users are hidden unless asked for; message text is deferred.  Decisions of the sysop: first audience is the **sysop** (scripts, dashboards, monitoring), but the design **keeps the caller option open** (offline messages, BBS-to-BBS later);
**version 1 is strictly read-only**; **TLS is included from the start**.  (The web UI was dropped earlier; this is only the API.)

## Shape

* **A new port type `"api"` in `mklisten.json`**, served by a new program **`mkapi`** that `mklisten` starts for each connection, the way it starts `mk` (one process per request: no shared state, a crash
  hurts nobody).  `mkapi` speaks **HTTP/1.1 with `Connection: close`** and JSON only; no keep-alive, no chunked requests, no uploads (v1 has only GET).  Binds to `127.0.0.1` unless the port says otherwise.
* **TLS** with the native TLS we have (`MKTls`, `-Y` style: the session process does the handshake; cert and key as for the telnet TLS ports); a port that is not on loopback **must** have TLS (or `"insecure": true`
  said out loud, which logs a warning).  A reverse proxy in front works too (`PROXY` is read as it is for the telnet ports).  Missing libssl: the port is skipped with the "NOT opened" line, as now.
* **Versioned paths** `/v1/...`; errors are JSON `{"error": "..."}` with the right status (400, 401, 403, 404, 405, 429, 500).  Only GET and HEAD; anything else is 405.  No CORS headers.
* Times are ISO 8601 (local time with offset), numbers are numbers, text is UTF-8 (CP437 names converted).

## Tokens: `apitokens.json`

In the BBS directory, **mode 600**, never in `mklisten.json`.  Written only by **`mkapitoken`**; `mkapi` reads it on every request (so adding or revoking needs no restart).

```json
{ "tokens": [
  { "id": "dash", "hash": "sha256:9f2c...", "scopes": ["status", "nodes", "stats"], "created": "2026-11-24T10:00:00-05:00",
    "expires": "2027-11-24", "from": ["127.0.0.1", "10.0.0.0/8"], "note": "the dashboard",
    "user": "" } ] }
```

* A token is `mkapi_` + 43 random base64url characters (256 bits).  It is shown **once**, by `mkapitoken add`; only its SHA-256 is kept (a random token needs no slow hash).  Compared in constant time.
* `mkapitoken add <id> -s scope,scope [-e date] [-f address,net] [-u "User Name"] [-n note]`, `list` (never shows tokens, shows scopes, expiry, last use), `revoke <id>`, `rotate <id>`.  `last used` is kept
  in `apitokens.use` (a separate file, so the token file is not rewritten at each request).
* **Scopes** (v1, read-only): `status`, `nodes`, `events`, `mailer`, `stats`, `calls`, `areas`, `users` (the user list without passwords, hashes or private fields), and `*` for all.  Checked per endpoint.
* **The caller option (reserved, not built):** `"user"` names a BBS user **by name** (names survive `mkuserpack`, numbers do not).  A token with a user acts as that user: its scopes are cut down to what the
  user's security level allows, and the scope family **`self:`** (`self:mail`, `self:offline`, `self:profile`, later `self:send`) is for such tokens only.  v1 accepts and stores `user` but gives such a token **no
  endpoint** (403), so nothing about it can be misused before it is designed; the file format does not change when it is turned on.  BBS-to-BBS later fits the same way: a token whose user is a QWK/net node.
* **Failed tokens** (no token, unknown, expired, wrong address, missing scope) exit `mkapi` with the errorlevel the **login guard** counts, so repeated bad tokens block the address as bad passwords do
  (default 5 in 10 minutes); 401/403 bodies never say which part was wrong.  Every request is logged (token **id**, address, path, status) in the BBS log; never the token.

## Endpoints, version 1

| GET | scope | what |
|---|---|---|
| `/v1` | none (token needed) | version, the BBS name, the paths below |
| `/v1/status` | `status` | BBS name, version, uptime of `mklisten`, nodes in use / total, callers today, the next event |
| `/v1/nodes` | `nodes` | each node: number, port label, user name (or "-"), activity, since, address (as `mkmon` shows) |
| `/v1/events` | `events` | the events: number, time, days, action, status, last run and result, next run (from `events.info` / `events.run`) |
| `/v1/mailer` | `mailer` | what the mailer reports on its control socket: links, queued, last session (read only) |
| `/v1/stats?from=&to=&by=` | `stats` | what `mkstats` shows: totals, or by day / hour / node / label / port / user / result / type |
| `/v1/calls?limit=&since=` | `calls` | the last calls (the statistics lines) |
| `/v1/areas/messages`, `/v1/areas/files` | `areas` | areas with their numbers of messages / files, last date, sizes |
| `/v1/areas/files/{area}?q=&limit=&after=` | `files` | the files of one area: name, description (from `files.bbs`, continuation lines joined with a line feed), size, date; a file the list does not name has description null; paged by name (`next` is the last name), `q` searches names and descriptions |
| `/v1/users?q=&limit=&after=` , `/v1/users/{name}` | `users` | name, city, security level, calls, last call, flags; paged; no password, no phone numbers unless the token also has `users:private` |

Everything comes from files and sockets that exist (`stats/*.tsv`, `events.info`, node files, the mailer socket, the message and file bases opened read-only); `mkapi` writes nothing but its log line and the
`apitokens.use` line.  Large answers are paged (`limit` default 100, most 1000; `next` cursor in the answer).

## Phases

1. **Core:** `mkapi` (HTTP parser with size and time limits, JSON writer, TLS, token check with scopes, the log line, `/v1`, `/v1/status`), the `"api"` port type in `mklisten` (+ `mklisten -t` checks, the TLS rules), `mkapitoken`; tests (real requests over a socket and over TLS: no token, bad token, expired, wrong address, wrong scope, good token; the login guard blocks after bad tokens; the token file is mode 600 and holds no plain token).
2. **Data endpoints** one by one with tests against the private fixture: nodes, events, stats, calls, areas, users, mailer.
3. **Docs** `API.md` (every endpoint with an example, curl lines, the scopes, the token tool, the TLS set-up, `mklisten.json` example), a systemd/`make install` note, `MKBBS.md` and the deb.
4. **Later, not planned here:** writes (`events:run`, `mailer:poll`, `nodes:kick`), the `self:` family, BBS-to-BBS.

## Open points

1. `users:private` (phone numbers and addresses) in v1, or never in the API?  (Proposal: never in v1; the scope name is reserved.)
2. Should `/v1/users` list **deleted** users (flag only) or hide them?  (Proposal: hide, with `?deleted=1` for the `users` scope.)
3. Does `mkapi` read a **message's text** at all?  (Proposal: not in v1 at all; counts and headers of areas only, because message text is the first thing a caller token will need and deserves its own design.)
