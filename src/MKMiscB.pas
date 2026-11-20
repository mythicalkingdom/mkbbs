Unit MKMiscB;
{$I MKB.Def}

Interface

Procedure UserSearch;
Procedure ChangeVoicePhone;
Procedure ChangeDataPhone;
Procedure ChangePwd;
Procedure DisplayBulletin(CmdStr: String);
Procedure TimeInfo;
Procedure DoQuest(CmdStr: String);
Procedure DoYourMail;
Procedure UsageStats;
Procedure DoFlags(Str: String);
Procedure ListNodes;
Procedure DisplayVersion;

Implementation


Uses MKFile, MKString, MKName, MKDoor, MKCfgAbs, MKComAbs, MKQuest, MKLogEnt, MKPwd,
  MKMRead, MKCodes, MKDos, MKRCfgMK, MKMisc, MKGlobT, MKCFile, CompDt,
    MKVCrt,
  MKScrn, Dos;


Procedure UsageStats;
  Var
    TL: TimeLogType;
    DA: LongInt;
    TmpStr: String;
    TmpLong: LongInt;
    i: Word;

  Begin
  User.SetStopMore(False);
  User.SetMore(True);
  User.DisplayNewLine;
  User.ResetLines(1);
  TmpStr := Config^.FindBbsFile('timelog.bbs') + 'timelog.bbs';
  If FileExist(TmpStr) Then
    Begin
    If LoadFile(TmpStr, TL, SizeOf(TL)) = 0 Then
      Begin
      DA := DaysAgo(TL.StartDate);
      If DA > 0 Then
        Begin
        User.DisplayAttr(Config^.GetSystemColor(1));
        User.DisplayStrLn(Long2Str(DA) + ' ' + Prompts.GetString(311));
        User.DisplayNewLine;
        i := 0;
        While(User.Ok And Not User.StopMore and (i < 7)) Do
          Begin
          TmpLong := TL.BusyPerDay[i];
          TmpLong := ((TmpLong * 100) Div (60 * 24)) Div DA;
          User.DisplayAttr(Config^.GetSystemColor(1));
          User.DisplayStr(PadLeft(Long2Str(TmpLong),' ', 3) + ' ');
          User.DisplayAttr(Config^.GetSystemColor(2));
          User.DisplayStr(Prompts.GetString(312));
          User.DisplayAttr(Config^.GetSystemColor(3));
          User.DisplayStrLn(' ' + Prompts.GetString(304 + i));
          Inc(i);
          If  User.CheckHot(' ') = ' ' Then
            Begin
            User.SetStopMore(True);
            CommFlushOut;
            End;
          End;
        User.DisplayNewLine;
        i := 0;
        While(User.Ok And Not User.StopMore and (i < 24)) Do
          Begin
          TmpLong := TL.BusyPerHour[i];
          TmpLong := ((TmpLong * 100) Div 60) Div DA;
          User.DisplayAttr(Config^.GetSystemColor(1));
          User.DisplayStr(PadLeft(Long2Str(TmpLong), ' ', 3) + ' ');
          User.DisplayAttr(Config^.GetSystemColor(2));
          User.DisplayStr(Prompts.GetString(312));
          User.DisplayAttr(Config^.GetSystemColor(3));
          User.DisplayStrLn(' ' + PadLeft(Long2Str(i),'0',2) + ':00 - ' +
          PadLeft(Long2Str(i),'0',2) + ':59');
          Inc(i);
          If  User.CheckHot(' ') = ' ' Then
            Begin
            User.SetStopMore(True);
            CommFlushOut;
            End;
          End;
        User.DisplayNewLine;
        End;
      End
    Else
    User.DisplayStrLn(Prompts.GetString(313));
    End
  Else
    User.DisplayStrLn(Prompts.GetString(313));
  User.PressEnter;
  End;


Procedure ChangeVoicePhone;
  Var
    TmpStr: String;

  Begin
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(043) + ' ');
  TmpStr := '';
  TmpStr := User.AskPhone;
  If Length(TmpStr) > 0 Then
    User.SetUserVoicePhone(TmpStr);
  End;


