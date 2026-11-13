{$V-}
{$F+}
{$O+}

Unit CFGMSG;

{$I OPDEFINE.INC}

Interface

Procedure DoCfgMsg(MsgNum: Word);

Implementation


uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor, OpPick,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow,
  OpSelect,  OpEntry, CfgGlob, CfgSec2, MKGlobT, MKString,
  MKCfgAbs, MKMsgAbs, MKMsgHud, MKMsgFid, MKMsgSqu, CfgYn;


{Entry field constants}
const
  idName = 0;
  idShortName = idName + 1;
  idAddr = idShortName + 1;
  idNetStatus = idAddr + 1;
  idTypes = idNetStatus + 1;
  idFormat = idTypes + 1;
  idOptions = idFormat + 1;
  idDaysKept = idOptions + 1;
  idMsgsKept = idDaysKept + 1;
  idRcvdDays = idMsgsKept + 1;
  idReadSec = idRcvdDays + 1;
  idWriteSec = idReadSec + 1;
  idSysopSec = idWriteSec + 1;
  idOrigin = idSysopSec + 1;
  idAreaTag = idOrigin + 1;
  idEchoTo = idAreaTag + 1;
  idFidoOptions = idEchoTo + 1;
  idFileId = idFidoOptions + 1;
  idMsgPath = idFileId + 1;
  idHub = idMsgPath + 1;
  idSelect = idHub + 1;

{Help index constants}
const
  hiName                 = 1;
  hiShortName            = hiName + 1;
  hiAddr                 = hiShortName + 1;
  hiNetStatus            = hiAddr + 1;
  hiTypes                 = hiNetStatus + 1;
  hiFormat = hiTypes + 1;
  hiOptions = hiFormat + 1;
  hiDaysKept             = hiOptions + 1;
  hiMsgsKept             = hiDaysKept + 1;
  hiRcvdDays             = hiMsgsKept + 1;
  hiReadSec              = hiRcvdDays + 1;
  hiWriteSec             = hiReadSec + 1;
  hiSysopSec             = hiWriteSec + 1;
  hiOrigin               = hiSysopSec + 1;
  hiAreaTag              = hiOrigin + 1;
  hiEchoTo               = hiAreaTag + 1;
  hiFidoOptions = hiEchoTo + 1;
  hiFileId = hiFidoOptions + 1;
  hiMsgPath = hiFileId + 1;
  hiHub = hiMsgPath + 1;
  hiSelect               = hiHub + 1;

type
  UserRecord =
    record
      AreaNum: Word;
      Name: String[40];
      ShortName: String[12];
      FormatStr: String[8];
      FileId: String[13];
      MsgPath: String[70];
      DaysKept: Word;
      MsgsKept: Word;
      RcvdDays: Word;
      Addr                 : string[25];
      NetStatus            : Char;
      Types                : string[8];
      Options              : Char;
      ReadSec: SecType;
      WriteSec: SecType;
      SysopSec: SecType;
      Origin               : string[55];
      AreaTag              : string[40];
      EchoTo               : Char;
      FidoOptions: Char;
      Hub                  : string[25];
      Select               : string[4];
    end;

var
  ES     : EntryScreen;
  UR: ^UserRecord;
  Status : Word;
  MsgNo: Word;
  Addr: AddrType;



Procedure NetStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := 'Network - ' + Char(Item + Ord('A') - 1);
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
  NetPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  NetPick.SetSelectMarker(' * ','');
  NetPick.AllocateSelectSet(26);
  For i := 1 to 26 Do
    Begin
    If Config^.GetMsgNetwork(UR^.AreaNum, i) Then
      NetPick.SelectItem(i)
    Else
      NetPick.DeSelectItem(i);
    End;
  NetPick.Process;
  For i := 1 to 26 Do
    Config^.SetMsgNetwork(UR^.AreaNum, i, NetPick.ItemIsSelected(i));
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


Procedure FormatPickStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item of
    1: IString := 'Hudson';
    2: IString := 'Squish';
    3: IString := '*.Msg';
    4: IString := 'JAM';
    Else
      IString := 'Unknown';
    End;
  End;


