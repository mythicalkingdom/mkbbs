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
  MKDoor, MKGlobT, MKCallerIO;


Type
  EHostAbort = Class(Exception);

  TMKTerm = Class(TBasicTerm)
  Private
    Procedure StopRun(Const Why: String);
  Public
    IO: TCallerIO;                     {the caller: keys, Ctrl-C, lines, output}
    InternalText: AnsiString;          {what the interpreter reported as an internal error}
    Constructor Create; Override;
    Destructor Destroy; Override;
    Procedure OutputString(Const S: AnsiString); Override;
    Function  GetInput: AnsiString; Override;
    Procedure SetColor(Fg, Bg: Integer); Override;
    Procedure ClearScreen; Override;
    Procedure GotoXY(AX, AY: Integer); Override;
    Procedure GetXY(Out AX, AY: Integer); Override;
    Function  HasKeys: Boolean; Override;
    Function  KeysAvailable: Boolean; Override;
    Function  GetKey: AnsiString; Override;
    Procedure Idle; Override;
    Function  PollBreak: Boolean; Override;
    Procedure InternalError(Const What: AnsiString);
  End;


Constructor TMKTerm.Create;
  Begin
  Inherited Create;
  IO := TCallerIO.Create(@StopRun);
  IO.MuteOnStop := True;               {RunLocked would say "Internal error": the caller must not see it}
  End;


Destructor TMKTerm.Destroy;
  Begin
  IO.Free;
  Inherited Destroy;
  End;


Procedure TMKTerm.StopRun(Const Why: String);
  {Leave the interpreter at once: INPUT repeats itself on a bad answer, so a value that
   means "stop" cannot be returned.  RunLocked catches the exception.}
  Begin
  Raise EHostAbort.Create(Why);
  End;


Procedure TMKTerm.OutputString(Const S: AnsiString);
  Begin
  IO.Write(S);
  End;


Function TMKTerm.GetInput: AnsiString;
  Begin
  Result := IO.ReadLine;
  End;


Procedure TMKTerm.SetColor(Fg, Bg: Integer);
  Begin
  IO.SetColor(Fg, Bg);
  End;


Procedure TMKTerm.ClearScreen;
  Begin
  IO.ClearScreen;
  End;


Procedure TMKTerm.GotoXY(AX, AY: Integer);
  Begin
  IO.GotoXY(AX, AY);
  End;


Procedure TMKTerm.GetXY(Out AX, AY: Integer);
  Begin
  AX := IO.X;
  AY := IO.Y;
  End;


Function TMKTerm.HasKeys: Boolean;
  Begin
  Result := True;
  End;


Function TMKTerm.KeysAvailable: Boolean;
  Begin
  Result := IO.KeyAvailable;
  End;


Function TMKTerm.GetKey: AnsiString;
  Var
    K: AnsiString;

  Begin
  IO.RawKey(True, K);
  Result := K;
  End;


Procedure TMKTerm.Idle;
  Begin
  IO.Idle;
  End;


Function TMKTerm.PollBreak: Boolean;
  Begin
  Result := IO.PollBreak;
  End;


Procedure TMKTerm.InternalError(Const What: AnsiString);
  Begin
  If Copy(What, 1, 10) <> 'EHostAbort' Then
    InternalText := What;
  End;


{------------------------------------------------------------ the command}

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
  Full := FindProgramFile(Name);
  If (Full = '') And (Pos(' ', Name) > 0) Then
    Full := FindProgramFile(Copy(Name, 1, Pos(' ', Name) - 1));   {a path with notes after it}
  If Full = '' Then
    Begin
    User.DisplayStrLn('Error: ' + Name + ' Not Found');
    RunLog('BASIC program not found : ' + Name);
    User.PressEnter;
    Exit;
    End;
  If Not ReadWholeFile(Full, Text) Then
    Begin
    User.DisplayStrLn('Error: ' + Name + ' cannot be read');
    RunLog('BASIC program cannot be read : ' + Full);
    User.PressEnter;
    Exit;
    End;
  User.PostStatus(uoDoor);
  RunLog('BASIC program : ' + Full);
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
    Quiet := Term.IO.Gone;
    If Term.IO.Broke Then
      Status := 'break';
    If (Not Quiet) And Term.IO.Raised And Term.IO.Broke Then
      Begin
      If Term.IO.X > 1 Then
        User.DisplayNewLine;
      User.DisplayStrLn('Break');      {Ctrl-C while waiting for the caller}
      End
    Else If (Not Quiet) And (Term.IO.X > 1) Then
      User.DisplayNewLine;             {the program stopped in the middle of a line}
    If Term.InternalText <> '' Then
      RunLog('BASIC internal error : ' + Term.InternalText);
    RunLog('BASIC ended (' + Status + ')' + Copy(' - caller gone', 1, 15 * Ord(Quiet)));
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
