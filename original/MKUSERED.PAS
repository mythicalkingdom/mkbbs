{$V-}
{$M 32768, 200000, 650000}
Program MKUserEd;

{$I OPDEFINE.INC}
{$I MKB.DEF}

uses
  {$IFNDEF DPMI}
  Overlay,
  {$ENDIF}
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor, OpMenu,
  OpMouse,  OpDate,  OpAbsFld,  OpCmd,  OpField,  OpFrame, OpPick,
  OpWindow,  OpSelect,  OpEntry, MKName, MKGlobT, MKString, MKFile,
  MKCfgAbs, MKCfgMK, MKCfgRA, MKCfgSB, MKCfgQB, CfgSec2,
  MKMsgAbs, MKMsgHud, MKMsgFid, MKMsgSqu, MKDos, CfgYN, OpConst;

{$IFNDEF DPMI}
{$O MKCfgMK}
{$O MKCfgRA}
{$O MKCfgQB}
{$O MKCfgSB}
{$O MKMSGHud}
{$O MKMSGSqu}
{$O MKMSGFid}
{$O MKCfgAbs}
{$ENDIF}

const
  MouseChar  : Char = #04;

const
  Frame1 = '…»ªºÕÕ∫∫';
  WinOptions = wBordered+wClear+wUserContents+wResizeable;

const
  EsColors : ColorSet = (
    TextColor       : YellowOnBlue;       TextMono        : WhiteOnBlack;
    CtrlColor       : YellowOnBlue;       CtrlMono        : WhiteOnBlack;
    FrameColor      : WhiteOnBlue;        FrameMono       : LtGrayOnBlack;
    HeaderColor     : WhiteOnBlue;        HeaderMono      : BlackOnLtGray;
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
  miEdit0         = 0;
  miNext1         = 1;
  miPrior2        = 2;
  miFirst3        = 3;
  miLast4         = 4;
  miSearch5       = 5;
  miAdd6          = 6;
  miDelete7       = 7;
  miGoTo8         = 8;
  miValidate9     = 9;

{Entry field constants}
const
  idName                 = 0;
  idPassword             = idName + 1;
  idHandle               = idPassword + 1;
  idHomePhone            = idHandle + 1;
  idLocation             = idHomePhone + 1;
  idDataPhone            = idLocation + 1;
  idSecurity             = idDataPhone + 1;
  idNM                   = idSecurity + 1;
  idPending              = idNM + 1;
  idScrnLen              = idPending + 1;
  idEntered              = idScrnLen + 1;
  idTimes                = idEntered + 1;
  idElapsed              = idTimes + 1;
  idULFiles              = idElapsed + 1;
  idULK                  = idULFiles + 1;
  idDLFiles              = idULK + 1;
  idDLK                  = idDLFiles + 1;
  idTodayK               = idDLK + 1;
  idDeleted              = idTodayK + 1;
  idScrnClr              = idDeleted + 1;
  idMore                 = idScrnClr + 1;
  idAnsi                 = idMore + 1;
  idAvatar               = idAnsi + 1;
  idNoKill               = idAvatar + 1;
  idIgnoreHrs            = idNoKill + 1;
  idFullScr              = idIgnoreHrs + 1;
  idMale                 = idFullScr + 1;
  idVSysop               = idMale + 1;
  idHidden               = idVSysop + 1;
  idBirthdate            = idHidden + 1;
  idFirstCall            = idBirthdate + 1;
  idExpire               = idFirstCall + 1;
  idLastCall             = idExpire + 1;
  idLastTime             = idLastCall + 1;
  idNewDate              = idLastTime + 1;
  idPageTune             = idNewDate + 1;
  idPageBan              = idPageTune + 1;
  idAutoPage             = idPageBan + 1;
  idIgnorePg             = idAutoPage + 1;
  idAddress              = idIgnorePg + 1;
  idZipCode              = idAddress + 1;
  idComment              = idZipCode + 1;
  idProtocol             = idComment + 1;
  idPacker               = idProtocol + 1;
  idMaxMsg               = idPacker + 1;
  idMaxArea              = idMaxMsg + 1;
  idNetStat              = idMaxArea + 1;
  idOffNew = idNetStat + 1;
  idOffScrn = idOffNew + 1;
  idOffBull = idOffScrn + 1;
  idOffVerify = idOffBull + 1;
  idOffFlag = idOffVerify + 1;
  idOffOwn = idOffFlag + 1;
  idOffAll = idOffOwn + 1;
  idOffZero = idOffAll + 1;
  idOffGate = idOffZero + 1;
  idOffArea = idOffGate + 1;
  idBankMin              = idOffArea + 1;
  idBankByte             = idBankMin + 1;

{Help index constants}
const
  hiName                 = 1;
  hiPassword             = hiName + 1;
  hiHandle               = hiPassword + 1;
  hiHomePhone            = hiHandle + 1;
  hiLocation             = hiHomePhone + 1;
  hiDataPhone            = hiLocation + 1;
  hiSecurity             = hiDataPhone + 1;
  hiNM                   = hiSecurity + 1;
  hiPending              = hiNM + 1;
  hiScrnLen              = hiPending + 1;
  hiEntered              = hiScrnLen + 1;
  hiTimes                = hiEntered + 1;
  hiElapsed              = hiTimes + 1;
  hiULFiles              = hiElapsed + 1;
  hiULK                  = hiULFiles + 1;
  hiDLFiles              = hiULK + 1;
  hiDLK                  = hiDLFiles + 1;
  hiTodayK               = hiDLK + 1;
  hiDeleted              = hiTodayK + 1;
  hiScrnClr              = hiDeleted + 1;
  hiMore                 = hiScrnClr + 1;
  hiAnsi                 = hiMore + 1;
  hiAvatar               = hiAnsi + 1;
  hiNoKill               = hiAvatar + 1;
  hiIgnoreHrs            = hiNoKill + 1;
  hiFullScr              = hiIgnoreHrs + 1;
  hiMale                 = hiFullScr + 1;
  hiVSysop               = hiMale + 1;
  hiHidden               = hiVSysop + 1;
  hiBirthdate            = hiHidden + 1;
  hiFirstCall            = hiBirthdate + 1;
  hiExpire               = hiFirstCall + 1;
  hiLastCall             = hiExpire + 1;
  hiLastTime             = hiLastCall + 1;
  hiNewDate              = hiLastTime + 1;
  hiPageTune             = hiNewDate + 1;
  hiPageBan              = hiPageTune + 1;
  hiAutoPage             = hiPageBan + 1;
  hiIgnorePg             = hiAutoPage + 1;
  hiAddress              = hiIgnorePg + 1;
  hiZipCode              = hiAddress + 1;
  hiComment              = hiZipCode + 1;
  hiProtocol             = hiComment + 1;
  hiPacker               = hiProtocol + 1;
  hiMaxMsg               = hiPacker + 1;
  hiMaxArea              = hiMaxMsg + 1;
  hiNetStat              = hiMaxArea + 1;
  hiOffNew = hiNetStat + 1;
  hiOffScrn = hiOffNew + 1;
  hiOffBull = hiOffScrn + 1;
  hiOffVerify = hiOffBull + 1;
  hiOffFlag = hiOffVerify + 1;
  hiOffOwn = hiOffFlag + 1;
  hiOffAll = hiOffOwn + 1;
  hiOffZero = hiOffAll + 1;
  hiOffGate = hiOffZero + 1;
  hiOffArea = hiOffGate + 1;
  hiBankMin = hiOffArea + 1;
  hiBankByte             = hiBankMin + 1;


Type  UserRecord = Record
  Name                 : string[35];
  Password             : string[15];
  Handle               : string[35];
  HomePhone            : string[12];
  Location             : string[25];
  DataPhone            : string[12];
  Security: SecType;
  NM                   : Integer;
  Pending              : Integer;
  ScrnLen              : Word;
  Entered              : Word;
  Times                : Word;
  Elapsed              : Integer;
  ULFiles              : Word;
  ULK                  : Word;
  DLFiles              : Word;
  DLK                  : Word;
  TodayK               : Integer;
  Deleted              : Boolean;
  ScrnClr              : Boolean;
  More                 : Boolean;
  Ansi                 : Boolean;
  Avatar               : Boolean;
  NoKill               : Boolean;
  IgnoreHrs            : Boolean;
  FullScr              : Boolean;
  Male                 : Boolean;
  VSysop               : Boolean;
  Hidden               : Boolean;
  Birthdate            : String[8];
  FirstCall            : String[8];
  Expire               : String[8];
  LastCall             : String[8];
  LastTime             : Time;
  NewDate              : String[8];
  PageTune             : Byte;
  PageBan              : Boolean;
  AutoPage             : Boolean;
  IgnorePg             : Boolean;
  Address              : string[40];
  ZipCode              : string[10];
  Comment              : string[60];
  Protocol             : Char;
  Packer               : Char;
  MaxMsg               : Word;
  MaxArea              : Word;
  RealNetStat: LongInt;
  NetStat              : Char;
  OffNew: Boolean;
  OffScrn: Boolean;
  OffBull: Boolean;
  OffVerify: Boolean;
  OffFlag: Boolean;
  OffOwn: Boolean;
  OffAll: Boolean;
  OffZero: Boolean;
  OffGate: Boolean;
  BankMin              : LongInt;
  BankByte             : LongInt;
  UserNum: LongInt;
  Offline: Array[1..500] of Boolean;
  OffDisp: Char;
  End;


Type ValidateType = Record
  Sec: SecType;
  MsgName: String[13];
  MsgArea: Word;
  Priv: Boolean;
  End;


Type UserEdCfgType = Record
  VRec: Array[1..9] of ValidateType;
  End;


Var
  ES: ScrollingEntryScreen;
  UR: UserRecord;
  CES     : EntryScreen;
  VS: CommandWindow;
  Status: Word;
  BbsType: Word;
  UserEdCfg: UserEdCfgType;
  Password: String[15];
  GoToES: EntryScreen;
  GoToNum: Word;
  SearchES: EntryScreen;
  SearchName: String;


{$F+}
Procedure NetStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := 'Network - ' + Char(Item + Ord('A') - 1);
  End;


{$F+}
Procedure AreaSStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := Pad(Long2Str(Item),4) + Copy(Config^.GetMsgName(Item), 1, 19);
  End;


Procedure DoOfflinePick;
  Var
    AreaSPick: PickList;
    i: Word;

  Begin
  If Not AreaSPick.InitCustom(3,8,76,22,ESColors,
    wBordered+wClear+wUserContents,
    24, 500, AreaSStr,PickVertical, MultipleChoice) Then
    Halt;
  AreaSPick.wFrame.SetFrameType(Frame1);
  AreaSPick.wFrame.AddShadow(shBR, shSeeThru);
  AreaSPick.wFrame.AddHeaderColor('[ Offline Mail Areas ]', heTC, WhiteOnBlue, BlackOnLtGray);
  AreaSPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  AreaSPick.SetSelectMarker(' * ','');
  AreaSPick.AllocateSelectSet(501);
  For i := 1 to 500 Do
    Begin
    If UR.Offline[i] Then
      AreaSPick.SelectItem(i)
    Else
      AreaSPick.DeselectItem(i);
    End;
  AreaSPick.Process;
  For i := 1 to 500 Do
    Begin
    UR.Offline[i] := AreaSPick.ItemIsSelected(i);
    End;
  AreaSPick.Erase;
  AreaSPick.Done;
  End;


Procedure DoCfgNet;
  Var
    i: Word;
    ConfMask: LongInt;
    NetPick: PickList;

  Const
    One: LongInt=1;

  Begin
  If Not NetPick.InitCustom(3,8,76,22,ESColors,
    wBordered+wClear+wUserContents,
    24, 26, NetStr,PickVertical, MultipleChoice) Then
    Halt;
  NetPick.wFrame.SetFrameType(Frame1);
  NetPick.wFrame.AddShadow(shBR, shSeeThru);
  NetPick.wFrame.AddHeaderColor('[ Networks ]', heTC, WhiteOnBlue, BlackOnLtGray);
  NetPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '≤', '∞', EsColors);
  NetPick.SetSelectMarker(' * ','');
  NetPick.AllocateSelectSet(26);
  ConfMask := 1;
  For i := 1 to 26 Do
    Begin
    If (ConfMask and UR.RealNetStat) <> 0 Then
      NetPick.SelectItem(i)
    Else
      NetPick.DeSelectItem(i);
    ConfMask := ConfMask shl 1;
    End;
  NetPick.Process;
  ConfMask := 1;
  UR.RealNetStat := 0;
  For i := 1 to 26 Do
    Begin
    If NetPick.ItemIsSelected(i) Then
      UR.RealNetStat := UR.RealNetStat or ConfMask;
    ConfMask := ConfMask shl 1;
    End;
  NetPick.Erase;
  NetPick.Done;
  End;


