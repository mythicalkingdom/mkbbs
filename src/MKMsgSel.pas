Unit MKMsgSel;

{$I MKB.Def}

Interface

Uses
    MKVCrt,
  MKString, MKDoor, MKCfgAbs, MKGlobT, MKFile, MKComAbs;


Type ConfInfo = Record
  ConfsAvail: Word;
  AreaAvail: Array[1..500] of Boolean;
  Chosen: Array[1..500] of Boolean;
  ConfsList: Array[1..500] Of Word;
  SingleChoice: Word;
  MaxConfPage: Word;
  ConfScreen: Word;
  ConfChoice: String[10];
  ConfsDone: Boolean;
  CurrConfPage: Word;
  CC: Char;
  FirstConf: Word;
  Multiple: Boolean;
  DoLast: Boolean;
  MaxArea: Word;
  DoFiles: Boolean;
  End;



Type ConfSelectObj = Object
  CI: ^ConfInfo;
  Procedure Init;                           {Initialize}
  Procedure Done;                           {Done}
  Procedure SelectConfs(Multiple: Boolean; AskLast: Boolean; DoFiles: Boolean);
    {Gets selection for multiple or single choice and optionally
     asks to update last read pointers}
  Procedure SetAvailable(Area: Word; Setting: Boolean);
    {Marks area as available or not}
  Procedure SetChosen(Area: Word; Setting: Boolean);
    {Marks area as chosen or not}
  Function  IsChosen(Area: Word): Boolean;  {Tells whether area was chosen}
  Function  GetSelectedArea: Word;          {Finds first selected area}
  Function  ConfStr(DConf: Word): String;   {Internal use}
  Procedure DisplayPage(PageNo: Word);      {Internal use display a page}
  Procedure TempDisp(TStr: String);         {Display string and then erase}
  Procedure GoToConf(GConf: Word);          {Internal use position cursor}
{  Procedure ResetPtr(RConf: Word); }         {Internal use ask and reset
    last read pointer}
  Procedure HandleConf;                     {Internal Use}
  End;


Implementation

Const
  NumColumns = 3;
  CSpace = 3;
  CWidth = 23;
  ResLines = 5;
  DelayTime = 700;


Procedure ConfSelectObj.Init;
  Var
    i: Word;

  Begin
  New(CI);
  For i := 1 to 500 Do
    Begin
    CI^.AreaAvail[i] := False;
    CI^.Chosen[i] := False;
    End;
  CI^.SingleChoice := 0;
  End;


Procedure ConfSelectObj.Done;
  Begin
  Dispose(CI);
  End;


Procedure ConfSelectObj.SetAvailable(Area: Word; Setting: Boolean);
  Begin
  CI^.AreaAvail[Area] := Setting;
  End;


Procedure ConfSelectObj.SetChosen(Area: Word; Setting: Boolean);
  Begin
  CI^.Chosen[Area] := Setting;
  End;



Function ConfSelectObj.IsChosen(Area: Word): Boolean;
  Begin
  IsChosen := CI^.Chosen[Area];
  End;


Function ConfSelectObj.ConfStr(DConf: Word): String;
  Var
    ConfName: String[12];
    TempStr: String[50];
    AConf: Word;

  Begin
  If DConf > CI^.ConfsAvail Then
    ConfStr := ''
  Else
    Begin
    AConf := CI^.ConfsList[DConf];
    If CI^.DoFiles Then
      ConfName := PadRight(Config^.GetFileShortName(AConf), ' ', 12)
    Else
      ConfName := PadRight(Config^.GetMsgShortName(AConf), ' ', 12);
    TempStr := PadLeft(Long2Str(AConf), ' ',3);
    If IsChosen(Aconf) Then
      TempStr := ' * ' + TempStr + ' ' + ConfName
    Else
      TempStr := '   ' + TempStr + ' ' + ConfName;
    ConfStr := PadRight(TempStr, ' ', CWidth);
    End;
  End;


