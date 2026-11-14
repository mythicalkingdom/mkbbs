Unit MKSnoop;   {Lets the sysop watch a session: a filter that copies the output}

{$I MKB.Def}

{
     SnoopComObj wraps the caller's session (outermost, after the Telnet / WS
     filter, so what it copies is the plain terminal data the BBS sent) and
     listens on a Unix domain socket, e.g. <rundir>/node3.snoop.  A monitor
     (mkmon) that connects there receives

        1. the last Ring bytes of output, so the screen is not empty, then
        2. everything the BBS sends to the caller from then on.

     A monitor that cannot keep up (the socket is full) is dropped, the caller
     is never held up by it.

     What the monitor sends back are commands (frames):

        'D' n data(n)    n bytes typed by the sysop: they reach the BBS as if
                         the caller had typed them (n = 0..255)
        'S' n data       n bytes typed by the sysop for a chat or for answering
                         a page: kept apart (SysopKeyPressed / SysopReadKey),
                         they are not the caller's input
        'C'              the sysop asks for a chat (SnoopHandler 'C')
        'K'              disconnect the caller (hang up)
        '+' m / '-' m    give / take m minutes (1..255) of the caller's time
                         (done by SnoopHandler, which the BBS supplies)

     The answer to a command is a short text for the sysop, sent as an APC
     string  ESC _ text ESC \  among the output; the BBS can also tell all
     monitors something (SnoopNotify: "Chat started" ...) (terminals ignore it; mkmon
     takes it out).  The socket file is created with mode 0600: only the user that
     runs the BBS (and root) can attach.

     The listening socket is checked whenever the session is used, and while
     the BBS waits for the caller (GetChar and WaitForChar wait in short
     slices), so a monitor can attach to an idle node too.
}

Interface

Uses MKComAbs;

Const
  SnoopRing = 4096;
  SnoopMax  = 2;                       {Monitors at the same time}

Type
  SnoopCmdFunc = Function(Cmd: Char; Arg: LongInt): String;
    {'K' (before the hang up), 'C' (chat), '+' or '-' with minutes; returns the
     message for the sysop.  Set by the BBS, Nil = the BBS cannot do it.}

Var
  SnoopHandler: SnoopCmdFunc;


Type
  SnoopComObj = Object(AbsComObj)
    Inner: AbsComPtr;
    OwnsInner: Boolean;
    Path: String;                      {The socket file}
    ListenFd: LongInt;                   {-1 = no snooping possible}
    Clients: Array[1..SnoopMax] Of LongInt;
    Ring: Array[0..SnoopRing - 1] Of Char;
    RingPos: LongInt;                  {Total bytes ever seen}
    Tick: Word;
    Inj: Array[0..255] Of Char;        {typed by the sysop, not yet read}
    InjHead, InjCount: Word;
    Sys: Array[0..255] Of Char;        {typed by the sysop for a chat / page}
    SysHead, SysCount: Word;
    InChat: Boolean;                   {a chat is going on (a monitor that comes later is told)}
    CSt: Array[1..SnoopMax] Of Byte;   {frame parser of each monitor}
    CTag: Array[1..SnoopMax] Of Char;
    CLen: Array[1..SnoopMax] Of Byte;
    Constructor Init(AInner: AbsComPtr; AOwns: Boolean; SockPath: String);
    Destructor Done; Virtual;
    Function  OpenSession: Boolean; Virtual;
    Procedure CloseSession; Virtual;
    Procedure Hangup; Virtual;
    Function  GetCarrier: Boolean; Virtual;
    Function  InEmpty: Boolean; Virtual;
    Function  OutReady: Boolean; Virtual;
    Function  OutEmpty: Boolean; Virtual;
    Function  GetChar: Char; Virtual;
    Function  PeekChar: Char; Virtual;
    Procedure SendChar(Ch: Char); Virtual;
    Function  SendCharNW(Ch: Char): Boolean; Virtual;
    Function  SendBlock(Var Dt; DSize: Word): Word; Virtual;
    Function  GetBlock(Var Dt; DSize: Word): Word; Virtual;
    Function  WaitForChar(Ms: Word): Boolean; Virtual;
    Procedure SendStr(Str: String); Virtual;
    Procedure FlushIn; Virtual;
    Procedure FlushOut; Virtual;
    Procedure SetBPS(Rate: LongInt); Virtual;
    Function  GetBPS: LongInt; Virtual;
    Function  GetCommInfo: String; Virtual;
    Function  GetRemoteAddr: String; Virtual;
    Function  GetTermType: String; Virtual;
    Procedure SetRemoteAddr(Addr: String); Virtual;
    Function  GetWindowSize(Var C, R: Word): Boolean; Virtual;
    Function  WindowVersion: Word; Virtual;
    Function  Watchers: Word;          {Monitors attached now}
    Procedure Accept;                  {Internal: take a waiting monitor, read commands}
    Procedure ReadCmds;                {Internal}
    Procedure Feed(i: Word; B: Byte);  {Internal: one command byte}
    Procedure Command(i: Word; Cmd: Char; Arg: LongInt); {Internal}
    Procedure Reply(i: Word; Msg: String); {Internal}
    Function  InjPop: Char;            {Internal}
    Procedure Copy2(Var Dt; DSize: Word);   {Internal: record and forward}
    End;

  SnoopComPtr = ^SnoopComObj;