Procedure GetNet(Var ESP: EntryScreenPtr; ScreenNo: Word);
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
          DoCfgNet;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure GetOfflineAreas(Var ESP: EntryScreenPtr; ScreenNo: Word);
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
          DoOfflinePick;
          ESP^.DrawField(ScreenNo);
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
      idPassword: Begin
        UR.Password := Password;
        ESP^.DrawField(idPassword);
        End;
      idHandle               : ;
      idHomePhone            : ;
      idLocation             : ;
      idDataPhone            : ;
      idSecurity: GetSecurity(UR.Security, ESP, idSecurity,'[ User Security ]');
      idNM                   : ;
      idPending              : ;
      idScrnLen              : ;
      idEntered              : ;
      idTimes                : ;
      idElapsed              : ;
      idULFiles              : ;
      idULK                  : ;
      idDLFiles              : ;
      idDLK                  : ;
      idTodayK               : ;
      idDeleted              : ;
      idScrnClr              : ;
      idMore                 : ;
      idAnsi                 : ;
      idAvatar               : ;
      idNoKill               : ;
      idIgnoreHrs            : ;
      idFullScr              : ;
      idMale                 : ;
      idVSysop               : ;
      idHidden               : ;
      idBirthdate            : ;
      idFirstCall            : ;
      idExpire               : ;
      idLastCall             : ;
      idLastTime             : ;
      idNewDate              : ;
      idPageTune             : ;
      idPageBan              : ;
      idAutoPage             : ;
      idIgnorePg             : ;
      idAddress              : ;
      idZipCode              : ;
      idComment              : ;
      idProtocol             : ;
      idPacker               : ;
      idMaxMsg               : ;
      idMaxArea              : ;
      idNetStat: GetNet(ESP, idNetStat);
      idOffArea: GetOfflineAreas(ESP, idOffArea);
      idBankMin              : ;
      idBankByte             : ;
    end;
