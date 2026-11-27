{ SPDX-License-Identifier: GPL-3.0-or-later }
program listentest;
{$mode objfpc}{$H+}
{ Starts mklisten with a test configuration (fakemk stands in for mk) and plays callers.
  usage: listentest <mklisten> <fakemk> <workdir> }
uses BaseUnix, Sockets, SysUtils, Classes;

var
  Fails: Integer;
  Listener: TPid;
  Work: String;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name); Inc(Fails); end;
end;

function Connect(Port: Word): LongInt;
var S: LongInt; A: TInetSockAddr; i: Integer;
begin
  Result := -1;
  for i := 1 to 50 do begin
    S := fpSocket(AF_INET, SOCK_STREAM, 0);
    FillChar(A, SizeOf(A), 0);
    A.sin_family := AF_INET; A.sin_port := htons(Port); A.sin_addr := StrToNetAddr('127.0.0.1');
    if fpConnect(S, @A, SizeOf(A)) = 0 then begin Result := S; Exit; end;
    fpClose(S);
    Sleep(100);
  end;
end;

{ read until Needle appears, EOF, or the time is up }
function ReadUntil(S: LongInt; Needle: String; Ms: Integer): String;
var P: TPollFd; B: Array[0..1023] of Char; N: LongInt; t: Int64; Chunk: String;
begin
  Result := '';
  t := GetTickCount64;
  while GetTickCount64 - t < Ms do begin
    P.fd := S; P.events := POLLIN; P.revents := 0;
    if fpPoll(@P, 1, 100) > 0 then begin
      N := fpRead(S, B, SizeOf(B));
      if N <= 0 then Exit;
      SetString(Chunk, PChar(@B), N);
      Result := Result + Chunk;
      if (Needle <> '') and (Pos(Needle, Result) > 0) then Exit;
    end;
  end;
end;

procedure Say(S: LongInt; T: String);
begin
  if fpWrite(S, T[1], Length(T)) < 0 then ;
end;

function AtEof(S: LongInt; Ms: Integer): Boolean;   { true when the server has closed }
var P: TPollFd; B: Array[0..255] of Char; t: Int64; N: LongInt;
begin
  Result := False;
  t := GetTickCount64;
  while GetTickCount64 - t < Ms do begin
    P.fd := S; P.events := POLLIN; P.revents := 0;
    if fpPoll(@P, 1, 100) > 0 then begin
      N := fpRead(S, B, SizeOf(B));
      if N <= 0 then begin Result := True; Exit; end;
    end;
  end;
end;

var
  Cfg: TStringList;
  Args: Array[0..4] of PChar;
  T1, T2, T3, T4, T5, T6: LongInt;
  S: String;
  Status: cInt;
  i: Integer;
  ok: Boolean;
