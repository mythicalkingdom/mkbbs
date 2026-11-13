Unit MKComTelnet;   {Telnet protocol filter over another session}

{$I MKB.Def}

{
     TelnetComObj wraps any other session (normally an FdComObj on a TCP socket,
     but a pipe pair or MKComStd behind inetd works the same) and speaks the
     Telnet protocol to the caller:

       - Output: a data byte 255 goes out as 255 255.
       - Input: IAC commands, option negotiation and sub-negotiation are taken
         out of the data stream.  CR NUL and CR LF reach the BBS as a single CR
         (the BBS only ever expects a carriage return from the Enter key).
       - Negotiation at OpenSession, the way a BBS wants it: this side echoes
         (WILL ECHO), suppresses go-ahead (both ways) and uses 8-bit binary
         (both ways); the caller is asked for its window size (NAWS) and
         terminal type (TTYPE).
       - Options are answered with the usual rules (no negotiation loops,
         WONT / DONT for everything not supported).

     What the caller told us is kept in Cols, Rows (0 = unknown) and TermType.
     ScreenChanged is set when a NAWS or TTYPE report arrived; the owner may
     look at it now and then and clear it.

     Everything else (carrier, buffering, emulated speed, hangup) is the wrapped
     session's: a filter does no I/O of its own.
}

Interface

Uses MKComAbs;


Const
  TelIAC   = 255;
  TelDONT  = 254;
  TelDO    = 253;
  TelWONT  = 252;
  TelWILL  = 251;
  TelSB    = 250;
  TelSE    = 240;
  TelOptBinary = 0;
  TelOptEcho   = 1;
  TelOptSGA    = 3;
  TelOptTType  = 24;
  TelOptNaws   = 31;


