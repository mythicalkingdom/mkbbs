Unit MKLogOn;
{$I MKB.Def}

Interface

Function  GetLimits(Level: Word): String;
Function  GetTimeFromLimit(LStr: String): Word;
Function  GetKFromLimit(LStr: String; Baud: Word): Word;
Function  AskName: String;
Procedure StartUpUser;
Procedure DoMailer(MailerStr: String);
Procedure LogOffSysInfo;
Procedure DoLanguage;

Implementation


Uses MKFile, MKString, MKCfgAbs, MKDoor, MKGlobT, MKComAbs, MKLogEnt, MKPwd,
  MKMiscB, MKDos, MKMRead, MKCodes, MKRCfgMK, MKExtRun,
    MKVCrt,
  Dos;


Var
  NewUser: Boolean;
  PassStr: String[50];
  PassRaw: String[50];                 {what was typed after the name (name;password): the whole text}
  DoorStr: String[15];


Function TrashName(Name: String; FN: String): Boolean;
  Var
    TF: TFile;
    TmpStr: String;
    Tmp: Word;
    DoneSearch: Boolean;

  Begin
  TrashName := False;
  DoneSearch := False;
  Name := Upper(Name);
  FN := Config^.FindBbsFile(FN) + FN;
  If FileExist(FN) Then
    Begin
    TF.Init;
    If TF.OpenTextFile(FN) Then
      Begin
      TmpStr := Upper(TF.GetString);
      While (TF.StringFound  and (Not DoneSearch)) Do
        Begin
        Tmp := Pos(TmpStr, Name);
        If Tmp > 0 Then
          Begin
          If Tmp + Length(TmpStr) > Length(Name) Then
            Begin
            If ((Tmp = 0) or (Name[Tmp - 1] = ' ')) Then
              Begin
              TrashName := True;
              DoneSearch := True;
              End;
            End
          Else
            Begin
            DoneSearch := (Name[Tmp + Length(TmpStr)] = ' ') and
            ((Tmp = 0) or (Name[Tmp - 1] = ' '));
            TrashName := DoneSearch;
            End;
          End;
        TmpStr := Upper(TF.GetString);
        End;
      If TF.CloseTextFile Then;
      End;
    End;
  End;



Procedure DoSysInfo;
  Var
    SysInfo: SysInfoType;
    SysPath: String;
    SysFile: File;
    NumRead: Word;

  Begin
  SysPath := Config^.FindBbsFile('sysinfo.bbs') + 'sysinfo.bbs';
  Assign(SysFile, SysPath);
  FileMode := fmReadWrite + fmDenyWrite;
  If shReset(SysFile, SizeOf(SysInfo)) Then
    Begin
    If shRead(SysFile, SysInfo, 1, NumRead) Then
      Begin
      If CurrentPort <> 0 Then
        Inc(SysInfo.CallCount);
      User.SetSysInfo(SysInfo);
      Seek(SysFile, 0);
      If shWrite(SysFile, SysInfo, 1) Then;
      End;
    Close(SysFile);
    End
  End;


Procedure LogOffSysInfo;
  Var
    SysInfo: SysInfoType;
    SysPath: String;
    SysFile: File;
    NumRead: Word;
    TL: TimeLogType;
    i: Word;
    TmpLong: LongInt;
    CHour: Word;
    CDay: Word;
    Y, Mo, Dy, Mi, Sc, S100: Word;       {separate variables: GetDate works the
                                          day of week out from the other three}

  Begin
  SysPath := Config^.FindBbsFile('sysinfo.bbs') + 'sysinfo.bbs';
  Assign(SysFile, SysPath);
  FileMode := fmReadWrite + fmDenyWrite;
  If shReset(SysFile, SizeOf(SysInfo)) Then
    Begin
    If shRead(SysFile, SysInfo, 1, NumRead) Then
      Begin
      If CurrentPort <> 0 Then
        SysInfo.LastCaller := User.GetUserName;
      Seek(SysFile, 0);
      If shWrite(SysFile, SysInfo, 1) Then;
      End;
    Close(SysFile);
    End;
  SysPath := Config^.FindBbsFile('timelog.bbs') + 'timelog.bbs';
  If Not FileExist(SysPath) Then
    Begin
    For i := 0 to 6 Do
      TL.BusyPerDay[i] := 0;
    For i := 0 to 23 Do
      TL.BusyPerHour[i] := 0;
    TL.StartDate := DateStr(GetDosDate);
    If SaveFile(SysPath, TL, SizeOf(TL)) = 0 Then;
    End;
  If LoadFile(SysPath, TL, SizeOf(TL)) = 0 Then
    Begin
    TmpLong := User.GetUserSecondsOn Div 60;  {Minutes on}
    GetDate(Y, Mo, Dy, CDay);
    GetTime(CHour, Mi, Sc, S100);
    Inc(TL.BusyPerHour[CHour], TmpLong);
    Inc(TL.BusyPerDay[CDay], TmpLong);
    If SaveFile(SysPath, TL, SizeOf(TL)) = 0 Then;
    End;
  End;


