{$V-}

Unit MKDrawCF;

{$I OPDEFINE.INC}
{$I MKB.DEF}

Interface

Function GetPickFileName(Var PPath: String): String;
Function MKEditProc(Prompt: String; ForceUp, TrimBlanks: Boolean;
  MaxLen: Byte; Var S: String): Boolean;
Function GetBbsStr: String;
Function GetMenuCmd: Word;
Function GetActionCmd: Word;
Procedure GetPickChar;
Procedure GetDrawSet(Var DSet: Word);
Procedure InitCustCodes;
Procedure DoneCustCodes;


Const
  Frame1 = '…»ªºÕÕ∫∫';

Var
  ExtChars: Array[1..15] of String[12];
  CurrSet: Word;


Implementation

Uses OpColor, OpCrt, CfgYN,
  Dos,  OpInline,  OpString,  OpRoot, OPEdit,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame, OpPick,
  OpWindow,  OpSelect,  OpEntry, OpDir, MKString, MKFile;


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
  WinOptions = wBordered+wClear+wUserContents;

Type BCodeRec = Record
  Prompt: String[30];
  Code: String[25];
  End;

Const
  MaxCust = 100;

Type CustArray = Array[1..MaxCust] of BCodeRec;

Var
  CustCodes: ^CustArray;
  NumCust: Word;


Procedure DoneCustCodes;
  Begin
  Dispose(CustCodes);
  End;


Procedure InitCustCodes;
  Var
    TF: TFile;
    TmpStr1: String;
    TmpStr2: String;
    i: Word;

  Begin
  New(CustCodes);
  NumCust := 0;
  For i := 1 to MaxCust Do
    Begin
    CustCodes^[i].Prompt := '';
    CustCodes^[i].Code := '';
    End;
  If FileExist('Codes.MKD') Then
    Begin
    TF.Init;
    If TF.OpenTextFile('Codes.MKD') Then
      Begin
      TmpStr1 := TF.GetString;
      TmpStr2 := TF.GetString;
      While (TF.StringFound and (NumCust < MaxCust)) Do
        Begin
        Inc(NumCust);
        CustCodes^[NumCust].Prompt := TmpStr1;
        CustCodes^[NumCust].Code := TmpStr2;
        TmpStr1 := TF.GetString;
        TmpStr2 := TF.GetString;
        End;
      If TF.CloseTextFile Then;
      End;
    TF.Done;
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
    ProcessBox('Finding Screen Files', '[ Please Wait ]');
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


Const
  MaxBbsCodes = 64;
  MenuAttr = 1;
  MenuBlink = MenuAttr + 1;
  MenuInt = MenuBlink + 1;
  MenuUnder = MenuBlink + 1;
  MenuRev = MenuUnder + 1;
  MenuFill = MenuRev + 1;
  MenuCopy = MenuFill + 1;
  MenuMove = MenuCopy + 1;
  MenuIns = MenuMove + 1;
  MenuDel = MenuIns + 1;
  MenuClr = MenuDel + 1;
  MenuPick = MenuClr + 1;
  MenuGet = MenuPick + 1;
  MenuEncl = MenuGet + 1;
  MenuLoad = MenuEncl + 1;
  MenuSave = MenuLoad + 1;
  MenuHelp = MenuSave + 1;
  MenuDos = MenuHelp + 1;
  MenuExit = MenuDos + 1;
  MaxMenuChoice = MenuExit;


{$F+}
Procedure PickCharStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  Case Item of
    1..15:  IString := '  ' + ExtChars[Item];
    Else
      IString := '';
    End;
  End;


{$F+}
Procedure PickDrawStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  Case Item of
    1..4:  IString := '  ' + ExtChars[Item];
    Else
      IString := '    Normal';
    End;
  End;


