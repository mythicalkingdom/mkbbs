{ SPDX-License-Identifier: GPL-3.0-or-later }
program wstest;
{$mode tp}
{ MKComWS (WebSocket filter) and MKProxy (PROXY header) over a socket pair; the test plays the caller. }
uses BaseUnix, Sockets, MKPlat, MKComAbs, MKComFd, MKComWS, MKProxy;

type Blob = String;   { binary strings; fine up to 255 bytes, longer data goes through Big }

var
  Fails: Integer;
  Peer: LongInt;
  Fd: FdComObj;
  W: WsComObj;
  Fds: Array[0..1] of cInt;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name); Inc(Fails); end;
end;

procedure Say(S: String);
begin
  if Length(S) > 0 then if fpWrite(Peer, S[1], Length(S)) < 0 then ;
end;

var Big: Array[0..4095] of Byte; BigLen: Integer;

function Hear: String;        { what the caller received (first 255 bytes in the string, all in Big) }
var P: TPollFd; N: LongInt; B: Array[0..511] of Byte; S: String; i: Integer;
begin
  S := ''; BigLen := 0;
  repeat
    P.fd := Peer; P.events := POLLIN; P.revents := 0;
    N := 0;
    if fpPoll(@P, 1, 40) > 0 then N := fpRead(Peer, B, 512);
    for i := 0 to N - 1 do begin
      if BigLen < 4096 then begin Big[BigLen] := B[i]; Inc(BigLen); end;
      if Length(S) < 255 then S := S + Chr(B[i]);
    end;
  until N <= 0;
  Hear := S;
end;

function Frame(Op: Byte; Fin: Boolean; Payload: String; Masked: Boolean): String;
var S: String; i: Integer; K: Array[0..3] of Byte;
begin
  K[0] := 1; K[1] := 2; K[2] := 3; K[3] := 4;
  if Fin then S := Chr($80 or Op) else S := Chr(Op);
  if Length(Payload) < 126 then
    S := S + Chr(Length(Payload) or ($80 * Ord(Masked)))
  else
    S := S + Chr(126 or ($80 * Ord(Masked))) + Chr(Length(Payload) shr 8) + Chr(Length(Payload) and 255);
  if Masked then begin
    S := S + Chr(1) + Chr(2) + Chr(3) + Chr(4);
    for i := 1 to Length(Payload) do S := S + Chr(Ord(Payload[i]) xor K[(i - 1) and 3]);
  end else S := S + Payload;
  Frame := S;
end;

function Rd(Max: Integer): String;
var S: String;
begin
  S := '';
  while (Length(S) < Max) and not W.InEmpty do S := S + W.GetChar;
  Rd := S;
end;

function Request(Key: String; Proto: String): String;
var S: String;
begin
  S := 'GET /bbs HTTP/1.1'#13#10'Host: x'#13#10'Upgrade: websocket'#13#10'Connection: keep-alive, Upgrade'#13#10 +
    'Sec-WebSocket-Key: ' + Key + #13#10'Sec-WebSocket-Version: 13'#13#10;
  if Proto <> '' then S := S + 'Sec-WebSocket-Protocol: ' + Proto + #13#10;
  Request := S + #13#10;
end;

procedure NewPair;
begin
  if fpSocketPair(AF_UNIX, SOCK_STREAM, 0, @Fds) <> 0 then begin writeln('no socketpair'); Halt(1); end;
  Peer := Fds[1];
  Fd.InitFd(Fds[0], Fds[0]);
end;

var
  S, Addr: String;
  i: Integer;
  t0: Int64;
  P: AbsComPtr;
  ok: Boolean;

