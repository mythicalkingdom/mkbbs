{ SPDX-License-Identifier: GPL-3.0-or-later }
Program LrTool;   {helper of msgconvtest (MK=<config dir>):  lrtool get|set <area id> <user number> [value]   the last-read pointer of the user (JAM: by the check sum of the name, as mkmsgconv)
                                                          lrtool useron <name> <node>             a caller on line (useron.bbs)
                                                          lrtool useron -                         nobody on line}
{$mode objfpc}{$H+}
Uses SysUtils, MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKFile, MKMsgAbs, MKMsgHud, MKMsgJam, MKMsgSqu, MKMsgFid, MKMsgMer, MKMsgSyn, MKOpen;
Var
  M: AbsMsgPtr;
  U: UsersType;
  UO: UserOnType;
  Fn: String;
  K: LongInt;
Begin
Config := NewMKConfig(True);                  {MKJSON set: the JSON file, else the record files}
Config^.Load;
If ParamStr(1) = 'areaid' Then
  Begin
  WriteLn(Config^.GetMsgAreaId(StrToInt(ParamStr(2))));
  Halt(0);
  End;
If ParamStr(1) = 'useron' Then
  Begin
  Fn := IncludeTrailingPathDelimiter(Config^.GetBbsPath) + 'useron.bbs';
  DeleteFile(Fn);
  If ParamStr(2) <> '-' Then
    Begin
    FillChar(UO, SizeOf(UO), 0);
    UO.Name := ParamStr(2);
    UO.Node := StrToInt(ParamStr(3));
    UO.Status := 1;
    If SaveFilePos(Fn, UO, SizeOf(UO), 0) <> 0 Then Halt(3);
    End;
  Halt(0);
  End;
K := StrToInt(ParamStr(3));
If LoadFilePos(Config^.FindBbsFile('users.bbs') + 'users.bbs', U, SizeOf(U), K * SizeOf(U)) <> 0 Then Halt(4);
If Not OpenMsgArea(M, ParamStr(2)) Then Halt(2);
If UpCase(ParamStr(2)[1]) = 'J' Then
  K := JamStrCrc(U.Name);
If ParamStr(1) = 'set' Then
  M^.SetLastRead(K, StrToInt(ParamStr(4)))
Else
  WriteLn(M^.GetLastRead(K));
If CloseMsgArea(M) Then;
End.
