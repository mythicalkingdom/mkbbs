{$V-}

Unit MKREADCF;

{$I OPDEFINE.INC}
{$I MKB.DEF}

Interface

Uses OpColor, OpCrt;


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

const
  MenuColors : ColorSet = (
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



Type ReadCfgType = Record
  Name: String[35];
  UserNum: LongInt;
  UseText: Boolean;
  TextEd: String[70];
  QuoteStr: String[8];
  LastExport: String[70];
  SpellCheck: String[70];
  QuoteHdr: String[70];
  Taglines: Boolean;
  NextTag: Word;
  YourBeep: Boolean;
  NewOnly: Boolean;
  MsgOrder: Byte;
  Colors: Array[1..10] of Byte;
  Crash: Boolean;
  Direct: Boolean;
  Imm: Boolean;
  FileReq: Boolean;
  FAttach: Boolean;
  KillSent: Boolean;
  NetPath: String[70];
  NetTaglines: Boolean;
  NetFido: Boolean;
  AnsiBaud: Word;
  PrnName: String[13];
  End;


Var
  CfgRec: ReadCfgType;

Procedure EditCfg;
Procedure DoTagEdit(Var TagLineStr: String; TagNum: Word);
Procedure EditHelp;
Procedure NoHelp;
Procedure MenuHelp;
Procedure LoadTwits;
Function  Twit(Name: String): Boolean;

Implementation

uses
  Dos,  OpInline,  OpString,  OpRoot,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame, OpPick,
  OpWindow,  OpSelect,  OpEntry, MKColor, MKString, MKFile, MKCfgAbs;


{Entry field constants}
const
  idName                 = 0;
  idUserNum              = idName + 1;
  idTextEd               = idUserNum + 1;
  idUseTxt               = idTextEd + 1;
  idQuoteStr             = idUseTxt + 1;
  idYourBeep             = idQuoteStr + 1;
  idSpellCheck           = idYourBeep + 1;
  idQuoteHdr             = idSpellCheck + 1;
  idNewOnly              = idQuoteHdr + 1;
  idTaglines             = idNewOnly + 1;
  idMsgOrder             = idTaglines + 1;
  idNetOpt = idMsgOrder + 1;
  idNetPath = idNetOpt + 1;
  idAnsiBaud = idNetPath + 1;
  idPrnName = idAnsiBaud + 1;
  idColor1               = idPrnName + 1;
  idColor7 = idColor1 + 1;
  idColor2               = idColor7 + 1;
  idColor3               = idColor2 + 1;
  idColor4               = idColor3 + 1;
  idColor5               = idColor4 + 1;
  idColor6               = idColor5 + 1;

{Help index constants}
const
  hiName                 = 1;
  hiUserNum              = hiName + 1;
  hiTextEd               = hiUserNum + 1;
  hiUseTxt               = hiTextEd + 1;
  hiQuoteStr             = hiUseTxt + 1;
  hiYourBeep             = hiQuoteStr + 1;
  hiSpellCheck           = hiYourBeep + 1;
  hiQuoteHdr             = hiSpellCheck + 1;
  hiNewOnly              = hiQuoteHdr + 1;
  hiTaglines             = hiNewOnly + 1;
  hiMsgOrder             = hiTaglines + 1;
  hiNetOpt = hiMsgOrder + 1;
  hiNetPath = hiNetOpt + 1;
  hiAnsiBaud = hiNetPath + 1;
  hiPrnName = hiAnsiBaud + 1;
  hiColor1               = hiPrnName + 1;
  hiColor7 = hiColor1 + 1;
  hiColor2               = hiColor7 + 1;
  hiColor3               = hiColor2 + 1;
  hiColor4               = hiColor3 + 1;
  hiColor5               = hiColor4 + 1;
  hiColor6               = hiColor5 + 1;

Const
  MaxTwits = 20;

var
  ES     : EntryScreen;
  Status : Word;
  TagToEdit: String;
  TagES: EntryScreen;
  Fake: String[3];
  TwitList: Array[1..MaxTwits] of String[35];
  NumTwits: Word;


Function Twit(Name: String): Boolean;
  Var
    i: Word;

  Begin
  Twit := False;
  Name := Upper(Name);
  i := 1;
  While i <= NumTwits Do
    Begin
    If TwitList[i] = Name Then
      Twit := True;
    Inc(i);
    End;
  End;


Procedure LoadTwits;
  Var
    TF: TFile;
    TmpStr: String;

  Begin
  NumTwits := 0;
  TmpStr := Config^.FindBbsFile('Twit.Ctl') + 'Twit.Ctl';
  If FileExist(TmpStr) Then
    Begin
    TF.Init;
    If TF.OpenTextFile(TmpStr) Then
      Begin
      TmpStr := TF.GetString;
      While (TF.StringFound and (NumTwits < MaxTwits)) Do
        Begin
        Inc(NumTwits);
        TwitList[NumTwits] := Upper(TmpStr);
        TmpStr := TF.GetString;
        End;
      If TF.CloseTextFile Then;
      End;
    TF.Done;
    End;
  End;


Procedure MenuHelp;
  Begin
  WriteLn;
  WriteLn('                        MKRead Main Menu Commands');
  WriteLn;
  WriteLn('      Area       Select new area for reading messages');
  WriteLn('      Prior      Go To Previous Message in current area');
  WriteLn('      Next       Go To Next Message in current area');
  WriteLn('      Export     Export current message to a text file');
  WriteLn('      Reply      Reply to current message');
  WriteLn('      Enter      Enter a new message');
  WriteLn('      +Pg        Next Page of the current message');
  WriteLn('      -Pg        Previous Page of the current message');
  WriteLn('      Config     Set Configuration Parameters of MKRead');
  WriteLn('      Jump       JumpList to select new message in current area');
  WriteLn('      Del        Delete the current message');
  WriteLn('      Shell      Shell to Dos');
  WriteLn('      View       View current message in Ansi/Avatar format');
  WriteLn('      Quit       Exit MKRead');
  WriteLn;
  WriteLn('                             Command Keys');
  WriteLn('      Alt-F      Forward msg         Alt-R     Resort messages');
  WriteLn('      Alt-G      Grab tagline        Alt-T     Edit Taglines');
  WriteLn('      Alt-S      Select tagline      Alt-P     Print message ');
  End;


Procedure EditHelp;
  Begin
  WriteLn('                     MKRead Internal Editor Commands');
  WriteLn;
  WriteLn('  Left            Cursor Left             Right           Cursor right');
  WriteLn('  Ctl-Left        Word left               Ctl-Right       Word right');
  WriteLn('  Home            Begin of line           End             End of line');
  WriteLn('  Up              Cursor Up               Down            Cursor Down');
  WriteLn('  Ctl-W           Display Up              Ctl-Z           Display Down');
  WriteLn('  PgUp            Page Up                 PgDn            Page Down');
  WriteLn('  Ctl-PgUp        Top of File             Ctl-PgDn        End of file');
  WriteLn('  Ctl-J L         Jump to line            Esc             Exit editor');
  WriteLn('  Del             Delete character        BkSp            Backspace');
  WriteLn('  Ctl-Y           Delete line             Ctl-Q Y         Delete to EOL');
  WriteLn('  Ctl-T           Delete word             Ctl-N           Insert line');
  WriteLn('  Tab             Tab                     Ctl-P           Control character');
  WriteLn('  F7 or Ctl-K R   Begin Block             F8 or Ctl-K K   End Block');
  WriteLn('  Ctl-K T         Mark Word               Ctl-Q B         Jump Begin Block');
  WriteLn('  Ctl-Q K         Jump End Block          Ctl-K H         Hide/Unhide Block');
  WriteLn('  Ctl-K C         Copy block              Ctl-K V         Move block');
  WriteLn('  Ctl-K Y         Delete block            Ctl-K I         Indent block');
  WriteLn('  Ctl-K U         Unindent block          Ctl-K R         Read Text File');
  WriteLn('  Ctl-Q F         Find text               Ctl-Q A         Search/Replace');
  WriteLn('  Ctl-L           Search again            Ctl-O C         Center Text');
  WriteLn('  Ins             Insert/Overwrite        Ctl-Q L         Restore Line');
  End;


Procedure NoHelp;
  Begin
  WriteLn;
  WriteLn('                           MKRead Online Message Reader');
  WriteLn;
  WriteLn('     No Help is available for the current activity');
  End;



{$F+}
Procedure PickNetStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  Case Item of
    1: IString := 'Crash';
    2: IString := 'Direct';
    3: IString := 'Immediate';
    4: IString := 'File Request';
    5: IString := 'File Attach';
    6: IString := 'Kill after sending';
    7: IString := 'Add tagline';
    8: IString := 'Add Fido Info';
    Else
      IString := '';
    End;
  End;


Procedure GetNetOptions;
  Const
    Frame1 = 'ÉÈ»¼ÍÍºº';
    WinOptions = wBordered+wClear+wUserContents;

  Var
    NetPick: PickList;

  Begin
  If Not NetPick.InitDeluxe(25,10,55,18,ESColors,
    wBordered+wClear+wUserContents,
    25, 8, PickNetStr, PickVertical, MultipleChoice, pkMousePage) Then
    Halt;
  If MouseInstalled then
    begin
    SoftMouseCursor($0000, (ColorMono(EsColors.MouseColor,
      EsColors.MouseMono) shl 8) + Byte(MouseChar));
    ShowMouse;
    PickCommands.cpOptionsOn(cpEnableMouse);
    End;
  NetPick.pkOptionsOn(pkStick);
  NetPick.wFrame.SetFrameType(Frame1);
  NetPick.wFrame.AddShadow(shBR, shSeeThru);
  NetPick.wFrame.AddHeaderColor('[Default NetMail Options ]', heTC, WhiteOnBlue, BlackOnLtGray);
  NetPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  NetPick.SetSelectMarker(' * ','');
  NetPick.AllocateSelectSet(8);
  If CfgRec.Crash Then
    NetPick.SelectItem(1)
  Else
    NetPick.DeSelectItem(1);
  If CfgRec.Direct Then
    NetPick.SelectItem(2)
  Else
    NetPick.DeSelectItem(2);
  If CfgRec.Imm Then
    NetPick.SelectItem(3)
  Else
    NetPick.DeSelectItem(3);
  If CfgRec.FileReq Then
    NetPick.SelectItem(4)
  Else
    NetPick.DeSelectItem(4);
  If CfgRec.FAttach Then
    NetPick.SelectItem(5)
  Else
    NetPick.DeSelectItem(5);
  If CfgRec.KillSent Then
    NetPick.SelectItem(6)
  Else
    NetPick.DeSelectItem(6);
  If CfgRec.NetTaglines Then
    NetPick.SelectItem(7)
  Else
    NetPick.DeSelectItem(7);
  If CfgRec.NetFido Then
    NetPick.SelectItem(8)
  Else
    NetPick.DeSelectItem(8);
  NetPick.Process;
  CfgRec.Crash := NetPick.ItemIsSelected(1);
  CfgRec.Direct := NetPick.ItemIsSelected(2);
  CfgRec.Imm := NetPick.ItemIsSelected(3);
  CfgRec.FileReq := NetPick.ItemIsSelected(4);
  CfgRec.FAttach := NetPick.ItemIsSelected(5);
  CfgRec.KillSent := NetPick.ItemIsSelected(6);
  CfgRec.NetTaglines := NetPick.ItemIsSelected(7);
  CfgRec.NetFido := NetPick.ItemIsSelected(8);
  NetPick.Erase;
  NetPick.Done;
  End;


Procedure GetNet(Var ESP: EntryScreenPtr;  ScreenNo: Word);
  Var
    Temp: Word;

  Const
    Wait = 100;

  Begin
  Delay(Wait);
  ESP^.PositionCursorAt(ESP^.FindField(ScreenNo));
  HideMouse;
  Temp := ReadKeyWord;
    Case Temp of
    7181: Begin
          GetNetOptions;
          ESP^.SetNextField(ScreenNo + 1);
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
      idName                 : ;
      idUserNum              : ;
      idTextEd               : ;
      idUseTxt               : ;
      idQuoteStr             : ;
      idYourBeep             : ;
      idSpellCheck           : ;
      idQuoteHdr             : ;
      idNewOnly              : ;
      idTaglines             : ;
      idMsgOrder             : ;
      idNetOpt: GetNet(ESP, idNetOpt);
      idNetPath:;
      idColor1: GetColor(CfgRec.Colors[1], ESP, idColor1, '[ Text Color ]');
      idColor7: GetColor(CfgRec.Colors[7], ESP, idColor7, '[ Quote Color ]');
      idColor2: GetColor(CfgRec.Colors[2], ESP, idColor2, '[ Header Title ]');
      idColor3: GetColor(CfgRec.Colors[3], ESP, idColor3, '[ Header Data ]');
      idColor4: GetColor(CfgRec.Colors[4], ESP, idColor4, '[ Menu Color ]');
      idColor5: GetColor(CfgRec.Colors[5], ESP, idColor5, '[ Menu Key ]');
      idColor6: GetColor(CfgRec.Colors[6], ESP, idColor6, '[ Menu Select ]');
    end;
end;

procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idName                 : ;
      idUserNum              : ;
      idTextEd               : ;
      idUseTxt               : ;
      idQuoteStr             : ;
      idYourBeep             : ;
      idSpellCheck           : ;
      idQuoteHdr             : ;
      idNewOnly              : ;
      idTaglines             : ;
      idMsgOrder             : ;
      idNetOpt:;
      idNetPath:;
      idColor1               : ;
      idColor2               : ;
      idColor3               : ;
      idColor4               : ;
      idColor5               : ;
      idColor6               : ;
    end;
end;

procedure IncChoice(var Value; ID : Word; Factor : Integer; var St : string);
  {-Increment a multiple choice field value and convert it to a string}

  Const
    MaxOrders = 4;

  Begin
  Case Factor of
    1: Inc(CfgRec.MsgOrder);
    -1: Dec(CfgRec.MsgOrder);
    End;
  If CfgRec.MsgOrder < 1 Then
    CfgRec.MsgOrder := MaxOrders;
  If CfgRec.MsgOrder > MaxOrders Then
    CfgRec.MsgOrder := 1;
  Case CfgRec.MsgOrder Of
    1: St := 'Subject';
    2: St := 'Msg Number';
    3: St := 'Date/Time';
    4: St := 'From';
    Else
      St := 'Undefined';
    End;
  End;

procedure ErrorHandler(UnitCode : Byte; var ErrCode : Word; Msg : string);
  {-Report errors}
begin
  RingBell;
end;

procedure DisplayHelp(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
  {-Display context sensitive help}
begin
end;

function InitEntryScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
const
  Frame1 = 'ÉÈ»¼ÍÍºº';
  WinOptions = wBordered+wClear+wUserContents;
begin
  with ES do begin
    if not InitCustom(4, 2, 75, 22, EsColors, WinOptions) then begin
      InitEntryScreen := InitStatus;
      Exit;
    end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeaderColor('[ MKRead Configuration ]', heTC, WhiteOnBlue, BlackOnLtGray);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(WrapAtEdges);

    SetPreEditProc(PreEdit);
    SetPostEditProc(PostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);

    AddTextField(
      '---- Colors -----', 17, 27);

  {idName:}
    AddStringField(
      'Name:', 1, 3,
      CharStr('X', 35), 1, 9, 35,
      hiName, CfgRec.Name);

  {idUserNum:}
    AddLongField(
      'User Num:', 1, 47,
      '999999', 1, 57,
      hiUserNum, $80000000, $7FFFFFFF, CfgRec.UserNum);

  {idTextEd:}
    AddStringField(
      'Editor:', 3, 3,
      CharStr('X', 60), 3, 11, 60,
      hiTextEd, CfgRec.TextEd);

  {idUseTxt:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Use Text Control File:', 5, 3,
      'Y', 5, 26,
      hiUseTxt, CfgRec.UseText);
    esFieldOptionsOff(efClickExit);

  {idQuoteStr:}
    AddStringField(
      'Quote Str:', 5, 30,
      'XXXXXXXX', 5, 41, 8,
      hiQuoteStr, CfgRec.QuoteStr);

  {idYourBeep:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Beep Your Mail:', 5, 52,
      'Y', 5, 68,
      hiYourBeep, CfgRec.YourBeep);
    esFieldOptionsOff(efClickExit);

  {idSpellCheck:}
    AddStringField(
      'Spell Checker', 7, 3,
      CharStr('X', 55), 7, 17, 55,
      hiSpellCheck, CfgRec.SpellCheck);

  {idQuoteHdr:}
    AddStringField(
      'Quote Header:', 9, 3,
      CharStr('X', 55), 9, 17, 55,
      hiQuoteHdr, CfgRec.QuoteHdr);

  {idNewOnly:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'New Mail Only:', 11, 3,
      'Y', 11, 18,
      hiNewOnly, CfgRec.NewOnly);
    esFieldOptionsOff(efClickExit);

  {idTaglines:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Taglines:', 11, 21,
      'Y', 11, 31,
      hiTaglines, CfgRec.Taglines);
    esFieldOptionsOff(efClickExit);

  {idMsgOrder:}
    AddChoiceField(
      'Msg Order:', 11, 34,
      'XXXXXXXXXXXX', 11, 45,
      hiMsgOrder, 1, IncChoice, CfgRec.MsgOrder);

    Fake := '*';

    AddStringField(
      'NetMail:', 11, 59,
      'X', 11, 69, 1,
      hiNetOpt, Fake);

    AddStringField(
      'NetMail Path:', 13, 3,
      CharStr('X', 55), 13, 17, 55,
      hiQuoteHdr, CfgRec.NetPath);

    AddWordField(
      'Ansi Baud:', 15, 3,
      '99999', 15, 14,
      hiAnsiBaud, 0, $FFFF, CfgRec.AnsiBaud);

    AddStringField(
      'Printer Name:', 15, 23,
      CharStr('X', 13), 15, 37, 13,
      hiPrnName, CfgRec.PrnName);

  {idColor1:}
    AddByteField(
      'Text:', 19, 3,
      'KK', 19, 9,
      hiColor1, 0, 255, CfgRec.Colors[1]);

    AddByteField(
      'Quote:', 19, 14,
      'KK', 19, 21,
      hiColor7, 0, 255, CfgRec.Colors[7]);

  {idColor2:}
    AddByteField(
      'Hdr Titles:', 19, 26,
      'KK', 19, 38,
      hiColor2, 0, 255, CfgRec.Colors[2]);

  {idColor3:}
    AddByteField(
      'Hdr Info:', 19, 43,
      'KK', 19, 53,
      hiColor3, 0, 255, CfgRec.Colors[3]);

  {idColor4:}
    AddByteField(
      'Menu:', 21, 3,
      'KK', 21, 9,
      hiColor4, 0, 255, CfgRec.Colors[4]);

  {idColor5:}
    AddByteField(
      'Menu Key Char:', 21, 24,
      'KK', 21, 39,
      hiColor5, 0, 255, CfgRec.Colors[5]);

  {idColor6:}
    AddByteField(
      'Menu Selector:', 21, 50,
      'KK', 21, 65,
      hiColor6, 0, 255, CfgRec.Colors[6]);

    InitEntryScreen := RawError;
  end;
end;

Procedure EditCfg;
  begin
  if MouseInstalled then
    with EsColors do begin
      {activate mouse cursor}
      SoftMouseCursor($0000, (ColorMono(MouseColor, MouseMono) shl 8)+
                             Byte(MouseChar));
      ShowMouse;
      {enable mouse support}
      EntryCommands.cpOptionsOn(cpEnableMouse);
    end;
  Status := InitEntryScreen;
  if Status <> 0 then begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
  end;
  ES.Process;
  ES.Erase;
  HideMouse;
  ES.Done;
  ESColors.HighItemColor := CfgRec.Colors[2];
  ESColors.TextColor := CfgRec.Colors[3];
  MenuColors.TextColor := CfgRec.Colors[4];
  MenuColors.HighItemColor := CfgRec.Colors[5];
  MenuColors.SelItemColor := CfgRec.Colors[6];
  End;


function TagInitEntryScreen(TagNum: Word) : Word;
  {-Initialize entry screen generated by MAKESCRN}
  const
    Frame1 = 'ÉÈ»¼ÍÍºº';
    WinOptions = wBordered+wClear+wUserContents;

  begin
  with TagES do
    begin
    if not InitCustom(3, 10, 76, 12, EsColors, WinOptions) then
      begin
      TagInitEntryScreen := InitStatus;
      Exit;
      end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ Edit TagLine ]', heTC);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(ExitAtEdges);
    SetErrorProc(ErrorHandler);
  {idUserNum:}
    AddStringField(
      Long2Str(TagNum) + ':', 2, 6,
      PadRight('','X',60), 2, 11,
      60, 0, TagToEdit);
    TagInitEntryScreen := RawError;
    end;
  end;


Function GreekStr(InStr: String): String;
  Var
    TmpStr: String;
    Cnt: Word;
    FoundPos: Word;

  Const
    OrigChars: String = 'ABCDEFGIJLNOQTUYZ';
    CvtChars: String  = 'àá›ëîŸ‡‹õœ¤¢€çæ˜ä';

  Begin
  TmpStr := InStr;
  Cnt := 1;
  While Cnt <= Length(InStr) Do
    Begin
    FoundPos := Pos(UpCase(InStr[Cnt]), OrigChars);
    If FoundPos > 0 Then
      TmpStr[Cnt] := CvtChars[FoundPos];
    Inc(Cnt);
    End;
  GreekStr := TmpStr;
  End;


Procedure DoTagEdit(Var TagLineStr: String; TagNum: Word);
  Var
    Done: Boolean;
    TmpStr: String;
    Cnt: Word;

  Begin
  TagToEdit := TagLineStr;
  if MouseInstalled then
    with EsColors do begin
      {activate mouse cursor}
      SoftMouseCursor($0000, (ColorMono(MouseColor, MouseMono) shl 8)+
                             Byte(MouseChar));
      ShowMouse;
      {enable mouse support}
      EntryCommands.cpOptionsOn(cpEnableMouse);
    end;
  Status := TagInitEntryScreen(TagNum);
  if Status <> 0 then begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
  end;
  TagES.GetCommandProcessor^.AddCommand(ccUser1, 1, $3000, 0); {Alt-B Backward}
  TagES.GetCommandProcessor^.AddCommand(ccUser2, 1, $2200, 0); {Alt-G Greek}
  TagES.GetCommandProcessor^.AddCommand(ccUser3, 1, $1600, 0); {Alt-U Upper}
  TagES.GetCommandProcessor^.AddCommand(ccUser4, 1, $2600, 0); {Alt-L Lower}
  TagES.GetCommandProcessor^.AddCommand(ccUser5, 1, $3200, 0); {Alt-M Mixed}
  TagES.GetCommandProcessor^.AddCommand(ccUser6, 1, $2e00, 0); {Alt-C Clean}
  TagES.Select;
  Done := False;
  While Not Done Do
    Begin
    TagES.Process;
    Case TagES.GetLastCommand of
      ccUser1:
        Begin
        Cnt := Length(TagToEdit);
        TmpStr := '';
        While Cnt > 0 Do
          Begin
          TmpStr := TmpStr + TagToEdit[Cnt];
          Dec(Cnt);
          End;
        TagToEdit := TmpStr;
        TagES.Select;
        End;
      ccUser2:
        Begin
        TagToEdit := GreekStr(TagToEdit);
        TagES.Select;
        End;
      ccUser3:
        Begin
        TagToEdit := Upper(TagToEdit);
        TagES.Select;
        End;
      ccUser4:
        Begin
        TagToEdit := Lower(TagToEdit);
        TagES.Select;
        End;
      ccUser5:
        Begin
        TagToEdit := Proper(TagToEdit);
        TagES.Select;
        End;
      ccUser6:
        Begin
        Cnt := 1;
        While Cnt <= Length(TagToEdit) Do
          Begin
          TagToEdit[Cnt] := CleanChar(TagToEdit[Cnt]);
          Inc(Cnt);
          End;
        TagES.Select;
        End;
      ccQuit: Done := True;
      Else
        Begin
        Done := True;
        TagLineStr := TagToEdit;
        End;
      End;
    End;
  TagES.Erase;
  HideMouse;
  TagES.Done;
  End;



End.
