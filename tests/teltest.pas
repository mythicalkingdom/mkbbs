{ SPDX-License-Identifier: GPL-3.0-or-later }
program teltest;
{$mode tp}
{ MKComFd + MKComTelnet over a socket pair: the test plays the caller. }
uses BaseUnix, Sockets, MKPlat, MKComAbs, MKComFd, MKComTelnet;

var
  Fails: Integer;
  Ccols, Crows: Word;
  Peer: LongInt;                       { the caller's end }
  Fd: FdComObj;
  T: TelnetComObj;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name); Inc(Fails); end;
end;

procedure Say(S: String);              { the caller sends bytes }
begin
  if fpWrite(Peer, S[1], Length(S)) < 0 then;
end;

function Hear: String;                 { what the caller has received so far }
var P: TPollFd; N: LongInt; B: Array[0..255] of Char; S: String;
begin
  S := '';
  repeat
    P.fd := Peer; P.events := POLLIN; P.revents := 0;
    N := 0;
    if fpPoll(@P, 1, 30) > 0 then N := fpRead(Peer, B, 256);
    if (N > 0) and (Length(S) + N < 255) then begin Move(B, S[Length(S)+1], N); Inc(S[0], N); end;
  until N <= 0;
  Hear := S;
end;

function Hex(S: String): String;
var i: Integer; R: String;
const D: String = '0123456789ABCDEF';
begin
  R := '';
  for i := 1 to Length(S) do R := R + D[Ord(S[i]) shr 4 + 1] + D[Ord(S[i]) and 15 + 1];
  Hex := R;
end;

function Rd(Max: Integer): String;     { what the BBS can read now }
var S: String;
begin
  S := '';
  while (Length(S) < Max) and not T.InEmpty do S := S + T.GetChar;
  Rd := S;
end;

var
  Fds: Array[0..1] of cInt;
  S: String;
  t0, el: Int64;
  i: Integer;

