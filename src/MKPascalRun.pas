{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKPascalRun;   {Menu command 170: run a Pascal program for the caller}

{$MODE OBJFPC}
{$H+}

{
     The menu item's data is the path of a Pascal program (Turbo Pascal 5.5/7 style
     source; "\" or "/" in the path; a relative path is looked for in the BBS
     directory), optionally followed by parameters for ParamStr:

          GAMES\HANGMAN.PAS
          GAMES\HANGMAN.PAS easy 10

     The program is compiled and run by the mkpascal interpreter
     (../mkpascal-fpc, see build.sh).  Its units, include files and data files are
     read from and written to the directory the program is in, and nowhere else.

     The caller is the terminal: Write / WriteLn go through User.DisplayStr, ReadLn
     reads a line with simple editing, ReadKey / KeyPressed read single keys (the
     arrow keys come as Turbo Pascal reports them: #0 then the scan code), and
     ClrScr, GotoXY and TextColor use ANSI when the caller has it.

     Whatever ends the program ends the menu command and the menu goes on:
       the end of the program or Halt        back to the menu
       a compile error, a run time error,
       a limit or Ctrl-C                     the message, then Press Enter
       carrier lost, time over, idle timeout the program is stopped quietly
     Ctrl-C also works while the program computes or waits in ReadLn / ReadKey.

     Built without the interpreter (no -dMKPASCAL) the command only tells the
     caller that Pascal is not available.
}

Interface

Uses Classes, HostReg;

Procedure RunPascalProgram(Data: ShortString);

Procedure RunPascalExtension(Const Full: AnsiString; Reg: THostRegistry; Secs: LongInt; Args: TStrings; Silent: Boolean);
  {Silent (a hook): an error is only logged, the caller is not asked to press Enter.  An extension of the sysop (MKExtRun, menu command 175): the program at Full, with the host commands of Reg, for at most Secs seconds of run time (0: no limit); Args are its parameters (ParamStr)}


Implementation


{$IFDEF MKPASCAL}

Uses
  SysUtils, mkp_defs, mkp_harness, mkpascal,
  MKDoor, MKGlobT, MKCallerIO;


Type
  TPasTerm = Class(TMKTerm)
  Private
    FScan: Integer;                    {the scan code that follows an extended key, -1 = none}
    Procedure StopRun(Const Why: String);
  Public
    IO: TCallerIO;
    Reg: THostRegistry;                {HostCall: the commands of an extension (not ours); Nil for a plain program}
    Constructor Create;
    Destructor Destroy; Override;
    Procedure Write(Const S: RawByteString); Override;
    Function  ReadLine(Out Line: RawByteString): Boolean; Override;
    Function  LineEndEchoed: Boolean; Override;
    Function  ReadKey: Integer; Override;
    Function  KeyPressed: Boolean; Override;
    Procedure ClearScreen; Override;
    Procedure GotoXY(X, Y: Integer); Override;
    Procedure GetXY(Out X, Y: Integer); Override;
    Procedure SetColor(Fg, Bg: Integer); Override;
    Function  HostCall(Const Cmd: RawByteString; Out Err: String): RawByteString; Override;
  End;

  { called by the interpreter every few thousand steps }
  TYielder = Class
    Session: TMKSession;
    IO: TCallerIO;
    Procedure Yield;
  End;


Constructor TPasTerm.Create;
  Begin
  Inherited Create;
  FScan := -1;
  IO := TCallerIO.Create(@StopRun);
  End;


Destructor TPasTerm.Destroy;
  Begin
  IO.Free;
  Inherited Destroy;
  End;


Procedure TPasTerm.StopRun(Const Why: String);
  {Ctrl-C, carrier lost, time over: end the program from inside a wait.  Run reports
   EMKBreak as "Program interrupted at line N." (not shown when the caller is gone).}
  Begin
  Raise EMKBreak.Create(Why);
  End;


Procedure TPasTerm.Write(Const S: RawByteString);
  Begin
  IO.Write(S);
  End;


Function TPasTerm.ReadLine(Out Line: RawByteString): Boolean;
  Begin
  Line := IO.ReadLine;
  Result := True;
  End;


Function TPasTerm.LineEndEchoed: Boolean;
  Begin
  Result := False;                     {the interpreter writes CR LF}
  End;


Function TPasTerm.ReadKey: Integer;
  Var
    K: AnsiString;

  Begin
  If FScan >= 0 Then
    Begin
    Result := FScan;
    FScan := -1;
    Exit;
    End;
  IO.RawKey(True, K);
  If (Length(K) = 2) And (K[1] = #0) Then
    Begin
    FScan := Ord(K[2]);                {an arrow key: #0 now, the scan code with the next ReadKey}
    Result := 0;
    End
  Else
    Result := Ord(K[1]);
  End;


Function TPasTerm.KeyPressed: Boolean;
  Begin
  Result := (FScan >= 0) Or IO.KeyAvailable;
  End;


Procedure TPasTerm.ClearScreen;
  Begin
  IO.ClearScreen;
  End;


Procedure TPasTerm.GotoXY(X, Y: Integer);
  Begin
  IO.GotoXY(X, Y);
  End;


Procedure TPasTerm.GetXY(Out X, Y: Integer);
  Begin
  X := IO.X;
  Y := IO.Y;
  End;


Procedure TPasTerm.SetColor(Fg, Bg: Integer);
  Begin
  IO.SetColor(Fg, Bg);
  End;


Function TPasTerm.HostCall(Const Cmd: RawByteString; Out Err: String): RawByteString;
  Var
    E: AnsiString;

  Begin
  If Reg <> Nil Then
    Begin
    Result := Reg.Call(Cmd, E);
    Err := E;
    End
  Else
    Result := Inherited HostCall(Cmd, Err);
  End;


Procedure TYielder.Yield;
  Begin
  IO.Idle;
  If IO.PollBreak Then
    Session.RequestBreak;              {Ctrl-C or the caller is gone: stops at the next check}
  End;


{------------------------------------------------------------ the command}

Procedure RunPascalText(Const Full, Text: AnsiString; Rest0: AnsiString; Reg: THostRegistry; Secs: LongInt; Args: TStrings; Silent: Boolean); Forward;


Procedure RunPascalProgram(Data: ShortString);
  Var
    Name, Full, Rest, Text: AnsiString;
    Term: TPasTerm;
    Files: TDiskFiles;
    Session: TMKSession;
    Yielder: TYielder;
    Status: TMKRunStatus;
    Quiet, Failed: Boolean;
    i, p: Integer;

  Begin
  Name := Trim(Data);
  For i := 1 To Length(Name) Do
    If Name[i] = '\' Then
      Name[i] := '/';
  Rest := '';
  Full := FindProgramFile(Name);       {the whole text may be a path}
  If Full = '' Then
    Begin                              {the first word is the path, the rest are parameters}
    p := Pos(' ', Name);
    If p > 0 Then
      Begin
      Rest := Trim(Copy(Name, p + 1, 255));
      Name := Copy(Name, 1, p - 1);
      Full := FindProgramFile(Name);
      End;
    End;
  If (Length(Name) >= 2) And (Name[1] = '"') And (Name[Length(Name)] = '"') Then
    Name := Copy(Name, 2, Length(Name) - 2);
  If Full = '' Then
    Begin
    User.DisplayStrLn('Error: ' + Name + ' Not Found');
    RunLog('Pascal program not found : ' + Name);
    User.PressEnter;
    Exit;
    End;
  If Not ReadWholeFile(Full, Text) Then
    Begin
    User.DisplayStrLn('Error: ' + Name + ' cannot be read');
    RunLog('Pascal program cannot be read : ' + Full);
    User.PressEnter;
    Exit;
    End;
  RunPascalText(Full, Text, Rest, Nil, 0, Nil, False);
  End;


Procedure RunPascalText(Const Full, Text: AnsiString; Rest0: AnsiString; Reg: THostRegistry; Secs: LongInt; Args: TStrings; Silent: Boolean);
  Var
    Rest: AnsiString;
    Term: TPasTerm;
    Files: TDiskFiles;
    Session: TMKSession;
    Yielder: TYielder;
    Status: TMKRunStatus;
    Quiet, Failed: Boolean;
    i, p: Integer;

  Begin
  Rest := Rest0;
  User.PostStatus(uoDoor);
  RunLog('Pascal program : ' + Full + Copy(' ' + Rest, 1, 255 * Ord(Rest <> '')));
  Status := rsError;
  Failed := False;
  Quiet := False;
  Term := TPasTerm.Create;
  Term.Reg := Reg;
  Files := TDiskFiles.Create(ExtractFileDir(Full));
  Session := TMKSession.Create(Term, Files);
  Yielder := TYielder.Create;
  Try
    Yielder.Session := Session;
    Yielder.IO := Term.IO;
    Session.OnYield := @Yielder.Yield;
    If Secs > 0 Then
      Session.MaxRuntimeMs := Secs * 1000;
    If Args <> Nil Then
      For i := 1 To Args.Count - 1 Do
        Session.Params.Add(Args[i]);
    Try
      While Rest <> '' Do              {parameters for ParamStr}
        Begin
        p := Pos(' ', Rest);
        If p = 0 Then
          p := Length(Rest) + 1;
        Session.Params.Add(Copy(Rest, 1, p - 1));
        Rest := Trim(Copy(Rest, p + 1, 255));
        End;
      If Session.LoadSource(Text) Then
        Status := Session.Run
      Else
        Begin
        Failed := True;                {a compile error}
        User.DisplayStrLn(Session.LastError);
        RunLog('Pascal compile error : ' + Session.LastError);
        End;
    Except
      On E: Exception Do
        Begin
        Failed := True;
        User.DisplayStrLn('Error: ' + E.Message);
        RunLog('Pascal error : ' + E.ClassName + ': ' + E.Message);
        End;
    End;
    Quiet := Term.IO.Gone;
    If (Not Quiet) And (Term.IO.X > 1) And (Not Failed) Then
      User.DisplayNewLine;             {the program stopped in the middle of a line}
    If Not Failed Then
      Begin
      Case Status Of
        rsEnd: RunLog('Pascal ended (end)');
        rsHalt: RunLog('Pascal ended (halt ' + IntToStr(Session.ExitCode) + ')');
        rsError: RunLog('Pascal ended (error ' + IntToStr(Session.ExitCode) + ')');
        rsLimit: RunLog('Pascal ended (limit)');
        rsBreak: RunLog('Pascal ended (break)' + Copy(' - caller gone', 1, 15 * Ord(Quiet)));
        End;
      End;
    If (Not Quiet) And (Not Silent) And (Failed Or (Status In [rsError, rsLimit, rsBreak])) Then
      User.PressEnter;                 {an error, a limit or a break: let the caller read it}
  Finally
    Yielder.Free;
    Session.Free;
    Files.Free;
    Term.Free;
  End;
  End;


Procedure RunPascalExtension(Const Full: AnsiString; Reg: THostRegistry; Secs: LongInt; Args: TStrings; Silent: Boolean);
  Var
    Text: AnsiString;

  Begin
  If Not ReadWholeFile(Full, Text) Then
    Begin
    User.DisplayStrLn('Error: the extension cannot be read');
    RunLog('Pascal extension cannot be read : ' + Full);
    User.PressEnter;
    Exit;
    End;
  RunPascalText(Full, Text, '', Reg, Secs, Args, Silent);
  End;


{$ELSE}


Uses MKDoor, MKLogEnt;


Procedure RunPascalProgram(Data: ShortString);
  Begin
  User.DisplayStrLn('Pascal is not available in this version of MK');
  If LogEntry.LI <> Nil Then
    LogEntry.WriteEntry('Pascal program ignored (not built in) : ' + Data);
  User.PressEnter;
  End;


Procedure RunPascalExtension(Const Full: AnsiString; Reg: THostRegistry; Secs: LongInt; Args: TStrings; Silent: Boolean);
  Begin
  User.DisplayStrLn('Pascal is not available in this version of MK');
  User.PressEnter;
  End;


{$ENDIF}


End.
