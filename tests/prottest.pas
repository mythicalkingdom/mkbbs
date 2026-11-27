{ SPDX-License-Identifier: GPL-3.0-or-later }
program prottest;
{$mode tp}
{$H+}
{ prottest send <proto> <file> <dir>   sends <file> with MKProt to the real rz / rx / rb (lrzsz), which works in <dir>
  prottest recv <proto> <file> <dir>   the real sz / sx / sb sends <file>, MKProt receives it into <dir>
  prottest pair <proto> <file> <dir>   MKProt sends and a second MKProt receives (for what lrzsz does not have: Ymodem-G ...)
  proto: e Xmodem to a receiver that sees damaged blocks, z Zmodem, x Xmodem (checksum receiver), c Xmodem (CRC receiver), k 1k-Xmodem, y Ymodem, g Ymodem-G, q 1k-Xmodem-G
  An optional last argument: v = show the window, t = trace every byte.
  Over a socketpair as a session (MKComFd); prints "result ..." lines (tests/prottest.py) }
uses BaseUnix, Unix, Sockets, ctypes, MKComAbs, MKComFd, MKProt, MKVideo, MKString;

var Fds: array[0..1] of cint; Pid: LongInt; P: ProtObj; Mode, Proto, Peer: AnsiString; A: array[0..6] of AnsiString; Args: array[0..7] of PChar;
    St: cint; Ok: Boolean; N, i: Integer;

procedure SetProto(var Pr: ProtObj);
begin
  case Proto[1] of
    'x', 'c', 'e': Pr.SetXmodem;
    'k': Pr.SetX1K;
    'y': Pr.SetYModem;
    'g': Pr.SetYModemG;
    'q': Pr.SetXmodemG;
    else Pr.SetZmodem;
  end;
  if (Proto[1] = 'x') then Pr.PI^.CrcType := 1;
end;

begin
  Mode := ParamStr(1); Proto := ParamStr(2);
  if fpSocketPair(AF_UNIX, SOCK_STREAM, 0, @Fds[0]) <> 0 then halt(1);
  Pid := fpFork;
  if Pid = 0 then begin
    fpClose(Fds[0]);
    if Mode = 'pair' then begin
      { the other end is MKProt, too: it receives }
      ComSession := New(FdComPtr, InitFd(Fds[1], Fds[1]));
      CurrentPort := 1; CurrentRate := 38400;
      CommInit;
      ProtQuiet := True;
      P.Init; SetProto(P); P.SetRecvName('pair.bin');
      Ok := P.Recv(ParamStr(4));
      if Ok and (P.PI^.NumFiles = 1) then halt(0) else halt(1);
    end;
    fpDup2(Fds[1], 0); fpDup2(Fds[1], 1);
    N := 0;
    if Mode = 'send' then begin
      fpChdir(ParamStr(4));
      case Proto[1] of
        'z': begin Peer := 'rz'; A[1] := '-b'; N := 1; end;
        'x': begin Peer := 'rx'; A[1] := '-b'; A[2] := 'x.out'; N := 2; end;
        'c', 'k': begin Peer := 'rx'; A[1] := '-b'; A[2] := '-c'; A[3] := 'x.out'; N := 3; end;
        'e': begin Peer := 'rx'; A[1] := '-b'; A[2] := '-c'; A[3] := '--errors'; A[4] := '4000'; A[5] := 'x.out'; N := 5; end;
        'y': begin Peer := 'rb'; A[1] := '-b'; N := 1; end;
      end;
    end else begin
      case Proto[1] of
        'z': begin Peer := 'sz'; A[1] := '-b'; A[2] := ParamStr(3); N := 2; end;
        'x', 'c': begin Peer := 'sx'; A[1] := '-b'; A[2] := ParamStr(3); N := 2; end;
        'k': begin Peer := 'sx'; A[1] := '-b'; A[2] := '-k'; A[3] := ParamStr(3); N := 3; end;
        'y': begin Peer := 'sb'; A[1] := '-b'; A[2] := ParamStr(3); N := 2; end;
      end;
    end;
    A[0] := Peer;
    for i := 0 to N do Args[i] := PChar(A[i]);
    Args[N + 1] := nil;
    fpExecv('/usr/bin/' + Peer, @Args[0]);
    halt(127);
  end;
  fpClose(Fds[1]);
  ComSession := New(FdComPtr, InitFd(Fds[0], Fds[0]));
  CurrentPort := 1; CurrentRate := 38400;
  CommInit;
  ProtQuiet := ParamStr(5) <> 'v';
  ProtTrace := ParamStr(5) = 't';
  P.Init;
  SetProto(P);
  if (Mode = 'send') or (Mode = 'pair') then begin
    P.AddSendFile(ParamStr(3));
    P.Send;
    Ok := (P.PI^.Error = 0) and (P.GetFileStatus(1) = 1);
    writeln('result send ok=', Ok, ' error=', P.PI^.Error);
  end else begin
    P.SetRecvName('rx.bin');
    Ok := P.Recv(ParamStr(4));
    writeln('result recv ok=', Ok, ' files=', P.PI^.NumFiles, ' name=', P.PI^.FN[1], ' status=', P.GetFileStatus(1));
  end;
  fpWaitPid(Pid, @St, 0);
  writeln('result peer exit=', St);
end.
