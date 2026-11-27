{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgFast;   {"Fast" message area options: one flag per message area, converted from CFGFAST}

{$I MKB.Def}

Interface

Procedure DoFastPick(FastType: Word);

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgList;

Function AreaStr(Item: Word): String;
  Begin
  AreaStr := PadRight(Long2Str(Item), ' ', 4) + Copy(Config^.GetMsgName(Item), 1, 19);
  End;


Procedure DoFastPick(FastType: Word);
  Var
    Marks: CfgBigMarks;
    i: Word;
    Title: String;

  Begin
  Case FastType Of
    1: Title := 'Allow Combined';
    2: Title := 'Allow Ansi';
    3: Title := 'Allow Hi-Bit Chars';
    4: Title := 'Allow Reader Taglines';
    5: Title := 'Add Fido Info';
    6: Title := 'Reader Tearlines';
    7: Title := 'Allow Offline';
    8: Title := 'Force Offline';
    9: Title := 'Default Combined';
    10: Title := 'Reader Origin Lines';
    11: Title := 'Import Path';
    12: Title := 'Hide Imported Path';
    13: Title := 'Import Seen-By';
    14: Title := 'Hide Imported Seen-By';
    Else Title := '*';
    End;
  For i := 1 To 500 Do
    Case FastType Of
      1: Marks[i] := Config^.GetMsgAllowCombined(i);
      2: Marks[i] := Config^.MsgAllowAnsi(i);
      3: Marks[i] := Config^.MsgAllowHiBit(i);
      4: Marks[i] := Config^.MsgAllowTag(i);
      5: Marks[i] := Config^.MsgAddFido(i);
      6: Marks[i] := Config^.GetMsgReaderTear(i);
      7: Marks[i] := Config^.GetMsgAllowOffline(i);
      8: Marks[i] := Config^.GetMsgForceOffline(i);
      9: Marks[i] := Config^.GetMsgDefCombined(i);
      10: Marks[i] := Config^.GetMsgReaderOrig(i);
      11: Marks[i] := Config^.GetEchoAreaImportPath(i);
      12: Marks[i] := Config^.GetEchoAreaHidePath(i);
      13: Marks[i] := Config^.GetEchoAreaImportSeen(i);
      14: Marks[i] := Config^.GetEchoAreaHideSeen(i);
      Else Marks[i] := False;
      End;
  If RunMarkList(Title, 500, 28, AreaStr, Marks) Then
    For i := 1 To 500 Do
      Case FastType Of
        1: Config^.SetMsgAllowCombined(i, Marks[i]);
        2: Config^.SetMsgAllowAnsi(i, Marks[i]);
        3: Config^.SetMsgAllowHiBit(i, Marks[i]);
        4: Config^.SetMsgAllowTag(i, Marks[i]);
        5: Config^.SetMsgAddFido(i, Marks[i]);
        6: Config^.SetMsgReaderTear(i, Marks[i]);
        7: Config^.SetMsgAllowOffline(i, Marks[i]);
        8: Config^.SetMsgForceOffline(i, Marks[i]);
        9: Config^.SetMsgDefCombined(i, Marks[i]);
        10: Config^.SetMsgReaderOrig(i, Marks[i]);
        11: Config^.SetEchoAreaImportPath(i, Marks[i]);
        12: Config^.SetEchoAreaHidePath(i, Marks[i]);
        13: Config^.SetEchoAreaImportSeen(i, Marks[i]);
        14: Config^.SetEchoAreaHideSeen(i, Marks[i]);
        End;
  End;


End.