Procedure LogOnUser;
  Var
    Sec: SecType;
    TmpStr: String;
    TodayStr: String;
    LDate: LongInt;
    Left: LongInt;

  Begin
  DoSysInfo;
  User.SetUserTimesCalled(User.GetUserTimesCalled + 1);
  User.GetUserSec(Sec);
  TmpStr := '';
  TmpStr := GetLimits(Sec.Level);
  If User.GetUserLastDate = DateStr(GetDosDate) Then
    Begin
    If GetTimeFromLimit(TmpStr) < User.GetUserElapsed Then
      User.SetSessionTimeLimit(60)
    Else
      User.SetSessionTimeLimit((GetTimeFromLimit(TmpStr) -
        User.GetUserElapsed) * 60);
    End
  Else
    Begin
    User.SetSessionTimeLimit(GetTimeFromLimit(TmpStr) * 60);
    User.SetUserTodayK(0);
    End;
  User.SetUserDLLimit(GetKFromLimit(TmpStr, UserBaud));
  User.SetStartTime;
  If SecsToEvent >= 0 Then
    Begin                              {an exclusive event is coming (mk -T): the call ends before it}
    Left := SecsToEvent;
    If Left < 30 Then
      Left := 30;
    If Left < User.GetSessionTimeLimit Then
      Begin
      User.SetSessionTimeLimit(Left);
      User.DisplayStrLn(PromptOr(534, 'The BBS closes for maintenance in') + ' ' + Long2Str((Left + 59) Div 60) + ' ' +
        PromptOr(535, 'minute(s): this call ends then.'));
      End;
    End;
  If BbsDisplay.DisplayBbsFile('welcome', '') = '' Then;
  If BbsDisplay.DisplayBbsFile('welcome1', '') = '' Then;
  LDate := LongDate(User.GetUserLastDate);
  TmpStr := BBSDisplay.ScreenFileExpand('OnceOnly');
  If DateFile(TmpStr) >= LDate Then
    If BBSDisplay.DisplayBbsFile('onceonly', '') = '' Then;
  TmpStr := BBSDisplay.ScreenFileExpand('OnceOnl2');
  If DateFile(TmpStr) >= LDate Then
    If BBSDisplay.DisplayBbsFile('onceonl2', '') = '' Then;
  User.GetUserSec(Sec);
  If BbsDisplay.DisplayBbsFile('sec' + Long2Str(Sec.Level), '') = '' Then;
  CheckYourMail;
  If BbsDisplay.DisplayBbsFile('news','') = '' Then;
  TmpStr := User.GetUserBirthDate;
  TodayStr := DateStr(GetDosDate);
  If (Copy(TodayStr, 1, 2) = Copy(TmpStr, 1, 2)) And
  (Copy(TodayStr, 4, 2) = Copy(TmpStr, 4, 2)) Then
    Begin
    If BbsDisplay.DisplayBbsFile('birthday', '') = '' Then;
    End;
  End;


Procedure GetNewUserCity;
  Var
    SectionDone: Boolean;
    TmpStr: String;

  Begin
  SectionDone := False;
  TmpStr := '';
  While((User.Ok) and (Not SectionDone)) Do
    Begin
    User.DisplayNewLine;
    User.DisplayStr(Prompts.GetString(041) + ' ');
    TmpStr := User.InputProper(35);
    If Length(TmpStr) > 5 Then
      Begin
      SectionDone := True;
      User.SetUserCity(TmpStr);
      End;
    End
  End;


Procedure GetNewUserBD;
  Var
    SectionDone: Boolean;
    TmpStr: String;
    DT: DateTime;
    TDate: LongInt;

  Begin
  SectionDone := False;
  TmpStr := '';
  While((User.Ok) and (Not SectionDone)) Do
    Begin
    DT.Year := 0;
    DT.Month := 0;
    DT.Day := 0;
    User.DisplayNewLine;
    User.DisplayStr(Prompts.GetString(057) + ' ' + Prompts.GetString(012) +
      Prompts.GetString(058) + Prompts.GetString(013) + ' ');
    SectionDone := User.AskDate(DT);
    User.DisplayNewLine;
    End;
  If DT.Year < 100 Then
    Begin
    If DT.Year < 80 Then
      Inc(DT.Year, 2000)
    Else
      Inc(DT.Year, 1900);
    End;
  PackTime(DT, TDate);
  User.SetUserBirthDate(DateStr(TDate));
  End;


