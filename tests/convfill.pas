{ SPDX-License-Identifier: GPL-3.0-or-later }
Program ConvFill;   {helper of msgconvtest: convfill <area> : writes a few different messages into the area (by the configuration), deletes the third}
{$mode objfpc}{$H+}
Uses SysUtils, MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKMsgAbs, MKMsgHud, MKMsgJam, MKMsgSqu, MKMsgFid, MKMsgMer, MKMsgSyn, MKOpen;
Var
  M: AbsMsgPtr;
  A: Word;
  i: Integer;
  O, D: AddrType;

Procedure Add(Const From, ToN, Subj: String; Priv, Rcvd: Boolean; Refer: LongInt; Const Kludge: String; Const Body: String);
  Var
    p: Integer;
    S, L: String;

  Begin
  M^.StartNewMsg;
  M^.SetFrom(From);
  M^.SetTo(ToN);
  M^.SetSubj(Subj);
  M^.SetDate('11-' + RightStr('0' + IntToStr(10 + i), 2) + '-26');
  M^.SetTime('1' + IntToStr(i mod 10) + ':15');
  M^.SetPriv(Priv);
  M^.SetRcvd(Rcvd);
  M^.SetLocal(True);
  M^.SetSent(True);
  M^.SetOrig(O);
  M^.SetDest(D);
  M^.SetRefer(Refer);
  If Kludge <> '' Then
    M^.DoKludgeLn(Kludge);
  S := Body;
  Repeat
    p := Pos('|', S);
    If p = 0 Then L := S Else L := Copy(S, 1, p - 1);
    M^.DoStringLn(L);
    If p > 0 Then Delete(S, 1, p);
  Until p = 0;
  If M^.WriteMsg <> 0 Then Halt(3);
  End;

Begin
Config := NewMKConfig(True);
Config^.Load;
A := StrToInt(ParamStr(1));
If Not OpenOrCreateMsgArea(M, Config^.GetMsgAreaId(A)) Then
  Begin
  WriteLn(StdErr, 'cannot open ', Config^.GetMsgAreaId(A));
  Halt(2);
  End;
O.Zone := 1; O.Net := 110; O.Node := 290; O.Point := 0;
D.Zone := 1; D.Net := 110; D.Node := 100; D.Point := 3;
i := 1; Add('Alice', 'All', 'First message', False, False, 0, '', 'Hello|second line|');
i := 2; Add('Bob', 'Alice', 'Re: First message', False, False, 1, 'MSGID: 1:110/290 12345678', 'A reply|with two lines');
i := 3; Add('Carol', 'All', 'Deleted soon', False, False, 0, '', 'This goes');
i := 4; Add('Dave', 'Alice', 'Private one', True, True, 0, '', 'Secret text');
i := 5; Add('A name of thirty five characters!', 'Another name of thirty-five chars', 'A rather long subject line of about seventy characters, which only some kinds keep', False, False, 0, '', 'Long header fields');
i := 6; Add('Eve', 'All', 'Re: Re: First message', False, False, 2, 'REPLY: 1:110/290 12345678', 'Third level|' + StringOfChar('x', 70) + '|' + StringOfChar('y', 79) + '|last line');
i := 7; Add('Frank', 'All', 'Short body', False, False, 0, '', 'x');
M^.SeekFirst(3);
If M^.SeekFound Then
  Begin
  M^.MsgStartUp;
  M^.DeleteMsg;
  End;
M^.CloseMsgBase;
Dispose(M, Done);
End.
