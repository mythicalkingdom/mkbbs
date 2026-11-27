{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgOff;   {Available offline mail types, converted from CFGOFF}

{$I MKB.Def}

Interface

Procedure DoCfgOffType;

Implementation

Uses MKCfgAbs, CfgList;

Procedure DoCfgOffType;
  Var
    Marks: CfgMarks;
    i: Word;

  Begin
  FillChar(Marks, SizeOf(Marks), 0);
  For i := 1 To 5 Do
    Marks[i] := Config^.GetOffTypeAvail(i);
  If RunChecks('Available Offline', 'QWK|XRS|BlueWave|Text|PKT', Marks) Then
    For i := 1 To 5 Do
      Config^.SetOffTypeAvail(i, Marks[i]);
  End;


End.