Procedure ConfSelectObj.DisplayPage(PageNo: Word);
  Var
    i: Word;
    TempStr: String;
    Horz: Word;

  Begin
  User.ClearScreen;
  User.ResetLines(1);
  User.SetStopMore(False);
  CI^.FirstConf := ((PageNo - 1) * (CI^.ConfScreen - ResLines) * NumColumns) + 1;
  For i := 1 to (CI^.ConfScreen - ResLines) Do
    Begin
    If ((User.CheckHot(' ') = ' ') and (Not CI^.Multiple)) Then
      Begin
      User.SetStopMore(True);
      CommFlushOut;
      End;
    If Not User.StopMore Then
      Begin
      For Horz := 0 to (NumColumns - 1) Do
        Begin
        TempStr := ConfStr(CI^.FirstConf + ((i - 1) * NumColumns)+ Horz);
        If Length(TempStr) > 0 Then
          Begin
          User.DisplayAttr(Config^.GetSystemColor(1));
          User.DisplayStr(Copy(TempStr,1,3));
          User.DisplayAttr(Config^.GetSystemColor(2));
          User.DisplayStr(Copy(TempStr,4,4));
          User.DisplayAttr(Config^.GetSystemColor(3));
          User.DisplayStr(Copy(TempStr,8,(23-7)));
          If Horz <> (NumColumns - 1) Then
             User.DisplayStr(PadRight('', ' ', CSpace));
          End;
        End;
      User.DisplayNewLine;
      End;
    End;
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(246) + ' ');
  End;


