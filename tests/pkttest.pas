program pkttest;
{$mode tp}
{ pkttest write <file>   the messages pkttest.py also makes with MessagePacket.js
  pkttest dump <file>    every message of a packet, one field per line
  pkttest self <dir>     round trips, ReWriteHdr, DeleteMsg, yours, errors, UTF-8 }
uses MKString, MKFile, MKGlobT, MKMsgAbs, MKMsgPkt, Dos;

var Fails: Integer;
    M: PktMsgObj;
    Orig, Dest, A: AddrType;

procedure Check(N: String; Ok: Boolean);
begin if Ok then writeln('ok   pkt: ', N) else begin writeln('FAIL pkt: ', N); Inc(Fails); end; end;

function Esc(S: String): String;
var i: Word; R: String;
begin R := '';
  for i := 1 to Length(S) do
    if S[i] = #1 then R := R + '^'
    else if S[i] = #13 then R := R + '|'
    else if S[i] = #10 then R := R + '~'
    else if S[i] < ' ' then R := R + '.'
    else R := R + S[i];
  Esc := R;
end;

function AStr(var X: AddrType): String;
begin AStr := Long2Str(X.Zone) + ':' + Long2Str(X.Net) + '/' + Long2Str(X.Node) + '.' + Long2Str(X.Point); end;

function AllText: String;
var S: String; C: Char;
begin S := '';
  M.MsgTxtStartUp;
  C := M.GetChar;
  while not M.EOM do begin S := S + C; C := M.GetChar; end;
  AllText := S;
end;

procedure Dump(F: String);
var E: Word; Z, Y: AddrType;
begin
  M.Init; M.SetMsgPath(F);
  E := M.OpenMsgBase;
  if E <> 0 then begin writeln('open error ', E); Fails := 1; M.Done; Exit; end;
  M.GetPktOrig(Z); M.GetPktDest(Y);
  writeln('packet ', AStr(Z), ' ', AStr(Y), ' pwd=', M.GetPktPassword, ' n=', M.NumberOfMsgs, ' clean=', M.PktClean);
  M.SeekFirst(1);
  while M.SeekFound do begin
    M.MsgStartUp;
    M.GetOrig(A); M.GetDest(Dest);
    writeln('msg ', M.GetMsgNum, ' from=', M.GetFrom, ' to=', M.GetTo, ' subj=', M.GetSubj,
      ' date=', M.GetDate, ' time=', M.GetTime, ' orig=', AStr(A), ' dest=', AStr(Dest),
      ' attr=', M.GetAttr, ' cost=', M.GetCost, ' area=', M.GetArea, ' msgid=', M.GetMsgId);
    writeln('text ', Esc(AllText));
    M.SeekNext;
  end;
  M.CloseMsgBase; M.Done;
end;

