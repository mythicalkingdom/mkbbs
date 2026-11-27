{ SPDX-License-Identifier: GPL-3.0-or-later }
{$I MKB.Def}
Unit CfgEPack;  {Cfg Echoing Systems Pack}

Interface

Function PackerNum(Packer: String): Word;
Function PackerStr(PN: Word): String;


Implementation

uses
  MKString;


Function PackerStr(PN: Word): String;
  Begin
  Case PN of
    1: PackerStr := 'LZH';
    2: PackerStr := 'ZIP';
    3: PackerStr := 'ARC';
    4: PackerStr := 'ZOO';
    5: PackerStr := 'DWC';
    6: PackerStr := 'ARJ';
    7: PackerStr := 'HYP';
    Else
      PackerStr := '  ';
    End;
  End;

Function PackerNum(Packer: String): Word;
  Var
    TmpStr: String;

  Begin
  TmpStr := Upper(Copy(Packer,1,3));
  If Packer = 'LZH' Then
    PackerNum := 1
  Else If Packer = 'ZIP' Then
    PackerNum := 2
  Else If Packer = 'ARC' Then
    PackerNum := 3
  Else If Packer = 'ZOO' Then
    PackerNum := 4
  Else If Packer = 'DWC' Then
    PackerNum := 5
  Else If Packer = 'ARJ' Then
    PackerNum := 6
  Else If Packer = 'HYP' Then
    PackerNum := 7
  Else
    PackerNum := 0
  End;



End.