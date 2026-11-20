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
     list (-l) works.

     In the node list: L runs the BBS in local mode (mk -L -N<node>, the node of "localnode" in the mklisten
     configuration, mk from MKMON_MK) on this connection and returns here when it ends (it asks for the sysop's login
     as usual; one at a time); M shows the mailer (the binkp mailer mkbink that mklisten runs, see MKMonMail); E shows the events
     mklisten runs (when, what, state, next and last run; R runs one now);
     a node number and Enter watch the node, the number and
     K disconnect it, C chat with the caller (watches the node, the chat starts
     when the BBS is ready), + / - give / take 5 minutes.  While
     watching, everything is view only until typing is switched on; commands
     start with Ctrl-A:
         Ctrl-A T   typing on / off (what you type reaches the BBS as if the
                    caller had typed it)
         Ctrl-A C   chat: what you type appears on the caller's screen (as
                    in the old local chat), Esc ends it.  Also answers a page.
         Ctrl-A K   disconnect the caller (asks Y/N)
         Ctrl-A + / -   give / take 5 minutes
         Ctrl-A A   send a real Ctrl-A (typing on)
         Ctrl-A ?   help          Ctrl-X or Ctrl-A X   stop watching
}

Uses
  BaseUnix, Unix, Sockets, Dos, sha1,
  MKString, MKFile, MKGlobT, MKComAbs, MKSess, MKMonMail, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKPty;


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
    Baud: LongInt;
    Addr: String[64];
    Start: LongInt;
    UserName: String[35];
    Status: Byte;
    End;


Const
  MaxNodes = 255;
  TimeStep = 5;                        {minutes for + and -}
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
    1: Config := NewMKConfig(True);
    2: Config := New(RARCfgObjPtr, Init);
    3: Config := New(QBCfgObjPtr, Init);
    4: Config := New(SBCfgObjPtr, Init);
    End;
  If Config = Nil Then
    Exit;
  Config^.Load;
  If Config^.GetError = 0 Then
    UserOnPath := Config^.GetBbsPath + 'useron.bbs';
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
      Else If K = 'baud' Then N.Baud := Str2Long(V)
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
  Say(Esc + '[0;37;40m' + Esc + '[2J' + Esc + '[H');
  SayLn(Esc + '[1;37;40mMK sysop monitor' + Esc + '[0;37;40m   ' + Long2Str(NumNodes) + ' node(s) in use');
  SayLn('');
  SayLn(Esc + '[1;33;40m' + HeadLine + Esc + '[0;37;40m');
  For i := 1 To NumNodes Do
    SayLn(NodeLine(Nodes[i]));
  If NumNodes = 0 Then
    SayLn('(nobody is online)');
  SayLn('');
  SayLn('Type a node number, then:  Enter watch   C chat   K disconnect   + / - ' + Long2Str(TimeStep) + ' min');
  Say('R refresh, M mailer, E events, L local BBS, Q quit: ' + Typed);
  CommFlushOut;
  End;


Var
  FSt: Byte;                           {APC filter: 0 text, 1 ESC, 2 in message, 3 ESC in message}
  FMsg: String;                        {message being collected}
  FDone: String;                       {last complete message}
  FGot: Boolean;
  FOut: Array[0..4095] Of Char;
  FOutN: Word;


Procedure FilterBytes(Var Buf; N: LongInt);
  {Takes the answers (ESC _ text ESC \) out of the stream the node sends}
  Var
    k: LongInt;
    B: Char;

  Procedure Put1(C: Char);
    Begin
    If FOutN < SizeOf(FOut) Then
      Begin
      FOut[FOutN] := C;
      Inc(FOutN);
      End;
    End;

  Begin
  FOutN := 0;
  For k := 0 To N - 1 Do
    Begin
    B := Chr(Ord(PChar(@Buf)[k]));
    Case FSt Of
      0: If B = Esc Then FSt := 1 Else Put1(B);
      1: If B = '_' Then
           Begin
           FSt := 2;
           FMsg := '';
           End
         Else If B = Esc Then
           Put1(B)                       {stay: another ESC may start it}
         Else
           Begin
           Put1(Esc);
           Put1(B);
           FSt := 0;
           End;
      2: If B = Esc Then FSt := 3
         Else If Length(FMsg) < 120 Then FMsg := FMsg + B;
      3: If B = '\' Then
           Begin
           FDone := FMsg;
           FGot := True;
           FSt := 0;
           End
         Else
           FSt := 2;
      End;
    End;
  End;


