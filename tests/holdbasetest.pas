{ SPDX-License-Identifier: GPL-3.0-or-later }
program holdbasetest;
{$mode tp}
{ hold for pickup in JAM, Squish and Merlin: written with SetHold, read back after reopening, changed with ReWriteHdr;
  the other flags are not disturbed }
uses MKString, MKFile, MKGlobT, MKMsgAbs, MKMsgJam, MKMsgSqu, MKMsgMer;
var Fails: Integer; Dir: String;

procedure Check(N: String; Ok: Boolean);
begin if Ok then writeln('ok   hold: ', N) else begin writeln('FAIL hold: ', N); Inc(Fails); end; end;

procedure Add(P: AbsMsgPtr; Subj: String; Hold, Priv, Crash: Boolean);
var A: AddrType;
begin
  P^.StartNewMsg;
  P^.SetFrom('Alice'); P^.SetTo('Bob'); P^.SetSubj(Subj);
  P^.SetDate('02-03-95'); P^.SetTime('12:34');
  A.Zone := 1; A.Net := 110; A.Node := 290; A.Point := 0; P^.SetOrig(A);
  A.Node := 100; P^.SetDest(A);
  if Hold then P^.SetHold(True);
  if Priv then P^.SetPriv(True);
  if Crash then P^.SetCrash(True);
  P^.DoStringLn('text');
  if P^.WriteMsg <> 0 then writeln('  (WriteMsg failed for ', Subj, ')');
end;

procedure Go(Name: String; P: AbsMsgPtr; Path: String; Mer: Boolean);
begin
  P^.SetMsgPath(Path);
  Check(Name + ': create', P^.CreateMsgBase(200, 0) = 0);
  Check(Name + ': open', P^.OpenMsgBase = 0);
  if not Mer then Check(Name + ': lock', P^.LockMsgBase);
  Add(P, 'held', True, False, False);
  Add(P, 'plain', False, False, False);
  Add(P, 'held private crash', True, True, True);
  if not Mer then Check(Name + ': unlock', P^.UnLockMsgBase);
  Check(Name + ': 3 messages', P^.NumberOfMsgs = 3);
  P^.CloseMsgBase;
  Check(Name + ': reopen', P^.OpenMsgBase = 0);
  P^.SeekFirst(1); P^.MsgStartUp;
  Check(Name + ': #1 held (read after reopening)', P^.SeekFound and P^.IsHold and (not P^.IsPriv) and (not P^.IsCrash));
  P^.SeekFirst(2); P^.MsgStartUp;
  Check(Name + ': #2 not held', P^.SeekFound and (not P^.IsHold));
  P^.SeekFirst(3); P^.MsgStartUp;
  Check(Name + ': #3 held, private, crash', P^.IsHold and P^.IsPriv and P^.IsCrash);
  { change with ReWriteHdr }
  P^.SeekFirst(2); P^.MsgStartUp;
  P^.SetHold(True); P^.ReWriteHdr;
  P^.SeekFirst(1); P^.MsgStartUp;
  P^.SetHold(False); P^.ReWriteHdr;
  P^.SeekFirst(3); P^.MsgStartUp;
  P^.SetHold(False); P^.ReWriteHdr;
  P^.CloseMsgBase;
  Check(Name + ': reopen again', P^.OpenMsgBase = 0);
  P^.SeekFirst(1); P^.MsgStartUp;
  Check(Name + ': #1 hold cleared', not P^.IsHold);
  P^.SeekFirst(2); P^.MsgStartUp;
  Check(Name + ': #2 hold set', P^.IsHold and (not P^.IsPriv));
  P^.SeekFirst(3); P^.MsgStartUp;
  Check(Name + ': #3 hold cleared, private and crash kept', (not P^.IsHold) and P^.IsPriv and P^.IsCrash);
  P^.MsgTxtStartUp;
  Check(Name + ': the text is intact', P^.GetString(79) = 'text');
  P^.CloseMsgBase;
end;

var J: JamMsgPtr; S: SqMsgPtr; M: MerlinMsgPtr;
begin
  Dir := WithBackSlash(ParamStr(1));
  FileMode := fmReadWrite;
  EraseFile(Dir + 'hj.jhr'); EraseFile(Dir + 'hj.jdt'); EraseFile(Dir + 'hj.jdx'); EraseFile(Dir + 'hj.jlr');
  EraseFile(Dir + 'hs.sqd'); EraseFile(Dir + 'hs.sqi'); EraseFile(Dir + 'hs.sql');
  EraseFile(Dir + 'hm.dat');
  New(J, Init); Go('JAM', J, Dir + 'hj', False); Dispose(J, Done);
  New(S, Init); Go('Squish', S, Dir + 'hs', False); Dispose(S, Done);
  New(M, Init); Go('Merlin', M, Dir + 'hm.dat', True); Dispose(M, Done);
  writeln('failures: ', Fails);
  Halt(Fails);
end.