begin
  if fpSocketPair(AF_UNIX, SOCK_STREAM, 0, @Fds) <> 0 then begin writeln('no socketpair'); Halt(1); end;
  Peer := Fds[1];
  Fd.InitFd(Fds[0], Fds[0]);
  Fd.RemoteAddr := '10.1.2.3';
  T.Init(@Fd, False);
  ComSession := @T;

  Check('open', T.OpenSession);
  S := Hear;
  Check('offers sent', S = #255#251#1 + #255#251#3 + #255#253#3 + #255#251#0 + #255#253#0 + #255#253#31 + #255#253#24);
  Check('carrier', T.GetCarrier);
  Check('remote addr passes through', T.GetRemoteAddr = '10.1.2.3');
  Check('info', T.GetCommInfo = 'Telnet over Stream session');

  { the caller answers: DO ECHO, DO SGA, WILL SGA, DO BINARY, WILL BINARY, WILL NAWS, WILL TTYPE }
  Say(#255#253#1 + #255#253#3 + #255#251#3 + #255#253#0 + #255#251#0 + #255#251#31 + #255#251#24);
  Check('no data yet', T.InEmpty);
  S := Hear;
  Check('terminal type is asked for', S = #255#250#24#1#255#240);
  Check('echo/sga/binary are on', T.Negotiated(1, True) and T.Negotiated(3, True) and T.Negotiated(0, True) and
        T.Negotiated(3, False) and T.Negotiated(0, False));
  Check('naws/ttype are on', T.Negotiated(31, False) and T.Negotiated(24, False));

  { window size and terminal type }
  Say(#255#250#31#0#80#0#25#255#240 + #255#250#24#0'ANSI'#255#240);
  Check('no data from sub-negotiation', T.InEmpty);
  Check('window size', (T.Cols = 80) and (T.Rows = 25));
  Check('terminal type', T.TermType = 'ANSI');
  Check('the session reports it (GetTermType)', T.GetTermType = 'ANSI');
  Check('screen changed flag', T.ScreenChanged);
  Check('window size through the session', CommWindowSize(Ccols, Crows) and (Ccols = 80) and (Crows = 25));
  Check('window version counts reports', CommWindowVersion = 1);
  Say(#255#250#31#0#100#0#40#255#240);
  Check('resize', T.InEmpty and (T.Rows = 40) and (CommWindowVersion = 2));

  { data: CR NUL, CR LF, IAC IAC, a bare LF, an IAC NOP in the middle }
  Say('A'#13#0'B'#13#10'C'#255#255'D'#10'E'#255#241'F');
  S := Rd(20);
  Check('data filtered: ' + Hex(S), S = 'A'#13'B'#13'C'#255'D'#10'EF');

  { a sequence split across reads }
  Say('X'#255); S := Rd(5); Check('split 1', S = 'X');
  Say(#253); S := Rd(5); Check('split 2', S = '');
  Say(#1'Y'); S := Rd(5); Check('split 3 (answer to a redundant DO ECHO is none)', S = 'Y');
  S := Hear;
  Check('no reply to options already in force', S = '');

  { unsupported options get refused, once }
  Say(#255#253#99 + #255#251#98);
  S := Rd(5);
  S := Hear;
  Check('refuse unknown options', S = #255#252#99 + #255#254#98);
  Say(#255#254#1);                   { DONT ECHO }
  S := Rd(5);
  Check('DONT ECHO acknowledged', Hear = #255#252#1);
  Check('echo off', not T.Negotiated(1, True));

  { output: 255 is doubled }
  T.SendChar('a');
  T.SendChar(#255);
  T.SendStr('bc');
  for i := 1 to 3 do ;
  T.FlushOut;
  S := Hear;
  Check('output escaping', S = 'a'#255#255'bc');

  { peek, wait }
  Say('Q');
  Check('wait for char', T.WaitForChar(500));
  Check('peek', T.PeekChar = 'Q');
  Check('get', T.GetChar = 'Q');
  t0 := MKTicks;
  Check('wait times out', not T.WaitForChar(150));
  el := MKTicks - t0;
  Check('wait took about 150 ms', (el >= 120) and (el < 400));
  Say(#255#253#99);                  { only a command, no data: must not return early with data }
  Check('command only is not data', not T.WaitForChar(100));
  S := Hear;

  { hang up from the caller's side }
  fpClose(Peer);
  Check('carrier lost', not T.WaitForChar(300) and not T.GetCarrier);
  T.Hangup;

  { emulated speed over a fresh pair }
  fpSocketPair(AF_UNIX, SOCK_STREAM, 0, @Fds);
  Peer := Fds[1];
  Fd.InitFd(Fds[0], Fds[0]);
  Fd.SetBPS(2400);                    { 240 characters per second }
  Check('coBPS', Fd.coBPS = 2400);
  t0 := MKTicks;
  for i := 1 to 120 do Fd.SendChar('.');
  Fd.FlushOut;
  el := MKTicks - t0;
  Check('2400 bps: 120 chars take about half a second', (el >= 380) and (el < 800));
  S := Hear;
  Check('2400 bps: all arrived', Length(S) = 120);
  Fd.SetBPS(0);
  t0 := MKTicks;
  for i := 1 to 120 do Fd.SendChar('.');
  Fd.FlushOut;
  el := MKTicks - t0;
  Check('no pace: immediate', el < 100);
  S := Hear;
  { an idle line does not bank credit: after a pause the next burst is paced again }
  Fd.SetBPS(2400);
  Fd.SendChar('x'); Fd.FlushOut; S := Hear;
  MKDelay(300);
  t0 := MKTicks;
  for i := 1 to 120 do Fd.SendChar('.');
  Fd.FlushOut;
  el := MKTicks - t0;
  Check('idle line does not bank credit', el >= 380);
  S := Hear;
  Fd.Hangup;
  Check('hangup: peer sees end of file', (Hear = '') and (fpRead(Peer, S[1], 1) = 0));
  Check('hangup: no carrier', not Fd.GetCarrier);
  fpClose(Peer);

  writeln('failures: ', Fails);
  Halt(Fails);
end.
