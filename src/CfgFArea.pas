Unit CfgFArea;   {File Areas list, converted from CFGFAREA}

{$I MKB.Def}

Interface

Procedure DoCfgFArea;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgList, CfgFile;

Function ItemStr(Item: Word): String;
  Begin
  ItemStr := PadRight(Long2Str(Item), ' ', 4) + Copy(Config^.GetFileAreaName(Item), 1, 19);
  End;

Procedure DoCfgFArea;
  Begin
  RunList('File Areas', 300, 34, ItemStr, DoCfgFile);
  End;


End.
