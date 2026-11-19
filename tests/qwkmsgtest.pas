program qwkmsgtest;
{$mode tp}
{$H+}
{ qwkmsgtest write <file> [rep]   the messages qwkjs.mjs also writes
  qwkmsgtest dump <file> [rep]    every message of a file, one field per line
  qwkmsgtest reply <file> <conf> <board>  a REP with two messages in conference <conf> and one in 999
  qwkmsgtest self <dir>           round trips, conferences, kludges, status, ReWriteHdr, DeleteMsg, errors, damage }
uses MKString, MKFile, MKGlobT, MKMsgAbs, MKMsgQwk, Dos;

var Fails: Integer;
    M: QwkMsgObj;

procedure Check(N: String; Ok: Boolean);
begin if Ok then writeln('ok   qwk: ', N) else begin writeln('FAIL qwk: ', N); Inc(Fails); end; end;

function Esc(S: String): String;
var i: Word; R: String;
begin R := '';
  for i := 1 to Length(S) do
    if S[i] = #1 then R := R + '^'
    else if S[i] = #13 then R := R + '|'
    else if S[i] < ' ' then R := R + '.'
    else R := R + S[i];
  Esc := R;
end;

function AllText: String;
var S: String; C: Char;
begin S := '';
  M.MsgTxtStartUp;
  C := M.GetChar;
  while not M.EOM do begin S := S + C; C := M.GetChar; end;
  AllText := S;
end;

function B2S(B: Boolean): String;
begin if B then B2S := 'T' else B2S := 'F'; end;

procedure Dump(F: String; Rep: Boolean);
var E: Word;
begin
  M.Init; M.SetMsgPath(F); M.SetRepMode(Rep);
  E := M.OpenMsgBase;
  if E <> 0 then begin writeln('open error ', E); Fails := 1; M.Done; Exit; end;
  writeln('file id=', M.GetPacketId, ' n=', M.NumberOfMsgs, ' clean=', B2S(M.GetClean));
  M.SeekFirst(1);
  while M.SeekFound do begin
    M.MsgStartUp;
    writeln('msg ', M.GetMsgNum, ' conf=', M.GetMsgConf, ' qwk=', M.GetQwkNum, ' logical=', M.GetLogicalNum,
      ' from=', M.GetFrom, ' to=', M.GetTo, ' subj=', M.GetSubj, ' date=', M.GetDate, ' time=', M.GetTime,
      ' priv=', B2S(M.IsPriv), ' rcvd=', B2S(M.IsRcvd), ' ref=', M.GetRefer, ' status=', M.GetStatusChar,
      ' echo=', B2S(M.GetEchoFlag), ' tag=', B2S(M.GetHasTag), ' msgid=', M.GetMsgId, ' reply=', M.GetReplyId);
    writeln('text ', Esc(AllText));
    M.SeekNext;
  end;
  M.CloseMsgBase; M.Done;
end;