Function ParsePass(NameStr: String): String;
  Var
    TmpStr: String;
    TmpDoor: String;
    i: Word;

  Begin
  TmpStr := NameStr;
  i := Pos('/',NameStr);
  If i > 0 Then
    Begin
    DoorStr := Copy(NameStr, i + 1, 50);
    TmpStr := Copy(NameStr, 1, i - 1);
    End
  Else
    DoorStr := '';
  ParsePass := TmpStr;
  End;


Procedure GetNewUserPassword;
  Var
    TmpStr: String;
    TmpStr2: String;
    SectionDone: Boolean;
    POK: Boolean;
    Hashed: Boolean;

  Begin
  Hashed := False;
  SectionDone := False;
  While ((User.Ok) and (Not SectionDone)) Do
    Begin
    POK := False;
    While ((User.Ok) and (Not POK)) Do
      Begin
      User.DisplayNewLine;
      If BbsDisplay.DisplayBbsFile('password', '') = '' Then;
      User.DisplayNewLine;
      User.DisplayStr(Prompts.GetString(036) + ' ');
      Hashed := (User.UserPwdMaxLen > PwdMaxPlain);   {kept as a hash: as typed, blanks and all}
      TmpStr := User.InputPwd(User.UserPwdMaxLen);
      If Not Hashed Then
        TmpStr := ExtractWord(ParsePass(Upper(TmpStr)), 1);
      User.DisplayNewLine;
      If (Length(TmpStr) >= Config^.GetMinPwd) And (TmpStr <> '*') Then
        POK := True
      Else
        Begin
        User.DisplayStrLn(Prompts.GetString(300));
        User.DisplayNewLine;
        End;
      End;
    User.DisplayStr(Prompts.GetString(037) + ' ');
    TmpStr2 := User.InputPwd(User.UserPwdMaxLen);
    If Not Hashed Then
      TmpStr2 := ExtractWord(ParsePass(Upper(TmpStr2)), 1);
    If (TmpStr = TmpStr2) And User.ChangeUserPwd(TmpStr) Then
      Begin
      SectionDone := True;
      End
    Else
      Begin
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(038));
      End;
    End;
  End;


Procedure GetNewUserScrnLen;
  Var
    Tmp: Word;

  Begin
  User.DisplayNewLine;
  User.DisplayStr(Prompts.GetString(55) +
    User.DefaultNumStr(User.GetUserScrLength));
  Tmp := User.AskNumber(User.GetUserScrLength, 16, 66);
  User.SetUserScrLength(Tmp);
  User.DisplayNewLine;
  End;


Procedure NewUserDataPhone;
  Var
    SectionDone: Boolean;

  Begin
  SectionDone := False;
  While ((Not SectionDone) and (User.OK)) Do
    Begin
    ChangeDataPhone;
    User.DisplayNewLine;
    If Length(User.GetUserDataPhone) >= Config^.GetMinPhone Then
      SectionDone := True
    Else
      Begin
      User.DisplayStrLn(Prompts.GetString(301));
      User.DisplayNewLine;
      End
    End;
  End;


Procedure NewUserVoicePhone;
  Var
    SectionDone: Boolean;

  Begin
  SectionDone := False;
  While ((Not SectionDone) and (User.OK)) Do
    Begin
    ChangeVoicePhone;
    User.DisplayNewLine;
    If Length(User.GetUserVoicePhone) >= Config^.GetMinPhone Then
      SectionDone := True
    Else
      Begin
      User.DisplayStrLn(Prompts.GetString(301));
      User.DisplayNewLine;
      End
    End;
  End;


Procedure GetNewFullScrn;
  Var
    NFull: Boolean;

  Begin
  If Length(Config^.GetEditCmdPath) > 0 Then
    Begin
    User.DisplayNewLine;
    NFull := False;
    User.AskYN(Prompts.GetString(026),NFull);
    User.SetUserFullEd(NFull);
    User.DisplayNewLine;
    End
  Else
    User.SetUserFullEd(False);
  End;