Procedure ChangeDataPhone;
  Var
    TmpStr: String;

  Begin
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(044) + ' ');
  TmpStr := '';
  TmpStr := User.AskPhone;
  If Length(TmpStr) > 0 Then
    User.SetUserDataPhone(TmpStr);
  End;




Procedure ChangePwd;
  Var
    TmpStr: String;
    TmpStr2: String;
    Hashed: Boolean;

  Begin
  If User.GetUserScrnClr Then
    User.ClearScreen;
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(110) + ' ');
  TmpStr := User.InputPwd(PwdMaxHashed);
  User.DisplayNewLine;
  User.DisplayNewLine;
  If User.CheckUserPwd(TmpStr) Then
    Begin
    Hashed := (User.UserPwdMaxLen > PwdMaxPlain);   {a hash keeps the password as typed}
    User.DisplayStr(Prompts.GetString(061) + ' ');
    TmpStr := User.InputPwd(User.UserPwdMaxLen);
    User.DisplayNewLine;
    User.DisplayNewLine;
    User.DisplayStr(Prompts.GetString(037) + ' ');
    TmpStr2 := User.InputPwd(User.UserPwdMaxLen);
    User.DisplayNewLine;
    User.DisplayNewLine;
    If Not Hashed Then
      Begin
      TmpStr := Upper(TmpStr);
      TmpStr2 := Upper(TmpStr2);
      End;
    If (TmpStr = TmpStr2) And (Length(TmpStr) >= Config^.GetMinPwd) And User.ChangeUserPwd(TmpStr) Then
      Begin
      User.DisplayStrLn(Prompts.GetString(191));
      LogEntry.WriteEntry('Password changed');
      End
    Else
      Begin
      User.DisplayStrLn(Prompts.GetString(192));
      End;
    End
  Else
    Begin
    User.DisplayStrLn(Prompts.GetString(039));
    End;
  User.DisplayNewLine;
  User.PressEnter;
  End;


Procedure DisplayBulletin(CmdStr: String);
  Var
    TmpStr: String;
    TmpStr2: String;

  Begin
  TmpStr := ExtractWord(CmdStr, 1);
  If ((Length(TmpStr) > 0) and (Length(TmpStr) < 8)) Then
    Begin
    If BbsDisplay.DisplayBbsFile(TmpStr,' ') <> ' ' Then;
    If (BbsDisplay.GetError <> 0) Then
      User.DisplayStr('Error: ' + CmdStr + ' Not Found')
    Else
      Begin
      User.DisplayNewLine;
      User.DisplayAttr(Config^.GetSystemColor(1));
      User.DisplayStr(Prompts.GetString(22));
      TmpStr2 := User.InputStr('', 8 - Length(TmpStr));
      TmpStr2 := StripBoth(TmpStr2,' ');
      User.DisplayNewLine;
      If Length(TmpStr2) > 0 Then
        Begin
        If BbsDisplay.DisplayBbsFile(TmpStr + TmpStr2,' ') <> ' ' Then;
        If (BbsDisplay.GetError <> 0) Then
          User.DisplayStr('Error: ' + CmdStr + ' Not Found');
        User.PressEnter;
        End;
      End;
    End;
  End;




Procedure TimeInfo;
  Begin
  User.DisplayNewLine;
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(240) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStrLn(FormattedDosDate(GetDosDate, Prompts.GetString(58)));
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(241) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStrLn(Copy(TimeStr(GetDosDate), 1, 5));
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(242) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStrLn(CommaStr(User.GetUserSecondsOn Div 60));
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(243) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStrLn(CommaStr((User.GetUserElapsed + User.GetUserSecondsOn) Div 60));
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(244) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStrLn(CommaStr(User.TimeRemain Div 60));
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(245) + ' ');
  User.DisplayAttr(Config^.GetSystemColor(2));
  User.DisplayStrLn(CommaStr(User.GetUserTimeLimit));
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.PressEnter;
  End;