Var
  ActiveSnoop: SnoopComPtr;            {the session of this process, Nil without one}


Function  SysopKeyPressed: Boolean;    {The sysop typed a key for the chat / the page}
Function  SysopReadKey: Char;          {It (#0 when there is none)}
Procedure SysopFlushKeys;
Procedure SnoopNotify(Msg: String);    {Tell the monitors (shown in their bar)}


Implementation

Uses BaseUnix, Sockets;


Type
  TByteBlock = Array[0..$FFFE] Of Byte;


Constructor SnoopComObj.Init(AInner: AbsComPtr; AOwns: Boolean; SockPath: String);
  Var
    A: TUnixSockAddr;
    i: Word;
    OldMask: TMode;

  Begin
  Inherited Init;
  Inner := AInner;
  OwnsInner := AOwns;
  Path := SockPath;
  ListenFd := -1;
  RingPos := 0;
  Tick := 0;
  InjHead := 0;
  InjCount := 0;
  SysHead := 0;
  SysCount := 0;
  InChat := False;
  ActiveSnoop := @Self;
  For i := 1 To SnoopMax Do
    Begin
    Clients[i] := -1;
    CSt[i] := 0;
    End;
  If (Path = '') Or (Length(Path) > 100) Then
    Exit;
  ListenFd := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  If ListenFd < 0 Then
    Begin
    ListenFd := -1;
    Exit;
    End;
  FillChar(A, SizeOf(A), 0);
  A.family := AF_UNIX;
  Move(Path[1], A.path, Length(Path));
  fpUnlink(Path);                      {left behind by a node that died}
  OldMask := fpUmask($7F);
  If fpBind(ListenFd, @A, SizeOf(A)) <> 0 Then
    Begin
    fpUmask(OldMask);
    fpClose(ListenFd);
    ListenFd := -1;
    Exit;
    End;
  fpUmask(OldMask);
  fpChmod(Path, $180);
  fpFcntl(ListenFd, F_SetFl, fpFcntl(ListenFd, F_GetFl) Or O_NONBLOCK);
  If fpListen(ListenFd, 2) <> 0 Then
    Begin
    fpClose(ListenFd);
    fpUnlink(Path);
    ListenFd := -1;
    End;
  End;


Destructor SnoopComObj.Done;
  Var
    i: Word;

  Begin
  If ActiveSnoop = @Self Then
    ActiveSnoop := Nil;
  For i := 1 To SnoopMax Do
    If Clients[i] >= 0 Then
      fpClose(Clients[i]);
  If ListenFd >= 0 Then
    Begin
    fpClose(ListenFd);
    fpUnlink(Path);
    End;
  If OwnsInner And (Inner <> Nil) Then
    Dispose(Inner, Done);
  End;


Function SnoopComObj.Watchers: Word;
  Var
    i, N: Word;

  Begin
  N := 0;
  For i := 1 To SnoopMax Do
    If Clients[i] >= 0 Then
      Inc(N);
  Watchers := N;
  End;


Procedure Put(Var C: LongInt; Var Dt; N: LongInt);
  {Send everything or drop the monitor}
  Var
    P: PChar;
    R: LongInt;

  Begin
  P := @Dt;
  While (N > 0) And (C >= 0) Do
    Begin
    R := fpSend(C, P, N, MSG_NOSIGNAL);
    If R <= 0 Then
      Begin
      fpClose(C);
      C := -1;
      End
    Else
      Begin
      Inc(P, R);
      Dec(N, R);
      End;
    End;
  End;


Procedure SnoopComObj.Accept;
  Var
    C: LongInt;
    i: Word;
    N, Start, k: LongInt;
    Block: Array[0..SnoopRing - 1] Of Char;

  Begin
  If ListenFd < 0 Then
    Exit;
  ReadCmds;
  C := fpAccept(ListenFd, Nil, Nil);
  If C < 0 Then
    Exit;
  i := 1;
  While (i <= SnoopMax) And (Clients[i] >= 0) Do
    Inc(i);
  If i > SnoopMax Then
    Begin
    fpClose(C);
    Exit;
    End;
  fpFcntl(C, F_SetFl, fpFcntl(C, F_GetFl) Or O_NONBLOCK);
  Clients[i] := C;
  CSt[i] := 0;
  {the recent output, from the start of a line when the ring has wrapped}
  If RingPos < SnoopRing Then
    Begin
    N := RingPos;
    Start := 0;
    End
  Else
    Begin
    N := SnoopRing;
    Start := RingPos Mod SnoopRing;
    End;
  For k := 0 To N - 1 Do
    Block[k] := Ring[(Start + k) Mod SnoopRing];
  k := 0;
  If RingPos >= SnoopRing Then
    Begin
    While (k < N) And (Block[k] <> #10) Do
      Inc(k);
    If k < N Then
      Inc(k)
    Else
      k := 0;
    End;
  If N - k > 0 Then
    Put(Clients[i], Block[k], N - k);
  If InChat Then
    Reply(i, 'Chat started: type to the caller, Esc ends');
  End;


Procedure SnoopComObj.Reply(i: Word; Msg: String);
  Begin
  If Clients[i] >= 0 Then
    Begin
    Msg := #27'_' + Msg + #27'\';
    Put(Clients[i], Msg[1], Length(Msg));
    End;
  End;


Function SnoopComObj.InjPop: Char;
  Begin
  InjPop := Inj[InjHead];
  InjHead := (InjHead + 1) And 255;
  Dec(InjCount);
  End;


Procedure SnoopComObj.Command(i: Word; Cmd: Char; Arg: LongInt);
  Var
    Msg: String;

  Begin
  Msg := '';
  Case Cmd Of
    'K': Begin
         If @SnoopHandler <> Nil Then
           Msg := SnoopHandler(Cmd, Arg);
         If Msg = '' Then
           Msg := 'Disconnected';
         Reply(i, Msg);
         Inner^.SendStr(#13#10'You have been disconnected by the sysop.'#13#10);
         Inner^.FlushOut;
         Inner^.Hangup;
         End;
    'C': Begin
         If @SnoopHandler <> Nil Then
           Msg := SnoopHandler(Cmd, Arg)
         Else
           Msg := 'This BBS cannot chat';
         Reply(i, Msg);
         End;
    '+', '-': Begin
              If @SnoopHandler <> Nil Then
                Msg := SnoopHandler(Cmd, Arg)
              Else
                Msg := 'This BBS cannot change the time';
              Reply(i, Msg);
              End;
    End;
  End;


Procedure SnoopComObj.Feed(i: Word; B: Byte);
  Begin
  Case CSt[i] Of
    0: Begin                           {a command letter}
       CTag[i] := Chr(B);
       Case CTag[i] Of
         'D', 'S': CSt[i] := 1;
         '+', '-': CSt[i] := 3;
         'K': Command(i, 'K', 0);
         'C': Command(i, 'C', 0);
         End;
       End;
    1: Begin                           {length of the typed text}
       CLen[i] := B;
       If B = 0 Then
         CSt[i] := 0
       Else
         CSt[i] := 2;
       End;
    2: Begin                           {typed text}
       If CTag[i] = 'S' Then
         Begin
         If SysCount < 256 Then
           Begin
           Sys[(SysHead + SysCount) And 255] := Chr(B);
           Inc(SysCount);
           End;
         End
       Else If InjCount < 256 Then
         Begin
         Inj[(InjHead + InjCount) And 255] := Chr(B);
         Inc(InjCount);
         End;
       Dec(CLen[i]);
       If CLen[i] = 0 Then
         CSt[i] := 0;
       End;
    3: Begin                           {minutes}
       CSt[i] := 0;
       If B > 0 Then
         Command(i, CTag[i], B);
       End;
    End;
  End;


Procedure SnoopComObj.ReadCmds;
  Var
    i: Word;
    N, k: LongInt;
    Buf: Array[0..255] Of Byte;

  Begin
  For i := 1 To SnoopMax Do
    If Clients[i] >= 0 Then
      Begin
      N := fpRecv(Clients[i], @Buf, SizeOf(Buf), MSG_NOSIGNAL);
      If N = 0 Then
        Begin
        fpClose(Clients[i]);               {the monitor left}
        Clients[i] := -1;
        End
      Else If N > 0 Then
        For k := 0 To N - 1 Do
          Feed(i, Buf[k]);
      End;
  End;


Procedure SnoopComObj.Copy2(Var Dt; DSize: Word);
  Var
    i: Word;
    k: LongInt;

  Begin
  If ListenFd < 0 Then
    Exit;
  For k := 0 To DSize - 1 Do
    Begin
    Ring[RingPos Mod SnoopRing] := Chr(TByteBlock(Dt)[k]);
    Inc(RingPos);
    End;
  For i := 1 To SnoopMax Do
    If Clients[i] >= 0 Then
      Put(Clients[i], Dt, DSize);
  End;


Function SnoopComObj.OpenSession: Boolean;
  Begin
  OpenSession := Inner^.OpenSession;
  End;


Procedure SnoopComObj.CloseSession;
  Begin
  Inner^.CloseSession;
  End;


Procedure SnoopComObj.Hangup;
  Begin
  Inner^.Hangup;
  End;


Function SnoopComObj.GetCarrier: Boolean;
  Begin
  Accept;
  GetCarrier := Inner^.GetCarrier;
  End;


Function SnoopComObj.InEmpty: Boolean;
  Begin
  Accept;
  InEmpty := (InjCount = 0) And Inner^.InEmpty;
  End;


Function SnoopComObj.OutReady: Boolean;
  Begin
  OutReady := Inner^.OutReady;
  End;


Function SnoopComObj.OutEmpty: Boolean;
  Begin
  OutEmpty := Inner^.OutEmpty;
  End;


Function SnoopComObj.GetChar: Char;
  Begin
  GetChar := #0;
  Repeat
    Accept;
    If InjCount > 0 Then
      Begin
      GetChar := InjPop;
      Exit;
      End;
    If Inner^.WaitForChar(50) Then
      Begin
      GetChar := Inner^.GetChar;
      Exit;
      End;
  Until Not Inner^.GetCarrier;
  End;


Function SnoopComObj.PeekChar: Char;
  Begin
  Accept;
  If InjCount > 0 Then
    PeekChar := Inj[InjHead]
  Else
    PeekChar := Inner^.PeekChar;
  End;


Procedure SnoopComObj.SendChar(Ch: Char);
  Begin
  Inc(Tick);
  If (Tick And 63) = 0 Then
    Accept;
  Copy2(Ch, 1);
  Inner^.SendChar(Ch);
  End;


Function SnoopComObj.SendCharNW(Ch: Char): Boolean;
  Var
    Ok: Boolean;

  Begin
  Ok := Inner^.SendCharNW(Ch);
  If Ok Then
    Copy2(Ch, 1);
  SendCharNW := Ok;
  End;


Function SnoopComObj.SendBlock(Var Dt; DSize: Word): Word;
  Var
    N: Word;

  Begin
  Accept;
  N := Inner^.SendBlock(Dt, DSize);
  If N > 0 Then
    Copy2(Dt, N);
  SendBlock := N;
  End;


Function SnoopComObj.GetBlock(Var Dt; DSize: Word): Word;
  Var
    N: Word;

  Begin
  N := 0;
  While (N < DSize) And (Not InEmpty) Do
    Begin
    TByteBlock(Dt)[N] := Ord(GetChar);
    Inc(N);
    End;
  GetBlock := N;
  End;


Function SnoopComObj.WaitForChar(Ms: Word): Boolean;
  Var
    T: Word;

  Begin
  WaitForChar := False;
  Repeat
    Accept;
    If InjCount > 0 Then
      Begin
      WaitForChar := True;
      Exit;
      End;
    If Ms > 50 Then
      T := 50
    Else
      T := Ms;
    If Inner^.WaitForChar(T) Then
      Begin
      WaitForChar := True;
      Exit;
      End;
    Dec(Ms, T);
  Until (Ms = 0) Or (Not Inner^.GetCarrier);
  End;


Procedure SnoopComObj.SendStr(Str: String);
  Begin
  If Length(Str) > 0 Then
    SendBlock(Str[1], Length(Str));
  End;


Procedure SnoopComObj.FlushIn;
  Begin
  InjCount := 0;
  Inner^.FlushIn;
  End;


Procedure SnoopComObj.FlushOut;
  Begin
  Inner^.FlushOut;
  End;


Procedure SnoopComObj.SetBPS(Rate: LongInt);
  Begin
  coBPS := Rate;
  Inner^.SetBPS(Rate);
  End;


Function SnoopComObj.GetBPS: LongInt;
  Begin
  GetBPS := Inner^.GetBPS;
  End;


Function SnoopComObj.GetCommInfo: String;
  Begin
  GetCommInfo := Inner^.GetCommInfo;
  End;


Function SnoopComObj.GetTermType: String;
  Begin
  GetTermType := Inner^.GetTermType;
  End;


Function SnoopComObj.GetRemoteAddr: String;
  Begin
  GetRemoteAddr := Inner^.GetRemoteAddr;
  End;


Procedure SnoopComObj.SetRemoteAddr(Addr: String);
  Begin
  Inner^.SetRemoteAddr(Addr);
  End;


Function SnoopComObj.GetWindowSize(Var C, R: Word): Boolean;
  Begin
  GetWindowSize := Inner^.GetWindowSize(C, R);
  End;


Function SnoopComObj.WindowVersion: Word;
  Begin
  WindowVersion := Inner^.WindowVersion;
  End;



Function SysopKeyPressed: Boolean;
  Begin
  SysopKeyPressed := False;
  If ActiveSnoop = Nil Then
    Exit;
  If ActiveSnoop^.SysCount = 0 Then
    ActiveSnoop^.Accept;               {the monitor's keys may be waiting on the socket}
  SysopKeyPressed := ActiveSnoop^.SysCount > 0;
  End;


Function SysopReadKey: Char;
  Begin
  SysopReadKey := #0;
  If ActiveSnoop = Nil Then
    Exit;
  With ActiveSnoop^ Do
    If SysCount > 0 Then
      Begin
      SysopReadKey := Sys[SysHead];
      SysHead := (SysHead + 1) And 255;
      Dec(SysCount);
      End;
  End;


Procedure SysopFlushKeys;
  Begin
  If ActiveSnoop <> Nil Then
    ActiveSnoop^.SysCount := 0;
  End;


Procedure SnoopNotify(Msg: String);
  Var
    i: Word;

  Begin
  If ActiveSnoop = Nil Then
    Exit;
  If Copy(Msg, 1, 12) = 'Chat started' Then
    ActiveSnoop^.InChat := True
  Else If Copy(Msg, 1, 10) = 'Chat ended' Then
    ActiveSnoop^.InChat := False;
  With ActiveSnoop^ Do
    For i := 1 To SnoopMax Do
      If Clients[i] >= 0 Then
        Reply(i, Msg);
  End;


Begin
SnoopHandler := Nil;
ActiveSnoop := Nil;
End.