Procedure DoCfgFormat;
  Var
    i: Word;
    FormatPick: PickList;

  Begin
  If Not FormatPick.InitCustom(15,8,30,13,ESColors,
    wBordered+wClear+wUserContents,
    13, 04, FormatPickStr, PickVertical, SingleChoice) Then
    Halt;
  FormatPick.wFrame.SetFrameType(Frame1);
  FormatPick.wFrame.AddShadow(shBR, shSeeThru);
  FormatPick.wFrame.AddHeaderColor('[ Msg Format ]', heTC, WhiteOnBlue, BlackOnLtGray);
  FormatPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  Case Config^.GetMsgBaseType(UR^.AreaNum) of
    'H': FormatPick.SetInitialChoice(1);
    'S': FormatPick.SetInitialChoice(2);
    'F': FormatPick.SetInitialChoice(3);
    'J': FormatPick.SetInitialChoice(4);
    End;
  FormatPick.Process;
  If FormatPick.GetLastCommand = ccSelect Then
    Begin
    Case FormatPick.GetLastChoice of
      1: Begin
         Config^.SetMsgBaseType(UR^.AreaNum, 'H');
         UR^.FormatStr := 'Hudson';
         End;
      2: Begin
         Config^.SetMsgBaseType(UR^.AreaNum, 'S');
         UR^.FormatStr := 'Squish';
         End;
      3: Begin
         Config^.SetMsgBaseType(UR^.AreaNum, 'F');
         UR^.FormatStr := '*.Msg';
         End;
      4: Begin
         Config^.SetMsgBaseType(UR^.AreaNum, 'J');
         UR^.FormatStr := 'JAM';
         End;
      End;
    End;
  FormatPick.Erase;
  FormatPick.Done;
  End;


Procedure GetFormat(Var ESP: EntryScreenPtr; ScreenNo: Word);
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
          DoCfgFormat;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure MsgPathPickStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item of
    1..10: IString := Config^.GetMsgPath(Item);
    Else
      IString := '';
    End;
  End;


Procedure DoCfgMsgPath;
  Var
    i: Word;
    MsgPathPick: PickList;

  Begin
  If Not MsgPathPick.InitCustom(5,8,75,20,ESColors,
    wBordered+wClear+wUserContents,
    70, 10, MsgPathPickStr, PickVertical, SingleChoice) Then
    Halt;
  MsgPathPick.wFrame.SetFrameType(Frame1);
  MsgPathPick.wFrame.AddShadow(shBR, shSeeThru);
  MsgPathPick.wFrame.AddHeaderColor('[ Msg Base Path ]', heTC, WhiteOnBlue, BlackOnLtGray);
  MsgPathPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  MsgPathPick.SetInitialChoice(Config^.GetMsgPathNum(UR^.AreaNum));
  MsgPathPick.Process;
  If MsgPathPick.GetLastCommand = ccSelect Then
    Begin
    Config^.SetMsgPathNum(UR^.AreaNum, MsgPathPick.GetLastChoice);
    UR^.MsgPath := Config^.GetMsgPath(MsgPathPick.GetLastChoice);
    End;
  MsgPathPick.Erase;
  MsgPathPick.Done;
  End;


Procedure GetMsgPath(Var ESP: EntryScreenPtr; ScreenNo: Word);
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
          DoCfgMsgPath;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure MEchoSStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Var
    Addr: AddrType;

  Begin
  Config^.GetEchoToAddr(Item, Addr);
  IString := PadLeft(Long2Str(Item),' ',3) + '  ' + AddrStr(Addr);
  End;





Procedure POrigStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := PadLeft(Long2Str(Item),'0',2) + ' ' + Config^.GetOrigStr(Item);
  End;


Procedure MTypeStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item of
    1: IString := 'Normal';
    2: IString := 'Net Mail';
    3: IString := 'EchoMail';
    Else
      IString := '';
    End;
  End;



Procedure MAddrStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Var
    Addr: AddrType;

  Begin
  Config^.GetAddr(Item, Addr);
  IString := PadLeft(Long2Str(Item),' ',3) + '  ' + AddrStr(Addr);
  End;


