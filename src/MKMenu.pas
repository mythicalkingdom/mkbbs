Program MKMenu;

{$I MKB.Def}

{
     Menu editor for the MK BBS (Free Vision, text mode): edits the *.MNU files.

        mkmenu [menufile]        MK (or RA, QUICK, SBBS) names the BBS config directory

     Without a file name the *.MNU files of the BBS are listed to choose from;
     a name without a path is looked for in the menu directory.  Converted from
     the Object Professional MKMENU.

        Enter        edit the item         Ins / Alt-V   insert a line
        Del / Alt-Y  delete the line       Alt-P         menu prompt and colours
        Alt-L        load a menu file      Alt-S         save the menu file
        Alt-Z        clear (new menu)      F1 / Alt-H    help
        Esc / Alt-X  leave (asks to save)

     The DOS shell (Alt-J) and the mouse fast-action menu of the old version are
     gone; the menu bar has everything.
}

Uses
  Objects, Drivers, Views, Menus, Dialogs, App, Dos,
  MKString, MKFile, MKGlobT, MKMenuCf, CfgBox, CfgList, CfgPal, MKKbd;


Const
  cmEditItem = 3100;
  cmInsertLine = 3101;
  cmDeleteLine = 3102;
  cmLoadMenu = 3103;
  cmSaveMenu = 3104;
  cmClearMenu = 3105;
  cmHeaderEd = 3106;
  cmKeysHelp = 3107;
  cmExitEd = 3108;


{------------------------------------------------ the list of items}

Type
  PItemView = ^ItemView;
  ItemView = Object(TListViewer)
    Constructor Init(Var R: TRect; AScroll: PScrollBar);
    Function  GetText(Item: LongInt; MaxLen: LongInt): String; Virtual;
    Procedure SelectItem(Item: LongInt); Virtual;
    End;

  PMenuWin = ^MenuWin;
  MenuWin = Object(TDialog)              {a dialog: its palette has the colours a list needs (a plain
                                          window's has not: the list came out in blinking error colours)}
    Procedure ShowName;
    End;


Constructor ItemView.Init(Var R: TRect; AScroll: PScrollBar);
  Begin
  Inherited Init(R, 1, Nil, AScroll);
  SetRange(MaxMenuItems);
  End;


Function ItemView.GetText(Item: LongInt; MaxLen: LongInt): String;
  Begin
  GetText := Copy(ItemStr(Item + 1), 1, MaxLen);
  End;


Procedure ItemView.SelectItem(Item: LongInt);
  Begin
  Message(Application, evCommand, cmEditItem, @Self);
  End;


Procedure MenuWin.ShowName;
  Begin
  If Title <> Nil Then
    DisposeStr(Title);
  Title := NewStr('[ ' + CurrFile + ' ]');
  If Frame <> Nil Then
    Frame^.DrawView;
  End;


{------------------------------------------------ the application}

Type
  MenuApp = Object(TApplication)
    Win: PMenuWin;
    List: PItemView;
    Constructor Init;
    Procedure InitMenuBar; Virtual;
    Procedure InitStatusLine; Virtual;
    Procedure HandleEvent(Var Event: TEvent); Virtual;
    Procedure StartFile;
    Procedure DoCommand(Cmd: Word);
    Function  SaveChanges: Boolean;      {False = the sysop wants to stay}
    Procedure LoadFile;
    Function  SaveMenuFile: Boolean;
    Procedure Redraw;
    End;


Constructor MenuApp.Init;
  Var
    R: TRect;
    SB: PScrollBar;

  Begin
  Inherited Init;
  DeskTop^.GetExtent(R);
  R.Grow(-3, 0);
  New(Win, Init(R, ''));
  Win^.Flags := wfMove;
  Win^.GetExtent(R);
  R.Grow(-1, -1);
  Dec(R.B.X);
  SB := Win^.StandardScrollBar(sbVertical Or sbHandleKeyboard);
  New(List, Init(R, SB));
  Win^.Insert(List);
  DeskTop^.Insert(Win);
  Win^.ShowName;
  End;


Procedure MenuApp.InitMenuBar;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~F~ile', hcNoContext, NewMenu(
      NewItem('~L~oad menu', 'Alt-L', kbNoKey, cmLoadMenu, hcNoContext,
      NewItem('~S~ave menu', 'Alt-S', kbNoKey, cmSaveMenu, hcNoContext,
      NewItem('~C~lear (new menu)', 'Alt-Z', kbNoKey, cmClearMenu, hcNoContext,
      NewLine(
      NewItem('E~x~it', 'Alt-X', kbNoKey, cmExitEd, hcNoContext,
      Nil)))))),
    NewSubMenu('~E~dit', hcNoContext, NewMenu(
      NewItem('~E~dit item', 'Enter', kbNoKey, cmEditItem, hcNoContext,
      NewItem('~I~nsert line', 'Ins', kbNoKey, cmInsertLine, hcNoContext,
      NewItem('~D~elete line', 'Del', kbNoKey, cmDeleteLine, hcNoContext,
      NewLine(
      NewItem('Menu ~p~rompt and colors', 'Alt-P', kbNoKey, cmHeaderEd, hcNoContext,
      Nil)))))),
    NewSubMenu('~H~elp', hcNoContext, NewMenu(
      NewItem('~K~eys', 'F1', kbNoKey, cmKeysHelp, hcNoContext,
      Nil)),
    Nil))))));
  End;


