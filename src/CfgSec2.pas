{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgSec2;   {Security level and flags editor}

{$I MKB.Def}

{
     EnterSec edits a security record (level and four flag bytes shown as 8
     binary digits each, first digit = bit 0).  EditSecurity has the signature
     the forms use for F2 on a field (see CfgForm.OnF2): Data points to the
     SecType.
}

Interface

Uses MKGlobT;

Procedure EnterSec(Var Sec: SecType; Title: String);
Procedure EditSecurity(Data: Pointer; Title: String);

Implementation

Uses CfgGlob, CfgForm;

Type
  ByteArray = Array[1..4] Of Byte;

Procedure EnterSec(Var Sec: SecType; Title: String);
  Var
    F: CfgFormObj;
    UR: SecType;
    Flag: Array[1..4] Of String[8];
    i: Word;

  Begin
  UR := Sec;
  For i := 1 To 4 Do
    Flag[i] := Flag2Str(ByteArray(UR.Flags)[i]);
  F.Init(Title);
  F.Window(24, 6, 45, 16);
  F.At(2, 3, 2, 10);
  F.AddNumber('Level:', UR.Level, 2, 0, 65535, 'Security level');
  F.At(4, 3, 4, 12);
  F.Filter('01');
  F.AddString('A Flags:', Flag[1], 8, 'Flags 1-8 of set A (1 = on)');
  F.At(6, 3, 6, 12);
  F.Filter('01');
  F.AddString('B Flags:', Flag[2], 8, 'Flags 1-8 of set B (1 = on)');
  F.At(8, 3, 8, 12);
  F.Filter('01');
  F.AddString('C Flags:', Flag[3], 8, 'Flags 1-8 of set C (1 = on)');
  F.At(10, 3, 10, 12);
  F.Filter('01');
  F.AddString('D Flags:', Flag[4], 8, 'Flags 1-8 of set D (1 = on)');
  If F.Execute Then
    Begin
    Sec := UR;
    For i := 1 To 4 Do
      ByteArray(Sec.Flags)[i] := Str2Flag(Flag[i]);
    End;
  End;


Procedure EditSecurity(Data: Pointer; Title: String);
  Begin
  EnterSec(SecType(Data^), Title);
  End;


End.
