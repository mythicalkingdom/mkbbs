Program NetTest;   {MKNet: the address functions, and connect / listen over IPv4 and IPv6 on the loopback (IPV6-PLAN.md phase 1)}

{$MODE OBJFPC}
{$H+}

Uses SysUtils, BaseUnix, Sockets, MKNet;

Var
  Fails: Integer = 0;


Procedure Check(Const Name: String; Ok: Boolean; Const Info: String = '');
  Begin
  If Ok Then
    WriteLn('ok   net: ', Name)
  Else
    Begin
    WriteLn('FAIL net: ', Name, '  ', Info);
    Inc(Fails);
    End;
  End;


Function PortOf(Fd: LongInt): Word;
  Var
    S: Array[0..127] Of Byte;
    L: TSockLen;

  Begin
  L := SizeOf(S);
  fpGetSockName(Fd, @S, @L);
  PortOf := (S[2] Shl 8) Or S[3];
  End;


Function CanConnect(Const Host: String; Port: Word; Out PeerSeen: String; L: LongInt): Boolean;
  {connects to the listener L and accepts on it; PeerSeen is NetPeer of the accepted socket}
  Var
    C, A: LongInt;
    Err: String;
    S: Array[0..127] Of Byte;
    Len: TSockLen;

  Begin
  CanConnect := False;
  PeerSeen := '';
  If Not NetConnect(Host, Port, 2000, C, Err) Then
    Exit;
  Len := SizeOf(S);
  A := fpAccept(L, @S, @Len);
  If A >= 0 Then
    Begin
    PeerSeen := NetPeer(A);
    fpClose(A);
    End;
  fpClose(C);
  CanConnect := A >= 0;
  End;


Var
  L, L2: LongInt;
  What, Peer, H: String;
  P: Word;
  Port: Integer;
  V6: Boolean;

Begin
Check('normalise: a mapped IPv4 address is the IPv4 address', NetNormalise('::FFFF:192.0.2.7') = '192.0.2.7', NetNormalise('::FFFF:192.0.2.7'));
Check('normalise: IPv6 in its shortest form, lower case', (NetNormalise('2001:0DB8:0:0:0:0:0:7') = '2001:db8::7') And (NetNormalise('0:0:0:0:0:0:0:1') = '::1'), NetNormalise('2001:0DB8:0:0:0:0:0:7'));
Check('normalise: a zone is cut off', NetNormalise('fe80::1%eth0') = 'fe80::1');
Check('normalise: IPv4 and what is no address stay', (NetNormalise('192.0.2.7') = '192.0.2.7') And (NetNormalise('not an address') = 'not an address'));
Check('family', (NetFamily('1.2.3.4') = 4) And (NetFamily('::1') = 6) And (NetFamily('::ffff:1.2.3.4') = 4) And (NetFamily('x') = 0) And (NetFamily('') = 0) And (NetFamily('1.2.3') = 0));
Check('match: the same address in different spellings', NetMatch('::1', '0:0:0:0:0:0:0:1') And NetMatch('::ffff:10.0.0.1', '10.0.0.1') And Not NetMatch('10.0.0.1', '10.0.0.2'));
Check('match: IPv4 nets', NetMatch('10.1.2.3', '10.0.0.0/8') And Not NetMatch('11.0.0.1', '10.0.0.0/8') And NetMatch('192.168.7.9', '192.168.4.0/22') And Not NetMatch('192.168.8.1', '192.168.4.0/22') And NetMatch('1.2.3.4', '0.0.0.0/0'));
Check('match: IPv6 nets', NetMatch('2001:db8:1::5', '2001:db8::/32') And Not NetMatch('2001:db9::1', '2001:db8::/32') And NetMatch('2001:db8::7', '2001:db8::7/128') And Not NetMatch('2001:db8::8', '2001:db8::7/128'));
Check('match: an IPv4 address is not in an IPv6 net and the other way, a bad prefix matches nothing', Not NetMatch('1.2.3.4', '::/0') And Not NetMatch('::1', '0.0.0.0/0') And Not NetMatch('10.0.0.1', '10.0.0.0/33') And Not NetMatch('10.0.0.1', '10.0.0.0/x') And Not NetMatch('junk', '10.0.0.0/8'));
Check('loopback', NetIsLoopback('127.0.0.1') And NetIsLoopback('127.5.5.5') And NetIsLoopback('::1') And NetIsLoopback('::ffff:127.0.0.1') And Not NetIsLoopback('192.0.2.1') And Not NetIsLoopback('2001:db8::1') And Not NetIsLoopback('junk'));
Check('split: host, host:port', NetSplitHostPort('bbs.example.org', H, Port) And (H = 'bbs.example.org') And (Port = -1) And NetSplitHostPort('bbs.example.org:24554', H, Port) And (H = 'bbs.example.org') And (Port = 24554));
Check('split: [v6]:port, [v6], a bare IPv6 address', NetSplitHostPort('[2001:db8::1]:24554', H, Port) And (H = '2001:db8::1') And (Port = 24554) And NetSplitHostPort('[::1]', H, Port) And (H = '::1') And (Port = -1) And NetSplitHostPort('2001:db8::1', H, Port) And (H = '2001:db8::1') And (Port = -1));
Check('split: what is none', Not NetSplitHostPort('', H, Port) And Not NetSplitHostPort('[::1', H, Port) And Not NetSplitHostPort('host:99999', H, Port) And Not NetSplitHostPort('[::1]x', H, Port) And Not NetSplitHostPort('a:b:c', H, Port));
Check('join', (NetJoinHostPort('host', 24554) = 'host:24554') And (NetJoinHostPort('::1', 80) = '[::1]:80'));