Procedure GetNewUserAnsi;
  Var
    NAnsi: Boolean;

  Begin
  User.DisplayNewLine;
  NAnsi := User.WasAnsiDetected;
  User.AskYN(Prompts.GetString(048), NAnsi);
  User.SetUserAnsi(NAnsi);
  User.DisplayNewLine;
  End;


Procedure GetNewUserAvatar;
  Var
    NAvatar: Boolean;

  Begin
  User.DisplayNewLine;
  NAvatar := False;
  User.AskYN(Prompts.GetString(049),NAvatar);
  User.SetUserAvatar(NAvatar);
  User.DisplayNewLine;
  End;



Procedure GetNewUserMore;
  Var
    NMore: Boolean;

  Begin
  User.DisplayNewLine;
  NMore := True;
  User.AskYN(Prompts.GetString(059),NMore);
  User.SetUserMore(NMore);
  User.DisplayNewLine;
  End;



Procedure GetNewUserScrClr;
  Var
    NClr: Boolean;

  Begin
  User.DisplayNewLine;
  NClr := True;
  User.AskYN(Prompts.GetString(060),NClr);
  User.SetUserScrnClr(NClr);
  User.DisplayNewLine;
  End;




Procedure SetFirstAreas;
  Var
    i: Word;

  Begin
  i := 1;
  While (i < Config^.GetMaxMsgAreas) And (Config^.GetMsgName(i) = '') Do
    Inc(i);
  If Config^.GetMsgName(i) <> '' Then
    User.SetUserMsgTemplate(i);
  i := 1;
  While (i < Config^.GetMaxFileAreas) And (Config^.GetFileAreaName(i) = '') Do
    Inc(i);
  If Config^.GetFileAreaName(i) <> '' Then
    User.SetUserFileTemplate(i);
  End;