Procedure SendFrame(S: LongInt; Tag: Char; Arg: Byte; Var Data; N: Byte);
  Var
    Hd: String;

  Begin
  Hd := Tag;
  If (Tag = '+') Or (Tag = '-') Then
    Hd := Hd + Chr(Arg)
  Else If (Tag = 'D') Or (Tag = 'S') Then
    Hd := Hd + Chr(N);
  fpSend(S, @Hd[1], Length(Hd), MSG_NOSIGNAL);
  If ((Tag = 'D') Or (Tag = 'S')) And (N > 0) Then
    fpSend(S, @Data, N, MSG_NOSIGNAL);
  End;


Function OpenSnoop(Node: LongInt): LongInt;
  {Socket to the node, -1 when it cannot be reached}
  Var
    S: LongInt;
    A: TUnixSockAddr;
    Path: String;

  Begin
  OpenSnoop := -1;
  Path := RunDir + '/node' + Long2Str(Node) + '.snoop';
  If Length(Path) > 100 Then
    Exit;
  S := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  If S < 0 Then
    Exit;
  FillChar(A, SizeOf(A), 0);
  A.family := AF_UNIX;
  Move(Path[1], A.path, Length(Path));
  If fpConnect(S, @A, SizeOf(A)) <> 0 Then
    Begin
    fpClose(S);
    Exit;
    End;
  OpenSnoop := S;
  End;


Function NodeCommand(Node: LongInt; Tag: Char; Arg: Byte): String;
  {One command to a node, returns its answer}
  Var
    S: LongInt;
    P: TPollFd;
    Buf: Array[0..4095] Of Char;
    N: LongInt;
    T: Word;
    Dummy: Byte;

  Begin
  S := OpenSnoop(Node);
  If S < 0 Then
    Begin
    NodeCommand := 'Node ' + Long2Str(Node) + ' cannot be reached.';
    Exit;
    End;
  FSt := 0;
  FGot := False;
  FDone := '';
  SendFrame(S, Tag, Arg, Dummy, 0);
  T := 0;
  While (Not FGot) And (T < 40) Do         {up to 2 seconds}
    Begin
    P.fd := S;
    P.events := POLLIN;
    P.revents := 0;
    If fpPoll(@P, 1, 50) > 0 Then
      Begin
      N := fpRead(S, Buf, SizeOf(Buf));
      If N <= 0 Then
        T := 100
      Else
        FilterBytes(Buf, N);
      End
    Else
      Inc(T);
    End;
  fpClose(S);
  If FGot Then
    NodeCommand := FDone
  Else
    NodeCommand := 'No answer from node ' + Long2Str(Node) + '.';
  End;


Var
  BarDirty: Boolean;                   {the bar must be drawn (when the stream is between sequences)}
  BarShown: String;                    {what the bar said when it was drawn last}
  StSt: Byte;                          {the node's stream: 0 text, 1 after ESC, 2 in CSI, 3 in a string,
                                        4 ESC in a string, 5 ESC + intermediate}
  CsiBuf: String[24];
  Sgr: String;                         {the colors the node has set (to put them back after the bar)}
  BarMsg: String;                      {an answer shown for a moment instead of the status}
  BarTicks: Integer;                   {how much longer (in 50 ms steps)}
  BarTyping: Boolean;
  BarChat: Boolean;
  BarNode: LongInt;
  BarInfo: String;                     {Node, name, activity ...}
  BarRows, BarCols: Word;
  BarVer: Word;


Procedure Status(M: String);
  {Show an answer in the bar for 3 seconds}
  Begin
  BarMsg := M;
  BarTicks := 60;
  BarDirty := True;
  End;


