{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgAddr;   {Converted from CFGADDR for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgAddr(SysNum: Word);

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm;

Var
  UR: ^AddrType;

Procedure DoCfgAddr(SysNum: Word);
  Var
    F: CfgFormObj;

  Begin
  New(UR);
  Config^.GetAddr(SysNum, UR^);
  F.Init('Address');
  F.Window(11, 7, 69, 9);
  F.At(2, 3, 2, 9);
  F.AddNumber('Zone:', UR^.Zone, 2, 0, 65535, 'Zone');
  F.At(2, 18, 2, 23);
  F.AddNumber('Net:', UR^.Net, 2, 0, 65535, 'Net');
  F.At(2, 31, 2, 37);
  F.AddNumber('Node:', UR^.Node, 2, 0, 65535, 'Node');
  F.At(2, 45, 2, 52);
  F.AddNumber('Point:', UR^.Point, 2, 0, 65535, 'Point');
  If F.Execute Then
    Begin
    Config^.SetAddr(SysNum, UR^);
    End;
    Dispose(UR);
  End;


End.
