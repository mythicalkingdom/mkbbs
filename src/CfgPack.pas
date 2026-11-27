{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgPack;   {Converted from CFGPACK for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgPack(PN: Word);

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;


type
  UserRecord =
    record
      Name                 : string[10];
      Key                  : Char;
      Avail                : Boolean;
      PackCmd              : string[80];
      UnPackCmd            : string[80];
      PackStr: String[7];
    end;

Var
  UR: ^UserRecord;

Procedure DoCfgPack(PN: Word);
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  Case PN of
    1: UR^.PackStr := '[ LZH ]';
    2: UR^.PackStr := '[ ZIP ]';
    3: UR^.PackStr := '[ ARC ]';
    4: UR^.PackStr := '[ ZOO ]';
    5: UR^.PackStr := '[ DWC ]';
    6: UR^.PackStr := '[ ARJ ]';
    7: UR^.PackStr := '[ HYP ]';
    Else
      UR^.PackStr := '[ ??? ]';
    End;
  UR^.Name := Config^.GetPackName(PN);
  UR^.Key := Config^.GetPackChar(PN);
  UR^.Avail := Config^.GetPackAvail(PN);
  UR^.PackCmd := Config^.GetPackCmdLine(PN);
  UR^.UnPackCmd := Config^.GetUnPackCmdLine(PN);
  F.Init(UR^.PackStr);
  F.Window(5, 5, 76, 11);
  F.At(2, 3, 2, 9);
  F.AddString('Name:', UR^.Name, 10, 'Name');
  F.At(2, 24, 2, 29);
  F.AddChar('Key:', UR^.Key, 'Key');
  F.At(2, 37, 2, 48);
  F.AddYesNo('Available:', UR^.Avail, 'Available');
  F.At(4, 3, 4, 18);
  F.Show(80);
  F.AddString('Pack Cmd Line:', UR^.PackCmd, 50, 'Pack Cmd Line');
  F.At(6, 3, 6, 20);
  F.Show(80);
  F.AddString('UnPack Cmd Line:', UR^.UnPackCmd, 50, 'UnPack Cmd Line');
  If F.Execute Then
    Begin
  Config^.SetPackName(PN, UR^.Name);
    Config^.SetPackChar(PN, UR^.Key);
    Config^.SetPackAvail(PN, UR^.Avail);
    Config^.SetPackCmdLine(PN, UR^.PackCmd);
    Config^.SetUnPackCmdLine(PN, UR^.UnPackCmd);
    End;
    Dispose(UR);
  End;


End.
