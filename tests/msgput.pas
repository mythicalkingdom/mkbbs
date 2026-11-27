{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MsgPut;
{$mode objfpc}{$H+}
{ helper of apitest: msgput add <area id> <from> <to> <subject> <private 0|1> <text, lines separated by |> [reply-to] [kludge]
                     msgput del <area id> <number> }
Uses SysUtils, MKGlobT, MKMsgAbs, MKOpen, MKMsgMer;
Var
  M: AbsMsgPtr;
  A: AddrType;
  S, L: String;
  p: Integer;
Begin
If ParamCount < 3 Then Halt(1);
If Not OpenOrCreateMsgArea(M, ParamStr(2)) Then Halt(2);
If ParamStr(1) = 'del' Then
  Begin
  M^.SeekFirst(StrToInt(ParamStr(3)));
  If M^.SeekFound Then
    Begin
    M^.MsgStartUp;
    M^.DeleteMsg;
    End;
  End
Else
  Begin
  M^.StartNewMsg;
  M^.SetFrom(ParamStr(3));
  M^.SetTo(ParamStr(4));
  M^.SetSubj(ParamStr(5));
  M^.SetDate('11-20-26');
  M^.SetTime('10:15');
  M^.SetPriv(ParamStr(6) = '1');
  M^.SetLocal(True);
  A.Zone := 1; A.Net := 110; A.Node := 100; A.Point := 0;
  M^.SetOrig(A);
  If ParamCount >= 8 Then
    M^.SetRefer(StrToIntDef(ParamStr(8), 0));
  If ParamCount >= 9 Then
    M^.DoKludgeLn(ParamStr(9));
  S := ParamStr(7);
  Repeat
    p := Pos('|', S);
    If p = 0 Then
      L := S
    Else
      L := Copy(S, 1, p - 1);
    M^.DoStringLn(L);
    If p > 0 Then
      Delete(S, 1, p);
  Until p = 0;
  If M^.WriteMsg <> 0 Then Halt(3);
  End;
M^.CloseMsgBase;
Dispose(M, Done);
End.