Procedure MOptStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  Case Item of
    01: IString := 'Allow Ansi';
    02: IString := 'Allow HiBit';
    03: IString := 'Allow Taglines';
    04: IString := 'Allow Offline';
    05: IString := 'Force Offline';
    06: IString := 'Allow Combined';
    07: IString := 'Add Fido Info';
    08: IString := 'Reader Tearline';
    09: IString := 'Allow File Attach';
    10: IString := 'Default Combined';
    11: IString := 'Allow Private';
    12: IString := 'Allow Public';
    13: IString := 'Allow Real Name';
    14: IString := 'Allow Handle';
    15: IString := 'Allow Alias';
    16: IString := 'Reader Origin Line';
    End;
  End;


Procedure FOptStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);
  Begin
  Case Item of
    01: IString := 'Pass-Thru Area';
    02: IString := 'Import Path';
    03: IString := 'Hide Imported Path';
    04: IString := 'Import Seen-By';
    05: IString := 'Hide Imported Seen-By';
    End;
  End;



Procedure MAddrPick;
  Var
    MAPick: PickList;
    MAddr: Word;

  Begin
  If Not MAPick.InitCustom(8,8,72,22,ESColors,
    wBordered+wClear+wUserContents,
    30, 10, MAddrStr,PickVertical, SingleChoice) Then
    Halt;
  MAddr := Config^.GetMsgAddrNum(UR^.AreaNum);
  MAPick.SetInitialChoice(MAddr);
  MAPick.wFrame.SetFrameType(Frame1);
  MAPick.wFrame.AddShadow(shBR, shSeeThru);
  MAPick.wFrame.AddHeaderColor('[ Address ]', heTC, WhiteOnBlue, BlackOnLtGray);
  MAPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  MAPick.Process;
  MAPick.Erase;
  If MAPick.GetLastCommand = ccSelect Then
    MAddr := MAPick.GetLastChoice;
  MAPick.Done;
  Config^.SetMsgAddrNum(UR^.AreaNum, MAddr);
  UR^.Addr := Config^.GetMsgAddrStr(UR^.AreaNum);
  End;


Procedure MTypePick;
  Var
    MTPick: PickList;
    MType: MailType;
    Tmp: Word;

  Begin
  If Not MTPick.InitCustom(31,8,62,22,ESColors,
    wBordered+wClear+wUserContents,
    30, 3, MTypeStr,PickVertical, SingleChoice) Then
    Halt;
  MType := Config^.GetMsgType(UR^.AreaNum);
  Case MType of
    Normal: MTPick.SetInitialChoice(1);
    EchoMail: MTPick.SetInitialChoice(3);
    NetMail: MTPick.SetInitialChoice(2);
    End;
  MTPick.wFrame.SetFrameType(Frame1);
  MTPick.wFrame.AddShadow(shBR, shSeeThru);
  MTPick.wFrame.AddHeaderColor('[ Mail Type ]', heTC, WhiteOnBlue, BlackOnLtGray);
  MTPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  MTPick.Process;
  MTPick.Erase;
  If MTPick.GetLastCommand = ccSelect Then
    Begin
    Case MTPick.GetLastChoice Of
      1: Config^.SetMsgType(UR^.AreaNum, Normal);
      2: Config^.SetMsgType(UR^.AreaNum, NetMail);
      3: Config^.SetMsgType(UR^.AreaNum, EchoMail);
      End;
    End;
  MTPick.Done;
  Case Config^.GetMsgType(UR^.AreaNum) Of
    Normal: UR^.Types := 'Normal';
    Echomail: UR^.Types := 'EchoMail';
    NetMail: UR^.Types := 'NetMail';
    End;
  End;


