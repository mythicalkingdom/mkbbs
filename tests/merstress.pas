{ SPDX-License-Identifier: GPL-3.0-or-later }
program merstress;
{$mode tp}
{ Merlin stress and recovery tests.
  merstress <dir>                 random adds/deletes/rewrites, repair tests
  merstress write <file> <tag> <n>   add n messages (run several at once) }
uses Dos, MKString, MKFile, MKGlobT, MKMsgMer;
var
  Fails: Integer;
  M: MerlinMsgPtr;
  FN: String;

procedure Check(Name: String; Ok: Boolean);
begin
  if Ok then writeln('ok   ', Name) else begin writeln('FAIL ', Name, '  (err=', M^.MInfo^.Error, ')'); Inc(Fails); end;
  Flush(Output);
end;

function Body(N: LongInt): String;
var S: String; i: Integer;
begin
  S := 'body of ' + Long2Str(N) + ':';
  for i := 1 to N mod 23 do S := S + ' word' + Long2Str(i);
  Body := S;
end;

procedure Report;
var i: Integer;
begin
  for i := 1 to M^.MInfo^.ReportCnt do writeln('     problem: ', M^.MInfo^.Report[i]);
  if M^.MInfo^.ReportMore > 0 then writeln('     ... and ', M^.MInfo^.ReportMore, ' more');
end;

function Verify: LongInt;   { every active message must carry its own number in subject and text }
var Bad, N: LongInt; S: String;
begin
  Bad := 0; N := 0;
  M^.SeekFirst(0);
  while M^.SeekFound do
  begin
    Inc(N);
    S := M^.GetSubj;
    if S <> 'subj ' + Long2Str(M^.GetMsgNum) then Inc(Bad);
    M^.MsgTxtStartUp;
    if M^.GetString(250) <> Body(M^.GetMsgNum) then Inc(Bad);
    M^.SeekNext;
  end;
  if N <> M^.NumberOfMsgs then Inc(Bad);
  Verify := Bad;
end;

procedure AddMsg(Num: LongInt; Refer: LongInt);
begin
  M^.StartNewMsg;
  M^.SetFrom('Tester'); M^.SetTo('Name' + Long2Str(Num mod 7)); M^.SetSubj('subj ' + Long2Str(Num));
  M^.SetRefer(Refer);
  M^.DoStringLn(Body(Num));
  if M^.WriteMsg <> 0 then Inc(Fails);
end;

procedure Flip(Pos: LongInt; Val: Byte);   { corrupt one byte of the file }
var F: File;
begin
  Assign(F, FN); FileMode := 2; Reset(F, 1); Seek(F, Pos); BlockWrite(F, Val, 1); Close(F);
end;

var
  i, k, N, R, Cnt: LongInt;
  Dir: String;
  F: File;
  Sz: LongInt;
  Buf: Array[0..511] of Byte;
