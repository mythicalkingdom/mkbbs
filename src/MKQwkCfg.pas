{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKQwkCfg;

{$I MKB.Def}

{
     MKQwkCfg - configuration of the offline mail door (config.mko), Free Vision, converted from MKQWKCFG.PAS.
     Run it in the directory of config.mko (or where the PATH finds it) with MK (or RA, QUICK, SBBS) set to the BBS
     configuration directory as for mk.  A new config.mko is made with defaults for this machine (zip, sz ... found in
     the PATH).  The conference settings (confs.mko) and the user records (users.mko) are in the "common path".
}

Uses
  Objects, Drivers, Views, Menus, App, MsgBox,
  MKString, MKCfgAbs, MKGlobT, MKQwkG, CfgQwk, CfgPal, MKKbd;

Const
  cmMain = 1000;
  cmConfs = 1001;
  cmDefaults = 1002;
  cmUsers = 1003;
  cmProts = 1004;
  cmPackers = 1005;
  cmScreens = 1006;
  cmQuitCfg = 1007;
  cmQuitDlg = 2000;

Type
  QApp = Object(TApplication)
    Chosen: Word;
    Constructor Init;
    Procedure InitMenuBar; Virtual;
    Procedure InitStatusLine; Virtual;
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    Procedure AskQuit;
    End;


Constructor QApp.Init;
  Begin
  Inherited Init;
  Chosen := 0;
  End;


Procedure QApp.InitMenuBar;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~M~KQwkCfg', hcNoContext, NewMenu(
      NewItem('~M~ain Configuration', '', kbNoKey, cmMain, hcNoContext,
      NewItem('~C~onference Settings', '', kbNoKey, cmConfs, hcNoContext,
      NewItem('~D~efault User Settings', '', kbNoKey, cmDefaults, hcNoContext,
      NewItem('~U~ser Editor', '', kbNoKey, cmUsers, hcNoContext,
      NewItem('~P~rotocols', '', kbNoKey, cmProts, hcNoContext,
      NewItem('Archive Pac~k~ers', '', kbNoKey, cmPackers, hcNoContext,
      NewItem('~S~creens', '', kbNoKey, cmScreens, hcNoContext,
      NewItem('~Q~uit', '', kbNoKey, cmQuitCfg, hcNoContext,
      Nil))))))))),
    Nil))));
  End;


Procedure QApp.InitStatusLine;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~Alt-M~ Menu', kbAltM, cmMenu,
      NewStatusKey('', kbF10, cmMenu,
      NewStatusKey('~Alt-X~ Quit', kbAltX, cmQuitDlg, Nil))),
    Nil)));
  End;


Procedure QApp.AskQuit;
  Begin
  Case MessageBox('Save the changes to config.mko?', Nil, mfConfirmation + mfYesNoCancel) Of
    cmYes: Begin Chosen := 1; EndModal(cmQuit); End;
    cmNo: Begin Chosen := 2; EndModal(cmQuit); End;
    End;
  End;


Procedure QApp.HandleEvent(Var Event: TEvent);
  Begin
  Inherited HandleEvent(Event);
  If Event.What = evCommand Then
    Begin
    Case Event.Command Of
      cmQuitDlg, cmQuitCfg: AskQuit;
      cmMain: EditQMain;
      cmConfs: PickBBSArea;
      cmDefaults: EditQDef;
      cmUsers: EditQUser;
      cmProts: PickProt;
      cmPackers: PickPackers;
      cmScreens: EditQScrns;
      Else Exit;
      End;
    ClearEvent(Event);
    End;
  End;


Var
  A: QApp;
  Loaded: Boolean;

Begin
WriteLn('MKQwkCfg - Offline Mail Door Configuration');
LoadBbsCfg;
If Config = Nil Then
  Begin
  WriteLn(StdErr, 'No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory');
  Halt(1);
  End;
QwkSetDefaults;
Loaded := LoadQwkCfg;
If Not Loaded Then
  WriteLn('No config.mko found: it is made with defaults')
Else
  QwkFixPaths;
InstallKeyboard;
MaroonOn;
A.Init;
A.Run;
A.Done;
MaroonOff;                             {after the video is closed: the screen is given back}
If A.Chosen = 1 Then
  Begin
  If SaveQwkCfg Then
    WriteLn('config.mko saved')
  Else
    WriteLn('Error saving config.mko');
  End
Else
  WriteLn('Changes not saved');
End.