begin
  Check('RFC 6455 accept value', WebSocketAccept('dGhlIHNhbXBsZSBub25jZQ==') = 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=');

  { ---- handshake ---- }
  NewPair;
  W.Init(@Fd, False);
  Say(Request('dGhlIHNhbXBsZSBub25jZQ==', 'binary, base64'));
  Check('open', W.OpenSession);
  S := Hear;
  Check('101', Copy(S, 1, 12) = 'HTTP/1.1 101');
  Check('accept header', Pos('Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=', S) > 0);
  Check('sub-protocol binary', Pos('Sec-WebSocket-Protocol: binary', S) > 0);
  Check('path', W.Path = '/bbs');
  Check('info', W.GetCommInfo = 'WebSocket over Stream session');

  { ---- input ---- }
  Say(Frame(1, True, 'Hi', True));
  Check('text frame', Rd(5) = 'Hi');
  S := '';
  for i := 1 to 130 do S := S + Chr(65 + i mod 26);
  Say(Frame(2, True, S, True));
  Check('binary frame with 16 bit length', Rd(200) = S);
  Say(Frame(1, False, 'ab', True) + Frame(0, True, 'cd', True));
  Check('fragmented message', Rd(10) = 'abcd');
  S := Frame(2, True, 'xyz', True);
  for i := 1 to Length(S) do begin Say(S[i]); W.WaitForChar(5); end;
  Check('frame arriving byte by byte', Rd(10) = 'xyz');
  Say(Frame(2, True, '', True));
  Check('empty frame is no data', W.InEmpty);
  Hear;

  { ---- ping, pong ---- }
  Say(Frame(9, True, 'ping!', True));
  Check('ping is not data', W.InEmpty);
  S := Hear;
  Check('pong with the same payload', S = #$8A#5'ping!');
  Say(Frame(10, True, '', True) + Frame(2, True, 'k', True));
  Check('pong ignored', Rd(5) = 'k');
  Say(Frame(9, True, 'p', True) + Frame(2, True, 'q', True));
  Check('data after a ping', Rd(5) = 'q');
  Hear;

  { ---- output ---- }
  W.SendStr('hello');
  Check('buffered until flushed', Hear = '');
  W.FlushOut;
  Check('binary frame', Hear = #$82#5'hello');
  for i := 1 to 300 do W.SendChar(Chr(i and 255));
  W.FlushOut;
  S := Hear;
  Check('300 bytes: 16 bit length', (BigLen = 304) and (Big[0] = $82) and (Big[1] = 126) and (Big[2] = 1) and (Big[3] = 44) and (Big[4] = 1) and (Big[303] = (300 and 255)));
  for i := 1 to 2500 do W.SendChar('z');
  W.FlushOut;
  S := Hear;
  Check('2500 bytes: split into frames, all arrive', BigLen = 2500 + 4 + 4 + 4);   { 1024 + 1024 + 452 }
  W.SendStr('wait');
  Check('output goes out when the BBS waits', (not W.WaitForChar(40)) and (Hear = #$82#4'wait'));

  { ---- errors ---- }
  Say(Frame(1, True, 'bad', False));
  Check('unmasked frame refused', not W.WaitForChar(100));
  S := Hear;
  Check('close 1002', S = #$88#2#3#$EA);
  Check('carrier gone', not W.GetCarrier);
  fpClose(Peer);

  { ---- close from the caller ---- }
  NewPair;
  W.Init(@Fd, False);
  Say(Request('dGhlIHNhbXBsZSBub25jZQ==', ''));
  W.OpenSession;
  S := Hear;
  Check('no sub-protocol offered, none answered', Pos('Sec-WebSocket-Protocol', S) = 0);
  Say(Frame(8, True, #3#232, True));
  Check('close frame ends the session', not W.WaitForChar(200));
  Check('close answered', Hear = #$88#2#3#232);
  Check('no carrier', not W.GetCarrier);
  fpClose(Peer);

  { ---- the BBS hangs up ---- }
  NewPair;
  W.Init(@Fd, False);
  Say(Request('abc', ''));
  W.OpenSession;
  Hear;
  W.SendStr('bye');
  W.Hangup;
  S := Hear;
  Check('hangup: last data then close frame', S = #$82#3'bye'#$88#2#3#232);
  Check('hangup: socket closed', fpRead(Peer, S[1], 1) = 0);
  fpClose(Peer);

  { ---- not a WebSocket request ---- }
  NewPair;
  W.Init(@Fd, False);
  Say('GET / HTTP/1.1'#13#10'Host: x'#13#10#13#10);
  Check('plain GET refused', not W.OpenSession);
  S := Hear;
  Check('426 answer', Copy(S, 1, 12) = 'HTTP/1.1 426');
  Check('no carrier after refusal', not W.GetCarrier);
  fpClose(Peer);

  { ---- the caller never sends a request ---- }
  { (10 s timeout; not run here) }

  { ---- PROXY protocol ---- }
  NewPair;
  Addr := 'orig';
  Say('PROXY TCP4 192.0.2.7 127.0.0.1 51234 2325'#13#10'rest');
  Check('v1 header', ReadProxyHeader(@Fd, Addr, 1000) and (Addr = '192.0.2.7'));
  Check('v1: data after the header is untouched', (Fd.GetChar = 'r') and (Fd.GetChar = 'e'));
  fpClose(Peer); Fd.Hangup;
  NewPair; Addr := 'orig';
  Say('PROXY UNKNOWN'#13#10);
  Check('v1 UNKNOWN keeps the address', ReadProxyHeader(@Fd, Addr, 1000) and (Addr = 'orig'));
  fpClose(Peer); Fd.Hangup;
  NewPair; Addr := 'orig';
  Say('PROXY TCP6 2001:db8::1 ::1 5 6'#13#10);
  Check('v1 IPv6', ReadProxyHeader(@Fd, Addr, 1000) and (Addr = '2001:db8::1'));
  fpClose(Peer); Fd.Hangup;
  NewPair; Addr := 'orig';
  Say('GET / HTTP/1.1'#13#10);
  Check('not a PROXY header', not ReadProxyHeader(@Fd, Addr, 1000));
  fpClose(Peer); Fd.Hangup;
  NewPair; Addr := 'orig';
  Say('PROXY TCP4 evil;rm 1.1.1.1 1 2'#13#10);
  Check('bad characters in the address', not ReadProxyHeader(@Fd, Addr, 1000));
  fpClose(Peer); Fd.Hangup;
  NewPair; Addr := 'orig';
  Say(#13#10#13#10#0#13#10'QUIT'#10 + #$21#$11#0#12 + #192#0#2#9 + #127#0#0#1 + #200#10 + #9#41 + 'data');
  Check('v2 TCP4', ReadProxyHeader(@Fd, Addr, 1000) and (Addr = '192.0.2.9'));
  Check('v2: data after the header is untouched', Fd.GetChar = 'd');
  fpClose(Peer); Fd.Hangup;
  NewPair; Addr := 'orig';
  Say(#13#10#13#10#0#13#10'QUIT'#10 + #$21#$21#0#36 + #$20#$01#$0d#$b8#0#0#0#0#0#0#0#0#0#0#0#1 + #0#0#0#0#0#0#0#0#0#0#0#0#0#0#0#1 + #0#5#0#6);
  Check('v2 TCP6', ReadProxyHeader(@Fd, Addr, 1000) and (Addr = '2001:db8:0:0:0:0:0:1'));
  fpClose(Peer); Fd.Hangup;
  NewPair; Addr := 'orig';
  Say(#13#10#13#10#0#13#10'QUIT'#10 + #$20#0#0#0);
  Check('v2 LOCAL', ReadProxyHeader(@Fd, Addr, 1000) and (Addr = 'orig'));
  fpClose(Peer); Fd.Hangup;
  NewPair; Addr := 'orig';
  t0 := MKTicks;
  Check('no header: times out', not ReadProxyHeader(@Fd, Addr, 300));
  Check('timeout took about 300 ms', (MKTicks - t0 >= 250) and (MKTicks - t0 < 1000));
  fpClose(Peer); Fd.Hangup;

  writeln('failures: ', Fails);
  Halt(Fails);
end.
