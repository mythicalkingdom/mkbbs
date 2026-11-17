Unit MKPty;   {Run a program for the caller on a pseudo terminal}

{$I MKB.Def}

{
     A door or other program started from a menu has the caller on its standard input and output.  A plain socket is not
     what a Unix program expects: there is no echo, a carriage return is not an end of line, a line feed does not go to the
     start of the next line, the telnet bytes of the connection are in the way and a program that wants a terminal (curses,
     isatty) does not work.  PtyRun starts the program on a pseudo terminal instead and carries everything between that
     terminal and the caller's session (MKComAbs: the telnet filter, snooping ...):

         what the caller types       -> the terminal (the line discipline echoes, makes the CR a line end ...)
         what the program writes     -> the caller, as it is (bytes, not translated)

     TERM, COLUMNS and LINES are set from what the caller's terminal reported.  When the caller's window changes the program
     is told (SIGWINCH).  When the caller goes away the program gets SIGHUP.

     Result of PtyRun: 0 = the program ran (ExitCode is its status), ptyNoPty = no pseudo terminal could be made (the caller
     of PtyRun can run the program in the old way), ptyNoExec = the program could not be started.
}

Interface

Const
  ptyNoPty = 1;
  ptyNoExec = 2;

Function PtyRun(Prog: String; Args: String; Term: String; Var ExitCode: LongInt): Word;


Implementation

Uses Classes, BaseUnix, Unix, MKString, MKComAbs;


Const
  TIOCGPTN = $80045430;
  TIOCSPTLCK = $40045431;
  TIOCSCTTY = $540E;
  TIOCSWINSZ = $5414;
  FD_CLOEXEC_ = 1;

Type
  WinSizeType = Packed Record
    Rows, Cols, XPix, YPix: Word;
    End;

  PCharArr = Array Of PChar;


Procedure SplitArgs(S: String; Var L: TStringList);
  {blank separated, "..." keeps blanks together}
  Var
    i: Word;
    InQ: Boolean;
    Cur: String;
    Have: Boolean;

  Begin
  Cur := '';
  InQ := False;
  Have := False;
  For i := 1 To Length(S) Do
    Begin
    If S[i] = '"' Then
      Begin
      InQ := Not InQ;
      Have := True;
      End
    Else If (S[i] = ' ') And (Not InQ) Then
      Begin
      If Have Then
        L.Add(Cur);
      Cur := '';
      Have := False;
      End
    Else
      Begin
      Cur := Cur + S[i];
      Have := True;
      End;
    End;
  If Have Then
    L.Add(Cur);
  End;


Function SetWinSize(Fd: LongInt): Boolean;
  Var
    Cols, Rows: Word;
    WS: WinSizeType;

  Begin
  SetWinSize := False;
  If ComSession = Nil Then
    Exit;
  If Not ComSession^.GetWindowSize(Cols, Rows) Then
    Begin
    Cols := 80;
    Rows := 24;
    End;
  WS.Rows := Rows;
  WS.Cols := Cols;
  WS.XPix := 0;
  WS.YPix := 0;
  SetWinSize := fpIoctl(Fd, TIOCSWINSZ, @WS) = 0;
  End;


