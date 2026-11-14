Unit MKBasicRun;   {Menu command 169: run a BASIC program for the caller}

{$MODE OBJFPC}
{$H+}

{
     The menu item's data is the path of a BASIC program (GW-BASIC text or
     tokenized .BAS, "\" or "/" in the path; a relative path is looked for in the
     BBS directory).  The program runs in the mkbasic interpreter
     (../mkbasic-fpc, see build.sh) as a LOCKED session: it is run, not edited or
     listed, and LOAD / SAVE / CHAIN / RUN "file" give "Permission denied".  It may
     read and write files in the directory the program is in (and nowhere else).

     The caller is the terminal: output goes through User.DisplayStr, INPUT reads
     a line with simple editing, INKEY$ / INPUT$ read single keys (the arrow keys
     are reported like on a PC: CHR$(0) + scan code), COLOR / CLS / LOCATE use
     ANSI when the caller has it.

     Whatever ends the program ends the menu command and the menu goes on:
       END / STOP / SYSTEM    the normal end
       an error or a limit    the interpreter's message, then Press Enter
       Ctrl-C                 "Break in <line>", then Press Enter (also inside INPUT / INKEY$)
       carrier lost, time over, idle timeout   the program is stopped quietly
     Nothing is left running: there is no direct mode and no prompt.

     Built without the interpreter (no -dMKBASIC) the command only tells the
     caller that BASIC is not available.
}

Interface

Procedure RunBasicProgram(Path: ShortString);


Implementation


{$IFDEF MKBASIC}

Uses
  SysUtils, Classes, Math, BasicNum, BasicFiles, BasicTerm, Basic,
  MKComAbs, MKDoor, MKFile, MKLogEnt, MKCfgAbs, MKGlobT;


Type
  EHostAbort = Class(Exception);

  TMKTerm = Class(TBasicTerm)
  Private
    FQueue: AnsiString;                {keys typed ahead (Ctrl-C is not queued)}
    FBreak: Boolean;                   {the caller pressed Ctrl-C}
    FGone: Boolean;                    {the caller is gone (carrier, time, idle)}
    FMuted: Boolean;                   {the run was stopped from inside: no more output}
    FRaised: Boolean;                  {...with an exception (INPUT / INKEY$ waiting)}
    FLastCR: Boolean;
    Procedure Pump;
    Function  CallerGone: Boolean;
    Procedure StopRun(Const Why: String);
    Function  RawKey(Wait: Boolean; Var K: AnsiString): Boolean;
  Public
    InternalText: AnsiString;          {what the interpreter reported as an internal error}
    Procedure OutputString(Const S: AnsiString); Override;
    Function  GetInput: AnsiString; Override;
    Procedure SetColor(Fg, Bg: Integer); Override;
    Procedure ClearScreen; Override;
    Procedure GotoXY(AX, AY: Integer); Override;
    Function  HasKeys: Boolean; Override;
    Function  KeysAvailable: Boolean; Override;
    Function  GetKey: AnsiString; Override;
    Procedure Idle; Override;
    Function  PollBreak: Boolean; Override;
    Procedure InternalError(Const What: AnsiString);
    Property  Gone: Boolean Read FGone;
    Property  Broke: Boolean Read FBreak;
    Property  Raised: Boolean Read FRaised;
    Property  Column: Integer Read FX;
  End;


Function TMKTerm.CallerGone: Boolean;
  Begin
  User.CheckInput;                     {time over, carrier lost}
  Result := (Not User.OK) Or (CommActive And (Not CommCarrier));
  If Result Then
    FGone := True;
  End;


Procedure TMKTerm.StopRun(Const Why: String);
  {Leave the interpreter at once: INPUT repeats itself on a bad answer, so a value that
   means "stop" cannot be returned.  RunLocked catches the exception and says
   "Internal error", which the caller must not see: the output is muted from here.}
  Begin
  FMuted := True;
  FRaised := True;
  If Why <> 'break' Then
    FGone := True;
  Raise EHostAbort.Create(Why);
  End;


Procedure TMKTerm.Pump;
  {take what the caller typed: Ctrl-C is a break, the rest waits in the queue}
  Var
    Ch: Char;

  Begin
  While User.InputChr(Ch) Do
    Begin
    If Ch = #3 Then
      Begin
      FBreak := True;
      FQueue := '';
      End
    Else If Length(FQueue) < 1024 Then
      FQueue := FQueue + Ch;
    End;
  End;