Type TelnetComObj = Object(AbsComObj)
  Inner: AbsComPtr;                    {The wrapped session}
  OwnsInner: Boolean;                  {Done disposes it}
  HavePeek: Boolean;
  PeekCh: Char;
  AfterCR: Boolean;
  St: Byte;                            {Parser state}
  Verb: Byte;
  SbLen: Word;
  Sb: Array[0..255] Of Byte;
  Us: Array[0..255] Of Byte;           {0 off, 1 on, 2 asked and waiting}
  Him: Array[0..255] Of Byte;
  Cols, Rows: Word;                    {Caller's window, 0 = unknown}
  TermType: String[40];
  ScreenChanged: Boolean;
  WinVer: Word;                        {Counts the NAWS reports}
  Constructor Init(AInner: AbsComPtr; AOwns: Boolean);
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
  Function  SendBlock(Var Dt; DSize: Word): Word; Virtual;
  Function  GetBlock(Var Dt; DSize: Word): Word; Virtual;
  Function  WaitForChar(Ms: Word): Boolean; Virtual;
  Procedure FlushOut; Virtual;
  Procedure SetBPS(Rate: LongInt); Virtual;
  Function  GetCommInfo: String; Virtual;
  Function  GetRemoteAddr: String; Virtual;
  Procedure SetRemoteAddr(Addr: String); Virtual;
  Function  GetWindowSize(Var C, R: Word): Boolean; Virtual;
  Function  WindowVersion: Word; Virtual;
  Function  Negotiated(Opt: Byte; Mine: Boolean): Boolean;
    {Option is in force (Mine = we do it, else the caller does)}
  Procedure Fill(WaitMs: LongInt);     {Internal}
  Procedure Process(C: Char);          {Internal}
  Procedure Data(C: Char);             {Internal}
  Procedure Command(V, Opt: Byte);     {Internal: send IAC V Opt}
  Procedure Offer(Opt: Byte; Mine: Boolean); {Internal}
  Procedure GotOption(V, Opt: Byte);   {Internal}
  Procedure GotSub;                    {Internal}
  End;


Type TelnetComPtr = ^TelnetComObj;


Implementation


Uses MKPlat;


Function Supports(Opt: Byte; Mine: Boolean): Boolean;
  Begin
  If Mine Then
    Supports := Opt In [TelOptBinary, TelOptEcho, TelOptSGA]
  Else
    Supports := Opt In [TelOptBinary, TelOptSGA, TelOptTType, TelOptNaws];
  End;


Constructor TelnetComObj.Init(AInner: AbsComPtr; AOwns: Boolean);
  Begin
  Inherited Init;
  Inner := AInner;
  OwnsInner := AOwns;
  HavePeek := False;
  AfterCR := False;
  St := 0;
  Verb := 0;
  SbLen := 0;
  FillChar(Us, SizeOf(Us), 0);
  FillChar(Him, SizeOf(Him), 0);
  Cols := 0;
  Rows := 0;
  TermType := '';
  ScreenChanged := False;
  WinVer := 0;
  End;


Destructor TelnetComObj.Done;
  Begin
  If OwnsInner And (Inner <> Nil) Then
    Dispose(Inner, Done);
  Inner := Nil;
  Inherited Done;
  End;


Procedure TelnetComObj.Command(V, Opt: Byte);
  Begin
  Inner^.SendChar(Chr(TelIAC));
  Inner^.SendChar(Chr(V));
  Inner^.SendChar(Chr(Opt));
  End;


Procedure TelnetComObj.Offer(Opt: Byte; Mine: Boolean);
  Begin
  If Mine Then
    Begin
    Us[Opt] := 2;
    Command(TelWILL, Opt);
    End
  Else
    Begin
    Him[Opt] := 2;
    Command(TelDO, Opt);
    End;
  End;


Function TelnetComObj.OpenSession: Boolean;
  Begin
  HavePeek := False;
  AfterCR := False;
  St := 0;
  OpenSession := False;
  If Not Inner^.OpenSession Then
    Exit;
  OpenSession := True;
  Offer(TelOptEcho, True);
  Offer(TelOptSGA, True);
  Offer(TelOptSGA, False);
  Offer(TelOptBinary, True);
  Offer(TelOptBinary, False);
  Offer(TelOptNaws, False);
  Offer(TelOptTType, False);
  Inner^.FlushOut;
  End;


Function TelnetComObj.Negotiated(Opt: Byte; Mine: Boolean): Boolean;
  Begin
  If Mine Then
    Negotiated := Us[Opt] = 1
  Else
    Negotiated := Him[Opt] = 1;
  End;


Procedure TelnetComObj.GotOption(V, Opt: Byte);
  Begin
  Case V Of
    TelDO:
      If Supports(Opt, True) Then
        Begin
        If Us[Opt] = 0 Then
          Command(TelWILL, Opt);
        Us[Opt] := 1;
        End
      Else
        Command(TelWONT, Opt);
    TelDONT:
      Begin
      If Us[Opt] = 1 Then
        Command(TelWONT, Opt);
      Us[Opt] := 0;
      End;
    TelWILL:
      If Supports(Opt, False) Then
        Begin
        If Him[Opt] = 0 Then
          Command(TelDO, Opt);
        If Him[Opt] <> 1 Then
          Begin
          Him[Opt] := 1;
          If Opt = TelOptTType Then
            Begin                        {ask for the terminal type: IAC SB TTYPE SEND IAC SE}
            Inner^.SendChar(Chr(TelIAC));
            Inner^.SendChar(Chr(TelSB));
            Inner^.SendChar(Chr(TelOptTType));
            Inner^.SendChar(#1);
            Inner^.SendChar(Chr(TelIAC));
            Inner^.SendChar(Chr(TelSE));
            End;
          End;
        End
      Else
        Command(TelDONT, Opt);
    TelWONT:
      Begin
      If Him[Opt] = 1 Then
        Command(TelDONT, Opt);
      Him[Opt] := 0;
      End;
    End;
  End;


Procedure TelnetComObj.GotSub;
  Var
    i: Word;

  Begin
  If SbLen = 0 Then
    Exit;
  If (Sb[0] = TelOptNaws) And (SbLen >= 5) Then
    Begin
    Cols := Sb[1] * 256 + Sb[2];
    Rows := Sb[3] * 256 + Sb[4];
    Inc(WinVer);
    ScreenChanged := True;
    End
  Else If (Sb[0] = TelOptTType) And (SbLen >= 2) And (Sb[1] = 0) Then
    Begin                                {IS <name>}
    TermType := '';
    For i := 2 To SbLen - 1 Do
      If Length(TermType) < 40 Then
        TermType := TermType + Chr(Sb[i]);
    ScreenChanged := True;
    End;
  End;


Procedure TelnetComObj.Data(C: Char);
  Begin
  If AfterCR And ((C = #0) Or (C = #10)) Then
    AfterCR := False                     {CR NUL / CR LF: the second one is padding}
  Else
    Begin
    AfterCR := (C = #13);
    PeekCh := C;
    HavePeek := True;
    End;
  End;


Procedure TelnetComObj.Process(C: Char);
  Begin
  Case St Of
    0: If C = Chr(TelIAC) Then
         St := 1
       Else
         Data(C);
    1: Begin
       St := 0;
       Case Ord(C) Of
         TelIAC: Data(C);                {IAC IAC is the data byte 255}
         TelWILL, TelWONT, TelDO, TelDONT:
           Begin
           Verb := Ord(C);
           St := 2;
           End;
         TelSB:
           Begin
           SbLen := 0;
           St := 3;
           End;
         End;                            {other commands (NOP, AYT, BRK ...) are ignored}
       End;
    2: Begin
       St := 0;
       GotOption(Verb, Ord(C));
       End;
    3: If C = Chr(TelIAC) Then
         St := 4
       Else If SbLen < SizeOf(Sb) Then
         Begin
         Sb[SbLen] := Ord(C);
         Inc(SbLen);
         End;
    4: Begin
       If C = Chr(TelIAC) Then
         Begin
         If SbLen < SizeOf(Sb) Then
           Begin
           Sb[SbLen] := TelIAC;
           Inc(SbLen);
           End;
         St := 3;
         End
       Else
         Begin
         If C = Chr(TelSE) Then
           GotSub;
         St := 0;
         End;
       End;
    End;
  End;


Procedure TelnetComObj.Fill(WaitMs: LongInt);
  {Look for one data character, waiting up to WaitMs}
  Var
    Start, Left: Int64;

  Begin
  Start := MKTicks;
  While Not HavePeek Do
    Begin
    If Not Inner^.InEmpty Then
      Process(Inner^.GetChar)
    Else
      Begin
      If Not Inner^.GetCarrier Then
        Exit;
      Left := WaitMs - (MKTicks - Start);
      If Left <= 0 Then
        Exit;
      If Left > 60000 Then
        Left := 60000;
      If Not Inner^.WaitForChar(Left) Then
        If Not Inner^.GetCarrier Then
          Exit;
      End;
    End;
  End;


Procedure TelnetComObj.CloseSession;
  Begin
  Inner^.CloseSession;
  End;


Procedure TelnetComObj.Hangup;
  Begin
  HavePeek := False;
  Inner^.Hangup;
  End;


Function TelnetComObj.GetCarrier: Boolean;
  Begin
  If Not HavePeek Then
    Fill(0);
  GetCarrier := HavePeek Or Inner^.GetCarrier;
  End;


Function TelnetComObj.InEmpty: Boolean;
  Begin
  Fill(0);
  InEmpty := Not HavePeek;
  End;


Function TelnetComObj.OutReady: Boolean;
  Begin
  OutReady := Inner^.OutReady;
  End;


Function TelnetComObj.OutEmpty: Boolean;
  Begin
  OutEmpty := Inner^.OutEmpty;
  End;


Function TelnetComObj.GetChar: Char;
  Begin
  While (Not HavePeek) And Inner^.GetCarrier Do
    Fill(100);
  If HavePeek Then
    Begin
    GetChar := PeekCh;
    HavePeek := False;
    End
  Else
    GetChar := #0;
  End;


Function TelnetComObj.PeekChar: Char;
  Begin
  Fill(0);
  If HavePeek Then
    PeekChar := PeekCh
  Else
    PeekChar := #0;
  End;


Procedure TelnetComObj.SendChar(Ch: Char);
  Begin
  If Ch = Chr(TelIAC) Then
    Inner^.SendChar(Ch);                 {escaped by doubling}
  Inner^.SendChar(Ch);
  End;


Type
  TByteBlock = Array[0..$FFFE] Of Byte;


Function TelnetComObj.SendBlock(Var Dt; DSize: Word): Word;
  Var
    i: Word;

  Begin
  SendBlock := 0;
  If DSize = 0 Then
    Exit;
  For i := 0 To DSize - 1 Do
    SendChar(Chr(TByteBlock(Dt)[i]));
  SendBlock := DSize;
  End;


Function TelnetComObj.GetBlock(Var Dt; DSize: Word): Word;
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


Function TelnetComObj.WaitForChar(Ms: Word): Boolean;
  Begin
  Fill(Ms);
  WaitForChar := HavePeek;
  End;


Procedure TelnetComObj.FlushOut;
  Begin
  Inner^.FlushOut;
  End;


Procedure TelnetComObj.SetBPS(Rate: LongInt);
  Begin
  coBPS := Rate;
  Inner^.SetBPS(Rate);
  End;


Function TelnetComObj.GetCommInfo: String;
  Begin
  GetCommInfo := 'Telnet over ' + Inner^.GetCommInfo;
  End;


Function TelnetComObj.GetRemoteAddr: String;
  Begin
  GetRemoteAddr := Inner^.GetRemoteAddr;
  End;


Procedure TelnetComObj.SetRemoteAddr(Addr: String);
  Begin
  Inner^.SetRemoteAddr(Addr);
  End;


Function TelnetComObj.GetWindowSize(Var C, R: Word): Boolean;
  Begin
  C := Cols;
  R := Rows;
  GetWindowSize := (Cols > 0) And (Rows > 0);
  End;


Function TelnetComObj.WindowVersion: Word;
  Begin
  WindowVersion := WinVer;
  End;


End.
