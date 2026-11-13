{$V-}
{$F+}
{$O+}

Unit CFGPATH;

Interface

Procedure DoCfgPath;

Implementation

{$I OPDEFINE.INC}

Uses
  Dos,  OpInline,  OpString,  OpRoot,  OpCrt,  OpColor,
  OpMouse,  OpAbsFld,  OpCmd,  OpField,  OpFrame,  OpWindow,
  OpSelect,  OpEntry, MKString, MKGlobT, MKCfgAbs, CfgGlob;


{Entry field constants}
const
  idMsgPath1             = 0;
  idMsgPath2             = idMsgPath1 + 1;
  idMsgPath3             = idMsgPath2 + 1;
  idMsgPath4             = idMsgPath3 + 1;
  idMsgPath5             = idMsgPath4 + 1;
  idMsgPath6             = idMsgPath5 + 1;
  idMsgPath7             = idMsgPath6 + 1;
  idMsgPath8             = idMsgPath7 + 1;
  idMsgPath9             = idMsgPath8 + 1;
  idMsgPath10             = idMsgPath9 + 1;
  idNetPath              = idMsgPath10 + 1;
  idTempPath             = idNetPath + 1;
  idLogFileName          = idTempPath + 1;
  idEditCmdPath          = idLogFileName + 1;
  idNodeListPath         = idEditCmdPath + 1;
  idAttachPath           = idNodeListPath + 1;
  idSemPath = idAttachPath + 1;
  idEchoLog = idSemPath + 1;

{Help index constants}
const
  hiMsgPath1             = 1;
  hiMsgPath2             = hiMsgPath1 + 1;
  hiMsgPath3             = hiMsgPath2 + 1;
  hiMsgPath4             = hiMsgPath3 + 1;
  hiMsgPath5             = hiMsgPath4 + 1;
  hiMsgPath6             = hiMsgPath5 + 1;
  hiMsgPath7             = hiMsgPath6 + 1;
  hiMsgPath8             = hiMsgPath7 + 1;
  hiMsgPath9             = hiMsgPath8 + 1;
  hiMsgPath10             = hiMsgPath9 + 1;
  hiNetPath              = hiMsgPath10 + 1;
  hiTempPath             = hiNetPath + 1;
  hiLogFileName          = hiTempPath + 1;
  hiEditCmdPath          = hiLogFileName + 1;
  hiNodeListPath         = hiEditCmdPath + 1;
  hiAttachPath           = hiNodeListPath + 1;
  hiSemPath = hiAttachPath + 1;
  hiEchoLog = hiSemPath + 1;

Type UserRecord = Record
  MsgPath: Array[1..10] Of String[60];
  NetPath: string[60];
  TempPath: string[60];
  LogFileName: string[60];
  EditCmdPath: string[60];
  NodeListPath: string[60];
  AttachPath: string[60];
  SemPath: String[60];
  EchoLog: String[60];
  End;


Var
  ES: EntryScreen;
  UR: ^UserRecord;
  Status : Word;

procedure PreEdit(ESP : EntryScreenPtr);
  {-Called just before a field is edited}
begin
  with ESP^ do
    case GetCurrentID of
      idMsgPath1             : ;
      idMsgPath2             : ;
      idMsgPath3             : ;
      idMsgPath4             : ;
      idNetPath              : ;
      idTempPath             : ;
      idLogFileName          : ;
      idEditCmdPath          : ;
      idNodeListPath         : ;
      idAttachPath           : ;
    end;
end;

procedure PostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^ do
    case GetCurrentID of
      idMsgPath1: Begin
                  AddBackSlash(UR^.MsgPath[1]);
                  ESP^.DrawField(idMsgPath1);
                  End;
      idMsgPath2: Begin
                  AddBackSlash(UR^.MsgPath[2]);
                  ESP^.DrawField(idMsgPath2);
                  End;
      idMsgPath3: Begin
                  AddBackSlash(UR^.MsgPath[3]);
                  ESP^.DrawField(idMsgPath3);
                  End;
      idMsgPath4: Begin
                  AddBackSlash(UR^.MsgPath[4]);
                  ESP^.DrawField(idMsgPath4);
                  End;
      idMsgPath5: Begin
                  AddBackSlash(UR^.MsgPath[5]);
                  ESP^.DrawField(idMsgPath5);
                  End;
      idMsgPath6: Begin
                  AddBackSlash(UR^.MsgPath[6]);
                  ESP^.DrawField(idMsgPath6);
                  End;
      idMsgPath7: Begin
                  AddBackSlash(UR^.MsgPath[7]);
                  ESP^.DrawField(idMsgPath7);
                  End;
      idMsgPath8: Begin
                  AddBackSlash(UR^.MsgPath[8]);
                  ESP^.DrawField(idMsgPath8);
                  End;
      idMsgPath9: Begin
                  AddBackSlash(UR^.MsgPath[9]);
                  ESP^.DrawField(idMsgPath9);
                  End;
      idMsgPath10: Begin
                  AddBackSlash(UR^.MsgPath[10]);
                  ESP^.DrawField(idMsgPath10);
                  End;
      idNetPath:  Begin
                  AddBackSlash(UR^.NetPath);
                  ESP^.DrawField(idNetPath);
                  End;
      idTempPath: Begin
                  AddBackSlash(UR^.TempPath);
                  ESP^.DrawField(idTempPath);
                  End;
      idLogFileName: ;
      idEditCmdPath: ;
      idNodeListPath: Begin
                  AddBackSlash(UR^.NodeListPath);
                  ESP^.DrawField(idNodeListPath);
                  End;
      idAttachPath: Begin
                  AddBackSlash(UR^.AttachPath);
                  ESP^.DrawField(idAttachPath);
                  End;
      idSemPath: Begin
                  AddBackSlash(UR^.SemPath);
                  ESP^.DrawField(idSemPath);
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

