{$V-}
{$F+}
{$O+}
Unit CFGEVENT;

{$I OPDEFINE.INC}

Interface

Procedure EditEvent(EventNum: Byte);
Procedure DoCfgEvent;


Implementation

Uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow, OpPick,
  OpSelect,  OpEntry, MKGlobT, MKCfgAbs, CfgGlob, MKString;


{Entry field constants}
const
  idStatus               = 0;
  idTimeH                = idStatus + 1;
  idTimeM                = idTimeH + 1;
  idEL                   = idTimeM + 1;
  idForced               = idEL + 1;
  idDays                 = idForced + 1;

{Help index constants}
const
  hiStatus               = 1;
  hiTimeH                = hiStatus + 1;
  hiTimeM                = hiTimeH + 1;
  hiEL                   = hiTimeM + 1;
  hiForced               = hiEL + 1;
  hiDays                 = hiForced + 1;

Type UserRecord = Record
  EventNum: Byte;
  Status: string[15];
  TimeH: Byte;
  TimeM: Byte;
  EL: Byte;
  Forced: string[15];
  Days: Char;
  End;


Var
  ES: EntryScreen;
  UR: ^UserRecord;
  Status : Word;


Procedure StatusStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item Of
    1: IString := 'Deleted';
    2: IString := 'Enabled';
    3: IString := 'Disabled';
    Else
      IString := '';
    End;
  End;


Procedure DoCfgEventStatus;
  Var
    i: Word;
    Pick: PickList;


  Begin
  If Not Pick.InitCustom(30,10,53,20,ESColors,
    wBordered+wClear+wUserContents,
    18, 3, StatusStr,PickVertical, SingleChoice) Then
    Halt;
  Pick.wFrame.SetFrameType(Frame1);
  Pick.wFrame.AddShadow(shBR, shSeeThru);
  Pick.wFrame.AddHeaderColor('[ Event Status ]', heTC, WhiteOnBlue, BlackOnLtGray);
  Pick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  Pick.SetInitialChoice(Config^.GetEventStatus(UR^.EventNum) + 1);
  Pick.Process;
  If Pick.GetLastCommand = ccSelect Then
    Begin
    i := Pick.GetLastChoice;
    Config^.SetEventStatus(UR^.EventNum, i - 1);
    Case i Of
      1: UR^.Status := 'Deleted';
      2: UR^.Status := 'Enabled';
      3: UR^.Status := 'Disabled';
      End;
    End;
  Pick.Erase;
  Pick.Done;
  End;


Procedure GetEventStatus(Var ESP: EntryScreenPtr; ScreenNo: Word);
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
          DoCfgEventStatus;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure ForcedStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item Of
    1: IString := 'Normal';
    2: IString := 'Forced';
    3: IString := 'Delayable';
    Else
      IString := '';
    End;
  End;


Procedure DoCfgEventForced;
  Var
    i: Word;
    Pick: PickList;


  Begin
  If Not Pick.InitCustom(10,12,30,20,ESColors,
    wBordered+wClear+wUserContents,
    18, 3, ForcedStr,PickVertical, SingleChoice) Then
    Halt;
  Pick.wFrame.SetFrameType(Frame1);
  Pick.wFrame.AddShadow(shBR, shSeeThru);
  Pick.wFrame.AddHeaderColor('[ Event Forced ]', heTC, WhiteOnBlue, BlackOnLtGray);
  Pick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  Pick.SetInitialChoice(Config^.GetEventForced(UR^.EventNum) + 1);
  Pick.Process;
  If Pick.GetLastCommand = ccSelect Then
    Begin
    i := Pick.GetLastChoice;
    Config^.SetEventForced(UR^.EventNum, i - 1);
    Case i Of
      1: UR^.Forced := 'Normal';
      2: UR^.Forced := 'Forced';
      3: UR^.Forced := 'Delayable';
      End;
    End;
  Pick.Erase;
  Pick.Done;
  End;


Procedure GetEventForced(Var ESP: EntryScreenPtr; ScreenNo: Word);
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
          DoCfgEventForced;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure DaysStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  Case Item Of
    1: IString := 'Sunday';
    2: IString := 'Monday';
    3: IString := 'Tuesday';
    4: IString := 'Wednesday';
    5: IString := 'Thursday';
    6: IString := 'Friday';
    7: IString := 'Saturday';
    Else
      IString := '';
    End;
  End;


Procedure DoCfgEventDays;
  Var
    i: Word;
    Pick: PickList;


  Begin
  If Not Pick.InitCustom(27, 12, 48, 23,ESColors,
    wBordered+wClear+wUserContents,
    18, 7, DaysStr,PickVertical, MultipleChoice) Then
    Halt;
  Pick.wFrame.SetFrameType(Frame1);
  Pick.wFrame.AddShadow(shBR, shSeeThru);
  Pick.wFrame.AddHeaderColor('[ Event Days ]', heTC, WhiteOnBlue, BlackOnLtGray);
  Pick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  Pick.AllocateSelectSet(8);
  Pick.SetSelectMarker(' * ','');
  For i := 1 to 7 Do
    Begin
    If Config^.GetEventOnDay(UR^.EventNum, i) Then
      Pick.SelectItem(i)
    Else
      Pick.DeSelectItem(i);
    End;
  Pick.Process;
  For i := 1 to 7 Do
    Config^.SetEventOnDay(UR^.EventNum, i, Pick.ItemIsSelected(i));
  Pick.Erase;
  Pick.Done;
  End;


