{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgGlob;   {Helpers shared by the configuration editor screens}

{$I MKB.Def}

{
     The colour set, frame characters and mouse cursor of the Object
     Professional version are gone: Free Vision draws the windows.  Only the
     flag string conversions are left.
}

Interface

Function Flag2Str(Number: Byte): String;
Function Str2Flag(St: String): Byte;

Implementation

Uses MKString;

Function Flag2Str(Number: Byte): String;
  Var
    Temp2: Byte;
    i: Word;
    TempStr: String[8];

  Begin
  Temp2 := $01;
  For i := 1 to 8 Do
    Begin
    If (Number and Temp2) <> 0 Then
      TempStr[i] := '1'
    Else
      TempStr[i] := '0';
    Temp2 := Temp2 shl 1;
    End;
  TempStr[0] := #8;
  Flag2Str := TempStr;
  End;


Function Str2Flag(St: String): Byte;
  Var
    i: Word;
    Temp1: Byte;
    Temp2: Byte;

  Begin
  St := StripBoth(St,' ');
  St := PadLeft(St,'0',8);
  Temp1 := 0;
  Temp2 := $01;
  For i := 1 to 8 Do
    Begin
    If St[i] = '1' Then
      Inc(Temp1,Temp2);
    Temp2 := Temp2 shl 1;
    End;
  Str2Flag := Temp1;
  End;


End.
