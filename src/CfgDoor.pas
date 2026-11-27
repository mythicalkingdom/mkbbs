{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgDoor;   {Log-on doors, converted from CFGDOOR}

{$I MKB.Def}

Interface

Procedure DoPickDoor;
Procedure DoCfgDoor(DN: Word);

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgList, CfgSec2;

Type
  UserRecord = Record
    Data: String[79];
    Sec: SecType;
    End;


Procedure DoCfgDoor(DN: Word);
  Var
    UR: ^UserRecord;
    F: CfgFormObj;

  Begin
  New(UR);
  Config^.GetDoorSec(DN, UR^.Sec);
  UR^.Data := Config^.GetDoorData(DN);
  F.Init('Door Config #' + Long2Str(DN));
  F.Window(5, 15, 75, 19);
  F.At(2, 3, 2, 14);
  F.Show(55);
  F.AddString('Door Data:', UR^.Data, 79, 'Door program and its options');
  F.At(4, 3, 4, 13);
  F.AddNumber('Security:', UR^.Sec.Level, 2, 0, 65535, 'Security level needed');
  F.OnF2(EditSecurity, @UR^.Sec, 'Door Security');
  If F.Execute Then
    Begin
    Config^.SetDoorSec(DN, UR^.Sec);
    Config^.SetDoorData(DN, UR^.Data);
    End;
  Dispose(UR);
  End;


Function DoorStr(Item: Word): String;
  Begin
  DoorStr := PadLeft(Long2Str(Item), ' ', 2) + ' ' + Copy(Config^.GetDoorData(Item), 1, 55);
  End;


Procedure DoPickDoor;
  Begin
  RunList('Log-On Doors', 10, 60, DoorStr, DoCfgDoor);
  End;


End.