Procedure MOptPick;
  Var
    MOPick: PickList;

  Begin
  If Not MOPick.InitCustom(8,8,72,22,ESColors,
    wBordered+wClear+wUserContents,
    30, 16, MOptStr,PickVertical, MultipleChoice) Then
    Halt;
  MOPick.SetSelectMarker(' * ','');
  MOPick.wFrame.SetFrameType(Frame1);
  MOPick.wFrame.AddShadow(shBR, shSeeThru);
  MOPick.wFrame.AddHeaderColor('[ Options ]', heTC, WhiteOnBlue, BlackOnLtGray);
  MOPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  MOPick.AllocateSelectSet(17);
  If Config^.MsgAllowAnsi(UR^.AreaNum) Then
    MOPick.SelectItem(1)
  Else
    MOPick.DeSelectItem(1);
  If Config^.MsgAllowHiBit(UR^.AreaNum) Then
    MOPick.SelectItem(2)
  Else
    MOPick.DeSelectItem(2);
  If Config^.MsgAllowTag(UR^.AreaNum) Then
    MOPick.SelectItem(3)
  Else
    MOPick.DeSelectItem(3);
  If Config^.GetMsgAllowOffline(UR^.AreaNum) Then
    MOPick.SelectItem(4)
  Else
    MOPick.DeSelectItem(4);
  If Config^.GetMsgForceOffline(UR^.AreaNum) Then
    MOPick.SelectItem(5)
  Else
    MOPick.DeSelectItem(5);
  If Config^.GetMsgAllowCombined(UR^.AreaNum) Then
    MOPick.SelectItem(6)
  Else
    MOPick.DeSelectItem(6);
  If Config^.MsgAddFido(UR^.AreaNum) Then
    MOPick.SelectItem(7)
  Else
    MOPick.DeSelectItem(7);
  If Config^.GetMsgReaderTear(UR^.AreaNum) Then
    MOPick.SelectItem(8)
  Else
    MOPick.DeSelectItem(8);
  If Config^.GetMsgFAttach(UR^.AreaNum) Then
    MOPick.SelectItem(9)
  Else
    MOPick.DeSelectItem(9);
  If Config^.GetMsgDefCombined(UR^.AreaNum) THen
    MOPick.SelectItem(10)
  Else
    MOPick.DeSelectItem(10);
  If Config^.MsgAllowPriv(UR^.AreaNum) Then
    MOPick.SelectItem(11)
  Else
    MOPick.DeSelectItem(11);
  If Config^.MsgAllowPubl(UR^.AreaNum) Then
    MOPick.SelectItem(12)
  Else
    MOPick.DeSelectItem(12);
  If Config^.MsgAllowReal(UR^.AreaNum) Then
    MOPick.SelectItem(13)
  Else
    MOPick.DeSelectItem(13);
  If Config^.MsgAllowHdl(UR^.AreaNum) Then
    MOPick.SelectItem(14)
  Else
    MOPick.DeSelectItem(14);
  If Config^.MsgAllowAnon(UR^.AreaNum) Then
    MOPick.SelectItem(15)
  Else
    MOPick.DeSelectItem(15);
  If Config^.GetMsgReaderOrig(UR^.AreaNum) Then
    MOPick.SelectItem(16)
  Else
    MOPick.DeSelectItem(16);
  MOPick.Process;
  Config^.SetMsgAllowAnsi(UR^.AreaNum, MOPick.ItemIsSelected(1));
  Config^.SetMsgAllowHiBit(UR^.AreaNum, MOPick.ItemIsSelected(2));
  Config^.SetMsgAllowTag(UR^.AreaNum, MOPick.ItemIsSelected(3));
  Config^.SetMsgAllowOffline(UR^.AreaNum, MOPick.ItemIsSelected(4));
  Config^.SetMsgForceOffline(UR^.AreaNum, MOPick.ItemIsSelected(5));
  Config^.SetMsgAllowCombined(UR^.AreaNum, MOPick.ItemIsSelected(6));
  Config^.SetMsgAddFido(UR^.AreaNum, MOPick.ItemIsSelected(7));
  Config^.SetMsgReaderTear(UR^.AreaNum, MOPick.ItemIsSelected(8));
  Config^.SetMsgFAttach(UR^.AreaNum, MOPick.ItemIsSelected(9));
  Config^.SetMsgDefCombined(UR^.AreaNum, MOPick.ItemIsSelected(10));
  Config^.SetMsgAllowPriv(UR^.AreaNum, MOPick.ItemIsSelected(11));
  Config^.SetMsgAllowPubl(UR^.AreaNum, MOPick.ItemIsSelected(12));
  Config^.SetMsgAllowReal(UR^.AreaNum, MOPick.ItemIsSelected(13));
  Config^.SetMsgAllowHdl(UR^.AreaNum, MOPick.ItemIsSelected(14));
  Config^.SetMsgAllowAnon(UR^.AreaNum, MOPick.ItemIsSelected(15));
  Config^.SetMsgReaderOrig(UR^.AreaNum, MOPick.ItemIsSelected(16));
  MOPick.Erase;
  MOPick.Done;
  End;