begin
  if ParamCount < 3 then begin writeln('usage'); Halt(2); end;
  Work := ParamStr(3);
  Cfg := TStringList.Create;
  Cfg.Add('{ "mk": "' + ParamStr(2) + '", "logfile": "' + Work + '/listen.log",');
  Cfg.Add('  "pidfile": "' + Work + '/listen.pid", "_note": "test",');
  Cfg.Add('  "ports": [');
  Cfg.Add('    { "port": 24601, "type": "telnet", "baud": 9600, "nodes": "1-2",');
  Cfg.Add('      "config": "/cfg/x", "bind": "127.0.0.1" },');
  Cfg.Add('    { "port": 24602, "stype": "raw", "nodes": [3, 4], "maxperip": 1, "bind": "127.0.0.1" },');
  Cfg.Add('    { "port": 24603, "type": "ws", "nodes": 5, "bind": "127.0.0.1", "proxy": true, "baud": 19200 }');
  Cfg.Add('  ] }');
  Cfg.SaveToFile(Work + '/listen.cfg');

  Listener := fpFork;
  if Listener = 0 then begin
    Args[0] := PChar(ParamStr(1)); Args[1] := '-c'; Args[2] := PChar(Work + '/listen.cfg');
    Args[3] := Nil;
    fpExecv(ParamStr(1), PPChar(@Args[0]));
    fpExit(127);
  end;

  { telnet port: node 1, the Telnet offers, the session details }
  T1 := Connect(24601);
  Check('connect telnet', T1 >= 0);
  S := ReadUntil(T1, 'MK=/cfg/x', 3000);
  Check('telnet negotiation offered first', Copy(S, 1, 3) = #255#251#1);
  Check('telnet: node 1, type, baud, address, env', Pos('NODE 1 TYPE TELNET BAUD 9600 ADDR 127.0.0.1 MK=/cfg/x', S) > 0);
  Say(T1, 'ab');
  S := ReadUntil(T1, 'AB', 3000);
  Check('echo through the filter: ' + S, Pos('AB', S) > 0);
  Say(T1, #255#255 + 'c');
  S := ReadUntil(T1, 'C', 3000);
  Check('255 survives both ways', Pos(#255#255 + 'C', S) > 0);

  T2 := Connect(24601);
  S := ReadUntil(T2, 'MK=/cfg/x', 3000);
  Check('second caller gets node 2', Pos('NODE 2 ', S) > 0);

  T3 := Connect(24601);
  S := ReadUntil(T3, '', 2000);
  Check('third caller: busy message', Pos('all lines are busy', S) > 0);
  Check('third caller: closed', AtEof(T3, 1000));
  fpClose(T3);

  { a node is freed when its caller leaves }
  fpClose(T1);
  ok := False;
  for i := 1 to 20 do begin
    T4 := Connect(24601);
    S := ReadUntil(T4, 'MK=/cfg/x', 1500);
    if Pos('NODE 1 ', S) > 0 then begin ok := True; Break; end;
    fpClose(T4);
    Sleep(200);
  end;
  Check('node 1 is free again after the caller left', ok);

  { the caller says Q: mk hangs up, the connection closes }
  Say(T2, 'q');
  S := ReadUntil(T2, '!', 3000);
  Check('Q answered', Pos('!', S) > 0);
  Check('connection closed by the session', AtEof(T2, 3000));
  fpClose(T2);

  { raw port: no Telnet bytes, per address limit }
  T5 := Connect(24602);
  S := ReadUntil(T5, 'MK=', 3000);
  Check('raw: node 3, no IAC', (Pos('NODE 3 TYPE RAW BAUD 0 ADDR 127.0.0.1', S) > 0) and (Pos(#255, S) = 0));
  Say(T5, 'xyz');
  S := ReadUntil(T5, 'XYZ', 3000);
  Check('raw echo', Pos('XYZ', S) > 0);
  T6 := Connect(24602);
  S := ReadUntil(T6, '', 2000);
  Check('raw: second caller from the same address is refused', Pos('busy', S) > 0);
  fpClose(T6);
  fpClose(T5);
  fpClose(T4);

  { WebSocket port behind a TLS front end: PROXY header, upgrade, framed data }
  T5 := Connect(24603);
  Say(T5, 'PROXY TCP4 192.0.2.77 127.0.0.1 40000 24603'#13#10 +
    'GET / HTTP/1.1'#13#10'Host: x'#13#10'Upgrade: websocket'#13#10'Connection: Upgrade'#13#10 +
    'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=='#13#10'Sec-WebSocket-Version: 13'#13#10#13#10);
  S := ReadUntil(T5, 'MK=', 3000);
  Check('ws: upgraded', (Copy(S, 1, 12) = 'HTTP/1.1 101') and (Pos('s3pPLMBiTxaQ9kYGzzhZRbK+xOo=', S) > 0));
  Check('ws: banner in a binary frame, address from the PROXY header',
    (Pos(#$82, S) > 0) and (Pos('NODE 5 TYPE WS BAUD 19200 ADDR 192.0.2.77', S) > 0));
  Say(T5, #$82#$81#1#2#3#4 + Chr(Ord('g') xor 1));
  S := ReadUntil(T5, 'G', 3000);
  Check('ws: masked frame in, echo frame out', Pos(#$82#1'G', S) > 0);
  Say(T5, #$88#$80#1#2#3#4);
  S := ReadUntil(T5, '', 3000);
  Check('ws: close frame answered, then closed', Pos(#$88#2#3#232, S) > 0);
  fpClose(T5);
  T5 := Connect(24603);                { no PROXY header: refused by mk }
  Say(T5, 'GET / HTTP/1.1'#13#10#13#10);
  S := ReadUntil(T5, 'MK=', 1500);
  Check('ws: connection without PROXY header gets no session', Pos('NODE', S) = 0);
  fpClose(T5);

  { stop the listener }
  Sleep(300);
  fpKill(Listener, SIGTERM);
  Check('listener stops on SIGTERM', fpWaitPid(Listener, @Status, 0) = Listener);
  Check('listener exit status 0', wifexited(Status) and (wexitstatus(Status) = 0));
  Check('pid file removed', not FileExists(Work + '/listen.pid'));
  Check('log written', FileExists(Work + '/listen.log'));

  writeln('failures: ', Fails);
  Halt(Fails);
end.
