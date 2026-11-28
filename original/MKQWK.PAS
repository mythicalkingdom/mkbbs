Program MKQwk;
{$M 32768,0,655360}

{$I MKB.Def}

{$IFNDEF DPMI}
  {$DEFINE USEOVERLAY}
{$ENDIF}

Uses
  {$IFDEF USEOVERLAY}
  Overlay, OvrXms,
  {$ENDIF}
  {$IFDEF OPRO}
  OpCrt,
  {$ELSE}
  Crt,
  {$ENDIF}
  MKQwkO, MKFile, MKString, MKOpen, MKQwkG, ExecAcc, ExecSwap;


{$IFDEF USEOVERLAY}
{.$O MKCfgAbs}
{$O MKRCfgMK}
{$O MKRCfgRA}
{$O MKRCfgR2}
{$O MKCfgQB}
{$O MKCfgSB}
{$O MKRCfgEz}
{$O MKMsgSqu}
{$O MKMsgHud}
{$O MKMsgEzy}
{$O MKMsgFid}
{$O MKMsgJam}
{$O MKMsgMer}
{.$O MKUsrAbs}
{.$O MKUsrMK}
{.$O MKOffAbs}
{$O MKOffTxt}
{$O MKOffQwk}
{$O MKOffBwv}
{.$O MKOffXrs}
{.$O MKComAbs}
{.$O MKComDir}
{.$O MKString}
{.$O MKFile}
{$ENDIF}


{$IFDEF USEOVERLAY}
Procedure LoadOverlay;
  Begin
  OvrFileMode := 64;
  OvrInit('MKQWK.OVR');
  If OvrResult <> 0 Then
    Begin
    WriteLn(OvrResult, ' Error loading MKQwk.Ovr');
    Halt(1);
    End;
  OvrSetBuf(32000);
  OvrInitXms;
  If OvrResult <> 0 Then
    Begin
    OvrInitEMS;
    If ((OvrResult < 0) and (OvrResult > -5)) Then
      Begin
      WriteLn(OvrResult, ' Error loading MKQwk.Ovr' );
      Halt(1);
      End;
    End;
  End;
{$ENDIF}


Begin
{$IFDEF USEOVERLAY}
LoadOverlay;
{$ENDIF}
Ta := TextAttr;
WriteLn;
WriteLn('MKQwk Offline Maildoor - version 1.10');
WriteLn('  Copyright 1994 by Mark May - Mythical Kingdom Software');
WriteLn;
TextAttr := LightCyan;
ProcessCmdLine;
ExecAcc.NWInitExecSwap := ExecSwap.InitExecSwap; {To maximize swap space}
ExecAcc.NWShutDownExecSwap := ExecSwap.ShutDownExecSwap;
ExecAcc.ExecWithSwap := ExecSwap.ExecWithSwap;
ExecAcc.NWUseEMSSwap := ExecSwap.NWUseEMSSwap;
GetDir(0, OrigDir);                    {get current director}
If LoadQwkCfg Then
  Begin
  MainQwk;
  End
Else
  WriteLn('Unable to load Config.MKO');
TextAttr := Ta;
End.