Function PtyRun(Prog: String; Args: String; Term: String; Var ExitCode: LongInt): Word;
  Var
    Master, Slave, Idx: LongInt;
    SlaveName: String;
    Pid: TPid;
    ExecPipe: TFilDes;
    Status: cInt;
    Argv, Envv: PCharArr;
    ArgL, EnvS: TStringList;
    i: Integer;
    W: String;
    Cols, Rows: Word;
    Buf: Array[0..4095] Of Byte;
    N, Sent, K: LongInt;
    Rd: TFDSet;
    ChildDone, MasterOpen: Boolean;
    Ver, LastVer: Word;
    Err: Byte;
    Idle: LongInt;

  Begin
  PtyRun := ptyNoPty;
  ExitCode := 0;
  If ComSession = Nil Then
    Exit;
  Master := fpOpen('/dev/ptmx', O_RDWR Or O_NOCTTY);
  If Master < 0 Then
    Exit;
  Idx := 0;
  If fpIoctl(Master, TIOCSPTLCK, @Idx) <> 0 Then
    Begin
    fpClose(Master);
    Exit;
    End;
  If fpIoctl(Master, TIOCGPTN, @Idx) <> 0 Then
    Begin
    fpClose(Master);
    Exit;
    End;
  SlaveName := '/dev/pts/' + Long2Str(Idx);
  If fpPipe(ExecPipe) <> 0 Then
    Begin
    fpClose(Master);
    Exit;
    End;
  fpFcntl(ExecPipe[1], F_SETFD, FD_CLOEXEC_);
  fpFcntl(Master, F_SETFD, FD_CLOEXEC_);
  If Not ComSession^.GetWindowSize(Cols, Rows) Then
    Begin
    Cols := 80;
    Rows := 24;
    End;
  If Term = '' Then
    Term := 'ansi';
  ComSession^.FlushOut;
  Pid := fpFork;
  If Pid < 0 Then
    Begin
    fpClose(Master);
    fpClose(ExecPipe[0]);
    fpClose(ExecPipe[1]);
    Exit;
    End;
  If Pid = 0 Then
    Begin
    {---- the program}
    fpClose(ExecPipe[0]);
    fpSetsid;
    Slave := fpOpen(SlaveName, O_RDWR);
    If Slave < 0 Then
      Begin
      Err := 1;
      fpWrite(ExecPipe[1], Err, 1);
      fpExit(127);
      End;
    fpIoctl(Slave, TIOCSCTTY, Pointer(0));
    SetWinSize(Slave);
    fpDup2(Slave, 0);
    fpDup2(Slave, 1);
    fpDup2(Slave, 2);
    For i := 3 To 255 Do
      If i <> ExecPipe[1] Then
        fpClose(i);
    fpSignal(SIGPIPE, SignalHandler(SIG_DFL));
    fpSignal(SIGCHLD, SignalHandler(SIG_DFL));
    fpSignal(SIGHUP, SignalHandler(SIG_DFL));
    fpSignal(SIGINT, SignalHandler(SIG_DFL));
    fpSignal(SIGTERM, SignalHandler(SIG_DFL));
    ArgL := TStringList.Create;
    ArgL.Add(Prog);
    SplitArgs(Args, ArgL);
    SetLength(Argv, ArgL.Count + 1);
    For i := 0 To ArgL.Count - 1 Do
      Argv[i] := PChar(ArgL[i]);
    Argv[ArgL.Count] := Nil;
    EnvS := TStringList.Create;
    i := 0;
    While envp[i] <> Nil Do
      Begin
      W := StrPas(envp[i]);
      If (Copy(W, 1, 5) <> 'TERM=') And (Copy(W, 1, 8) <> 'COLUMNS=') And (Copy(W, 1, 6) <> 'LINES=') Then
        EnvS.Add(W);
      Inc(i);
      End;
    EnvS.Add('TERM=' + Term);
    EnvS.Add('COLUMNS=' + Long2Str(Cols));
    EnvS.Add('LINES=' + Long2Str(Rows));
    SetLength(Envv, EnvS.Count + 1);
    For i := 0 To EnvS.Count - 1 Do
      Envv[i] := PChar(EnvS[i]);
    Envv[EnvS.Count] := Nil;
    fpExecve(Prog, PPChar(@Argv[0]), PPChar(@Envv[0]));
    Err := fpGetErrno And 255;
    If Err = 0 Then
      Err := 255;
    fpWrite(ExecPipe[1], Err, 1);
    fpExit(127);
    End;
  {---- the BBS: the pipe tells whether the program started (it closes when the program is exec'ed)}
  fpClose(ExecPipe[1]);
  Err := 0;
  K := fpRead(ExecPipe[0], Err, 1);
  fpClose(ExecPipe[0]);
  If K > 0 Then
    Begin
    fpWaitPid(Pid, @Status, 0);
    fpClose(Master);
    PtyRun := ptyNoExec;
    Exit;
    End;
  ChildDone := False;
  MasterOpen := True;
  LastVer := CommWindowVersion;
  Idle := 0;
  While MasterOpen Do
    Begin
    {what the program wrote goes to the caller}
    fpFD_ZERO(Rd);
    fpFD_SET(Master, Rd);
    N := fpSelect(Master + 1, @Rd, Nil, Nil, 15);
    If (N > 0) And (fpFD_ISSET(Master, Rd) <> 0) Then
      Begin
      N := fpRead(Master, Buf, SizeOf(Buf));
      If N > 0 Then
        Begin
        Sent := 0;
        While (Sent < N) And ComSession^.GetCarrier Do
          Begin
          K := ComSession^.SendBlock(Buf[Sent], N - Sent);
          If K > 0 Then
            Inc(Sent, K);
          End;
        End
      Else
        MasterOpen := False;                  {the program and everything it started closed the terminal}
      End;
    {what the caller typed goes to the program}
    If MasterOpen Then
      Begin
      While Not ComSession^.InEmpty Do
        Begin
        N := ComSession^.GetBlock(Buf, SizeOf(Buf));
        If N <= 0 Then
          Break;
        Sent := 0;
        While Sent < N Do
          Begin
          K := fpWrite(Master, Buf[Sent], N - Sent);
          If K <= 0 Then
            Break;
          Inc(Sent, K);
          End;
        End;
      Ver := CommWindowVersion;
      If Ver <> LastVer Then
        Begin
        LastVer := Ver;
        SetWinSize(Master);
        End;
      End;
    {the caller is gone: the program is told}
    If Not ComSession^.GetCarrier Then
      Begin
      fpKill(Pid, SIGHUP);
      If Not ChildDone Then
        Begin
        Inc(Idle);
        If Idle > 200 Then
          Begin
          fpKill(Pid, SIGKILL);
          End;
        End;
      End;
    If Not ChildDone Then
      If fpWaitPid(Pid, @Status, WNOHANG) = Pid Then
        ChildDone := True;
    If ChildDone And MasterOpen Then
      Begin
      {the program ended: what is left in the terminal is still sent}
      fpFD_ZERO(Rd);
      fpFD_SET(Master, Rd);
      N := fpSelect(Master + 1, @Rd, Nil, Nil, 5);
      If (N <= 0) Or (fpFD_ISSET(Master, Rd) = 0) Then
        MasterOpen := False;
      End;
    End;
  fpClose(Master);
  If Not ChildDone Then
    fpWaitPid(Pid, @Status, 0);
  If wifexited(Status) Then
    ExitCode := wexitstatus(Status)
  Else
    ExitCode := 128 + wtermsig(Status);
  PtyRun := 0;
  End;


End.
