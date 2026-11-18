program qwkimptest;
{$mode tp}
{$H+}
{ qwkimptest <dir>: a REP made with MKMsgQwk goes into message areas with MKQwkImp }
uses MKString, MKFile, MKGlobT, MKMsgAbs, MKMsgQwk, MKOpen, MKQwkImp, Dos;

var Fails: Integer;
    Dir: String;
    Notes: Array[0..9] of LongInt;
    Posted: Array[1..20] of LongInt;
    NumPosted: Integer;

procedure Check(N: String; Ok: Boolean);
begin if Ok then writeln('ok   qwkimp: ', N) else begin writeln('FAIL qwkimp: ', N); Inc(Fails); end; end;

function MapProc(Conf: LongInt; var T: QwkImpTarget; var Moved: Boolean): Boolean;
begin
  MapProc := True;
  case Conf of
    1: begin T.AreaId := 'J' + Dir + 'a1'; T.Area := 1; T.ForceFrom := 'Test User'; T.PrivMode := 0; end;
    2: begin T.AreaId := 'J' + Dir + 'net'; T.Area := 2; T.Kind := mmtNetMail; T.OrigAddr.Zone := 1; T.OrigAddr.Net := 110;
         T.OrigAddr.Node := 290; T.OrigAddr.Point := 0; T.PrivMode := 1; T.ForceFrom := 'Test User'; end;
    3: begin T.AreaId := 'J' + Dir + 'echo'; T.Area := 3; T.Kind := mmtEchoMail; T.TearLine := '--- MK Bbs';
         T.OriginLine := ' * Origin: Test (1:110/290)'; T.PrivMode := 2; T.ForceFrom := 'Test User'; T.ReDate := True; end;
    4: MapProc := False;
    9: begin T.AreaId := 'J' + Dir + 'bad'; T.Area := 99; Moved := True; end;
    else MapProc := False;
  end;
end;

procedure NoteProc(Code: Word; Conf: LongInt; Msg: AbsMsgPtr);
begin
  if Code < 10 then Inc(Notes[Code]);
  if (Code = qiPosted) and (NumPosted < 20) then begin Inc(NumPosted); Posted[NumPosted] := Msg^.GetMsgNum; end;
end;

function Esc(S: String): String;
var i: Word; R: String;
begin R := '';
  for i := 1 to Length(S) do
    if S[i] = #1 then R := R + '^' else if S[i] = #13 then R := R + '|' else R := R + S[i];
  Esc := R;
end;

