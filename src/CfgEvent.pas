Unit CfgEvent;   {Events, converted from CFGEVENT}

{$I MKB.Def}

Interface

Procedure DoCfgEvent;

Implementation

Uses MKString, MKCfgAbs, CfgForm, CfgList;

Var
  EventNo: Byte;


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


Procedure EditEvent(EventNum: Word);
  Var
    F: CfgFormObj;
    Status, Forced, TimeH, TimeM, EL: Byte;

  Begin
  EventNo := EventNum;
  EL := Config^.GetEventEL(EventNum);
  TimeH := Hi(Config^.GetEventTime(EventNum));
  TimeM := Lo(Config^.GetEventTime(EventNum));
  Status := Config^.GetEventStatus(EventNum);
  Forced := Config^.GetEventForced(EventNum);
  F.Init('Event ' + Long2Str(EventNum));
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
  F.AddNumber('ErrorLevel:', EL, 1, 0, 255, 'Error level the BBS exits with');
  F.At(4, 33, 4, 41);
  F.AddChoice('Forced:', Forced, 1, 0, 'Normal|Forced|Delayable',
    'Normal, forced (callers are kicked off) or delayable');
  F.At(4, 52, 4, 52);
  F.AddAction('Days...', PickDays, Nil, '', 'Days of the week the event runs');
  If F.Execute Then
    Begin
    Config^.SetEventStatus(EventNum, Status);
    Config^.SetEventForced(EventNum, Forced);
    Config^.SetEventEL(EventNum, EL);
    Config^.SetEventTime(EventNum, (TimeH Shl 8) + TimeM);
    End;
  End;


Function EventStr(Item: Word): String;
  Begin
  EventStr := PadRight(Long2Str(Item), ' ', 4) + Word2TimeStr(Config^.GetEventTime(Item)) +
    ' Level ' + Long2Str(Config^.GetEventEL(Item));
  End;


Procedure DoCfgEvent;
  Begin
  RunList('Events', 30, 36, EventStr, EditEvent);
  End;


End.
