program postmsg;
{$mode tp}
{$H+}
{ POSTPRIV=1 makes it private, POSTRCVD=1 read.   postmsg <area> <from> <to> <subject> <text line> [<text line> ...]: writes a public local message (an echomail one with the environment variable POSTTYPE=echo) in a message area of the BBS
  (MK=<config dir>) the way mk's editor does; the message base is made when it is not there yet (tests/hubsetup.py). }
uses Dos, MKString, MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKMsgAbs, MKOpen;
var P: AbsMsgPtr; Yy, Mo, Dd, Dw, Hh, Mi, Ss, Cs: Word; i: Integer; Area: Word;
function Z2(N: Word): String; begin Z2 := Chr(48 + (N div 10) mod 10) + Chr(48 + N mod 10); end;
begin
  Config := NewMKConfig(True);
  if Config = nil then begin writeln('no config'); halt(1); end;
  Config^.Load;
  Area := Str2Long(ParamStr(1));
  if not OpenOrCreateMsgArea(P, Config^.GetMsgAreaId(Area)) then begin writeln('area ', Area, ': cannot open or make'); halt(1); end;
  GetDate(Yy, Mo, Dd, Dw); GetTime(Hh, Mi, Ss, Cs);
  if GetEnv('POSTTYPE') = 'echo' then P^.SetMailType(mmtEchoMail) else P^.SetMailType(mmtNormal);
  P^.StartNewMsg;
  P^.SetFrom(ParamStr(2)); P^.SetTo(ParamStr(3)); P^.SetSubj(ParamStr(4));
  P^.SetDate(Z2(Mo) + '-' + Z2(Dd) + '-' + Z2(Yy mod 100)); P^.SetTime(Z2(Hh) + ':' + Z2(Mi));
  P^.SetPriv(GetEnv('POSTPRIV') <> ''); P^.SetLocal(True); P^.SetEcho(True);
  if GetEnv('POSTRCVD') <> '' then P^.SetRcvd(True);
  for i := 5 to ParamCount do P^.DoStringLn(ParamStr(i));
  if P^.WriteMsg <> 0 then begin writeln('write failed'); halt(1); end;
  writeln('posted as message ', P^.GetMsgNum, ' in area ', Area, ' (', Config^.GetMsgName(Area), ')');
  if CloseMsgArea(P) then;
end.