Procedure FOptPick;
  Var
    FOPick: PickList;

  Begin
  If Not FOPick.InitCustom(8,12,72,22,ESColors,
    wBordered+wClear+wUserContents,
    30, 5, FOptStr,PickVertical, MultipleChoice) Then
    Halt;
  FOPick.SetSelectMarker(' * ','');
  FOPick.wFrame.SetFrameType(Frame1);
  FOPick.wFrame.AddShadow(shBR, shSeeThru);
  FOPick.wFrame.AddHeaderColor('[ Fido Options ]', heTC, WhiteOnBlue, BlackOnLtGray);
  FOPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  FOPick.AllocateSelectSet(6);
  If Config^.GetEchoAreaPassThru(UR^.AreaNum) Then
    FOPick.SelectItem(1)
  Else
    FOPick.DeSelectItem(1);
  If Config^.GetEchoAreaImportPath(UR^.AreaNum) Then
    FOPick.SelectItem(2)
  Else
    FOPick.DeSelectItem(2);
  If Config^.GetEchoAreaHidePath(UR^.AreaNum) Then
    FOPick.SelectItem(3)
  Else
    FOPick.DeSelectItem(3);
  If Config^.GetEchoAreaImportSeen(UR^.AreaNum) Then
    FOPick.SelectItem(4)
  Else
    FOPick.DeSelectItem(4);
  If Config^.GetEchoAreaHideSeen(UR^.AreaNum) Then
    FOPick.SelectItem(5)
  Else
    FOPick.DeSelectItem(5);
  FOPick.Process;
  Config^.SetEchoAreaPassThru(UR^.AreaNum, FOPick.ItemIsSelected(1));
  Config^.SetEchoAreaImportPath(UR^.AreaNum, FOPick.ItemIsSelected(2));
  Config^.SetEchoAreaHidePath(UR^.AreaNum, FOPick.ItemIsSelected(3));
  Config^.SetEchoAreaImportSeen(UR^.AreaNum, FOPick.ItemIsSelected(4));
  Config^.SetEchoAreaHideSeen(UR^.AreaNum, FOPick.ItemIsSelected(5));
  FOPick.Erase;
  FOPick.Done;
  End;



Procedure OrigPick;
  Var
    OPick: PickList;

  Begin
  If Not OPick.InitCustom(8,8,72,22,ESColors,
    wBordered+wClear+wUserContents,
    50, 20, POrigStr,PickVertical, SingleChoice) Then
    Halt;
  OPick.SetInitialChoice(Config^.GetMsgOrigNum(UR^.AreaNum));
  OPick.wFrame.SetFrameType(Frame1);
  OPick.wFrame.AddShadow(shBR, shSeeThru);
  OPick.wFrame.AddHeaderColor('[ Origin Line ]', heTC, WhiteOnBlue, BlackOnLtGray);
  OPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  OPick.Process;
  OPick.Erase;
  If OPick.GetLastCommand = ccSelect Then
    Config^.SetMsgOrigNum(UR^.AreaNum, OPick.GetLastChoice);
  OPick.Done;
  UR^.Origin := Config^.GetOrigStr(Config^.GetMsgOrigNum(UR^.AreaNum));
  End;



