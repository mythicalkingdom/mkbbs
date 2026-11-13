program merjs;
{$mode tp}
{ read a base written by MessageMerlin.js (usage: merjs <file>) }
uses MKString, MKGlobT, MKMsgMer;
var M: MerlinMsgPtr; Fails: Integer; A: AddrType; S: String;
procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name, '  (err=', M^.MInfo^.Error, ')'); Inc(Fails); end;
end;
begin
  New(M); M^.Init; M^.SetMsgPath(ParamStr(1));
  Check('open', M^.OpenMsgBase = 0);
  Check('check clean', M^.Check);
  Check('4 active messages', M^.NumberOfMsgs = 4);
  M^.SeekFirst(0);
  Check('msg 1', (M^.GetMsgNum = 1) and (M^.GetFrom = 'Jane') and (M^.GetTo = 'John') and (M^.GetSubj = 'Plain'));
  Check('cp437 charset', M^.GetCharset = 'CP437');
  Check('utc +120', M^.GetUtcOffset = 120);
  Check('date', (M^.GetDate = '07-04-96') and (M^.GetTime = '17:30'));
  Check('replies linked', (M^.GetSeeAlso = 2) and (M^.GetNextSeeAlso = 0));
  M^.MsgTxtStartUp;
  Check('text', (M^.GetString(79) = 'hello') and (M^.GetString(79) = 'world'));
  M^.SeekNext;
  Check('msg 2', (M^.GetMsgNum = 2) and (M^.GetRefer = 1) and (M^.GetNextSeeAlso = 3));
  M^.SeekNext; M^.SeekNext;
  Check('msg 4 (5 deleted)', M^.SeekFound and (M^.GetMsgNum = 4));
  Check('netmail flags', M^.IsPriv and M^.IsLocal and M^.IsEchoed);
  M^.GetOrig(A);
  Check('orig', (A.Zone = 1) and (A.Net = 110) and (A.Node = 290) and (A.Point = 3));
  M^.GetDest(A);
  Check('dest', (A.Zone = 2) and (A.Net = 240) and (A.Node = 1) and (A.Point = 0));
  M^.MsgTxtStartUp;
  S := M^.GetString(79);
  Check('kludge MSGID', S = #1'MSGID: 1:110/290.3 abcd');
  S := M^.GetString(79);
  Check('kludge TZUTC', S = #1'TZUTC: -0500');
  S := M^.GetString(79);
  Check('kludge Via', S = #1'Via 1:2/3 foo');
  Check('body', M^.GetString(79) = 'net body');
  Check('utc from TZUTC kludge', M^.GetUtcOffset = 120);
  Check('last read', M^.GetLastRead(9) = 3);
  M^.SeekFirst(5);
  Check('5 is gone', not M^.SeekFound);
  Check('highest = 5', M^.GetHighMsgNum = 5);
  { Pascal appends to the JS base, then the JS checker looks again }
  M^.StartNewMsg; M^.SetFrom('Pascal'); M^.SetTo('John'); M^.SetSubj('from FPC'); M^.DoStringLn('written by the Pascal unit');
  Check('write', M^.WriteMsg = 0);
  Check('new number 6', M^.GetMsgNum = 6);
  M^.SeekFirst(3); M^.DeleteMsg;
  Check('delete 3', M^.NumberOfMsgs = 4);
  Check('check clean after writes', M^.Check);
  M^.Done; Dispose(M);
  writeln('failures: ', Fails);
  Halt(Fails);
end.
