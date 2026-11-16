Unit MKQuest;
{$I MKB.Def}

Interface

Uses MKFile;

Const
  QAMaxAnswers = 50;
  QAMaxOutput = 100;
  MaxIf = 20;
  MaxGoSub = 20;

Type QuestInfoType = Record
  Answers: Array[1..QAMaxAnswers] Of String;
  PostLines: Array[1..QAMaxOutput] Of String;
  Name: String[8];
  Error: Word;
  QF: TFile;
  Finished: Boolean;
  OutLines: Word;
  SkippingIf: Boolean;
  IfStackPtr: Word;
  IgnoredIf: Word;
  IfStack: Array[1..MaxIf] of Boolean;
  GoSubPtr: Word;
  GoSubStack: Array[1..MaxGoSub] of LongInt;
  End;


Type QuestObj = Object
  QI: ^QuestInfoType;
  Procedure Init;                           {Initialize}
  Procedure Process(FN: String);            {Load Q-A file and execute}
  Procedure DoCmd(TmpStr: String);          {Process text command line}
  Procedure Done;                           {Done}
  Function  GetError: Word;                 {Get error code}
  Procedure AddStr(St: String);             {Add output string}
  Function  FindGo(TmpStr2: String): Boolean; {Find label for goto gosub}
  End;


Implementation


Uses MKString, MKGlobT, MKCfgAbs, MKDoor, MKCodes, MKShell, MKDos, MKMisc,
  MKComAbs, MKCmd, MKRCfgMK,
    MKVCrt,
    Dos;


Procedure QuestObj.Init;                      {Initialize}
  Begin
  New(QI);
  QI^.Error := 0;
  End;


Function QuestObj.GetError: Word;
  Begin
  GetError := QI^.Error;
  End;


Procedure QuestObj.AddStr(St: String);
  Begin
  If (QI^.OutLines < QaMaxOutPut) Then
    Begin
    Inc(QI^.OutLines);
    QI^.PostLines[QI^.OutLines] := St;
    End;
  End;


Function QuestObj.FindGo(TmpStr2: String): Boolean;
  Var
    TmpLong: LongInt;
    TmpStr3: String;
    TmpBool: Boolean;

  Begin
  TmpLong := QI^.QF.GetTextPos;
  If QI^.QF.Restart Then;
  TmpStr3 := StripBoth(QI^.QF.GetString, ' ');
  TmpBool := False;
  While ((QI^.QF.StringFound) And (Not TmpBool)) Do
    Begin
    If TmpStr3[1] = ':' Then
      Begin
      TmpStr3 := Copy(TmpStr3, 2, 255);
      If Pos(' ', TmpStr3) > 0 Then
        TmpStr3 := Copy(TmpStr3, 1, Pos(' ', TmpStr3) - 1);
      If Upper(TmpStr3) = Upper(TmpStr2) Then
        TmpBool := True;
      End;
    If Not TmpBool Then
      TmpStr3 := StripBoth(QI^.QF.GetString, ' ');
    End;
  If Not TmpBool Then
    Begin
    If QI^.QF.SeekTextFile(TmpLong) Then;
    User.DisplayStrLn(Prompts.GetString(195));
    End;
  FindGo := TmpBool;
  End;