procedure WriteTwo(F: String);
var E: Word;
begin
  M.Init; M.SetMsgPath(F);
  Orig.Zone := 1; Orig.Net := 110; Orig.Node := 290; Orig.Point := 0;
  Dest.Zone := 1; Dest.Net := 110; Dest.Node := 100; Dest.Point := 0;
  M.SetPacketInfo(Orig, Dest, 'SECRET');
  M.StartNewMsg;
  M.SetFrom('Mark May'); M.SetTo('All'); M.SetSubj('Caf' + #130 + ' test');
  M.SetMailType(mmtEchoMail); M.SetArea('TEST.ECHO'); M.SetMsgId('1:110/290 6a0b0001');
  M.SetDate('11-16-26'); M.SetTime('13:14');
  M.DoStringLn('Hello'); M.DoStringLn('second line ' + #130);
  E := M.WriteMsg; Check('write echomail', E = 0);
  M.StartNewMsg;
  M.SetFrom('Mark May'); M.SetTo('Sysop'); M.SetSubj('Net'); M.SetMsgId('1:110/290.2 6a0b0002');
  Orig.Point := 2; Dest.Zone := 2; Dest.Net := 250; Dest.Node := 1; Dest.Point := 3;
  M.SetOrig(Orig); M.SetDest(Dest);
  M.SetPriv(True); M.SetCrash(True);
  M.SetDate('11-16-26'); M.SetTime('13:14');
  M.DoStringLn('net body');
  E := M.WriteMsg; Check('write netmail', E = 0);
  M.Done;
end;

procedure Self(D: String);
var F, F2: String; E: Word; i: Word; S: String; N: LongInt; Z, Y: AddrType; Tm: Text; B: Byte;
    Fl: File;
begin
  D := WithBackSlash(D);
  F := D + 'self.pkt';
  EraseFile(F);
  M.Init; M.SetMsgPath(F);
  Check('no packet yet: MsgBaseExists False, OpenMsgBase 1001', (not M.MsgBaseExists) and (M.OpenMsgBase = 1001));
  Check('creating needs packet info (1003)', M.CreateMsgBase(0, 0) = 1003);
  Orig.Zone := 1; Orig.Net := 110; Orig.Node := 290; Orig.Point := 0;
  Dest.Zone := 1; Dest.Net := 110; Dest.Node := 100; Dest.Point := 0;
  M.SetPacketInfo(Orig, Dest, 'PW');
  Check('CreateMsgBase', M.CreateMsgBase(0, 0) = 0);
  Check('... again: 1009', M.CreateMsgBase(0, 0) = 1009);
  Check('an empty packet opens, 0 messages', (M.OpenMsgBase = 0) and (M.NumberOfMsgs = 0) and (M.GetHighMsgNum = 0) and M.PktClean);
  M.SeekFirst(1);
  Check('... SeekFound False', not M.SeekFound);
  M.GetPktOrig(Z); M.GetPktDest(Y);
  Check('header: addresses, password', (AStr(Z) = '1:110/290.0') and (AStr(Y) = '1:110/100.0') and (M.GetPktPassword = 'PW'));

  { echomail while the packet is open: reloaded, positioned on the new message }
  M.StartNewMsg;
  M.SetFrom('Mark May'); M.SetTo(''); M.SetSubj('First'); M.SetMailType(mmtEchoMail); M.SetArea('MK.TEST');
  M.SetDate('03-05-97'); M.SetTime('07:08');
  M.DoStringLn('line one'); M.DoKludgeLn('PID: MKBBS 1.0'); M.DoStringLn('line two'); M.DoString('no final cr');
  Check('echomail write (open packet)', M.WriteMsg = 0);
  Check('... now 1 message, current is #1', (M.NumberOfMsgs = 1) and (M.GetMsgNum = 1) and M.SeekFound);
  M.MsgStartUp;
  Check('... from / to (All) / subject / area', (M.GetFrom = 'Mark May') and (M.GetTo = 'All') and (M.GetSubj = 'First') and (M.GetArea = 'MK.TEST'));
  Check('... date 03-05-97, time 07:08', (M.GetDate = '03-05-97') and (M.GetTime = '07:08'));
  M.GetOrig(A); M.GetDest(Dest);
  Check('... origin 1:110/290, destination = the packet destination', (AStr(A) = '1:110/290.0') and (AStr(Dest) = '1:110/100.0'));
  Check('... made a MSGID: <address> <8 hex>', (Copy(M.GetMsgId, 1, 10) = '1:110/290 ') and (Length(M.GetMsgId) = 18));
  S := AllText;
  Check('... text: MSGID kludge, PID kludge, lines, tear, origin, SEEN-BY (with ^A), PATH',
    (Pos(#1'MSGID: 1:110/290 ', S) = 1) and (Pos(#1'PID: MKBBS 1.0'#13, S) > 0) and (Pos('line one'#13, S) > 0) and
    (Pos('no final cr'#13'--- mkbbs'#13' * Origin: mkbbs (1:110/290)'#13, S) > 0) and
    (Pos(#1'SEEN-BY: 110/100 290'#13, S) > 0) and (Pos(#1'PATH: 110/290'#13, S) > 0));
  Check('... the AREA: line is not in the text', Pos('AREA:', S) = 0);
  M.MsgTxtStartUp;
  S := M.GetNoKludgeStr(79);
  Check('... GetNoKludgeStr skips the kludge lines', S = 'line one');

  { netmail }
  M.StartNewMsg;
  M.SetFrom('Mark May'); M.SetTo('Sysop'); M.SetSubj('Net'); M.SetMailType(mmtNetMail);
  Orig.Point := 4; Dest.Zone := 2; Dest.Net := 250; Dest.Node := 7; Dest.Point := 0;
  M.SetOrig(Orig); M.SetDest(Dest); M.SetPriv(True); M.SetCrash(True); M.SetLocal(True);
  M.DoStringLn('to you');
  Check('netmail write', M.WriteMsg = 0);
  Check('... #2', (M.NumberOfMsgs = 2) and (M.GetMsgNum = 2));
  M.SeekFirst(2); M.MsgStartUp;
  M.GetOrig(A); M.GetDest(Dest);
  Check('... origin 1:110/290.4 (INTL, FMPT), destination 2:250/7.0', (AStr(A) = '1:110/290.4') and (AStr(Dest) = '2:250/7.0'));
  Check('... private, crash, local, not echoed', M.IsPriv and M.IsCrash and M.IsLocal and (not M.IsEchoed) and (not M.IsRcvd));
  S := AllText;
  Check('... INTL and FMPT kludges, no tear / origin', (Pos(#1'INTL 2:250/7 1:110/290'#13, S) = 1) and (Pos(#1'FMPT 4'#13, S) > 0) and
    (Pos('---', S) = 0) and (Pos('Origin', S) = 0));

  { errors }
  M.StartNewMsg; M.SetFrom('a'); M.SetTo('b'); M.SetMailType(mmtEchoMail);
  Check('echomail without an area: 1005', M.WriteMsg = 1005);
  M.StartNewMsg; M.SetFrom('a'); M.SetTo('b'); M.SetArea('X'); M.SetPriv(True);
  Check('private echomail: 1014', M.WriteMsg = 1014);
  M.StartNewMsg; M.SetFrom('a'); M.SetTo('b'); M.SetMailType(mmtNetMail);
  Check('netmail without a destination: 1006', M.WriteMsg = 1006);
  M.StartNewMsg; M.SetFrom('A name that is far too long to fit in thirty-five bytes'); M.SetTo('b'); M.SetArea('X');
  Check('a name over 35 bytes: 1012', M.WriteMsg = 1012);
  M.StartNewMsg; M.SetFrom(''); M.SetTo('b'); M.SetArea('X');
  Check('no from: 1013', M.WriteMsg = 1013);
  Check('nothing was added by those', M.NumberOfMsgs = 2);

  { flags: ReWriteHdr }
  M.SeekFirst(1); M.MsgStartUp;
  M.SetRcvd(True); M.SetSent(True); M.ReWriteHdr;
  Check('ReWriteHdr keeps the state in memory', M.IsRcvd and M.IsSent);
  M.CloseMsgBase;
  Check('reopen', M.OpenMsgBase = 0);
  M.SeekFirst(1); M.MsgStartUp;
  Check('... received and sent are in the file; the other message is unchanged',
    M.IsRcvd and M.IsSent);
  M.SeekFirst(2); M.MsgStartUp;
  Check('... #2 unchanged', M.IsPriv and M.IsCrash and (not M.IsRcvd));

  { yours }
  M.StartNewMsg; M.SetFrom('Someone'); M.SetTo('mark may'); M.SetSubj('For you'); M.SetArea('MK.TEST'); M.DoStringLn('x');
  Check('write #3 (To in lower case)', M.WriteMsg = 0);
  M.StartNewMsg; M.SetFrom('Someone'); M.SetTo('Handle'); M.SetSubj('For the handle'); M.SetArea('MK.TEST'); M.DoStringLn('y');
  Check('write #4', M.WriteMsg = 0);
  M.YoursFirst('Mark May', 'Handle');
  Check('YoursFirst: #3', M.YoursFound and (M.GetMsgNum = 3) and (M.GetSubj = 'For you'));
  M.YoursNext;
  Check('YoursNext: #4 (the handle)', M.YoursFound and (M.GetMsgNum = 4));
  M.YoursNext;
  Check('YoursNext: no more', not M.YoursFound);

  { seeking }
  M.SeekFirst(0);
  Check('SeekFirst(0) = first message', M.SeekFound and (M.GetMsgNum = 1));
  M.SeekPrior;
  Check('SeekPrior before the first: not found', not M.SeekFound);
  M.SeekNext;
  Check('... SeekNext after that: #1', M.SeekFound and (M.GetMsgNum = 1));
  M.SeekFirst(4); M.SeekNext;
  Check('SeekNext after the last: not found', not M.SeekFound);
  M.SeekPrior;
  Check('... SeekPrior from there: #4', M.SeekFound and (M.GetMsgNum = 4));
  M.SeekFirst(99);
  Check('SeekFirst(99): not found', not M.SeekFound);
  M.SetMsgLoc(3);
  Check('... #3', M.SeekFound and (M.GetMsgLoc = 3));

  { delete }
  M.SeekFirst(2); M.MsgStartUp;
  M.DeleteMsg;
  Check('DeleteMsg #2: 3 messages, cursor on the one before', (M.NumberOfMsgs = 3) and (M.GetMsgNum = 1));
  M.SeekNext; M.MsgStartUp;
  Check('... the old #3 is #2 now', M.GetSubj = 'For you');
  M.SeekFirst(1); M.MsgStartUp;
  Check('... #1 is intact', (M.GetSubj = 'First') and (Pos('line two', AllText) > 0));
  Check('... no .tmp left', not FileExist(F + '.tmp'));
  M.CloseMsgBase;

  { a packet that changed while open is not written to }
  Check('reopen for the change test', M.OpenMsgBase = 0);
  Assign(Fl, F); Reset(Fl, 1); Seek(Fl, FileSize(Fl)); B := 0; BlockWrite(Fl, B, 1); Close(Fl);
  M.SeekFirst(1); M.MsgStartUp; M.SetRcvd(False); M.ReWriteHdr;
  Check('ReWriteHdr on a packet that changed: nothing written', M.IsRcvd = False);
  M.SeekFirst(1); M.DeleteMsg;
  Check('DeleteMsg on a packet that changed: still 3 messages', M.NumberOfMsgs = 3);
  M.CloseMsgBase;
  Assign(Fl, F); Reset(Fl, 1); Seek(Fl, FileSize(Fl) - 3); B := 7; BlockWrite(Fl, B, 1); BlockWrite(Fl, B, 1); Close(Fl);
  M.StartNewMsg; M.SetFrom('a'); M.SetTo('b'); M.SetArea('X');
  Check('a packet with a bad message type (damaged) is not appended to: 1007', M.WriteMsg = 1007);

  { UTF-8 writing and reading, CP437 reading }
  F2 := D + 'utf.pkt';
  EraseFile(F2);
  M.Done;
  M.Init; M.SetMsgPath(F2);
  M.SetPacketInfo(Orig, Dest, '');
  M.SetWriteUtf8(True);
  M.StartNewMsg; M.SetFrom('Jos' + #130); M.SetTo('All'); M.SetSubj('Caf' + #130 + ' ' + #176); M.SetArea('X');
  M.DoStringLn('caf' + #130 + ' ' + #219 + ' end');
  Check('write UTF-8', M.WriteMsg = 0);
  Assign(Fl, F2); Reset(Fl, 1); N := FileSize(Fl); Close(Fl);
  Check('... the file has CHRS: UTF-8 4 and UTF-8 bytes', N > 100);
  M.SetWriteUtf8(False);
  M.StartNewMsg; M.SetFrom('Jos' + #130); M.SetTo('All'); M.SetSubj('plain cp437'); M.SetArea('X');
  M.DoStringLn('caf' + #130);
  Check('write CP437 (second message, same packet)', M.WriteMsg = 0);
  Check('open', M.OpenMsgBase = 0);
  M.SeekFirst(1); M.MsgStartUp;
  Check('UTF-8 message read back as CP437: from, subject', (M.GetFrom = 'Jos' + #130) and (M.GetSubj = 'Caf' + #130 + ' ' + #176));
  S := AllText;
  Check('... text', Pos('caf' + #130 + ' ' + #219 + ' end', S) > 0);
  Check('... the CHRS kludge is there', Pos(#1'CHRS: UTF-8 4'#13, S) > 0);
  M.SeekFirst(2); M.MsgStartUp;
  Check('CP437 message: from and text', (M.GetFrom = 'Jos' + #130) and (Pos('caf' + #130, AllText) > 0));
  M.CloseMsgBase;
  M.SetReadCharset(pcLatin1);
  M.OpenMsgBase; M.SeekFirst(2); M.MsgStartUp;
  Check('read as Latin-1 (setting, no CHRS): e acute from Latin-1 would be $E9 -> CP437 $82; byte $82 is a control: ?',
    M.GetFrom <> '');
  M.CloseMsgBase; M.Done;
end;

begin
  if ParamCount < 2 then begin writeln('usage'); Halt(2); end;
  FileMode := fmReadWrite;
  if ParamStr(1) = 'write' then begin EraseFile(ParamStr(2)); WriteTwo(ParamStr(2)); end
  else if ParamStr(1) = 'dump' then Dump(ParamStr(2))
  else Self(ParamStr(2));
  if ParamStr(1) = 'self' then writeln('failures: ', Fails);
  Halt(Fails);
end.
