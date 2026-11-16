Unit MKCallerIO;   {The caller as an embedded interpreter sees it: keys, Ctrl-C, lines, output}

{$MODE OBJFPC}
{$H+}

{
     The BASIC and Pascal interpreters that run menu commands (MKBasicRun,
     MKPascalRun) each have a terminal object of their own; both put the BBS
     caller behind it with TCallerIO:

       Write         output through User.DisplayStr (nothing once the caller is gone)
       ReadLine      one line with backspace / Ctrl-U editing, echoed
       RawKey        the next key; an arrow key is CHR$(0) + the PC scan code
       Pump          takes what the caller typed; Ctrl-C is a break, the rest is queued
       Idle          time over / idle checks and warnings

     Waiting for the caller never blocks for good: a Ctrl-C, a lost carrier, time
     over or the idle limit calls OnStop(Why), which has to raise the interpreter's
     own "stop" exception (the interpreter cannot be given a value that means stop:
     INPUT asks again on a bad answer).

     FindProgramFile, ReadWholeFile and RunLog are the pieces the two runners share
     for the menu data (a program path) and the log.
}

Interface

Type
  TStopProc = Procedure(Const Why: String) Of Object;

  TCallerIO = Class
  Private
    FQueue: AnsiString;                {keys typed ahead (Ctrl-C is not queued)}
    FBreak: Boolean;                   {the caller pressed Ctrl-C}
    FGone: Boolean;                    {the caller is gone (carrier, time, idle)}
    FMuted: Boolean;                   {no more output}
    FRaised: Boolean;                  {a wait was ended with OnStop}
    FLastCR: Boolean;
    FOnStop: TStopProc;
    FX, FY: Integer;                   {cursor position, 1 based}
    Procedure Track(Const S: AnsiString);
  Public
    MuteOnStop: Boolean;               {OnStop mutes the output (the interpreter would say "Internal error")}
    Constructor Create(AOnStop: TStopProc);
    Procedure Pump;
    Function  CallerGone: Boolean;
    Procedure StopRun(Const Why: String);
    Function  RawKey(Wait: Boolean; Var K: AnsiString): Boolean;
    Function  KeyAvailable: Boolean;
    Procedure Write(Const S: AnsiString);
    Function  ReadLine: AnsiString;
    Procedure SetColor(Fg, Bg: Integer);
    Procedure ClearScreen;
    Procedure GotoXY(AX, AY: Integer);
    Procedure Idle;
    Function  PollBreak: Boolean;
    Property  Gone: Boolean Read FGone;
    Property  Broke: Boolean Read FBreak;
    Property  Raised: Boolean Read FRaised;
    Property  X: Integer Read FX;
    Property  Y: Integer Read FY;
  End;


Procedure RunLog(Const S: String);
Function  FindProgramFile(Name: String): String;
Function  ReadWholeFile(Const FN: String; Var Text: AnsiString): Boolean;


Implementation

Uses
  SysUtils, Classes, MKComAbs, MKDoor, MKFile, MKLogEnt, MKCfgAbs;


Constructor TCallerIO.Create(AOnStop: TStopProc);
  Begin
  Inherited Create;
  FOnStop := AOnStop;
  FX := 1;
  FY := 1;
  End;


Procedure TCallerIO.Track(Const S: AnsiString);
  Var
    i: Integer;

  Begin
  For i := 1 To Length(S) Do
    Case S[i] Of
      #8: If FX > 1 Then Dec(FX);
      #10: If FY < 24 Then Inc(FY);
      #13: FX := 1;
      Else
        Begin
        Inc(FX);
        If FX > 80 Then
          Begin
          FX := 1;
          If FY < 24 Then Inc(FY);
          End;
        End;
      End;
  End;


Function TCallerIO.CallerGone: Boolean;
  Begin
  User.CheckInput;                     {time over, carrier lost}
  Result := (Not User.OK) Or (CommActive And (Not CommCarrier));
  If Result Then
    FGone := True;
  End;


Procedure TCallerIO.StopRun(Const Why: String);
  Begin
  If MuteOnStop Then
    FMuted := True;
  FRaised := True;
  If Why <> 'break' Then
    FGone := True;
  If Assigned(FOnStop) Then
    FOnStop(Why);
  End;


Procedure TCallerIO.Pump;
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


Function TCallerIO.RawKey(Wait: Boolean; Var K: AnsiString): Boolean;
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


Function TCallerIO.KeyAvailable: Boolean;
  Begin
  Pump;
  If FBreak Then
    StopRun('break');
  Result := FQueue <> '';
  End;


Procedure TCallerIO.Write(Const S: AnsiString);
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


Function TCallerIO.ReadLine: AnsiString;
  {one line with backspace and Ctrl-U; the end of the line is not echoed (the
   interpreter writes it)}
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
          Write(#8' '#8);
          End;
      #21, #24:
        While Length(Line) > 0 Do
          Begin
          Delete(Line, Length(Line), 1);
          Write(#8' '#8);
          End;
      #27: ;
      Else
        If (Ch >= ' ') And (Length(Line) < 254) Then
          Begin
          Line := Line + Ch;
          Write(Ch);
          End;
      End;
    End;
  End;


Procedure TCallerIO.SetColor(Fg, Bg: Integer);
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


Procedure TCallerIO.ClearScreen;
  Begin
  User.ClearScreen;
  FX := 1;
  FY := 1;
  End;


Procedure TCallerIO.GotoXY(AX, AY: Integer);
  Begin
  If User.GetUserAnsi Then
    Write(#27'[' + IntToStr(AY) + ';' + IntToStr(AX) + 'H');
  FX := AX;
  FY := AY;
  End;


Procedure TCallerIO.Idle;
  Begin
  User.CheckInput;
  User.TimeWarn;
  End;


Function TCallerIO.PollBreak: Boolean;
  Begin
  Pump;
  Result := FBreak Or CallerGone;
  End;


{------------------------------------------------------------ the menu data}

Procedure RunLog(Const S: String);
  Begin
  If LogEntry.LI <> Nil Then
    LogEntry.WriteEntry(S);
  End;


Function FindProgramFile(Name: String): String;
  {as typed, or in the BBS directory; the name is taken as it is written}
  Begin
  Result := '';
  If FileExist(Name) Then
    Result := Name
  Else If (Name <> '') And (Name[1] <> '/') And
          FileExist(Config^.GetBbsPath + Name) Then
    Result := Config^.GetBbsPath + Name;
  End;


Function ReadWholeFile(Const FN: String; Var Text: AnsiString): Boolean;
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


End.
