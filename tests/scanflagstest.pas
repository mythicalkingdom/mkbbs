{ SPDX-License-Identifier: GPL-3.0-or-later }
program scanflagstest;
{$mode tp}
{ what the scanner of mktoss relies on: a message written like the BBS editor does (local, echo) is "to export" when read
  back (local, echoed, not sent); after SetSent(True) + SetEcho(False) + ReWriteHdr it is not; a tossed message (not local,
  not echo) never is }
uses MKString, MKFile, MKGlobT, MKMsgAbs, MKMsgJam, MKMsgSqu, MKMsgMer;
var Fails: Integer; Dir: String;

procedure Check(N: String; Ok: Boolean);
begin if Ok then writeln('ok   scanflags: ', N) else begin writeln('FAIL scanflags: ', N); Inc(Fails); end; end;

function ToExport(P: AbsMsgPtr): Boolean;
begin ToExport := P^.IsLocal and P^.IsEchoed and (not P^.IsSent) and (not P^.IsDeleted); end;

procedure Add(P: AbsMsgPtr; Subj: String; Local, Echo: Boolean);
begin
  P^.SetMailType(mmtEchoMail);
  P^.StartNewMsg;
  P^.SetFrom('Alice'); P^.SetTo('All'); P^.SetSubj(Subj);
  P^.SetDate('02-03-95'); P^.SetTime('12:34');
  P^.SetLocal(Local); P^.SetEcho(Echo); P^.SetRcvd(False); P^.SetSent(False);
  P^.DoStringLn('text');
  if P^.WriteMsg <> 0 then writeln('  (WriteMsg failed for ', Subj, ')');
end;

procedure Go(Name: String; P: AbsMsgPtr; Path: String; Create: Boolean);
begin
  P^.SetMsgPath(Path);
  if Create then Check(Name + ': create', P^.CreateMsgBase(200, 0) = 0);
  Check(Name + ': open', P^.OpenMsgBase = 0);
  Add(P, 'local', True, True);
  Add(P, 'tossed', False, False);
  P^.CloseMsgBase;
  Check(Name + ': reopen', P^.OpenMsgBase = 0);
  P^.SeekFirst(1); P^.MsgStartUp;
  Check(Name + ': the local echo message is to be exported', P^.SeekFound and ToExport(P));
  P^.SeekFirst(2); P^.MsgStartUp;
  Check(Name + ': the tossed message is not', P^.SeekFound and (not ToExport(P)));
  P^.SeekFirst(1); P^.MsgStartUp;
  P^.SetSent(True); P^.SetEcho(False); P^.ReWriteHdr;
  P^.CloseMsgBase;
  Check(Name + ': reopen again', P^.OpenMsgBase = 0);
  P^.SeekFirst(1); P^.MsgStartUp;
  Check(Name + ': after SetSent + SetEcho(False) + ReWriteHdr it is not to be exported (and is still local)', (not ToExport(P)) and P^.IsLocal);
  P^.SeekFirst(2); P^.MsgStartUp;
  Check(Name + ': the other one is still not', not ToExport(P));
  P^.CloseMsgBase;
end;

var J: JamMsgPtr; S: SqMsgPtr; M: MerlinMsgPtr;
begin
  Dir := WithBackSlash(ParamStr(1));
  FileMode := fmReadWrite;
  EraseFile(Dir + 'sj.jhr'); EraseFile(Dir + 'sj.jdt'); EraseFile(Dir + 'sj.jdx'); EraseFile(Dir + 'sj.jlr');
  EraseFile(Dir + 'ss.sqd'); EraseFile(Dir + 'ss.sqi'); EraseFile(Dir + 'ss.sql');
  EraseFile(Dir + 'sm.dat');
  New(J, Init); Go('JAM', J, Dir + 'sj', True); Dispose(J, Done);
  New(S, Init); Go('Squish', S, Dir + 'ss', True); Dispose(S, Done);
  New(M, Init); Go('Merlin', M, Dir + 'sm.dat', True); Dispose(M, Done);
  writeln('failures: ', Fails);
  Halt(Fails);
end.
