Unit MKEvent;   {When an event is due: no files, no clock, only numbers (see EVENTS-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
     All times are "local seconds": the seconds since 1970-01-01 00:00:00 as the wall clock of the system shows them
     (UNIX time plus the time zone), so a day is exactly 86400 of them and the day of the week follows from the day
     number.  The caller turns real time into local seconds and back.  Daylight saving changes are the caller's
     business: an event is scheduled by the wall clock, so it runs at 03:00 on both sides of the change.

     An event is a time of day (minutes, 0..1440; 1440 = 24:00 = the end of the day) and the days of the week it runs
     (bit 1 = Sunday ... bit 7 = Saturday, as Config.Mk).  An *occurrence* is one such time on one such day.
     "Missed" occurrences are those that fell between the last one dealt with (LastDue) and now.
}

Interface

Const
  OnTimeSecs = 60;                     {an occurrence at most this late is on time, not missed}
  MaxLookBack = 400;                   {days of occurrences counted (a longer outage counts as this long)}
  elSkip = 0;                          {Late modes: the same numbers as elSkip ... in MKGlobT}
  elWithin = 1;
  elRun = 2;
  elPerMiss = 3;

Function WeekDayOf(Day: Int64): Integer;
  {0 = Sunday ... 6 = Saturday}

Function RunsOnDay(Days: Byte; Day: Int64): Boolean;

Function OccurrenceTime(Day: Int64; Minutes: Word): Int64;

Procedure Occurrences(Minutes: Word; Days: Byte; After, UpTo: Int64; Var Count: Word; Var Latest: Int64);
  {How many occurrences fall after After and at or before UpTo (at most MaxLookBack days back), and the latest of
   them (0 when none)}

Procedure Decide(Late: Byte; LateMin: Word; LateMax: Byte; Minutes: Word; Days: Byte; LastDue, Now: Int64;
  Var Runs: Word; Var NewDue, Latest: Int64);
  {The occurrences after LastDue up to now: how many runs they make (Runs), the latest occurrence (Latest, what the
   runs are for) and the new LastDue (the latest occurrence, or LastDue when there was none).
     one on time (at most OnTimeSecs late)  -> 1 run, whatever Late says
     elSkip     the missed ones are dropped    -> 0
     elWithin   1 run if the latest is at most LateMin minutes late, else 0
     elRun      1 run
     elPerMiss  one run for each, at most LateMax (at least 1)}

Function ExpiresAt(Late: Byte; LateMin: Word; Due: Int64): Int64;
  {A run that has to wait (for callers to leave, for another event) is dropped after this time; 0 = never}

Function MinutesToNext(Minutes: Word; Days: Byte; Now: Int64): LongInt;
  {Minutes (rounded up) to the next occurrence after Now, -1 when the event never runs}


Implementation

Function WeekDayOf(Day: Int64): Integer;
  Begin
  WeekDayOf := Integer((Day + 4) Mod 7);          {1970-01-01 was a Thursday}
  End;


Function RunsOnDay(Days: Byte; Day: Int64): Boolean;
  Begin
  RunsOnDay := (Days And (1 Shl WeekDayOf(Day))) <> 0;
  End;


Function OccurrenceTime(Day: Int64; Minutes: Word): Int64;
  Begin
  OccurrenceTime := Day * 86400 + Int64(Minutes) * 60;
  End;


Procedure Occurrences(Minutes: Word; Days: Byte; After, UpTo: Int64; Var Count: Word; Var Latest: Int64);
  Var
    D, D1, D2: Int64;
    T: Int64;

  Begin
  Count := 0;
  Latest := 0;
  If (Minutes > 1440) Or (Days = 0) Or (UpTo <= After) Then
    Exit;
  If UpTo - After > Int64(MaxLookBack) * 86400 Then
    After := UpTo - Int64(MaxLookBack) * 86400;
  D1 := After Div 86400;
  D2 := UpTo Div 86400;
  For D := D1 To D2 Do
    If RunsOnDay(Days, D) Then
      Begin
      T := OccurrenceTime(D, Minutes);
      If (T > After) And (T <= UpTo) Then
        Begin
        Inc(Count);
        Latest := T;
        End;
      End;
  End;


Procedure Decide(Late: Byte; LateMin: Word; LateMax: Byte; Minutes: Word; Days: Byte; LastDue, Now: Int64;
  Var Runs: Word; Var NewDue, Latest: Int64);
  Var
    N: Word;
    Lateness, Grace: Int64;

  Begin
  Runs := 0;
  NewDue := LastDue;
  Occurrences(Minutes, Days, LastDue, Now, N, Latest);
  If N = 0 Then
    Exit;
  NewDue := Latest;
  Lateness := Now - Latest;
  If Lateness <= OnTimeSecs Then
    Begin
    Runs := 1;                         {on time: the ones before it (a very late tick) are not missed runs}
    If (Late = elPerMiss) And (N > 1) Then
      Begin
      Runs := N;
      If LateMax < 1 Then LateMax := 1;
      If Runs > LateMax Then Runs := LateMax;
      End;
    Exit;
    End;
  Case Late Of
    elSkip: Runs := 0;
    elWithin:
      Begin
      Grace := Int64(LateMin) * 60;
      If Grace < OnTimeSecs Then Grace := OnTimeSecs;
      If Lateness <= Grace Then Runs := 1;
      End;
    elRun: Runs := 1;
    elPerMiss:
      Begin
      Runs := N;
      If LateMax < 1 Then LateMax := 1;
      If Runs > LateMax Then Runs := LateMax;
      End;
    Else
      Runs := 0;
  End;
  End;


Function ExpiresAt(Late: Byte; LateMin: Word; Due: Int64): Int64;
  Begin
  Case Late Of
    elSkip: ExpiresAt := Due + OnTimeSecs;
    elWithin: ExpiresAt := Due + Int64(LateMin) * 60 + OnTimeSecs;
    Else
      ExpiresAt := 0;
  End;
  End;


Function MinutesToNext(Minutes: Word; Days: Byte; Now: Int64): LongInt;
  Var
    D: Int64;
    T: Int64;
    I: Integer;

  Begin
  MinutesToNext := -1;
  If (Minutes > 1440) Or (Days = 0) Then
    Exit;
  D := Now Div 86400;
  For I := 0 To 8 Do
    Begin
    If RunsOnDay(Days, D + I) Then
      Begin
      T := OccurrenceTime(D + I, Minutes);
      If T > Now Then
        Begin
        MinutesToNext := LongInt((T - Now + 59) Div 60);
        Exit;
        End;
      End;
    End;
  End;


End.
