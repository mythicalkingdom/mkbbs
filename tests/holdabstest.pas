{ SPDX-License-Identifier: GPL-3.0-or-later }
program holdabstest;
{$mode tp}
{ the abstract message object: hold is False and SetHold does nothing (bases without the flag); the packet unit answers through the abstract pointer }
uses MKString, MKFile, MKGlobT, MKMsgAbs, MKMsgPkt, MKMsgHud, MKMsgEzy, MKMsgSyn;
var Fails: Integer; Abs: AbsMsgObj; P: AbsMsgPtr;
procedure Check(N: String; Ok: Boolean);
begin if Ok then writeln('ok   hold: ', N) else begin writeln('FAIL hold: ', N); Inc(Fails); end; end;
begin
  Abs.Init;
  Abs.SetHold(True);
  Check('AbsMsgObj.IsHold is False (and SetHold is harmless)', not Abs.IsHold);
  Abs.Done;
  P := New(PktMsgPtr, Init);
  Check('PktMsgObj through an AbsMsgPtr: IsHold is virtual (False on a new object)', not P^.IsHold);
  P^.StartNewMsg; P^.SetHold(True);
  Check('... SetHold(True) through the abstract pointer reaches the packet unit', P^.IsHold);
  Dispose(PktMsgPtr(P), Done);
  P := New(HudsonMsgPtr, Init);
  P^.SetHold(True);
  Check('a base without the flag (Hudson): IsHold is False', not P^.IsHold);
  Dispose(HudsonMsgPtr(P), Done);
  P := New(EzyMsgPtr, Init);
  P^.SetHold(True);
  Check('a base without the flag (Ezycom): IsHold is False', not P^.IsHold);
  Dispose(EzyMsgPtr(P), Done);
  P := New(SynMsgPtr, Init);
  P^.SetHold(True);
  Check('a base without the flag (Synchronet): IsHold is False', not P^.IsHold);
  Dispose(SynMsgPtr(P), Done);
  writeln('failures: ', Fails);
  Halt(Fails);
end.
