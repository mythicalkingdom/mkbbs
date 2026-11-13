Unit CfgPLan;   {Languages list, converted from CFGPLAN}

{$I MKB.Def}

Interface

Procedure DoCfgPLan;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgList, CfgLang;

Function ItemStr(Item: Word): String;
  Begin
  ItemStr := PadRight(Long2Str(Item), ' ', 2) + Config^.GetLangName(Item);
  End;

Procedure DoCfgPLan;
  Begin
  RunList('Languages', 10, 30, ItemStr, DoCfgLang);
  End;


End.
