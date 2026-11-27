{ SPDX-License-Identifier: GPL-3.0-or-later }
program fidtest;
{$mode tp}
{ the hold flag of the Fido *.msg unit: attribute word at offset 186, hold = $0200 }
uses MKString, MKFile, MKGlobT, MKMsgAbs, MKMsgFid, Dos;

var Fails: Integer;
    M: FidoMsgObj;
    D: String;
    A: AddrType;
    F: File;
    B: Array[0..1] of Byte;

procedure Check(N: String; Ok: Boolean);
begin if Ok then writeln('ok   fido: ', N) else begin writeln('FAIL fido: ', N); Inc(Fails); end; end;

function RawAttr(Num: Word): Word;
var X: File; W: Word;
begin
  Assign(X, D + Long2Str(Num) + '.msg'); Reset(X, 1); Seek(X, 186); BlockRead(X, W, 2); Close(X);
  RawAttr := W;
end;

begin
  D := WithBackSlash(ParamStr(1));
  FileMode := fmReadWrite;
  EraseFile(D + '1.msg'); EraseFile(D + '2.msg');
  M.Init; M.SetMsgPath(D);
  A.Zone := 1; A.Net := 110; A.Node := 290; A.Point := 0;
  M.StartNewMsg;
  M.SetOrig(A); A.Node := 100; M.SetDest(A);
  M.SetFrom('Mark May'); M.SetTo('Sysop'); M.SetSubj('held');
  M.SetDate('11-16-26'); M.SetTime('13:14');
  M.SetPriv(True); M.SetHold(True);
  M.DoStringLn('body');
  Check('write a netmail with SetHold(True)', M.WriteMsg = 0);
  Check('the attribute word of 1.msg is $0201 (private + hold)', RawAttr(1) = $0201);
  M.StartNewMsg;
  M.SetOrig(A); M.SetDest(A);
  M.SetFrom('Mark May'); M.SetTo('Sysop'); M.SetSubj('not held');
  M.SetDate('11-16-26'); M.SetTime('13:14');
  M.SetPriv(True); M.SetCrash(True);
  M.DoStringLn('body');
  Check('write a netmail without it', M.WriteMsg = 0);
  Check('the attribute word of 2.msg is $0003 (no hold)', RawAttr(2) = $0003);
  M.SeekFirst(1); M.MsgStartUp;
  Check('SeekFirst(1): IsHold, IsPriv, not IsFileReq', M.SeekFound and M.IsHold and M.IsPriv and (not M.IsFileReq));
  M.SeekFirst(2); M.MsgStartUp;
  Check('#2: not IsHold, IsCrash', (not M.IsHold) and M.IsCrash);
  M.SetHold(True);
  Check('SetHold(True) on #2: IsHold, other flags kept', M.IsHold and M.IsPriv and M.IsCrash);
  M.SeekFirst(1); M.MsgStartUp;   {opening another message closes (and writes) #2}
  Check('... in the file: $0203', RawAttr(2) = $0203);
  M.SeekFirst(2); M.MsgStartUp;
  Check('... read again: IsHold', M.IsHold);
  M.SetHold(False);
  Check('SetHold(False): cleared', (not M.IsHold) and M.IsPriv and M.IsCrash);
  M.SeekFirst(1); M.MsgStartUp;   {opening another message closes (and writes) #2}
  Check('... in the file: $0003 again', RawAttr(2) = $0003);
  M.SeekFirst(2); M.MsgStartUp;
  M.SetFileReq(True);
  M.SeekFirst(1); M.MsgStartUp;   {opening another message closes (and writes) #2}
  Check('hold and file request are separate bits (file request: $0803)', RawAttr(2) = $0803);
  M.SeekFirst(2); M.MsgStartUp;
  Check('... IsFileReq, not IsHold', M.IsFileReq and (not M.IsHold));
  M.CloseMsgBase;
  M.Done;
  writeln('failures: ', Fails);
  Halt(Fails);
end.
