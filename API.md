# The JSON API

A read only API for the sysop's scripts, dashboards and monitoring: what the BBS is doing now (nodes, events, the mailer), what it did (calls, statistics) and what it has (areas, files, users).
Version 1 **only reads**: `GET` and `HEAD`; nothing can be changed through it.  The design and its reasons are in `API-PLAN.md`.

```
 your script ──HTTPS──▶ mklisten (port of the type "api") ──▶ mkapi (one process for each request) ──▶ the BBS files
                          bad tokens: the login guard           token file apitokens.json, mode 600
```

## Set it up

1. **A port in `mklisten.json`** (the example file has one on 2340):

   ```json
   { "port": 2340, "type": "api", "config": "/bbs/ra" }
   ```

   It listens on `127.0.0.1` unless you say `"bind"`.  Any other address **needs TLS** (below), or `"insecure": true` if you really want tokens to travel in the clear (the log warns).  The port stays open while
   an exclusive event runs.  `"maxperip"` defaults to 10.  `mkapi` is started from the directory of `mk` (or named with `"mkapi": "/path"` at the top level).

2. **A token** for each program that will call:

   ```
   mkapitoken -c /bbs/ra add dash -s status,nodes,stats -n "the dashboard"
   ```

   prints the token **once** (`mkapi_` and 43 characters).  Only its SHA-256 is kept, in `apitokens.json` in the BBS directory (mode 600).  Lose it and `rotate` makes a new one.

3. **Call it:**

   ```
   curl -H "Authorization: Bearer mkapi_..." http://127.0.0.1:2340/v1/status
   ```

## Tokens: `mkapitoken`

```
mkapitoken [-c config dir] add ID -s scope,scope [-e yyyy-mm-dd] [-f address,net] [-u "User Name"] [-n note] [-q]
mkapitoken [-c config dir] list | revoke ID | rotate ID [-q]
```

* `-e` the last day the token works (none: no end).  `-f` the addresses it may be used from (`10.0.0.0/8` nets understood; none: anywhere).  `-q` prints only the token, for scripts.
* `list` shows scopes, expiry, addresses, the last use (time and address) and never a token.  `revoke` and `rotate` act at once, **no restart**: `mkapi` reads the file at every request.
* `-u "User Name"` names a BBS user **by name**.  It is stored for later (callers using the API as themselves); in version 1 such a token has no endpoint of its own, only the scopes it lists.  The `self:...`
  scopes are for these tokens only and have no endpoint yet.

**Scopes** (an endpoint needs its scope; `*` is all of them):

| scope | for |
|---|---|
| `status` | `/v1/status` |
| `nodes` | `/v1/nodes` |
| `events` | `/v1/events` |
| `mailer` | `/v1/mailer` |
| `stats` | `/v1/stats` |
| `calls` | `/v1/calls` |
| `areas` | `/v1/areas/messages`, `/v1/areas/files` (the areas with their counts) |
| `files` | `/v1/areas/files/<area>` (the files themselves: names and descriptions) |
| `users` | `/v1/users`, `/v1/users/<name>` |
| `users:private` | reserved: nothing in version 1 gives phone numbers or addresses |

A request with no token, a token that is not known, expired or used from the wrong address gets **401**, a token without the scope **403**.  The answer never says which check failed.  Both count for the **login guard**
of `mklisten` (`MKLISTEN.md`): five of them from one address within ten minutes block the address for an hour (the machine itself, `127.0.0.1`, is never blocked unless you change `allow`).

## What every answer looks like