function InitEntryScreen : Word;
  {-Initialize entry screen generated by MAKESCRN}
  Const
    WinOptions = wBordered+wClear+wUserContents;

  Begin
  with ES do begin
    if not InitCustom(5, 4, 74, 21, EsColors, WinOptions) then begin
      InitEntryScreen := InitStatus;
      Exit;
    end;

    wFrame.SetFrameType(Frame1);
    wFrame.AddShadow(shBR, shSeeThru);
    wFrame.AddHeader('[ System Paths ]', heTC);
    esFieldOptionsOn(efCursorToEnd+efClearFirstChar);
    SetWrapMode(WrapAtEdges);

    SetPreEditProc(PreEdit);
    SetPostEditProc(PostEdit);
    SetErrorProc(ErrorHandler);
    EntryCommands.SetHelpProc(DisplayHelp);

  {idMsgPath1:}
    AddStringField(
      'Msg Base 1:', 1, 3,
      CharStr('X', 50), 1, 15, 50,
      hiMsgPath1, UR^.MsgPath[1]);

  {idMsgPath2:}
    AddStringField(
      'Msg Base 2:', 2, 3,
      CharStr('X', 50), 2, 15, 50,
      hiMsgPath2, UR^.MsgPath[2]);

  {idMsgPath3:}
    AddStringField(
      'Msg Base 3:', 3, 3,
      CharStr('X', 50), 3, 15, 50,
      hiMsgPath3, UR^.MsgPath[3]);

  {idMsgPath4:}
    AddStringField(
      'Msg Base 4:', 4, 3,
      CharStr('X', 50), 4, 15, 50,
      hiMsgPath4, UR^.MsgPath[4]);

    AddStringField(
      'Msg Base 5:', 5, 3,
      CharStr('X', 50), 5, 15, 50,
      hiMsgPath4, UR^.MsgPath[5]);

    AddStringField(
      'Msg Base 6:', 6, 3,
      CharStr('X', 50), 6, 15, 50,
      hiMsgPath4, UR^.MsgPath[6]);

    AddStringField(
      'Msg Base 7:', 7, 3,
      CharStr('X', 50), 7, 15, 50,
      hiMsgPath4, UR^.MsgPath[7]);

    AddStringField(
      'Msg Base 8:', 8, 3,
      CharStr('X', 50), 8, 15, 50,
      hiMsgPath4, UR^.MsgPath[8]);

    AddStringField(
      'Msg Base 9:', 9, 3,
      CharStr('X', 50), 9, 15, 50,
      hiMsgPath4, UR^.MsgPath[9]);

    AddStringField(
      'Msg Base10:', 10, 3,
      CharStr('X', 50), 10, 15, 50,
      hiMsgPath4, UR^.MsgPath[10]);

  {idNetPath:}
    AddStringField(
      'NetMail:', 11, 3,
      CharStr('X', 50), 11, 12, 50,
      hiNetPath, UR^.NetPath);

  {idTempPath:}
    AddStringField(
      'Temp Files:', 12, 3,
      CharStr('X', 50), 12, 15, 50,
      hiTempPath, UR^.TempPath);

  {idLogFileName:}
    AddStringField(
      'Log File:', 13, 3,
      CharStr('X', 50), 13, 13, 50,
      hiLogFileName, UR^.LogFileName);

  {idEditCmdPath:}
    AddStringField(
      'Editor:', 14, 3,
      CharStr('X', 50), 14, 11, 50,
      hiEditCmdPath, UR^.EditCmdPath);

  {idNodeListPath:}
    AddStringField(
      'Node List Dir:', 15, 3,
      CharStr('X', 50), 15, 18, 50,
      hiNodeListPath, UR^.NodeListPath);

  {idAttachPath:}
    AddStringField(
      'File Attach:', 16, 3,
      CharStr('X', 50), 16, 16, 50,
      hiAttachPath, UR^.AttachPath);

  {idSemPath:}
    AddStringField(
      'Semaphore Path:', 17, 3,
      CharStr('X', 50), 17, 19, 50,
      hiSemPath, UR^.SemPath);

    AddStringField(
      'EchoToss Log:', 18, 3,
      CharStr('X', 50), 18, 17, 50,
      hiEchoLog, UR^.EchoLog);

    InitEntryScreen := RawError;
    End;
  End;



Procedure DoCfgPath;
  Var
    i: Word;

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
  For i := 1 to 10 Do
    UR^.MsgPath[i] := Config^.GetMsgPath(i);
  UR^.NetPath := Config^.GetNetPath;
  UR^.TempPath := Config^.GetTempPath;
  UR^.LogFileName := Config^.GetLogFileName;
  UR^.EditCmdPath := Config^.GetEditCmdPath;
  UR^.NodeListPath := Config^.GetNodeListPath;
  UR^.AttachPath := Config^.GetAttachPath;
  UR^.SemPath := Config^.GetSemaphorePath;
  UR^.EchoLog := Config^.GetEchoLog;
  ES.Process;
  ES.Erase;
  HideMouse;
  ES.Done;
  For i := 1 to 10 Do
    Config^.SetMsgPath(i, UR^.MsgPath[i]);
  Config^.SetNetPath(UR^.NetPath);
  Config^.SetTempPath(UR^.TempPath);
  Config^.SetLogFileName(UR^.LogFileName);
  Config^.SetEditCmdPath(UR^.EditCmdPath);
  Config^.SetNodeListPath(UR^.NodeListPath);
  Config^.SetAttachPath(UR^.AttachPath);
  Config^.SetSemaphorePath(UR^.SemPath);
  Config^.SetEchoLog(UR^.EchoLog);
  Dispose(UR);
  End;


End.
