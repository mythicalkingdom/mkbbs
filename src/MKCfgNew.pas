Unit MKCfgNew;   {Which object holds the MK configuration: the JSON file (MKJSON is set) or the .mk files}

{$I MKB.Def}

Interface

Uses MKCfgAbs;

Type CfgObjPtr = ^CfgObj;

Function NewMKConfig(ReadOnly: Boolean): CfgObjPtr;
  {The configuration object of an MK BBS.  MKJSON set: MKJsonCfgObj (MKCfgJs, bbsconfig.json).  Else the record files:
   MKRCfgObj (ReadOnly: the programs that only read the configuration) or MKCfgObj (the ones that change it).}

Implementation

Uses MKCfgMK, MKRCfgMK, MKCfgJs;


Function NewMKConfig(ReadOnly: Boolean): CfgObjPtr;
  Begin
  If JsonConfigWanted Then
    NewMKConfig := New(MKJsonCfgObjPtr, Init)
  Else If ReadOnly Then
    NewMKConfig := New(MKRCfgObjPtr, Init)
  Else
    NewMKConfig := New(MKCfgObjPtr, Init);
  End;


End.
