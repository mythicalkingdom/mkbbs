Unit MKMenuCF;
{$I MKB.Def}

Interface

Uses MKStr, MKString, MKFile, OpCrt, MKCfgAbs, MKRCfgMK, MKRCfgRA,
  MKCfgQB, MKCfgSB, OpColor, MKGlobT, OpMenu;

Const
  MaxMenuItems = 50;


Type MenuArray = Array[0..MaxMenuItems] of MenuType;

Var
  BBSPath: String;
  MenuPath: String;
  Prompts: StrObj;
  BbsType: Word;
  CurrFile: String;
  NumItems: Word;
  MA: MenuArray;
  Modified: Boolean;
  CmdMenu: Menu;


const
  MouseChar: Char = #04;

const
  EsColors : ColorSet = (
    TextColor       : YellowOnBlue;       TextMono        : WhiteOnBlack;
    CtrlColor       : YellowOnBlue;       CtrlMono        : WhiteOnBlack;
    FrameColor      : WhiteOnBlue;        FrameMono       : LtGrayOnBlack;
    HeaderColor     : WhiteOnCyan;        HeaderMono      : BlackOnLtGray;
    ShadowColor     : DkGrayOnBlack;      ShadowMono      : WhiteOnBlack;
    HighlightColor  : WhiteOnRed;         HighlightMono   : BlackOnLtGray;
    PromptColor     : LtGrayOnBlue;       PromptMono      : LtGrayOnBlack;
    SelPromptColor  : LtGrayOnBlue;       SelPromptMono   : LtGrayOnBlack;
    ProPromptColor  : LtGrayOnBlue;       ProPromptMono   : LtGrayOnBlack;
    FieldColor      : YellowOnBlue;       FieldMono       : LtGrayOnBlack;
    SelFieldColor   : BlueOnCyan;         SelFieldMono    : WhiteOnBlack;
    ProFieldColor   : LtGrayOnBlue;       ProFieldMono    : LtGrayOnBlack;
    ScrollBarColor  : CyanOnBlue;         ScrollBarMono   : LtGrayOnBlack;
    SliderColor     : CyanOnBlue;         SliderMono      : WhiteOnBlack;
    HotSpotColor    : BlackOnCyan;        HotSpotMono     : BlackOnLtGray;
    BlockColor      : YellowOnCyan;       BlockMono       : WhiteOnBlack;
    MarkerColor     : WhiteOnCyan;        MarkerMono      : BlackOnLtGray;
    DelimColor      : YellowOnBlue;       DelimMono       : WhiteOnBlack;
    SelDelimColor   : BlueOnCyan;         SelDelimMono    : WhiteOnBlack;
    ProDelimColor   : YellowOnBlue;       ProDelimMono    : WhiteOnBlack;
    SelItemColor    : YellowOnCyan;       SelItemMono     : BlackOnLtGray;
    ProItemColor    : LtGrayOnBlue;       ProItemMono     : LtGrayOnBlack;
    HighItemColor   : WhiteOnBlue;        HighItemMono    : WhiteOnBlack;
    AltItemColor    : WhiteOnBlue;        AltItemMono     : WhiteOnBlack;
    AltSelItemColor : WhiteOnCyan;        AltSelItemMono  : BlackOnLtGray;
    FlexAHelpColor  : WhiteOnBlue;        FlexAHelpMono   : WhiteOnBlack;
    FlexBHelpColor  : WhiteOnBlue;        FlexBHelpMono   : WhiteOnBlack;
    FlexCHelpColor  : LtCyanOnBlue;       FlexCHelpMono   : BlackOnLtGray;
    UnselXrefColor  : YellowOnBlue;       UnselXrefMono   : LtBlueOnBlack;
    SelXrefColor    : WhiteOnCyan;        SelXrefMono     : BlackOnLtGray;
    MouseColor      : WhiteOnRed;         MouseMono       : BlackOnLtGray
  );


Const
  Frame1 = '…»ªºÕÕ∫∫';