end;

procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idName                 : ;
      idPassword: Begin
        Password := UR.Password;
        UR.Password := '';
        ESP^.DrawField(idPassword);
        End;
      idHandle               : ;
      idHomePhone            : ;
      idLocation             : ;
      idDataPhone            : ;
      idSecurity             : ;
      idNM                   : ;
      idPending              : ;
      idScrnLen              : ;
      idEntered              : ;
      idTimes                : ;
      idElapsed              : ;
      idULFiles              : ;
      idULK                  : ;
      idDLFiles              : ;
      idDLK                  : ;
      idTodayK               : ;
      idDeleted              : ;
      idScrnClr              : ;
      idMore                 : ;
      idAnsi                 : ;
      idAvatar               : ;
      idNoKill               : ;
      idIgnoreHrs            : ;
      idFullScr              : ;
      idMale                 : ;
      idVSysop               : ;
      idHidden               : ;
      idBirthdate            : ;
      idFirstCall            : ;
      idExpire               : ;
      idLastCall             : ;
      idLastTime             : ;
      idNewDate              : ;
      idPageTune             : ;
      idPageBan              : ;
      idAutoPage             : ;
      idIgnorePg             : ;
      idAddress              : ;
      idZipCode              : ;
      idComment              : ;
      idProtocol             : ;
      idPacker               : ;
      idMaxMsg               : ;
      idMaxArea              : ;
      idNetStat              : ;
      idBankMin              : ;
      idBankByte             : ;
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


procedure CDisplayHelp(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
  {-Display context sensitive help}
begin
end;


Function InitEntryScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
begin
  with ES do begin
    if not InitCustom(2, 2, 79, 22, EsColors, WinOptions) then begin
      InitEntryScreen := InitStatus;
      Exit;
    end;
    SetPassWordChar('*');
    wFrame.SetFrameType(Frame1);
{    wFrame.AddHeader('[ MKUser User Editor ]', heTC);}
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(WrapAtEdges);

    SetPreEditProc(PreEdit);
    SetPostEditProc(PostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);

  {idName:}
    AddStringField(
      'Name:', 1, 3,
      CharStr('X', 35), 1, 9, 35,
      hiName, UR.Name);

  {idPassword:}
    AddStringField(
      'Password:', 1, 49,
      'XXXXXXXXXXXXXXX', 1, 59, 15,
      hiPassword, UR.Password);

  {idHandle:}
    AddStringField(
      'Handle:', 2, 3,
      CharStr('X', 35), 2, 11, 35,
      hiHandle, UR.Handle);

  {idHomePhone:}
    AddStringField(
      'Home Phone:', 2, 49,
      'XXXXXXXXXXXX', 2, 61, 12,
      hiHomePhone, UR.HomePhone);

  {idLocation:}
    AddStringField(
      'Location:', 3, 3,
      CharStr('X', 25), 3, 13, 25,
      hiLocation, UR.Location);

  {idDataPhone:}
    AddStringField(
      'Data Phone:', 3, 49,
      'XXXXXXXXXXXX', 3, 61, 12,
      hiDataPhone, UR.DataPhone);

  {idSecurity:}
    AddWordField(
      'Security:', 5, 3,
      '99999', 5, 13,
      hiSecurity, 0, 65535, UR.Security.Level);

  {idNM:}
    AddIntField(
      'Credit:', 5, 20,
      '99999', 5, 28,
      hiNM, -32768, 32767, UR.NM);

  {idPending:}
    AddIntField(
      'Pending:', 5, 35,
      '99999', 5, 44,
      hiPending, -32768, 32767, UR.Pending);

  {idScrnLen:}
    AddWordField(
      'Screen Length:', 5, 51,
      '999', 5, 66,
      hiScrnLen, 0, 65535, UR.ScrnLen);

  {idEntered:}
    AddWordField(
      'Msgs Entered:', 6, 3,
      '99999', 6, 17,
      hiEntered, 0, 65535, UR.Entered);

  {idTimes:}
    AddWordField(
      'Times Called:', 6, 24,
      '99999', 6, 38,
      hiTimes, 0, 65535, UR.Times);

  {idElapsed:}
    AddIntField(
      'Elapsed Time:', 6, 45,
      '99999', 6, 59,
      hiElapsed, -32768, 32767, UR.Elapsed);

  {idULFiles:}
    AddWordField(
      'UL #:', 7, 3,
      '99999', 7, 9,
      hiULFiles, 0, 65535, UR.ULFiles);

  {idULK:}
    AddWordField(
      'UL Kb:', 7, 16,
      '99999', 7, 23,
      hiULK, 0, 65535, UR.ULK);

  {idDLFiles:}
    AddWordField(
      'DL #:', 7, 30,
      '99999', 7, 36,
      hiDLFiles, 0, 65535, UR.DLFiles);

  {idDLK:}
    AddWordField(
      'DL Kb:', 7, 43,
      '99999', 7, 50,
      hiDLK, 0, 65535, UR.DLK);

  {idTodayK:}
    AddIntField(
      'Today Kb:', 7, 57,
      '99999', 7, 67,
      hiTodayK, -32768, 32767, UR.TodayK);

  {idDeleted:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Deleted:', 8, 3,
      'Y', 8, 12,
      hiDeleted, UR.Deleted);
    esFieldOptionsOff(efClickExit);

  {idScrnClr:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Screen Clear:', 8, 16,
      'Y', 8, 30,
      hiScrnClr, UR.ScrnClr);
    esFieldOptionsOff(efClickExit);

  {idMore:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'More:', 8, 34,
      'Y', 8, 40,
      hiMore, UR.More);
    esFieldOptionsOff(efClickExit);

  {idAnsi:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Ansi:', 8, 44,
      'Y', 8, 50,
      hiAnsi, UR.Ansi);
    esFieldOptionsOff(efClickExit);

  {idAvatar:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Avatar:', 8, 54,
      'Y', 8, 62,
      hiAvatar, UR.Avatar);
    esFieldOptionsOff(efClickExit);

  {idNoKill:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'No Kill:', 8, 66,
      'Y', 8, 75,
      hiNoKill, UR.NoKill);
    esFieldOptionsOff(efClickExit);

  {idIgnoreHrs:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Ignore Hrs:', 9, 3,
      'Y', 9, 15,
      hiIgnoreHrs, UR.IgnoreHrs);
    esFieldOptionsOff(efClickExit);

  {idFullScr:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Full Scrn Editor:', 9, 19,
      'Y', 9, 37,
      hiFullScr, UR.FullScr);
    esFieldOptionsOff(efClickExit);

  {idMale:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Male:', 9, 40,
      'Y', 9, 46,
      hiMale, UR.Male);
    esFieldOptionsOff(efClickExit);

  {idVSysop:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Visit Sysop:', 9, 50,
      'Y', 9, 63,
      hiVSysop, UR.VSysop);
    esFieldOptionsOff(efClickExit);

  {idHidden:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Hidden:', 9, 66,
      'Y', 9, 74,
      hiHidden, UR.Hidden);
    esFieldOptionsOff(efClickExit);

  {idBirthdate:}
    esFieldOptionsOff(efTrimBlanks);
    AddDateStField(
      'Birthdate:', 11, 3,
      'mm-dd-yy', 11, 14,
      hiBirthdate, UR.Birthdate);
    esFieldOptionsOn(efTrimBlanks);

  {idFirstCall:}
    esFieldOptionsOff(efTrimBlanks);
    AddDateStField(
      'First Called:', 11, 24,
      'mm-dd-yy', 11, 38,
      hiFirstCall, UR.FirstCall);
    esFieldOptionsOn(efTrimBlanks);

  {idExpire:}
    esFieldOptionsOff(efTrimBlanks);
    AddDateStField(
      'Expiration:', 11, 48,
      'mm-dd-yy', 11, 60,
      hiExpire, UR.Expire);
    esFieldOptionsOn(efTrimBlanks);

  {idLastCall:}
    esFieldOptionsOff(efTrimBlanks);
    AddDateStField(
      'Last Called', 12, 3,
      'mm-dd-yy', 12, 15,
      hiLastCall, UR.LastCall);
    esFieldOptionsOn(efTrimBlanks);

  {idLastTime:}
    AddTimeField(
      '', 12, 25,
      'hh:mm', 12, 25,
      hiLastTime, MinTime, MinTime, UR.LastTime);

  {idNewDate:}
    esFieldOptionsOff(efTrimBlanks);
    AddDateStField(
      'New Files Date:', 12, 32,
      'mm-dd-yy', 12, 48,
      hiNewDate, UR.NewDate);
    esFieldOptionsOn(efTrimBlanks);

  {idPageTune:}
    AddByteField(
      'Page Tune:', 14, 3,
      '999', 14, 14,
      hiPageTune, 0, 255, UR.PageTune);

  {idPageBan:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Page Ban:', 14, 20,
      'Y', 14, 30,
      hiPageBan, UR.PageBan);
    esFieldOptionsOff(efClickExit);

  {idAutoPage:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Auto Page:', 14, 34,
      'Y', 14, 45,
      hiAutoPage, UR.AutoPage);
    esFieldOptionsOff(efClickExit);

  {idIgnorePg:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Ignore Page Hrs:', 14, 49,
      'Y', 14, 66,
      hiIgnorePg, UR.IgnorePg);
    esFieldOptionsOff(efClickExit);

  {idAddress:}
    AddStringField(
      'Address:', 16, 3,
      CharStr('X', 40), 16, 12, 40,
      hiAddress, UR.Address);

  {idZipCode:}
    AddStringField(
      'Zip Code:', 16, 55,
      'XXXXXXXXXX', 16, 65, 10,
      hiZipCode, UR.ZipCode);

  {idComment:}
    AddStringField(
      'Comment:', 17, 3,
      CharStr('X', 60), 17, 12, 60,
      hiComment, UR.Comment);

  {idProtocol:}
    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Protocol:', 18, 3,
      'X', 18, 13,
      hiProtocol, #0, #0, UR.Protocol);
    esFieldOptionsOn(efTrimBlanks);

  {idPacker:}
    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Packer:', 18, 16,
      'X', 18, 24,
      hiPacker, #0, #0, UR.Packer);
    esFieldOptionsOn(efTrimBlanks);

  {idMaxMsg:}
    AddWordField(
      'Max Msgs:', 18, 27,
      '99999', 18, 37,
      hiMaxMsg, 0, 65535, UR.MaxMsg);

  {idMaxArea:}
    AddWordField(
      'Max Per Area:', 18, 44,
      '9999', 18, 58,
      hiMaxArea, 0, 65535, UR.MaxArea);

  {idNetStat:}
    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Net Status:', 18, 64,
      'X', 18, 76,
      hiNetStat, #0, #0, UR.NetStat);
    esFieldOptionsOn(efTrimBlanks);

    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Off New Files:', 19, 3,
      'Y', 19, 18,
      hiOffNew, UR.OffNew);

    AddYesNoField(
      'Off Scrns:', 19, 21,
      'Y', 19, 32,
      hiOffScrn, UR.OffScrn);

    AddYesNoField(
      'Off Bulls:', 19, 35,
      'Y', 19, 46,
      hiOffBull, UR.OffBull);

    AddYesNoField(
      'Off Verify:', 19, 49,
      'Y', 19, 61,
      hiOffVerify, UR.OffVerify);

    AddYesNoField(
      'Off Flag:', 19, 64,
      'Y', 19, 74,
      hiOffFlag, UR.OffFlag);

    AddYesNoField(
      'Off Own Msg:', 20, 3,
      'Y', 20, 16,
      hiOffOwn, UR.OffOwn);

    AddYesNoField(
      'Off All Your:', 20, 18,
      'Y', 20, 32,
      hiOffAll, UR.OffAll);

    AddYesNoField(
      'Off Zero Pkt:', 20, 34,
      'Y', 20, 48,
      hiOffZero, UR.OffZero);

    AddYesNoField(
      'Off GateWay:', 20, 50,
      'Y', 20, 63,
      hiOffGate, UR.OffGate);

    esFieldOptionsOff(efClickExit);

    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Areas:', 20, 65,
      'X', 20, 72,
      hiOffArea, #0, #0, UR.OffDisp);
    esFieldOptionsOn(efTrimBlanks);

  {idBankMin:}
    AddLongField(
      'Time Bank Minutes:', 21, 3,
      '99999', 21, 22,
      hiBankMin, $80000000, $7FFFFFFF, UR.BankMin);

  {idBankByte:}
    AddLongField(
      'Time Bank Bytes:', 21, 29,
      '99999999', 21, 46,
      hiBankByte, $80000000, $7FFFFFFF, UR.BankByte);

    esFieldOptionsOn(efProtected);
    AddLongField(
      'User Number:', 21, 58,
      '99999', 21, 71,
      hiBankByte + 1, 0, $7FFFFFFF, UR.UserNum);
    esFieldOptionsOff(efProtected);

    AllocateScreen;

    InitEntryScreen := RawError;
  end;