{$F+}
Procedure PickMenuStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  Case Item of
    MenuAttr:  IString := '   Attribute Selection';
    MenuBlink: IString := '   Toggle Blinking';
    MenuInt:   IString := '   Toggle Intensity';
    MenuUnder: IString := '   Pick color under cursor';
    MenuRev:   IString := '   Reverse color attribute';
    MenuFill:  IString := '   Fill area with attribute';
    MenuCopy:  IString := '   Copy area of the screen';
    MenuMove:  IString := '   Move area of the screen';
    MenuClr:   IString := '   Clear area of the screen';
    MenuPick:  IString := '   Pick BBS Screen Code';
    MenuHelp:  IString := '   Help';
    MenuDos:   IString := '   Shell to Dos';
    MenuExit:  IString := '   Exit from MKDraw';
    MenuLoad:  IString := '   Load a screen file';
    MenuSave:  IString := '   Save a screen file';
    MenuGet:   IString := '   Get extended char set';
    MenuEncl:  IString := '   Enclose area in box frame';
    MenuIns:   IString := '   Insert a blank line';
    MenuDel:   IString := '   Delete current line';
    End;
  End;


Function MenuCode(Item: Word): Word;
  Begin
  Case Item of
    MenuAttr: MenuCode := ccUser1;
    MenuBlink: MenuCode := ccUser3;
    MenuInt: MenuCode := ccUser41;
    MenuUnder: MenuCode := ccUser2;
    MenuRev: MenuCode := ccUser9;
    MenuFill: MenuCode := ccUser6;
    MenuCopy: MenuCode := ccUser8;
    MenuMove: MenuCode := ccUser7;
    MenuIns: MenuCode := ccUser43;
    MenuDel: MenuCode := ccUser44;
    MenuClr: MenuCode := ccUser5;
    MenuPick: MenuCode := ccUser40;
    MenuHelp: MenuCode := ccHelp;
    MenuDos: MenuCode := ccUser10;
    MenuExit: MenuCode := ccDone;
    MenuGet: MenuCode := ccUser42;
    MenuEncl: MenuCode := ccUser46;
    MenuLoad: MenuCode := ccUser4;
    MenuSave: MenuCode := ccSaveFile;
    Else
      MenuCode := ccNone;
    End;
  End;



{$F+}
Procedure PickBbsStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  If NumCust = 0 Then
    Begin
    Case Item of
      01: IString := 'Wait on Enter    [^A]';
      02: IString := 'Disable Stopping [^B]';
      03: IString := 'Enable Stopping  [^C]';
      04: IString := 'Enable More?     [^D]';
      05: IString := 'Disable More?    [^E]';
      06: IString := 'Beep             [^G]';
      07: IString := 'Clear Screen     [^L]';
      08: IString := 'Pause one second [^W]';
      09: IString := 'Full Name        [^FA]';
      10: IString := 'Location         [^FB]';
      11: IString := 'Password         [^FC]';
      12: IString := 'Bus/Data phone   [^FD]';
      13: IString := 'Voice/Home phone [^FE]';
      14: IString := 'Last call date   [^FF]';
      15: IString := 'Last call time   [^FG]';
      16: IString := 'A security flags [^FH]';
      17: IString := 'B security flags [^FI]';
      18: IString := 'C security flags [^FJ]';
      19: IString := 'D security flags [^FK]';
      20: IString := 'Netmail credit   [^FL]';
      21: IString := 'Messages Posted  [^FM]';
      22: IString := 'Last msg read    [^FN]';
      23: IString := 'Security level   [^FO]';
      24: IString := 'Total calls      [^FP]';
      25: IString := 'Num Uploads      [^FQ]';
      26: IString := 'Kb Uploads       [^FR]';
      27: IString := 'Num Downloads    [^FS]';
      28: IString := 'Kb Downloads     [^FT]';
      29: IString := 'Mins used today  [^FU]';
      30: IString := 'Screen length    [^FV]';
      31: IString := 'First name       [^FW]';
      32: IString := 'Ansi setting     [^FX]';
      33: IString := 'More? setting    [^FY]';
      34: IString := 'Screen clearing  [^FZ]';
      35: IString := 'Full scrn editor [^F0]';
      36: IString := 'Avatar setting   [^F8]';
      37: IString := 'System calls     [^KA]';
      38: IString := 'Last caller      [^KB]';
      39: IString := 'Active msgs      [^KC]';
      40: IString := 'Low msg number   [^KD]';
      41: IString := 'High msg number  [^KE]';
      42: IString := 'Times paged      [^KF]';
      43: IString := 'Day of week      [^KG]';
      44: IString := 'Number of users  [^KH]';
      45: IString := 'Time (24hr)      [^KI]';
      46: IString := 'Todays date      [^KJ]';
      47: IString := 'Mins this call   [^KK]';
      48: IString := 'Secs this call   [^KL]';
      49: IString := 'Mins today       [^KM]';
      50: IString := 'Secs today       [^KN]';
      51: IString := 'Mins remain      [^KO]';
      52: IString := 'Secs remain      [^KP]';
      53: IString := 'Daily time limit [^KQ]';
      54: IString := 'Baud rate        [^KR]';
      55: IString := 'Short Day of week[^KS]';
      56: IString := 'Daily kb limit   [^KT]';
      57: IString := 'Mins until event [^KU]';
      58: IString := 'Next event time  [^KV]';
      59: IString := 'Line number      [^KW]';
      60: IString := 'Terminate call   [^KX]';
      61: IString := 'Curr msg area    [^KY]';
      62: IString := 'Curr file area   [^KZ]';
      63: IString := 'Num msg area     [^K1]';
      64: IString := 'Num file area    [^K2]';
      Else
        IString := '';
      End;
    End
  Else
    Begin
    If Item <= NumCust Then
      IString := CustCodes^[Item].Prompt
    Else
      IString := '';
    End;
  End;


