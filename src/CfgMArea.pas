Unit CfgMArea;   {Message areas list, converted from CFGMAREA}

{$I MKB.Def}

Interface

Procedure DoCfgMArea;

Implementation

Uses MKString, MKCfgAbs, CfgList, CfgMsg;

Function ItemStr(Item: Word): String;
  Begin
  ItemStr := PadRight(Long2Str(Item), ' ', 4) + Copy(Config^.GetMsgName(Item), 1, 19);
  End;


Procedure DoCfgMArea;
  Begin
  RunList('Message Areas', 500, 34, ItemStr, DoCfgMsg);
  End;


End.
