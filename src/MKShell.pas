Unit MKShell;
{$I MKB.Def}

Interface

Type
  TWrapHook = Function(Var Cmd: String; Const NodeDir: String): Boolean;
    {set by MKDosDoor: gives the command line a sandbox (bubblewrap) when the settings say so; False = the program must not be run (the hook has logged why)}

Var
  ShellWrapHook: TWrapHook;

Function WriteDorInfo: Word;
Function WriteDoorSys: Word;
Function WriteCallInfo: Word;
Function WriteDoor32(Raw: Boolean): Word;
  {DOOR32.SYS: comm type (2 = the connection is a socket and the program has it as its standard input / output: Raw, with *S;
   0 = local: a pseudo terminal, a pipe), the handle (0: the descriptor of standard input / output), the baud rate, the BBS software, the user's record number,
   real name, handle, security level, minutes left, emulation (1 ANSI), node}
Procedure TypeSeven(Cmd: String);
  {Menu command 007, run a program: the command line, with these parameters (from the DOS original, a * and a letter):
     *B baud  *C comspec  *D door.sys  *F first name  *L last name  *G ansi 1/0  *M (swap, ignored)  *N node  *P baud
     *R user record  *T minutes left  *W callinfo.bbs  *3 door32.sys  *! time stops while the program runs  *0 *1 templates  ** a star
     *S  Linux: the program gets the caller's connection itself as standard input / output (no terminal); without it the
         program runs on a pseudo terminal (MKPty: echo, CR LF, TERM / COLUMNS / LINES from the caller's terminal, raw mode
         for curses; MK_NOPTY in the environment turns the terminal off for all)
   The program name may have a DOS style path (backslashes), without a path it is looked for in the BBS directory, then in
   the path.  One that cannot be run is reported to the caller and logged.
   The program runs in node<N> below the BBS directory (made when it is needed), where the drop files DORINFO1.DEF, DOOR.SYS, CALLINFO.BBS and
   EXITINFO.BBS are written: every node has a directory of its own.}


Implementation


Uses MKFile, MKString, MKCfgAbs, MKDoor, MKGlobT, MKComAbs, MKDos, MKLogEnt,
  MKRCfgMK,
  BaseUnix,
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
    WriteLn(DorFile, User.GetUserPwdShown);
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
    WriteLn(DorFile, User.GetUserPwdShown);
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


Function WriteDoor32(Raw: Boolean): Word;
  Var
    F: Text;
    Error: Word;
    Sec: SecType;
    St: Stat;
    CommType: Byte;
    Ansi: Byte;
    Nm, Hd: String;

  Begin
  CommType := 0;
  If Raw And CommActive Then
    Begin
    {a socket as standard input: the program can use it as it is; behind SSH or a front end it is a pipe or a terminal: local}
    If (fpFStat(0, St) = 0) And fpS_ISSOCK(St.st_mode) Then
      CommType := 2;
    End;
  User.GetUserSec(Sec);
  Nm := User.GetUserName;
  Hd := User.GetUserHandle;
  If Hd = '' Then
    Hd := Nm;
  Ansi := 0;
  If User.GetUserAnsi Then
    Ansi := 1;
  Assign(F, 'door32.sys');
  ReWrite(F);
  Error := IoResult;
  If Error = 0 Then
    Begin
    Write(F, Long2Str(CommType), #13#10, '0', #13#10, Long2Str(User.GetUserBaud), #13#10, BbsVersion, #13#10,
      Long2Str(User.GetUserRecNum), #13#10, Nm, #13#10, Hd, #13#10, Long2Str(Sec.Level), #13#10,
      Long2Str(User.TimeRemain Div 60), #13#10, Long2Str(Ansi), #13#10, Long2Str(User.GetUserLineNum), #13#10);
    Error := IoResult;
    Close(F);
    If IoResult <> 0 Then;
    End;
  WriteDoor32 := Error;
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
    Door32: Boolean;
    DoorStart: LongInt;
    Tx, Ty: Byte;
    Failed: Word;
    RawDoor: Boolean;
    UsePty: Boolean;
    HomeDir, NodeDir, Prog, Wrapped: String;
    InNode: Boolean;

  Begin
  Failed := 0;
  RawDoor := False;
  User.PostStatus(uoDoor);
  FreezeTime := False;
  FossilHot := False;
  CallInfo := False;
  Door32 := False;
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
        '3': Door32 := True;
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
  {the program runs in a directory of its own for this node (node<N> in the BBS directory): the drop files, exitinfo.bbs and what the program
   writes without a path are there, so two nodes do not meet.  A program that is named without a full path is looked for as before (the BBS
   directory first, then the path) and made a full path, since the directory changes; a parameter that is a relative path is not changed}
  HomeDir := GetCurrentPath;
  Prog := ShellProgram(ExtractWord(CmdStr, 1));
  If (Prog <> '') And (Prog[1] <> '/') And FileExist(Prog) Then
    Begin
    If Copy(Prog, 1, 2) = './' Then
      Delete(Prog, 1, 2);
    CmdStr := HomeDir + Prog + Copy(CmdStr, Length(ExtractWord(CmdStr, 1)) + 1, 255);
    End;
  NodeDir := HomeDir + 'node' + Long2Str(User.GetUserLineNum);
  InNode := False;
  If Not DirExist(NodeDir) Then
    MkDir(NodeDir);
  If IoResult <> 0 Then;
  If DirExist(NodeDir) Then
    Begin
    ChDir(NodeDir);
    InNode := IoResult = 0;
    End;
  Error := WriteDorInfo;
  If ((Error = 0) And (DoorSys)) Then
    Error := WriteDoorSys;
  If ((Error = 0) And (CallInfo)) Then
    Error := WriteCallInfo;
  If (Error = 0) And (Door32) Then
    Error := WriteDoor32(RawDoor);
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
    Wrapped := CmdStr;
    If (@ShellWrapHook <> Nil) And (Not ShellWrapHook(Wrapped, NodeDir)) Then
      Failed := 8
    Else
      Begin
      DoShell(Wrapped, Swapping, False);
      Failed := ShellError;
      End;
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
  If InNode Then
    Begin
    ChDir(StripTrail(HomeDir, DirectorySeparator));
    If IoResult <> 0 Then;
    End;
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
