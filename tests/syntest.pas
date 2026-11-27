{ SPDX-License-Identifier: GPL-3.0-or-later }
program syntest;
{$mode tp}
{ MKMsgSyn tests.
    syntest dump <base>          one line per visible message, to compare with the JS reader
    syntest selftest <dir>       create / write / read / delete round trips
    syntest check <base>         the index CRCs stored in a Synchronet made base match ours }
uses Dos, MKString, MKFile, MKGlobT, MKMsgAbs, MKMsgSyn;
var
  Fails: Integer;
  M: SynMsgPtr;
  Mode: String;
  i: LongInt;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name, '  (err=', M^.MInfo^.Error, ')'); Inc(Fails); end;
  Flush(Output);
end;

procedure Dump;
var S: String; C: Char; Sum, High, Len: LongInt;
begin
  M^.SeekFirst(0);
  while M^.SeekFound do
  begin
    Sum := 0; High := 0; Len := 0;
    M^.MsgTxtStartUp;
    while not M^.EOM do
    begin
      C := M^.GetChar;
      if (C <> #13) and (C <> #10) then
      begin
        Inc(Len);
        if Ord(C) > 127 then Inc(High) else Sum := (Sum * 31 + Ord(C)) and $FFFFFF;
      end;
    end;
    writeln(M^.GetMsgNum, '|', M^.GetFrom, '|', M^.GetTo, '|', M^.GetSubj, '|', M^.MInfo^.Hdr.Attr, '|',
      M^.MInfo^.Hdr.AuxAttr, '|', M^.MInfo^.Hdr.NetAttr, '|', M^.MInfo^.Hdr.WrittenTime, '|', M^.GetRefer, '|',
      M^.GetSeeAlso, '|', M^.GetNextSeeAlso, '|', Len, '|', High, '|', Sum);
    M^.SeekNext;
  end;
end;

procedure Add(From, ToN, Subj, Txt: String; Refer: LongInt);
begin
  M^.StartNewMsg;
  M^.SetFrom(From); M^.SetTo(ToN); M^.SetSubj(Subj); M^.SetRefer(Refer);
  M^.SetDate('02-03-95'); M^.SetTime('12:34'); M^.SetUtcOffset(-300);
  M^.DoStringLn(Txt); M^.DoStringLn('second line');
  if M^.WriteMsg <> 0 then Inc(Fails);
end;

procedure Wipe(Base: String);          { leftovers of an earlier run }
const Ext: Array[1..5] of String[4] = ('.shd', '.sdt', '.sid', '.sda', '.sha');
var i: Integer; F: File;
begin
  {$I-}
  for i := 1 to 5 do begin
    Assign(F, Base + Ext[i]);
    Erase(F);
    if IOResult <> 0 then ;
  end;
  {$I+}
end;

procedure SelfTest(Hyper: Boolean; Base: String);
var i: Integer; A: AddrType; S: String;
begin
  Wipe(Base);
  New(M); M^.Init; M^.SetMsgPath(Base); M^.SetHyperAlloc(Hyper);
  Check('create', M^.CreateMsgBase(0, 0) = 0);
  Check('create twice refused', M^.CreateMsgBase(0, 0) = synExists);
  Check('open', M^.OpenMsgBase = 0);
  Check('empty base', M^.NumberOfMsgs = 0);
  Add('Alice', 'Bob', 'Hello', 'first line 1', 0);
  Check('write 1', M^.SeekFound and (M^.GetMsgNum = 1));
  Add('Carol', 'Bob', 'Re: Hello', 'first line 2', 1);
  Add('Dave', 'Alice', 'Other', 'first line 3', 0);
  Add('Erin', 'Bob', 'RE: re: Hello', 'first line 4', 1);
  Check('4 messages', M^.NumberOfMsgs = 4);
  Check('highest', (M^.GetHighMsgNum = 4) and (M^.GetHighActiveMsgNum = 4));
  M^.SeekFirst(0);
  Check('header', (M^.GetFrom = 'Alice') and (M^.GetTo = 'Bob') and (M^.GetSubj = 'Hello'));
  Check('date and time kept', (M^.GetDate = '02-03-95') and (M^.GetTime = '12:34'));
  Check('zone kept', M^.GetUtcOffset = -300);
  M^.MsgTxtStartUp;
  Check('text', (M^.GetString(79) = 'first line 1') and (M^.GetString(79) = 'second line') and M^.EOM);
  Check('reply chain', (M^.GetSeeAlso = 2));
  M^.SeekNext;
  Check('msg 2 refers to 1, next reply 4', (M^.GetMsgNum = 2) and (M^.GetRefer = 1) and (M^.GetNextSeeAlso = 4));
  M^.SeekFirst(3);
  Check('seekfirst(3)', M^.GetMsgNum = 3);
  M^.SeekPrior;
  Check('seekprior', M^.GetMsgNum = 2);
  M^.SeekFirst(99);
  Check('beyond the end', not M^.SeekFound);
  M^.YoursFirst('bob', '');
  i := 0;
  while M^.YoursFound do begin Inc(i); M^.YoursNext; end;
  Check('yours (3 for Bob)', i = 3);
  Check('CRCs are what Synchronet computes (re: stripped)', SynSubjCrc('RE: re: Hello') = SynSubjCrc('Hello'));
  M^.SeekFirst(4);
  M^.MInfo^.Hdr.Attr := M^.MInfo^.Hdr.Attr;
  M^.SetPriv(True); M^.SetRcvd(True); M^.SetLocal(True); M^.SetEcho(True);
  M^.ReWriteHdr;
  Check('flags rewritten', M^.IsPriv and M^.IsRcvd and M^.IsLocal and M^.IsEchoed and (M^.GetMsgNum = 4));
  M^.SetPriv(False);
  M^.ReWriteHdr;
  Check('flag cleared', (not M^.IsPriv) and M^.IsRcvd);
  M^.SeekFirst(2); M^.DeleteMsg;
  Check('deleted is not visible', (M^.NumberOfMsgs = 3) and (M^.GetHighMsgNum = 4));
  M^.SeekFirst(2);
  Check('seek skips the deleted one', M^.GetMsgNum = 3);
  M^.SetIncludeDeleted(True);
  Check('SetIncludeDeleted shows it', M^.NumberOfMsgs = 4);
  M^.SeekFirst(2);
  Check('...and it is flagged deleted', (M^.GetMsgNum = 2) and M^.IsDeleted);
  M^.SetIncludeDeleted(False);
  A.Zone := 1; A.Net := 110; A.Node := 290; A.Point := 3;
  M^.StartNewMsg; M^.SetFrom('Net'); M^.SetTo('Sysop'); M^.SetSubj('Netmail'); M^.SetOrig(A);
  A.Zone := 2; A.Net := 240; A.Node := 1; A.Point := 0; M^.SetDest(A);
  M^.DoKludgeLn('MSGID: 1:110/290.3 abcd');
  M^.DoStringLn('net body'); M^.SetCost(25);
  Check('write netmail', M^.WriteMsg = 0);
  Check('cost', M^.GetCost = 25);
  M^.GetOrig(A);
  Check('orig address', (A.Zone = 1) and (A.Net = 110) and (A.Node = 290) and (A.Point = 3));
  M^.GetDest(A);
  Check('dest address', (A.Zone = 2) and (A.Net = 240) and (A.Node = 1));
  M^.MsgTxtStartUp;
  S := M^.GetString(79);
  Check('kludge line left out of the text', S = 'net body');
  S := '';
  for i := 1 to 700 do S := S + Chr(65 + i mod 26);
  M^.StartNewMsg; M^.SetFrom('Big'); M^.SetTo('All'); M^.SetSubj('multi block text');
  for i := 1 to 12 do M^.DoStringLn(S);
  Check('write 8k text', M^.WriteMsg = 0);
  M^.MsgTxtStartUp;
  Check('8k text reads back', (M^.GetString(250) = Copy(S, 1, 250)) and (M^.GetTxtPos = 250));
  Check('lock', M^.LockMsgBase and M^.UnLockMsgBase);
  Check('close', M^.CloseMsgBase = 0);
  Check('reopen', M^.OpenMsgBase = 0);
  Check('persisted', M^.NumberOfMsgs = 5);
  Check('no from refused', (M^.CloseMsgBase = 0) and (M^.OpenMsgBase = 0));
  M^.StartNewMsg; M^.SetFrom(''); M^.DoStringLn('x');
  Check('write without from refused', M^.WriteMsg = synNoFrom);
  M^.StartNewMsg; M^.SetFrom('x'); M^.DoString('   ');
  Check('empty text refused', M^.WriteMsg = synNoText);
  M^.SetMailBase(True);
  M^.StartNewMsg; M^.SetFrom('x'); M^.DoStringLn('x');
  Check('mail base is read only', M^.WriteMsg = synMailBase);
  M^.Done; Dispose(M);
end;

procedure CheckCrcs;
var Bad, N: LongInt;
begin
  Bad := 0; N := 0;
  M^.SeekFirst(0);
  while M^.SeekFound do
  begin
    Inc(N);
    with M^.MInfo^ do
      if (Idx^[Cur].ToCrc <> SynNameCrc(MsgTo)) or (Idx^[Cur].FromCrc <> SynNameCrc(MsgFrom)) or
         (Idx^[Cur].SubjCrc <> SynSubjCrc(MsgSubj)) then
      begin Inc(Bad); if Bad <= 5 then writeln('  mismatch at message ', Hdr.Number); end;
    M^.SeekNext;
  end;
  writeln(N, ' messages, ', Bad, ' CRC mismatches');
  Check('all index CRCs match', Bad = 0);
end;

begin
  Mode := ParamStr(1);
  if Mode = 'selftest' then
  begin
    SelfTest(False, WithBackSlash(ParamStr(2)) + 'syn_alloc');
    SelfTest(True, WithBackSlash(ParamStr(2)) + 'syn_hyper');
    writeln('failures: ', Fails);
    Halt(Fails);
  end;
  if Mode = 'write' then
  begin
    New(M); M^.Init; M^.SetMsgPath(ParamStr(2));
    if M^.OpenMsgBase <> 0 then begin writeln('open failed ', M^.MInfo^.Error); Halt(2); end;
    for i := 1 to Str2Long(ParamStr(4)) do
    begin
      M^.StartNewMsg;
      M^.SetFrom(ParamStr(3)); M^.SetTo('All'); M^.SetSubj('concurrent ' + ParamStr(3) + ' ' + Long2Str(i));
      M^.DoStringLn('text ' + Long2Str(i));
      if M^.WriteMsg <> 0 then begin writeln('write failed ', M^.MInfo^.Error); Halt(3); end;
    end;
    M^.Done; Dispose(M);
    Halt(0);
  end;
  New(M); M^.Init; M^.SetMsgPath(ParamStr(2));
  if M^.OpenMsgBase <> 0 then begin writeln('open failed ', M^.MInfo^.Error); Halt(2); end;
  if Mode = 'dump' then Dump
  else if Mode = 'check' then begin CheckCrcs; writeln('failures: ', Fails); Halt(Fails); end;
  M^.Done; Dispose(M);
end.