V6 := NetHasIPv6;
If Not V6 Then
  WriteLn('skip: no IPv6 on this system (the IPv6 connection tests are left out)');

{ IPv4 only }
Check('listen 0.0.0.0: IPv4 only', NetListen('0.0.0.0', 0, L, What), What);
P := PortOf(L);
Check('... a connection to 127.0.0.1 works, the peer is 127.0.0.1', CanConnect('127.0.0.1', P, Peer, L) And (Peer = '127.0.0.1'), Peer);
If V6 Then
  Check('... a connection to ::1 does not', Not CanConnect('::1', P, Peer, L));
fpClose(L);
Check('a bad bind address is refused with a reason', (Not NetListen('999.1.1.1', 0, L, What)) And (Pos('bad bind address', What) > 0), What);
Check('a name that does not exist: Unknown host', (Not NetConnect('no-such-host.invalid', 9, 1000, L, What)) And (Pos('Unknown host', What) > 0), What);

If V6 Then
  Begin
  { dual stack }
  Check('listen with no bind: IPv4 and IPv6', NetListen('', 0, L, What) And (Pos('IPv4 and IPv6', What) > 0), What);
  P := PortOf(L);
  Check('... IPv4 caller: the peer is 127.0.0.1 (not ::ffff:127.0.0.1)', CanConnect('127.0.0.1', P, Peer, L) And (Peer = '127.0.0.1'), Peer);
  Check('... IPv6 caller: the peer is ::1', CanConnect('::1', P, Peer, L) And (Peer = '::1'), Peer);
  Check('... [::1] with brackets as the host', CanConnect('[::1]', P, Peer, L));
  Check('... the name localhost', CanConnect('localhost', P, Peer, L));
  fpClose(L);
  { IPv6 only }
  Check('listen ::1: IPv6 only', NetListen('::1', 0, L, What), What);
  P := PortOf(L);
  Check('... a connection to ::1 works', CanConnect('::1', P, Peer, L) And (Peer = '::1'), Peer);
  Check('... a connection to 127.0.0.1 does not', Not CanConnect('127.0.0.1', P, Peer, L));
  fpClose(L);
  { the name has two addresses, the first is refused: the next one is tried }
  Check('listen 127.0.0.1 only', NetListen('127.0.0.1', 0, L2, What), What);
  P := PortOf(L2);
  Check('a name that resolves to ::1 and 127.0.0.1 connects to the one that listens (localhost)', CanConnect('localhost', P, Peer, L2) And (Peer = '127.0.0.1'), Peer);
  fpClose(L2);
  End;

WriteLn('failures: ', Fails);
If Fails > 0 Then
  Halt(1);
End.