{$F+}
Procedure PickActionStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  Case Item of
    01: IString := ' None';
    02: IString := ' Home';
    03: IString := ' Clear Screen';
    Else
      IString := '';
    End;
  End;


Function BbsCode(Item: Word): String;
  Begin
  If NumCust = 0 Then
    Begin
    Case Item of
      01: BbsCode := #1;
      02: BbsCode := #2;
      03: BbsCode := #3;
      04: BbsCode := #4;
      05: BbsCode := #5;
      06: BbsCode := #7;
      07: BbsCode := #12;
      08: BbsCode := #23;
      09: BbsCode := #6#65;
      10: BbsCode := #6#66;
      11: BbsCode := #6#67;
      12: BbsCode := #6#68;
      13: BbsCode := #6#69;
      14: BbsCode := #6#70;
      15: BbsCode := #6#71;
      16: BbsCode := #6#72;
      17: BbsCode := #6#73;
      18: BbsCode := #6#74;
      19: BbsCode := #6#75;
      20: BbsCode := #6#76;
      21: BbsCode := #6#77;
      22: BbsCode := #6#78;
      23: BbsCode := #6#79;
      24: BbsCode := #6#80;
      25: BbsCode := #6#81;
      26: BbsCode := #6#82;
      27: BbsCode := #6#83;
      28: BbsCode := #6#84;
      29: BbsCode := #6#85;
      30: BbsCode := #6#86;
      31: BbsCode := #6#87;
      32: BbsCode := #6#88;
      33: BbsCode := #6#89;
      34: BbsCode := #6#90;
      35: BbsCode := #6#48;
      36: BbsCode := #6#56;
      37: BbsCode := #11#65;
      38: BbsCode := #11#66;
      39: BbsCode := #11#67;
      40: BbsCode := #11#68;
      41: BbsCode := #11#69;
      42: BbsCode := #11#70;
      43: BbsCode := #11#71;
      44: BbsCode := #11#72;
      45: BbsCode := #11#73;
      46: BbsCode := #11#74;
      47: BbsCode := #11#75;
      48: BbsCode := #11#76;
      49: BbsCode := #11#77;
      50: BbsCode := #11#78;
      51: BbsCode := #11#79;
      52: BbsCode := #11#80;
      53: BbsCode := #11#81;
      54: BbsCode := #11#82;
      55: BbsCode := #11#83;
      56: BbsCode := #11#84;
      57: BbsCode := #11#85;
      58: BbsCode := #11#86;
      59: BbsCode := #11#87;
      60: BbsCode := #11#88;
      61: BbsCode := #11#89;
      62: BbsCode := #11#90;
      63: BbsCode := #11#49;
      64: BbsCode := #11#50;
      Else
        BbsCode := '';
      End;
    End
  Else
    Begin
    If Item <= NumCust Then
      BbsCode := CustCodes^[Item].Code
    Else
      BbsCode := '';
    End;
  End;