end;


Procedure DefaultUser;
  Var
    i: Word;

  Begin
  UR.Name := '';
  Password := '';
  UR.Password := '';
  UR.Handle := '';
  UR.HomePhone := '';
  UR.Location := '';
  UR.DataPhone := '';
  UR.Security.Level := 0;
  UR.Security.Flags := 0;
  UR.NM := 0;
  UR.Pending := 0;
  UR.ScrnLen := 23;
  UR.Entered := 0;
  UR.Times := 0;
  UR.Elapsed := 0;
  UR.ULFiles := 0;
  UR.ULK := 0;
  UR.DLFiles := 0;
  UR.DLK := 0;
  UR.TodayK := 0;
  UR.Deleted := False;
  UR.ScrnClr := True;
  UR.More := True;
  UR.Ansi := False;
  UR.NoKill := False;
  UR.IgnoreHrs := False;
  UR.FullScr := False;
  UR.UserNum := NameSearch.GetPos;
  UR.BirthDate := '';
  UR.FirstCall := '';
  UR.LastCall := '';
  UR.LastTime := TimeStringToTime('hh:mm', '00:00');
  UR.Avatar := False;
  UR.Comment := '';
  UR.PageTune := 1;
  UR.Protocol := #0;
  UR.BankMin := 0;
  UR.Expire := '';
  UR.Packer := #0;
  UR.NewDate := '';
  UR.Address := '';
  UR.ZipCode := '';
  UR.OffNew := False;
  UR.OffScrn := True;
  UR.OffBull := True;
  UR.OffVerify := False;
  UR.OffFlag := True;
  UR.OffOwn := True;
  UR.OffAll := True;
  UR.OffZero := False;
  UR.OffGate := False;
  UR.RealNetStat := 0;
  UR.NetStat := '*';
  For i := 1 to 500 Do
    UR.Offline[i] := False;
  ES.Select;
  ES.ResetScreen;
  End;