Procedure MenuApp.InitStatusLine;
  Var
    R: TRect;

  Begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F1~ Help', kbNoKey, cmKeysHelp,
      NewStatusKey('~Enter~ Edit', kbNoKey, cmEditItem,
      NewStatusKey('~Ins~ Insert', kbNoKey, cmInsertLine,
      NewStatusKey('~Del~ Delete', kbNoKey, cmDeleteLine,
      NewStatusKey('~Alt-S~ Save', kbNoKey, cmSaveMenu,
      NewStatusKey('~Alt-X~ Exit', kbNoKey, cmExitEd, Nil)))))),
    Nil)));
  End;


Procedure MenuApp.Redraw;
  Begin
  Win^.ShowName;
  List^.DrawView;
  End;


Function MenuApp.SaveMenuFile: Boolean;
  {Asks for the name, saves.  False when it was not saved.}
  Var
    TmpStr: String;
    Dest: String;

  Begin
  SaveMenuFile := False;
  TmpStr := CurrFile;
  If IsWild(TmpStr) Then
    TmpStr := MenuDir(TmpStr);
  If Not AskFileName('FileName: ', TmpStr) Then
    Exit;
  TmpStr := StripBoth(TmpStr, ' ');
  If TmpStr = '' Then
    Exit;
  If Not HasExt(TmpStr) Then
    TmpStr := TmpStr + '.mnu';
  If Pos('/', TmpStr) = 0 Then
    TmpStr := MenuDir(CurrFile) + TmpStr;  {no directory: next to the file being edited}
  Dest := TmpStr;
  If FileExist(Dest) And (ResolveCase(Dest) <> ResolveCase(CurrFile)) Then
    If DoYesNo('[ Overwrite File ]', True) <> 1 Then
      Exit;
  If MenuSave(Dest) Then
    Begin
    CurrFile := ResolveCase(Dest);
    SaveMenuFile := True;
    Redraw;
    End
  Else
    MsgBox('Error saving ' + Dest);
  End;


Function MenuApp.SaveChanges: Boolean;
  Begin
  SaveChanges := True;
  If Modified Then
    Case DoYesNo('[ Save Changes ]', True) Of
      1: If Not SaveMenuFile Then
           SaveChanges := False;
      0: SaveChanges := False;
      End;
  End;


Procedure MenuApp.LoadFile;
  Var
    TmpName: String;

  Begin
  If Not SaveChanges Then
    Exit;
  TmpName := MenuDir(CurrFile) + '*.MNU';
  If AskFileName('FileName: ', TmpName) Then
    Begin
    TmpName := StripBoth(TmpName, ' ');
    If (Pos('/', TmpName) = 0) And (Not IsWild(TmpName)) Then
      TmpName := MenuDir(CurrFile) + TmpName;
    If IsWild(TmpName) Then
      Begin
      If Not PickMenuFile(TmpName, TmpName) Then
        TmpName := '';
      End;
    If TmpName <> '' Then
      Begin
      If FileExist(TmpName) Then
        Begin
        CurrFile := ResolveCase(TmpName);
        If Not MenuLoad(CurrFile) Then
          MsgBox('Error reading ' + CurrFile);
        End
      Else
        MsgBox('File not found: ' + TmpName);
      End;
    End;
  Redraw;
  End;


