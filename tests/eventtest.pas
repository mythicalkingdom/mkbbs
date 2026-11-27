{ SPDX-License-Identifier: GPL-3.0-or-later }
Program EventTest;   {The arithmetic of MKEvent: days of the week, occurrences, the four ways to handle a missed event}

{$MODE OBJFPC}
{$H+}

Uses MKEvent;

Const
  Sat2000 = 10957;                     {2000-01-01, a Saturday, as a day number}
  AllDays = 127;

Var
  Fails: Integer = 0;


Procedure Check(Name: String; Ok: Boolean);
  Begin
  If Ok Then
    WriteLn('ok   events: ', Name)
  Else
    Begin
    WriteLn('FAIL events: ', Name);
    Inc(Fails);
    End;
  End;


Function At(Day: Int64; H, M: Integer): Int64;
  Begin
  At := Day * 86400 + H * 3600 + M * 60;
  End;


Var
  N: Word;
  L, Due, Lt: Int64;
  R: Word;
  D: Int64;

Begin
  Check('1970-01-01 was a Thursday (4), 2000-01-01 a Saturday (6)', (WeekDayOf(0) = 4) And (WeekDayOf(Sat2000) = 6));
  Check('Sunday is bit 1, Saturday bit 7', RunsOnDay(1, Sat2000 + 1) And Not RunsOnDay(1, Sat2000) And RunsOnDay(64, Sat2000) And
    Not RunsOnDay(64, Sat2000 + 1));
  Check('an occurrence is the day plus the time', OccurrenceTime(5, 90) = 5 * 86400 + 5400);

  Occurrences(180, AllDays, At(10, 2, 0), At(10, 4, 0), N, L);
  Check('one occurrence of 03:00 between 02:00 and 04:00', (N = 1) And (L = At(10, 3, 0)));
  Occurrences(180, AllDays, At(10, 3, 0), At(10, 4, 0), N, L);
  Check('the occurrence at exactly After is not counted', N = 0);
  Occurrences(180, AllDays, At(10, 2, 0), At(10, 3, 0), N, L);
  Check('the occurrence at exactly UpTo is counted', (N = 1) And (L = At(10, 3, 0)));
  Occurrences(180, AllDays, At(10, 2, 0), At(14, 4, 0), N, L);
  Check('five days: five occurrences, the latest on the last day', (N = 5) And (L = At(14, 3, 0)));
  Occurrences(180, 1, At(Sat2000, 0, 0), At(Sat2000 + 14, 0, 0), N, L);
  Check('Sundays only over two weeks: 2', (N = 2) And (WeekDayOf(L Div 86400) = 0));
  Occurrences(180, 0, At(10, 2, 0), At(20, 4, 0), N, L);
  Check('no days: none', N = 0);
  Occurrences(1440, AllDays, At(10, 12, 0), At(11, 12, 0), N, L);
  Check('24:00 is the end of the day (= 00:00 of the next one)', (N = 1) And (L = At(11, 0, 0)));
  Occurrences(0, AllDays, At(10, 12, 0), At(11, 12, 0), N, L);
  Check('00:00 once a day', (N = 1) And (L = At(11, 0, 0)));
  Occurrences(180, AllDays, At(10, 0, 0), At(10 + 3000, 0, 0), N, L);
  Check('a very long outage counts at most the look back (400 days)', N = 400);

  { Decide: daily 03:00, Within 10 minutes, at most 5 runs }
  Decide(elWithin, 10, 5, 180, AllDays, At(10, 2, 59), At(10, 3, 0) + 1, R, D, Lt);
  Check('on time (1 second late): 1 run, LastDue moves to the occurrence', (R = 1) And (D = At(10, 3, 0)) And (Lt = D));
  Decide(elWithin, 10, 5, 180, AllDays, At(10, 3, 0), At(10, 3, 0) + 30, R, D, Lt);
  Check('already dealt with: nothing', (R = 0) And (D = At(10, 3, 0)));
  Decide(elWithin, 10, 5, 180, AllDays, At(9, 12, 0), At(10, 3, 8), R, D, Lt);
  Check('Within: 8 minutes late, grace 10: 1 run', (R = 1) And (D = At(10, 3, 0)));
  Decide(elWithin, 10, 5, 180, AllDays, At(9, 12, 0), At(10, 3, 11), R, D, Lt);
  Check('Within: 11 minutes late: none, but LastDue still moves', (R = 0) And (D = At(10, 3, 0)));
  Decide(elWithin, 0, 5, 180, AllDays, At(9, 12, 0), At(10, 3, 0) + 20, R, D, Lt);
  Check('Within 0 minutes: on time still runs', R = 1);
  Decide(elSkip, 10, 5, 180, AllDays, At(9, 12, 0), At(10, 3, 5), R, D, Lt);
  Check('Skip: 5 minutes late is dropped', (R = 0) And (D = At(10, 3, 0)));
  Decide(elSkip, 10, 5, 180, AllDays, At(9, 12, 0), At(10, 3, 0) + 5, R, D, Lt);
  Check('Skip: on time runs', R = 1);
  Decide(elRun, 10, 5, 180, AllDays, At(9, 12, 0), At(10, 20, 0), R, D, Lt);
  Check('Run: 17 hours late: 1 run', (R = 1) And (D = At(10, 3, 0)));
  Decide(elRun, 10, 5, 180, AllDays, At(9, 12, 0), At(13, 20, 0), R, D, Lt);
  Check('Run: four days missed: still 1 run, LastDue is the latest', (R = 1) And (D = At(13, 3, 0)));
  Decide(elPerMiss, 10, 5, 180, AllDays, At(9, 12, 0), At(13, 20, 0), R, D, Lt);
  Check('Per miss: four days missed: 4 runs', (R = 4) And (D = At(13, 3, 0)));
  Decide(elPerMiss, 10, 5, 180, AllDays, At(9, 12, 0), At(40, 20, 0), R, D, Lt);
  Check('Per miss: a month missed: at most 5 runs', R = 5);
  Decide(elPerMiss, 10, 0, 180, AllDays, At(9, 12, 0), At(40, 20, 0), R, D, Lt);
  Check('Per miss with a cap of 0 is 1', R = 1);
  Decide(elPerMiss, 10, 5, 180, AllDays, At(9, 12, 0), At(10, 3, 0) + 3, R, D, Lt);
  Check('Per miss: on time: 1 run', R = 1);
  Decide(elWithin, 10, 5, 180, 1, At(Sat2000, 12, 0), At(Sat2000 + 1, 2, 0), R, D, Lt);
  Check('a Sunday event does not run at 03:00 on Saturday night', (R = 0) And (D = At(Sat2000, 12, 0)));
  Decide(elWithin, 10, 5, 180, 1, At(Sat2000, 12, 0), At(Sat2000 + 1, 3, 5), R, D, Lt);
  Check('... but on Sunday 03:05 (5 minutes late, grace 10) it runs', R = 1);

  Check('expiry: Skip a minute, Within the grace and a minute, the others never',
    (ExpiresAt(elSkip, 10, 1000) = 1060) And (ExpiresAt(elWithin, 10, 1000) = 1000 + 600 + 60) And (ExpiresAt(elRun, 10, 1000) = 0) And
    (ExpiresAt(elPerMiss, 10, 1000) = 0));

  Check('minutes to the next 03:00 from 02:30 the same day: 30', MinutesToNext(180, AllDays, At(10, 2, 30)) = 30);
  Check('... from 02:30:30: 30 (rounded up)', MinutesToNext(180, AllDays, At(10, 2, 30) + 30) = 30);
  Check('... from 03:00 exactly: tomorrow, 1440', MinutesToNext(180, AllDays, At(10, 3, 0)) = 1440);
  Check('Sunday only, from a Saturday noon: Sunday 03:00 is 15 hours away', MinutesToNext(180, 1, At(Sat2000, 12, 0)) = 15 * 60);
  Check('no days: -1', MinutesToNext(180, 0, At(10, 2, 30)) = -1);

  WriteLn('failures: ', Fails);
  If Fails > 0 Then
    Halt(1);
End.
