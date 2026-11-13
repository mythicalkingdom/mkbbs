program fakemk;
{$mode tp}
{ Stands in for "mk" in the listener test.  Takes the same options (-N -S -B -A),
  builds the session the same way, says who it is, then echoes upper-cased input
  until the caller hangs up or sends Q. }
uses Dos, MKComAbs, MKSess, MKString, MKSnoop;
var
  Minutes: LongInt;
  i: Word; S, Typ, Addr, Cfg: String; Proxy: Boolean; Rate: LongInt; Node: LongInt; C: Char;
function Sysop(Cmd: Char; Arg: LongInt): String;
begin
  case Cmd of
    '+': begin Inc(Minutes, Arg); Sysop := 'Added ' + Long2Str(Arg) + ' min, ' + Long2Str(Minutes) + ' left'; end;
    '-': begin Dec(Minutes, Arg); Sysop := 'Took ' + Long2Str(Arg) + ' min, ' + Long2Str(Minutes) + ' left'; end;
    'K': Sysop := 'Node kicked';
  end;
end;

begin
  Minutes := 30;
  SnoopHandler := Sysop;
  Proxy := False; Typ := ''; Addr := ''; Rate := 0; Node := 0;
  for i := 1 to ParamCount do begin
    S := ParamStr(i);
    if (Length(S) > 1) and (S[1] = '-') then
      case UpCase(S[2]) of
        'N': Node := Str2Long(Copy(S, 3, 5));
        'S': Typ := Copy(S, 3, 10);
        'B': Rate := Str2Long(Copy(S, 3, 7));
        'A': Addr := Copy(S, 3, 64);
        'H': Proxy := True;
      end;
  end;
  Cfg := GetEnv('MK');
  ComSession := CreateSession(Typ, Rate, Addr, Proxy);
  if ComSession = Nil then begin WriteLn(StdErr, SessionError); Halt(3); end;
  if (GetEnv('MKRUN') <> '') and (Node > 0) then
    ComSession := New(SnoopComPtr, Init(ComSession, True, GetEnv('MKRUN') + '/node' + Long2Str(Node) + '.snoop'));
  CommInit;
  ComSession^.SendStr('NODE ' + Long2Str(Node) + ' TYPE ' + Typ + ' BAUD ' + Long2Str(Rate) +
    ' ADDR ' + ComSession^.GetRemoteAddr + ' MK=' + Cfg + #13#10);
  CommFlushOut;
  while CommCarrier do
    if ComSession^.WaitForChar(200) then begin
      C := CommRecv;
      if UpCase(C) = 'Q' then begin CommSend('!'); CommFlushOut; CommHangup; end
      else if C = '#' then ComSession^.SendStr(#27'[1;31m')   {sets bold red: no text}
      else CommSend(UpCase(C));
    end;
  CommRelease;
  Dispose(ComSession, Done);
end.
