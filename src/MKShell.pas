Unit MKShell;
{$I MKB.Def}

Interface

Function WriteDorInfo: Word;
Function WriteDoorSys: Word;
Function WriteCallInfo: Word;
Procedure TypeSeven(Cmd: String);
  {Menu command 007, run a program: the command line, with these parameters (from the DOS original, a * and a letter):
     *B baud  *C comspec  *D door.sys  *F first name  *L last name  *G ansi 1/0  *M (swap, ignored)  *N node  *P baud
     *R user record  *T minutes left  *W callinfo.bbs  *! time stops while the program runs  *0 *1 templates  ** a star
     *S  Linux: the program gets the caller's connection itself as standard input / output (no terminal); without it the
         program runs on a pseudo terminal (MKPty: echo, CR LF, TERM / COLUMNS / LINES from the caller's terminal, raw mode
         for curses; MK_NOPTY in the environment turns the terminal off for all)
   The program name may have a DOS style path (backslashes), without a path it is looked for in the BBS directory, then in
   the path.  One that cannot be run is reported to the caller and logged.}


Implementation


Uses MKFile, MKString, MKCfgAbs, MKDoor, MKGlobT, MKComAbs, MKDos, MKLogEnt,
  MKRCfgMK,
  MKScrn,
    MKVCrt,
  Dos;



Function WriteDorInfo: Word;
  Var
    DorFile: Text;
    Error: Word;
    Graphics: Word;
    Sec: SecType;

  Begin
  Error := 0;
  Assign(DorFile, 'dorinfo1.def');
  ReWrite(DorFile);
  Error := IoResult;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Upper(Config^.GetBbsName));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Upper(ExtractWord(Config^.GetSysopName, 1)));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Upper(ExtractWord(Config^.GetSysopName,
      WordCount(Config^.GetSysopName))));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'COM' + Long2Str(CurrentPort));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserBaud) + ' BAUD,N,8,1');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, '0');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Upper(ExtractWord(User.GetUserName, 1)));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Upper(ExtractWord(User.GetUserName,
      WordCount(User.GetUserName))));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Upper(User.GetUserCity));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    Graphics := 0;
    If User.GetUserAnsi Then
      Inc(Graphics, 1);
    If User.GetUserAvatar Then
      Inc(Graphics, 2);
    WriteLn(DorFile, Long2Str(Graphics));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    User.GetUserSec(Sec);
    WriteLn(DorFile, Long2Str(Sec.Level));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.TimeRemain Div 60));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    Close(DorFile);
    Error := IoResult;
    End;
  WriteDorInfo := Error;
  End;


Function WriteDoorSys: Word;
  Var
    DorFile: Text;
    Error: Word;
    Graphics: Word;
    Sec: SecType;

  Begin
  Error := 0;
  Assign(DorFile, 'door.sys');
  ReWrite(DorFile);
  Error := IoResult;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'COM' + Long2Str(CurrentPort) + ':');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserBaud));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, '8');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserLineNum));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'N');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'Y');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'Y');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'Y');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'Y');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserName);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserCity);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserVoicePhone);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserDataPhone);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserPwd);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    User.GetUserSec(Sec);
    WriteLn(DorFile, Long2Str(Sec.Level));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserTimesCalled));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserLastDate);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.TimeRemain));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.TimeRemain Div 60));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    If User.GetUserAnsi Then
      WriteLn(DorFile, 'GR')
    Else
      WriteLn(DorFIle, 'NG');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserScrLength));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'N');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'ABCDEFG');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'G');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, '12/31/99');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserRecNum));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'Z');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserULFiles));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserDLFiles));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserTodayK));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserDLLimit));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    Close(DorFile);
    Error := IoResult;
    End;
  WriteDoorSys := Error;
  End;


Function WriteCallInfo: Word;
  Var
    DorFile: Text;
    Error: Word;
    Graphics: Word;
    Sec: SecType;

  Begin
  Error := 0;
  Assign(DorFile, 'callinfo.bbs');
  ReWrite(DorFile);
  Error := IoResult;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserName);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    Case User.GetUserBaud Of
      00300: WriteLn(DorFile, '1');
      01200: WriteLn(DorFile, '2');
      02400: WriteLn(DorFile, '0');
      09600: WriteLn(DorFile, '3');
      19200: WriteLn(DorFile, '4');
      00000: WriteLn(DorFile, '5');
      Else
        WriteLn(DorFile, '3');
      End;
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserCity);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    User.GetUserSec(Sec);
    WriteLn(DorFile, Long2Str(Sec.Level));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.TimeRemain Div 60));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    If User.GetUserAnsi Then
      WriteLn(DorFile, 'COLOR')
    Else
      WriteLn(DorFIle, 'MONO');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserPwd);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserRecNum));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserSecondsOn Div 60));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Copy(TimeStr(GetDosDate),1,5));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Copy(TimeStr(GetDosDate),1,5) + DateStr(GetDosDate));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'A');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, '0');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, '100');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserTodayK));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserDLLimit));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserVoicePhone);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, DateStr(GetDosDate) + Copy(TimeStr(GetDosDate),1,5));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'NOVICE');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'All');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, User.GetUserLastDate);
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserTimesCalled));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserScrLength));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserCombRead));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserULFiles));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserDLFiles));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, '8');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    If CurrentPort = 0 Then
      WriteLn(DorFile, 'LOCAL')
    Else
      WriteLn(DorFile, 'REMOTE');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'COM' + Long2Str(CurrentPort));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, '01/01/80');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserBaud));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'TRUE');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, 'Normal Connection');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, DateStr(GetDosDate) + Copy(TimeStr(GetDosDate +
      ((User.TimeRemain Div 60) * 32)),1,5));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, Long2Str(User.GetUserLineNum));
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    WriteLn(DorFile, '0');
    Error := IoResult;
    End;
  If Error = 0 Then
    Begin
    Close(DorFile);
    Error := IoResult;
    End;
  WriteCallInfo := Error;
  End;


