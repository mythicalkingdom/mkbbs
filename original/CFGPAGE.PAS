{$V-}
Unit CFGPAGE;

{$I OPDEFINE.INC}

Interface

Procedure DoCfgPage;


Implementation

Uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame,
  OpWindow,  OpSelect,  OpEntry, CfgGlob, MKGlobT, MKCfgAbs;


{Entry field constants}
const
  idS1H = 0;

{Help index constants}
const
  hiPage = 1;


Type UserRecord = Record
  StartHour: Array[0..6] of Byte;
  StartMin: Array[0..6] of Byte;
  StopHour: Array[0..6] of Byte;
  StopMin: Array[0..6] of Byte;
  AskPageReason: Boolean;
  PageLength: Byte;
  DefaultPage: Byte;
  MaxPages: Byte;
  PageMsgArea: Word;
  End;

Var
  ES: EntryScreen;
  UR: ^UserRecord;
  Status : Word;

{$F+}
procedure PreEdit(ESP : EntryScreenPtr);
  {-Called just before a field is edited}
  begin
  with ESP^ do
    case GetCurrentID of
      idS1H                  : ;
    end;
  end;


procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
  begin
  with ESP^ do
    case GetCurrentID of
      idS1H                  : ;
    End;
  End;


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


Function InitEntryScreen : Word;
  Const
    WinOptions = wBordered+wClear+wUserContents;

  Begin
  with ES do
    begin
    if not InitCustom(9, 7, 70, 19, EsColors, WinOptions) then begin
      InitEntryScreen := InitStatus;
    Exit;
    End;
  wFrame.SetFrameType(Frame1);
  wFrame.AddShadow(shBR, shSeeThru);
  wFrame.AddHeader('[ Paging Configuration ]', heTC);
  esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
  SetWrapMode(WrapAtEdges);
  SetPreEditProc(PreEdit);
  SetPostEditProc(PostEdit);
  SetErrorProc(ErrorHandler);
  EntryCommands.SetHelpProc(DisplayHelp);
  SetPadChar(' ');
  AddTextField('Paging Hrs', 2, 3);
  AddTextField('Start', 2, 15);
  AddTextField('Stop', 2, 24);
  AddTextField('Options', 2, 41);
  SetPadChar('0');
  AddNumericByteField(
      'Sunday:', 4, 3,
      '99', 4, 15,
      1, 0, 23, UR^.StartHour[0]);
  AddNumericByteField(
      ':', 4, 17,
      '99', 4, 18,
      1, 0, 59, UR^.StartMin[0]);
  AddNumericByteField(
      '', 4, 24,
      '99', 4, 24,
      1, 0, 23, UR^.StopHour[0]);
  AddNumericByteField(
      ':', 4, 26,
      '99', 4, 27,
      1, 0, 59, UR^.StopMin[0]);

  SetPadChar(' ');
  {idPageLength:}
  AddByteField(
      'Page Length (Seconds):', 4, 34,
      '999', 4, 57,
      1, 0, 255, UR^.PageLength);
  SetPadChar('0');
  AddNumericByteField(
      'Monday:', 5, 3,
      '99', 5, 15,
      1, 0, 23, UR^.StartHour[1]);
  AddNumericByteField(
      ':', 5, 17,
      '99', 5, 18,
      1, 0, 59, UR^.StartMin[1]);
  AddNumericByteField(
      '', 5, 24,
      '99', 5, 24,
      1, 0, 23, UR^.StopHour[1]);
  AddNumericByteField(
      ':', 5, 26,
      '99', 5, 27,
      1, 0, 59, UR^.StopMin[1]);

  AddNumericByteField(
      'Tuesday:', 6, 3,
      '99', 6, 15,
      1, 0, 23, UR^.StartHour[2]);
  AddNumericByteField(
      ':', 6, 17,
      '99', 6, 18,
      1, 0, 59, UR^.StartMin[2]);
  AddNumericByteField(
      '', 6, 24,
      '99', 6, 24,
      1, 0, 23, UR^.StopHour[2]);
  AddNumericByteField(
      ':', 6, 26,
      '99', 6, 27,
      1, 0, 59, UR^.StopMin[2]);
  SetPadChar(' ');
  {idAskPageReason:}
    esFieldOptionsOn(efClickExit);
    AddYesNoField(
      'Ask Reason for Page:', 6, 34,
      'Y', 6, 55,
      1, UR^.AskPageReason);
    esFieldOptionsOff(efClickExit);
  SetPadChar('0');
  AddNumericByteField(
      'Wednesday:', 7, 3,
      '99', 7, 15,
      1, 0, 23, UR^.StartHour[3]);
  AddNumericByteField(
      ':', 7, 17,
      '99', 7, 18,
      1, 0, 59, UR^.StartMin[3]);
  AddNumericByteField(
      '', 7, 24,
      '99', 7, 24,
      1, 0, 23, UR^.StopHour[3]);
  AddNumericByteField(
      ':', 7, 26,
      '99', 7, 27,
      1, 0, 59, UR^.StopMin[3]);

  AddNumericByteField(
      'Thursday:', 8, 3,
      '99', 8, 15,
      1, 0, 23, UR^.StartHour[4]);
  AddNumericByteField(
      ':', 8, 17,
      '99', 8, 18,
      1, 0, 59, UR^.StartMin[4]);
  AddNumericByteField(
      '', 8, 24,
      '99', 8, 24,
      1, 0, 23, UR^.StopHour[4]);
  AddNumericByteField(
      ':', 8, 26,
      '99', 8, 27,
      1, 0, 59, UR^.StopMin[4]);
  SetPadChar(' ');
  {idDefaultPage:}
    AddByteField(
      'Default Page Number:', 8, 34,
      '999', 8, 55,
      1, 0, 255, UR^.DefaultPage);
  SetPadChar('0');
  AddNumericByteField(
      'Friday:', 9, 3,
      '99', 9, 15,
      1, 0, 23, UR^.StartHour[5]);
  AddNumericByteField(
      ':', 9, 17,
      '99', 9, 18,
      1, 0, 59, UR^.StartMin[5]);
  AddNumericByteField(
      '', 9, 24,
      '99', 9, 24,
      1, 0, 23, UR^.StopHour[5]);
  AddNumericByteField(
      ':', 9, 26,
      '99', 9, 27,
      1, 0, 59, UR^.StopMin[5]);

  AddNumericByteField(
      'Saturday:', 10, 3,
      '99', 10, 15,
      1, 0, 23, UR^.StartHour[6]);
  AddNumericByteField(
      ':', 10, 17,
      '99', 10, 18,
      1, 0, 59, UR^.StartMin[6]);
  AddNumericByteField(
      '', 10, 24,
      '99', 10, 24,
      1, 0, 23, UR^.StopHour[6]);
  AddNumericByteField(
      ':', 10, 26,
      '99', 10, 27,
      1, 0, 59, UR^.StopMin[6]);
  SetPadChar(' ');
  {idMaxPages:}
    AddByteField(
      'Maximum Pages Per Call:', 10, 34,
      '999', 10, 58,
      1, 0, 255, UR^.MaxPages);

  {idAskPageMsg:}
    AddWordField(
      'Message Area for message after Page:', 12, 10,
      '999', 12, 47,
      1, 0, 500, UR^.PageMsgArea);

    InitEntryScreen := RawError;
    End;
  End;