Procedure EchoToPick;
  Var
    PESysPick: PickList;
    i: Word;

  Begin
  If Not PESysPick.InitCustom(8,8,72,22,ESColors,
    wBordered+wClear+wUserContents,
    30, 32, MEchoSStr,PickVertical, MultipleChoice) Then
    Halt;
  PESysPick.AllocateSelectSet(32);
  PESysPick.SetSelectMarker(' * ','');
  PESysPick.wFrame.SetFrameType(Frame1);
  PESysPick.wFrame.AddShadow(shBR, shSeeThru);
  PESysPick.wFrame.AddHeaderColor('[ Echo Systems ]', heTC, WhiteOnBlue, BlackOnLtGray);
  PESysPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  For i := 1 to 32 Do
   Begin
   If Config^.GetEchoToArea(i, UR^.AreaNum) Then
     PESysPick.SelectItem(i)
   Else
     PESysPick.DeselectItem(i);
   End;
  PESysPick.Process;
  PESysPick.Erase;
  For i := 1 to 32 Do
   Config^.SetEchoToArea(i, UR^.AreaNum, PESysPick.ItemIsSelected(i));
  PESysPick.Done;
  End;


Procedure HubPick;
  Var
    HPick: PickList;

  Begin
  If Not HPick.InitCustom(8,8,72,22,ESColors,
    wBordered+wClear+wUserContents,
    30, 32, MEchoSStr,PickVertical, SingleChoice) Then
    Halt;
  HPick.SetInitialChoice(Config^.GetEchoToHub(UR^.AreaNum));
  HPick.wFrame.SetFrameType(Frame1);
  HPick.wFrame.AddShadow(shBR, shSeeThru);
  HPick.wFrame.AddHeaderColor('[ Host System ]', heTC, WhiteOnBlue, BlackOnLtGray);
  HPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  HPick.Process;
  HPick.Erase;
  If HPick.GetLastCommand = ccSelect Then
    Config^.SetEchoToHub(UR^.AreaNum, HPick.GetLastChoice);
  HPick.Done;
  Config^.GetEchoToAddr(Config^.GetEchoToHub(UR^.AreaNum), Addr);
  UR^.Hub := AddrStr(Addr);
  End;



Procedure GetEchoTo (Var ESP: EntryScreenPtr;
  ScreenNo: Word);
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
          EchoToPick;
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure GetMailType (Var ESP: EntryScreenPtr;
  ScreenNo: Word);
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
          MTypePick;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure GetMOpt (Var ESP: EntryScreenPtr;
  ScreenNo: Word);

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
          MOptPick;
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure GetFOpt (Var ESP: EntryScreenPtr; ScreenNo: Word);
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
          FOptPick;
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure GetOrig (Var ESP: EntryScreenPtr;
  ScreenNo: Word);

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
          OrigPick;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure GetHub (Var ESP: EntryScreenPtr;
  ScreenNo: Word);

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
          HubPick;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure GetMAddr (Var ESP: EntryScreenPtr;
  ScreenNo: Word);

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
          MAddrPick;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;





procedure PreEdit(ESP : EntryScreenPtr);
  {-Called just before a field is edited}
begin
  with ESP^ do
    case GetCurrentID of
      idName                 : ;
      idShortName            : ;
      idAddr: GetMAddr(ESP, idAddr);
      idNetStatus: GetNet(ESP, idNetStatus);
      idTypes: GetMailType(ESP, idTypes);
      idFormat: GetFormat(ESP, idFormat);
      idOptions: GetMOpt(ESP, idOptions);
      idDaysKept             : ;
      idMsgsKept             : ;
      idRcvdDays             : ;
      idReadSec: GetSecurity(UR^.ReadSec,ESP, idReadSec,'[ Read Security ]');
      idWriteSec: GetSecurity(UR^.WriteSec,ESP, idWriteSec,'[ Write Security ]');
      idSysopSec: GetSecurity(UR^.SysopSec,ESP, idSysopSec,'[ Sysop Security ]');
      idOrigin: GetOrig(ESP, idOrigin);
      idAreaTag              : ;
      idEchoTo: GetEchoTo(ESP, idEchoTo);
      idFidoOptions: GetFOpt(ESP, idFidoOptions);
      idFileId:;
      idMsgPath: GetMsgPath(ESP, idMsgPath);
      idHub: GetHub(ESP, idHub);
      idSelect               : ;
    end;
end;


procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idName                 : ;
      idShortName            : ;
      idAddr                 : ;
      idNetStatus            : ;
      idTypes                 : ;
      idOptions              : ;
      idDaysKept             : ;
      idMsgsKept             : ;
      idRcvdDays             : ;
      idReadSec              : ;
      idWriteSec             : ;
      idSysopSec             : ;
      idOrigin               : ;
      idAreaTag              : ;
      idEchoTo               : ;
      idHub                  : ;
      idSelect               : ;
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

function InitEntryScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
const
  WinOptions = wBordered+wClear+wUserContents;
begin
  with ES do begin
    if not InitCustom(3, 3, 77, 23, EsColors, WinOptions) then begin
      InitEntryScreen := InitStatus;
      Exit;
    end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ Message Area Configuration ]', heTC);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(WrapAtEdges);

    SetPreEditProc(PreEdit);
    SetPostEditProc(PostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);

  {idName:}
    AddStringField(
      'Name:', 2, 3,
      CharStr('X', 25), 2, 9, 25,
      hiName, UR^.Name);

  {idShortName:}
    AddStringField(
      'Short Name:', 2, 37,
      'XXXXXXXXXXXX', 2, 49, 12,
      hiShortName, UR^.ShortName);

  {idAddr:}
    AddStringField(
      'Address:', 4, 3,
      CharStr('X', 25), 4, 12, 25,
      hiAddr, UR^.Addr);

  {idNetStatus:}
    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Net Status:', 4, 48,
      'X', 4, 60,
      hiNetStatus, #0, #0, UR^.NetStatus);
    esFieldOptionsOn(efTrimBlanks);

  {idType:}
    AddStringField(
      'Type:', 6, 3,
      'XXXXXXXX', 6, 9, 8,
      hiTypes, UR^.Types);

    AddStringField(
      'Format:', 6, 22,
      'XXXXXXXX', 6, 30, 8,
      hiTypes, UR^.FormatStr);

  {idOptions:}
    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Options:', 6, 51,
      'X', 6, 60,
      hiOptions, #0, #0, UR^.Options);
    esFieldOptionsOn(efTrimBlanks);

  {idDaysKept:}
    AddWordField(
      'Days Kept:', 8, 3,
      '99999', 8, 14,
      hiDaysKept, 0, 65535, UR^.DaysKept);

  {idMsgsKept:}
    AddWordField(
      'Msgs Kept:', 8, 22,
      '99999', 8, 33,
      hiMsgsKept, 0, 65535, UR^.MsgsKept);

  {idRcvdDays:}
    AddWordField(
      'Received Days:', 8, 41,
      '99999', 8, 56,
      hiRcvdDays, 0, 65535, UR^.RcvdDays);

  {idReadSec:}
    AddWordField(
      'Read Sec:', 10, 3,
      '99999', 10, 13,
      hiReadSec, 0, 65535, UR^.ReadSec.Level);

  {idWriteSec:}
    AddWordField(
      'Write Sec:', 10, 22,
      '99999', 10, 33,
      hiWriteSec, 0, 65535, UR^.WriteSec.Level);

  {idSysopSec:}
    AddWordField(
      'Sysop Sec:', 10, 45,
      '99999', 10, 56,
      hiSysopSec, 0, 65535, UR^.SysopSec.Level);

  {idOrigin:}
    AddStringField(
      'Origin:', 12, 3,
      CharStr('X', 55), 12, 11, 50,
      hiOrigin, UR^.Origin);

  {idAreaTag:}
    AddStringField(
      'Area:', 14, 3,
      CharStr('X', 40), 14, 9, 40,
      hiAreaTag, UR^.AreaTag);

  {idEchoTo:}
    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Echo To:', 14, 51,
      'X', 14, 60,
      hiEchoTo, #0, #0, UR^.EchoTo);
    esFieldOptionsOn(efTrimBlanks);

  {idOptions:}
    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Fido Options:', 16, 3,
      'X', 16, 17,
      hiFidoOptions, #0, #0, UR^.FidoOptions);
    esFieldOptionsOn(efTrimBlanks);

    AddStringField(
      'File Id:', 16, 20,
      'XXXXXXXXXXXX', 16, 29, 12,
      hiFileId, UR^.FileId);

    AddStringField(
      'Path:', 18, 3,
      CharStr('X',60), 18, 9, 60,
      hiMsgPath, UR^.MsgPath);

  {idHub:}
    AddStringField(
      'Hub:', 20, 3,
      CharStr('X', 25), 20, 8, 25,
      hiHub, UR^.Hub);

  {idSelect:}
    AddStringField(
      'Select:', 20, 49,
      'XXXX', 20, 57, 4,
      hiSelect, UR^.Select);

    InitEntryScreen := RawError;
  end;
