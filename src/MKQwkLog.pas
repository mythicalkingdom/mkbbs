Unit MKQwkLog;       {mk -Q: the login of a QWK network system (or any caller who has a script)}

{$I MKB.Def}

{
     MKQwkLog - a simple login for callers that are programs: it is the way Synchronet does it, so the same scripts work.

       Login:      the name of the user record (the QWK id of the system); no new users, no language, no screens
       Password:   the password of the record; three tries
       Logging on to <system> as <name> ...   (as Synchronet says it, then the QWK: prompt)
       QWK:        D download the packet (<BBSID>.QWK), U upload the reply packet (<BBSID>.REP),
                   B both (upload first), ? the list, Q quit

     Only users with the QWK Node flag may come in this way.  The packet is the offline mail of the user record (QWK format,
     packer and protocol of the record or the first ones of the system, QWKE if the system wants it) and nothing is asked: the
     last read pointers of the record say what was sent already.  The prompts are not from the language file, so a
     script can wait for them.
}


Interface


Procedure QwkSession;


Implementation


Uses MKString, MKDoor, MKCfgAbs, MKGlobT, MKLogEnt, MKOfflin, MKFile;


Function QwkLogin: Boolean;
  Var
    Tries: Word;
    Name, Pwd: String;
    Ok: Boolean;

  Begin
  Ok := False;
  Tries := 0;
  While (Not Ok) And (Tries < 3) And User.Ok Do
    Begin
    Inc(Tries);
    User.DisplayStr('Login: ');
    Name := StripBoth(User.InputStr('', 40), ' ');
    User.DisplayNewLine;
    User.DisplayStr('Password: ');
    Pwd := User.InputPwd(50);
    User.DisplayNewLine;
    If (Name <> '') And User.Ok Then
      Begin
      User.GetUserPos(Name);
      If User.UserFound Then
        Begin
        User.ReadUser;
        Ok := User.GetUserQwkNode And User.CheckUserPwd(Pwd);
        End;
      End;
    If Not Ok Then
      Begin
      LogEntry.WriteEntry('QWK login failed for "' + Name + '"');
      User.DisplayStrLn('Login incorrect');
      End;
    End;
  If Ok Then
    Begin
    LogEntry.BlankLine;
    LogEntry.WriteEntry(User.GetUserName + ' on-line (QWK) at ' + Long2Str(UserBaud) + ' BPS');
    User.DisplayStrLn('Logging on to ' + Config^.GetBbsName + ' as ' + User.GetUserName + ' ...');
    User.PostStatus(uoLogIn);
    User.SetUserTimesCalled(User.GetUserTimesCalled + 1);
    User.SetSessionTimeLimit(3600);
    User.SetStartTime;
    User.SetIdleTimeLimit(120);
    User.SetUserOffType('Q');
    User.SetUserAnsi(False);
    User.SetMore(False);
    End
  Else
    User.SetOk(False);
  QwkLogin := Ok;
  End;


Procedure QwkSession;
  Var
    Ch: Char;
    Done: Boolean;

  Begin
  OfflineQuiet := True;
  If Not QwkLogin Then
    Exit;
  Done := False;
  While User.Ok And Not Done Do
    Begin
    User.DisplayStr('QWK: ');
    Ch := User.AskChoice('DUBQ?');
    If User.Ok Then
      Begin
      User.DisplayChr(Ch);
      User.DisplayNewLine;
      Case Ch Of
        'D': OfflineDL;
        'U': OfflineUL;
        'B': Begin
             OfflineUL;
             OfflineDL;
             End;
        '?': Begin
             User.DisplayNewLine;
             User.DisplayStrLn('QWK Offline Reader Menu');
             User.DisplayStrLn('U Upload REP reply packet');
             User.DisplayStrLn('D Download QWK message packet');
             User.DisplayStrLn('B Both: upload, then download');
             User.DisplayStrLn('Q Quit');
             User.DisplayNewLine;
             End;
        'Q': Done := True;
        End;
      End;
    End;
  User.SetOk(False);
  End;


End.
