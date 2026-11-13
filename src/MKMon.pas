Program MKMon;

{$I MKB.Def}

{
     mkmon - sysop monitor: which nodes are in use, and watch one of them.

        mkmon -l [-r dir]              list the nodes on the terminal and exit
        mkmon -S<type> [-A<addr>] [-H] the monitor session on standard input and
                                       output (mklisten starts it that way for a
                                       port of "type": "sysop")

     The nodes come from <rundir>/node<N>.info (written by mklisten when it
     starts mk) and, for the user and the activity, from UserOn.BBS in the
     BBS directory (environment MK / RA ... as for mk).  Watching a node opens
     <rundir>/node<N>.snoop, the Unix socket of that node's mk (see MKSnoop).
     The run directory is the environment MKRUN or -r.

     The session asks for the password in the environment MKMON_PASSWORD (plain
     text, or "sha1:" and the hex digest).  Without that variable only the
     list (-l) works.  View only: nothing typed here reaches the caller.
}

Uses
  BaseUnix, Sockets, Dos, sha1,
  MKString, MKFile, MKGlobT, MKComAbs, MKSess, MKCfgAbs, MKRCfgMK, MKRCfgRA, MKCfgQB, MKCfgSB;


Type
  UserOnRec = Record                   {as UserOnType in Struct.MK}
    Name: String[35];
    Handle: String[35];
    Node: Byte;
    Baud: Word;
    City: String[25];
    Status: Byte;
    End;

  NodeRec = Record
    Node: LongInt;
    Pid: LongInt;
    Port: LongInt;
    Typ: String[10];
    Addr: String[64];
    Start: LongInt;
    UserName: String[35];
    Status: Byte;
    End;


Const
  MaxNodes = 255;
  Esc = #27;


Var
  RunDir: String;
  UserOnPath: String;
  Nodes: Array[1..MaxNodes] Of NodeRec;
  NumNodes: Word;
  Local: Boolean;


Function Pad(S: String; N: Word): String;
  Begin
  While Length(S) < N Do
    S := S + ' ';
  If Length(S) > N Then
    S[0] := Chr(N);
  Pad := S;
  End;


Function Two(N: LongInt): String;
  Begin
  If N < 10 Then
    Two := '0' + Long2Str(N)
  Else
    Two := Long2Str(N);
  End;


Function ClockStr(T: LongInt): String;
  Var
    H, Mi, S, S100: Word;
    Secs: LongInt;

  Begin
  GetTime(H, Mi, S, S100);               {local time of day, minus the time since T}
  Secs := (LongInt(H) * 3600 + Mi * 60 + S) - (fpTime - T);
  Secs := ((Secs Mod 86400) + 86400) Mod 86400;
  ClockStr := Two(Secs Div 3600) + ':' + Two((Secs Div 60) Mod 60);
  End;


Procedure Delay(Ms: LongInt);
  Begin
  fpPoll(Nil, 0, Ms);
  End;


Function DurStr(Secs: LongInt): String;
  Begin
  If Secs < 0 Then
    Secs := 0;
  DurStr := Long2Str(Secs Div 3600) + ':' + Two((Secs Div 60) Mod 60) + ':' + Two(Secs Mod 60);
  End;


Function ActivityStr(St: Byte): String;
  Begin
  Case St Of
    uoBrowse: ActivityStr := 'Browsing';
    uoXfer: ActivityStr := 'File transfer';
    uoMsg: ActivityStr := 'Messages';
    uoDoor: ActivityStr := 'In a door';
    uoChat: ActivityStr := 'Chat';
    uoQuest: ActivityStr := 'Questionnaire';
    uoReady: ActivityStr := 'Ready';
    uoMail: ActivityStr := 'Offline mail';
    uoWait: ActivityStr := 'Connecting';
    uoLogIn: ActivityStr := 'Logging in';
    Else
      ActivityStr := 'Unknown';
    End;
  End;


