{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit CfgEvent;   {Events, converted from CFGEVENT}

{$I MKB.Def}

Interface

Procedure DoCfgEvent;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgList;

Const
  ActionNames = 'None|Command|Mailer poll|Mailer hold|Mailer free|Hub pass';
  ActionOf: Array[0..5] Of Byte = (eaNone, eaCommand, eaMailPoll, eaMailHold, eaMailFree, eaHubPass);

Var
  EventNo: Byte;
  Ext: ^EventsCfgType;                 {what the events do (Events.Mk), when the configuration keeps it}


Procedure PickDays(Data: Pointer; Title: String);
  {Days of the week the event runs}
  Var
    Marks: CfgMarks;
    i: Word;

  Begin
  FillChar(Marks, SizeOf(Marks), 0);
  For i := 1 To 7 Do
    Marks[i] := Config^.GetEventOnDay(EventNo, i);
  If RunChecks('Event Days', 'Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday', Marks) Then
    For i := 1 To 7 Do
      Config^.SetEventOnDay(EventNo, i, Marks[i]);
  End;


Function ActionIndex(A: Byte): Byte;
  Var
    i: Byte;

  Begin
  ActionIndex := 0;
  For i := 0 To 5 Do
    If ActionOf[i] = A Then
      ActionIndex := i;
  End;


Procedure EditEvent(EventNum: Word);
  Var
    F: CfgFormObj;
    Status, Forced, TimeH, TimeM, EL: Byte;
    X: EventExtType;
    Act: Byte;
    Excl, LogOut: Boolean;
    Cmd: String;

  Begin
  EventNo := EventNum;
  EL := Config^.GetEventEL(EventNum);
  TimeH := Hi(Config^.GetEventTime(EventNum));
  TimeM := Lo(Config^.GetEventTime(EventNum));
  Status := Config^.GetEventStatus(EventNum);
  Forced := Config^.GetEventForced(EventNum);
  If Ext <> Nil Then
    Begin
    X := Ext^.Ev[EventNum];
    Act := ActionIndex(X.Action);
    Excl := (X.Flags And efExclusive) <> 0;
    LogOut := (X.Flags And efLogOutput) <> 0;
    Cmd := X.Cmd;
    End;
  F.Init('Event ' + Long2Str(EventNum));
  If Ext <> Nil Then
    F.Window(4, 5, 76, 20)
  Else
    F.Window(7, 8, 72, 12);
  F.At(2, 4, 2, 12);
  F.AddChoice('Status:', Status, 1, 0, 'Deleted|Enabled|Disabled',
    'Space or the arrow keys change the status');
  F.At(2, 37, 2, 49);
  F.ZeroPad(2);
  F.AddNumber('Event Time:', TimeH, 1, 0, 24, 'Hour the event starts (0-24)');
  F.At(2, 51, 2, 52);
  F.ZeroPad(2);
  F.AddNumber(':', TimeM, 1, 0, 59, 'Minute the event starts');
  F.At(4, 4, 4, 16);
  F.AddNumber('ErrorLevel:', EL, 1, 0, 255, 'Error level: when it is not 0 the script events.sh in the BBS directory is run with it');
  F.At(4, 33, 4, 41);
  F.AddChoice('Forced:', Forced, 1, 0, 'Normal|Forced|Delayable',
    'Normal, forced (callers are kicked off) or delayable; matters to an exclusive event');
  F.At(4, 52, 4, 52);
  F.AddAction('Days...', PickDays, Nil, '', 'Days of the week the event runs');
  If Ext <> Nil Then
    Begin
    F.At(6, 4, 6, 12);
    F.AddChoice('Action:', Act, 1, 0, ActionNames,
      'What the event does: run a command, or poll / hold / free a link (or *) through the mailer');
    F.At(7, 4, 7, 12);
    F.Show(58);
    F.AddString('Command:', Cmd, 100, 'The command line (no shell); the address or * for the mailer actions; the id of the hub (its map file) for a hub pass');
    F.At(9, 4, 9, 22);
    F.AddChoice('If it was missed:', X.Late, 1, 0, 'Skip|Within minutes|Run|Run per miss',
      'Skip it; run it if at most the minutes below late; run it once however late; run once for each time it was missed');
    F.At(10, 4, 10, 22);
    F.AddNumber('Minutes late:', X.LateMin, 2, 0, 1440, 'Grace for "Within minutes"');
    F.At(10, 30, 10, 42);
    F.AddNumber('Most runs:', X.LateMax, 1, 1, 99, 'Most runs for "Run per miss"');
    F.At(12, 4, 12, 16);
    F.AddYesNo('Exclusive:', Excl, 'Nothing else runs and no one logs on while it runs (packing the message base or the users)');
    F.At(12, 28, 12, 40);
    F.AddYesNo('Log output:', LogOut, 'Put what the command prints into the log');
    F.At(12, 47, 12, 58);
    F.AddNumber('Timeout:', X.TimeoutMin, 2, 0, 1440, 'Minutes before it is stopped, 0 = 60');
    F.At(14, 4, 14, 72);
    F.AddText('Needs mklisten: it runs the events (see EVENTS-PLAN.md).');
    End;
  If F.Execute Then
    Begin
    Config^.SetEventStatus(EventNum, Status);
    Config^.SetEventForced(EventNum, Forced);
    Config^.SetEventEL(EventNum, EL);
    Config^.SetEventTime(EventNum, (TimeH Shl 8) + TimeM);
    If Ext <> Nil Then
      Begin
      X.Action := ActionOf[Act];
      X.Flags := X.Flags And Not (efExclusive Or efLogOutput);
      If Excl Then X.Flags := X.Flags Or efExclusive;
      If LogOut Then X.Flags := X.Flags Or efLogOutput;
      X.Cmd := Cmd;
      Ext^.Ev[EventNum] := X;
      Config^.SetEventExt(Ext^);
      End;
    End;
  End;


Function EventStr(Item: Word): String;
  Var
    S: String;

  Begin
  S := PadRight(Long2Str(Item), ' ', 4) + Word2TimeStr(Config^.GetEventTime(Item)) +
    ' Level ' + Long2Str(Config^.GetEventEL(Item));
  If Ext <> Nil Then
    Begin
    S := PadRight(S, ' ', 22);
    Case Ext^.Ev[Item].Action Of
      eaCommand: S := S + 'Run ' + Ext^.Ev[Item].Cmd;
      eaMailPoll: S := S + 'Poll ' + Ext^.Ev[Item].Cmd;
      eaMailHold: S := S + 'Hold ' + Ext^.Ev[Item].Cmd;
      eaMailFree: S := S + 'Free ' + Ext^.Ev[Item].Cmd;
      eaHubPass: S := S + 'Hub ' + Ext^.Ev[Item].Cmd;
    End;
    If (Ext^.Ev[Item].Flags And efExclusive) <> 0 Then
      S := S + ' (exclusive)';
    End;
  EventStr := S;
  End;


Procedure DoCfgEvent;
  Begin
  Ext := Nil;
  If Config^.HasEventExt Then
    Begin
    New(Ext);
    Config^.GetEventExt(Ext^);
    End;
  RunList('Events', 30, 60, EventStr, EditEvent);
  If Ext <> Nil Then
    Dispose(Ext);
  Ext := Nil;
  End;


End.