Procedure Initialize;
Procedure Finish;
Procedure MenuLoad(FN: String);          {Load file name}
Procedure EditMenu(Item: Word);
Function  MKEditProc(Prompt: String; ForceUp, TrimBlanks: Boolean;
            MaxLen: Byte; Var S: String): Boolean;
Function  GetPickFileName(Var PPath: String): String;
Function  GetMenuCmd: Word;
Procedure GetCmdFromMenu(Var Item: Byte);
Procedure EditHdr;

Implementation


uses
  Dos,  OpInline,  OpString,  OpRoot,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow,
  OpSelect,  OpEntry, CfgGlob, MKColor, OpEdit, OPPick, OPDir,
  CfgYN;


Const
  MnuLoad = 1;
  MnuSave = MnuLoad + 1;
  MnuClear = MnuSave + 1;
  MnuIns = MnuClear + 1;
  MnuDel = MnuIns + 1;
  MnuHelp = MnuDel + 1;
  MnuHdr = MnuHelp + 1;
  MnuDos = MnuHdr + 1;
  MnuExit = MnuDos + 1;
  MaxMenuChoice = MnuExit;


{$F+}
Procedure PickMenuStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  Case Item of
    MnuHdr:   IString := '   Edit Header Info';
    MnuClear: IString := '   Clear Menu';
    MnuHelp:  IString := '   Help';
    MnuDos:   IString := '   Shell to Dos';
    MnuExit:  IString := '   Exit from MKMenu';
    MnuLoad:  IString := '   Load Menu file';
    MnuSave:  IString := '   Save Menu file';
    MnuIns:   IString := '   Insert a blank line';
    MnuDel:   IString := '   Delete current line';
    End;
  End;


Function MenuCode(Item: Word): Word;
  Begin
  Case Item of
    MnuIns:   MenuCode := ccUser3;
    MnuDel:   MenuCode := ccUser2;
    MnuClear: MenuCode := ccUser5;
    MnuHelp:  MenuCode := ccUser6;
    MnuDos:   MenuCode := ccUser10;
    MnuExit:  MenuCode := ccUser7;
    MnuLoad:  MenuCode := ccUser4;
    MnuSave:  MenuCode := ccUser1;
    MnuHdr:   MenuCode := ccUser9;
    Else
      MenuCode := ccNone;
    End;
  End;




{$F+}
Function MKEditProc(Prompt: String; ForceUp, TrimBlanks: Boolean;
  MaxLen: Byte; Var S: String): Boolean;

  Var
    LE: LineEditor;
    PromptWin: StackWindowPtr;


  Begin
  New(PromptWin, InitCustom(1,1,80,1, ESColors, wClear));
  PromptWin^.Draw;
  TextAttr := ESColors.TextColor;
  LE.Init(ESColors);
  If ForceUp Then
    LE.leEditOptionsOn(leForceUpper);
  If Not TrimBlanks Then
    LE.leEditOptionsOff(leTrimBlanks);
  LE.ReadString(Prompt, 1, 1, MaxLen, 60, S);
  MKEditProc := (LE.GetLastCommand <> ccQuit);
  LE.Done;
  PromptWin^.Erase;
  Dispose(PromptWin, Done);
  End;