Procedure DoQuest(CmdStr: String);
  Var
    Quest: QuestObj;

  Begin
  User.DisplayNewLine;
  Quest.Init;
  Quest.Process(StripBoth(CmdStr, ' '));
  If Quest.GetError <> 0 Then
    Begin
    User.DisplayStrLn(Prompts.GetString(158) + ' ' + CmdStr);
    User.DisplayNewLine;
    User.PressEnter;
    End;
  Quest.Done;
  End;


Procedure DoYourMail;
  Var
    Answer: Boolean;

  Begin
  Answer := True;
  User.DisplayNewLine;
  User.AskYN(Prompts.GetString(050), Answer);
  User.DisplayNewLine;
  User.DisplayNewLine;
  If Answer Then
    CheckYourMail;
  End;


Procedure UserSearch;
  Var
    SFin: Boolean;
    SName: String[35];
    NameS: NameObj;

  Begin
  NameS.Init;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStr(Prompts.GetString(139) + ' ');
  SName := User.InputStr('',35);
  User.DisplayNewLine;
  User.ResetLines(1);
  User.SetStopMore(False);
  User.SetMore(True);
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(Prompts.GetString(111));
  SFin := NameS.SearchFirst(SName);
  While(User.Ok And Not User.StopMore and SFin) Do
    Begin
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStr(PadRight(Proper(NameS.GetName), ' ', 36));
    User.DisplayAttr(Config^.GetSystemColor(2));
    User.DisplayStr(PadRight(Proper(NameS.GetLocation), ' ', 26));
    User.DisplayAttr(Config^.GetSystemColor(3));
    User.DisplayStr(PadRight(NameS.GetLastDate, ' ', 10));
    User.DisplayAttr(Config^.GetSystemColor(4));
    User.DisplayStrLn(NameS.GetLastTime);
    If  User.CheckHot(' ') = ' ' Then
      Begin
      User.SetStopMore(True);
      CommFlushOut;
      End;
    SFin := NameS.SearchNext;
    End;
  NameS.Done;
  User.DisplayNewLine;
  User.PressEnter;
  End;


Procedure DoFlags(Str: String);
  Var
    Sec: SecType;
    Curr: String;
    wc: Word;
    numwords: Word;
    Tmp: LongInt;
    TmpLong: LongInt;

  Begin
  User.GetUserSec(Sec);
  NumWords := WordCount(Str);
  wc := 1;
  While wc <= NumWords Do
    Begin
    Curr := Upper(ExtractWord(Str, wc));
    Inc(wc);
    If ((Curr[1] in ['A'..'D']) And (Curr[2] in ['1'..'8']) and
    (Curr[3] in ['+','-','*']))Then
      Begin
      Case Curr[1] of
        'A': Tmp := 00;
        'B': Tmp := 08;
        'C': Tmp := 16;
        'D': Tmp := 24;
        End;
      Tmp := Tmp + (Ord(Curr[2]) - Ord('1'));
      If ((Tmp >= 0) and (Tmp < 32)) Then
        Begin
        TmpLong := 1;
        TmpLong := TmpLong shl Tmp;
        Case Curr[3] of
          '+': Sec.Flags := Sec.Flags or TmpLong;
          '-': Sec.Flags := Sec.Flags and (Not TmpLong);
          '*': Sec.Flags := Sec.Flags xor TmpLong;
          End;
        End;
      End;
    End;
  User.SetUserSec(Sec);
  End;


