Program MKMenu;
{$I MKB.Def}

Uses Overlay, MKMenuO, MKFile, MKString, Dos, OpCRT, MKAvatar, CfgYN, OPWindow,
  OPColor,OpCmd, MKColor, MKGlobT, MKMenuCF, OPPick,
  OPFrame, MKRCfgMK, MKCfgAbs, MKCfgRA, MKCfgSB, MKCfgQB, OpExec, OpMouse;

{$O MKRCfgMK}
{$O MKCfgRA}
{$O MKCFGSB}
{$O MKCfgQB}

Var
  CT: CursorType;
  TA: Byte;
  MenuPick: PickList;



Procedure NoHelp;
  Begin
  WriteLn(#13#13#13);
  WriteLn('No Help Available');
  End;


Procedure GeneralHelp;
  Begin
  WriteLn;
  WriteLn('                           Command Keys for MKMenu');
  WriteLn;
  WriteLn('   Alt-L         Load Menu');
  WriteLn('   Alt-S         Save Menu');
  WriteLn('   Alt-X {Esc}   Exit');
  WriteLn('   Alt-H {F1}    Help');
  WriteLn('   Alt-Z         Zap/Clear menu');
  WriteLn('   Alt-J         Jump to Dos');
  WriteLn('   {Ins}         Insert line');
  WriteLn('   {Del}         Delete line');
  WriteLn('   Alt-P         Edit menu prompt settings');
  WriteLn('   Mouse-Right   Fast Mouse Menu');
  Write;
  End;


Procedure DisplayHelp(HelpIndex : Word);
  Var
    HelpWin: StackWindowPtr;
    Ch: Char;

  Begin
  HideMouse;
  New(HelpWin, InitCustom(2,2,79,24, ESColors,
  wBordered + wClear + wSaveContents));
  If HelpWin <> nil Then
    Begin
    HelpWin^.wFrame.SetFrameType(Frame1);
    HelpWin^.Draw;
    SetCursorType(cuHidden);
    Case HelpIndex of
      1: GeneralHelp;
      Else
        NoHelp;
      End;
    Ch := Readkey;
    HelpWin^.Erase;
    Dispose(HelpWin, Done);
    SetCursorType(cuBlock);
    End;
  If MouseInstalled Then
    ShowMouse;
  End;




Function IsWild(St: String): Boolean;
  Begin
  IsWild := ((Pos('?',St) > 0) or (Pos('*',St) > 0));
  End;



Procedure GetLoadFile;
  Var
    TmpName: String;
    FStr: NameStr;
    EStr: ExtStr;

  Begin
  TmpName := CurrFile;
  FSplit(CurrFile, TmpName, FStr, EStr);
  TmpName := WithBackSlash(TmpName) + '*.MNU';
  If MKEditProc('FileName: ', True, True, 55, TmpName) Then
    Begin
    If IsWild(TmpName) Then
      TmpName := GetPickFileName(TmpName);
    If Length(TmpName) > 0 Then
      Begin
      If FileExist(TmpName) Then
        Begin
        CurrFile := TmpName;
        MenuLoad(CurrFile);
        Modified := False;
        End;
      End;
    End;
  End;


Procedure SaveMenuFile;
  Var
    DoSave: Boolean;
    LastItem: Word;
    TmpStr: String;
    F: File;

  Begin
  TmpStr := CurrFile;
  If MKEditProc('FileName: ', True, True, 55, TmpStr) Then
    Begin
    If Pos('.',TmpStr) = 0 Then
      TmpStr := TmpStr + '.MNU';
    If FileExist(TmpStr) Then
      DoSave := DoYesNo('[ Overwrite File ]', True) = 1
    Else
      DoSave := True;
    If DoSave Then
      Begin
      LastItem := 50;
      While ((LastItem > 0) and (MA[LastItem].Typ = 0)) Do
        Dec(LastItem);
      Assign(F, TmpStr);
      Erase(F);
      If IoResult <> 0 Then;
      If SaveFile(TmpStr, MA, (LastItem + 1) * SizeOf(MenuType)) <> 0 Then
        Write(#7, #7, #7)
      Else
        Modified := False;
      End;
    End;
  End;



{$F+}
Procedure PickMenuStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  If MA[Item].Typ <> 0 Then
    Begin
    If MA[Item].Key = #1 Then
      IString := ' þ '#186' '
    Else
      IString := ' ' + MA[Item].Key + ' '#186' ';
    IString := IString + Copy(PadRight(Prompts.GetString(MA[Item].Typ),' ',
      35),1,35) + ' '#186' ';
    IString := IString + Copy(MA[Item].Data, 1, 20);
    End
  Else
    IString := '   '#186' '+ PadRight('',' ', 35) + ' '#186;
  End;


Procedure InitMenuPick;
  Begin
  If Not MenuPick.InitDeluxe(10,4,70,21,ESColors,
    wBordered+wClear+wUserContents,
    60, MaxMenuItems, PickMenuStr, PickVertical, SingleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  MenuPick.pkOptionsOn(pkStick);
  MenuPick.wFrame.SetFrameType(Frame1);
  MenuPick.wFrame.AddHeaderColor('[ Menu Items ]', heTC, WhiteOnBlue, BlackOnLtGray);
  MenuPick.wFrame.AddHeaderColor('[ New File ]', heBC, WhiteOnBlue, BlackOnLtGray);
  MenuPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  MenuPick.wFrame.AddShadow(shBR, shSeeThru);
  MenuPick.SetInitialChoice(1);
  PickCommands.AddCommand(ccUser1,  1, $1f00, 0);   {Alt-S Save}
  PickCommands.AddCommand(ccUser7,  1, $2d00, 0);   {Alt-X Exit}
  PickCommands.AddCommand(ccUser4,  1, $2600, 0);   {Alt-L Load file}
  PickCommands.AddCommand(ccUser5,  1, $2c00, 0);   {Alt-Z Zap/Clear area}
  PickCommands.AddCommand(ccUser10, 1, $2400, 0);   {Alt-J Jump to Dos}
  PickCommands.AddCommand(ccUser2,  1, $5300, 0);   {Del}
  PickCommands.AddCommand(ccUser3,  1, $5200, 0);   {Ins}
  PickCommands.AddCommand(ccUser6,  1, $3b00, 0);   {F1 Help}
  PickCommands.AddCommand(ccUser6,  1, $2300, 0);   {Alt-H Help}
  PickCommands.AddCommand(ccUser9,  1, $1900, 0);   {Alt-P Menu prompts}
  PickCommands.AddCommand(ccUser8,  1, MouseRt, 0); {Fast Action Menu}
  PickCommands.AddCommand(ccUser3,  1, $2f00, 0);   {Alt-V insert line}
  PickCommands.AddCommand(ccUser2,  1, $1500, 0);   {Alt-Y delete line}
  End;


Procedure DoMenuCommand(Cmd: Word; Var Finished: Boolean);
  Var
    i: Word;
    Last: Word;
    P: Pointer;

  Begin
  Case Cmd of
    ccSelect: EditMenu(MenuPick.GetLastChoice);
    ccUser1:
      Begin
      SaveMenuFile;
      MenuPick.Select;
      End;
    ccUser2: {Delete}
      Begin
      If MenuPick.GetLastChoice > 0 Then
        Begin
        For i := MenuPick.GetLastChoice to 49 Do
          MA[i] := MA[i + 1];
        FillChar(MA[50], SizeOf(MA[50]), 0);
        Modified := True;
        End;
      MenuPick.Select;
      MenuPick.Draw;
      End;
    ccUser3: {Insert}
      Begin
      Last := MenuPick.GetLastChoice;
      If Last > 0 Then
        Begin
        i := 50;
        While i > Last Do
          Begin
          MA[i] := MA[i - 1];
          Dec(i);
          End;
        FillChar(MA[Last], SizeOf(MA[Last]), 0);
        Modified := True;
        End;
      MenuPick.Select;
      MenuPick.Draw;
      End;
    ccUser4:
      Begin
      If Modified Then
        Begin
        If DoYesNo('[ Save Changes ]', True) = 1 Then
          SaveMenuFile;
        End;
      GetLoadFile;  {Load File}
      MenuPick.ChangeHeader(1, '[ ' + CurrFile + ' ]');
      MenuPick.Select;
      End;
    ccUser5:
      Begin
      If Modified Then
        Begin
        If DoYesNo('[ Save Changes ]', True) = 1 Then
          SaveMenuFile;
        End;
      FillChar(MA, SizeOf(MA), 0);
      CurrFile := MenuPath + '*.Mnu';
      MenuPick.ChangeHeader(1, '[ ' + CurrFile + ' ]');
      MenuPick.Select;
      End;
    ccUser6:
      Begin
      DisplayHelp(1);
      MenuPick.Select;
      End;
    ccUser8:
      Begin
      i := GetMenuCmd;
      If i <> ccNone Then
        DoMenuCommand(i, Finished);
      End;
    ccUser9:
      Begin
      EditHdr;
      MenuPick.Select;
      End;
    ccUser10:
      Begin
      If SaveWindow(1,1, ScreenWidth, ScreenHeight, True, P) Then
        Begin
        HideMouse;
        Window(1,1,ScreenWidth, ScreenHeight);
        ClrScr;
        SetCursorType(CT);
        DisableEventHandling;
        If ExecDosSwap('', True, nil, 'MKMenu.$$$') <> 0 Then
          Write(#7);
        SetCursorType(cuBlock);
        EnableEventHandling;
        RestoreWindow(1,1, ScreenWidth, ScreenHeight, True, P);
        If MouseInstalled Then
          ShowMouse;
        End;
      End;
    Else
      Begin
      Finished := True;
      If Modified Then
        Begin
        If DoYesNo('[ Save Changes ]', True) = 1 Then
          SaveMenuFile;
        End;
      End;
    End;
  End;


Procedure MenuProcess;
  Var
    Finished: Boolean;

  Begin
  Finished := False;
  MenuPick.ChangeHeader(1, '[ ' + CurrFile + ' ]');
  While Not Finished Do
    Begin
    MenuPick.Process;
    DoMenuCommand(MenuPick.GetLastCommand, Finished);
    End;
  MenuPick.Erase;
  MenuPick.Done;
  End;




Begin
Modified := False;
TA := TextAttr;
DetectMultitasking := True;
ReInitCrt;
CT := ClassifyCursorType;
If Not ((CT = cuNormal) or (CT = cuFat) or (CT = cuBlock)) Then
  CT := cuNormal;
SetCursorType(cuBlock);
TextChar := #176;
TextAttr := LtGrayOnBlack;
ClrScr;
Initialize;
If ParamCount > 0 Then
  Begin
  CurrFile := Upper(ParamStr(1));
  If Pos('.',CurrFile) = 0 Then
    CurrFile := CurrFile + '.MNU';
  If FileExist(CurrFile) Then
    CurrFile := Upper(FExpand(ParamStr(1)))
  Else
    CurrFile := MenuPath + CurrFile;
  End
Else
  Begin
  CurrFile := MenuPath + '*.MNU';
  End;
If IsWild(CurrFile) Then
  CurrFile := GetPickFileName(CurrFile);
MenuLoad(CurrFile);
InitMenuPick;
MenuProcess;
If MouseInstalled then
  with EsColors do begin
  SoftMouseCursor($0000, (ColorMono(MouseColor, MouseMono) shl 8)+
                  Byte(MouseChar));
  ShowMouse;
  End;
Prompts.Done;
Finish;
SetCursorType(CT);
HideMouse;
TextAttr := TA;
ClrScr;
End.