Procedure ConfSelectObj.TempDisp(TStr: String);
  Begin
  User.DisplayStr(TStr);
  Delay(DelayTime);
  User.DisplayChr(#13);
  If User.GetUserAnsi Then
    User.ClrEol
  Else
    Begin
    User.DisplayStr(PadRight('', ' ', Length(TStr)));
    End;
  End;


Procedure ConfSelectObj.GoToConf(GConf: Word);
  Var
    i: Word;
    Coff: Word;
    CX, CY: Word;


  Begin
  i := 1;
  While ((i <= CI^.ConfsAvail) and (CI^.ConfsList[i] <> GConf)) Do
    Inc(i);
  If CI^.ConfsList[i] = GConf Then
    Begin
    If ((i >= CI^.FirstConf) and
    (i < ((CI^.CurrConfPage * (CI^.ConfScreen - ResLines) * NumColumns) + 1))) Then
      Begin;
      Coff := i - CI^.FirstConf;
      CX := (Coff Mod NumColumns);
      CX := (CX * (CSpace + CWidth)) + 2;
      CY := (Coff Div NumColumns) + 1;
      User.DisplayStr('[' + Long2Str(CY) + ';' + Long2Str(CX) + 'f'); {gotoyx}
      If CI^.Chosen[GConf] Then
        User.DisplayChr('*')
      Else
        User.DisplayChr(' ');
      End;
    End;
  End;


{
Procedure ConfSelectObj.ResetPtr(RConf: Word);
  Var
    ResetDone: Boolean;
    RC: Char;
    ResetChoice: String[10];
    ResetPrompt: String;
    RWord: Word;
    Code: Word;

  Begin
  ResetChoice := '';
  ResetDone := False;
  ResetPrompt := Prompts.GetString(199) +
    User.DefaultNumStr(User.GetUserLastRead(RConf));
  User.DisplayChr(#13);
  User.DisplayStr(ResetPrompt);
  While (User.Ok and (Not ResetDone)) Do
    Begin
    While (User.Ok and Not(User.InputChr(RC))) Do
      User.CheckInput;
    If User.Ok Then
      RC := UpCase(RC)
    Else
      RC := #0;
    Case RC of
      #08: Begin
           If Length(ResetChoice) > 0 Then
             Begin
             ResetChoice[0] := Chr(Length(ResetChoice) - 1);
             User.DisplayChr(#8);
             User.DisplayChr(' ');
             User.DisplayChr(#8);
             End;
           End;
      #13: Begin
           ResetDone := True;;
           End;
      '0'..'9': Begin
           If Length(ResetChoice) < 5 Then
             Begin
             ResetChoice := ResetChoice + RC;
             User.DisplayChr(RC);
             End;
           End;
      End;
    End;
  User.DisplayChr(#13);
  If User.GetUserAnsi Then
    User.ClrEol
  Else
    User.DisplayStr(PadRight('', ' ', Length(ResetPrompt) + 5));
  If (Length(ResetChoice) > 0) Then
    Begin
    Val(ResetChoice, RWord, Code);
    If ((Code = 0) and (RWord < $7fff))Then
      User.SetUserLastRead(RConf,RWord)
    Else
      Begin
      TempDisp(Prompts.GetString(248));
      End;
    End;
  End;
}


Procedure ConfSelectObj.HandleConf;
  Var
    CWord: Word;
    Code: Integer;
    DStr: String;
    TmpChr: Char;
    ChoiceStr: String[5];
    ResultStr: String[50];

  Begin
  If (Not CI^.Multiple) Then
    CI^.ConfsDone := True;
  ChoiceStr := Prompts.GetChar(001) + Prompts.GetChar(002) + #13;
  User.DisplayChr(#13);
  User.DisplayStr(PadRight('',' ',Length(Prompts.GetString(246)) + 6));
  User.DisplayChr(#13);
  Val(CI^.ConfChoice, CWord, Code);
  If ((Code = 0) and (CWord <= 500) and (CWord > 0) and
  CI^.AreaAvail[CWord]) Then
    Begin
    If CI^.Multiple Then
      Begin
      SetChosen(CWord, Not IsChosen(CWord));
      DStr := Prompts.GetString(249) + ' ' + Long2Str(CWord) + ' ' +
        Prompts.GetString(012) + Prompts.GetString(003) + ' ' +
        Prompts.GetString(004) + ' ' + Prompts.GetString(005) + ' ';
      If IsChosen(CWord) Then
        DStr := DStr + Prompts.GetString(003)
      Else
        DStr := DStr + Prompts.GetString(004);
      DStr := DStr + Prompts.GetString(013) + ' ' + Prompts.GetString(014) + ' ';
      User.DisplayStr(DStr);
      TmpChr := User.AskChoice(ChoiceStr);
      If (TmpChr <> #0) Then
        Case Pos(TmpChr, ChoiceStr) Of
          1: SetChosen(CWord, True);
          2: SetChosen(CWord, False);
          End;
      If IsChosen(CWord) Then
        ResultStr := Prompts.GetString(003)
      Else
        ResultStr := Prompts.GetString(004);
      User.DisplayStr(ResultStr);
      If ((User.GetUserAnsi) And (CI^.Multiple)) Then
        Begin
        User.DisplayStr('[s'); {save cursor position}
        GoToConf(CWord);
        User.DisplayStr('[u'); {restore cursor position}
        End;
      Delay(DelayTime);
      User.DisplayChr(#13);
      If User.GetUserAnsi THen
        User.ClrEol
      Else
        Begin
        User.DisplayStr(PadRight('', ' ', Length(Dstr) + 1 + Length(ResultStr)));
        User.DisplayChr(#13);
        End;
      End
    Else
      Begin
      CI^.SingleChoice := CWord;
      End;
    If ((IsChosen(CWord)) And (CI^.DoLast)) Then
      {ResetPtr(CWord)};
    End
  Else
    Begin
    If Code <> 0 Then
      TempDisp(Prompts.GetString(015))
    Else
      If Cword < 1 Then
        Begin
        TempDisp(Prompts.GetString(016) + ' 1');
        End
      Else
        If Cword > CI^.MaxArea Then
          Begin
          TempDisp(Prompts.GetString(017) + ' ' + Long2Str(CI^.MaxArea));
          End
        Else
          If Not CI^.AreaAvail[Cword] Then
            Begin
            TempDisp(Prompts.GetString(255));
            End;
    End;
  User.DisplayChr(#13);
  If CI^.Multiple Then
    User.DisplayStr(Prompts.GetString(246) + ' ');
  End;


Procedure ConfSelectObj.SelectConfs(Multiple: Boolean; AskLast: Boolean;
  DoFiles: Boolean);

  Var
    i: Word;
    ConfsPerPage: Word;
    AnswStr: String[20];

  Begin
  CI^.DoFiles := DoFiles;
  If CI^.DoFiles Then
    CI^.MaxArea := Config^.GetMaxFileAreas
  Else
    CI^.MaxArea := Config^.GetMaxMsgAreas;
  AnswStr := PadRight(Copy(Upper(Prompts.GetString(247)),1, 4), #0, 4);
  AnswStr := AnswStr + #8 + #13 + '0123456789';
  CI^.DoLast := AskLast;
  CI^.Multiple := Multiple;
  CI^.ConfsDone := False;
  CI^.CurrConfPage := 1;
  If ((User.GetUserScrLength < 10)
  or (User.GetUserScrLength > 23)) Then
    CI^.ConfScreen := 23
  Else
    CI^.ConfScreen := User.GetUserScrLength;
  CI^.ConfsAvail := 0;
  For i := 1 to 500 Do
    Begin
    If CI^.AreaAvail[i] Then
      Begin
      Inc(CI^.ConfsAvail);
      CI^.ConfsList[CI^.ConfsAvail] := i;
      End;
    End;
  ConfsPerPage := (NumColumns) * (CI^.ConfScreen - ResLines);
  CI^.MaxConfPage := (CI^.ConfsAvail + ConfsPerPage - 1) Div ConfsPerPage;
  DisplayPage(CI^.CurrConfPage);
  CI^.ConfChoice := '';
  While (User.Ok and (Not CI^.ConfsDone)) Do
    Begin
    While (User.Ok and Not(User.InputChr(CI^.CC))) Do
      User.CheckInput;
    If User.Ok Then
      CI^.CC := UpCase(CI^.CC)
    Else
      CI^.CC := #0;
    Case Pos(CI^.CC, AnswStr) of
      1: Begin                              {Next}
         If Length(CI^.ConfChoice) = 0 Then
           Begin
           Inc(CI^.CurrConfPage);
           If CI^.CurrConfPage > CI^.MaxConfPage Then
             CI^.ConfsDone := True
           Else
             DisplayPage(CI^.CurrConfPage);
           End;
         End;
      2: Begin                              {Back}
         If Length(CI^.ConfChoice) = 0 Then
           Begin
           Dec(CI^.CurrConfPage);
           If CI^.CurrConfPage < 1 Then
             CI^.ConfsDone := True
           Else
             DisplayPage(CI^.CurrConfPage);
           End;
         End;
      3: Begin                              {Again}
         If Length(CI^.ConfChoice) = 0 Then
           DisplayPage(CI^.CurrConfPage);
           End;
      4: Begin                              {Quit}
         If Length(CI^.ConfChoice) = 0 Then
           CI^.ConfsDone := True;
         End;
      5: Begin                              {Backspace}
         If Length(CI^.ConfChoice) > 0 Then
           Begin
           CI^.ConfChoice[0] := Chr(Length(CI^.ConfChoice) - 1);
           User.DisplayBkSpc;
           End;
         End;
      6: Begin                              {Enter}
         If Length(CI^.ConfChoice) = 0 Then
           Begin
           Inc(CI^.CurrConfPage);
{          If CI^.CurrConfPage > MaxConfPage Then
             CI^.ConfsDone := True
           Else
             DisplayPage(CI^.CurrConfPage); }  {Uncomment this for enter}
           End                                 {to be next page}
         Else
           HandleConf;
         CI^.ConfChoice := '';
         End;
      7..16: Begin                          {0 thru 9}
         If Length(CI^.ConfChoice) < 3 Then
           Begin
           CI^.ConfChoice := CI^.ConfChoice + CI^.CC;
           User.DisplayChr(CI^.CC);
           End;
         End;
      End;
    End;
  End;


Function ConfSelectObj.GetSelectedArea: Word;
  Var
    i: Word;

  Begin
  GetSelectedArea := CI^.SingleChoice;
  End;


End.

