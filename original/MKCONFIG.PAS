Program MKConfig;

Uses
{$IFNDEF DPMI}
  Overlay,
{$ENDIF}
  OpCrt, OpColor, CfgMenu, CfgGlob, Default, MKString,
  MKCfgAbs, MKCfgMK, MKCfgSB, MKCfgQB, MKCfgRA, MKGlobT, CfgYN;

{$IFNDEF DPMI}
{$O MKCfgMK}
{$O MKCfgRA}
{$O MKCfgQB}
{$O MKCfgSB}
{$O CfgPath}
{$O CfgResp}
{$O CfgFile}
{$O CfgXfer}
{$O CfgMsg}
{$O CfgEvent}
{$O CfgESys}
{$O Default}
{$O CfgMenu}
{$ENDIF}

Var
  Ta: Byte;
  OS: Word;
  BBSType: Word;

Begin
{$IFNDEF DPMI}
OvrFileMode := 64; {readonly + denynone}
OvrInit('MKCONFIG.OVR');
If OvrResult <> 0 Then
  Begin
  WriteLn(Long2Str(OvrResult) + ' Error loading MKCONFIG.OVR');
  Halt(1);
  End;
OvrSetBuf(80000);
{$ENDIF}
OS := 0;
BbsType := DetectBbsType;
Case BbsType Of
  1: Config := New(MKCfgObjPtr, Init);
  2: Config := New(RACfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
Config^.Load;
If Config^.GetError <> 0 Then
  Begin
  WriteLn('Please wait while default values are set');
  Config^.Allocate;
  SetCfgDefaults(Config^);
  SetMsgDefaults(Config^);
  SetFileDefaults(Config^);
  SetEchoDefaults(Config^);
  End;
Ta := TextAttr;
While OS = 0 Do
  Begin
  DoMenu;
  OS := DoYesNo('[ Save Changes ]', True);
  End;
TextAttr := Ta;
ClrScr;
Case OS of
  1: Begin
     WriteLn('Saving changes');
     Config^.Save;
     End;
  2: WriteLn('Changes not saved');
  End;
Dispose(Config, Done);
End.