Procedure ProcessNewUser;
  Var
    Sec: SecType;
    TmpStr: String;
    AllCorrect: Boolean;
    i: Word;

  Begin
  Config^.GetNewUserSec(Sec);
  User.SetUserSec(Sec);
  User.SetUserLastDate('00-00-00');
  User.SetUserCredit(Config^.GetNewUserNMCredit);
  User.SetUserScrLength(23);
  User.DetectWindow;                   {offer the caller's own window height}
  User.SetUserPageTune(Config^.GetDefaultPage);
  User.SetUserFirstDate(DateStr(GetDosDate));
  For i := 1 to Config^.GetMaxMsgAreas Do
    User.SetUserCombined(i, Config^.GetMsgDefCombined(i) and
    Config^.GetMsgAllowCombined(i));
  AllCorrect := False;
  While ((User.Ok) and (Not AllCorrect)) Do
    Begin
    User.DisplayAttr(Config^.GetSystemColor(1));
    GetNewUserCity;
    User.DisplayAttr(Config^.GetSystemColor(2));
    GetNewUserAnsi;
    User.DisplayAttr(Config^.GetSystemColor(3));
    GetNewUserAvatar;
    User.DisplayAttr(Config^.GetSystemColor(4));
    GetNewUserScrnLen;
    User.DisplayAttr(Config^.GetSystemColor(1));
    GetNewUserMore;
    User.DisplayAttr(Config^.GetSystemColor(2));
    GetNewUserScrClr;
    User.DisplayAttr(Config^.GetSystemColor(3));
    GetNewFullScrn;
    User.DisplayAttr(Config^.GetSystemColor(4));
    If Config^.GetAskVoicePhone Then
      NewUserVoicePhone;
    User.DisplayAttr(Config^.GetSystemColor(1));
    If Config^.GetAskDataPhone Then
      NewUserDataPhone;
    User.DisplayAttr(Config^.GetSystemColor(2));
    If Config^.GetAskBirthDate Then
      GetNewUserBD;
    User.DisplayAttr(Config^.GetSystemColor(3));
    GetNewUserPassword;
    AllCorrect := True;
    User.DisplayNewLine;
    User.AskYN(Prompts.GetString(062), AllCorrect);
    End;
  If BbsDisplay.DisplayBbsFile('newuser1', '') = '' Then;
  If BbsDisplay.DisplayBbsFile('newuser2', '') = '' Then;
  If User.Ok Then
    DoQuest('newuser');
  If User.Ok Then
    Begin
    SetFirstAreas;                       {a new caller starts in the first message and file area, not in area 0 (which nobody may use)}
    User.AddUser;
    LogOnUser;
    End;
  End;


Function TryPassword(Raw, Parsed: String): Boolean;
  {The text as it was typed is tried first (a password of a hashed account may have blanks or a slash), then the first
   word without a "/door" after it, which is what the DOS version took}
  Var
    Hashed, Ok: Boolean;
    Mins: LongInt;

  Begin
  If User.PwdLocked(Mins) Then
    Begin                              {a locked account takes no password, the right one included; the caller is told nothing it could use}
    LogEntry.WriteEntry('Locked account ' + User.GetUserName + ' tried a password (' + Long2Str(Mins) + ' minute(s) left)');
    TryPassword := False;
    Exit;
    End;
  Hashed := User.UserPwdIsHashed;
  Ok := (Length(Raw) > 0) And User.CheckUserPwd(Raw);
  If Ok Then
    DoorStr := ''
  Else
    Ok := User.CheckUserPwd(Parsed);
  If Ok And (Not Hashed) And User.UserPwdIsHashed Then
    LogEntry.WriteEntry('The password of ' + User.GetUserName + ' was converted to a hash');
  If Not Ok Then
    Begin
    User.NoteBadPwd;
    If User.PwdLocked(Mins) Then
      LogEntry.WriteEntry('The account of ' + User.GetUserName + ' is locked for ' + Long2Str(Mins) + ' minute(s): ' + Long2Str(User.PwdFailCount) +
        ' wrong passwords in a row');
    End;
  TryPassword := Ok;
  End;


Function CheckPassword: Boolean;
  Var
    PassTries: Word;
    PassOk: Boolean;
    TempPass: String;

  Begin
  PassTries := 0;
  PassOk := False;
  If Length(PassStr) > 0 Then
    Begin
    PassStr := ExtractWord(PassStr, 1);
    Inc(PassTries);
    PassOk := TryPassword(PassRaw, PassStr);
    If Not PassOk Then
      Begin
      User.DisplayNewLine;
      User.DisplayStrLn(Prompts.GetString(39));
      End;
    End;
  While ((Not PassOk) and (PassTries < Config^.GetPwdTries) and (User.Ok)) Do
    Begin
    User.DisplayNewLine;
    User.DisplayStr(Prompts.GetString(21) + ' ');
    TempPass := User.InputPwd(50);
    PassRaw := Copy(TempPass, 1, 50);
    PassStr := ExtractWord(ParsePass(TempPass), 1);
    If TryPassword(PassRaw, PassStr) Then
      PassOk := True
    Else
      Begin
      User.DisplayStrLn(Prompts.GetString(39));
      LogEntry.WriteEntry('Incorrect Password');    {what was typed is not written down}
      End;
    Inc(PassTries);
    User.CheckInput;
    End;
  CheckPassword := PassOk;
  End;


Procedure MailExit(ME: Integer);
  Begin
  WriteLn;
  WriteLn('Mailer exit at ', ME);
  Halt(ME);
  End;


Procedure DoMailer(MailerStr: String);
  Var
    MailLevel: Integer;
    LevelFound: Boolean;
    CurrNo: Word;
    TmpStr: String;
    HaveStar: Boolean;
    DoSwap: Boolean;

  Begin
  DoSwap := False;
  HaveStar := False;
  TmpStr := '';
  CurrNo := 1;
  While CurrNo <= Length(MailerStr) Do
    Begin
    If HaveStar Then
      Begin
      Case UpCase(MailerStr[CurrNo]) of
        '*': Begin
             TmpStr[0] := Succ(TmpStr[0]);
             TmpStr[Length(TmpStr)] := '*';
             End;
        'M': Begin
             HaveStar := False;
             DoSwap := True;
             End;
        Else
          Begin
          HaveStar := False;
          TmpStr[0] := Succ(TmpStr[0]);
          TmpStr[Length(TmpStr)] := '*';
          TmpStr[0] := Succ(TmpStr[0]);
          TmpStr[Length(TmpStr)] := MailerStr[CurrNo];
          End;
        End;
      End
    Else
      Begin
      Case UpCase(MailerStr[CurrNo]) of
        '*': HaveStar := True;
        Else
          Begin
          TmpStr[0] := Succ(TmpStr[0]);
          TmpStr[Length(TmpStr)] := MailerStr[CurrNo];
          End;
        End;
      End;
    Inc(CurrNo);
    End;
  If DoSwap Then
    WriteLn('MK Swapping to: ', TmpStr)
  Else
    WriteLn('MK Shelling to: ', TmpStr);
  DoShell(TmpStr, DoSwap, False);
  MailLevel := GetResultCode;
  LevelFound := False;
  CurrNo := 1;
  If MailLevel < 6 Then
    Inc(MailLevel, 10);
  While ((Not LevelFound) and (CurrNo < 12)) Do
    Begin
    If Config^.GetErrorLevel(CurrNo) = MailLevel Then
      LevelFound := True;
    If Not LevelFound Then
      Inc(CurrNo);
    End;
  If LevelFound Then
    Begin
    Case CurrNo of
      01: Begin
          LocalMode := True;
          UserBaud := 0;
          CurrentPort := 0;
          End;
      02: UserBaud := 300;
      03: UserBaud := 1200;
      04: UserBaud := 2400;
      05: UserBaud := 4800;
      06: UserBaud := 7200;
      07: UserBaud := 9600;
      08: UserBaud := 12000;
      09: UserBaud := 14400;
      10: UserBaud := 19200;
      11: UserBaud := 38400;
      End;
    User.SetUserBaud(UserBaud);
    End
  Else
    Begin
    MailExit(MailLevel);
    End;
  End;



Procedure StartUpUser;
  Begin
  User.SetUserAvatar(False);
  User.SetSessionTimeLimit(600);
  User.SetStartTime;
  User.SetIdleTimeLimit(240);
  User.SetMore(True);
  User.SetStopMore(False);
  User.SetUserScrLength(23);
  User.DetectWindow;
  User.ResetLines(1);
  User.SetUserMore(False);
  User.SetUserPageTimes(0);
  User.ClearGoSub;
  End;


Procedure PasswordNotices;
  {after a good password: the wrong ones there were since the last good log-on, a password that has expired (a new one is asked for now), one that is about to}
  Var
    Fails: Byte;
    Days: LongInt;
    Tries: Word;
    Done, Hashed: Boolean;
    P1, P2: String;

  Begin
  Fails := User.NoteGoodPwd;
  If Fails > 0 Then
    Begin
    User.DisplayNewLine;
    User.DisplayStrLn(PromptOr(537, 'Wrong passwords typed for your account since your last log-on:') + ' ' + Long2Str(Fails));
    LogEntry.WriteEntry(Long2Str(Fails) + ' wrong password(s) for ' + User.GetUserName + ' since the last good log-on');
    End;
  Days := User.PwdDaysLeft;
  If Days < 0 Then
    Exit;
  If Days = 0 Then
    Begin
    User.DisplayNewLine;
    User.DisplayStrLn(PromptOr(538, 'Your password has expired. You must choose a new one now.'));
    LogEntry.WriteEntry('The password of ' + User.GetUserName + ' has expired: a new one is asked for');
    Done := False;
    Tries := 0;
    While (Not Done) And (Tries < 3) And User.Ok Do
      Begin
      Inc(Tries);
      Hashed := (User.UserPwdMaxLen > PwdMaxPlain);
      User.DisplayNewLine;
      User.DisplayStr(Prompts.GetString(061) + ' ');
      P1 := User.InputPwd(User.UserPwdMaxLen);
      User.DisplayNewLine;
      User.DisplayStr(Prompts.GetString(037) + ' ');
      P2 := User.InputPwd(User.UserPwdMaxLen);
      User.DisplayNewLine;
      If Not Hashed Then
        Begin
        P1 := Upper(P1);
        P2 := Upper(P2);
        End;
      If P1 <> P2 Then
        User.DisplayStrLn(Prompts.GetString(192))
      Else If (Length(P1) < Config^.GetMinPwd) Or (P1 = '*') Then
        User.DisplayStrLn(Prompts.GetString(300))
      Else If User.CheckUserPwd(P1) Then
        User.DisplayStrLn(PromptOr(539, 'The new password must be different from the old one.'))
      Else If User.ChangeUserPwd(P1) Then
        Begin
        Done := True;
        User.DisplayStrLn(Prompts.GetString(191));
        LogEntry.WriteEntry('Password changed (it had expired)');
        End
      Else
        User.DisplayStrLn(Prompts.GetString(192));
      End;
    If Not Done Then
      Begin
      LogEntry.WriteEntry('The expired password of ' + User.GetUserName + ' was not changed: the call ends');
      User.DisplayStrLn(PromptOr(542, 'The password was not changed: this call ends.'));
      User.SetOk(False);
      End;
    End
  Else If (Config^.GetPwdWarn > 0) And (Days <= Config^.GetPwdWarn) Then
    Begin
    User.DisplayNewLine;
    User.DisplayStrLn(PromptOr(540, 'Your password expires in') + ' ' + Long2Str(Days) + ' ' + PromptOr(541, 'day(s).'));
    End;
  End;


Procedure BadPassword;
  Begin
  If CommCarrier Then
    ExitErrorLevel := LoginFailLevel;    {mklisten counts these per address; a caller who is gone (a port scan, a changed mind) is not a failed log-on}
  LogEntry.WriteEntry('Password Failure');
  LogEntry.WriteEntry('User off-line');
  User.SetOk(False);
    If CurrentPort <> 0 Then
    Begin
    LowerDtr;
    Delay(500);
    RaiseDtr;
    End;
  End;


Function ParseName(NameStr: String): String;
  Var
    TmpStr: String;
    TmpPass: String;
    i: Word;

  Begin
  TmpStr := NameStr;
  i := Pos(';',NameStr);
  If i > 0 Then
    Begin
    TmpPass := Copy(NameStr, i + 1, 50);
    TmpStr := Copy(NameStr, 1, i - 1);
    End
  Else
    TmpPass := '';
  PassRaw := Copy(TmpPass, 1, 50);
  PassStr := ParsePass(TmpPass);
  i := Pos('/', TmpStr);
  If i > 0 Then
    TmpStr := Copy(TmpStr, 1, i - 1);
  ParseName := TmpStr;
  End;


Function AskName: String;
  Const
    MaxTries = 10;

  Var
    NameTries: Word;
    TempStr: String;
    TempName: String;
    Finished: Boolean;
    NameOk: Boolean;
    i: Word;
    NameState: Word;
    TempExtr: String;

  Begin
  PassStr := '';
  PassRaw := '';
  DoorStr := '';
  TempName := '';
  NameTries := 0;
  Finished := False;
  While User.Ok and Not Finished Do
    Begin
    NameOk := True;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStr(Prompts.GetString(32) + ' ');
    TempStr := User.InputProper(60);
    TempStr := ParseName(TempStr);
    NameState := 0;
    TempName := '';
    i := 1;
    While i <= WordCount(TempStr) Do
      Begin
      TempExtr := ExtractWord(TempStr,i);
      If Length(TempExtr) > 0 Then
        Begin
        If Length(TempName) = 0 Then
          TempName := TempExtr
        Else
          TempName := TempName + ' ' + TempExtr;
        End;
      Inc(i);
      End;
    User.DisplayNewLine;
    Inc(NameTries);
    If Config^.GetOneWordName Then
      Begin
      If WordCount(TempName) < 1 Then
        NameOk := False;
      End
    Else
      Begin
      If WordCount(TempName) < 2 Then
        NameOk := False;
      End;
    If NameOk Then
      Begin
      If Config^.GetSevenBitNames Then
        Begin
        For i := 1 to Length(TempName) Do
          If TempName[i] > #127 Then
            NameOk := False;
        End;
      End;
    If NameOk Then
      Begin
      If TrashName(TempName, 'trashcan.ctl') Then
        Begin
        User.DisplayNewLine;
        User.DisplayAttr(Config^.GetSystemColor(1));
        User.DisplayStrLn(Prompts.GetString(302));
        NameOk := False;
        Finished := True;
        NameTries := MaxTries + 1;
        AskName := '';
        NewUser := False;
        LogEntry.WriteEntry('trashcan.ctl name used of ' + TempName);
        LogEntry.WriteEntry('Access Denied');
        End;
      End;
    If NameOk Then
      Begin
      LogEntry.BlankLine;
      LogEntry.WriteEntry(TempName + ' on-line at ' +
        Long2Str(UserBaud) + ' BPS');
      User.DisplayStrLn(Prompts.GetString(264));
      User.GetUserPos(TempName);
      If Not User.UserFound Then
        Begin
        User.DisplayNewLine;
        LogEntry.WriteEntry(TempName + ' Name not in user file');
        User.DisplayStrLn(Prompts.GetString(34) + ' "' + TempName + '"');
        NameOk := False;
        User.AskYN(Prompts.GetString(35), NameOk);
        User.DisplayNewLine;
        NewUser := True;
        End
      Else
        Begin
        NewUser := False;
        User.ReadUser;
        End;
      End;
    Finished := NameOk;
    If NameTries > MaxTries Then
      Begin
      Finished := True;
      AskName := '';
      End;
    User.CheckInput;
    End;
  If NameOk Then
    Begin
    If NewUser Then
      Begin
      User.SetUserName(TempName);
      User.PostStatus(uoLogIn);
      ProcessNewUser;
      If User.Ok Then
        RunHooks('newuser', Long2Str(User.GetUserSecLevel), Long2Str(NodeNumber), '', '');
      End
    Else
      Begin
      User.PostStatus(uoLogIn);
      If Not CheckPassword Then
        BadPassword
      Else
        Begin
        PasswordNotices;
        If User.Ok Then
          LogOnUser;
        End;
      End;
    End
  Else
    Begin
    If User.Ok And CommCarrier Then
      ExitErrorLevel := LoginFailLevel;    {no name was accepted (too many tries), the caller did not just hang up (a caller who is gone is no failed log-on: a port scan, a changed mind)}
    User.SetOk(False);
      If CurrentPort <> 0 Then
      Begin
      LowerDtr;
      Delay(500);
      RaiseDtr;
      End;
    End;
  End;


Function GetKFromLimit(LStr: String; Baud: Word): Word;
  Var
    WordNo: Word;

  Begin
  If (WordCount(LStr) > 2) Then
    Begin
    Case Baud of
      0: WordNo := 7;
      1..1199: WordNo := 3;
      1200..2399: WordNo := 4;
      2400..4799: WordNo := 5;
      4800..9599: WordNo := 6;
      Else
        WordNo := 7;
      End;
    If WordNo > WordCount(LStr) Then
      WordNo := WordCount(LStr);
    GetKFromLimit := Str2Long(ExtractWord(LStr, WordNo));
    End
  Else
    GetKFromLimit := 0;
  End;


Function GetTimeFromLimit(LStr: String): Word;
  Begin
  If (WordCount(LStr) > 1) Then
    GetTimeFromLimit := Str2Long(ExtractWord(LStr,2))
  Else
    GetTimeFromLimit := 0;
  End;


Function GetLimits(Level: Word): String;
  Var
    LFile: TFile;
    TStr: String;
    BestMatch: Word;
    i: Word;

  Begin
  BestMatch := 0;
  LFile.Init;
  GetLimits := '';
  If LFile.OpenTextFile(Config^.FindBbsFile('limits.ctl') + 'limits.ctl') Then
    Begin
    TStr := LFile.GetString;
    While LFile.StringFound Do
      Begin
      TStr := StripBoth(TStr, ' ');
      If ((TStr[1] <> ';') and (WordCount(TStr) > 1)) Then
        Begin
        i := Str2Long(ExtractWord(TStr,1));
        If ((i <= Level) and (i > BestMatch)) Then
          GetLimits := TStr;
        End;
      TStr := LFile.GetString;
      End;
    If LFile.CloseTextFile Then;
    End
  Else
    GetLimits := '';
  LFile.Done;
  End;


Procedure DoLanguage;
  Var
    i: Word;
    HotStr: String;
    LangChr: Char;

  Begin
  HotStr := '';
  For i := 1 to 10 Do
    Begin
    If Config^.GetLangName(i) <> '' Then
      Begin
      HotStr := HotStr + Chr(i + Ord('A') - 1);
      End;
    End;
  If Length(HotStr) > 1 Then
    Begin
    User.DisplayNewLine;
    User.DisplayStrLn(Prompts.GetString(340));
    User.DisplayNewLine;
    For i := 1 to 10 Do
      Begin
      User.DisplayAttr(Config^.GetSystemColor(1));
      If Config^.GetLangName(i) <> '' Then
        Begin
        User.DisplayStr(Prompts.GetString(12) + Chr(i + Ord('A') - 1) +
          Prompts.GetString(13) + ' ');
        User.DisplayStrLn(Config^.GetLangName(i));
        End;
      End;
    User.DisplayNewLine;
    User.DisplayStr(Prompts.GetString(339) + ' ');
    HotStr := HotStr + #13;
    LangChr := UpCase(User.AskChoice(HotStr));
    User.DisplayStrLn(LangChr);
    User.DisplayNewLine;
    If LangChr = #13 Then
      Begin
      Prompts.Load(Config^.FindBbsFile(Config^.GetLangFile(1) + '.lc') +
        Config^.GetLangFile(1) + '.lc');
      User.SetUserLanguage(1);
      End
    Else
      Begin
      i := Ord(LangChr) - Ord('A') + 1;
      If ((i > 0) and (i < 11)) Then
        Begin
        Prompts.Load(Config^.FindBbsFile(Config^.GetLangFile(i) + '.lc') +
          Config^.GetLangFile(i) + '.lc');
        User.SetUserLanguage(i);
        End;
      End;
    CommaChar := Prompts.GetChar(320);
    End;
  End;

End.
