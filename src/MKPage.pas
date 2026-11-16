Unit MKPage;
{$I MKB.Def}

Interface

Procedure DoPage;
Procedure PagePlay(PageTune: String);


Implementation


Uses MKFile, MKString, MKMusic, MKDoor, MKSnoop, MKCfgAbs, MKEnter, MKGlobT,
  Dos;


Var
  PageChar: Char;

Procedure PageKey(Var Stop: Boolean);
  {The sysop answers the page from mkmon: Ctrl-A C (or the C key in chat mode)
   chats, A sends the caller on to the message prompt}
  Var
    Ch: Char;

  Begin
  If SysopChatWanted Then
    Begin
    SysopChatWanted := False;
    PageChar := 'C';
    Stop := True;
    End
  Else
    Begin
    Ch := UpCase(SysopReadKey);
    Case Ch Of
      'A': Begin
           Stop := True;
           PageChar := 'A';
           End;
      'C': Begin
           PageChar := 'C';
           Stop := True;
           End;
      End;
    End;
  End;


Procedure PagePlay(PageTune: String);
  Var
    TF: TFile;
    Error: WOrd;
    TempStr: String;

  Begin
  PageChar := ' ';
  If Not FileExist(PageTune) Then
    PageChar := 'E';
  PlayInit;
  TF.Init;
  If Not TF.OpenTextFile(PageTune) Then
    PageChar := 'E';
  TempStr := TF.GetString;
  While ((PageChar = ' ') And (TF.StringFound)) Do
    Begin
    Play(TempStr);
    TempStr := TF.GetString;
    End;
  If Not TF.CloseTextFile Then;
  TF.Done;
  End;


Procedure MessageInstead;
  Var
    LeaveMsg: Boolean;
    MsgEnter: MsgEntObj;
    Sec: SecType;

  Begin
  User.GetUserSec(Sec);
  User.DisplayNewLine;
  User.DisplayStrLn(Prompts.GetString(076));
  LeaveMsg := (Config^.GetPageMsgArea <> 0);
  User.DisplayNewLine;
  If LeaveMsg Then
    Begin
    If Config^.MsgReadAccess(Config^.GetPageMsgArea, Sec) Then
      User.AskYN(Prompts.GetString(077), LeaveMsg)
    Else
      LeaveMsg := False;
    End;
  If LeaveMsg Then
    Begin
    User.DisplayNewLine;
    MsgEnter.Init;
    MsgEnter.SetArea(Config^.GetPageMsgArea);
    MsgEnter.SetFrom(User.GetUserName);
    MsgEnter.SetTo(Config^.GetSysopName);
    MsgEnter.MsgTest(Sec);
    MsgEnter.Done;
    End
  Else
    Begin
    User.DisplayNewLine;
    User.PressEnter;
    End;
  End;


Procedure DoPage;
  Var
    PageTimes: Word;
    PageOk: Word;
    PageStr: String;
    PageTune: Word;

  Begin
  MusicKeyPressed := SysopWaiting;
  MusicKeyProc := PageKey;
  PageChar := ' ';
  PageTune := User.GetUserPageTune;
  User.DisplayAttr(Config^.GetSystemColor(1));
  If Config^.InPageHours Then
    PageOk := 0
  Else
    PageOk := 1;
  If (PageOk = 0) Then
    Begin
    PageTimes := User.GetUserPageTimes;
    Inc(PageTimes);
    If (PageTimes > Config^.GetMaxPageTimes) Then
      PageOk := 1;
    End;
  If (PageOk = 0) Then
    Begin
    User.DisplayNewLine;
    User.DisplayStr(Prompts.GetString(075) + ' ');
    PageStr := User.InputStr('',40);
    User.DisplayNewLine;
    If Length(PageStr) > 0 Then
      User.SetChatReason(PageStr)
    Else
      PageOk := 2;
    End;
  If (PageOk = 0) Then
    Begin
    User.SetUserPageTimes(PageTimes);
    SnoopNotify('Page from ' + User.GetUserName + ': ' + User.GetChatReason);
    User.DisplayNewLine;
    User.DisplayStrLn(Prompts.GetString(095));
    PageStr := Config^.FindBbsFile('PAGE.' + Long2Str(PageTune)) + 'PAGE.' +
      Long2Str(PageTune);
    If ((Not FileExist(PageStr)) And (PageTune <> 0)) Then
      PageStr := Config^.FindBbsFile('page.mk') + 'page.mk';
    If FileExist(PageStr) Then
      PagePlay(PageStr)
    Else
      Begin
      PlayInit;
      If (PageTune <> 0) Then
        Begin
        Play('T200MNO2L8AO3L4DL8DDEFL4EL8DL4DL8O2AO3DEFGAB-L2AP8');
        If PageChar = ' ' Then
          Play('O3L8AO4L4DL8DDCO3B-L4AL8AL4AL8FL4AL8AGFEL4FL8DL4D');
        If PageChar = ' ' Then
          Play('O3L8EL4FL8FGAB-L4AL8AO4L4DP8O3L8DEFGFEDCL2DP8L8DL2EP8L8EFGFEDCL2D');
        If PageChar = ' ' Then
          Play('T200MNO2L8AO3L4DL8DDEFL4EL8DL4DL8O2AO3DEFGAB-L2AP8');
        If PageChar = ' ' Then
          Play('O3L8AO4L4DL8DDCO3B-L4AL8AL4AL8FL4AL8AGFEL4FL8DL4D');
        If PageChar = ' ' Then
          Play('O3L8EL4FL8FGAB-L4AL8AO4L4DP8O3L8DEFGFEDCL2DP8L8DL2EP8L8EFGFEDCL2DL1D');
        End
      Else
        Play('P1P1P1P1P1P1P1P1P1P1P1P1');
      End;
    If PageChar = 'C' Then
      User.DoChat;
    End;
  Case PageChar Of
    'A',' ': MessageInstead;
    End;
  End;

End.