Procedure QuestObj.DoCmd(TmpStr: String);
  Var
    TmpStr2: String;
    TmpStr3: String;
    Cmd: String[50];
    Tmp: Word;
    Tmp2: Word;
    Tmp3: Word;
    TmpLong: LongInt;
    TmpLong2: LongInt;
    TmpLong3: LongInt;
    TmpBool: Boolean;
    Code: Word;
    Sec: SecType;
    DT: DateTime;

  Begin
  Cmd := Upper(ExtractWord(TmpStr, 1));
  If (QI^.SkippingIf) Then
    Begin
    If Cmd = 'IF' Then
      Inc(QI^.IgnoredIf);
    If Cmd = 'ENDIF' Then
      Begin
      If QI^.IgnoredIf > 0 Then
        Begin
        Dec(QI^.IgnoredIf);
        End
      Else
        Begin
        If QI^.IfStackPtr > 1 Then
          Begin
          QI^.SkippingIf := QI^.IfStack[QI^.IfStackPtr];
          Dec(QI^.IfStackPtr);
          End
        Else
          Begin
          If QI^.IfStackPtr > 0 Then
            Dec(QI^.IfStackPtr);
          QI^.SkippingIf := False;
          End;
        End;
      End;
    If Cmd = 'ELSE' Then
      Begin
      If (QI^.IgnoredIf = 0) Then
        Begin
        If (QI^.IfStackPtr > 0) Then
          Begin
          QI^.IfStack[QI^.IfStackPtr] := Not QI^.IfStack[QI^.IfStackPtr];
          QI^.SkippingIf := QI^.IfStack[QI^.IfStackPtr];
          End;
        End;
      End;
    Cmd := ';';
    End;
  If ((Cmd[1] <> ':') And (Cmd[1] <> ';')) Then
    Begin
    Case Cmd[1] Of
      'A': Begin
           If Cmd = 'ASK' Then
             Begin
             If WordCount(TmpStr) >= 3 Then
               Begin
               Val(ExtractWord(TmpStr,3), Tmp, Code);
               If Code = 0 Then
                 Val(ExtractWord(TmpStr,2), Tmp2, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= QaMaxAnswers)
               And (Tmp2 > 0) And (Tmp2 <= 255)) Then
                 Begin
                 QI^.Answers[Tmp] := User.InputStr('',Tmp2);
                 User.DisplayNewLine;
                 End;
               End;
             End
           Else If Cmd = 'ASKEDIT' Then
             Begin
             If WordCount(TmpStr) >= 3 Then
               Begin
               Val(ExtractWord(TmpStr,3), Tmp, Code);
               If Code = 0 Then
                 Val(ExtractWord(TmpStr,2), Tmp2, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= QaMaxAnswers)
               And (Tmp2 > 0) And (Tmp2 <= 255)) Then
                 Begin
                 User.DisplayStr(QI^.Answers[Tmp]);
                 QI^.Answers[Tmp] := User.InputStr(QI^.Answers[Tmp],Tmp2);
                 User.DisplayNewLine;
                 End;
               End;
             End
           Else If Cmd = 'ASKFORCED' Then
             Begin
             If WordCount(TmpStr) >= 4 Then
               Begin
               Val(ExtractWord(TmpStr,4), Tmp, Code);
               If Code = 0 Then
                 Val(ExtractWord(TmpStr,2), Tmp2, Code);
               If Code = 0 Then
                 Val(ExtractWord(TmpStr, 3), Tmp3, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= QaMaxAnswers)
               And (Tmp3 >= Tmp2) And (Tmp3 <= 255)
               And (Tmp2 > 0) And (Tmp2 <= 255)) Then
                 Begin
                 QI^.Answers[Tmp] := '';
                 While ((User.Ok) and (Length(QI^.Answers[Tmp]) < Tmp2)) Do
                   Begin
                   QI^.Answers[Tmp] := User.InputStr('',Tmp3);
                   User.DisplayNewLine;
                   If (Length(QI^.Answers[Tmp]) < Tmp2) Then
                     User.DisplayStrLn(Prompts.GetString(196) +
                     ' ' + Long2Str(Tmp2));
                   End;
                 End;
               End;
             End
           Else If Cmd = 'ASKNUMBER' Then
             Begin
             If WordCount(TmpStr) >= 4 Then
               Begin
               Val(ExtractWord(TmpStr,4), Tmp, Code);
               If Code = 0 Then
                 Val(ExtractWord(TmpStr,2), TmpLong2, Code);
               If Code = 0 Then
                 Val(ExtractWord(TmpStr, 3), TmpLong3, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= QaMaxAnswers)
               And (TmpLong3 >= TmpLong2)) Then
                 Begin
                 TmpLong := User.AskNumber(0, TmpLong2, TmpLong3);
                 QI^.Answers[Tmp] := Long2Str(TmpLong);
                 User.DisplayNewLine;
                 End;
               End;
             End
           Else If Cmd = 'ASKDATE' Then
             Begin
             If WordCount(TmpStr) >= 3 Then
               Begin
               Val(ExtractWord(TmpStr,2), Tmp, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= QaMaxAnswers)) Then
                 Begin
                 If (Pos('"', TmpStr) > 0) Then
                   Begin
                   Delete(TmpStr, 1, Pos('"', TmpStr));
                   If (Pos('"', TmpStr) > 0) Then
                     Begin
                     TmpStr := Copy(TmpStr, 1, Pos('"', TmpStr) - 1);
                     User.DisplayStr(' ' + Prompts.GetString(58) + ' ');
                     DT.Month := 0;
                     DT.Year := 0;
                     DT.Day := 0;
                     If User.AskDate(DT) Then
                       QI^.Answers[Tmp] := FormattedDate(DT, TmpStr);
                     User.DisplayNewLine;
                     End;
                   End;
                 End;
               End;
             End
           Else If Cmd = 'ASKFORMATTED' Then
             Begin
             If WordCount(TmpStr) >= 3 Then
               Begin
               Val(ExtractWord(TmpStr,2), Tmp, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= QaMaxAnswers)) Then
                 Begin
                 If (Pos('"', TmpStr) > 0) Then
                   Begin
                   Delete(TmpStr, 1, Pos('"', TmpStr));
                   If (Pos('"', TmpStr) > 0) Then
                     Begin
                     TmpStr := Copy(TmpStr, 1, Pos('"', TmpStr) - 1);
                     QI^.Answers[Tmp] := User.AskFormatted(TmpStr);
                     User.DisplayNewLine;
                     End;
                   End;
                 End
               Else
                 User.DisplayStrLn(Prompts.GetString(195));
               End
             Else
               User.DisplayStrLn(Prompts.GetString(195));
             End
           Else If Cmd = 'ASKPHONE' Then
             Begin
             If WordCount(TmpStr) >= 2 Then
               Begin
               Val(ExtractWord(TmpStr,2), Tmp, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= QaMaxAnswers)) Then
                 Begin
                 QI^.Answers[Tmp] := User.AskPhone;
                 User.DisplayNewLine;
                 End
               Else
                 User.DisplayStrLn(Prompts.GetString(195));
               End
             Else
               User.DisplayStrLn(Prompts.GetString(195));
             End;
           End;
      'B': Begin
           If Cmd = 'BEEP' Then
             Begin
             User.DisplayChr(#7);
             End;
           End;
      'C': Begin
           If Cmd = 'CLEARSCREEN' Then
             Begin
             User.ClearScreen;
             End
           Else If Cmd = 'CHANGECOLOR' Then
             Begin
             If WordCount(TmpStr) >= 3 Then
               Begin
               Val(ExtractWord(TmpStr,2), Tmp, Code);
               If Code = 0 Then
                 Val(ExtractWord(TmpStr,3), Tmp2, Code);
               If Code = 0 Then
                 User.DisplayColor(Tmp, Tmp2)
               Else
                 User.DisplayStrLn(Prompts.GetString(195));
               End;
             End;
           End;
      'D': Begin
           If Cmd = 'DISPLAY' Then
             Begin
             TmpStr := StripLead(Copy(TmpStr, 9, 255),' ');
             TmpStr := StripBoth(TmpStr, '"');
             Tmp := 1;
             If User.Ok Then
               Begin
               While Tmp <= Length(TmpStr) Do
                 Begin
                 If TmpStr[Tmp] = '|' Then
                   User.DisplayNewLine
                 Else
                   User.DisplayChr(TmpStr[Tmp]);
                 Inc(Tmp);
                 End;
               End;
             End
           Else If Cmd = 'DISPLAYFILE' Then
             Begin
             If User.Ok Then
               TmpStr2 := BbsDisplay.DisplayBbsFile(ExtractWord(TmpStr, 2), '');
             If (BbsDisplay.GetError <> 0) Then
               User.DisplayStrLn(Prompts.GetString(195));
             End;
           End;
      'E': Begin
           If Cmd = 'ENDIF' Then
             Begin
             If QI^.IfStackPtr > 0 Then
               Begin
               Dec(QI^.IfStackPtr);
               If QI^.IfStackPtr > 0 Then
                 QI^.SkippingIf := QI^.IfStack[QI^.IfStackPtr]
               Else
                 QI^.SkippingIf := False;
               End
             Else
               QI^.SkippingIf := False;
             End
           Else If Cmd = 'ELSE' Then
             Begin
             If ((QI^.IgnoredIf = 0) And (QI^.IfStackPtr > 0)) Then
               Begin
               QI^.IfStack[QI^.IfStackPtr] := Not QI^.IfStack[QI^.IfStackPtr];
               QI^.SkippingIf := QI^.IfStack[QI^.IfStackPtr];
               End;
             End
           Else If Cmd = 'EXEC' Then
             Begin
             TmpStr2 := Copy(TmpStr,6, 255);
             TmpStr2 := StripBoth(TmpStr2, ' ');
             If User.Ok Then
               TypeSeven(TmpStr2);
             End;
           End;
      'G': Begin
           If Cmd = 'GETCHOICE' Then
             Begin
             If WordCount(TmpStr) >= 3 Then
               Begin
               Val(ExtractWord(TmpStr,3), Tmp, Code);
               If Code = 0 Then
                 Begin
                 TmpStr2 := Upper(ExtractWord(TmpStr, 2));
                 If ((Tmp > 0) And (Tmp <= QaMaxAnswers)) Then
                   Begin
                   QI^.Answers[Tmp] := User.AskChoice(TmpStr2);
                   User.DisplayStr(QI^.Answers[Tmp]);
                   User.DisplayNewLine;
                   End;
                 End
               End;
             End
           Else If ((Cmd = 'GOTO') And (User.Ok)) Then
             Begin
             If WordCount(TmpStr) > 1 Then
               Begin
               TmpStr2 := ExtractWord(TmpStr, 2);
               If Not FindGo(TmpStr2) Then
                 User.DisplayStrLn(Prompts.GetString(195));
               End;
             End
           Else If ((Cmd = 'GOSUB') And (User.Ok) And
           (QI^.GoSubPtr < MaxGoSub)) Then
             Begin
             If WordCount(TmpStr) > 1 Then
               Begin
               Inc(QI^.GoSubPtr);
               QI^.GoSubStack[QI^.GoSubPtr] := QI^.QF.GetTextPos;
               TmpStr2 := ExtractWord(TmpStr, 2);
               If Not FindGo(TmpStr2) Then
                 User.DisplayStrLn(Prompts.GetString(195));
               End;
             End;
           End;
      'I': Begin
           If Cmd = 'IF' Then
             Begin
             TmpStr2 := Copy(TmpStr, 4, Pos('=', TmpStr) - 4);
             TmpStr2 := StripBoth(TmpStr2, ' ');
             Val(TmpStr2, Tmp, Code);
             If Code = 0 Then
               Begin
               TmpStr2 := Copy(TmpStr, Pos('=', TmpStr) + 1, 255);
               TmpStr2 := StripBoth(TmpStr2, ' ');
               TmpStr2 := Upper(StripBoth(TmpStr2, '"'));
               TmpBool := (Upper(QI^.Answers[Tmp]) <> TmpStr2);
               If QI^.IfStackPtr < MaxIf Then
                 Begin
                 Inc(QI^.IfStackPtr);
                 QI^.SkippingIf := TmpBool;
                 QI^.IfStack[QI^.IfStackPtr] := TmpBool;
                 End;
               End;
             End;
           End;
      'L': Begin
           If Cmd = 'LISTANSWER' Then
             Begin
             If ((WordCount(TmpStr) > 1) and (User.Ok)) Then
               Begin
               Val(ExtractWord(TmpStr,2), Tmp, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= QaMaxAnswers)) Then
                 User.DisplayStrLn(QI^.Answers[Tmp])
               Else
                 User.DisplayStrLn(Prompts.GetString(195));
               End;
             End;
           End;
      'O': Begin
           If Cmd = 'OUTPUTANSWER' Then
             Begin
             TmpStr := Copy(TmpStr, Pos('"',TmpStr) + 1, 255);
             TmpStr2 := Copy(TmpStr, Pos('"',TmpStr) + 1, 255);
             TmpStr := Copy(TmpStr, 1, Pos('"',TmpStr) - 1);
             TmpStr2 := StripBoth(TmpStr2, ' ');
             Val(TmpStr2, Tmp, Code);
             TmpStr2 := '';
             If ((Code = 0) And (Tmp > 0) And (Tmp < QaMaxAnswers)) Then
               Begin
               Tmp2 := 1;
               While (Tmp2 <= Length(TmpStr)) Do
                 Begin
                 If TmpStr[Tmp2] = '|' Then
                   TmpStr2 := TmpStr2 + #13 + #10
                 Else
                   TmpStr2 := TmpStr2 + TmpStr[Tmp2];
                 Inc(Tmp2);
                 End;
               AddStr(TmpStr2 + QI^.Answers[Tmp] + #13 + #10);
               End
             Else
               User.DisplayStrLn(Prompts.GetString(195));
             End;
           End;
      'P': Begin
           If Cmd = 'POSTINFO' Then
             Begin
             AddStr('*** ' + User.GetUserName + ' completed questionaire at '
             + Copy(TimeStr(GetDosDate),1,5) + ' on ' + DateStr(GetDosDate)
             + ' ***' + #13 + #10);
             End
           Else If Cmd = 'POSTMESSAGE' Then
             Begin
             TmpStr2 := Copy(TmpStr, Pos('"', TmpStr) + 1, 255);
             TmpStr2 := Copy(TmpStr2, 1, Pos('"', TmpStr2) - 1);
             If Length(TmpStr2) > 0 Then
               PostMsg(TmpStr2)
             Else
               User.DisplayStrLn(Prompts.GetString(195));
             End
           Else If Cmd = 'PAUSE' Then
             Begin
             If WordCount(TmpStr) > 1 Then
               Begin
               Val(ExtractWord(TmpStr,2), Tmp, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= 120)) Then
                 Delay(Tmp * 1000)
               Else
                 User.DisplayStrLn(Prompts.GetString(195));
               End;
             End;
           End;
      'Q': Begin
           If Cmd = 'QUIT' Then
             QI^.Finished := True;
           End;
      'R': Begin
           If Cmd = 'RETURN' Then
             Begin
             If (QI^.GoSubPtr > 0) Then
               Begin
               If QI^.QF.SeekTextFile(QI^.GoSubStack[QI^.GoSubPtr]) Then;
               Dec(QI^.GoSubPtr);
               End;
             End;
           End;
      'S': Begin
           User.GetUserSec(Sec);
           If Cmd = 'SETSECURITY' Then
             Begin
             Val(ExtractWord(TmpStr,2), Tmp, Code);
             If Code = 0 Then
               Begin
               Sec.Level := Tmp;
               User.SetUserSec(Sec);
               End
             Else
               User.DisplayStrLn(Prompts.GetString(195));
             End
           Else If Cmd = 'SETVAR' Then
             Begin
             If WordCount(TmpStr) >= 3 Then
               Begin
               Val(ExtractWord(TmpStr,2), Tmp, Code);
               If ((Code = 0) And (Tmp > 0) And (Tmp <= QaMaxAnswers)) Then
                 Begin
                 If (Pos('"', TmpStr) > 0) Then
                   Begin
                   Delete(TmpStr, 1, Pos('"', TmpStr));
                   If (Pos('"', TmpStr) > 0) Then
                     Begin
                     TmpStr := Copy(TmpStr, 1, Pos('"', TmpStr) - 1);
                     QI^.Answers[Tmp] := TmpStr;
                     End;
                   End;
                 End
               Else
                 User.DisplayStrLn(Prompts.GetString(195));
               End
             Else
               User.DisplayStrLn(Prompts.GetString(195));
             End
           Else If Cmd = 'SETFLAG' Then
             Begin
             TmpStr2 := ExtractWord(TmpStr,2);
             Case UpCase(TmpStr2[1]) Of
               'A': Tmp := 00;
               'B': Tmp := 08;
               'C': Tmp := 16;
               'D': Tmp := 24;
               Else
                 Tmp := 100;
               End;
             If ((TmpStr2[2] >= '1') and (TmpStr2[2] <= '8')) Then
               Begin
               Tmp := Tmp + (Ord(TmpStr2[2]) - Ord('1'));
               End;
             If ((Tmp >= 0) and (Tmp < 32)) Then
               Begin
               TmpLong := 1;
               TmpLong := TmpLong shl Tmp;
               If Upper(ExtractWord(TmpStr, 3)) = 'ON' Then
                 Sec.Flags := Sec.Flags Or TmpLong
               Else If Upper(ExtractWord(TmpStr, 3)) = 'OFF' Then
                 Sec.Flags := Sec.Flags And (Not TmpLong);
               User.SetUserSec(Sec);
               End
             Else
               User.DisplayStrLn(Prompts.GetString(195));
             End;
           End;
      'W': Begin
           If Cmd = 'WAITENTER' Then
             User.WaitEnter;
           End;
      End;
    End;
  End;


Procedure QuestObj.Process(FN: String);      {Load Q-A file and execute}
  Var
    NumRead: Word;
    FilePath: String;
    TmpStr: String;
    Tmp: Word;
    OutF: File;
    Extn: String[4];

  Begin
  User.PostStatus(uoQuest);
  For Tmp := 1 to QaMaxAnswers Do
    QI^.Answers[Tmp] := '';
  For Tmp := 1 To QaMaxOutput Do
    QI^.PostLines[Tmp] := '';
  QI^.SkippingIf := False;
  QI^.IgnoredIf := 0;
  QI^.IfStackPtr := 0;
  QI^.GoSubPtr := 0;
  QI^.OutLines := 0;
  QI^.Error := 0;
  QI^.QF.Init;
  QI^.Finished := False;
  QI^.Name := Upper(StripBoth(FN,' '));
  FilePath := Config^.FindBbsFile(FN + '.q-a') + FN + '.q-a';
  If Not FileExist(FilePath) Then
    QI^.Error := 1000;
  If QI^.Error = 0 Then
    Begin
    If Not QI^.QF.OpenTextFile(FilePath) Then
      QI^.Error := 1010;
    End;
  While ((QI^.Error = 0) And (Not QI^.Finished)) Do
    Begin
    TmpStr := QI^.QF.GetString;
    If QI^.QF.StringFound Then
      Begin
      TmpStr := StripBoth(TmpStr,' ');
      DoCmd(TmpStr);
      End
    Else
      QI^.Finished := True;
    End;
  If QI^.Error = 0 Then
    If Not QI^.QF.CloseTextFile Then
      QI^.Error := 1020;
  If ((QI^.Error = 0) And (QI^.OutLines > 0)) Then
    Begin
    If ((CurrentPort = 0) Or (CommCarrier)) Then
      Extn := '.asw'
    Else
      Extn := '.adc';
    Assign(OutF, Config^.GetBbsPath + FN + Extn);
    FileMode := fmReadWrite + fmDenyWrite;
    If FileExist(Config^.GetBbsPath + FN + Extn) Then
      Begin
      If Not shReset(OutF, 1) Then
        QI^.Error := MKFileError;
      If QI^.Error = 0 Then
        Begin
        Seek(OutF, FileSize(OutF));
        QI^.Error := IoResult;
        End;
      End
    Else
      Begin
      ReWrite(OutF, 1);
      QI^.Error := IoResult;
      End;
    If (QI^.Error = 0) Then
      Begin
      Tmp := 1;
      While Tmp <= QI^.OutLines Do
        Begin
        If (QI^.Error = 0) Then
          Begin
          If Not shWrite(OutF, QI^.PostLines[Tmp][1], Length(QI^.PostLines[Tmp])) Then
            QI^.Error := MKFileError;
          End;
        Inc(Tmp);
        End;
      End;
    Close(OutF);
    If (IoResult <> 0) Then
      If QI^.Error = 0 Then
        Qi^.Error := 1030;
    End;
  QI^.QF.Done;
  End;


Procedure QuestObj.Done;                      {Done}
  Begin
  Dispose(QI);
  End;


End.