Procedure RefreshUser;
  Var
    i: Word;

  Begin
  UR.Name := NameSearch.GetName;
  Password := NameSearch.GetPwd;
  UR.Password := '';
  UR.Handle := NameSearch.GetHandle;
  UR.HomePhone := NameSearch.GetVoicePhone;
  UR.Location := NameSearch.GetLocation;
  UR.DataPhone := NameSearch.GetDataPhone;
  NameSearch.GetSec(UR.Security);
  UR.NM := NameSearch.GetNMCredit;
  UR.Pending := NameSearch.GetNMPending;
  UR.ScrnLen := NameSearch.GetScrnLen;
  UR.Entered := NameSearch.GetMsgsEntered;
  UR.Times := NameSearch.GetTimesCalled;
  UR.Elapsed := NameSearch.GetElapsed;
  UR.ULFiles := NameSearch.GetULFiles;
  UR.ULK := NameSearch.GetULK;
  UR.DLFiles := NameSearch.GetDLFiles;
  UR.DLK := NameSearch.GetDLK;
  UR.TodayK := NameSearch.GetTodayK;
  UR.Deleted := NameSearch.IsDeleted;
  UR.ScrnClr := NameSearch.IsScrnClr;
  UR.More := NameSearch.IsMore;
  UR.Ansi := NameSearch.IsAnsi;
  UR.NoKill := NameSearch.IsNoKill;
  UR.IgnoreHrs := NameSearch.IsIgnoreHrs;
  UR.FullScr := NameSearch.IsFullScrn;
  UR.UserNum := NameSearch.GetPos;
  UR.BirthDate := NameSearch.GetBirthDate; { *** }
  UR.FirstCall := NameSearch.GetFirstDate;
  UR.LastCall := NameSearch.GetLastDate;
  UR.LastTime := TimeStringToTime('hh:mm', NameSearch.GetLastTime);
  UR.Avatar := NameSearch.IsAvatar;
  UR.Comment := NameSearch.GetComment;
  UR.PageTune := NameSearch.GetPageTune;
  UR.Protocol := NameSearch.GetProt;
  UR.BankMin := NameSearch.GetBankTime;
  UR.Expire := NameSearch.GetExpire;
  UR.Packer := NameSearch.GetPacker;
  UR.NewDate := NameSearch.GetNewDate;
  UR.Address := NameSearch.GetAddr;
  UR.ZipCode := NameSearch.GetZip;
  UR.MaxMsg := NameSearch.GetOffMax;
  UR.MaxArea := NameSearch.GetOffConfMax;
  UR.OffNew := NameSearch.GetOffNew;
  UR.OffScrn := NameSearch.GetOffScrn;
  UR.OffBull := NameSearch.GetOffBull;
  UR.OffVerify := NameSearch.GetOffVerify;
  UR.OffFlag := NameSearch.GetOffFlag;
  UR.OffOwn := NameSearch.GetOffOwn;
  UR.OffAll := NameSearch.GetOffAll;
  UR.OffZero := NameSearch.GetOffZero;
  UR.OffGate := NameSearch.GetOffGate;
  UR.RealNetStat := NameSearch.GetNetStatus;
  For i := 1 to 500 Do
    UR.Offline[i] := NameSearch.GetUserOffline(i);
  ES.Select;
  ES.ResetScreen;
  End;


Procedure RefreshFile;
  Var
    i: Word;

  Begin
  NameSearch.SetName(UR.Name);
  NameSearch.SetHandle(UR.Handle);
  NameSearch.SetPwd(Password);
  NameSearch.SetVoicePhone(UR.HomePhone);
  NameSearch.SetLocation(UR.Location);
  NameSearch.SetDataPhone(UR.DataPhone);
  NameSearch.SetSec(UR.Security);
  NameSearch.SetNMCredit(UR.NM);
  NameSearch.SetNMPending(UR.Pending);
  NameSearch.SetScrnLen(UR.ScrnLen);
  NameSearch.SetMsgsEntered(UR.Entered);
  NameSearch.SetTimesCalled(UR.Times);
  NameSearch.SetElapsed(UR.Elapsed);
  NameSearch.SetULFiles(UR.ULFiles);
  NameSearch.SetULK(UR.ULK);
  NameSearch.SetDLFiles(UR.DLFiles);
  NameSearch.SetDLK(UR.DLK);
  NameSearch.SetTodayK(UR.TodayK);
  NameSearch.SetDelete(UR.Deleted);
  NameSearch.SetScrnClr(UR.ScrnClr);
  NameSearch.SetMore(UR.More);
  NameSearch.SetAnsi(UR.Ansi);
  NameSearch.SetNoKill(UR.NoKill);
  NameSearch.SetIgnoreHrs(UR.IgnoreHrs);
  NameSearch.SetFullScrn(UR.FullScr);
  NameSearch.SetBirthDate(UR.BirthDate);
  NameSearch.SetFirstDate(UR.FirstCall);
  NameSearch.SetLastDate(UR.LastCall);
  NameSearch.SetLastTime(TimeToTimeString('hh:mm', UR.LastTime));
  NameSearch.SetAvatar(UR.Avatar);
  NameSearch.SetComment(UR.Comment);
  NameSearch.SetPageTune(UR.PageTune);
  NameSearch.SetProt(UR.Protocol);
  NameSearch.SetBankTime(UR.BankMin);
  NameSearch.SetExpire(UR.Expire);
  NameSearch.SetPacker(UpCase(UR.Packer));
  NameSearch.SetNewDate(UR.NewDate);
  NameSearch.SetAddr(UR.Address);
  NameSearch.SetZip(UR.ZipCode);
  NameSearch.SetOffMax(UR.MaxMsg);
  NameSearch.SetOffConfMax(UR.MaxArea);
  NameSearch.SetOffNew(UR.OffNew);
  NameSearch.SetOffScrn(UR.OffScrn);
  NameSearch.SetOffBull(UR.OffBull);
  NameSearch.SetOffVerify(UR.OffVerify);
  NameSearch.SetOffFlag(UR.OffFlag);
  NameSearch.SetOffOwn(UR.OffOwn);
  NameSearch.SetOffAll(UR.OffAll);
  NameSearch.SetOffZero(UR.OffZero);
  NameSearch.SetOffGate(UR.OffGate);
  NameSearch.SetNetStatus(UR.RealNetStat);
  For i := 1 to 500 Do
    NameSearch.SetUserOffline(i, UR.Offline[i]);
  NameSearch.SaveChanges;
  End;


Procedure InitEdit;
  Begin
  ClrScr;
  If MouseInstalled then
    with EsColors do
    begin
    SoftMouseCursor($0000, (ColorMono(MouseColor, MouseMono) shl 8)+
                             Byte(MouseChar));
    ShowMouse;
    EntryCommands.cpOptionsOn(cpEnableMouse);
    end;
  Status := InitEntryScreen;
  If Status <> 0 then
    begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
    End;
  FillChar(UR, SizeOf(UR), 0);
  UR.LastTime := BadTime;
  UR.Protocol := ' ';
  UR.Packer := ' ';
  UR.NetStat := ' ';
  UR.OffDisp := ' ';
  ES.Select;
  RefreshUser;
  ES.Draw;
  End;