end;


Procedure DoCfgMsg(MsgNum: Word);
  Var
    Msg: AbsMsgPtr;

  Begin
  New(UR);
  MsgNo := MsgNum;
  UR^.AreaNum := MsgNum;
  UR^.Name := Config^.GetMsgName(MsgNum);
  UR^.ShortName := Config^.GetMsgShortName(MsgNum);
  UR^.AreaTag := Config^.GetEchoAreaTag(MsgNum);
  UR^.Select := Config^.GetMsgSelect(MsgNum);
  UR^.FileId := Config^.GetMsgFileId(MsgNum);
  UR^.MsgPath := Config^.GetMsgPath(Config^.GetMsgPathNum(MsgNum));
  Config^.GetMsgReadSecurity(MsgNum, UR^.ReadSec);
  Config^.GetMsgWriteSecurity(MsgNum, UR^.WriteSec);
  Config^.GetMsgSysopSecurity(MsgNum, UR^.SysopSec);
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
  UR^.NetStatus := '*';
  UR^.Options := '*';
  UR^.EchoTo := '*';
  Config^.GetEchoToAddr(Config^.GetEchoToHub(MsgNum), Addr);
  UR^.Hub := AddrStr(Addr);
  UR^.Addr := Config^.GetMsgAddrStr(MsgNum);
  UR^.Origin := Config^.GetMsgOrigStr(MsgNum);
  UR^.FidoOptions := '*';
  UR^.DaysKept := Config^.GetMsgDays(MsgNum);
  UR^.MsgsKept := Config^.GetMsgsKept(MsgNum);
  UR^.RcvdDays := Config^.GetMsgRcvdDays(MsgNum);
  Case Config^.GetMsgBaseType(MsgNum) of
    'H': UR^.FormatStr := 'Hudson';
    'S': UR^.FormatStr := 'Squish';
    'F': UR^.FormatStr := '*.Msg';
    Else
      UR^.FormatStr := 'Unknown';
    End;
  Case Config^.GetMsgType(MsgNum) Of
    Normal: UR^.Types := 'Normal';
    NetMail: UR^.Types := 'NetMail';
    EchoMail: UR^.Types := 'EchoMail';
    End;
  ES.Process;
  ES.Erase;
  HideMouse;
  ES.Done;
  Config^.SetMsgName(MsgNum, UR^.Name);
  Config^.SetMsgShortName(MsgNum, UR^.ShortName);
  Config^.SetMsgSelect(MsgNum, UR^.Select);
  Config^.SetEchoAreaTag(MsgNum, UR^.AreaTag);
  Config^.SetMsgReadSecurity(MsgNum, UR^.ReadSec);
  Config^.SetMsgWriteSecurity(MsgNum, UR^.WriteSec);
  Config^.SetMsgSysopSecurity(MsgNum, UR^.SysopSec);
  Config^.SetMsgDays(MsgNum, UR^.DaysKept);
  Config^.SetMsgsKept(MsgNum, UR^.MsgsKept);
  Config^.SetMsgRcvdDays(MsgNum, UR^.RcvdDays);
  Config^.SetMsgFileId(MsgNum, UR^.FileId);
  Case Config^.GetMsgBaseType(MsgNum) of
    'S': Begin
         Msg := New(SqMsgPtr, Init);
         If Msg <> Nil Then
           Begin
           Msg^.SetMsgPath(Copy(Config^.GetMsgAreaId(MsgNum),2,128));
           If Not Msg^.MsgBaseExists Then
             If DoYesNo('[ Create Msg Base ]', True) = 1 Then
               If Msg^.CreateMsgBase(UR^.MsgsKept, UR^.DaysKept) <> 0 Then
                 MsgBox('Unable to create messsage base');
           Dispose(Msg, Done);
           End;
         End;
    End;
  Dispose(UR);
  End;


End.