Procedure FindUserOnFile;
  Var
    BbsType: Word;

  Begin
  UserOnPath := '';
  Config := Nil;
  BbsType := DetectBbsType;
  Case BbsType Of
    1: Config := New(MKRCfgObjPtr, Init);
    2: Config := New(RARCfgObjPtr, Init);
    3: Config := New(QBCfgObjPtr, Init);
    4: Config := New(SBCfgObjPtr, Init);
    End;
  If Config = Nil Then
    Exit;
  Config^.Load;
  If Config^.GetError = 0 Then
    UserOnPath := Config^.GetBbsPath + 'UserOn.BBS';
  End;


Procedure ReadInfo(FName: String; Var N: NodeRec; Var Ok: Boolean);
  Var
    F: Text;
    L, K, V: String;
    p: Byte;

  Begin
  Ok := False;
  FillChar(N, SizeOf(N), 0);
  Assign(F, FName);
  {$I-}
  Reset(F);
  {$I+}
  If IoResult <> 0 Then
    Exit;
  While Not Eof(F) Do
    Begin
    ReadLn(F, L);
    p := Pos('=', L);
    If p > 0 Then
      Begin
      K := Copy(L, 1, p - 1);
      V := Copy(L, p + 1, 80);
      If K = 'node' Then N.Node := Str2Long(V)
      Else If K = 'pid' Then N.Pid := Str2Long(V)
      Else If K = 'port' Then N.Port := Str2Long(V)
      Else If K = 'type' Then N.Typ := V
      Else If K = 'addr' Then N.Addr := V
      Else If K = 'start' Then N.Start := Str2Long(V);
      End;
    End;
  Close(F);
  Ok := (N.Node > 0) And (N.Node <= MaxNodes);
  End;


Procedure LoadNodes;
  Var
    SR: SearchRec;
    N: NodeRec;
    Ok: Boolean;
    U: UserOnRec;
    i, j: Word;
    T: NodeRec;

  Begin
  NumNodes := 0;
  FindFirst(RunDir + '/node*.info', AnyFile, SR);
  While DosError = 0 Do
    Begin
    ReadInfo(RunDir + '/' + SR.Name, N, Ok);
    If Ok And (N.Pid > 0) Then
      Begin
      If (fpKill(N.Pid, 0) = 0) Or (fpGetErrno = ESysEPERM) Then   {the node is still running}
        Begin
        N.UserName := '';
        N.Status := uoWait;
        If UserOnPath <> '' Then
          If LoadFilePos(UserOnPath, U, SizeOf(U), LongInt(N.Node - 1) * SizeOf(U)) = 0 Then
            Begin
            N.UserName := U.Name;
            N.Status := U.Status;
            End;
        If NumNodes < MaxNodes Then
          Begin
          Inc(NumNodes);
          Nodes[NumNodes] := N;
          End;
        End;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  For i := 1 To NumNodes Do              {by node number}
    For j := i + 1 To NumNodes Do
      If Nodes[j].Node < Nodes[i].Node Then
        Begin
        T := Nodes[i];
        Nodes[i] := Nodes[j];
        Nodes[j] := T;
        End;
  End;


Function NodeLine(Const N: NodeRec): String;
  Begin
  NodeLine := Pad(Long2Str(N.Node), 5) + Pad(N.UserName, 22) + Pad(ActivityStr(N.Status), 15) +
    Pad(N.Addr, 17) + Pad(N.Typ, 8) + Pad(ClockStr(N.Start), 7) + DurStr(fpTime - N.Start);
  End;


Function HeadLine: String;
  Begin
  HeadLine := Pad('Node', 5) + Pad('User', 22) + Pad('Activity', 15) + Pad('Address', 17) +
    Pad('Type', 8) + Pad('Since', 7) + 'Online';
  End;


{------------------------------------------------------------ the session}

Procedure Say(S: String);
  Begin
  ComSession^.SendStr(S);
  End;