Procedure MenuApp.StartFile;
  {The file named on the command line, or a list of the menus to choose from}
  Var
    TmpStr: String;

  Begin
  If ParamCount > 0 Then
    Begin
    CurrFile := ParamStr(1);
    If Not HasExt(CurrFile) Then
      CurrFile := CurrFile + '.mnu';
    If FileExist(CurrFile) Then
      CurrFile := ResolveCase(FExpand(CurrFile))
    Else If Pos('/', CurrFile) = 0 Then
      CurrFile := MenuPath + CurrFile;
    End
  Else
    Begin
    TmpStr := MenuPath + '*.MNU';
    If Not PickMenuFile(TmpStr, CurrFile) Then
      CurrFile := MenuPath + 'new.mnu';      {nothing chosen: a new menu}
    End;
  If FileExist(CurrFile) Then
    Begin
    If Not MenuLoad(CurrFile) Then
      MsgBox('Error reading ' + CurrFile);
    End
  Else
    Begin
    FillChar(MA, SizeOf(MA), 0);
    Modified := False;
    End;
  Redraw;
  End;


Procedure MenuApp.DoCommand(Cmd: Word);
  Var
    i, Cur: Word;

  Begin
  Cur := List^.Focused + 1;
  Case Cmd Of
    cmEditItem:
      Begin
      EditMenuItem(Cur);
      List^.DrawView;
      End;
    cmInsertLine:
      Begin
      i := MaxMenuItems;
      While i > Cur Do
        Begin
        MA[i] := MA[i - 1];
        Dec(i);
        End;
      FillChar(MA[Cur], SizeOf(MA[Cur]), 0);
      Modified := True;
      List^.DrawView;
      End;
    cmDeleteLine:
      Begin
      For i := Cur To MaxMenuItems - 1 Do
        MA[i] := MA[i + 1];
      FillChar(MA[MaxMenuItems], SizeOf(MA[MaxMenuItems]), 0);
      Modified := True;
      List^.DrawView;
      End;
    cmLoadMenu: LoadFile;
    cmSaveMenu: If SaveMenuFile Then;
    cmClearMenu:
      Begin
      If SaveChanges Then
        Begin
        FillChar(MA, SizeOf(MA), 0);
        CurrFile := MenuPath + '*.MNU';
        Modified := False;
        Redraw;
        End;
      End;
    cmHeaderEd:
      Begin
      EditMenuHeader;
      List^.DrawView;
      End;
    cmKeysHelp:
      ShowText('Command Keys for MKMenu',
        'Enter         Edit the item' + #13 +
        'Ins / Alt-V   Insert a line' + #13 +
        'Del / Alt-Y   Delete the line' + #13 +
        'Alt-P         Edit the menu prompt and its colors' + #13 +
        'Alt-L         Load a menu file' + #13 +
        'Alt-S         Save the menu file' + #13 +
        'Alt-Z         Clear the menu (a new one)' + #13 +
        'Alt-X / Esc   Leave' + #13 +
        'F1 / Alt-H    This help' + #13 +
        'In the item:  F2 or Space chooses the command and the color');
    cmExitEd:
      If SaveChanges Then
        Message(@Self, evCommand, cmQuit, Nil);
    End;
  End;


Procedure MenuApp.HandleEvent(Var Event: TEvent);
  Var
    Cmd: Word;

  Begin
  Cmd := 0;
  If Event.What = evKeyDown Then
    Begin
    Case Event.KeyCode Of
      kbEnter: Cmd := cmEditItem;
      kbIns, kbAltV: Cmd := cmInsertLine;
      kbDel, kbAltY: Cmd := cmDeleteLine;
      kbAltL: Cmd := cmLoadMenu;
      kbAltS: Cmd := cmSaveMenu;
      kbAltZ: Cmd := cmClearMenu;
      kbAltP: Cmd := cmHeaderEd;
      kbF1, kbAltH: Cmd := cmKeysHelp;
      kbAltX, kbEsc: Cmd := cmExitEd;
      End;
    If Cmd <> 0 Then
      Begin
      ClearEvent(Event);
      DoCommand(Cmd);
      Exit;
      End;
    End;
  Inherited HandleEvent(Event);
  If Event.What = evCommand Then
    Begin
    If (Event.Command >= cmEditItem) And (Event.Command <= cmExitEd) Then
      Begin
      Cmd := Event.Command;
      ClearEvent(Event);
      DoCommand(Cmd);
      End;
    End;
  End;


Var
  A: MenuApp;

Begin
InitMenuEditor;
Modified := False;
InstallKeyboard;                       {Esc and the Ctrl keys work}
MaroonOn;
A.Init;
A.StartFile;
A.Run;
A.Done;
MaroonOff;
DoneMenuEditor;
End.
