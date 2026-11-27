{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgPSys;   {EchoMail Systems list, converted from CFGPSYS}

{$I MKB.Def}

Interface

Procedure DoCfgPSys;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgList, CfgESys;

Function ItemStr(Item: Word): String;
  Var
    Addr: AddrType;

  Begin
  Config^.GetEchoToAddr(Item, Addr);
  ItemStr := PadRight(Long2Str(Item), ' ', 3) + AddrStr(Addr);
  End;

Procedure DoCfgPSys;
  Begin
  RunList('EchoMail Systems', 32, 36, ItemStr, DoCfgESys);
  End;


End.
