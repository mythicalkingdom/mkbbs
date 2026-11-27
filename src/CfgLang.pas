{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgLang;   {Converted from CFGLANG for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgLang(LN: Word);

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;



Type UserRecord = Record
  Name: String[10];
  FileName: String[8];
  MenuPath: String[60];
  TxtPath: String[60];
  QuesPath: String[60];
  End;

Var
  UR: ^UserRecord;

Procedure DoCfgLang(LN: Word);
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  UR^.Name := Config^.GetLangName(LN);
  UR^.FileName := Config^.GetLangFile(LN);
  UR^.MenuPath := Config^.GetMnuPath(LN);
  UR^.TxtPath := Config^.GetTxtPath(LN);
  UR^.QuesPath := Config^.GetLangQuesPath(LN);
  F.Init('Language Configuration');
  F.Window(5, 5, 75, 13);
  F.At(2, 4, 2, 19);
  F.AddString('Language Name:', UR^.Name, 10, 'Language Name');
  F.At(2, 37, 2, 48);
  F.AddString('File Name:', UR^.FileName, 8, 'File Name');
  F.At(4, 4, 4, 15);
  F.AddDir('Menu Path:', UR^.MenuPath, 50, 'Menu Path');
  F.At(6, 4, 6, 18);
  F.AddDir('Screens Path:', UR^.TxtPath, 50, 'Screens Path');
  F.At(8, 4, 8, 14);
  F.AddDir('Q-A Path:', UR^.QuesPath, 50, 'Q-A Path');
  If F.Execute Then
    Begin
    Config^.SetLangName(LN, UR^.Name);
    Config^.SetLangFile(LN, UR^.FileName);
    Config^.SetMnuPath(LN, UR^.MenuPath);
    Config^.SetTxtPath(LN, UR^.TxtPath);
    Config^.SetLangQuesPath(LN, UR^.QuesPath);
    End;
    Dispose(UR);
  End;


End.