Procedure Track(Var Buf; N: LongInt);
  {Follows the node's output: where an escape sequence ends (the bar is only drawn
   between sequences), the colors it set, and screen clears (they wipe the bar)}
  Var
    k: LongInt;
    B: Byte;
    Seq: String;

  Begin
  For k := 0 To N - 1 Do
    Begin
    B := Ord(PChar(@Buf)[k]);
    Case StSt Of
      0: If B = 27 Then StSt := 1;
      1: If B = Ord('[') Then
           Begin
           StSt := 2;
           CsiBuf := '';
           End
         Else If B In [Ord(']'), Ord('P'), Ord('X'), Ord('^'), Ord('_')] Then
           StSt := 3
         Else If (B >= $20) And (B <= $2F) Then
           StSt := 5
         Else If B = 27 Then
           StSt := 1
         Else
           Begin
           If B = Ord('c') Then
             Sgr := '';                  {full reset}
           StSt := 0;
           End;
      5: If B = 27 Then
           StSt := 1
         Else If (B < $20) Or (B > $2F) Then
           StSt := 0;
      2: If B = 27 Then
           StSt := 1
         Else If (B >= $30) And (B <= $3F) Then
           Begin
           If Length(CsiBuf) < 24 Then
             CsiBuf := CsiBuf + Chr(B);
           End
         Else If (B >= $40) And (B <= $7E) Then
           Begin
           If B = Ord('m') Then
             Begin
             Seq := Esc + '[' + CsiBuf + 'm';
             If (CsiBuf = '') Or (CsiBuf = '0') Then
               Sgr := ''
             Else If (Copy(CsiBuf, 1, 2) = '0;') Or (CsiBuf[1] = ';') Then
               Sgr := Seq
             Else If Length(Sgr) + Length(Seq) > 200 Then
               Sgr := Seq
             Else
               Sgr := Sgr + Seq;
             End
           Else If (B = Ord('J')) And (CsiBuf = '2') Then
             BarDirty := True;           {the screen was cleared}
           StSt := 0;
           End;
      3: If B = 7 Then StSt := 0
         Else If B = 27 Then StSt := 4;
      4: If B = Ord('\') Then StSt := 0 Else StSt := 3;
      End;
    End;
  End;


Procedure BarSize;
  {The sysop's window: the bar is its last row, the node's output scrolls above it}
  Var
    C, R: Word;

  Begin
  BarCols := 80;
  BarRows := 25;
  If ComSession^.GetWindowSize(C, R) Then
    Begin
    If C >= 40 Then
      BarCols := C;
    If R >= 5 Then
      BarRows := R;
    End;
  BarVer := ComSession^.WindowVersion;
  Say(Esc + '[1;' + Long2Str(BarRows - 1) + 'r');   {scrolling region without the bar}
  End;


Procedure BarRefresh;
  {Who is on the node now}
  Var
    i: Word;

  Begin
  LoadNodes;
  BarInfo := '';
  For i := 1 To NumNodes Do
    If Nodes[i].Node = BarNode Then
      Begin
      BarInfo := 'Node ' + Long2Str(Nodes[i].Node) + '  ';
      If Nodes[i].UserName <> '' Then
        BarInfo := BarInfo + Nodes[i].UserName + '  '
      Else
        BarInfo := BarInfo + '-  ';
      If Nodes[i].Baud > 0 Then
        BarInfo := BarInfo + Long2Str(Nodes[i].Baud) + ' ';
      BarInfo := BarInfo + Nodes[i].Typ + '  ' + ActivityStr(Nodes[i].Status) + '  ' +
        Nodes[i].Addr;
      End;
  If BarInfo = '' Then
    BarInfo := 'Node ' + Long2Str(BarNode) + '  (ended)';
  End;


Function BarKey: String;
  {Everything the bar shows (not the time left of an answer)}
  Begin
  If BarTicks > 0 Then
    BarKey := BarMsg + #1 + Long2Str(Ord(BarTyping)) + Long2Str(Ord(BarChat))
  Else
    BarKey := BarInfo + #2 + Long2Str(Ord(BarTyping)) + Long2Str(Ord(BarChat));
  End;


Procedure DrawBar;
  Var
    T, Col: String;

  Begin
  If BarTicks > 0 Then
    Begin
    T := ' ' + BarMsg;
    Col := Esc + '[0;30;43m';            {answer: black on yellow}
    End
  Else
    Begin
    T := ' Ctrl-A=Help  ' + BarInfo;
    If BarChat Then
      Begin
      T := T + '  [CHAT: Esc ends]';
      Col := Esc + '[0;1;37;45m';        {chat: white on magenta}
      End
    Else If BarTyping Then
      Begin
      T := T + '  [TYPING]';
      Col := Esc + '[0;1;37;41m';        {typing on: white on red}
      End
    Else
      Col := Esc + '[0;30;47m';
    End;
  T := Pad(T, BarCols - 1);
  {save the cursor, draw, restore the cursor, then the colors the node had set}
  Say(Esc + '7' + Esc + '[' + Long2Str(BarRows) + ';1H' + Col + T + Esc + '[0m' + Esc + '8' +
    Esc + '[0m' + Sgr);
  BarShown := BarKey;
  BarDirty := False;
  End;


Function Watch(Node: LongInt; ChatFirst: Boolean): String;
  {Show what the node sends until Ctrl-X; returns a message for the menu}
  Var
    S: LongInt;
    Buf: Array[0..4095] Of Char;
    P: TPollFd;
    N: LongInt;
    C: Char;
    Gone, Typing, Prefix, AskKick, ChatOn: Boolean;
    Typed: Array[0..255] Of Char;
    TypedN: Word;
    Dummy: Byte;
    Steps: Word;
    FirstData: Boolean;
    Pend: String[16];                    {an escape sequence from the sysop's terminal, maybe an answer}
    PendAge: Word;
    k: Word;

  Procedure TypeByte(Ch: Char);
    {What the sysop types, for the caller.  The terminal's answers to queries the
     BBS sent (a cursor position report ESC [ row ; col R) are not typed text.}
    Procedure Add(Ch2: Char);
      Begin
      If TypedN < 255 Then
        Begin
        Typed[TypedN] := Ch2;
        Inc(TypedN);
        End;
      End;
    Procedure Flush;
      Var
        k: Word;
      Begin
      For k := 1 To Length(Pend) Do
        Add(Pend[k]);
      Pend := '';
      End;

    Begin
    PendAge := 0;
    If Pend = '' Then
      Begin
      If Ch = #27 Then
        Pend := #27
      Else
        Add(Ch);
      End
    Else
      Begin
      Pend := Pend + Ch;
      If (Length(Pend) = 2) And (Ch <> '[') Then
        Flush
      Else If (Length(Pend) > 2) And (Ch In ['0'..'9', ';']) Then
        Begin
        If Length(Pend) >= 14 Then
          Flush;
        End
      Else If (Length(Pend) > 2) And (Ch = 'R') And (Pos(';', Pend) > 0) Then
        Pend := ''                       {the answer: drop it}
      Else If Length(Pend) > 2 Then
        Flush;
      End;
    End;

  Begin
  Watch := '';
  S := OpenSnoop(Node);
  If S < 0 Then
    Begin
    Watch := 'Node ' + Long2Str(Node) + ' cannot be watched (not running, or no snoop socket).';
    Exit;
    End;
  StSt := 0;
  Sgr := '';
  BarNode := Node;
  BarMsg := '';
  BarTicks := 0;
  BarTyping := False;
  BarChat := False;
  Say(Esc + '[0m' + Esc + '[2J' + Esc + '[H');
  BarSize;
  Say(Esc + '[H');
  BarRefresh;
  DrawBar;
  CommFlushOut;
  Steps := 0;
  FirstData := True;
  If ChatFirst Then
    SendFrame(S, 'C', 0, Dummy, 0);
  Gone := False;
  Typing := False;
  ChatOn := False;
  Prefix := False;
  AskKick := False;
  Pend := '';
  StSt := 0;
  Sgr := '';
  BarDirty := True;                    {the first draw}
  PendAge := 0;
  FSt := 0;
  Repeat
    P.fd := S;
    P.events := POLLIN;
    P.revents := 0;
    FGot := False;
    If fpPoll(@P, 1, 50) > 0 Then
      Begin
      N := fpRead(S, Buf, SizeOf(Buf));
      If N <= 0 Then
        Gone := True
      Else
        Begin
        FilterBytes(Buf, N);
        If FOutN > 0 Then
          Begin
          ComSession^.SendBlock(FOut, FOutN);
          Track(FOut, FOutN);
          If FirstData Then
            Begin
            FirstData := False;
            BarDirty := True;            {what the node sent first may have covered the bar}
            End;
          End;
        CommFlushOut;
        If FGot Then
          Begin
          If Copy(FDone, 1, 12) = 'Chat started' Then
            Begin
            ChatOn := True;
            BarChat := True;
            End
          Else If Copy(FDone, 1, 10) = 'Chat ended' Then
            Begin
            ChatOn := False;
            BarChat := False;
            End;
          Status(FDone);
          End;
        End;
      End;
    TypedN := 0;
    While Not ComSession^.InEmpty Do
      Begin
      C := ComSession^.GetChar;
      If Prefix Then
        Begin
        Prefix := False;
        Case UpCase(C) Of
          'T': Begin
               Typing := Not Typing;
               BarTyping := Typing;
               If Typing Then
                 Status('Typing is ON: what you type goes to the caller (Ctrl-A T stops)')
               Else
                 Status('Typing is off: view only');
               End;
          'C': SendFrame(S, 'C', 0, Dummy, 0);
          'K': Begin
               AskKick := True;
               Status('Disconnect the caller?  Y / N');
               End;
          '+', '=': SendFrame(S, '+', TimeStep, Dummy, 0);
          '-', '_': SendFrame(S, '-', TimeStep, Dummy, 0);
          'X', #24: Gone := True;
          'A', #1: If Typing And (TypedN < 255) Then
                     Begin
                     Typed[TypedN] := #1;
                     Inc(TypedN);
                     End;
          '?', 'H': Status('^A: T type  C chat  K kick  + / - ' + Long2Str(TimeStep) + ' min  X leave   Ctrl-X leave');
          End;
        End
      Else If AskKick Then
        Begin
        AskKick := False;
        If UpCase(C) = 'Y' Then
          SendFrame(S, 'K', 0, Dummy, 0)
        Else
          Status('Not disconnected');
        End
      Else If C = #1 Then
        Prefix := True
      Else If C = #24 Then
        Gone := True
      Else If Typing Or ChatOn Then
        TypeByte(C);
      End;
    If Pend <> '' Then
      Begin
      Inc(PendAge);                      {a lone Esc is a key: let it go after a moment}
      If PendAge >= 2 Then
        Begin
        For k := 1 To Length(Pend) Do
          If TypedN < 255 Then
            Begin
            Typed[TypedN] := Pend[k];
            Inc(TypedN);
            End;
        Pend := '';
        End;
      End;
    If TypedN > 0 Then
      If ChatOn Then
        SendFrame(S, 'S', 0, Typed, TypedN)      {to the caller's screen, as chat}
      Else
        SendFrame(S, 'D', 0, Typed, TypedN);     {as the caller's input}
    If Not ComSession^.GetCarrier Then
      Gone := True;
    Inc(Steps);
    If BarTicks > 0 Then
      Dec(BarTicks);
    If ComSession^.WindowVersion <> BarVer Then
      Begin
      BarSize;
      BarDirty := True;
      End;
    If Steps >= 20 Then                  {look at who is on the node once a second}
      Begin
      Steps := 0;
      BarRefresh;
      End;
    If BarKey <> BarShown Then
      BarDirty := True;                  {the text changed}
    If BarDirty And (StSt = 0) Then      {never inside one of the node's escape sequences}
      Begin
      DrawBar;
      CommFlushOut;
      End;
  Until Gone;
  fpClose(S);
  Say(Esc + '[0m' + Esc + '[r' + Esc + '[2J' + Esc + '[H');
  Watch := '';
  End;


Function LocalMk: String;
  {L: the BBS in local mode (mk -L) on the node of the listener's "localnode" setting, on a pseudo terminal
   to this connection; the answer is a message (empty when it ran and ended)}
  Var
    MkPath, NodeStr, Term: String;
    Lock: LongInt;
    Code: LongInt;
    R: Word;

  Begin
  LocalMk := '';
  MkPath := GetEnv('MKMON_MK');
  NodeStr := GetEnv('MKMON_NODE');
  If (MkPath = '') Or (Str2Long(NodeStr) < 1) Then
    Begin
    LocalMk := 'The local BBS is not set up ("localnode" in the mklisten configuration).';
    Exit;
    End;
  {one local session at a time: a lock on a file in the run directory (gone with the process)}
  Lock := fpOpen(RunDir + '/local.lock', O_RDWR Or O_CREAT, 438);
  If Lock < 0 Then
    Begin
    LocalMk := 'Cannot open ' + RunDir + '/local.lock';
    Exit;
    End;
  If fpFlock(Lock, LOCK_EX Or LOCK_NB) <> 0 Then
    Begin
    fpClose(Lock);
    LocalMk := 'The local BBS is already running.';
    Exit;
    End;
  Term := ComSession^.GetTermType;
  R := PtyRun(MkPath, '-L -N' + Long2Str(Str2Long(NodeStr)), Term, Code);
  fpFlock(Lock, LOCK_UN);
  fpClose(Lock);
  Say(Esc + '[0m' + Esc + '[?25h' + Esc + '[?1049l');     {whatever the BBS left on the terminal}
  If R = ptyNoPty Then
    LocalMk := 'No pseudo terminal for the local BBS.'
  Else If R = ptyNoExec Then
    LocalMk := 'Cannot start ' + MkPath
  Else If Code <> 0 Then
    LocalMk := 'The local BBS ended with code ' + Long2Str(Code) + '.';
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
        'M': Begin
             Typed := '';
             Msg := MailerScreen(RunDir);       {the binkp mailer (mkbink), if mklisten runs it}
             ShowNodes('');
             If Msg <> '' Then
               Begin
               SayLn('');
               SayLn(Msg);
               CommFlushOut;
               Msg := '';
               End;
             End;
        'E': Begin
             Typed := '';
             Msg := EventsScreen(RunDir);       {the events mklisten runs}
             ShowNodes('');
             If Msg <> '' Then
               Begin
               SayLn('');
               SayLn(Msg);
               CommFlushOut;
               Msg := '';
               End;
             End;
        'L': Begin
             Typed := '';
             Msg := LocalMk;
             ShowNodes('');
             If Msg <> '' Then
               Begin
               SayLn('');
               SayLn(Msg);
               CommFlushOut;
               Msg := '';
               End;
             End;
        'Q', #24, #3: Exit;
        'C': If Typed <> '' Then
               Begin
               N := Str2Long(Typed);
               Typed := '';
               LoadNodes;
               Found := False;
               For i := 1 To NumNodes Do
                 If Nodes[i].Node = N Then
                   Found := True;
               If Found Then
                 Begin
                 Msg := Watch(N, True);        {asks for the chat once the window is up}
                 End
               Else
                 Msg := 'Node ' + Long2Str(N) + ' is not in use.';
               ShowNodes('');
               If Msg <> '' Then
                 Begin
                 SayLn('');
                 SayLn(Msg);
                 CommFlushOut;
                 Msg := '';
                 End;
               End;
        'K', '+', '-', '=':
             If Typed <> '' Then
               Begin
               N := Str2Long(Typed);
               Typed := '';
               LoadNodes;
               Found := False;
               For i := 1 To NumNodes Do
                 If Nodes[i].Node = N Then
                   Found := True;
               If Not Found Then
                 Msg := 'Node ' + Long2Str(N) + ' is not in use.'
               Else If UpCase(C) = 'K' Then
                 Begin
                 SayLn('');
                 Say('Disconnect node ' + Long2Str(N) + '?  Y / N ');
                 CommFlushOut;
                 If UpCase(Key(30000)) = 'Y' Then
                   Msg := NodeCommand(N, 'K', 0)
                 Else
                   Msg := 'Not disconnected';
                 End
               Else If (C = '-') Then
                 Msg := NodeCommand(N, '-', TimeStep)
               Else
                 Msg := NodeCommand(N, '+', TimeStep);
               ShowNodes('');
               SayLn('');
               SayLn(Msg);
               CommFlushOut;
               Msg := '';
               End;
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
                 Msg := Watch(N, False)
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
