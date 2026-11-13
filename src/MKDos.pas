Unit MKDos;
{$I MKB.Def}

Interface

Uses Dos;

Const
  TicksPerDay = 1573040;    {BIOS timer ticks per 24 hours (18.2065/sec)}

Function GetDosDate: LongInt;
Function GetDOW: Word;
Function GetResultCode: Integer;
  {Exit code of the last program run with Dos.Exec; negative = abnormal end}
Function TimeCounter: LongInt;
  {Timer ticks since midnight, 18.2065 per second.  This replaces the BIOS
   tick counter the DOS version read from absolute address 0040:006C.}
Function TimeOut(Time:LongInt):Boolean; {If time is later than current time
  in timerticks}


Implementation


Function TimeCounter: LongInt;
  Var
    H, M, S, S100: Word;
    Hundredths: LongInt;

  Begin
  GetTime(H, M, S, S100);
  Hundredths := ((LongInt(H) * 60 + M) * 60 + S) * 100 + S100;
  {ticks = hundredths * 18.2065 / 100 = hundredths * 182065 / 1000000}
  TimeCounter := LongInt((Int64(Hundredths) * 182065) Div 1000000);
  End;


Function TimeOut(Time:LongInt):Boolean;
  Var
    TimeDiff: LongInt;

  Begin
  TimeDiff := Time - TimeCounter;
  If TimeDiff < 0 Then
    TimeOut := True
  Else
    Begin
    If (TimeDiff > (TicksPerDay Div 2)) Then   {Counter wrapped at midnight}
      Dec(TimeDiff, TicksPerDay);
    If TimeDiff < 0 Then
      TimeOut := True
    Else
      TimeOut := False;
    End;
  End;


Function GetResultCode: Integer;
  Var
    Code: Word;

  Begin
  Code := DosExitCode;               {High byte = how it ended, low = exit code}
  If Hi(Code) <> 0 Then
    GetResultCode := - Hi(Code)
  Else
    GetResultCode := Lo(Code);
  End;


Function GetDosDate: LongInt;
  Var
    DT: DateTime;
    DosDate: LongInt;
    DOW: Word;

  Begin
  GetDate(DT.Year, DT.Month, DT.Day, DOW);
  GetTime(DT.Hour, DT.Min, DT.Sec, DOW);
  PackTime(DT, DosDate);
  GetDosDate := DosDate;
  End;


Function GetDOW: Word;
  Var
    DT: DateTime;
    DOW: Word;

  Begin
  GetDate(DT.Year, DT.Month, DT.Day, DOW);
  GetDOW := DOW;
  End;


End.