Function GetBbsStr: String;
  Var
    BbsPick: PickList;
    NumCodes: Word;

  Begin
  NumCodes := MaxBbsCodes;
  If NumCust > 0 Then
    NumCodes := NumCust;
  If Not BbsPick.InitDeluxe(2,2,79,19,ESColors,
    wBordered+wClear+wUserContents,
    25, NumCodes, PickBbsStr,PickVertical, SingleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  BbsPick.pkOptionsOn(pkStick);
  BbsPick.wFrame.SetFrameType(Frame1);
  BbsPick.wFrame.AddHeaderColor('[ Bbs Screen Code ]', heTC, WhiteOnBlue, BlackOnLtGray);
  BbsPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  BbsPick.SetInitialChoice(1);
  BbsPick.Process;
  BbsPick.Erase;
  If BbsPick.GetLastCommand = ccSelect Then
    GetBbsStr := BbsCode(BbsPick.GetLastChoice)
  Else
    GetBbsStr := '';
  BbsPick.Done;
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
  MenuPick.wFrame.AddHeaderColor('[ MKDraw Fast Menu ]', heTC, WhiteOnBlue, BlackOnLtGray);
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


Function GetActionCmd: Word;
  Var
    MenuPick: PickList;

  Begin
  If Not MenuPick.InitDeluxe(30, 10, 50, 13, ESColors,
    wBordered+wClear+wUserContents,
    15, 3, PickActionStr,PickVertical, SingleChoice, pkMousePage) Then
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
  MenuPick.wFrame.AddHeaderColor('[ Action ]', heTC, WhiteOnBlue, BlackOnLtGray);
  MenuPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  MenuPick.SetInitialChoice(1);
  MenuPick.Process;
  MenuPick.Erase;
  If MenuPick.GetLastCommand = ccSelect Then
    GetActionCmd := MenuPick.GetLastChoice
  Else
    GetActionCmd := 0;
  MenuPick.Done;
  End;


Procedure GetPickChar;
  Var
    CharPick: PickList;

  Begin
  If Not CharPick.InitDeluxe(32,5,48,20,ESColors,
    wBordered+wClear+wUserContents,
    14, 15, PickCharStr,PickVertical, SingleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  CharPick.pkOptionsOn(pkStick);
  CharPick.wFrame.SetFrameType(Frame1);
  CharPick.wFrame.AddHeaderColor('[ Ext Char Set ]', heTC, WhiteOnBlue, BlackOnLtGray);
  CharPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  CharPick.SetInitialChoice(CurrSet);
  CharPick.Process;
  CharPick.Erase;
  If CharPick.GetLastCommand = ccSelect Then
    CurrSet := CharPick.GetLastChoice;
  CharPick.Done;
  End;


Procedure GetDrawSet(Var DSet: Word);
  Var
    DrawPick: PickList;

  Begin
  If Not DrawPick.InitDeluxe(32,10,48,14,ESColors,
    wBordered+wClear+wUserContents,
    15, 5, PickDrawStr,PickVertical, SingleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  DrawPick.pkOptionsOn(pkStick);
  DrawPick.wFrame.SetFrameType(Frame1);
  DrawPick.wFrame.AddHeaderColor('[ Drawing Mode ]', heTC, WhiteOnBlue, BlackOnLtGray);
  DrawPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  DrawPick.SetInitialChoice(DSet);
  DrawPick.Process;
  DrawPick.Erase;
  If DrawPick.GetLastCommand = ccSelect Then
    DSet := DrawPick.GetLastChoice;
  DrawPick.Done;
  End;


End.
