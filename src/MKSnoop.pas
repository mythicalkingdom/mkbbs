Unit MKSnoop;   {Lets the sysop watch a session: a filter that copies the output}

{$I MKB.Def}

{
     SnoopComObj wraps the caller's session (outermost, after the Telnet / WS
     filter, so what it copies is the plain terminal data the BBS sent) and
     listens on a Unix domain socket, e.g. <rundir>/node3.snoop.  A monitor
     (mkmon) that connects there receives

        1. the last Ring bytes of output, so the screen is not empty, then
        2. everything the BBS sends to the caller from then on.

     View only: whatever the monitor sends back is never read.  A monitor that
     cannot keep up (the socket is full) is dropped, the caller is never held
     up by it.  The socket file is created with mode 0600: only the user that
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
  SnoopComObj = Object(AbsComObj)
    Inner: AbsComPtr;
    OwnsInner: Boolean;
    Path: String;                      {The socket file}
    ListenFd: LongInt;                   {-1 = no snooping possible}
    Clients: Array[1..SnoopMax] Of LongInt;
    Ring: Array[0..SnoopRing - 1] Of Char;
    RingPos: LongInt;                  {Total bytes ever seen}
    Tick: Word;
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
    Procedure SetRemoteAddr(Addr: String); Virtual;
    Function  GetWindowSize(Var C, R: Word): Boolean; Virtual;
    Function  WindowVersion: Word; Virtual;
    Function  Watchers: Word;          {Monitors attached now}
    Procedure Accept;                  {Internal: take a waiting monitor}
    Procedure Copy2(Var Dt; DSize: Word);   {Internal: record and forward}
    End;

  SnoopComPtr = ^SnoopComObj;


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
  For i := 1 To SnoopMax Do
    Clients[i] := -1;
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
  InEmpty := Inner^.InEmpty;
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
  While (Not Inner^.WaitForChar(200)) And Inner^.GetCarrier Do
    Accept;
  GetChar := Inner^.GetChar;
  End;


Function SnoopComObj.PeekChar: Char;
  Begin
  Accept;
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
  Begin
  GetBlock := Inner^.GetBlock(Dt, DSize);
  End;


Function SnoopComObj.WaitForChar(Ms: Word): Boolean;
  Var
    T: Word;

  Begin
  WaitForChar := False;
  Repeat
    Accept;
    If Ms > 200 Then
      T := 200
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


End.
