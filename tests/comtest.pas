program comtest;
{$mode tp}
{ MKComAbs: the abstract session, its defaults and the old-style wrappers,
  using a loopback descendant. }
uses MKComAbs;

Type
  LoopCom = Object(AbsComObj)
    Inp: String;               { what the "caller" has sent }
    Outp: String;              { what the BBS has sent }
    Up: Boolean;
    Constructor Init;
    Function  GetCarrier: Boolean; Virtual;
    Procedure Hangup; Virtual;
    Function  InEmpty: Boolean; Virtual;
    Function  GetChar: Char; Virtual;
    Function  PeekChar: Char; Virtual;
    Procedure SendChar(Ch: Char); Virtual;
    Function  GetCommInfo: String; Virtual;
    End;

Constructor LoopCom.Init;
  Begin
  Inherited Init;
  Inp := ''; Outp := ''; Up := True;
  End;
Function LoopCom.GetCarrier: Boolean; begin GetCarrier := Up; end;
Procedure LoopCom.Hangup; begin Up := False; end;
Function LoopCom.InEmpty: Boolean; begin InEmpty := Length(Inp) = 0; end;
Function LoopCom.GetChar: Char;
  begin
  if Length(Inp) > 0 then begin GetChar := Inp[1]; Delete(Inp, 1, 1); end else GetChar := #0;
  end;
Function LoopCom.PeekChar: Char; begin if Length(Inp) > 0 then PeekChar := Inp[1] else PeekChar := #0; end;
Procedure LoopCom.SendChar(Ch: Char); begin Outp := Outp + Ch; end;
Function LoopCom.GetCommInfo: String; begin GetCommInfo := 'Loopback test session'; end;

var
  Fails: Integer;
  L: LoopCom;
  B: Array[1..10] of Byte;
  A: AbsComObj;
  i: Integer;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name); Inc(Fails); end;
end;

begin
  { no session: every wrapper is safe }
  Check('no session: carrier false', not CommCarrier);
  Check('no session: in empty', CommInEmpty);
  Check('no session: recv #0', CommRecv = #0);
  Check('no session: send dropped', not CommSendNW('x'));
  CommSend('x'); CommFlushIn; CommFlushOut; CommInit; CommRelease; CommHangup;
  Check('no session: info', GetCommInfo = 'No session');
  { the bare abstract object }
  A.Init;
  Check('abstract: not connected', not A.GetCarrier);
  Check('abstract: input empty', A.InEmpty);
  Check('abstract: info', A.GetCommInfo = 'No session');
  A.SetBPS(38400);
  Check('abstract: bps', A.GetBPS = 38400);
  Check('abstract: nothing waits', not A.WaitForChar(30));
  A.Done;
  { a descendant, through the old calls }
  L.Init;
  ComSession := @L;
  Check('carrier', CommCarrier);
  Check('info', GetCommInfo = 'Loopback test session');
  Check('input empty', CommInEmpty);
  L.Inp := 'AB';
  Check('input not empty', not CommInEmpty);
  Check('peek', CommPeek = 'A');
  Check('recv', (CommRecv = 'A') and (CommRecv = 'B'));
  CommSend('h');
  Check('SendCharNW', CommSendNW('i'));
  L.SendStr(' there');
  Check('output', L.Outp = 'hi there');
  Check('OutReady/OutEmpty', CommOutReady and CommOutEmpty);
  for i := 1 to 10 do B[i] := 64 + i;
  Check('SendBlock', (L.SendBlock(B, 10) = 10) and (Copy(L.Outp, 9, 10) = 'ABCDEFGHIJ'));
  L.Inp := '0123456789';
  FillChar(B, SizeOf(B), 0);
  Check('GetBlock takes what is waiting', (L.GetBlock(B, 4) = 4) and (B[1] = 48) and (B[4] = 51));
  CommFlushIn;
  Check('FlushIn', CommInEmpty);
  L.Inp := 'x';
  Check('WaitForChar ready', L.WaitForChar(100));
  CommFlushIn;
  Check('WaitForChar times out', not L.WaitForChar(50));
  CommHangup;
  Check('hangup', not CommCarrier);
  Check('WaitForChar after hangup returns at once', not L.WaitForChar(5000));
  L.Done;
  ComSession := Nil;
  writeln('failures: ', Fails);
  Halt(Fails);
end.