Procedure SayLn(S: String);
  Begin
  ComSession^.SendStr(S + #13#10);
  End;


Function Key(Ms: Word): Char;
  {Next key, #0 when none comes in time (Ms) - hangs up count as a Ctrl-X}
  Begin
  Key := #0;
  If Not ComSession^.GetCarrier Then
    Begin
    Key := #24;
    Exit;
    End;
  If ComSession^.WaitForChar(Ms) Then
    Key := ComSession^.GetChar
  Else If Not ComSession^.GetCarrier Then
    Key := #24;
  End;


Function Correct(Typed: String): Boolean;
  Var
    Want: String;

  Begin
  Want := GetEnv('MKMON_PASSWORD');
  If Want = '' Then
    Begin
    Correct := False;
    Exit;
    End;
  If Copy(Want, 1, 5) = 'sha1:' Then
    Begin
    Typed := 'sha1:' + SHA1Print(SHA1String(Typed));
    Want := LowerCase(Want);
    End;
  Correct := Typed = Want;
  End;


Function Login: Boolean;
  Var
    Tries: Byte;
    Pw: String;
    C: Char;
    Waited: Word;

  Begin
  Login := False;
  If GetEnv('MKMON_PASSWORD') = '' Then
    Begin
    SayLn('No password is set for the monitor.');
    Exit;
    End;
  For Tries := 1 To 3 Do
    Begin
    Say('Password: ');
    CommFlushOut;
    Pw := '';
    Waited := 0;
    Repeat
      C := Key(1000);
      If C = #0 Then
        Begin
        Inc(Waited);
        If Waited > 60 Then
          C := #24;
        End
      Else
        Waited := 0;
      Case C Of
        #0, #10:;
        #8, #127: If Length(Pw) > 0 Then Dec(Pw[0]);
        #24, #3, #4: Exit;
        #13: ;
        Else
          If (C >= ' ') And (Length(Pw) < 80) Then
            Pw := Pw + C;
        End;
    Until C = #13;
    SayLn('');
    If Correct(Pw) Then
      Begin
      Login := True;
      Exit;
      End;
    SayLn('Wrong password.');
    CommFlushOut;
    Delay(1500);
    End;
  End;


Procedure ShowNodes(Typed: String);
  Var
    i: Word;

  Begin
  LoadNodes;
  Say(Esc + '[0m' + Esc + '[2J' + Esc + '[H');
  SayLn(Esc + '[1;37mMK sysop monitor' + Esc + '[0m   ' + Long2Str(NumNodes) + ' node(s) in use');
  SayLn('');
  SayLn(Esc + '[1;33m' + HeadLine + Esc + '[0m');
  For i := 1 To NumNodes Do
    SayLn(NodeLine(Nodes[i]));
  If NumNodes = 0 Then
    SayLn('(nobody is online)');
  SayLn('');
  Say('Node number to watch, R refresh, Q quit: ' + Typed);
  CommFlushOut;
  End;


Function Watch(Node: LongInt): String;
  {Show what the node sends until Ctrl-X; returns a message for the menu}
  Var
    S: LongInt;
    A: TUnixSockAddr;
    Path: String;
    Buf: Array[0..4095] Of Char;
    P: TPollFd;
    N: LongInt;
    C: Char;
    Gone: Boolean;

  Begin
  Watch := '';
  Path := RunDir + '/node' + Long2Str(Node) + '.snoop';
  S := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  FillChar(A, SizeOf(A), 0);
  A.family := AF_UNIX;
  If (Length(Path) > 100) Or (S < 0) Then
    Begin
    Watch := 'Node ' + Long2Str(Node) + ' cannot be watched.';
    Exit;
    End;
  Move(Path[1], A.path, Length(Path));
  If fpConnect(S, @A, SizeOf(A)) <> 0 Then
    Begin
    fpClose(S);
    Watch := 'Node ' + Long2Str(Node) + ' cannot be watched (not running, or no snoop socket).';
    Exit;
    End;
  Say(Esc + '[0m' + Esc + '[2J' + Esc + '[H' + 'Watching node ' + Long2Str(Node) +
    '.  Ctrl-X ends.' + #13#10);
  CommFlushOut;
  Delay(1200);
  Say(Esc + '[0m' + Esc + '[2J' + Esc + '[H');
  Gone := False;
  Repeat
    P.fd := S;
    P.events := POLLIN;
    P.revents := 0;
    If fpPoll(@P, 1, 50) > 0 Then
      Begin
      N := fpRead(S, Buf, SizeOf(Buf));
      If N <= 0 Then
        Gone := True
      Else
        Begin
        ComSession^.SendBlock(Buf, N);
        CommFlushOut;
        End;
      End;
    While Not ComSession^.InEmpty Do
      Begin
      C := ComSession^.GetChar;
      If C = #24 Then
        Gone := True;                    {Ctrl-X}
      End;
    If Not ComSession^.GetCarrier Then
      Gone := True;
  Until Gone;
  fpClose(S);
  Say(Esc + '[0m' + Esc + '[2J' + Esc + '[H');
  Watch := '';
  End;


Procedure Monitor;
  Var
    Typed, Msg: String;
    C: Char;
    Idle: Word;
    N: LongInt;
    Found: Boolean;
    i: Word;

  Begin
  Typed := '';
  Idle := 0;
  Msg := '';
  ShowNodes(Typed);
  Repeat
    C := Key(5000);
    If C = #0 Then
      Begin
      Inc(Idle);
      If Idle > 120 Then
        Exit;                            {10 minutes of nothing}
      ShowNodes(Typed);
      End
    Else
      Begin
      Idle := 0;
      Case UpCase(C) Of
        '0'..'9': If Length(Typed) < 3 Then
                    Begin
                    Typed := Typed + C;
                    Say(C);
                    CommFlushOut;
                    End;
        #8, #127: If Length(Typed) > 0 Then
                    Begin
                    Dec(Typed[0]);
                    Say(#8' '#8);
                    CommFlushOut;
                    End;
        'R': Begin
             Typed := '';
             ShowNodes(Typed);
             End;
        'Q', #24, #3: Exit;
        #13: Begin
             If Typed <> '' Then
               Begin
               N := Str2Long(Typed);
               Typed := '';
               LoadNodes;
               Found := False;
               For i := 1 To NumNodes Do
                 If Nodes[i].Node = N Then
                   Found := True;
               If Found Then
                 Msg := Watch(N)
               Else
                 Msg := 'Node ' + Long2Str(N) + ' is not in use.';
               End;
             ShowNodes('');
             If Msg <> '' Then
               Begin
               SayLn('');
               SayLn(Msg);
               CommFlushOut;
               Msg := '';
               End;
             End;
        End;
      End;
  Until False;
  End;


Var
  i: Word;
  S, TmpStr: String;
  SessType, SessAddr: String;
  SessProxy: Boolean;
  j: Word;

Begin
RunDir := GetEnv('MKRUN');
SessType := '';
SessAddr := '';
SessProxy := False;
Local := False;
i := 1;
While i <= ParamCount Do
  Begin
  S := ParamStr(i);
  TmpStr := Upper(S);
  If (Length(S) > 1) And (S[1] = '-') Then
    Case TmpStr[2] Of
      'L': Local := True;
      'R': Begin
           If Length(S) > 2 Then
             RunDir := Copy(S, 3, 200)
           Else If i < ParamCount Then
             Begin
             Inc(i);
             RunDir := ParamStr(i);
             End;
           End;
      'S': SessType := Copy(TmpStr, 3, 10);
      'A': SessAddr := Copy(S, 3, 64);
      'H': SessProxy := True;
      End;
  Inc(i);
  End;
If RunDir = '' Then
  RunDir := '/tmp/mklisten-' + Long2Str(fpGetUid);
FindUserOnFile;
If Local Then
  Begin
  LoadNodes;
  WriteLn(HeadLine);
  For j := 1 To NumNodes Do
    WriteLn(NodeLine(Nodes[j]));
  Halt(0);
  End;
ComSession := CreateSession(SessType, 0, SessAddr, SessProxy);
If ComSession = Nil Then
  Begin
  WriteLn(StdErr, SessionError);
  Halt(1);
  End;
CommInit;
If Login Then
  Monitor;
SayLn('');
SayLn('Bye.');
CommFlushOut;
CommRelease;
Dispose(ComSession, Done);
End.
