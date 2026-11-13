Unit CfgPAddr;   {Addresses list, converted from CFGPADDR}

{$I MKB.Def}

Interface

Procedure DoCfgPAddr;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgList, CfgAddr;

Function ItemStr(Item: Word): String;
  Var
    TmpAddr: AddrType;

  Begin
  Config^.GetAddr(Item, TmpAddr);
  ItemStr := PadRight(Long2Str(Item), ' ', 3) + AddrStr(TmpAddr);
  End;

Procedure DoCfgPAddr;
  Begin
  RunList('Addresses', 10, 36, ItemStr, DoCfgAddr);
  End;


End.
