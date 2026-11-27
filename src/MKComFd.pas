{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKComFd;   {Comm session on a pair of file descriptors (socket, pipe, pty)}

{$I MKB.Def}

{
     The base of every session that is "just a stream of bytes":
       - a TCP socket handed over by the listener or by inetd,
       - a pipe pair, a pty, standard input/output (MKComStd derives from this).

     Nothing here speaks any protocol.  Telnet, WebSocket and so on are filters
     that wrap a session (see MKComTelnet), so they work the same behind the
     listener, inetd or a test pipe.

     Output is buffered and goes out when the buffer fills, when the BBS waits
     for input, or on FlushOut.  The caller is "gone" when the input reaches end
     of file or a write fails.

     EMULATED SPEED: SetPace(Rate) limits output to Rate bits per second (10 bits
     per character, like a modem with start and stop bits).  0 means full speed.
     The limit is applied when the buffer is written, in small steps, so a key
     pressed during a long screen is noticed within about 100 ms of output.
}

Interface

Uses MKComAbs;


Type
  TlsReadFn = Function(Conn: Pointer; Buf: Pointer; N: LongInt): LongInt;   {n bytes; 0 closed; -1 failed; -2 try again}
  TlsWriteFn = Function(Conn: Pointer; Buf: Pointer; N: LongInt): LongInt;  {n bytes; -1 failed; -2 try again}
  TlsPendFn = Function(Conn: Pointer): LongInt;                             {bytes already decrypted and waiting}
  TlsFreeFn = Procedure(Conn: Pointer);

Type FdComObj = Object(AbsComObj)
  InFd: LongInt;                       {Descriptor to read from (-1: none)}
  OutFd: LongInt;                      {Descriptor to write to}
  CloseFds: Boolean;                   {Hangup closes the descriptors}
  Up: Boolean;                         {Caller still there}
  HavePeek: Boolean;
  PeekCh: Char;
  Pace: LongInt;                       {Emulated bits per second, 0 = none}
  PaceDue: Int64;                      {MKTicks when the emulated line is free}
  RemoteAddr: String[64];              {Caller's address, if the owner knows it}
  Tls: Pointer;                        {Nil, or the TLS connection that the descriptors carry: the four functions below do the reading and writing}
  TlsRd: TlsReadFn;
  TlsWr: TlsWriteFn;
  TlsPend: TlsPendFn;
  TlsFree: TlsFreeFn;
  OutLen: Word;
  OutBuf: Array[0..4095] Of Char;
  Constructor Init;
  Constructor InitFd(AIn, AOut: LongInt);
  Procedure SetPace(Rate: LongInt);
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
  Function  SendBlock(Var Dt; DSize: Word): Word; Virtual;
  Function  GetBlock(Var Dt; DSize: Word): Word; Virtual;
  Function  WaitForChar(Ms: Word): Boolean; Virtual;
  Procedure FlushOut; Virtual;
  Procedure SetBPS(Rate: LongInt); Virtual;
  Function  GetCommInfo: String; Virtual;
  Function  GetRemoteAddr: String; Virtual;
  Procedure SetRemoteAddr(Addr: String); Virtual;
  Procedure Fill(WaitMs: LongInt);     {Internal: try to read one character}
  Procedure PutOut;                    {Internal: write the output buffer}
  Procedure DropFds;                   {Internal: close the descriptors}
  End;


Type FdComPtr = ^FdComObj;


Implementation


{$IFDEF UNIX}

Uses BaseUnix, Sockets, MKPlat;


Constructor FdComObj.Init;
  Begin
  InitFd(-1, -1);
  End;


Constructor FdComObj.InitFd(AIn, AOut: LongInt);
  Begin
  Inherited Init;
  InFd := AIn;
  OutFd := AOut;
  CloseFds := True;
  Up := (AIn >= 0) And (AOut >= 0);
  HavePeek := False;
  Pace := 0;
  PaceDue := 0;
  RemoteAddr := '';
  Tls := Nil;
  OutLen := 0;
  fpSignal(SIGPIPE, SignalHandler(SIG_IGN));   {a dropped caller is an error code, not a kill}
  End;


Procedure FdComObj.SetPace(Rate: LongInt);
  Begin
  If Rate < 0 Then
    Rate := 0;
  Pace := Rate;
  PaceDue := 0;
  End;


Procedure FdComObj.SetBPS(Rate: LongInt);
  Begin
  coBPS := Rate;
  SetPace(Rate);
  End;


Function FdComObj.OpenSession: Boolean;
  Begin
  HavePeek := False;
  OpenSession := Up;
  End;


Procedure FdComObj.CloseSession;
  Begin
  FlushOut;
  End;


Procedure FdComObj.DropFds;
  Begin
  If Tls <> Nil Then
    Begin
    TlsFree(Tls);
    Tls := Nil;
    End;
  If CloseFds Then
    Begin
    If OutFd >= 0 Then
      Begin
      fpShutdown(OutFd, 2);              {sockets: tell the peer; harmless otherwise}
      fpClose(OutFd);
      End;
    If (InFd >= 0) And (InFd <> OutFd) Then
      fpClose(InFd);
    InFd := -1;
    OutFd := -1;
    End;
  End;


Procedure FdComObj.Hangup;
  Begin
  FlushOut;
  Up := False;
  HavePeek := False;
  DropFds;
  End;


Procedure FdComObj.PutOut;
  Var
    Sent: Word;
    N: LongInt;
    Chunk: LongInt;
    Now: Int64;

  Begin
  Sent := 0;
  While (Sent < OutLen) And Up Do
    Begin
    Chunk := OutLen - Sent;
    If Pace > 0 Then
      Begin
      If Chunk > (Pace Div 200) + 1 Then
        Chunk := (Pace Div 200) + 1;     {about 50 ms of output per write}
      Now := MKTicks;
      If PaceDue < Now Then
        PaceDue := Now;                  {the line was idle}
      If PaceDue - Now > 50 Then
        MKDelay(PaceDue - Now - 50);
      End;
    If Tls <> Nil Then
      N := TlsWr(Tls, @OutBuf[Sent], Chunk)
    Else
      N := fpWrite(OutFd, OutBuf[Sent], Chunk);
    If N > 0 Then
      Begin
      Inc(Sent, N);
      If Pace > 0 Then
        Inc(PaceDue, (N * 10000) Div Pace);
      End
    Else If (Tls <> Nil) And (N = -2) Then
      MKDelay(5)
    Else If (Tls = Nil) And (N < 0) And (fpGetErrno = ESysEINTR) Then
      Continue
    Else If (Tls = Nil) And (N < 0) And (fpGetErrno = ESysEAGAIN) Then
      MKDelay(5)
    Else
      Up := False;                       {broken pipe/socket: the caller dropped}
    End;
  OutLen := 0;
  End;


Procedure FdComObj.Fill(WaitMs: LongInt);
  {Look for one input character, waiting up to WaitMs}
  Var
    P: TPollFd;
    R: cInt;
    N: LongInt;
    C: Char;

  Begin
  If HavePeek Or (Not Up) Then
    Exit;
  If OutLen > 0 Then
    PutOut;
  If InFd < 0 Then
    Begin
    Up := False;
    Exit;
    End;
  If (Tls = Nil) Or (TlsPend(Tls) <= 0) Then
    Begin                                {(TLS: a character may already be decrypted and waiting: the descriptor shows nothing then)}
    P.fd := InFd;
    P.events := POLLIN;
    P.revents := 0;
    R := fpPoll(@P, 1, WaitMs);
    If R <= 0 Then
      Exit;
    If (P.revents And (POLLIN Or POLLHUP Or POLLERR)) = 0 Then
      Exit;
    End;
  If Tls <> Nil Then
    N := TlsRd(Tls, @C, 1)
  Else
    N := fpRead(InFd, C, 1);
  If (Tls <> Nil) And (N = -2) Then
    Exit
  Else If N = 1 Then
    Begin
    PeekCh := C;
    HavePeek := True;
    End
  Else If N = 0 Then
    Up := False                          {end of file: the caller hung up}
  Else If Tls <> Nil Then
    Up := False                          {TLS: a failed read}
  Else If (fpGetErrno <> ESysEINTR) And (fpGetErrno <> ESysEAGAIN) Then
    Up := False;
  End;


Function FdComObj.GetCarrier: Boolean;
  Begin
  If Up And (Not HavePeek) Then
    Fill(0);                             {notice an end of file}
  GetCarrier := Up;
  End;


Function FdComObj.InEmpty: Boolean;
  Begin
  Fill(0);
  InEmpty := Not HavePeek;
  End;


Function FdComObj.OutReady: Boolean;
  Begin
  OutReady := Up;
  End;


Function FdComObj.OutEmpty: Boolean;
  Begin
  PutOut;
  OutEmpty := True;
  End;


Function FdComObj.GetChar: Char;
  Begin
  While (Not HavePeek) And Up Do
    Fill(100);
  If HavePeek Then
    Begin
    GetChar := PeekCh;
    HavePeek := False;
    End
  Else
    GetChar := #0;
  End;


Function FdComObj.PeekChar: Char;
  Begin
  Fill(0);
  If HavePeek Then
    PeekChar := PeekCh
  Else
    PeekChar := #0;
  End;


Procedure FdComObj.SendChar(Ch: Char);
  Var
    Limit: LongInt;

  Begin
  If Not Up Then
    Exit;
  Limit := SizeOf(OutBuf);
  If (Pace > 0) And (Limit > (Pace Div 100) + 1) Then
    Limit := (Pace Div 100) + 1;         {keep about 100 ms of output buffered}
  If OutLen >= Limit Then
    PutOut;
  If Not Up Then
    Exit;
  OutBuf[OutLen] := Ch;
  Inc(OutLen);
  End;


Type
  TByteBlock = Array[0..$FFFE] Of Byte;


Function FdComObj.SendBlock(Var Dt; DSize: Word): Word;
  Var
    i: Word;

  Begin
  If (Not Up) Or (DSize = 0) Then
    Begin
    SendBlock := 0;
    Exit;
    End;
  For i := 0 To DSize - 1 Do
    SendChar(Chr(TByteBlock(Dt)[i]));
  SendBlock := DSize;
  End;


Function FdComObj.GetBlock(Var Dt; DSize: Word): Word;
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


Function FdComObj.WaitForChar(Ms: Word): Boolean;
  Begin
  Fill(Ms);
  WaitForChar := HavePeek;
  End;


Procedure FdComObj.FlushOut;
  Begin
  PutOut;
  End;


Function FdComObj.GetCommInfo: String;
  Begin
  GetCommInfo := 'Stream session';
  End;


Function FdComObj.GetRemoteAddr: String;
  Begin
  GetRemoteAddr := RemoteAddr;
  End;


Procedure FdComObj.SetRemoteAddr(Addr: String);
  Begin
  RemoteAddr := Addr;
  End;

{$ELSE}
{$ERROR MKComFd needs Unix file descriptors}
{$ENDIF}


End.
