Unit CfgPPack;   {Packers list, converted from CFGPPACK}

{$I MKB.Def}

Interface

Procedure DoCfgPPack;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgList, CfgPack;

Function ItemStr(Item: Word): String;
  Begin
  Case Item Of
    1: ItemStr := 'LZH';
    2: ItemStr := 'ZIP';
    3: ItemStr := 'ARC';
    4: ItemStr := 'ZOO';
    5: ItemStr := 'DWC';
    6: ItemStr := 'ARJ';
    7: ItemStr := 'HYP';
    Else ItemStr := '';
    End;
  End;

Procedure DoCfgPPack;
  Begin
  RunList('Packers', 7, 14, ItemStr, DoCfgPack);
  End;


End.
