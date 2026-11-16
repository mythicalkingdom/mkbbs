program tossmake;
{$mode tp}
{ tossmake: local messages as the BBS writes them (mk's editor): echomail in area 6 and netmail in area 4 }
uses MKString, MKGlobT, MKCfgAbs, MKCfgMK, MKMsgAbs, MKOpen;
var P: AbsMsgPtr; A, B: AddrType;

procedure Net(Subj: String; Dest: AddrType; Crash, Hold, Priv: Boolean);
begin
  if not OpenMsgArea(P, Config^.GetMsgAreaId(4)) then begin writeln('area 4: cannot open'); Halt(1); end;
  P^.SetMailType(mmtNetMail);
  P^.StartNewMsg;
  Config^.GetMsgAddr(4, A);
  P^.SetOrig(A); P^.SetDest(Dest);
  P^.SetFrom('Mark May'); P^.SetTo('Someone'); P^.SetSubj(Subj);
  P^.SetDate('11-16-26'); P^.SetTime('14:15');
  P^.SetPriv(Priv); P^.SetCrash(Crash); P^.SetHold(Hold); P^.SetLocal(True); P^.SetEcho(True);
  P^.DoStringLn('netmail text');
  if P^.WriteMsg <> 0 then begin writeln('write failed'); Halt(1); end;
  if CloseMsgArea(P) then;
end;

begin
  Config := New(MKCfgObjPtr, Init); Config^.Load;
  { an echomail message in area 6 }
  if not OpenMsgArea(P, Config^.GetMsgAreaId(6)) then begin writeln('area 6: cannot open'); Halt(1); end;
  P^.SetMailType(mmtEchoMail);
  P^.StartNewMsg;
  P^.SetFrom('Mark May'); P^.SetTo('All'); P^.SetSubj('local echo message');
  P^.SetDate('11-16-26'); P^.SetTime('14:15');
  P^.SetLocal(True); P^.SetEcho(True);
  P^.DoStringLn('written by the BBS');
  P^.DoStringLn('--- MK Bbs v0.01');
  P^.DoStringLn(Config^.GetDefaultOrigStr(6));
  if P^.WriteMsg <> 0 then begin writeln('write failed'); Halt(1); end;
  { a second one that is not marked for export (already sent) }
  P^.StartNewMsg;
  P^.SetFrom('Mark May'); P^.SetTo('All'); P^.SetSubj('local, not to be exported');
  P^.SetDate('11-16-26'); P^.SetTime('14:16');
  P^.SetLocal(True); P^.SetEcho(False);
  P^.DoStringLn('stays here');
  if P^.WriteMsg <> 0 then begin writeln('write failed'); Halt(1); end;
  if CloseMsgArea(P) then;
  { netmail: direct to system 2 (normal), to a node behind system 1 (crash), hold to system 1 }
  B.Zone := 1; B.Net := 110; B.Node := 200; B.Point := 0;
  Net('netmail to 1:110/200', B, False, False, True);
  B.Zone := 2; B.Net := 250; B.Node := 1; B.Point := 0;
  Net('crash netmail to 2:250/1', B, True, False, True);
  B.Zone := 1; B.Net := 110; B.Node := 100; B.Point := 0;
  Net('held netmail to 1:110/100', B, False, True, True);
end.