Function GetPickFileName(Var PPath: String): String;
  Var
    Dir: DirList;
    Finished: Boolean;
    Tmp1: NameStr;
    Tmp2: ExtStr;

  Begin
  If Dir.InitCustom(3,6,77,23, esColors, DefWindowOptions or wBordered,
  MaxAvail, PickVertical, SingleFile) Then
    Begin
    If MouseInstalled Then
      ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    Dir.SetPosLimits(1,1, ScreenWidth, ScreenHeight -1);
    Dir.SetPadSize(1,1);
    Dir.diOptionsOn(diOptimizeSize);
    Dir.AddMaskHeader(True, 1, 30, heTC);
    Dir.SetSortOrder(SortName);
    Dir.SetNameFormat;
    Dir.SetMask(PPath, AnyFile);
    Dir.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
    Finished := False;
    ProcessBox('Finding Menu Files', '[ Please Wait ]');
    Dir.PreLoadDirList;
    EndProcessBox;
    Dir.Process;
    Case Dir.GetLastCommand of
      ccSelect: GetPickFileName := Dir.GetSelectedPath;
      Else
        GetPickFileName := '';
      End;
    Dir.Done;
    End
  Else
    Begin
    Write(#7, #7, #7);
    GetPickFileName := '';
    End;
  End;




{Entry field constants}
const
  idKey                  = 0;
  idTyp                  = idKey + 1;
  idTypeDesc             = idTyp + 1;
  idPrompt               = idTypeDesc + 1;
  idData                 = idPrompt + 1;
  idDataDesc             = idData + 1;
  idSecurity             = idDataDesc + 1;
  idColor                = idSecurity + 1;
  idFlagsA               = idColor + 1;
  idFlagsB               = idFlagsA + 1;
  idFlagsC               = idFlagsB + 1;
  idFlagsD               = idFlagsC + 1;

{Help index constants}
const
  hiKey                  = 1;
  hiTyp                  = hiKey + 1;
  hiTypeDesc             = hiTyp + 1;
  hiPrompt               = hiTypeDesc + 1;
  hiData                 = hiPrompt + 1;
  hiDataDesc             = hiData + 1;
  hiSecurity             = hiDataDesc + 1;
  hiColor                = hiSecurity + 1;
  hiFlagsA               = hiColor + 1;
  hiFlagsB               = hiFlagsA + 1;
  hiFlagsC               = hiFlagsB + 1;
  hiFlagsD               = hiFlagsC + 1;

type
  MenuEntRecord =
    record
      Key                  : String[3];
      Typ                  : Byte;
      TypeDesc             : string[40];
      Prompt               : string[75];
      Data                 : string[75];
      DataDesc             : string[60];
      Security             : Word;
      Color                : Byte;
      FlagsA               : string[8];
      FlagsB               : string[8];
      FlagsC               : string[8];
      FlagsD               : string[8];
    end;
var
  ES     : EntryScreen;
  UR     : MenuEntRecord;
  Status : Word;


Procedure HandleMenu(Var Typ: Byte; Var ESP: EntryScreenPtr);
  Var
    Temp: Word;

  Const
    Wait = 100;

  Begin
  Delay(Wait);
  ESP^.PositionCursorAt(ESP^.FindField(idTyp));
  HideMouse;
  Temp := ReadKeyWord;
    Case Temp of
    7181: Begin
          GetCmdFromMenu(Typ);
          ESP^.Select;
          ESP^.DrawField(idTyp);
          UR.TypeDesc := Prompts.GetString(UR.Typ);
          UR.DataDesc := Prompts.GetString(UR.Typ + 256);
          ESP^.DrawField(idTypeDesc);
          ESP^.DrawField(idDataDesc);
          ESP^.SetNextField(idPrompt);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;




{$F+}
procedure PreEdit(ESP : EntryScreenPtr);
  {-Called just before a field is edited}
begin
  with ESP^ do
    case GetCurrentID of
      idKey                  : ;
      idTyp: HandleMenu(UR.Typ, ESP);
      idColor: GetColor(UR.Color, ESP, idColor, '[ Prompt Color ]');
    end;
end;

procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idKey                  : ;
      idTyp:
        Begin
        UR.TypeDesc := Prompts.GetString(UR.Typ);
        UR.DataDesc := Prompts.GetString(UR.Typ + 256);
        ESP^.DrawField(idTypeDesc);
        ESP^.DrawField(idDataDesc);
        End;
    end;
end;

procedure IncChoice(var Value; ID : Word; Factor : Integer; var St : string);
  {-Increment a multiple choice field value and convert it to a string}
begin
end;

procedure ErrorHandler(UnitCode : Byte; var ErrCode : Word; Msg : string);
  {-Report errors}
begin
  RingBell;
end;

procedure DisplayHelp(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
  {-Display context sensitive help}
begin
end;
{$F-}

Type  ByteArray = Array[1..4] of Byte;


Function InitMenuEntryScreen : Word;
  Const
    WinOptions = wBordered+wClear+wUserContents;

  Begin
  UserSet1 := ['0','1'];
  with ES do begin
    if not InitCustom(3, 5, 76, 16, EsColors, WinOptions) then begin
      InitMenuEntryScreen := InitStatus;
      Exit;
    end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    SetWrapMode(WrapAtEdges);

    SetPreEditProc(PreEdit);
    SetPostEditProc(PostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);

  {idKey:}
    esFieldOptionsOff(efMapCtrls + efForceOverType);
    AddStringField(
      'Key:', 2, 4,
      '!', 2, 9,
      1, hiKey, UR.Key);
    esFieldOptionsOn(efMapCtrls + efForceOverType);

  {idTyp:}
  esFieldOptionsOn(efClearFirstChar);
    AddByteField(
      'Type:', 2, 15,
      '999', 2, 21,
      hiTyp, 0, 255, UR.Typ);
  esFieldOptionsOff(efClearFirstChar);

  esFieldOptionsOn(efProtected);
  {idTypeDesc:}
    AddStringField(
      '', 2, 30,
      CharStr('X', 40), 2, 30, 40,
      hiTypeDesc, UR.TypeDesc);
  esFieldOptionsOff(efProtected);

  {idPrompt:}
  esFieldOptionsOn(efClearFirstChar + efCursorToEnd);
    AddStringField(
      'Prompt:', 4, 4,
      CharStr('X', 75), 4, 12, 60,
      hiPrompt, UR.Prompt);
  esFieldOptionsOff(efClearFirstChar + efCursorToEnd);

  {idData:}
  esFieldOptionsOn(efClearFirstChar + efCursorToEnd);
    AddStringField(
      'Data:', 6, 4,
      CharStr('X', 75), 6, 10, 60,
      hiData, UR.Data);
  esFieldOptionsOff(efClearFirstChar + efCursorToEnd);

  {idDataDesc:}
  esFieldOptionsOn(efProtected);
    AddStringField(
      '', 7, 10,
      CharStr('X', 60), 7, 10, 60,
      hiDataDesc, UR.DataDesc);
  esFieldOptionsOff(efProtected);

  {idSecurity:}
  esFieldOptionsOn(efClearFirstChar + efCursorToEnd);
    AddWordField(
      'Security:', 9, 4,
      '99999', 9, 14,
      hiSecurity, 0, 65535, UR.Security);
  esFieldOptionsOff(efClearFirstChar + efCursorToEnd);

  {idColor:}
  esFieldOptionsOn(efClearFirstChar);
    AddByteField(
      'Color:', 9, 38,
      'KK', 9, 45,
      hiColor, 0, 255, UR.Color);

  {idFlagsA:}
    AddStringField(
      'A:', 11, 4,
      '11111111', 11, 7, 8,
      hiFlagsA, UR.FlagsA);

  {idFlagsB:}
    AddStringField(
      'B:', 11, 20,
      '11111111', 11, 23, 8,
      hiFlagsB, UR.FlagsB);

  {idFlagsC:}
    AddStringField(
      'C:', 11, 36,
      '11111111', 11, 39, 8,
      hiFlagsC, UR.FlagsC);

  {idFlagsD:}
    AddStringField(
      'D:', 11, 53,
      '11111111', 11, 56, 8,
      hiFlagsD, UR.FlagsD);
  esFieldOptionsOff(efClearFirstChar);

    InitMenuEntryScreen := RawError;
  end;
end;


Procedure EditMenu(Item: Word);
  Var
    Tmp: LongInt;

  Begin
  EntryCommands.cpOptionsOn(cpEnableMouse);
  UR.Key := MA[Item].Key;
  UR.Typ := MA[Item].Typ;
  If UR.Typ > 0 Then
    Begin
    UR.TypeDesc := Prompts.GetString(MA[Item].Typ);
    UR.DataDesc := Prompts.GetString(MA[Item].Typ + 256);
    End
  Else
    Begin
    UR.TypeDesc := '';
    UR.DataDesc := '';
    End;
  UR.Prompt := MA[Item].Prompt;
  UR.Data := MA[Item].Data;
  UR.Security := MA[Item].Security;
  UR.FlagsA := Flag2Str(ByteArray(MA[Item].Flags)[1]);
  UR.FlagsB := Flag2Str(ByteArray(MA[Item].Flags)[2]);
  UR.FlagsC := Flag2Str(ByteArray(MA[Item].Flags)[3]);
  UR.FlagsD := Flag2Str(ByteArray(MA[Item].Flags)[4]);
  UR.Color := MA[Item].FgColor or (MA[Item].BgColor shl 4);
  ES.Select;
  ES.Process;
  ES.Erase;
  If UR.Color <> (MA[Item].FgColor or (MA[Item].BgColor shl 4)) Then
    Begin
    Modified := True;
    MA[Item].FgColor := UR.Color and $f;
    MA[Item].BgColor := (UR.Color shr 4) and $f;
    End;
  If MA[Item].Key <> UR.Key Then
    Begin
    Modified := True;
    MA[Item].Key := UR.Key[1];
    End;
  If MA[Item].Typ <> UR.Typ Then
    Begin
    Modified := True;
    MA[Item].Typ := UR.Typ;
    End;
  If MA[Item].Prompt <> UR.Prompt THen
    Begin
    Modified := True;
    MA[Item].Prompt := UR.Prompt;
    End;
  If MA[Item].Data <> UR.Data Then
    Begin
    Modified := True;
    MA[Item].Data := UR.Data;
    End;
  If MA[Item].Security <> UR.Security Then
    Begin
    Modified := True;
    MA[Item].Security := UR.Security;
    End;
  ByteArray(Tmp)[1] := Str2Flag(UR.FlagsA);
  ByteArray(Tmp)[2] := Str2Flag(UR.FlagsB);
  ByteArray(Tmp)[3] := Str2Flag(UR.FlagsC);
  ByteArray(Tmp)[4] := Str2Flag(UR.FlagsD);
  If Tmp <> MA[Item].Flags Then
    Begin
    Modified := True;
    MA[Item].Flags := Tmp;
    End;
  End;


Procedure MenuLoad(FN: String);          {Load file name}
  Var
    F: File;
    NumRead: Word;
    MenuPath: String;
    Error: Word;

  Begin
  Error := 0;
  FillChar(MA, SizeOf(MA), 0);
  If FileExist(FN) Then
    Begin
    Assign(F, FN);
    FileMode := fmReadOnly + fmDenyNone;
    If Not shReset(F, SizeOf(MenuType)) Then
      Error := 1010;
    End
  Else
    Error := 1;
  If Error = 0 Then
    If Not shRead(F, MA, MaxMenuItems + 1, NumItems) Then
      Error := 1020;
  Close(F);
  If IoResult <> 0 Then;
  If Error = 0 Then
    Dec(NumItems)
  Else
    NumItems := 0;
  Modified := False;
  End;


Function InitCmdMenu: Word;
  Var
    j: Word;
    NumGroups: Word;
    NumSubItems: Word;
    CurrItem: Word;
    CurrSub: Word;
    SubStr: String;
    SubNum: Word;

  Begin
  With CmdMenu do
    Begin
    j := 550;
    While Length(Prompts.GetString(j)) > 0 Do
      Inc(j);
    NumGroups := (j - 550) Div 2;
    if not InitCustom(29, 8, 59, 7 + NumGroups, esColors,
                      wBordered+wClear+wUserContents+wCoversOnDemand,
                      Vertical) then
      begin
      InitCmdMenu := InitStatus;
      Exit;
      end;
    mnOptionsOn(mnArrowSelect + mnAllHotSpots + mnAltMatch);
    mnOptionsOff(mnPopOnSelect+mnUseItemForTopic);
    If MouseInstalled Then
      MenuCommands.cpOptionsOn(cpEnableMouse);
    wFrame.SetFrameType(Frame1);
    AddShadow(shBR, shSeeThru);
    For CurrItem := 1 to NumGroups Do
      Begin
      AddItem(Copy(Prompts.GetString(550 + ((CurrItem - 1) * 2)), 1, 30),
        CurrItem, 0, 549 + CurrItem);
      SubStr := Prompts.GetString(551 + ((CurrItem - 1) * 2));
      NumSubItems := MKString.WordCount(SubStr);
      If NumSubItems < 13 Then
        AddFramedSubMenu(36, 11, 75, NumSubItems + 10, Vertical, Frame1)
      Else
        AddFramedSubMenu(32, 11, 75, 23, Vertical, Frame1);
      AddShadow(shBR, shSeeThru);
      For CurrSub := 1 to NumSubItems Do
        Begin
        SubNum := MKString.Str2Long(MKString.ExtractWord(SubStr, CurrSub));
        AddItem(Long2Str(SubNum) + ' ' + Copy(Prompts.GetString(SubNum), 1, 30), CurrSub, 0, SubNum);
        End;
      ItemsDone;
      End;
    ItemsDone;
    InitCmdMenu := RawError;
    End;
  End;


Procedure GetCmdFromMenu(Var Item: Byte);
  Var
    MenuDone: Boolean;

  Begin
  MenuDone := False;
  CmdMenu.Select;
  CmdMenu.DefaultPath(Item);
  CmdMenu.Draw;
  While Not MenuDone Do
    Begin
    CmdMenu.Process;
    Case CmdMenu.GetLastCommand of
      ccSelect:
        Begin
        MenuDone := True;
        Item := CmdMenu.MenuChoice;
        End;
      ccQuit : MenuDone := True;
      ccError : MenuDone := True;
      End;
    End;
  CmdMenu.Erase;
  End;


Procedure Initialize;
  Var
    TmpStr: String;

  Begin
  BBSType := DetectBBSType;
  Case BbsType Of
    1: Config := New(MKRCfgObjPtr, Init);
    2: Config := New(RARCfgObjPtr, Init);
    3: Config := New(QBCfgObjPtr, Init);
    4: Config := New(SBCfgObjPtr, Init);
    End;
  If BBSType = 0 Then
    Begin
    WriteLn('Fatal Error: Environment variable not found');
    Halt(42);
    End;
  Config^.Load;
  If Config^.GetError <> 0 Then
    Begin
    WriteLn('Unable to Load BBS Config Info');
    Halt(41);
    End;
  BBSPath := Config^.GetBBSPath;
  MenuPath := Config^.GetMnuPath(1);
  TmpStr := Config^.FindBbsFile('MKMenu.LC') + 'MKMenu.LC';
  Dispose(Config, Done);
  Prompts.Init;
  Prompts.Load(TmpStr);
  If InitMenuEntryScreen = 0 Then;
  If InitCmdMenu = 0 Then;
  End;


Procedure Finish;
  Begin
  ES.Done;
  CmdMenu.Select;
  CmdMenu.Done;
  End;


Function GetMenuCmd: Word;
  Var
    MenuPick: PickList;

  Begin
  If Not MenuPick.InitDeluxe(25, 5, 55, 4 + MaxMenuChoice, ESColors,
    wBordered+wClear+wUserContents,
    30, MaxMenuChoice, PickMenuStr,PickVertical, SingleChoice, pkMousePage) Then
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
  MenuPick.wFrame.AddHeaderColor('[ MKMenu Fast Action Menu ]', heTC, WhiteOnBlue, BlackOnLtGray);
  MenuPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  MenuPick.SetInitialChoice(1);
  MenuPick.Process;
  MenuPick.Erase;
  If MenuPick.GetLastCommand = ccSelect Then
    GetMenuCmd := MenuCode(MenuPick.GetLastChoice)
  Else
    GetMenuCmd := ccNone;
  MenuPick.Done;
  End;

const
  idHPrompt               = 0;
  idPColor               = idHPrompt + 1;
  idHColor               = idPColor + 1;

{Help index constants}
const
  hiHPrompt               = 1;
  hiPColor               = hiHPrompt + 1;
  hiHColor               = hiPColor + 1;

Type MenuHdrRecord = record
  Prompt               : string[75];
  PColor               : Byte;
  HColor               : Byte;
  End;


Var
  HES: EntryScreen;
  HUR: MenuHdrRecord;

{$F+}
procedure HPreEdit(ESP : EntryScreenPtr);
  {-Called just before a field is edited}
begin
  with ESP^ do
    case GetCurrentID of
      idHPrompt               : ;
      idPColor: GetColor(HUR.PColor, ESP, idPColor, '[ Prompt Color ]');
      idHColor: GetColor(HUR.HColor, ESP, idHColor, '[ Highlight Color ]');
    end;
end;

procedure HPostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idHPrompt               : ;
      idPColor               : ;
      idHColor               : ;
    end;
end;

Function InitHdrScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
const
  Frame1 = '…»ªºÕÕ∫∫';
  WinOptions = wBordered+wClear+wUserContents;
begin
  with HES do begin
    if not InitCustom(5, 5, 75, 9, EsColors, WinOptions) then begin
      InitHdrScreen := InitStatus;
      Exit;
    end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ Menu Prompt Settings ]', heTC);
    SetWrapMode(WrapAtEdges);

    SetPreEditProc(HPreEdit);
    SetPostEditProc(HPostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);

  {idPrompt:}
    SetPadChar('∞');
    esFieldOptionsOff(efTrimBlanks);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    esFieldOptionsOff(efTrimBlanks);
    AddSimpleStringField(
      'Prompt:', 2, 3,
      'X', 2, 11, 55, 55,
      hiHPrompt, HUR.Prompt);
    esFieldOptionsOn(efTrimBlanks);
    esFieldOptionsOff(efCursorToEnd+efClearFirstChar);
    SetPadChar(' ');

  {idPColor:}
    AddByteField(
      'Prompt Color:', 4, 3,
      'KK', 4, 17,
      hiPColor, 0, 255, HUR.PColor);

  {idHColor:}
    AddByteField(
      'Highlight Color:', 4, 34,
      'KK', 4, 51,
      hiHColor, 0, 255, HUR.HColor);

    InitHdrScreen := RawError;
  end;
end;


Procedure EditHdr;
  Begin
  if MouseInstalled then
    with EsColors do begin
      {activate mouse cursor}
      SoftMouseCursor($0000, (ColorMono(MouseColor, MouseMono) shl 8)+
                             Byte(MouseChar));
      ShowMouse;
      {enable mouse support}
      EntryCommands.cpOptionsOn(cpEnableMouse);
    end;
  HUR.Prompt := MA[0].Prompt;
  HUR.PColor := MA[0].FgColor or (MA[0].BgColor shl 4);
  HUR.HColor := MA[0].Typ or (MA[0].Security shl 4);
  Status := InitHdrScreen;
  if Status <> 0 then
    begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
    end;
  HES.Process;
  HES.Erase;
  HES.Done;
  If MA[0].Prompt <> HUR.Prompt Then
    Begin
    Modified := True;
    MA[0].Prompt := HUR.Prompt;
    End;
  If HUR.PColor <> (MA[0].FgColor or (MA[0].BgColor shl 4)) Then
    Begin
    Modified := True;
    MA[0].FgColor := HUR.PColor and $f;
    MA[0].BgColor := (HUR.PColor shr 4) and $f;
    End;
  If HUR.HColor <> MA[0].Typ or (MA[0].Security shl 4) Then
    Begin
    Modified := True;
    MA[0].Typ := HUR.HColor and $f;
    MA[0].Security := (HUR.HColor shr 4) and $f;
    End;
  End;


End.
