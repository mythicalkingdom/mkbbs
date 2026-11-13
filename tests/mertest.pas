program mertest;
{$mode tp}
{ Merlin message base tests: round trip, replies, delete, last read, repair.
  usage: mertest <work dir> }
uses Dos, MKString, MKFile, MKGlobT, MKMsgMer;
var
  Fails: Integer;
  Dir, FN: String;
  M: MerlinMsgPtr;
  i: Integer;
  S: String;
  A: AddrType;
  R: Word;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name, '  (err=', M^.MInfo^.Error, ')'); Inc(Fails); end;
  Flush(Output);
end;

procedure Add(From, ToN, Subj, Txt: String; Refer: LongInt);
begin
  M^.StartNewMsg;
  M^.SetFrom(From); M^.SetTo(ToN); M^.SetSubj(Subj);
  M^.SetDate('02-03-95'); M^.SetTime('12:34');
  M^.SetUtcOffset(-300);
  M^.SetRefer(Refer);
  M^.DoStringLn(Txt);
  M^.DoStringLn('second line');
  R := M^.WriteMsg;
end;

begin
  Dir := ParamStr(1);
  FN := WithBackSlash(Dir) + 'merlin.dat';
  if FileExist(FN) then EraseFile(FN);
  New(M); M^.Init; M^.SetMsgPath(FN);
  Check('create', M^.CreateMsgBase(0, 0) = 0);
  Check('create twice refused', M^.CreateMsgBase(0, 0) = merExists);
  Check('open', M^.OpenMsgBase = 0);
  Check('check clean (new)', M^.Check);
  Check('empty: NumberOfMsgs', M^.NumberOfMsgs = 0);
  Add('Alice', 'Bob', 'Hello', 'first line 1', 0);
  Check('write 1', (R = 0) and (M^.GetMsgNum = 1));
  Add('Carol', 'Bob', 'Re: Hello', 'first line 2', 1);
  Add('Dave', 'Alice', 'Other', 'first line 3', 0);
  Add('Erin', 'Bob', 'Re: Re: Hello', 'first line 4', 1);
  Check('4 messages', M^.NumberOfMsgs = 4);
  Check('highest', (M^.GetHighMsgNum = 4) and (M^.GetHighActiveMsgNum = 4));
  Check('check clean (4 msgs)', M^.Check);
  M^.SeekFirst(0);
  Check('seekfirst', M^.SeekFound and (M^.GetMsgNum = 1));
  Check('header', (M^.GetFrom = 'Alice') and (M^.GetTo = 'Bob') and (M^.GetSubj = 'Hello'));
  Check('date/time', (M^.GetDate = '02-03-95') and (M^.GetTime = '12:34'));
  Check('utc offset', M^.GetUtcOffset = -300);
  Check('charset', M^.GetCharset = 'UTF-8');
  M^.MsgTxtStartUp;
  S := M^.GetString(79);
  Check('text line 1', S = 'first line 1');
  S := M^.GetString(79);
  Check('text line 2', S = 'second line');
  Check('EOM', M^.EOM);
  Check('reply chain', (M^.GetSeeAlso = 2));
  M^.SeekNext;
  Check('msg 2', M^.SeekFound and (M^.GetMsgNum = 2) and (M^.GetRefer = 1) and (M^.GetNextSeeAlso = 4));
  M^.SeekFirst(3);
  Check('seekfirst(3)', M^.GetMsgNum = 3);
  M^.SeekPrior;
  Check('seekprior', M^.GetMsgNum = 2);
  M^.SeekFirst(99);
  Check('seek beyond end', not M^.SeekFound);
  M^.YoursFirst('bob', 'Robert');
  i := 0;
  while M^.YoursFound do begin Inc(i); M^.YoursNext; end;
  Check('yours (3 for Bob)', i = 3);
  { addresses and kludges }
  A.Zone := 1; A.Net := 110; A.Node := 290; A.Point := 0;
  M^.StartNewMsg;
  M^.SetFrom('Frank'); M^.SetTo('Bob'); M^.SetSubj('Netmail'); M^.SetOrig(A);
  A.Zone := 2; A.Net := 5030; A.Node := 301; A.Point := 7; M^.SetDest(A);
  M^.SetPriv(True); M^.SetLocal(True); M^.SetEcho(True);
  M^.DoKludgeLn('MSGID: 1:110/290 12345678');
  M^.DoKludgeLn('PID: MKTest 1.0');
  M^.DoKludgeLn('FOO: something odd');
  M^.DoStringLn('body line');
  Check('write netmail', M^.WriteMsg = 0);
  M^.SeekFirst(5);
  Check('netmail flags', M^.IsPriv and M^.IsLocal and M^.IsEchoed and (not M^.IsRcvd));
  M^.GetOrig(A);
  Check('orig addr', (A.Zone = 1) and (A.Net = 110) and (A.Node = 290) and (A.Point = 0));
  M^.GetDest(A);
  Check('dest addr', (A.Zone = 2) and (A.Net = 5030) and (A.Node = 301) and (A.Point = 7));
  M^.MsgTxtStartUp;
  S := M^.GetString(79);
  Check('kludge 1', S = #1'MSGID: 1:110/290 12345678');
  S := M^.GetString(79);
  Check('kludge 2', S = #1'PID: MKTest 1.0');
  S := M^.GetString(79);
  Check('kludge 3', S = #1'FOO: something odd');
  S := M^.GetNoKludgeStr(79);
  Check('body after kludges', S = 'body line');
  { export tracking }
  Check('export first', M^.ExportFirst(0) and (M^.GetMsgNum = 5));
  Check('mark exported', M^.MarkExported(5, False) = 0);
  Check('nothing to export', not M^.ExportFirst(0));
  Check('last scanned', M^.GetLastScanned = 5);
  { last read }
  Check('lastread none', M^.GetLastRead(42) = 0);
  M^.SetLastRead(42, 3);
  M^.SetLastRead(7, 4);
  M^.SetLastRead(42, 5);
  Check('lastread 42', M^.GetLastRead(42) = 5);
  Check('lastread 7', M^.GetLastRead(7) = 4);
  for i := 100 to 140 do M^.SetLastRead(i, i);
  Check('lastread grows', (M^.GetLastRead(120) = 120) and (M^.GetLastRead(42) = 5));
  Check('check clean (lastread)', M^.Check);
  { rewrite header }
  M^.SeekFirst(2);
  M^.SetTo('Bobby Tables the Third, of a really long name that moves the frame');
  M^.SetSubj('A new and much longer subject than the old one had, to force the frame to grow past its slot');
  M^.SetRcvd(True);
  M^.ReWriteHdr;
  Check('rewrite hdr', M^.SeekFound and (M^.GetMsgNum = 2) and M^.IsRcvd and (Copy(M^.GetTo, 1, 11) = 'Bobby Table'));
  M^.MsgTxtStartUp;
  Check('text kept', M^.GetString(79) = 'first line 2');
  Check('check clean (rewrite)', M^.Check);
  { delete }
  M^.SeekFirst(1);
  M^.DeleteMsg;
  Check('delete 1', (not M^.SeekFound) and (M^.NumberOfMsgs = 4));
  M^.SeekFirst(2);
  Check('reply unlinked: 2 now top level', (M^.GetRefer = 0));
  M^.SeekFirst(4);
  Check('reply 4 re-parented', (M^.GetRefer = 0));
  Check('check clean (delete)', M^.Check);
  M^.SeekFirst(2);
  M^.DeleteMsg;
  M^.SeekFirst(3);
  M^.DeleteMsg;
  Check('NumberOfMsgs 2', M^.NumberOfMsgs = 2);
  Check('check clean (3 deleted)', M^.Check);
  for i := 1 to 50 do Add('Gina', 'Hal', 'bulk ' + Chr(48 + i mod 10), 'bulk text', 0);
  Check('50 more', M^.NumberOfMsgs = 52);
  Check('check clean (bulk)', M^.Check);
  { reopen, a second reader }
  Check('close', M^.CloseMsgBase = 0);
  Check('reopen', M^.OpenMsgBase = 0);
  M^.SeekFirst(0);
  Check('first after reopen = 4', M^.GetMsgNum = 4);
  Check('highest after reopen', M^.GetHighMsgNum = 55);
  Check('display num', M^.GetMsgDisplayNum = M^.GetMsgNum - 3);
  { lock / unlock nesting }
  Check('LockMsgBase', M^.LockMsgBase);
  Check('LockMsgBase nested', M^.LockMsgBase);
  Add('Ivan', 'Jo', 'locked add', 'written while locked', 0);
  Check('write while locked', R = 0);
  Check('Unlock 1', M^.UnLockMsgBase);
  Check('Unlock 2', M^.UnLockMsgBase);
  Check('Unlock 3 fails', not M^.UnLockMsgBase);
  { validation and name limits }
  M^.StartNewMsg; M^.SetFrom(''); M^.DoStringLn('x');
  Check('no from refused', M^.WriteMsg = merNoFrom);
  M^.StartNewMsg; M^.SetFrom('x'); M^.DoString('   '); M^.DoChar(#13);
  Check('empty text refused', M^.WriteMsg = merNoText);
  S := '';
  for i := 1 to 100 do S := S + #$C3#$A9;           { 100 x e-acute = 200 bytes of UTF-8 }
  M^.StartNewMsg; M^.SetFrom('Unicode'); M^.SetTo(''); M^.SetSubj(S); M^.DoStringLn('long subject');
  Check('write long subject', M^.WriteMsg = 0);
  Check('subject cut to 128 bytes on a character boundary', (Length(M^.GetSubj) = 128) and (M^.GetSubj[128] = #$A9));
  Check('empty to becomes All', M^.GetTo = 'All');
  M^.Done; Dispose(M);
  writeln('failures: ', Fails);
  Halt(Fails);
end.
