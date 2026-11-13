Unit CfgPage;   {Converted from CFGPAGE for Free Vision}

{$I MKB.Def}

Interface

Procedure DoCfgPage;

Implementation

Uses MKString, MKGlobT, MKCfgAbs, CfgForm, CfgGlob;



Type UserRecord = Record
  StartHour: Array[0..6] of Byte;
  StartMin: Array[0..6] of Byte;
  StopHour: Array[0..6] of Byte;
  StopMin: Array[0..6] of Byte;
  AskPageReason: Boolean;
  PageLength: Byte;
  DefaultPage: Byte;
  MaxPages: Byte;
  PageMsgArea: Word;
  End;

Var
  UR: ^UserRecord;

Procedure DoCfgPage;
  Var
    F: CfgFormObj;
    i: Word;
    Tmp: Word;

  Begin
  New(UR);
  For i := 0 To 6 Do
    Begin
    UR^.StartHour[i] := Hi(Config^.GetPageStart(i));
    UR^.StartMin[i] := Lo(Config^.GetPageStart(i));
    UR^.StopHour[i] := Hi(Config^.GetPageStop(i));
    UR^.StopMin[i] := Lo(Config^.GetPageStop(i));
    End;
  UR^.PageMsgArea := Config^.GetPageMsgArea;
  UR^.MaxPages := Config^.GetMaxPageTimes;
  UR^.PageLength := Config^.GetPageLength;
  UR^.DefaultPage := Config^.GetDefaultPage;
  UR^.AskPageReason := Config^.GetAskPageReason;
  F.Init('Paging Configuration');
  F.Window(9, 7, 70, 19);
  F.At(2, 3, 0, 0);
  F.AddText('Paging Hrs');
  F.At(2, 15, 0, 0);
  F.AddText('Start');
  F.At(2, 24, 0, 0);
  F.AddText('Stop');
  F.At(2, 41, 0, 0);
  F.AddText('Options');
  F.At(4, 3, 4, 15);
  F.AddNumber('Sunday:', UR^.StartHour[0], 1, 0, 23, 'Sunday');
  F.At(4, 17, 4, 18);
  F.AddNumber(':', UR^.StartMin[0], 1, 0, 59, '');
  F.At(4, 24, 4, 24);
  F.AddNumber('', UR^.StopHour[0], 1, 0, 23, '');
  F.At(4, 26, 4, 27);
  F.AddNumber(':', UR^.StopMin[0], 1, 0, 59, '');
  F.At(4, 34, 4, 57);
  F.AddNumber('Page Length (Seconds):', UR^.PageLength, 1, 0, 255, 'Page Length (Seconds)');
  F.At(5, 3, 5, 15);
  F.AddNumber('Monday:', UR^.StartHour[1], 1, 0, 23, 'Monday');
  F.At(5, 17, 5, 18);
  F.AddNumber(':', UR^.StartMin[1], 1, 0, 59, '');
  F.At(5, 24, 5, 24);
  F.AddNumber('', UR^.StopHour[1], 1, 0, 23, '');
  F.At(5, 26, 5, 27);
  F.AddNumber(':', UR^.StopMin[1], 1, 0, 59, '');
  F.At(6, 3, 6, 15);
  F.AddNumber('Tuesday:', UR^.StartHour[2], 1, 0, 23, 'Tuesday');
  F.At(6, 17, 6, 18);
  F.AddNumber(':', UR^.StartMin[2], 1, 0, 59, '');
  F.At(6, 24, 6, 24);
  F.AddNumber('', UR^.StopHour[2], 1, 0, 23, '');
  F.At(6, 26, 6, 27);
  F.AddNumber(':', UR^.StopMin[2], 1, 0, 59, '');
  F.At(6, 34, 6, 55);
  F.AddYesNo('Ask Reason for Page:', UR^.AskPageReason, 'Ask Reason for Page');
  F.At(7, 3, 7, 15);
  F.AddNumber('Wednesday:', UR^.StartHour[3], 1, 0, 23, 'Wednesday');
  F.At(7, 17, 7, 18);
  F.AddNumber(':', UR^.StartMin[3], 1, 0, 59, '');
  F.At(7, 24, 7, 24);
  F.AddNumber('', UR^.StopHour[3], 1, 0, 23, '');
  F.At(7, 26, 7, 27);
  F.AddNumber(':', UR^.StopMin[3], 1, 0, 59, '');
  F.At(8, 3, 8, 15);
  F.AddNumber('Thursday:', UR^.StartHour[4], 1, 0, 23, 'Thursday');
  F.At(8, 17, 8, 18);
  F.AddNumber(':', UR^.StartMin[4], 1, 0, 59, '');
  F.At(8, 24, 8, 24);
  F.AddNumber('', UR^.StopHour[4], 1, 0, 23, '');
  F.At(8, 26, 8, 27);
  F.AddNumber(':', UR^.StopMin[4], 1, 0, 59, '');
  F.At(8, 34, 8, 55);
  F.AddNumber('Default Page Number:', UR^.DefaultPage, 1, 0, 255, 'Default Page Number');
  F.At(9, 3, 9, 15);
  F.AddNumber('Friday:', UR^.StartHour[5], 1, 0, 23, 'Friday');
  F.At(9, 17, 9, 18);
  F.AddNumber(':', UR^.StartMin[5], 1, 0, 59, '');
  F.At(9, 24, 9, 24);
  F.AddNumber('', UR^.StopHour[5], 1, 0, 23, '');
  F.At(9, 26, 9, 27);
  F.AddNumber(':', UR^.StopMin[5], 1, 0, 59, '');
  F.At(10, 3, 10, 15);
  F.AddNumber('Saturday:', UR^.StartHour[6], 1, 0, 23, 'Saturday');
  F.At(10, 17, 10, 18);
  F.AddNumber(':', UR^.StartMin[6], 1, 0, 59, '');
  F.At(10, 24, 10, 24);
  F.AddNumber('', UR^.StopHour[6], 1, 0, 23, '');
  F.At(10, 26, 10, 27);
  F.AddNumber(':', UR^.StopMin[6], 1, 0, 59, '');
  F.At(10, 34, 10, 58);
  F.AddNumber('Maximum Pages Per Call:', UR^.MaxPages, 1, 0, 255, 'Maximum Pages Per Call');
  F.At(12, 10, 12, 47);
  F.AddNumber('Message Area for message after Page:', UR^.PageMsgArea, 2, 0, 500, 'Message Area for message after Page');
  If F.Execute Then
    Begin
    For i := 0 To 6 Do
      Begin
      Config^.SetPageStart(i, (256 * UR^.StartHour[i]) + UR^.StartMin[i]);
      Config^.SetPageStop(i, (256 * UR^.StopHour[i]) + UR^.StopMin[i]);
      End;
    Config^.SetPageMsgArea(UR^.PageMsgArea);
    Config^.SetMaxPageTimes(UR^.MaxPages);
    Config^.SetPageLength(UR^.PageLength);
    Config^.SetDefaultPage(UR^.DefaultPage);
    Config^.SetAskPageReason(UR^.AskPageReason);
    End;
    Dispose(UR);
  End;


End.
