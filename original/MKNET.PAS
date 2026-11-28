Program MKNet;

{$M 20000, 200000, 655360}

{$I MKB.Def}

{..$ DEFINE USEOVERLAY}

Uses
  {$IFDEF USEOVERLAY}
  Overlay,
  {$ENDIF}
  Extend, MKNetGl, MKFile, MKString, Dos, MKNetG, MKPack,
  {$IFDEF OPRO}
    OpCrt,
  {$ELSE}
    Crt,
  {$ENDIF}
  ExecAcc, ExecSwap;

{$IFDEF USEOVERLAY}
{$O MKMsgFid}
{$O MKMsgEzy}
{$O MKMsgHud}
{$O MKMsgSqu}
{$O MKMSGJam}
{$O MKPack}
{$ENDIF}


Var
  Ta: Byte;

Begin
{$IFDEF USEOVERLAY}
OvrFileMode := 64;
OvrInit('MKNET.OVR');
If OvrResult <> 0 Then
  Begin
  WriteLn(OvrResult, ' Error loading MKNET.OVR');
  Halt(1);
  End;
OvrSetBuf(32000);
OvrInitEMS;
If ((OvrResult < 0) and (OvrResult > -5)) Then
  Begin
  WriteLn(OvrResult, ' Error loading MKNET.OVR' );
  Halt(1);
  End;
{$ENDIF}
Ta := TextAttr;
WriteLn('MKNet - Copyright 1993-1994 by Mark May Mythical Kingdom Software');
ExecAcc.NWInitExecSwap := ExecSwap.InitExecSwap; {To maximize swap space}
ExecAcc.NWShutDownExecSwap := ExecSwap.ShutDownExecSwap;
ExecAcc.ExecWithSwap := ExecSwap.ExecWithSwap;
ExecAcc.NWUseEMSSwap := ExecSwap.NWUseEMSSwap;
GetDir(0, OrigDir);                    {get current director}
If ParamCount < 1 Then
  Begin
  WriteLn;
  WriteLn('Error: Must give host name on command line');
  WriteLn;
  WriteLn('Example: MKNet TRP');
  WriteLn;
  Halt(1);
  End;
DoBanner;                              {display ansi banner}
HostName := Upper(ParamStr(1));        {get hostname from command line}
InitHost;                              {initialize hostcfg record}
If Not LoadHost Then                   {load hostcfg record}
  Begin
  WriteLn;
  WriteLn('Error: Unable to load ', HostName , '.CFG');
  WriteLn;
  Halt(2);
  End;
AddBackSlash(HostCfg^.InQwkPath);      {ensure paths have trailing backslash}
AddBackSlash(HostCfg^.OutRepPath);
AddBackSlash(HostCfg^.WorkPath);
GetPackPaths(Packers);                 {find archivers paths}
PackObj.Init;
TempDir := CreateTempDir(HostCfg^.WorkPath); {create working directory}
If Length(TempDir) = 0 Then
  Begin
  WriteLn;
  WriteLn('Error: Unable to create temp/work directory');
  WriteLn;
  Halt(3);
  End;
AddBackSlash(TempDir);
If FileExist(HostCfg^.InQwkPath + HostName + '.QW?') Then  {Does QWK exist}
  Begin
  If FileExist(HostCfg^.OutRepPath + HostName + '.REP') Then  {If Rep exists delete it}
    If EraseFile(HostCfg^.OutRepPath + HostName + '.REP') Then;
  ExportRep;
  UnPackQwks;
  End
Else
  Begin
  If FileExist(HostCfg^.OutRepPath + HostName + '.REP') Then
    Begin
    StatusLine('Unpacking existing .REP');
    ChDir(StripTrail(TempDir,'\'));
    Result := UnPack(HostCfg^.OutRepPath + HostName + '.REP', '*.*');
    If Result <> 0 Then
      StatusLine('ErrorLevel ' + Long2Str(Result) + ' from Unpacker');
    End;
  ExportRep;
  End;
StatusLine('Packing REP file');
If FileExist(TempDir + HostName + '.MSG') Then
  PackRep;
StatusLine('Normal Completion');
If SaveHost Then;                      {Save updated lastreads}
ReleaseHost;                           {Deallocate HostCfg Record}
If IoResult <> 0 Then;
ChDir(StripTrail(TempDir, '\'));
If IoResult <> 0 Then;
ChDir('\');
If IoResult <> 0 Then;
ChDir(StripTrail(OrigDir, '\'));       {Return to original directory}
If IoResult <> 0 Then;
RmDir(StripTrail(TempDir, '\'));       {Remove working directory}
PackObj.Done;
Delay(1000);
Window(1,1,80,25);
TextAttr := Ta;
ClrScr;
End.