Procedure GetEventDays(Var ESP: EntryScreenPtr; ScreenNo: Word);
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
          DoCfgEventDays;
          ESP^.DrawField(ScreenNo);
          ESP^.SetNextField(ScreenNo + 1);
          End;
    Else
      StuffKey(Temp);
    End;
  ShowMouse;
  End;


Procedure EventStr(Item: Word; Mode: PkMode; Var IType: PkItemType; Var
  IString: String; PickPtr: PickListPtr);

  Begin
  IString := Pad(Long2Str(Item),4) + Word2TimeStr(Config^.GetEventTime(Item)) +
    ' Level ' + Long2Str(Config^.GetEventEL(Item));
  End;



Procedure DoCfgEvent;
  Var
    EdMore: Boolean;
    MsgNo: Word;
    EventPick: PickList;

  Begin
  EdMore := True;
  If Not EventPick.InitCustom(3,8,76,22,ESColors,
    wBordered+wClear+wUserContents,
    24, 30, EventStr, PickVertical, SingleChoice) Then
    Halt;
  EventPick.wFrame.SetFrameType(Frame1);
  EventPick.wFrame.AddShadow(shBR, shSeeThru);
  EventPick.wFrame.AddHeaderColor('[ Events ]', heTC, WhiteOnBlue, BlackOnLtGray);
  EventPick.wFrame.AddCustomScrollBar(frRR, 1, MaxLongInt, 1, 1, '²', '°', EsColors);
  While EdMore Do
    Begin
    EventPick.Process;
    EventPick.Erase;
    If EventPick.GetLastCommand = ccSelect Then
      Begin
      MsgNo := EventPick.GetLastChoice;
      EditEvent(MsgNo);
      End
    Else
      EdMore := False;
    End;
  EventPick.Done;
  End;


Procedure PreEdit(ESP : EntryScreenPtr);
  {-Called just before a field is edited}
  Begin
  with ESP^ do
    case GetCurrentID of
      idStatus: GetEventStatus(ESP, idStatus);
      idTimeH: ;
      idTimeM: ;
      idEL: ;
      idForced: GetEventForced(ESP, idForced);
      idDays: GetEventDays(ESP, idDays);
      End;
  End;


procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idStatus               : ;
      idTimeH                : ;
      idTimeM                : ;
      idEL                   : ;
      idForced               : ;
      idDays                 : ;
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


Function InitEntryScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
  const
  WinOptions = wBordered+wClear+wUserContents;
  Begin
  with ES do begin
    if not InitCustom(7, 8, 72, 12, EsColors, WinOptions) then begin
      InitEntryScreen := InitStatus;
      Exit;
    end;

  wFrame.SetFrameType(Frame1);
  wFrame.AddShadow(shBR, shSeeThru);
  wFrame.AddHeader('[ Event ' + Long2Str(UR^.EventNum) + ' Configuration ]', heTC);
  esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
  SetWrapMode(WrapAtEdges);

  SetPreEditProc(PreEdit);
  SetPostEditProc(PostEdit);
  SetErrorProc(ErrorHandler);
  EntryCommands.SetHelpProc(DisplayHelp);

  {idStatus:}
    AddStringField(
      'Status:', 2, 4,
      'XXXXXXXXXXXXXXX', 2, 12, 15,
      hiStatus, UR^.Status);

  {idTimeH:}
    SetPadChar('0');
    AddNumericByteField(
      'Event Time:', 2, 37,
      '99', 2, 49,
      hiTimeH, 0, 24, UR^.TimeH);
    SetPadChar(' ');

  {idTimeM:}
    esFieldOptionsOff(efAutoAdvanceChar);
    SetPadChar('0');
    AddNumericByteField(
      ':', 2, 51,
      '99', 2, 52,
      hiTimeM, 0, 59, UR^.TimeM);
    esFieldOptionsOn(efAutoAdvanceChar);
    SetPadChar(' ');

  {idEL:}
    AddByteField(
      'ErrorLevel:', 4, 4,
      '999', 4, 16,
      hiEL, 0, 255, UR^.EL);

  {idForced:}
    AddStringField(
      'Forced:', 4, 23,
      'XXXXXXXXXXXXXXX', 4, 31, 15,
      hiForced, UR^.Forced);

  {idDays:}
    esFieldOptionsOff(efTrimBlanks);
    SetPadChar('*');
    AddCharField(
      'Days:', 4, 50,
      'X', 4, 56,
      hiDays, #0, #0, UR^.Days);
    esFieldOptionsOn(efTrimBlanks);
    SetPadChar(' ');

    InitEntryScreen := RawError;
    End;
  End;


Procedure EditEvent(EventNum: Byte);
  Begin
  New(UR);
  UR^.EventNum := EventNum;
  UR^.Days := '*';
  UR^.EL := Config^.GetEventEL(EventNum);
  UR^.TimeH := Hi(Config^.GetEventTime(EventNum));
  UR^.TimeM := Lo(COnfig^.GetEventTime(EventNum));
  Case Config^.GetEventStatus(EventNum) of
    0: UR^.Status := 'Deleted';
    1: UR^.Status := 'Enabled';
    2: UR^.Status := 'Disabled';
    End;
  Case Config^.GetEventForced(EventNum) of
    0: UR^.Forced := 'Normal';
    1: UR^.Forced := 'Forced';
    2: UR^.Forced := 'Delayble';
    End;
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
  Config^.SetEventEL(EventNum, UR^.EL);
  Config^.SetEventTime(EventNum, (UR^.TimeH shl 8) + UR^.TimeM);
  Dispose(UR);
  End;


End.
