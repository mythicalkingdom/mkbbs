{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgNet;   {Networks an echomail system may use (A-Z), converted from CFGNET}

{$I MKB.Def}

Interface

Procedure DoCfgNet(SysNo: Word);

Implementation

Uses MKCfgAbs, CfgList;

Function NetStr(Item: Word): String;
  Begin
  NetStr := 'Network - ' + Char(Item + Ord('A') - 1);
  End;


Procedure DoCfgNet(SysNo: Word);
  Var
    Marks: CfgBigMarks;
    i: Word;

  Begin
  FillChar(Marks, SizeOf(Marks), 0);
  For i := 1 To 26 Do
    Marks[i] := Config^.GetEchoToNetwork(SysNo, i);
  If RunMarkList('Networks', 26, 24, NetStr, Marks) Then
    For i := 1 To 26 Do
      Config^.SetEchoToNetwork(SysNo, i, Marks[i]);
  End;


End.
