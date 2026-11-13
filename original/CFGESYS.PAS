{$V-}
{$F+}
{$O+}

Unit CFGESYS;

{$I OPDEFINE.INC}

Interface


Procedure DoCfgESys(SysNum: Word);


Implementation


uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,  OpMouse,
  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow,  OpSelect,
  OpEntry, CfgGlob, MKGlobT, CfgNet, CfgEPack, OpPick, MKCfgAbs;


{Entry field constants}
const
  idZone                 = 0;
  idNet                  = idZone + 1;
  idNode                 = idNet + 1;
  idPoint                = idNode + 1;
  idPWD                  = idPoint + 1;
  idPacker               = idPWD + 1;
  idEchos                = idPacker + 1;
  idNetworks             = idEchos + 1;
  idMailType             = idNetworks + 1;

{Help index constants}
const
  hiZone                 = 1;
  hiNet                  = hiZone + 1;
  hiNode                 = hiNet + 1;
  hiPoint                = hiNode + 1;
  hiPWD                  = hiPoint + 1;
  hiPacker               = hiPWD + 1;
  hiEchos                = hiPacker + 1;
  hiNetworks             = hiEchos + 1;
  hiMailType             = hiNetworks + 1;


Type UserRecord = Record
  Addr: AddrType;
  Archiver: Byte;
  MailType: Byte;
  Pwd: String[15];
  End;


Var
  ES     : EntryScreen;
  UR: ^UserRecord;
  Status : Word;
  SysNo: Word;
  Packer: String[3];
  Echos: Char;
  Networks: Char;
  MailType: String[6];
  PackPick: PickList;
  MailPick: PickList;


Procedure AreaSStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := Pad(Long2Str(Item),4) + Copy(Config^.GetMsgName(Item), 1, 19);
  End;



Procedure EchoPick;
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
  AreaSPick.wFrame.AddHeaderColor('[ Message Areas ]', heTC, WhiteOnBlue, BlackOnLtGray);
  AreaSPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  AreaSPick.SetSelectMarker(' * ','');
  AreaSPick.AllocateSelectSet(501);
  For i := 1 to 500 Do
    Begin
    If Config^.GetEchoToArea(i, SysNo) Then
      AreaSPick.SelectItem(i)
    Else
      AreaSPick.DeSelectItem(i);
    End;
  AreaSPick.Process;
  For i := 1 to 500 Do
    Begin
    Config^.SetEchoToArea(i, SysNo, AreaSPick.ItemIsSelected(i));
    End;
  AreaSPick.Erase;
  AreaSPick.Done;
  End;


Procedure GetEchos(Var ESP: EntryScreenPtr; ScreenNo: Word);
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
          EchoPick;
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;



Function MTypeNum(MailType: String): Word;
  Begin
  MTypeNum := 0;
  If MailType = 'IMMED' Then
    MTypeNum := 0
  Else If MailType = 'CRASH' Then
    MTypeNum := 1
  Else If MailType = 'NORMAL' Then
    MTypeNum := 2
  Else If MailType = 'HOLD' Then
    MTypeNum := 3;
  End;


Function MailTStr(Num: Word): String;
  Begin
  Case Num of
    0: MailTStr := 'IMMED';
    1: MailTStr := 'CRASH';
    2: MailTStr := 'NORMAL';
    3: MailTStr := 'HOLD';
    End;
  End;


Procedure MailStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := MailTStr(Item - 1);
  End;





procedure PreEdit(ESP : EntryScreenPtr);
  {-Called just before a field is edited}

Var
  TmpNet: LongInt;

begin
  with ESP^ do
    case GetCurrentID of
      idZone                 : ;
      idNet                  : ;
      idNode                 : ;
      idPoint                : ;
      idPWD                  : ;
      idPacker:;
      idEchos: GetEchos(ESP, idEchos);
      idNetworks: GetNet(SysNo, ESP, idNetworks);
      idMailType             : ;
    end;
end;

procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idZone                 : ;
      idNet                  : ;
      idNode                 : ;
      idPoint                : ;
      idPWD                  : ;
      idPacker               : ;
      idEchos                : ;
      idNetworks             : ;
      idMailType             : ;
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


