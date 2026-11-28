Unit MKNetGl;

{$I MKB.Def}

Interface

Uses MKMsgAbs;

{$I MKNET.INC}

Var
  HostCfg: ^HostCfgType;
  HostName: String[8];
  HostFName: String[128];
  Msg: AbsMsgPtr;

Procedure InitHost;                    {Initialize Host Cfg and allocate}
Function  LoadHost: Boolean;           {Load Host Cfg from file}
Procedure ReleaseHost;                 {Deallocate host cfg}
Function  SaveHost: Boolean;           {Save Host Cfg to file}


Implementation

Uses MKString, MKFile, MKOpen;

Function LoadHost: Boolean; {Load Host Config File}
  Var
    LoadError: Boolean;

  Begin
  FillChar(HostCfg^, SizeOf(HostCfg^), #0);
  LoadError := Not(FindOnPath(HostName + '.Cfg', HostFName));
  If IoResult <> 0 Then;
  If Not LoadError Then
    Begin
    LoadError := (LoadFile(HostFName, HostCfg^, SizeOf(HostCfg^)) <> 0);
    End;
  LoadHost := Not(LoadError);
  End;


Function SaveHost: Boolean; {Save Host Config File}
  Begin
  If IoResult <> 0 Then;
  SaveHost := (SaveFile(HostFName, HostCfg^, SizeOf(HostCfg^)) = 0);
  End;


Procedure SetDefaults; {Set default values}
  Var
    i: Word;

  Begin
  FillChar(HostCfg^, SizeOf(HostCfg^), #0);
  HostCfg^.ComprType := 'Z';
  HostCfg^.GateWay := False;
  For i := 1 To MaxNetAreas Do
    Begin
    HostCfg^.Areas[i].QwkNum := -1;
    HostCfg^.Areas[i].BbsNum := 0;
    HostCfg^.Areas[i].LastRead := 0;
    End;
  End;


Procedure InitHost;
  Begin
  New(HostCfg);
  SetDefaults;
  End;


Procedure ReleaseHost;
  Begin
  Dispose(HostCfg);
  End;


End.