* JSON, UTF-8 (the BBS's CP437 text is converted), `Content-Type: application/json; charset=utf-8`, with `Content-Length`, `Cache-Control: no-store` and `Connection: close`.  One request for each connection.
* Times are ISO 8601 with the zone (`2026-11-24T10:15:00-05:00`), days are `yyyy-mm-dd`.
* Errors: `{"error": "..."}` with 400 (bad request or parameter), 401, 403, 404, 405 (anything but GET and HEAD; `Allow: GET, HEAD`), 414, 431.  `HEAD` gives the headers and the length.
* Large answers are paged: `limit` (default 100, at most 1000 or 500 where it says so) and `after`; `next` is what to give as `after` for the following page, `null` on the last one.

## Endpoints

### `GET /v1`
The token's id and scopes, the name of the BBS and the list of paths.  Needs any good token.

### `GET /v1/status`  (`status`)
```json
{ "bbs": "Mythical Kingdom", "software": "Mythical Kingdom Bbs - Version 0.01 Alpha", "time": "2026-11-24T10:15:00-05:00", "nodes": { "in_use": 2 } }
```

### `GET /v1/nodes`  (`nodes`)
The nodes in use, as `mkmon` shows them: `node`, `user`, `handle`, `activity` (browsing, file transfer, messages, door, chat, questionnaire, ready, offline mail, connecting, logging in), `port`, `type`, `baud`, `address`,
`since`; and `count`.

### `GET /v1/events`  (`events`)
`available` (false when `mklisten` has no events), `new_logons_refused`, `callers`, `queued`, `running`, `stale` (`mklisten` has not refreshed the file for 15 seconds) and `events`: `number`, `enabled`, `time` (`HH:MM`),
`days` (`sun`..`sat`), `state` (idle, waiting, retry, running, disabled), `exclusive`, `next_in_minutes`, `last_run`, `last_result`, `errorlevel`, `action`.

### `GET /v1/mailer`  (`mailer`)
What the mailer (`mkbink`) says on its control socket; nothing is sent to it.  `{"running": false}` when there is none, otherwise `me` (address, name, sysop, started, port, version), `statistics` (calls, ok,
failed, answered, bytes and files sent and received), `links` (address, name, host, flags, poll minutes, state, failures, `next_call`, `last_result`, waiting files and bytes, `last_call`) and `sessions` (id, direction,
remote, system, sysop, location, started, state, bytes and files).

### `GET /v1/stats?from=&to=&by=`  (`stats`)
What `mkstats` reports, from `stats/YYYY-MM.tsv`.  `from` and `to` are days (default: the first of this month to today).  `by` is `day`, `hour`, `node`, `label`, `port`, `user`, `result` or `type`.

```json
{ "from": "2026-11-01", "to": "2026-11-30", "files": 1,
  "totals": { "calls": 412, "logons": 380, "failed": 9, "no_logon": 23, "minutes": 5120.4, "upload_files": 14, "upload_k": 3300, "download_files": 98, "download_k": 41200, "messages": 77,
              "callers": 41, "longest_minutes": 85.2, "busiest_hour": 21, "busiest_day": "2026-11-14" },
  "by": "user", "rows": [ { "user": "Ann", "calls": 30, "logons": 30, ... } ] }
```

### `GET /v1/calls?limit=&since=`  (`calls`)
The last calls, newest first (`limit` default 50, at most 500).  `since` is a day or a unix time.  Each: `start`, `end`, `node`, `type`, `label`, `port`, `address`, `user`, `result` (ok, failed, nologon), `seconds`,
`upload_files`, `download_files`, `upload_k`, `download_k`, `messages` and, for a failed log-on, `reason`.

### `GET /v1/areas/messages`  (`areas`)
Every message area: `number`, `name`, `type` (local, echomail, netmail), `base` (the kind of base: H Hudson, S Squish, J JAM, F Fido `*.msg`, M Merlin, Y Synchronet), `messages`, `highest` (null when the base cannot be opened).

### `GET /v1/areas/files`  (`areas`)
Every file area: `number`, `name`, `available` (false when its directory is not there), `files` (on the disk), `listed` (in `files.bbs`), `bytes`, `newest`.

### `GET /v1/areas/files/<area>?q=&limit=&after=`  (`files`)
The files of one area, sorted by name without regard to case: `name`, `description` (from `files.bbs`; continuation lines are joined with a line feed; `null` for a file the list does not name), `size`, `date`.
A file the list names that is not on the disk is left out.  `q` searches names and descriptions; `after` is the name the page before ended with (`next`).  An area that is not there: 404.

### `GET /v1/users?q=&limit=&after=&deleted=1`  (`users`)
`users`, `count`, `next`.  Each: `number` (the position in the user file: it changes when `mkuserpack` packs the file, see `MAINT.md`), `name`, `handle`, `city`, `level`, `calls`, `first_call`, `last_call`, `upload_files`, `download_files`,
`upload_k`, `download_k`, `messages`, `deleted`, `qwk_node`.  No passwords, no phone numbers, no street addresses.  **Deleted users are hidden** unless you ask with `deleted=1`.  `q` searches names and handles.

### `GET /v1/users/<name>`  (`users`)
One user by name (any case, URL encoded: `/v1/users/Mark%20May`); 404 when there is none.

## TLS

* **Native:** `"tls": true` on the port with the `"tls"` section of `mklisten.json` (certificate chain and key, the same ones as for the TLS telnet ports; needs the OpenSSL library `libssl`).  Without the library or
  the files the port is **not opened** and the log says why; the other ports run.

  ```json
  "tls": { "cert": "/etc/letsencrypt/live/bbs.example.org/fullchain.pem", "key": "/etc/letsencrypt/live/bbs.example.org/privkey.pem" },
  "ports": [ { "port": 2341, "type": "api", "tls": true, "config": "/bbs/ra" } ]
  ```

  `curl --cacert fullchain.pem https://bbs.example.org:2341/v1/status -H "Authorization: Bearer ..."`
* **A front end** (nginx, stunnel, HAProxy) on the same machine: keep the api port on `127.0.0.1` and, so the log and the token's address list see the real caller, send the PROXY protocol and say `"proxy": true`
  (this needs `"bind": "127.0.0.1"`, as for the other ports).

## Logging, and what to watch

* Every request is one line in the `mklisten` log: `api: <token id> <address> GET /v1/status 200`.  The token itself is never logged.  A line `api request ended (exit 88)` is a refused token.
* `apitokens.use` (next to the token file) has the last use of each token; `mkapitoken list` shows it.
* The token file only has hashes, but it names who may call and from where: it is in the BBS directory, so a backup of that directory holds it; keep such copies private.  Give each program its own token with the least scope it needs.
* Tokens do not expire unless you set `-e`; rotate the ones of people who leave.

## Not in version 1

Any write (running an event, polling a link, disconnecting a node), message text, the `self:` calls of a caller who acts as himself, and BBS-to-BBS calls.  The token file already has the `user` field for the callers
who come later, and the plan is in `API-PLAN.md`.
