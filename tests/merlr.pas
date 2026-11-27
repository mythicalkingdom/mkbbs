{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MerLR;
{$mode objfpc}{$H+}
{ helper of userpacktest: merlr new|set|get <Merlin base> [user [value]] }
Uses SysUtils, MKMsgAbs, MKOpen, MKMsgMer;
Var
  M: AbsMsgPtr;
  i: LongInt;
Begin
If (ParamCount < 2) Then Halt(1);
If Not OpenOrCreateMsgArea(M, 'M' + ParamStr(2)) Then Halt(2);
If ParamStr(1) = 'set' Then
  Begin
  For i := 0 To StrToInt(ParamStr(3)) - 1 Do
    M^.SetLastRead(i, i + 70000);
  End
Else If ParamStr(1) = 'get' Then
  WriteLn(M^.GetLastRead(StrToInt(ParamStr(3))));
M^.CloseMsgBase;
Dispose(M, Done);
End.
