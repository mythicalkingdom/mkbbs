Unit MKComAbs;  {Abstract comm session object - replaces MKFossil}

{$I MKB.Def}

{
     MKComAbs - Copyright 1993 by Mark May - MK Software
     You are free to use this code in your programs, however
     it may not be included in Source/TPU function libraries
     without my permission.

     Mythical Kingom Tech BBS (513)237-7737 HST/v32
     FidoNet: 1:110/290
     Rime: ->MYTHKING
     You may also reach me at maym@dmapub.dma.org
}

{
     MKFossil talked to a modem through the FOSSIL driver (INT 14h) or the
     IBMCOM direct UART code.  This unit replaces it for the new version, where
     a caller arrives as a SESSION: a Telnet connection, an SSH channel, the
     standard input/output of a process started by inetd, a local console...

     AbsComObj is the abstract session.  Descendants (one unit each, e.g.
     MKComTel, MKComSsh, MKComStd) override the virtual methods; the rest of
     the BBS only ever talks to an AbsComObj.

     The method names follow the earlier AbsComObj of the MK source (GetCarrier,
     InEmpty, OutReady, SendChar, LowerDTR ...) so the units written against it
     (MKUsrAbs and the others) compile unchanged.  The modem methods are kept
     as harmless virtuals: LowerDTR hangs up, OpenPort / ClosePort / CommResume
     open and close the session, flow control, break and baud do nothing but
     remember the value.  FOSSIL / direct detection (ComType, CommForce) and the
     FOSSIL info block are gone.

     Names of the old procedural calls that still make sense are kept as thin
     wrappers on the current session (ComSession), so old code only needs
     "Uses MKComAbs" instead of "Uses MKFossil":

         MKFossil            MKComAbs
         CommInit            CommInit          (ComSession^.OpenSession)
         CommRelease         CommRelease       (ComSession^.CloseSession)
         CommCarrier         CommCarrier       (ComSession^.GetCarrier)
         CommRecv/CommPeek   CommRecv/CommPeek
         CommSend/CommSendNW CommSend/CommSendNW
         CommInEmpty         CommInEmpty
         CommOutReady        CommOutReady
         CommOutEmpty        CommOutEmpty
         CommFlushIn/Out     CommFlushIn/CommFlushOut
         GetCommInfo         GetCommInfo
         LowerDTR (hang up)  CommHangup        (ComSession^.Hangup)
         RaiseDTR            RaiseDTR          (does nothing)
         CommSetBaud         CommSetBaud       (only records CurrentRate)
         CurrentRate         CurrentRate       (nominal speed, default 38400)
         CurrentPort         CurrentPort       (0 = local mode, else remote;
                                                no longer a port number)
         CurrentPort > 0     CommActive        (session attached, not local)
         CommFlow/Break      CommFlow/CommStartBreak/CommStopBreak (no-ops)
     LowerDTR and the other modem leftovers are kept only so old code
     compiles; new code should use CommHangup / the session methods.

     Without a session (ComSession = Nil) the wrappers are safe: nothing is
     connected, nothing to read, sends are dropped.
}


Interface


Const
  fcNone = 0;
  fcSoft = 1;
  fcHard = 2;
  fcBoth = fcSoft + fcHard;