{$F+}
procedure CustomizeItemString(var Name : String; Key : LongInt;
                              Selected, Highlighted : Boolean;
                              WPtr : RawWindowPtr);
  {-Customize menu item strings}
begin
end;


function InitMenu(var M : Menu) : Word;
  {-Initialize menu system generated by MAKEMENU}
  begin
  with M do
    begin
    if not InitCustom(1, 24, 80, 24, ESColors,
                      wClear+wUserContents+wCoversOnDemand,
                      Horizontal) then begin
      InitMenu := InitStatus;
      Exit;
    end;
    mnOptionsOn(mnAlphaMatch+mnSelectOnMatch+mnArrowSelect+mnAllHotSpots);
    mnOptionsOff(mnAllowPending+mnPopOnSelect+mnUseItemForTopic+
                 mnSelectOnClick+mnAltMatch);
    AddItemHelp('Edit', 3, 1, miEdit0,
                '  Edit User');
    AddItemHelp('Next', 10, 1, miNext1,
                '  Next User');
    AddItemHelp('Prior', 17, 1, miPrior2,
                '  Prior User');
    AddItemHelp('First', 25, 1, miFirst3,
                '  Go To First User Record');
    AddItemHelp('Last', 33, 1, miLast4,
                '  Go To Last User Record');
    AddItemHelp('Search', 40, 1, miSearch5,
                '  Search for specific user name');
    AddItemHelp('Add', 49, 1, miAdd6,
                '  Add User');
    AddItemHelp('Delete', 55, 1, miDelete7,
                '  Toggle Delete User');
    AddItemHelp('GoTo', 64, 1, miGoTo8,
                '  Go To Specifc User Number');
    AddItemHelp('Validate', 71, 1, miValidate9,
                '  Validate Current User');
    ItemsDone;

    SetErrorProc(ErrorHandler);
    MenuCommands.SetHelpProc(DisplayHelp);
    SetCustomStringProc(CustomizeItemString);

    InitMenu := RawError;
    end;
  end;


function InitHelpLine(var H : RawWindow) : Word;
  {-Initialize window for the help line}
var
  Row : Byte;
begin
  Row := 25;
  if not H.InitCustom(1, Row, ScreenWidth, Row,
                      ESColors, wClear) then begin
    InitHelpLine := InitStatus;
    Exit;
  end;
  H.SetTextAttr(YellowOnBlue, LtGrayOnBlack);
  InitHelpLine := 0;
end;


  var
  M      : Menu;      {menu system}
  H      : RawWindow; {item help window}

procedure UpdateHelpLine(CurrentItem : MenuItemNodePtr; MPtr : MenuPtr);
  {-Update HelpLine for each menu item}
var
  S : String;
begin
  if CurrentItem = nil then
    S := ''
  else
    S := CurrentItem^.HelpString;
  H.wFastText(Pad(S, H.Width), 1, 1);
end;


{$F+}
procedure CPreEdit(ESP : EntryScreenPtr);
  begin
  Case ESP^.GetCurrentId Of
    00: GetSecurity(UserEdCfg.VRec[1].Sec,ESP, 00,'[ Template 1 Sec ]');
    04: GetSecurity(UserEdCfg.VRec[2].Sec,ESP, 04,'[ Template 2 Sec ]');
    08: GetSecurity(UserEdCfg.VRec[3].Sec,ESP, 08,'[ Template 3 Sec ]');
    12: GetSecurity(UserEdCfg.VRec[4].Sec,ESP, 12,'[ Template 4 Sec ]');
    16: GetSecurity(UserEdCfg.VRec[5].Sec,ESP, 16,'[ Template 5 Sec ]');
    20: GetSecurity(UserEdCfg.VRec[6].Sec,ESP, 20,'[ Template 6 Sec ]');
    24: GetSecurity(UserEdCfg.VRec[7].Sec,ESP, 24,'[ Template 7 Sec ]');
    28: GetSecurity(UserEdCfg.VRec[8].Sec,ESP, 28,'[ Template 8 Sec ]');
    32: GetSecurity(UserEdCfg.VRec[9].Sec,ESP, 32,'[ Template 9 Sec ]');
    End;
  end;

procedure CPostEdit(ESP : EntryScreenPtr);
  begin
  end;