Procedure DoCfgPage;
  Var
    i: Word;
    Tmp: Word;

  Begin
  New(UR);
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
  For i := 0 To 6 Do
    Begin
    UR^.StartHour[i] := Hi(Config^.GetPageStart(i));
    UR^.StartMin[i] := Lo(Config^.GetPageStart(i));
    UR^.StopHour[i] := Hi(Config^.GetPageStop(i));
    UR^.StopMin[i] := Lo(Config^.GetPageStop(i));
    End;
  UR^.PageMsgArea := Config^.GetPageMsgArea;
  UR^.MaxPages := Config^.GetMaxPageTimes;
  UR^.PageLength := Config^.GetPageLength;
  UR^.DefaultPage := Config^.GetDefaultPage;
  UR^.AskPageReason := Config^.GetAskPageReason;
  ES.Process;
  ES.Erase;
  HideMouse;
  ES.Done;
  For i := 0 To 6 Do
    Begin
    Config^.SetPageStart(i, (256 * UR^.StartHour[i]) + UR^.StartMin[i]);
    Config^.SetPageStop(i, (256 * UR^.StopHour[i]) + UR^.StopMin[i]);
    End;
  Config^.SetPageMsgArea(UR^.PageMsgArea);
  Config^.SetMaxPageTimes(UR^.MaxPages);
  Config^.SetPageLength(UR^.PageLength);
  Config^.SetDefaultPage(UR^.DefaultPage);
  Config^.SetAskPageReason(UR^.AskPageReason);
  Dispose(UR);
  End;


End.