{$F+}
Procedure PackStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item of
    1: IString := 'LZH';
    2: IString := 'ZIP';
    3: IString := 'ARC';
    4: IString := 'ZOO';
    5: IString := 'DWC';
    6: IString := 'ARJ';
    7: IString := 'HYP';
    Else
      IString := '';
    End;
  End;
{$F-}


function InitEntryScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
const
  WinOptions = wBordered+wClear+wUserContents;
begin
  with ES do begin
    if not InitCustom(11, 7, 65, 13, EsColors, WinOptions) then begin
      InitEntryScreen := InitStatus;
      Exit;
    end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ System ' + Long2Str(SysNo) +' ]', heTC);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(WrapAtEdges);

    SetPreEditProc(PreEdit);
    SetPostEditProc(PostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);

  {idZone:}
    AddWordField(
      'Zone:', 2, 3,
      '99999', 2, 9,
      hiZone, 0, 65535, UR^.Addr.Zone);

  {idNet:}
    AddWordField(
      'Net:', 2, 16,
      '99999', 2, 21,
      hiNet, 0, 65535, UR^.Addr.Net);

  {idNode:}
    AddWordField(
      'Node:', 2, 28,
      '99999', 2, 34,
      hiNode, 0, 65535, UR^.Addr.Node);

  {idPoint:}
    AddWordField(
      'Point:', 2, 41,
      '99999', 2, 48,
      hiPoint, 0, 65535, UR^.Addr.Point);

  {idPWD:}
    AddStringField(
      'Password:', 4, 3,
      'XXXXXXXXXXXXXXX', 4, 13, 15,
      hiPWD, UR^.PWD);

  {idPacker:}
    AddPickStringField(
      'Packer:', 4, 31,
      4, 39, 3,
      hiPacker, Packer, PackPick);

  {idEchos:}
    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Echos:', 4, 45,
      'X', 4, 52,
      hiEchos, #0, #0, Echos);
    esFieldOptionsOn(efTrimBlanks);

  {idNetworks:}
    esFieldOptionsOff(efTrimBlanks);
    AddCharField(
      'Network Security:', 6, 3,
      'X', 6, 21,
      hiNetworks, #0, #0, Networks);
    esFieldOptionsOn(efTrimBlanks);

  {idMailType:}
    AddPickStringField(
      'Mail Type:', 6, 36,
      6, 47, 6,
      hiMailType, MailType, MailPick);

    InitEntryScreen := RawError;
  end;
end;


Procedure DoCfgESys(SysNum: Word);
  Begin
  New(UR);
  SysNo := SysNum;
  Config^.GetEchoToAddr(SysNum, UR^.Addr);
  UR^.Archiver := Config^.GetEchoToPacker(SysNum);
  UR^.Pwd := Config^.GetEchoToPwd(SysNum);
  UR^.MailType := Config^.GetEchoToMailType(SysNum);
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
  If Not PackPick.InitCustom(45,13,55,23,esColors,
    defWindowOptions or wBordered, 20, 7, PackStr, PickVertical,
    SingleChoice) Then
    Halt(1);
  PackPick.wFrame.SetFrameType(Frame1);
  PackPick.wFrame.AddShadow(shBR, shSeeThru);
  PackPick.wFrame.AddHeader('[ Packer ]', heTC);
  If Not MailPick.InitCustom(55,15,67,25,esColors,
    defWindowOptions or wBordered, 20, 4, MailStr, PickVertical,
    SingleChoice) Then
    Halt(1);
  MailPick.wFrame.SetFrameType(Frame1);
  MailPick.wFrame.AddShadow(shBR, shSeeThru);
  MailPick.wFrame.AddHeader('[ Mail Type ]', heTC);
  Packer := PackerStr(UR^.Archiver);
  MailType := MailTStr(UR^.MailType);
  if Status <> 0 then begin
    WriteLn('Error initializing entry screen: ', Status);
    Halt(1);
  end;
  Echos := '*';
  Networks := '*';
  ES.Process;
  ES.Erase;
  HideMouse;
  PackPick.Done;
  ES.Done;
  UR^.Archiver := PackerNum(Packer);
  UR^.MailType := MTypeNum(MailType);
  Config^.SetEchoToAddr(SysNum, UR^.Addr);
  Config^.SetEchoToPacker(SysNum, UR^.Archiver);
  Config^.SetEchoToPwd(SysNum, UR^.Pwd);
  Config^.SetEchoToMailType(SysNum, UR^.MailType);
  Dispose(UR);
  End;


End.