function InitCEntryScreen : Word;
  const
    Frame1 = '…»ªºÕÕ∫∫';
    WinOptions = wBordered+wClear+wUserContents;

  Var
    Ct: Word;

  begin
  with CES do begin
    if not InitCustom(12, 5, 59, 17, EsColors, WinOptions) then
      begin
      InitCEntryScreen := InitStatus;
      Exit;
      end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ Validation Templates ]', heTC);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(WrapAtEdges);

    SetPreEditProc(CPreEdit);
    SetPostEditProc(CPostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(CDisplayHelp);

    AddTextField(
      'Security', 2, 7);
    AddTextField(
      'FileName', 2, 18);
    AddTextField(
      'Area', 2, 33);
    AddTextField(
      'Priv', 2, 40);


   For Ct := 1 to 9 Do
     Begin
     AddWordField(
      '#' + Long2Str(Ct) + ':', 3 + Ct, 4,
      '99999', 3 + Ct, 8,
      1, 0, 65535, UserEdCfg.VRec[Ct].Sec.Level);

  {idMsgName:}
    AddStringField(
      '', 3 + Ct, 16,
      'XXXXXXXXXXXXX', Ct + 3, 16, 13,
      1, UserEdCfg.VRec[Ct].MsgName);

  {idMsgArea:}
    AddWordField(
      '', 3 + Ct, 33,
      '9999', 3 + Ct, 33,
      1, 0, 65535, UserEdCfg.VRec[Ct].MsgArea);

  {idPriv:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      '', 3 + Ct, 42,
      'Y', 3 + Ct, 42,
      1, UserEdCfg.VRec[Ct].Priv);
    esFieldOptionsOff(efClickExit);
    End;

    InitCEntryScreen := RawError;
    end;
  end;


Procedure DoCfgEdit;
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
  Status := InitCEntryScreen;
  if Status <> 0 then begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
  end;
  CES.Process;
  CES.Erase;
  HideMouse;
  CES.Done;
  End;


Procedure SendMsg(ValNum: Word);
  Var
    NewArea: Word;
    TMsg: AbsMsgPtr;
    TempAddr: AddrType;
    TF: TFile;
    TmpStr: String;
    MError: Word;

  Begin
  MError := 0;
  If FileExist(Config^.GetBbsPath + UserEdCfg.VRec[ValNum].MsgName) Then
    Begin
    TF.Init;
    If Not TF.OpenTextFile(Config^.GetBbsPath + UserEdCfg.VRec[ValNum].MsgName) Then
      MError := 1;
    NewArea := UserEdCfg.VRec[ValNum].MsgArea;
    Case Config^.GetMsgBaseType(NewArea) Of
      'S': TMsg := New(SqMsgPtr, Init);
      'H': TMsg := New(HudsonMsgPtr, Init);
      'F': TMsg := New(FidoMsgPtr, Init);
      End;
    Tmsg^.SetMsgPath(Copy(Config^.GetMsgAreaId(NewArea),2,128));
    If TMsg^.OpenMsgBase <> 0 Then;
      Begin
      TMsg^.StartNewMsg;
      Case Config^.GetMsgType(NewArea) of
        Normal: TMsg^.SetMailType(mmtNormal);
        EchoMail: TMsg^.SetMailType(mmtEchoMail);
        NetMail: TMsg^.SetMailType(mmtNetMail);
        End;
      If Config^.GetMsgType(NewArea) = Netmail Then
        Begin
        Config^.GetMsgAddr(NewArea, TempAddr);
        TMsg^.SetOrig(TempAddr);
        TMsg^.SetDest(TempAddr);
        End;
      TmpStr := Proper(TF.GetString);
      TMsg^.SetFrom(TmpStr);
      TMsg^.SetTo(UR.Name);
      TmpStr := Proper(TF.GetString);
      TMsg^.SetSubj(TmpStr);
      TMsg^.SetPriv(UserEdCfg.VRec[ValNum].Priv);
      TMsg^.SetDate(DateStr(GetDosDate));
      TMsg^.SetTime(TimeStr(GetDosDate));
      TMsg^.SetLocal(True);
      TMsg^.SetEcho(False);
      TmpStr := TF.GetString;
      If TF.StringFound Then
        Begin
        While TF.StringFound Do
          Begin
          TMsg^.DoStringLn(TmpStr);
          TmpStr := TF.GetString;
          End;
        If TMsg^.WriteMsg = 0 Then;
        End;
      If TMsg^.CloseMsgBase <> 0 Then;
      End;
    If TF.CloseTextFile Then;
    TF.Done;
    Dispose(TMsg, Done);
    End;
  End;


Procedure ValidateUser(ValNum: Word);
  Var
    OS: Word;

  Begin
  UR.Security.Level := UserEdCfg.VRec[ValNum].Sec.Level;
  UR.Security.Flags := UR.Security.Flags Or UserEdCfg.VRec[ValNum].Sec.Flags;
  OS := DoYesNo('[ Send Message ]', True);
  Case OS of
    1: SendMsg(ValNum);
    2: ; {No msg}
    End;
  RefreshFile;
  End;


Type ValWindow = Object(CommandWindow)
  Procedure Process; Virtual;
  End;


Procedure ValWindow.Process;
  Begin
  Repeat
    GetNextCommand;
    Case GetLastCommand of
      ccUser1: ValidateUser(1);
      ccUser2: ValidateUser(2);
      ccUser3: ValidateUser(3);
      ccUser4: ValidateUser(4);
      ccUser5: ValidateUser(5);
      ccUser6: ValidateUser(6);
      ccUser7: ValidateUser(7);
      ccUser8: ValidateUser(8);
      ccUser9: ValidateUser(9);
      End;
    Until (GetLastCommand = ccQuit) or (GetLastCommand = ccError);
  End;


Procedure FillInAnswers;
  Var
    T: TFile;
    TmpStr: String;
    i: Word;
    SearchStr: String;

  Begin
  T.Init;
  SearchStr := '*** ' + UR.Name + ' completed questionaire';
  If T.OpenTextFile(Config^.GetBbsPath + 'NewUser.Asw') Then
    Begin
    TmpStr := T.GetString;
    While ((T.StringFound) and (Pos(SearchStr, TmpStr) = 0)) Do
      TmpStr := T.GetString;
    If Pos(SearchStr, TmpStr) > 0 Then
      Begin
      WriteLn(Copy(TmpStr, 1, 69));
      i := 1;
      TmpStr := T.GetString;
      While ((i < 16) and (Copy(TmpStr,1,3) <> '***') and (T.StringFound)) Do
        Begin
        WriteLn(Copy(TmpStr, 1, 69));
        TmpStr := T.GetString;
        End;
      End
    Else
      Begin
      WriteLn('Users answers not found');
      End;
    If T.CloseTextFile Then;
    End
  Else
    Begin
    WriteLn('Unable to open NewUser.Asw File');
    End;
  T.Done;
  End;



Procedure Validate;
  Const
    KeyMax = 50;
    KeySet: Array[0..KeyMax] of Byte = (
      2, $31, ccUser1,
      2, $32, ccUser2,
      2, $33, ccUser3,
      2, $34, ccUser4,
      2, $35, ccUser5,
      2, $36, ccUser6,
      2, $37, ccUser7,
      2, $38, ccUser8,
      2, $39, ccUser9,
      2, $1b, ccQuit,
      2, Ord('Q'), ccQuit,
      2, Ord('q'), ccQuit,
      2, Ord('N'), ccQuit,
      2, Ord('n'), ccQuit,
      0,0,0,0,0,0,0,0,0);

  Const
    Frame1 = '…»ªºÕÕ∫∫';

  Var
    VC: ^CommandProcessor;
    VS: ^ValWindow;
    Finished: Boolean;

  Begin
  Finished := False;
  New(VC);
  VC^.Init(@KeySet, KeyMax);
  New(VS);
  If Not VS^.InitCustom(5,7,75,23, esColors, wBordered + wClear + wSaveContents,
    VC^, ucNone) Then
    Begin
    WriteLn('Failed to init validation window');
    Halt(5);
    End;
  VS^.wFrame.SetFrameType(Frame1);
  VS^.wFrame.AddShadow(shBR, shSeeThru);
  VS^.wFrame.AddHeader('[ User Validation ]', heTC);
  VS^.Draw;
  FillInAnswers;
  VS^.Process;
  VC^.Done;
  VS^.Done;
  Dispose(VS);
  Dispose(VC);
  ES.Select;
  ES.ResetScreen;
  End;


procedure GoPreEdit(ESP : EntryScreenPtr);
  begin
  with ESP^ do
    case GetCurrentID of
      0: ;
    end;
  end;


procedure GoPostEdit(ESP : EntryScreenPtr);
  begin
  with ESP^ do
    case GetCurrentID of
      0: ;
    end;
  end;


function GoToInitEntryScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
  const
    Frame1 = '…»ªºÕÕ∫∫';
    WinOptions = wBordered+wClear+wUserContents;

  begin
  with GoToES do
    begin
    if not InitCustom(22, 10, 51, 12, EsColors, WinOptions) then
      begin
      GoToInitEntryScreen := InitStatus;
      Exit;
      end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ Go To User Number ]', heTC);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(ExitAtEdges);
    SetPreEditProc(GoPreEdit);
    SetPostEditProc(GoPostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);
  {idUserNum:}
    AddWordField(
      'User Number:', 2, 6,
      '99999', 2, 19,
      1, 0, NameSearch.GetNumUsers - 1, GoToNum);
    GoToInitEntryScreen := RawError;
    end;
  end;


Procedure DoGoToUserNum;
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
  Status := GoToInitEntryScreen;
  if Status <> 0 then begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
  end;
  GoToNum := NameSearch.GetPos;
  GoToES.Select;
  GoToES.Process;
  GoToES.Erase;
  HideMouse;
  Case GoToES.GetLastCommand of
    ccQuit:;
    Else
      Begin
      NameSearch.GoToPosition(GoToNum);
      RefreshUser;
      End;
    End;
  GoToES.Done;
  end;


function SearchInitEntryScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
  const
    Frame1 = '…»ªºÕÕ∫∫';
    WinOptions = wBordered+wClear+wUserContents;

  begin
  with SearchES do
    begin
    if not InitCustom(15, 10, 65, 12, EsColors, WinOptions) then
      begin
      SearchInitEntryScreen := InitStatus;
      Exit;
      end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ Search for User ]', heTC);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(ExitAtEdges);
    SetPreEditProc(GoPreEdit);
    SetPostEditProc(GoPostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);
    AddStringField(
      'Name:', 2, 3,
      CharStr('X', 35), 2, 9, 35,
      hiName, SearchName);
    SearchInitEntryScreen := RawError;
    end;
  end;


