{ SPDX-License-Identifier: GPL-3.0-or-later }
program tossdump;
{$mode tp}
{ tossdump <area> ...: the messages of the message areas of the configuration (MK=...) }
uses MKString, MKGlobT, MKCfgAbs, MKCfgMK, MKMsgAbs, MKOpen;
var i: Word; P: AbsMsgPtr; A: Word; S: String; C: Char; T: AnsiString; O, D: AddrType; Code: Integer;
begin
  Config := New(MKCfgObjPtr, Init); Config^.Load;
  for i := 1 to ParamCount do begin
    Val(ParamStr(i), A, Code);
    if not OpenMsgArea(P, Config^.GetMsgAreaId(A)) then begin writeln('area ', A, ': cannot open'); continue; end;
    writeln('area ', A, ' n=', P^.NumberOfMsgs);
    P^.SeekFirst(1);
    while P^.SeekFound do begin
      P^.MsgStartUp;
      P^.GetOrig(O); P^.GetDest(D);
      writeln('msg ', P^.GetMsgNum, ' from=', P^.GetFrom, ' to=', P^.GetTo, ' subj=', P^.GetSubj, ' date=', P^.GetDate, ' time=', P^.GetTime,
        ' echo=', P^.IsEchoed, ' fattach=', P^.IsFAttach, ' sent=', P^.IsSent, ' local=', P^.IsLocal, ' priv=', P^.IsPriv, ' orig=', AddrStr(O), ' dest=', AddrStr(D));
      P^.MsgTxtStartUp; T := ''; C := P^.GetChar;
      while not P^.EOM do begin if C = #13 then T := T + '|' else if C = #1 then T := T + '^' else if C >= ' ' then T := T + C; C := P^.GetChar; end;
      writeln('text ', T);
      P^.SeekNext;
    end;
    if CloseMsgArea(P) then;
  end;
end.