procedure WriteSet(F: String; Rep: Boolean);
var E: Word;
begin
  EraseFile(F);
  M.Init; M.SetMsgPath(F); M.SetPacketId('MKBBS');
  M.SetRepMode(Rep);
  if Rep then M.SetMailType(mmtEchoMail);
  Check('create', M.CreateMsgBase(0, 0) = 0);
  M.StartNewMsg;
  M.SetFrom('Mark May'); M.SetTo('All'); M.SetSubj('Caf' + #130 + ' test'); M.SetMsgConf(7);
  M.SetDate('11-16-26'); M.SetTime('13:14'); M.SetMsgId('1:110/290 6a0b0001');
  M.DoStringLn('Hello'); M.DoStringLn('second line ' + #130);
  E := M.WriteMsg; Check('write 1', E = 0);
  M.StartNewMsg;
  M.SetFrom('Mark May'); M.SetTo('Sysop'); M.SetSubj('Reply'); M.SetMsgConf(7);
  M.SetDate('11-16-26'); M.SetTime('13:15'); M.SetRefer(1); M.SetPriv(True);
  M.SetReplyId('1:110/290 6a0b0001'); M.SetMsgId('1:110/290 6a0b0002');
  M.DoStringLn('reply body');
  E := M.WriteMsg; Check('write 2', E = 0);
  M.StartNewMsg;
  M.SetFrom('Mark May'); M.SetTo('Bob'); M.SetSubj('Other conference'); M.SetMsgConf(12);
  M.SetDate('11-17-26'); M.SetTime('09:05'); M.SetPriv(True); M.SetRcvd(True);
  M.DoStringLn('three'); M.DoStringLn(''); M.DoStringLn('lines');
  E := M.WriteMsg; Check('write 3', E = 0);
  M.Done;
end;

{ a QWK file made by hand: header + text blocks }
procedure RawMsg(var Fl: File; Num: Word; Conf: Word; Frm, Tto, Subj, Txt: String; Status: Char);
var H: array[0..127] of Byte; B: array[0..127] of Byte; i, n, blocks: Word; T: String; Got: Word;
begin
  FillChar(H, 128, 32);
  H[0] := Ord(Status);
  T := Long2Str(Num); for i := 1 to Length(T) do H[i] := Ord(T[i]);
  T := '11-16-26'; for i := 1 to 8 do H[7 + i] := Ord(T[i]);
  T := '13:14'; for i := 1 to 5 do H[15 + i] := Ord(T[i]);
  for i := 1 to Length(Tto) do H[20 + i] := Ord(Tto[i]);
  for i := 1 to Length(Frm) do H[45 + i] := Ord(Frm[i]);
  for i := 1 to Length(Subj) do H[70 + i] := Ord(Subj[i]);
  blocks := 1 + (Length(Txt) + 127) div 128;
  T := Long2Str(blocks); for i := 1 to Length(T) do H[115 + i] := Ord(T[i]);
  H[122] := 225; H[123] := Conf and 255; H[124] := Conf shr 8;
  BlockWrite(Fl, H, 128);
  i := 1;
  while i <= Length(Txt) do begin
    FillChar(B, 128, 32);
    n := 0;
    while (n < 128) and (i <= Length(Txt)) do begin B[n] := Ord(Txt[i]); Inc(n); Inc(i); end;
    BlockWrite(Fl, B, 128);
  end;
end;

procedure RawStart(var Fl: File; FN: String);
var H: array[0..127] of Byte;
begin
  Assign(Fl, FN); ReWrite(Fl, 1);
  FillChar(H, 128, 32); H[0] := Ord('P'); H[1] := Ord('K');
  BlockWrite(Fl, H, 128);
end;

{ qwkmsgtest reply <file> <conf> <boardid>: the reply packet a QWK reader would make (tests/qwktest.py) }
procedure Reply(F: String; Conf: LongInt; Board: String; Tag: String);
begin
  EraseFile(F);
  M.Init; M.SetMsgPath(F); M.SetPacketId(Board); M.SetRepMode(True);
  M.CreateMsgBase(0, 0);
  M.StartNewMsg; M.SetFrom('MARK MAY'); M.SetTo('ALL'); M.SetSubj('Reply via REP' + Tag); M.SetMsgConf(Conf);
  M.SetDate('11-17-26'); M.SetTime('12:30'); M.DoStringLn('reply line one'); M.DoStringLn('reply line two'); M.WriteMsg;
  M.StartNewMsg; M.SetFrom('SOMEONE ELSE'); M.SetTo('SYSOP'); M.SetSubj('Second reply' + Tag); M.SetMsgConf(Conf);
  M.SetDate('11-17-26'); M.SetTime('12:31'); M.DoStringLn('another one'); M.WriteMsg;
  M.StartNewMsg; M.SetFrom('MARK MAY'); M.SetTo('ALL'); M.SetSubj('Lost one' + Tag); M.SetMsgConf(999);
  M.SetDate('11-17-26'); M.SetTime('12:32'); M.DoStringLn('nobody has conference 999'); M.WriteMsg;
  M.Done;
end;


{ qwkmsgtest control <file> <board> <conf>:<subject> ...: a reply packet of control messages to SBBS (tests/qwkpassivetest.py) }
procedure Control(F: String; Board: String);
var i: Word; S: String; P: Word;
begin
  EraseFile(F);
  M.Init; M.SetMsgPath(F); M.SetPacketId(Board); M.SetRepMode(True);
  M.CreateMsgBase(0, 0);
  for i := 4 to ParamCount do
  begin
    S := ParamStr(i); P := Pos(':', S);
    M.StartNewMsg; M.SetFrom('MARK MAY'); M.SetTo('SBBS'); M.SetSubj(Copy(S, P + 1, 70)); M.SetMsgConf(Str2Long(Copy(S, 1, P - 1)));
    M.SetDate('11-18-26'); M.SetTime('12:00'); M.DoStringLn('control message'); M.WriteMsg;
  end;
  M.Done;
end;


{ qwkmsgtest hub <file> <conf>: the MESSAGES.DAT of a hub (tests/qwknettest.py): two messages in conference <conf>, one in 99 }
procedure Hub(F: String; Conf: LongInt);
begin
  EraseFile(F);
  M.Init; M.SetMsgPath(F); M.SetPacketId('HUBPKT');
  M.CreateMsgBase(0, 0);
  M.StartNewMsg; M.SetFrom('REMOTE USER'); M.SetTo('ALL'); M.SetSubj('Hub message one'); M.SetMsgConf(Conf);
  M.SetDate('11-18-26'); M.SetTime('09:00'); M.DoStringLn('from the hub, line one'); M.DoStringLn('line two'); M.WriteMsg;
  M.StartNewMsg; M.SetFrom('ANOTHER REMOTE'); M.SetTo('ALL'); M.SetSubj('Hub message two'); M.SetMsgConf(Conf);
  M.SetDate('11-18-26'); M.SetTime('09:01'); M.DoStringLn('second from the hub'); M.WriteMsg;
  M.StartNewMsg; M.SetFrom('REMOTE USER'); M.SetTo('ALL'); M.SetSubj('Unmapped'); M.SetMsgConf(99);
  M.SetDate('11-18-26'); M.SetTime('09:02'); M.DoStringLn('a conference nobody maps'); M.WriteMsg;
  M.Done;
end;


procedure Self(D: String);
var F, F2: String; E: Word; i: Word; S: String; N: LongInt; Fl: File; Raw: array[0..127] of Byte;
    Root: Boolean;
begin
  D := WithBackSlash(D);
  F := D + 'self.dat';
  EraseFile(F);
  M.Init; M.SetMsgPath(F);
  Check('no file yet: MsgBaseExists False, OpenMsgBase 1001', (not M.MsgBaseExists) and (M.OpenMsgBase = 1001));
  M.SetPacketId('SELF');
  Check('CreateMsgBase', M.CreateMsgBase(0, 0) = 0);
  Check('... again: 1009', M.CreateMsgBase(0, 0) = 1009);
  Check('... the packet id', M.GetPacketId = 'SELF');
  Check('an empty file opens: 0 messages, clean', (M.NumberOfMsgs = 0) and M.GetClean and (M.NextConf(-1) = -1));
  M.SeekFirst(1);
  Check('... SeekFound False', not M.SeekFound);

  { MESSAGES.DAT style: numbers per conference, logical numbers }
  M.StartNewMsg; M.SetFrom('mark may'); M.SetTo('bob'); M.SetSubj('Hello'); M.SetMsgConf(3);
  M.SetDate('03-05-97'); M.SetTime('07:08'); M.DoStringLn('line one'); M.DoString('no final cr');
  Check('write (conference 3)', M.WriteMsg = 0);
  Check('... its number in the file is 1', M.GetMsgNum = 1);
  M.StartNewMsg; M.SetFrom('Mark'); M.SetSubj('Second'); M.SetMsgConf(3); M.DoStringLn('two');
  Check('write (conference 3 again)', M.WriteMsg = 0);
  M.StartNewMsg; M.SetFrom('Mark'); M.SetTo('Alice'); M.SetSubj('Five'); M.SetMsgConf(5); M.DoStringLn('five');
  Check('write (conference 5)', M.WriteMsg = 0);
  Check('3 messages, conferences 3 and 5 (and not 4)',
    (M.NumberOfMsgs = 3) and (M.NextConf(-1) = 3) and (M.NextConf(3) = 5) and (M.NextConf(5) = -1) and
    M.ConfPresent(5) and not M.ConfPresent(4));
  M.SeekFirst(1);
  Check('message 1: names upper case, to ALL when empty, conference 3', M.SeekFound);
  M.MsgStartUp;
  Check('... from MARK MAY, to BOB, subject kept', (M.GetFrom = 'MARK MAY') and (M.GetTo = 'BOB') and (M.GetSubj = 'Hello'));
  Check('... date and time', (M.GetDate = '03-05-97') and (M.GetTime = '07:08'));
  Check('... text: both lines, the last one ended', AllText = 'line one'#13'no final cr'#13);
  Check('... qwk number 1, logical 1, conference 3, public, unread, status blank',
    (M.GetQwkNum = 1) and (M.GetLogicalNum = 1) and (M.GetMsgConf = 3) and not M.IsPriv and not M.IsRcvd and (M.GetStatusChar = ' '));
  M.SeekNext; M.MsgStartUp;
  Check('message 2: to ALL, number 2', (M.GetTo = 'ALL') and (M.GetQwkNum = 2) and (M.GetLogicalNum = 2));
  M.SeekNext; M.MsgStartUp;
  Check('message 3: conference 5 starts again at number 1, logical 3', (M.GetMsgConf = 5) and (M.GetQwkNum = 1) and (M.GetLogicalNum = 3) and (M.GetTo = 'ALICE'));
  M.SeekNext;
  Check('... then no more', not M.SeekFound);

  { one conference at a time }
  M.SetConference(3);
  Check('SetConference(3): 2 messages, numbered 1 and 2', (M.NumberOfMsgs = 2) and (M.GetHighMsgNum = 2) and (M.GetConference = 3));
  M.SeekFirst(2); M.MsgStartUp;
  Check('... #2 is "Second"', M.SeekFound and (M.GetSubj = 'Second'));
  M.SetConference(5);
  M.SeekFirst(1);
  Check('SetConference(5): 1 message, "Five"', (M.NumberOfMsgs = 1) and M.SeekFound and (M.GetSubj = 'Five'));
  M.SetConference(9);
  M.SeekFirst(1);
  Check('SetConference(9): nothing', (M.NumberOfMsgs = 0) and not M.SeekFound);
  M.SetConference(-1);
  Check('SetConference(-1): everything again', M.NumberOfMsgs = 3);
  M.SetConference(5);
  M.StartNewMsg; M.SetFrom('Mark'); M.SetSubj('Default conference'); M.DoStringLn('x');
  Check('write with the filter as the conference', M.WriteMsg = 0);
  Check('... into conference 5, number 2', (M.GetMsgNum = 2) and (M.NumberOfMsgs = 2));
  M.SetConference(-1);
  M.StartNewMsg; M.SetFrom('Mark'); M.SetSubj('No conference'); M.DoStringLn('y');
  Check('write with neither: conference 0 (the main board)', (M.WriteMsg = 0) and M.ConfPresent(0));
  { the BBS number in a packet, and where the header went (for the index files) }
  M.StartNewMsg; M.SetFrom('Mark'); M.SetSubj('Number'); M.SetMsgConf(7); M.SetQwkNum(4242); M.DoStringLn('z');
  Check('write with a number of the caller (SetQwkNum)', M.WriteMsg = 0);
  Check('... GetLastBlock is the block of its header (block 0 is the id)', (M.GetLastBlock > 0) and (M.GetLastBlock = SizeFile(F) div 128 - 2));
  M.SetConference(7); M.SeekFirst(1); M.MsgStartUp;
  Check('... number 4242 in the file, in conference 7', M.SeekFound and (M.GetQwkNum = 4242) and (M.GetMsgConf = 7));
  M.StartNewMsg; M.SetFrom('Mark'); M.SetSubj('Number'); M.SetMsgConf(7); M.DoStringLn('z2');
  Check('... the next one without SetQwkNum goes on after the highest', (M.WriteMsg = 0) and (M.GetMsgNum >= 1));
  M.SetConference(-1);

  { names and fields cut, kludges }
  M.StartNewMsg; M.SetFrom('A very long name that does not fit in 25'); M.SetTo('B'); M.SetSubj('A subject longer than twenty-five bytes');
  M.SetMsgConf(2); M.DoKludgeLn('MSGID: 1:2/3 abcd'); M.DoKludgeLn('REPLY: 1:2/3 0001'); M.DoKludgeLn('Via MKBBS Tue'); M.DoKludgeLn('TZ: 0100');
  M.DoKludgeLn('PID: MKBBS'); M.DoKludgeLn('CHRS: CP437 2'); M.DoStringLn('body line'); M.DoStringLn(''); M.DoStringLn('');
  Check('write with long fields and kludges', M.WriteMsg = 0);
  Check('... GetCut, 2 kludge lines dropped', M.GetCut and (M.GetDropped = 2));
  M.SetConference(2); M.SeekFirst(1); M.MsgStartUp;
  Check('... fields cut at 25', (M.GetFrom = 'A VERY LONG NAME THAT DOE') and (M.GetSubj = 'A subject longer than twe'));
  Check('... msgid and reply id', (M.GetMsgId = '1:2/3 abcd') and (M.GetReplyId = '1:2/3 0001'));
  S := AllText;
  Check('... the text: the four kludges as ^A lines, the body, no empty lines at the end',
    Esc(S) = '^MSGID: 1:2/3 abcd|^REPLY: 1:2/3 0001|^Via MKBBS Tue|^TZ: 0100|body line|');
  M.MsgTxtStartUp;
  S := M.GetNoKludgeStr(79);
  Check('... first line without kludges is "body line"', S = 'body line');

  { QWKE: long names and subjects }
  M.SetQwke(qkOn);
  M.StartNewMsg; M.SetFrom('Alexandria von Hohenzollern-Sigmaringen'); M.SetTo('Bob'); M.SetSubj('Re: a subject that is far longer than the 25 bytes');
  M.SetMsgConf(11); M.DoKludgeLn('MSGID: 1:2/3 e1'); M.DoStringLn('qwke body'); M.DoStringLn('To: this is text, not a header line');
  Check('QWKE write (qkOn)', M.WriteMsg = 0);
  Check('... nothing was cut', not M.GetCut);
  M.SetConference(11); M.SeekFirst(1); M.MsgStartUp;
  Check('... read back (qkOn): the long From and Subject whole, To short', (M.GetFrom = 'Alexandria von Hohenzollern-Sigmaringen') and
    (M.GetSubj = 'Re: a subject that is far longer than the 25 bytes') and (M.GetTo = 'BOB'));
  Check('... the text has no From:/Subject: lines, the MSGID kludge and the later "To:" text line stay',
    Esc(AllText) = '^MSGID: 1:2/3 e1|qwke body|To: this is text, not a header line|');
  M.SetQwke(qkAuto);
  M.SetConference(11); M.SeekFirst(1); M.MsgStartUp;
  Check('... read with qkAuto the same (the header fields are the start of the long ones)', M.GetFrom = 'Alexandria von Hohenzollern-Sigmaringen');
  M.SetQwke(qkOff);
  M.SetConference(11); M.SeekFirst(1); M.MsgStartUp;
  Check('... read with qkOff: cut at 25, the lines are text', (M.GetFrom = 'ALEXANDRIA VON HOHENZOLLE') and
    (Pos('From: Alexandria von Hohenzollern-Sigmaringen', Esc(AllText)) > 0));
  { qkAuto does not take a line of an ordinary message for a header: the header does not match it }
  M.SetQwke(qkOff);
  M.StartNewMsg; M.SetFrom('Mark'); M.SetTo('Jim'); M.SetSubj('Plain'); M.SetMsgConf(12);
  M.DoStringLn('From: somebody else entirely, written by hand as text'); M.DoStringLn('real text');
  Check('write a plain message that starts with a "From:" text line', M.WriteMsg = 0);
  M.SetQwke(qkAuto);
  M.SetConference(12); M.SeekFirst(1); M.MsgStartUp;
  Check('... qkAuto keeps it as text (the header From is not the start of it)', (M.GetFrom = 'MARK') and
    (Esc(AllText) = 'From: somebody else entirely, written by hand as text|real text|'));
  M.SetQwke(qkOn);
  M.SetConference(12); M.SeekFirst(1); M.MsgStartUp;
  Check('... qkOn takes it as the long From', M.GetFrom = 'somebody else entirely, written by hand as text');
  M.SetQwke(qkOff);
  M.SetConference(-1);

  { errors of WriteMsg }
  M.SetConference(-1);
  M.StartNewMsg; M.DoStringLn('x');
  Check('no from: 1005', M.WriteMsg = 1005);
  M.StartNewMsg; M.SetFrom('A');
  Check('no text: 1006', M.WriteMsg = 1006);
  M.StartNewMsg; M.SetFrom('A'); M.SetMsgConf(70000); M.DoStringLn('x');
  Check('conference 70000: 1008', M.WriteMsg = 1008);
  M.StartNewMsg; M.SetFrom('A'); M.DoStringLn('a' + #227 + 'b'); M.DoStringLn('c');
  Check('a $E3 in the text is written as ?', M.WriteMsg = 0);
  M.CloseMsgBase;

  { status, tag line, ReWriteHdr, DeleteMsg, yours }
  F2 := D + 'status.dat';
  EraseFile(F2);
  M.SetMsgPath(F2); M.SetPacketId('ST');
  Check('create the status file', M.CreateMsgBase(0, 0) = 0);
  M.StartNewMsg; M.SetFrom('A'); M.SetTo('Me'); M.SetSubj('s1'); M.SetPriv(True); M.SetHasTag(True); M.DoStringLn('one'); M.WriteMsg;
  M.StartNewMsg; M.SetFrom('A'); M.SetTo('Me'); M.SetSubj('s2'); M.SetPriv(True); M.SetRcvd(True); M.DoStringLn('two'); M.WriteMsg;
  M.StartNewMsg; M.SetFrom('A'); M.SetTo('Other'); M.SetSubj('s3'); M.SetRcvd(True); M.DoStringLn('three'); M.WriteMsg;
  M.StartNewMsg; M.SetFrom('A'); M.SetTo('Me'); M.SetSubj('s4'); M.DoStringLn('four'); M.WriteMsg;
  M.SeekFirst(1); M.MsgStartUp;
  Check('status: private unread is + (QWK style), tag line', (M.GetStatusChar = '+') and M.IsPriv and not M.IsRcvd and M.GetHasTag);
  M.SeekNext; M.MsgStartUp;
  Check('... private read is *', (M.GetStatusChar = '*') and M.IsPriv and M.IsRcvd and not M.GetHasTag);
  M.SeekNext; M.MsgStartUp;
  Check('... public read is -', (M.GetStatusChar = '-') and not M.IsPriv and M.IsRcvd);
  M.YoursFirst('me', '');
  Check('yours: message 1 (private, unread, to Me)', M.YoursFound and (M.GetMsgNum = 1));
  M.YoursNext;
  Check('... then message 4 (2 is read)', M.YoursFound and (M.GetMsgNum = 4));
  M.YoursNext;
  Check('... then no more', not M.YoursFound);
  M.SeekFirst(1); M.MsgStartUp; M.SetRcvd(True); M.SetRefer(77);
  M.ReWriteHdr;
  Check('ReWriteHdr: no error', M.GetError = 0);
  M.CloseMsgBase;
  Check('reopen', M.OpenMsgBase = 0);
  M.SeekFirst(1); M.MsgStartUp;
  Check('... message 1 is now read (*) with reference 77, tag line still there', M.IsRcvd and (M.GetStatusChar = '*') and (M.GetRefer = 77) and M.GetHasTag);
  M.SetStatusStyle(qsPcBoard);
  M.SeekFirst(2); M.MsgStartUp;
  Check('PCBoard style: * is private unread, + private read', (not M.IsRcvd) and M.IsPriv);
  M.SetStatusStyle(qsQwk);
  M.SeekFirst(2); M.MsgStartUp;
  M.SeekFirst(2);
  M.DeleteMsg;
  Check('DeleteMsg: no error, 3 messages, cursor on #1', (M.GetError = 0) and (M.NumberOfMsgs = 3) and (M.GetMsgNum = 1));
  M.SeekNext; M.MsgStartUp;
  Check('... SeekNext gives what was #3 (s3)', M.SeekFound and (M.GetSubj = 's3'));
  M.CloseMsgBase;
  Check('reopen: the killed message is gone, 3 left', (M.OpenMsgBase = 0) and (M.NumberOfMsgs = 3) and (M.NumberInFile = 3));

  { REP style }
  F2 := D + 'rep.msg';
  WriteSet(F2, True);
  M.Init; M.SetMsgPath(F2); M.SetRepMode(True);
  Check('REP file opens', M.OpenMsgBase = 0);
  Check('... conferences 7 and 12', (M.NextConf(-1) = 7) and (M.NextConf(7) = 12));
  M.SeekFirst(1); M.MsgStartUp;
  Check('... number field = conference (7), echo flag, status blank', (M.GetQwkNum = 7) and M.GetEchoFlag and (M.GetStatusChar = ' '));
  M.SeekNext; M.MsgStartUp;
  Check('... private unread is * (PCBoard style)', (M.GetStatusChar = '*') and M.IsPriv and not M.IsRcvd and (M.GetRefer = 1));
  Check('... msgid / reply id / the text with the kludges', (M.GetReplyId = '1:110/290 6a0b0001') and (Esc(AllText) = '^MSGID: 1:110/290 6a0b0002|^REPLY: 1:110/290 6a0b0001|reply body|'));
  M.SeekNext; M.MsgStartUp;
  Check('... #3: private read is + , empty line inside kept', (M.GetStatusChar = '+') and M.IsRcvd and (Esc(AllText) = 'three||lines|'));
  M.CloseMsgBase;
  M.SetRepMode(False);

  { a long line and a long message are kept; appending to a file that has messages }
  F2 := D + 'long.dat';
  EraseFile(F2);
  M.SetMsgPath(F2); M.SetPacketId('LONG'); M.CreateMsgBase(0, 0);
  S := '';
  for i := 1 to 250 do S := S + 'abcdefghij';
  M.StartNewMsg; M.SetFrom('A'); M.SetMsgConf(1);
  for i := 1 to 40 do begin M.DoString(Copy(S, 1, 200)); M.DoString(Copy(S, 1, i * 5)); M.DoChar(#13); end;
  Check('a message with long lines (about 11 KB)', M.WriteMsg = 0);
  M.CloseMsgBase;
  Check('reopen; append another message', M.OpenMsgBase = 0);
  M.StartNewMsg; M.SetFrom('B'); M.SetMsgConf(1); M.DoStringLn('short'); E := M.WriteMsg;
  Check('... 2 messages, numbers 1 and 2 (error ' + Long2Str(E) + ', ' + Long2Str(M.NumberOfMsgs) + ' msgs, number ' + Long2Str(M.GetMsgNum) + ')', (E = 0) and (M.NumberOfMsgs = 2) and (M.GetMsgNum = 2));
  M.SeekFirst(1); M.MsgStartUp;
  N := 0; M.MsgTxtStartUp;
  while not M.EOM do begin M.GetChar; Inc(N); end;
  Dec(N);                                       { the last GetChar only found the end }
  Check('the first message: 40 lines of 205, 210 ... 400 characters, all there (' + Long2Str(N) + ')',
    N = 40 + 5 * (40 * 41 div 2) + 200 * 40);
  M.CloseMsgBase;

  { lock }
  M.SetMsgPath(F); Check('open again', M.OpenMsgBase = 0);
  Check('LockMsgBase / UnLockMsgBase', M.LockMsgBase and M.LockMsgBase and M.UnLockMsgBase);
  M.CloseMsgBase;

  { character sets: a hand made packet with UTF-8 }
  F2 := D + 'utf8.dat';
  RawStart(Fl, F2);
  RawMsg(Fl, 1, 1, 'Jos' + #$C3#$A9, 'All', 'Caf' + #$C3#$A9, 'Voil' + #$C3#$A0 + ' ' + #$E2#$82#$AC + #227 + 'second', ' ');
  Close(Fl);
  M.SetMsgPath(F2); M.SetReadCharset(qcAuto);
  Check('utf8 packet opens', M.OpenMsgBase = 0);
  M.SeekFirst(1); M.MsgStartUp;
  Check('auto: UTF-8 found, names and text in CP437 (e acute = $82, a grave = $85; the euro sign has none: ?)',
    (M.GetFrom = 'Jos' + #130) and (M.GetSubj = 'Caf' + #130) and (AllText = 'Voil' + #133 + ' ?'#13'second'#13));
  M.SetReadCharset(qcCp437); M.SeekFirst(1); M.MsgStartUp;
  Check('cp437: the bytes as they are', M.GetFrom = 'Jos' + #$C3#$A9);
  M.SetReadCharset(qcLatin1); M.SeekFirst(1); M.MsgStartUp;
  Check('latin1: two characters (A tilde has no CP437 code: ?)', M.GetFrom = 'Jos??');
  M.CloseMsgBase;

  { damage: a header-looking block missing between messages, a message cut off, junk at the end }
  F2 := D + 'bad.dat';
  RawStart(Fl, F2);
  RawMsg(Fl, 1, 1, 'A', 'B', 'first', 'text of one', ' ');
  FillChar(Raw, 128, Ord('Z'));
  BlockWrite(Fl, Raw, 128);                         { junk block }
  RawMsg(Fl, 2, 1, 'A', 'B', 'second', 'text of two', ' ');
  BlockWrite(Fl, Raw, 50);                          { not a whole block }
  Close(Fl);
  M.SetMsgPath(F2);
  Check('damaged: opens', M.OpenMsgBase = 0);
  Check('... not clean, both messages found', (not M.GetClean) and (M.NumberOfMsgs = 2));
  M.SeekFirst(2); M.MsgStartUp;
  Check('... #2 is "second"', M.GetSubj = 'second');
  M.StartNewMsg; M.SetFrom('A'); M.DoStringLn('x');
  Check('... writing is refused: 1004', M.WriteMsg = 1004);
  M.CloseMsgBase;
  RawStart(Fl, F2);
  RawMsg(Fl, 1, 1, 'A', 'B', 'first', 'text of one', ' ');
  Seek(Fl, FileSize(Fl) - 128);
  Truncate(Fl);                                     { the text block of the last message is gone }
  Close(Fl);
  Check('a message that runs past the end: opens, one message, not clean', (M.OpenMsgBase = 0) and (M.NumberOfMsgs = 1) and not M.GetClean);
  M.CloseMsgBase;

  { too short, no name }
  F2 := D + 'short.dat';
  Assign(Fl, F2); ReWrite(Fl, 1); BlockWrite(Fl, Raw, 10); Close(Fl);
  M.SetMsgPath(F2);
  Check('10 bytes: 1003', M.OpenMsgBase = 1003);
  M.SetMsgPath('');
  Check('no path: 1002', M.OpenMsgBase = 1002);

  { read only }
  F2 := D + 'ro.dat';
  EraseFile(F2);
  M.SetMsgPath(F2); M.SetPacketId('RO');
  M.CreateMsgBase(0, 0);
  M.StartNewMsg; M.SetFrom('A'); M.DoStringLn('x'); M.WriteMsg;
  M.CloseMsgBase;
  Assign(Fl, F2); SetFAttr(Fl, ReadOnly);
  M.SetMsgPath(F2);
  Check('read only file: opens and reads', (M.OpenMsgBase = 0) and (M.NumberOfMsgs = 1));
  M.StartNewMsg; M.SetFrom('A'); M.DoStringLn('x');
  Check('... writing: 1011 (or it worked: running as root)', (M.WriteMsg = 1011) or (M.GetError = 0));
  M.CloseMsgBase;
  SetFAttr(Fl, Archive);
  M.Done;
end;

begin
  Fails := 0;
  if ParamCount < 2 then begin writeln('usage: qwkmsgtest write|dump|self <file|dir> [rep]'); Halt(2); end;
  if ParamStr(1) = 'write' then WriteSet(ParamStr(2), ParamStr(3) = 'rep')
  else if ParamStr(1) = 'dump' then Dump(ParamStr(2), ParamStr(3) = 'rep')
  else if ParamStr(1) = 'reply' then Reply(ParamStr(2), Str2Long(ParamStr(3)), ParamStr(4), ParamStr(5))
  else if ParamStr(1) = 'control' then Control(ParamStr(2), ParamStr(3))
  else if ParamStr(1) = 'hub' then Hub(ParamStr(2), Str2Long(ParamStr(3)))
  else Self(ParamStr(2));
  if Fails > 0 then Halt(1);
end.