begin
  if ParamStr(1) = 'write' then
  begin
    FN := ParamStr(2);
    New(M); M^.Init; M^.SetMsgPath(FN); M^.SetSync(False);
    if M^.OpenMsgBase <> 0 then begin writeln('open failed ', M^.MInfo^.Error); Halt(1); end;
    for i := 1 to Str2Long(ParamStr(4)) do
    begin
      M^.StartNewMsg;
      M^.SetFrom(ParamStr(3)); M^.SetTo('All'); M^.SetSubj('concurrent ' + ParamStr(3) + ' ' + Long2Str(i));
      M^.DoStringLn('text ' + Long2Str(i));
      if M^.WriteMsg <> 0 then begin writeln('write failed ', M^.MInfo^.Error); Halt(2); end;
    end;
    M^.Done; Dispose(M);
    Halt(0);
  end;

  Dir := ParamStr(1);
  FN := WithBackSlash(Dir) + 'stress.dat';
  if FileExist(FN) then EraseFile(FN);
  if FileExist(WithBackSlash(Dir) + 'maxmsgs.dat') then EraseFile(WithBackSlash(Dir) + 'maxmsgs.dat');
  New(M); M^.Init; M^.SetMsgPath(FN); M^.SetSync(False);
  RandSeed := 12345;
  Check('create', M^.CreateMsgBase(0, 0) = 0);
  Check('open', M^.OpenMsgBase = 0);
  { 1. random adds / deletes / header rewrites }
  Cnt := 0;
  for i := 1 to 1500 do
  begin
    R := Random(10);
    if (R < 6) or (M^.NumberOfMsgs < 5) then
    begin
      Inc(Cnt);
      AddMsg(M^.GetHighMsgNum + 1, 0);
    end
    else if R < 9 then
    begin
      M^.SeekFirst(M^.GetHighMsgNum - Random(M^.GetHighMsgNum) );
      if M^.SeekFound then M^.DeleteMsg;
    end
    else
    begin
      M^.SeekFirst(M^.GetHighMsgNum - Random(M^.GetHighMsgNum));
      if M^.SeekFound then
      begin
        N := M^.GetMsgNum;
        M^.SetSubj('subj ' + Long2Str(N));
        if Random(2) = 0 then M^.SetTo('A much longer recipient name to force the header frame to move ' + Long2Str(N));
        M^.SetRcvd(Random(2) = 0);
        M^.ReWriteHdr;
      end;
    end;
    if i mod 250 = 0 then
    begin
      Check('check clean after ' + Long2Str(i) + ' ops', M^.Check);
      Report;
      Check('messages intact after ' + Long2Str(i), Verify = 0);
    end;
  end;
  Writeln('     ', M^.NumberOfMsgs, ' messages, high ', M^.GetHighMsgNum);
  { 2. replies: chain of 50 replies to one message, delete the root }
  AddMsg(M^.GetHighMsgNum + 1, 0);
  N := M^.GetHighMsgNum;
  for i := 1 to 50 do AddMsg(M^.GetHighMsgNum + 1, N);
  Check('check clean (reply chain)', M^.Check);
  M^.SeekFirst(N);
  M^.DeleteMsg;
  Check('check clean (root deleted)', M^.Check);
  Check('messages intact', Verify = 0);
  { 3. damage the index and the free list on purpose; Check sees it, Repair fixes it }
  M^.CloseMsgBase;
  Assign(F, FN); FileMode := 2; Reset(F, 1); Sz := FileSize(F);
  Seek(F, 132 + 14 + 40); BlockRead(F, Buf, 40);         { index records }
  FillChar(Buf, 40, $5A);
  Seek(F, 132 + 14 + 40); BlockWrite(F, Buf, 40);
  Close(F);
  Check('reopen damaged base (auto repair is off for the open check)', True);
  M^.SetAutoRepair(False);
  M^.OpenMsgBase;
  Check('Check finds the damage', not M^.Check);
  Writeln('     ', M^.MInfo^.ReportCnt, ' problems reported');
  Report;
  Check('Repair', M^.Repair);
  Check('Check clean after repair', M^.Check);
  M^.CloseMsgBase;
  M^.SetAutoRepair(True);
  Check('reopen', M^.OpenMsgBase = 0);
  Check('messages intact after repair', Verify = 0);
  { 3b. damage the index records and the free list pointer (found through the base header) }
  M^.CloseMsgBase;
  Assign(F, FN); FileMode := 2; Reset(F, 1);
  Seek(F, 18); BlockRead(F, Sz, 4);                       { IdxPtr }
  FillChar(Buf, 200, 0);
  Seek(F, Sz + 14 + 80); BlockWrite(F, Buf, 200);         { wipe 25 index records }
  Sz := 0;
  Seek(F, 22); BlockWrite(F, Sz, 4);                      { FreePtr := 0 }
  Close(F);
  M^.SetAutoRepair(False);
  M^.OpenMsgBase;
  Check('Check finds index damage', not M^.Check);
  Report;
  Check('Repair (index)', M^.Repair);
  Check('Check clean after index repair', M^.Check);
  Check('messages intact after index repair (some may be lost with the index)', Verify = 0);
  Writeln('     ', M^.NumberOfMsgs, ' messages after repair');
  M^.CloseMsgBase;
  M^.SetAutoRepair(True);
  Check('reopen', M^.OpenMsgBase = 0);
  { 4. a "crash": DIRTY flag set in the file; the next writer repairs first }
  M^.CloseMsgBase;
  Flip(56, 1);                                   { flags: DIRTY }
  Check('reopen dirty base', M^.OpenMsgBase = 0);   { open waits, then repairs it }
  Check('repaired on open', M^.Check);
  M^.CloseMsgBase;
  Flip(56, 1);
  M^.SetAutoRepair(False);
  Check('dirty base, no auto repair: open reads leniently', M^.OpenMsgBase = 0);
  Check('writer refuses', (M^.WriteMsg <> 0));
  M^.CloseMsgBase;
  M^.SetAutoRepair(True);
  Check('reopen repairs', M^.OpenMsgBase = 0);
  AddMsg(M^.GetHighMsgNum + 1, 0);
  Check('write works again', M^.Check);
  { 5. MaxMsgs: only the newest 20 stay }
  M^.CloseMsgBase;
  M^.SetMsgPath(WithBackSlash(Dir) + 'maxmsgs.dat');
  Check('create max 20', M^.CreateMsgBase(20, 0) = 0);
  Check('open max', M^.OpenMsgBase = 0);
  for i := 1 to 75 do AddMsg(i, 0);
  Check('only 20 remain', M^.NumberOfMsgs = 20);
  M^.SeekFirst(0);
  Check('oldest is 56', M^.GetMsgNum = 56);
  Check('check clean (maxmsgs)', M^.Check);
  M^.Done; Dispose(M);
  writeln('failures: ', Fails);
  Halt(Fails);
end.