Procedure SearchUser;
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
  Status := SearchInitEntryScreen;
  if Status <> 0 then begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
  end;
  SearchName := '';
  SearchES.Select;
  SearchES.Process;
  SearchES.Erase;
  HideMouse;
  Case SearchES.GetLastCommand of
    ccQuit:;
    Else
      Begin
      GoToNum := NameSearch.GetPos;
      ProcessBox('* Searching *', '[ Please Wait ]');
      If Not NameSearch.SearchFirst(SearchName) Then
        Begin
        EndProcessBox;
        NameSearch.GoToPosition(GoToNum);
        MsgBox('Search name not found!');
        End
      Else
        EndProcessBox;
      RefreshUser;
      End;
    End;
  SearchES.Done;
  end;


Procedure SearchAgain;
  Begin
  GoToNum := NameSearch.GetPos;
  ProcessBox('* Searching *', '[ Please Wait ]');
  If Not NameSearch.SearchNext Then
    Begin
    EndProcessBox;
    NameSearch.GoToPosition(GoToNum);
    MsgBox('Search name not found!');
    End
  Else
    EndProcessBox;
  RefreshUser;
  End;


Procedure DoMenu;
  Var
    MenuDone: Boolean;
    OS: Word;

  Begin
  MenuDone := False;
  Status := InitMenu(M);
  if Status <> 0 then begin
    WriteLn('Error initializing menu: ', Status);
    Halt(1);
  end;
  Status := InitHelpLine(H);
  if Status <> 0 then begin
    WriteLn('Error initializing help line: ', Status);
    Halt(1);
  end;
  M.SetCurrentItemProc(UpdateHelpLine);
  M.GetCommandProcessor^.AddCommand(ccUser1, 1, $2e00, 0); {Alt-C Config}
  M.GetCommandProcessor^.AddCommand(ccUser2, 1, $4700, 0);
  M.GetCommandProcessor^.AddCommand(ccUser3, 1, $4f00, 0);
  M.GetCommandProcessor^.AddCommand(ccUser4, 1, $4800, 0);
  M.GetCommandProcessor^.AddCommand(ccUser5, 1, $5000, 0);
  M.GetCommandProcessor^.AddCommand(ccUser6, 1, $2600, 0); {Alt-L Search again}
  M.GetCommandProcessor^.AddCommand(ccQuit, 1, Ord('Q'), 0);
  M.GetCommandProcessor^.AddCommand(ccQuit, 1, Ord('q'), 0);
  if MouseInstalled then
    with ESColors do
      begin
      SoftMouseCursor($0000, (ColorMono(MouseColor, MouseMono) shl 8)+
                             Byte(MouseChar));
      ShowMouse;
      MenuCommands.cpOptionsOn(cpEnableMouse);
      end;
  While Not MenuDone Do
    Begin
    H.Draw;
    M.Draw;
    M.Process;
    Case M.GetLastCommand of
      ccSelect:
        Begin
        case M.MenuChoice of
          miEdit0: Begin
            ES.Select;
            ES.Process;
            RefreshFile;
            M.Select;
            End;
          miNext1: Begin
            If NameSearch.GetPos < (NameSearch.GetNumUsers - 1) Then
              Begin
              If NameSearch.Next Then;
              RefreshUser;
              M.Select;
              End;
            End;
          miPrior2: Begin
            If NameSearch.GetPos > 0 Then
              Begin
              If NameSearch.Prior Then;
              RefreshUser;
              M.Select;
              End;
            End;
          miFirst3: Begin
            NameSearch.GoToPosition(0);
            RefreshUser;
            M.Select;
            End;
          miLast4: Begin
            NameSearch.GoToPosition(NameSearch.GetNumUsers - 1);
            RefreshUser;
            M.Select;
            End;
          miSearch5:
            Begin
            SearchUser;
            M.Select;
            End;
          miAdd6:
            Begin
            NameSearch.GoToPosition(NameSearch.GetNumUsers);
            DefaultUser;
            RefreshFile;
            ES.Select;
            ES.Process;
            RefreshFile;
            M.Select;
            End;
          miDelete7: Begin
            NameSearch.SetDelete(Not NameSearch.IsDeleted);
            RefreshUser;
            NameSearch.SaveChanges;
            M.Select;
            End;
          miGoTo8: Begin
            DoGoToUserNum;
            M.Select;
            End;
          miValidate9: Begin
            Validate;
            M.Select;
            End;
          End;
        End;
      ccQuit: Begin
         OS := DoYesNo('[ Exit Program ]', True);
         Case OS of
           1: MenuDone := True;
           2: ; {Not done}
           End;
         End;
      ccUser1: Begin
        DoCfgEdit; {Alt-C}
        M.Select;
        End;
      ccUser2: Begin {Home}
        NameSearch.GoToPosition(0);
        RefreshUser;
        M.Select;
        End;
      ccUser3: Begin {End}
        NameSearch.GoToPosition(NameSearch.GetNumUsers - 1);
        RefreshUser;
        M.Select;
        End;
      ccUser4: Begin {Up}
        If NameSearch.GetPos > 0 Then
          Begin
          If NameSearch.Prior Then;
          RefreshUser;
          M.Select;
          End;
        End;
      ccUser5: Begin {Down}
        If NameSearch.GetPos < (NameSearch.GetNumUsers - 1) Then
          Begin
          If NameSearch.Next Then;
          RefreshUser;
          M.Select;
          End;
        End;
      ccUser6:
        Begin
        SearchAgain;
        M.Select;
        End;
      End;
    M.Erase;
    H.Erase;
    End;
  HideMouse;
  H.Done;
  M.Done;
  End;



Procedure FinishEdit;
  Begin
  ES.Erase;
  HideMouse;
  ES.Done;
  End;



Procedure LoadCfg;
  Begin
  If FileExist(Config^.GetBbsPath + 'MKUserEd.Cfg') Then
    Begin
    If LoadFile(Config^.GetBbsPath + 'MKUserEd.Cfg', UserEdCfg, SizeOf(UserEdCfg)) = 0 Then;
    End
  Else
    FillChar(UserEdCfg, SizeOf(UserEdCfg), 0);
  End;



Begin
{$IFNDEF DPMI}
OvrFileMode := 64;
OvrInit('MKUSERED.OVR');
If OvrResult <> 0 Then
  Begin
  WriteLn(Long2Str(OvrResult) + ' Error loading MKUSERED.OVR');
  Halt(1);
  End;
OvrSetBuf(32000);
OvrInitEMS;
If ((OvrResult < 0) and (OvrResult > -5)) Then
  Begin
  WriteLn(Long2Str(OvrResult) + ' Error loading MKUSERED.OVR' );
  Halt(1);
  End;
{$ENDIF}
BbsType := DetectBbsType;
Case BbsType Of
  1: Config := New(MKCfgObjPtr, Init);
  2: Config := New(RACfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
Config^.Load;
LoadCfg;
NameSearch.Init;
NameSearch.SetBbsType(BbsType);
NameSearch.GoToPosition(0);
InitEdit;
DoMenu;
FinishEdit;
NameSearch.Done;
If SaveFile(Config^.GetBbsPath + 'MKUserEd.Cfg', UserEdCfg, SizeOf(UserEdCfg)) = 0 Then;
Dispose(Config, Done);
End.