Type AbsComObj = Object
  coBPS: LongInt;                      {Nominal connect speed, informational}
  coPort: Byte;                        {Remembered, not used}
  coFlow: Byte;
  coNumBits: Byte;
  coStopBits: Byte;
  coParity: Byte;
  Constructor Init;
  Destructor Done; Virtual;
  Function  OpenSession: Boolean; Virtual;      {Start / attach the session}
  Procedure CloseSession; Virtual;              {Release it (stay connected)}
  Procedure Hangup; Virtual;                    {Disconnect the caller}
  Function  GetCarrier: Boolean; Virtual;       {Caller is still there}
  Function  Connected: Boolean;                 {Same, shorter}
  Function  OpenPort(PortNo: Byte; Baud: LongInt; Flow: Byte; NumBits: Byte;
    StopBits: Byte; Parity: Byte): Boolean; Virtual;  {= OpenSession}
  Procedure ClosePort; Virtual;                 {= CloseSession}
  Procedure CommResume; Virtual;                {= OpenSession again}
  Function  GetCommPort: Integer;
  Procedure LowerDTR; Virtual;                  {= Hangup}
  Procedure RaiseDTR; Virtual;                  {Nothing to raise}
  Procedure SetFlowCtl(FC: Byte); Virtual;      {Remembered only}
  Procedure StartBreak; Virtual;
  Procedure StopBreak; Virtual;
  Function  GetInfo: String; Virtual;
  Function  InEmpty: Boolean; Virtual;          {Nothing waiting to be read}
  Function  OutReady: Boolean; Virtual;         {A character can be sent now}
  Function  OutEmpty: Boolean; Virtual;         {Everything sent has left}
  Function  GetChar: Char; Virtual;             {Next character (waits)}
  Function  PeekChar: Char; Virtual;            {Next character, not removed}
  Procedure SendChar(Ch: Char); Virtual;        {Send (waits)}
  Function  SendCharNW(Ch: Char): Boolean; Virtual; {Send, no wait}
  Function  SendBlock(Var Dt; DSize: Word): Word; Virtual;
    {Send DSize bytes, returns how many were sent}
  Function  GetBlock(Var Dt; DSize: Word): Word; Virtual;
    {Read up to DSize bytes that are waiting, returns how many; no waiting}
  Function  WaitForChar(Ms: Word): Boolean; Virtual;
    {Wait up to Ms milliseconds for a character; False on timeout/disconnect}
  Procedure SendStr(Str: String); Virtual;      {Send a string}
  Procedure FlushIn; Virtual;                   {Throw away unread input}
  Procedure FlushOut; Virtual;                  {Wait until output has left}
  Function  GetBPS: LongInt; Virtual;
  Procedure SetBPS(Rate: LongInt); Virtual;
  Function  GetCommInfo: String; Virtual;       {Describes the session}
  Function  GetRemoteAddr: String; Virtual;     {Caller's address, if known}
  Procedure SetRemoteAddr(Addr: String); Virtual; {Owner tells the address (listener, PROXY header)}
  Function  GetWindowSize(Var Cols, Rows: Word): Boolean; Virtual;
    {True when the caller's terminal has reported its size (Telnet NAWS ...)}
  Function  WindowVersion: Word; Virtual;       {Changes whenever a new size arrives}
  End;


Type AbsComPtr = ^AbsComObj;


Var
  ComSession: AbsComPtr;               {The current session}
  CurrentPort: Byte;                   {0 = local mode (no caller), else remote.
                                        Not a port number any more.}
  CurrentRate: Word;                   {Nominal connect speed; protocols use it
                                        to size timeouts and blocks}


Function  CommActive: Boolean;
Procedure CommSetBaud(Baud: Word);    {Only records the nominal speed}
Procedure CommFlow(Flow: Byte);       {Does nothing on a session}
Procedure CommStartBreak;             {Does nothing}
Procedure CommStopBreak;
Procedure LowerDTR;                   {Old name of CommHangup}
Procedure RaiseDTR;                   {Does nothing}
Procedure CommInit;
Procedure CommRelease;
Procedure CommHangup;
Function  CommCarrier: Boolean;
Function  CommRecv: Char;
Function  CommPeek: Char;
Procedure CommSend(Ch: Char);
Function  CommSendNW(Ch: Char): Boolean;
Function  CommInEmpty: Boolean;
Function  CommOutReady: Boolean;
Function  CommOutEmpty: Boolean;
Procedure CommFlushIn;
Procedure CommFlushOut;
Function  GetCommInfo: String;
Function  CommWindowSize(Var Cols, Rows: Word): Boolean;
Function  CommWindowVersion: Word;


Implementation


Uses MKPlat;


{------------------------------------------------------ the abstract object}

Constructor AbsComObj.Init;
  Begin
  coBPS := 0;
  coPort := 1;
  coFlow := 0;
  coParity := 0;
  coNumBits := 8;
  coStopBits := 1;
  End;


Destructor AbsComObj.Done;
  Begin
  End;


Function AbsComObj.OpenSession: Boolean;
  Begin
  OpenSession := True;
  End;


Procedure AbsComObj.CloseSession;
  Begin
  End;


Procedure AbsComObj.Hangup;
  Begin
  End;


Function AbsComObj.GetCarrier: Boolean;
  Begin
  GetCarrier := False;
  End;


Function AbsComObj.Connected: Boolean;
  Begin
  Connected := GetCarrier;
  End;


Function AbsComObj.OpenPort(PortNo: Byte; Baud: LongInt; Flow: Byte; NumBits: Byte;
  StopBits: Byte; Parity: Byte): Boolean;
  Begin
  coPort := PortNo;
  coBPS := Baud;
  coFlow := Flow;
  coNumBits := NumBits;
  coStopBits := StopBits;
  coParity := Parity;
  OpenPort := OpenSession;
  End;


Procedure AbsComObj.ClosePort;
  Begin
  CloseSession;
  End;


Procedure AbsComObj.CommResume;
  Begin
  If OpenSession Then;
  End;


Function AbsComObj.GetCommPort: Integer;
  Begin
  GetCommPort := coPort;
  End;


Procedure AbsComObj.LowerDTR;
  Begin
  Hangup;
  End;


Procedure AbsComObj.RaiseDTR;
  Begin
  End;


Procedure AbsComObj.SetFlowCtl(FC: Byte);
  Begin
  coFlow := FC;
  End;


Procedure AbsComObj.StartBreak;
  Begin
  End;


Procedure AbsComObj.StopBreak;
  Begin
  End;


Function AbsComObj.GetInfo: String;
  Begin
  GetInfo := GetCommInfo;
  End;


Function AbsComObj.InEmpty: Boolean;
  Begin
  InEmpty := True;
  End;


Function AbsComObj.OutReady: Boolean;
  Begin
  OutReady := True;
  End;


Function AbsComObj.OutEmpty: Boolean;
  Begin
  OutEmpty := True;
  End;


Function AbsComObj.GetChar: Char;
  Begin
  GetChar := #0;
  End;


Function AbsComObj.PeekChar: Char;
  Begin
  PeekChar := #0;
  End;


Procedure AbsComObj.SendChar(Ch: Char);
  Begin
  End;


Function AbsComObj.SendCharNW(Ch: Char): Boolean;
  Begin
  If OutReady Then
    Begin
    SendChar(Ch);
    SendCharNW := True;
    End
  Else
    SendCharNW := False;
  End;


Type
  TByteBlock = Array[0..$FFFE] Of Byte;


Function AbsComObj.SendBlock(Var Dt; DSize: Word): Word;
  {Plain version: one character at a time.  Descendants with a real buffer
   should override it.}
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


Function AbsComObj.GetBlock(Var Dt; DSize: Word): Word;
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


Function AbsComObj.WaitForChar(Ms: Word): Boolean;
  Var
    Waited: LongInt;

  Begin
  Waited := 0;
  While InEmpty And GetCarrier And (Waited < Ms) Do
    Begin
    MKDelay(10);
    Inc(Waited, 10);
    End;
  WaitForChar := Not InEmpty;
  End;


Procedure AbsComObj.SendStr(Str: String);
  Var
    i: Word;

  Begin
  For i := 1 To Length(Str) Do
    SendChar(Str[i]);
  End;


Procedure AbsComObj.FlushIn;
  Begin
  While Not InEmpty Do
    If GetChar = #0 Then;
  End;


Procedure AbsComObj.FlushOut;
  Var
    Waited: LongInt;

  Begin
  Waited := 0;
  While (Not OutEmpty) And GetCarrier And (Waited < 30000) Do
    Begin
    MKDelay(10);
    Inc(Waited, 10);
    End;
  End;


Function AbsComObj.GetBPS: LongInt;
  Begin
  GetBPS := coBPS;
  End;


Procedure AbsComObj.SetBPS(Rate: LongInt);
  Begin
  coBPS := Rate;
  End;


Function AbsComObj.GetCommInfo: String;
  Begin
  GetCommInfo := 'No session';
  End;


Function AbsComObj.GetRemoteAddr: String;
  Begin
  GetRemoteAddr := '';
  End;


Procedure AbsComObj.SetRemoteAddr(Addr: String);
  Begin
  End;


Function AbsComObj.GetWindowSize(Var Cols, Rows: Word): Boolean;
  Begin
  GetWindowSize := False;
  End;


Function AbsComObj.WindowVersion: Word;
  Begin
  WindowVersion := 0;
  End;


{------------------------------------- the old MKFossil calls, on the session}

Function CommActive: Boolean;
  {True when a session is attached and we are not in local mode (this is the
   old test CurrentPort > 0)}
  Begin
  CommActive := (ComSession <> Nil) And (CurrentPort <> 0);
  End;


Procedure CommSetBaud(Baud: Word);
  Begin
  CurrentRate := Baud;
  If ComSession <> Nil Then
    ComSession^.SetBPS(Baud);
  End;


Procedure CommFlow(Flow: Byte);
  Begin
  If ComSession <> Nil Then
    ComSession^.SetFlowCtl(Flow);
  End;


Procedure CommStartBreak;
  Begin
  If ComSession <> Nil Then
    ComSession^.StartBreak;
  End;


Procedure CommStopBreak;
  Begin
  If ComSession <> Nil Then
    ComSession^.StopBreak;
  End;


Procedure LowerDTR;
  Begin
  CommHangup;
  End;


Procedure RaiseDTR;
  Begin
  End;


Procedure CommInit;
  Begin
  If ComSession <> Nil Then
    If ComSession^.OpenSession Then;
  End;


Procedure CommRelease;
  Begin
  If ComSession <> Nil Then
    ComSession^.CloseSession;
  End;


Procedure CommHangup;
  Begin
  If ComSession <> Nil Then
    ComSession^.Hangup;
  End;


Function CommCarrier: Boolean;
  Begin
  If ComSession <> Nil Then
    CommCarrier := ComSession^.GetCarrier
  Else
    CommCarrier := False;
  End;


Function CommRecv: Char;
  Begin
  If ComSession <> Nil Then
    CommRecv := ComSession^.GetChar
  Else
    CommRecv := #0;
  End;


Function CommPeek: Char;
  Begin
  If ComSession <> Nil Then
    CommPeek := ComSession^.PeekChar
  Else
    CommPeek := #0;
  End;


Procedure CommSend(Ch: Char);
  Begin
  If ComSession <> Nil Then
    ComSession^.SendChar(Ch);
  End;


Function CommSendNW(Ch: Char): Boolean;
  Begin
  If ComSession <> Nil Then
    CommSendNW := ComSession^.SendCharNW(Ch)
  Else
    CommSendNW := False;
  End;


Function CommInEmpty: Boolean;
  Begin
  If ComSession <> Nil Then
    CommInEmpty := ComSession^.InEmpty
  Else
    CommInEmpty := True;
  End;


Function CommOutReady: Boolean;
  Begin
  If ComSession <> Nil Then
    CommOutReady := ComSession^.OutReady
  Else
    CommOutReady := False;
  End;


Function CommOutEmpty: Boolean;
  Begin
  If ComSession <> Nil Then
    CommOutEmpty := ComSession^.OutEmpty
  Else
    CommOutEmpty := True;
  End;


Procedure CommFlushIn;
  Begin
  If ComSession <> Nil Then
    ComSession^.FlushIn;
  End;


Procedure CommFlushOut;
  Begin
  If ComSession <> Nil Then
    ComSession^.FlushOut;
  End;


Function GetCommInfo: String;
  Begin
  If ComSession <> Nil Then
    GetCommInfo := ComSession^.GetCommInfo
  Else
    GetCommInfo := 'No session';
  End;


Function CommWindowSize(Var Cols, Rows: Word): Boolean;
  Begin
  If ComSession <> Nil Then
    CommWindowSize := ComSession^.GetWindowSize(Cols, Rows)
  Else
    CommWindowSize := False;
  End;


Function CommWindowVersion: Word;
  Begin
  If ComSession <> Nil Then
    CommWindowVersion := ComSession^.WindowVersion
  Else
    CommWindowVersion := 0;
  End;


Begin
  ComSession := Nil;
  CurrentPort := 1;
  CurrentRate := 38400;
End.