Procedure TypeSeven(Cmd: String);
  Var
    LastStar: Boolean;
    Error: Word;
    CmdStr: String;
    Swapping: Boolean;
    DoorSys: Boolean;
    CmdCtr: Word;
    FossilHot: Boolean;
    FreezeTime: Boolean;
    CallInfo: Boolean;
    DoorStart: LongInt;
    Tx, Ty: Byte;
    Failed: Word;
    RawDoor: Boolean;
    UsePty: Boolean;

  Begin
  Failed := 0;
  RawDoor := False;
  User.PostStatus(uoDoor);
  FreezeTime := False;
  FossilHot := False;
  CallInfo := False;
  CmdCtr := 1;
  DoorSys := False;
  LastStar := False;
  CmdStr := '';
  Swapping := False;
  While CmdCtr <= Length(Cmd) Do
    Begin
    If LastStar Then
      Begin
      LastStar := False;
      Case UpCase(Cmd[CmdCtr]) Of
        '*': Begin
             LastStar := True;
             CmdStr := CmdStr + '*';
             End;
        'A':; {Use handle}
        'B': CmdStr := CmdStr + Long2Str(User.GetUserBaud);
        'C': CmdStr := CmdStr + GetEnv('COMSPEC');
        'D': DoorSys := True;
        'F': CmdStr := CmdStr + ExtractWord(User.GetUserName, 1);
        'G': If User.GetUserAnsi Then
               CmdStr := CmdStr + '1'
             Else
               CmdStr := CmdStr + '0';
        'H': FossilHot := True;
        'L': CmdStr := CmdStr + ExtractWord(User.GetUserName,
               WordCount(User.GetUserName));
        'M': Swapping := True;
        'N': CmdStr := CmdStr + Long2Str(User.GetUserLineNum);
        'O':; {over ride baud}
        'P': CmdStr := CmdStr + Long2Str(User.GetUserBaud);
        'R': CmdStr := CmdStr + Long2Str(User.GetUserRecNum);
        'S': RawDoor := True;           {the program gets the caller's connection itself, no pseudo terminal}
        'T': CmdStr := CmdStr + Long2Str(User.TimeRemain Div 60);
        'W': CallInfo := True;
        '!': FreezeTime := True;
        '#':; {turn off want chat}
        '0': CmdStr := CmdStr + Config^.GetFileAreaPath(User.GetUserFileTemplate);
        '1': CmdStr := CmdStr + Long2Str(User.GetUserMsgTemplate);
        Else
          CmdStr := CmdStr + '*' + Cmd[CmdCtr];
        End;
      End
    Else
      Begin
      If Cmd[CmdCtr] = '*' Then
        LastStar := True
      Else
        CmdStr := CmdStr + Cmd[CmdCtr];
      End;
    Inc(CmdCtr);
    End;
  If LastStar Then
    CmdStr := CmdStr + '*';               {a * that ends the command line is a * (a wildcard: *.*)}
  Error := WriteDorInfo;
  If ((Error = 0) And (DoorSys)) Then
    Error := WriteDoorSys;
  If ((Error = 0) And (CallInfo)) Then
    Error := WriteCallInfo;
  If Error = 0 Then
    User.WriteExit('');
  DoorRaw := RawDoor;
  UsePty := DoorPtyWanted;
  If (Not FossilHot) And (Not UsePty) Then
    Begin
    CommRelease;
    End;
  If Error = 0 Then
    Begin
    DoorStart := User.CurrentTime;
    User.DisplayAttr(Config^.GetSystemColor(1));
    User.DisplayStrLn(Prompts.GetString(085));
    LogEntry.WriteEntry('DOS shell : ' + Cmd);
    Tx := WhereX;
    Ty := WhereY;
    DoShell(CmdStr, Swapping, False);
    Failed := ShellError;
    If FreezeTime Then
      User.AdjustTime(User.CurrentTime - DoorStart);
    End;
  GoToXY(1,1);
  DoorRaw := False;
  If (CurrentPort <> 0) And (Not UsePty) Then
    Begin
    CommInit;
    CommFlow(fcBoth);
    End;
  GoToXy(Tx, Ty);
  If Error = 0 Then
    User.ReadExit('');
  If Failed <> 0 Then
    Begin
    {the caller is told: a door that does not start must not look like nothing happened}
    User.DisplayNewLine;
    User.DisplayStrLn('Error: ' + ExtractWord(CmdStr, 1) + ' could not be run');
    LogEntry.WriteEntry('DOS shell failed (' + Long2Str(Failed) + ') : ' + CmdStr);
    User.PressEnter;
    End;
  End;

End.
