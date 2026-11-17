Program MKConfig;

{$I MKB.Def}

{
     Configuration editor for the MK BBS (Free Vision, text mode).
     Set MK (or RA, QUICK, SBBS) to the BBS configuration directory as for mk.
}

Uses
  MKString, MKCfgAbs, MKCfgMK, MKCfgNew, MKCfgSB, MKCfgQB, MKCfgRA, MKGlobT,
  Default, CfgMenu, MKKbd;

Var
  Choice: Word;
  BbsType: Word;

Begin
BbsType := DetectBbsType;
Case BbsType Of
  1: Config := NewMKConfig(False);
  2: Config := New(RACfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
If Config = Nil Then
  Begin
  WriteLn(StdErr, 'No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory');
  Halt(1);
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
InstallKeyboard;                        {Esc and the Ctrl keys work}
Choice := DoMenu;
Case Choice Of
  1: Begin
     WriteLn('Saving changes');
     Config^.Save;
     End;
  2: WriteLn('Changes not saved');
  End;
Dispose(Config, Done);
End.