Procedure ListNodes;
  Var
    UserOn: UserOnType;
    UOFile: File;

  Begin
  User.DisplayNewLine;
  User.ResetLines(1);
  User.SetStopMore(False);
  User.SetMore(True);
  User.DisplayNewLine;
  User.DisplayAttr(Config^.GetSystemColor(1));
  User.DisplayStrLn(Prompts.GetString(329));
  User.DisplaystrLn(Prompts.GetString(330));
  If FileExist(Config^.GetBBSPath + 'useron.bbs') Then
    Begin
    Assign(UOFile, Config^.GetBBSPath + 'useron.bbs');
    Filemode := fmreadonly + fmdenynone;
    Reset(UOFile, Sizeof(UserOnType));
    If IoResult = 0 Then
      Begin
      While Not EOF(UOFile) Do
        Begin
        BlockRead(UOFile, UserOn, 1);
        If IoResult = 0 Then
          Begin
          If UserOn.Status <> 0 Then
            Begin
            User.DisplayAttr(Config^.GetSystemColor(1));
            User.DisplayStr(PadLeft(Long2Str(UserOn.Node),' ',4) + ' ');
            If (UserOn.Status = uoWait) or (UserOn.Status = uoReady) Then
              Begin
              User.DisplayStr(PadRight('', ' ', 21));
              User.DisplayStr(PadRight('', ' ', 21));
              User.DisplayStr(PadRight('', ' ', 06));
              User.DisplayAttr(Config^.GetSystemColor(5));
              Case UserOn.Status of
                uoWait: User.DisplayStrLn(Prompts.GetString(338));
                End;
              End
            Else
              Begin
              User.DisplayAttr(Config^.GetSystemColor(2));
              User.DisplayStr(PadRight(Copy(UserOn.Name,1,20),' ', 21));
              User.DisplayAttr(Config^.GetSystemColor(3));
              User.DisplayStr(PadRight(Copy(UserOn.City,1,20),' ', 21));
              User.DisplayAttr(Config^.GetSystemColor(4));
              User.DisplayStr(PadLeft(Long2Str(UserOn.Baud),' ', 5) + ' ');
              User.DisplayAttr(Config^.GetSystemColor(5));
              Case UserOn.Status of
                uoBrowse: User.DisplayStrLn(Prompts.GetString(331));
                uoXfer: User.DisplayStrLn(Prompts.GetString(332));
                uoMsg: User.DisplayStrLn(Prompts.GetString(333));
                uoDoor: User.DisplayStrLn(Prompts.GetString(334));
                uoChat: User.DisplayStrLn(Prompts.GetString(335));
                uoQuest: User.DisplayStrLn(Prompts.GetString(336));
                uoMail: User.DisplayStrLn(Prompts.GetString(337));
                uoLogIn: User.DisplayStrLn(Prompts.GetString(365));
                End;
              End;
            End;
          End;
        End;
      Close(UOFile);
      If IoResult <> 0 Then;
      End;
    End;
  User.PressEnter;
  End;

Procedure DisplayVersion;
  Begin
  User.ClearScreen;
  If User.GetUserAnsi Then
    Begin
    User.DisplayStrLn('[0;36;40m[2J');
    User.DisplayStrLn('[1;37m…ÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕª');
    User.DisplayStr('∫   Mythical  Kingdom   ∫     ');
    User.DisplayAttr(White);
    User.DisplayStrLn(BBSVersion);
    User.DisplayStrLn('[1;37m∫       Software        ∫');
    User.DisplayStr('∫    [0m‹ ‹         ‹ ‹    [1m∫     ');
    User.DisplayAttr(LightGreen);
    User.DisplayStrLn(CopyRight);
    User.DisplayStrLn('[1;37m∫    [0m€€€  ﬁ[1;34mﬂ [0;37mﬁ[1;31mﬂ  [0;37m€€€    [1m∫');
    User.DisplayStr('∫    [0m€€€€€€€€€€€€€€€    [1m∫     ');
    User.DisplayAttr(LightBlue);
    User.DisplayStrLn(GetCompileDate);
    User.DisplayStrLn('[1;37m∫    [0m€€€€€€[33m∞∞∞[37m€€€€€€    [1m∫');
    User.DisplayStr('∫[0;32m±±±±±±±±±±±±±±±±±±±±±±±[1;37m∫     ');
    User.DisplayAttr(LightCyan);
    User.DisplayStrLn(Contact);
    User.DisplayStrLn('[1;37m»ÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕº');
    End
  Else
    Begin
    User.DisplayStrLn(BbsVersion);
    User.DisplayNewLine;
    User.DisplayStrLn(Copyright);
    User.DisplayNewLine;
    User.DisplayStrLn(GetCompileDate);
    User.DisplayNewLine;
    User.DisplayStrLn(Contact);
    End;
  User.DisplayNewLine;
  User.PressEnter;
  End;

End.
