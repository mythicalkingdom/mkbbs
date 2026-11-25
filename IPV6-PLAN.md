# IPv6 (plan, 2026-11-25)

Today everything that opens a network connection is IPv4 only: the listener (`fpSocket(AF_INET)`, `StrToNetAddr`, `TInetSockAddr` in `MKListen.pas`) and the three clients `MKComClient` (Telnet scripts of the QWK hubs), `MKFtp` (FTP / FTPS hubs) and `MKHttp`
(HTTP / HTTPS hubs), which also resolve names with `ResolveHostByName` (IPv4 only).  Already ready for IPv6: the PROXY header parser (`MKProxy.pas` takes `TCP6`), `mkbbsssh` (writes `PROXY TCP6` for an IPv6 caller), the login guard's default
allow list (`::1`), and the node files (`addr` is a string).  The binkp mailer `mkbink` is a separate repository (`../mkbink`): its sockets are all in one unit, `src/lib/binksocket.pas` (IPv4 only the same way), and it is done in phase 5 below, together with the nodelist host lookup of this repository (`MKNodeHost`, `mkbinkcfg`).

## What it should do

* **Listening:** a port with no `bind` (or `"bind": "::"`) listens on **IPv4 and IPv6** (one dual-stack socket, `IPV6_V6ONLY` off); `"bind": "0.0.0.0"` stays IPv4 only, `"bind": "::1"` / `"127.0.0.1"` loopback, any literal address
  binds that one.  If the kernel has no IPv6 the listener falls back to IPv4 and says so in its log.  `mklisten -t` accepts and prints the addresses.
* **Caller addresses** are text in their usual forms (`192.0.2.7`, `2001:db8::7`); an IPv4 caller on a dual-stack socket is shown as `192.0.2.7`, not `::ffff:192.0.2.7`, so counts (`maxperip`), the login guard, the log, `mkmon` and the statistics see one address for one machine.
  A zone (`fe80::1%eth0`) is cut off.
* **Login guard:** `allow` takes IPv6 addresses and nets (`2001:db8::/32`) as well as IPv4; the block list works on the normalised text.
* **"Loopback only" rules** (a sysop port, an `api` port without TLS, a `proxy` port) accept `127.0.0.1` and `::1`; the default bind of those ports stays `127.0.0.1`.
* **Clients:** names are resolved with `getaddrinfo` (IPv6 and IPv4, in the order the system says; each address is tried with a timeout until one connects); `[2001:db8::1]:8080` in hub URLs and `host`/`port` settings take IPv6 literals; FTP uses `EPSV` (and `EPRT`) in place of `PASV`/`PORT` when the control connection is IPv6, and falls back to `PASV` on IPv4 as now; the TLS name check is unchanged (it is about the name, not the address).
* **`mkmon`** has a wider address column (an IPv6 address is up to 39 characters), the monitor's own sockets stay Unix sockets.
* **`mkcheck`** says which addresses a listener port would bind, warns about an IPv6 literal in `bind` on a system without IPv6, and about `loginguard.allow` entries it cannot read.
* **Docs:** `MKLISTEN.md` (bind), `NETWORKING.md` / `HUBS.md` (hub hosts and URLs), `API.md`, `SSH.md`; the header comment of `MKListen.pas` and `mklisten.example.json`.

## How

A small unit **`MKNet.pas`** does the socket work for everybody, over `getaddrinfo` / `getnameinfo` of libc (declared `external 'c'`, as the TLS unit does for OpenSSL, so nothing depends on which `Sockets` features this FPC has):

```
Function NetConnect(Host: String; Port: Word; TimeoutMs: Integer; Out Fd: LongInt; Out Err: String): Boolean;   {all addresses of Host in turn}
Function NetListen(Bind: String; Port: Word; Out Fd: LongInt; Out Err: String; Out What: String): Boolean;      {'' / '::' dual stack, a literal, 0.0.0.0}
Function NetPeer(Fd: LongInt): String;                       {the other end as text, v4-mapped addresses normalised}
Function NetNormalise(Addr: String): String;                 {::ffff:a.b.c.d -> a.b.c.d, zone cut off, lower case, shortest form}
Function NetMatch(Addr, Entry: String): Boolean;             {an address against an address or a net (a.b.c.d/n, v6/n)}
Function NetIsLoopback(Addr: String): Boolean;
Function NetSplitHostPort(S: String; Out Host: String; Out Port: Integer): Boolean;   {host:port, [v6]:port, a URL's authority}
```

**Status:** phases 1, 2 and 3 are built (`src/MKNet.pas`, `tests/nettest.pas`; the listener, the guard, the PROXY addresses, `mkmon`, `mklisten -t`, `tests/iplistentest.py`; both in `build.sh`), and the clients (`MKComClient`, `MKFtp`, `MKHttp` on `NetConnect`, hub host parsing with `[v6]:port`; `clienttest`, `hubftptest`, `qwkhttptest` have IPv6 cases).  Checks and documents (phase 4) and `mkbink` (phase 5) are left.

## Phases

1. **`MKNet.pas`** and `tests/nettest.pas` (the pure functions: normalise, match, loopback, split; connect and listen on `::1` and `127.0.0.1` in loopback, dual stack accepts both, `bind` on one family refuses the other, a name with an IPv6 address, a name with both, a refused first address and a second that works).
2. **The listener:** `NetListen` for ports, `Accept` with `NetPeer`, `maxperip`, the guard (`NetMatch`, v6 nets), the loopback rules, `mklisten -t`, `mkmon` column; tests over `::1` and `127.0.0.1` for telnet, raw, sysop and api ports, and the PROXY header with `TCP6`.
3. **The clients:** `MKComClient`, `MKHttp`, `MKFtp` (`EPSV`), the hub URL and host parsing; the fake hubs of the tests (`fakeftp.py` and the telnet / HTTP fakes) listen on `::1` as well, so `qwkhttptest`, `hubftptest`, `hubexectest` and the Telnet script test run once over IPv6.
4. **Checks and docs:** `mkcheck`, the documents, the example configuration; the SSH front on an IPv6 address (`mkbbsssh` host `::1`).

5. **`mkbink` and the nodelist** (the other repository, `../mkbink`): `binksocket.pas` gets the same `getaddrinfo` connect (all addresses in turn) and a dual-stack listener (the links file's `bind`, default both), the peer address as normalised text in the log and for `accept-unknown`; the links file takes IPv6 literals as `host` (`[2001:db8::1]:24554` and bare `2001:db8::1`); its tests (`tests/runtest.py`, two instances on localhost) run over `::1` too.  Here: `MKNodeHost` / `mkbinkcfg` read the `IBN` / `INA` flags of the nodelist with IPv6 literals (`IBN:[2001:db8::1]:24554`, `INA:2001:db8::1`) and write them into the links file; `mkmon`'s mailer screen shows the longer addresses.

## Decisions (2026-11-25)

1. **Default bind:** a port with no `bind` listens on IPv4 and IPv6; a configuration with an explicit `bind` is unchanged.  2. **Dual stack as one socket**, `IPV6_V6ONLY` set to off explicitly.  3. **`mkbink` is part of the work** (phase 5), as its own commits in its repository.