function AllText(M: AbsMsgPtr): String;
var S: String; C: Char;
begin S := '';
  M^.MsgTxtStartUp;
  C := M^.GetChar;
  while not M^.EOM do begin S := S + C; C := M^.GetChar; end;
  if (Length(S) > 0) and (S[Length(S)] = #13) then SetLength(S, Length(S) - 1);   { JAM does not keep the last line end }
  AllText := S;
end;

procedure MakeRep(F: String);
var Q: QwkMsgObj;
begin
  EraseFile(F);
  Q.Init; Q.SetMsgPath(F); Q.SetPacketId('MKBBS'); Q.SetRepMode(True);
  Q.CreateMsgBase(0, 0);
  Q.StartNewMsg; Q.SetFrom('TEST USER'); Q.SetTo('ALL'); Q.SetSubj('Hello world'); Q.SetMsgConf(1);
  Q.SetDate('11-17-26'); Q.SetTime('10:11'); Q.SetMsgId('x 1');
  Q.DoStringLn('first line'); Q.DoStringLn('second line'); Q.WriteMsg;
  Q.StartNewMsg; Q.SetFrom('SOMEBODY ELSE'); Q.SetTo('MARK MAY'); Q.SetSubj('Private one'); Q.SetMsgConf(1);
  Q.SetDate('11-17-26'); Q.SetTime('10:12'); Q.SetPriv(True); Q.SetRefer(5);
  Q.DoStringLn('secret'); Q.WriteMsg;
  Q.StartNewMsg; Q.SetFrom('TEST USER'); Q.SetTo('SYSOP'); Q.SetSubj('@1:110/100'); Q.SetMsgConf(2);
  Q.SetDate('11-17-26'); Q.SetTime('10:13'); Q.SetPriv(True);
  Q.DoStringLn('Subj: The real subject'); Q.DoStringLn('netmail body'); Q.WriteMsg;
  Q.StartNewMsg; Q.SetFrom('TEST USER'); Q.SetTo('SYSOP'); Q.SetSubj('no address'); Q.SetMsgConf(2);
  Q.SetDate('11-17-26'); Q.SetTime('10:14'); Q.DoStringLn('lost'); Q.WriteMsg;
  Q.StartNewMsg; Q.SetFrom('TEST USER'); Q.SetTo('mark may'); Q.SetSubj('Echo reply'); Q.SetMsgConf(3);
  Q.SetDate('01-02-03'); Q.SetTime('04:05'); Q.SetPriv(True); Q.DoStringLn('echo text'); Q.WriteMsg;
  Q.StartNewMsg; Q.SetFrom('TEST USER'); Q.SetTo('ALL'); Q.SetSubj('Refused'); Q.SetMsgConf(4);
  Q.DoStringLn('nobody wants it'); Q.WriteMsg;
  Q.StartNewMsg; Q.SetFrom('TEST USER'); Q.SetTo('ALL'); Q.SetSubj('Unknown conference'); Q.SetMsgConf(9);
  Q.SetDate('11-17-26'); Q.SetTime('10:15'); Q.DoStringLn('goes to the area for bad messages'); Q.WriteMsg;
  Q.Done;
end;

procedure MakeArea(Name: String);
var M: AbsMsgPtr;
begin
  if OpenOrCreateMsgArea(M, 'J' + Dir + Name) then CloseMsgArea(M) else writeln('cannot make ', Name);
end;

var R: QwkImpResult; E: Word; M: AbsMsgPtr; i: Integer; S: String;
begin
  Fails := 0;
  Dir := WithBackSlash(ParamStr(1));
  MakeRep(Dir + 'test.msg');
  MakeArea('a1'); MakeArea('net'); MakeArea('echo'); MakeArea('bad');
  EraseFile(Dir + 'imp.dup');
  FillChar(Notes, SizeOf(Notes), 0);
  NumPosted := 0;
  E := QwkImportFile(Dir + 'test.msg', Dir + 'imp.dup', MapProc, NoteProc, R);
  Check('QwkImportFile: no error', E = 0);
  Check('7 messages in the file; 5 posted (one moved), 1 refused, 1 grunged, 0 dupes',
    (R.Msgs = 7) and (R.Posted = 5) and (R.Moved = 1) and (R.Refused = 1) and (R.Grunged = 1) and (R.Dupes = 0) and (R.Failed = 0));
  Check('the notes agree: 5 posted, 1 grunged, 1 refused (the conference), 1 moved',
    (Notes[qiPosted] = 5) and (Notes[qiGrunged] = 1) and (Notes[qiRefused] = 1) and (Notes[qiMoved] = 1));

  { area 1: the public one, with the forced name; the private one from somebody else is private as it said }
  Check('open area 1', OpenMsgArea(M, 'J' + Dir + 'a1'));
  Check('... 2 messages', M^.GetHighMsgNum = 2);
  M^.SeekFirst(1); M^.MsgStartUp;
  Check('... #1: from the forced name, to All (Proper case), subject, date, time, public',
    (M^.GetFrom = 'Test User') and (M^.GetTo = 'All') and (M^.GetSubj = 'Hello world') and (M^.GetDate = '11-17-26') and
    (M^.GetTime = '10:11') and not M^.IsPriv);
  S := Esc(AllText(M)); Check('... its text has no kludge line and no tear / origin (normal area): ' + S, S = 'first line|second line');
  M^.SeekNext; M^.MsgStartUp;
  Check('... #2: forced name, to Mark May, private, reference 5', (M^.GetFrom = 'Test User') and (M^.GetTo = 'Mark May') and M^.IsPriv and (M^.GetRefer = 5));
  CloseMsgArea(M);

  { netmail }
  Check('open the netmail area', OpenMsgArea(M, 'J' + Dir + 'net'));
  Check('... 1 message (the one without an address was grunged)', M^.GetHighMsgNum = 1);
  M^.SeekFirst(1); M^.MsgStartUp;
  Check('... subject from the "Subj:" line, to Sysop, private', (M^.GetSubj = 'The real subject') and (M^.GetTo = 'Sysop') and M^.IsPriv);
  S := Esc(AllText(M)); Check('... text is only the body: ' + S, S = 'netmail body');
  CloseMsgArea(M);

  { echo: tear and origin, redated, never private }
  Check('open the echo area', OpenMsgArea(M, 'J' + Dir + 'echo'));
  M^.SeekFirst(1); M^.MsgStartUp;
  Check('... not private although the message said so', not M^.IsPriv);
  Check('... redated (not 01-02-03)', M^.GetDate <> '01-02-03');
  Check('... text, tear line, origin line', Pos('echo text|--- MK Bbs|', Esc(AllText(M))) > 0);
  CloseMsgArea(M);

  { the area for bad messages }
  Check('open the area for bad messages', OpenMsgArea(M, 'J' + Dir + 'bad'));
  M^.SeekFirst(1); M^.MsgStartUp;
  Check('... the message of conference 9 is there', (M^.GetHighMsgNum = 1) and (M^.GetSubj = 'Unknown conference') and (M^.GetFrom = 'Test User'));
  CloseMsgArea(M);

  { the same file again: all posted ones are duplicates }
  FillChar(Notes, SizeOf(Notes), 0);
  E := QwkImportFile(Dir + 'test.msg', Dir + 'imp.dup', MapProc, NoteProc, R);
  Check('importing the file again: 5 dupes, nothing posted', (E = 0) and (R.Dupes = 5) and (R.Posted = 0) and (Notes[qiDupe] = 5));
  Check('... the areas did not grow', OpenMsgArea(M, 'J' + Dir + 'a1') and (M^.GetHighMsgNum = 2));
  CloseMsgArea(M);

  { errors }
  E := QwkImportFile(Dir + 'nothere.msg', '', MapProc, NoteProc, R);
  Check('no file: 1001', E = 1001);
  writeln('failures: ', Fails);
  Halt(Fails);
end.