Function TMKTerm.RawKey(Wait: Boolean; Var K: AnsiString): Boolean;
  {the next key; an arrow key comes as CHR$(0) + the PC scan code}
  Var
    Waited: Integer;

  Begin
  Result := False;
  K := '';
  Pump;
  While FQueue = '' Do
    Begin
    If FBreak Then
      StopRun('break');
    If CallerGone Then
      StopRun('carrier');
    If Not Wait Then
      Exit;
    User.CheckIdle;
    If Not User.OK Then
      StopRun('idle');
    If ComSession <> Nil Then
      ComSession^.WaitForChar(50)
    Else
      Sleep(50);
    Pump;
    End;
  If FBreak Then
    StopRun('break');
  K := FQueue[1];
  Delete(FQueue, 1, 1);
  If K = #27 Then
    Begin                              {ESC [ A  or  ESC O A: an arrow key}
    Waited := 0;
    While (Length(FQueue) < 2) And (Waited < 3) Do
      Begin
      If ComSession <> Nil Then
        ComSession^.WaitForChar(20);
      Pump;
      Inc(Waited);
      End;
    If (Length(FQueue) >= 2) And ((FQueue[1] = '[') Or (FQueue[1] = 'O')) Then
      Case FQueue[2] Of
        'A': Begin K := #0'H'; Delete(FQueue, 1, 2); End;
        'B': Begin K := #0'P'; Delete(FQueue, 1, 2); End;
        'C': Begin K := #0'M'; Delete(FQueue, 1, 2); End;
        'D': Begin K := #0'K'; Delete(FQueue, 1, 2); End;
        End;
    End;
  Result := True;
  End;


Procedure TMKTerm.OutputString(Const S: AnsiString);
  Var
    i, N: Integer;
    Part: ShortString;

  Begin
  If FMuted Or FGone Then
    Exit;
  If Not User.OK Then
    Begin
    FGone := True;
    Exit;
    End;
  i := 1;
  While i <= Length(S) Do
    Begin
    N := Length(S) - i + 1;
    If N > 200 Then
      N := 200;
    Part := Copy(S, i, N);
    User.DisplayStr(Part);
    Inc(i, N);
    End;
  Track(S);
  End;


Function TMKTerm.GetInput: AnsiString;
  {one line with backspace and Ctrl-U; the end of the line is not echoed (the
   interpreter prints it)}
  Var
    Line, K: AnsiString;
    Ch: Char;

  Begin
  Line := '';
  While True Do
    Begin
    RawKey(True, K);
    Ch := K[1];
    If (Ch = #0) Or ((Ch = #10) And FLastCR) Then
      Continue;                        {arrow keys, the LF of a CR LF}
    FLastCR := (Ch = #13);
    Case Ch Of
      #13, #10:
        Begin
        Result := Line;
        Exit;
        End;
      #8, #127:
        If Length(Line) > 0 Then
          Begin
          Delete(Line, Length(Line), 1);
          OutputString(#8' '#8);
          End;
      #21, #24:
        While Length(Line) > 0 Do
          Begin
          Delete(Line, Length(Line), 1);
          OutputString(#8' '#8);
          End;
      #27: ;
      Else
        If (Ch >= ' ') And (Length(Line) < 254) Then
          Begin
          Line := Line + Ch;
          OutputString(Ch);
          End;
      End;
    End;
  End;


Procedure TMKTerm.SetColor(Fg, Bg: Integer);
  Var
    Attr: Byte;

  Begin
  If Not User.GetUserAnsi Then
    Exit;
  Attr := (Fg And 15) Or ((Bg And 7) Shl 4);
  If Fg > 15 Then
    Attr := Attr Or 128;               {blink}
  User.DisplayAttr(Attr);
  End;


Procedure TMKTerm.ClearScreen;
  Begin
  User.ClearScreen;
  FX := 1;
  FY := 1;
  End;


Procedure TMKTerm.GotoXY(AX, AY: Integer);
  Begin
  If User.GetUserAnsi Then
    OutputString(#27'[' + IntToStr(AY) + ';' + IntToStr(AX) + 'H');
  FX := AX;
  FY := AY;
  End;


Function TMKTerm.HasKeys: Boolean;
  Begin
  Result := True;
  End;


Function TMKTerm.KeysAvailable: Boolean;
  Begin
  Pump;
  If FBreak Then
    StopRun('break');
  Result := FQueue <> '';
  End;


Function TMKTerm.GetKey: AnsiString;
  Var
    K: AnsiString;

  Begin
  RawKey(True, K);
  Result := K;
  End;


Procedure TMKTerm.Idle;
  Begin
  User.CheckInput;
  User.TimeWarn;
  End;


Function TMKTerm.PollBreak: Boolean;
  Begin
  Pump;
  Result := FBreak Or CallerGone;
  End;


Procedure TMKTerm.InternalError(Const What: AnsiString);
  Begin
  If Copy(What, 1, 10) <> 'EHostAbort' Then
    InternalText := What;
  End;


{------------------------------------------------------------ the command}

Procedure Log(Const S: String);
  Begin
  If LogEntry.LI <> Nil Then
    LogEntry.WriteEntry(S);
  End;


Function FindProgram(Name: String): String;
  {as typed, or in the BBS directory}
  Begin
  Result := '';
  If MKFile.FileExist(MKFile.ResolvePathCase(Name)) Then
    Result := MKFile.ResolvePathCase(Name)
  Else If (Name <> '') And (Name[1] <> '/') And
          MKFile.FileExist(MKFile.ResolvePathCase(Config^.GetBbsPath + Name)) Then
    Result := MKFile.ResolvePathCase(Config^.GetBbsPath + Name);
  End;


Function ReadAll(Const FN: String; Var Text: AnsiString): Boolean;
  Var
    F: TFileStream;

  Begin
  Result := False;
  Text := '';
  Try
    F := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
    Try
      If F.Size > 4 * 1024 * 1024 Then
        Exit;
      SetLength(Text, F.Size);
      If F.Size > 0 Then
        F.ReadBuffer(Text[1], F.Size);
      Result := True;
    Finally
      F.Free;
    End;
  Except
    Result := False;
  End;
  End;


Procedure RunBasicProgram(Path: ShortString);
  Var
    Name, Full, Status, Text: AnsiString;
    Term: TMKTerm;
    B: TBasic;
    OldMask: TFPUExceptionMask;
    i: Integer;
    Quiet: Boolean;

  Begin
  Name := Trim(Path);
  If (Length(Name) >= 2) And (Name[1] = '"') And (Name[Length(Name)] = '"') Then
    Name := Copy(Name, 2, Length(Name) - 2);
  For i := 1 To Length(Name) Do
    If Name[i] = '\' Then
      Name[i] := '/';
  Full := FindProgram(Name);
  If (Full = '') And (Pos(' ', Name) > 0) Then
    Full := FindProgram(Copy(Name, 1, Pos(' ', Name) - 1));   {a path with notes after it}
  If Full = '' Then
    Begin
    User.DisplayStrLn('Error: ' + Name + ' Not Found');
    Log('BASIC program not found : ' + Name);
    User.PressEnter;
    Exit;
    End;
  If Not ReadAll(Full, Text) Then
    Begin
    User.DisplayStrLn('Error: ' + Name + ' cannot be read');
    Log('BASIC program cannot be read : ' + Full);
    User.PressEnter;
    Exit;
    End;
  User.PostStatus(uoDoor);
  Log('BASIC program : ' + Full);
  Status := 'error';
  Quiet := False;
  Term := TMKTerm.Create;
  B := Nil;
  Try
    Try
      B := TBasic.Create(Term, TDirFiles.Create(ExtractFileDir(Full)), True);
      B.Locked := True;                {run only, no LIST / LOAD / SAVE / CHAIN}
      B.SystemMode := smEnd;           {SYSTEM ends the program, not the caller's session}
      B.RandomizeMode := rmClock;      {RANDOMIZE does not ask for a seed}
      B.OnInternalError := @Term.InternalError;
      OldMask := GetExceptionMask;
      MaskFloatExceptions;             {BASIC wants IEEE results, not exceptions}
      Try
        If B.LoadProgramText(Text, False) Then
          Status := B.RunLocked(-1)
        Else
          Status := 'load';
      Finally
        SetExceptionMask(OldMask);
      End;
    Except
      On E: Exception Do
        Begin
        Status := 'error';
        Term.InternalError(E.ClassName + ': ' + E.Message);
        End;
    End;
    Quiet := Term.Gone;
    If Term.Broke Then
      Status := 'break';
    If (Not Quiet) And Term.Raised And Term.Broke Then
      Begin
      If Term.Column > 1 Then
        User.DisplayNewLine;
      User.DisplayStrLn('Break');      {Ctrl-C while waiting for the caller}
      End
    Else If (Not Quiet) And (Term.Column > 1) Then
      User.DisplayNewLine;             {the program stopped in the middle of a line}
    If Term.InternalText <> '' Then
      Log('BASIC internal error : ' + Term.InternalText);
    Log('BASIC ended (' + Status + ')' + Copy(' - caller gone', 1, 15 * Ord(Quiet)));
    If (Not Quiet) And (Status <> 'end') And (Status <> 'stop') And (Status <> 'system') Then
      User.PressEnter;                 {an error, a limit or a break: let the caller read it}
  Finally
    B.Free;
    Term.Free;
  End;
  End;


{$ELSE}


Uses MKDoor, MKLogEnt;


Procedure RunBasicProgram(Path: ShortString);
  Begin
  User.DisplayStrLn('BASIC is not available in this version of MK');
  If LogEntry.LI <> Nil Then
    LogEntry.WriteEntry('BASIC program ignored (not built in) : ' + Path);
  User.PressEnter;
  End;


{$ENDIF}


End.
