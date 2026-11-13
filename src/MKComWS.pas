Unit MKComWS;   {WebSocket (RFC 6455) filter over another session}

{$I MKB.Def}

{
     WsComObj wraps any other session (a TCP socket, or the plain connection
     stunnel makes after it has removed the TLS) and speaks WebSocket to a
     browser terminal such as xterm.js:

       - OpenSession reads the HTTP upgrade request and answers it (101 with
         Sec-WebSocket-Accept).  Anything that is not a WebSocket request gets a
         short HTTP error and the caller is dropped.  Offering the sub-protocol
         "binary" is answered with "binary".
       - Output is sent in binary frames (the BBS sends raw bytes: ANSI and
         CP437, not guaranteed UTF-8, so text frames would be wrong).  Bytes are
         collected and go out as one frame when the BBS waits for input, on
         FlushOut, or when 1 KB has collected.
       - Input frames (text, binary, continuation) must be masked, as the RFC
         says; their payload is the data stream.  Ping is answered with Pong,
         Close is answered with Close and ends the session.  Anything
         unreasonable (unmasked frame, absurd length) closes with 1002.
       - A terminal in the browser sends keys as UTF-8; nothing is converted.

     TLS is not handled here: use stunnel (see MKProxy for the caller's address).
     Origin is not checked.
}

Interface

Uses MKComAbs;


Const
  WsOutMax = 1024;


Type WsComObj = Object(AbsComObj)
  Inner: AbsComPtr;                    {The wrapped session}
  OwnsInner: Boolean;
  Shaken: Boolean;                     {Upgrade done}
  Closed: Boolean;                     {Close frame seen or sent, or failed}
  HavePeek: Boolean;
  PeekCh: Char;
  FrSt: Byte;                          {Frame parser state}
  Opcode: Byte;
  PayLen: LongInt;
  ExtLeft: Byte;
  Masked: Boolean;
  Mask: Array[0..3] Of Byte;
  MaskPos: Byte;
  CtlLen: Byte;
  Ctl: Array[0..124] Of Byte;
  OutLen: Word;
  OutBuf: Array[0..WsOutMax - 1] Of Char;
  Protocol: String[20];                {Sub-protocol the client asked for}
  Path: String[80];                    {Request path}
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
  Procedure Fill(WaitMs: LongInt);     {Internal}
  Procedure Process(B: Byte);          {Internal: one byte of the frame stream}
  Procedure EndFrame;                  {Internal}
  Procedure SendFrame(Op: Byte; Var Dt; Len: Word);  {Internal}
  Procedure FlushFrame;                {Internal: collected output as one frame}
  Procedure Fail(Code: Word);          {Internal: send Close and drop}
  Function  Handshake: Boolean;        {Internal}
  End;


Type WsComPtr = ^WsComObj;


Function WebSocketAccept(Key: String): String;
  {Sec-WebSocket-Accept for a Sec-WebSocket-Key}


Implementation


Uses sha1, base64, MKPlat;

Const
  Guid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
  HandshakeMs = 10000;

Type
  TByteBlock = Array[0..$FFFE] Of Byte;


Function WebSocketAccept(Key: String): String;
  Var
    D: TSHA1Digest;
    S: String;
    i: Byte;

  Begin
  D := SHA1String(Key + Guid);
  S := '';
  For i := 0 To 19 Do
    S := S + Chr(D[i]);
  WebSocketAccept := EncodeStringBase64(S);
  End;


Constructor WsComObj.Init(AInner: AbsComPtr; AOwns: Boolean);
  Begin
  Inherited Init;
  Inner := AInner;
  OwnsInner := AOwns;
  Shaken := False;
  Closed := False;
  HavePeek := False;
  FrSt := 0;
  OutLen := 0;
  Protocol := '';
  Path := '';
  End;


Destructor WsComObj.Done;
  Begin
  If OwnsInner And (Inner <> Nil) Then
    Dispose(Inner, Done);
  Inner := Nil;
  Inherited Done;
  End;


Function Lower(S: String): String;
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    If S[i] In ['A'..'Z'] Then
      S[i] := Chr(Ord(S[i]) + 32);
  Lower := S;
  End;


Function Trim(S: String): String;
  Begin
  While (S <> '') And (S[1] In [' ', #9]) Do
    Delete(S, 1, 1);
  While (S <> '') And (S[Length(S)] In [' ', #9, #13]) Do
    Dec(S[0]);
  Trim := S;
  End;


Function WsComObj.Handshake: Boolean;
  {Read the HTTP request, answer it.  False: not a usable WebSocket request.}
  Var
    Start, Left: Int64;
    Line, Name, Val, Key, Resp: String;
    C: Char;
    Total, p: Word;
    First: Boolean;
    Upg, Conn, Version13: Boolean;
    Tmp: String;

  Begin
  Handshake := False;
  Start := MKTicks;
  Total := 0;
  First := True;
  Upg := False;
  Conn := False;
  Version13 := False;
  Key := '';
  Line := '';
  Repeat
    If Inner^.InEmpty Then
      Begin
      Left := HandshakeMs - (MKTicks - Start);
      If (Left <= 0) Or (Not Inner^.GetCarrier) Then
        Exit;
      If Not Inner^.WaitForChar(Left) Then
        Continue;
      End;
    C := Inner^.GetChar;
    Inc(Total);
    If Total > 8192 Then
      Exit;
    If C = #10 Then
      Begin
      Line := Trim(Line);
      If First Then
        Begin                            {GET /path HTTP/1.1}
        If Copy(Line, 1, 4) <> 'GET ' Then
          Exit;
        Delete(Line, 1, 4);
        p := Pos(' ', Line);
        If p > 0 Then
          Path := Copy(Line, 1, p - 1);
        First := False;
        End
      Else If Line = '' Then
        Break                            {end of the headers}
      Else
        Begin
        p := Pos(':', Line);
        If p > 0 Then
          Begin
          Name := Lower(Copy(Line, 1, p - 1));
          Val := Trim(Copy(Line, p + 1, 255));
          If Name = 'upgrade' Then
            Upg := Pos('websocket', Lower(Val)) > 0
          Else If Name = 'connection' Then
            Conn := Pos('upgrade', Lower(Val)) > 0
          Else If Name = 'sec-websocket-key' Then
            Key := Val
          Else If Name = 'sec-websocket-version' Then
            Version13 := Pos('13', Val) > 0
          Else If Name = 'sec-websocket-protocol' Then
            Begin
            If Pos('binary', Lower(Val)) > 0 Then
              Protocol := 'binary';
            End;
          End;
        End;
      Line := '';
      End
    Else If Length(Line) < 250 Then
      Line := Line + C;
  Until False;
  If Not (Upg And Conn And Version13 And (Key <> '')) Then
    Begin
    Resp := 'HTTP/1.1 426 Upgrade Required'#13#10 +
      'Sec-WebSocket-Version: 13'#13#10 +
      'Content-Type: text/plain'#13#10 +
      'Connection: close'#13#10#13#10 +
      'This is a BBS: connect with a WebSocket client.'#13#10;
    Inner^.SendStr(Resp);
    Inner^.FlushOut;
    Exit;
    End;
  Resp := 'HTTP/1.1 101 Switching Protocols'#13#10 +
    'Upgrade: websocket'#13#10 +
    'Connection: Upgrade'#13#10 +
    'Sec-WebSocket-Accept: ' + WebSocketAccept(Key) + #13#10;
  If Protocol <> '' Then
    Resp := Resp + 'Sec-WebSocket-Protocol: ' + Protocol + #13#10;
  Resp := Resp + #13#10;
  Inner^.SendStr(Resp);
  Inner^.FlushOut;
  Handshake := True;
  End;


Function WsComObj.OpenSession: Boolean;
  Begin
  OpenSession := False;
  HavePeek := False;
  FrSt := 0;
  OutLen := 0;
  Closed := False;
  If Not Inner^.OpenSession Then
    Exit;
  Shaken := Handshake;
  If Not Shaken Then
    Begin
    Closed := True;
    Inner^.Hangup;
    Exit;
    End;
  OpenSession := True;
  End;


Procedure WsComObj.SendFrame(Op: Byte; Var Dt; Len: Word);
  Var
    i: Word;

  Begin
  Inner^.SendChar(Chr($80 Or Op));
  If Len < 126 Then
    Inner^.SendChar(Chr(Len))
  Else
    Begin
    Inner^.SendChar(#126);
    Inner^.SendChar(Chr(Len Shr 8));
    Inner^.SendChar(Chr(Len And $FF));
    End;
  i := 0;
  While i < Len Do
    Begin
    Inner^.SendChar(Chr(TByteBlock(Dt)[i]));
    Inc(i);
    End;
  End;


Procedure WsComObj.FlushFrame;
  Begin
  If (OutLen > 0) And Shaken And (Not Closed) Then
    SendFrame(2, OutBuf, OutLen);
  OutLen := 0;
  End;


Procedure WsComObj.Fail(Code: Word);
  Var
    B: Array[0..1] Of Byte;

  Begin
  If Shaken And (Not Closed) Then
    Begin
    FlushFrame;
    B[0] := Code Shr 8;
    B[1] := Code And $FF;
    SendFrame(8, B, 2);
    Inner^.FlushOut;
    End;
  Closed := True;
  HavePeek := False;
  Inner^.Hangup;
  End;


Procedure WsComObj.EndFrame;
  Begin
  Case Opcode Of
    9: Begin                             {ping: pong with the same payload}
       FlushFrame;
       SendFrame(10, Ctl, CtlLen);
       End;
    8: Fail(1000);                       {close: answer and drop}
    End;
  FrSt := 0;
  End;


Procedure WsComObj.Process(B: Byte);
  Begin
  Case FrSt Of
    0: Begin                             {FIN, opcode}
       Opcode := B And $0F;
       If (B And $70) <> 0 Then
         Begin Fail(1002); Exit; End;    {reserved bits: no extension was agreed}
       FrSt := 1;
       End;
    1: Begin                             {mask bit, length}
       Masked := (B And $80) <> 0;
       If Not Masked Then
         Begin Fail(1002); Exit; End;
       B := B And $7F;
       PayLen := B;
       If B = 126 Then
         Begin ExtLeft := 2; PayLen := 0; FrSt := 2; End
       Else If B = 127 Then
         Begin ExtLeft := 8; PayLen := 0; FrSt := 2; End
       Else
         Begin
         MaskPos := 0;
         FrSt := 3;
         End;
       End;
    2: Begin                             {extended length}
       If (ExtLeft > 4) And (B <> 0) Then
         Begin Fail(1009); Exit; End;    {more than 4 GB: no}
       If ExtLeft <= 4 Then
         PayLen := PayLen * 256 + B;
       If (PayLen < 0) Or (PayLen > $1000000) Then
         Begin Fail(1009); Exit; End;
       Dec(ExtLeft);
       If ExtLeft = 0 Then
         Begin
         MaskPos := 0;
         FrSt := 3;
         End;
       End;
    3: Begin                             {masking key}
       Mask[MaskPos] := B;
       Inc(MaskPos);
       If MaskPos = 4 Then
         Begin
         MaskPos := 0;
         CtlLen := 0;
         If (Opcode >= 8) And (PayLen > 125) Then
           Begin Fail(1002); Exit; End;  {control frames are short}
         If PayLen = 0 Then
           EndFrame
         Else
           FrSt := 4;
         End;
       End;
    4: Begin                             {payload}
       B := B Xor Mask[MaskPos];
       MaskPos := (MaskPos + 1) And 3;
       If Opcode < 3 Then
         Begin                           {continuation, text, binary: the data}
         PeekCh := Chr(B);
         HavePeek := True;
         End
       Else If (Opcode >= 8) And (CtlLen < 125) Then
         Begin
         Ctl[CtlLen] := B;
         Inc(CtlLen);
         End;
       Dec(PayLen);
       If PayLen = 0 Then
         EndFrame;
       End;
    End;
  End;


Procedure WsComObj.Fill(WaitMs: LongInt);
  Var
    Start, Left: Int64;

  Begin
  If Closed Then
    Exit;
  Start := MKTicks;
  FlushFrame;
  While (Not HavePeek) And (Not Closed) Do
    Begin
    If Not Inner^.InEmpty Then
      Process(Ord(Inner^.GetChar))
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


Procedure WsComObj.CloseSession;
  Begin
  FlushFrame;
  Inner^.CloseSession;
  End;


Procedure WsComObj.Hangup;
  Begin
  If Shaken And (Not Closed) Then
    Fail(1000)
  Else
    Inner^.Hangup;
  HavePeek := False;
  Closed := True;
  End;


Function WsComObj.GetCarrier: Boolean;
  Begin
  If (Not HavePeek) And (Not Closed) Then
    Fill(0);
  GetCarrier := HavePeek Or ((Not Closed) And Inner^.GetCarrier);
  End;


Function WsComObj.InEmpty: Boolean;
  Begin
  Fill(0);
  InEmpty := Not HavePeek;
  End;


Function WsComObj.OutReady: Boolean;
  Begin
  OutReady := (Not Closed) And Inner^.OutReady;
  End;


Function WsComObj.OutEmpty: Boolean;
  Begin
  FlushFrame;
  OutEmpty := Inner^.OutEmpty;
  End;


Function WsComObj.GetChar: Char;
  Begin
  While (Not HavePeek) And (Not Closed) And Inner^.GetCarrier Do
    Fill(100);
  If HavePeek Then
    Begin
    GetChar := PeekCh;
    HavePeek := False;
    End
  Else
    GetChar := #0;
  End;


Function WsComObj.PeekChar: Char;
  Begin
  Fill(0);
  If HavePeek Then
    PeekChar := PeekCh
  Else
    PeekChar := #0;
  End;


Procedure WsComObj.SendChar(Ch: Char);
  Begin
  If Closed Then
    Exit;
  If OutLen >= WsOutMax Then
    FlushFrame;
  OutBuf[OutLen] := Ch;
  Inc(OutLen);
  End;


Function WsComObj.SendBlock(Var Dt; DSize: Word): Word;
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


Function WsComObj.GetBlock(Var Dt; DSize: Word): Word;
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


Function WsComObj.WaitForChar(Ms: Word): Boolean;
  Begin
  Fill(Ms);
  WaitForChar := HavePeek;
  End;


Procedure WsComObj.FlushOut;
  Begin
  FlushFrame;
  Inner^.FlushOut;
  End;


Procedure WsComObj.SetBPS(Rate: LongInt);
  Begin
  coBPS := Rate;
  Inner^.SetBPS(Rate);
  End;


Function WsComObj.GetCommInfo: String;
  Begin
  GetCommInfo := 'WebSocket over ' + Inner^.GetCommInfo;
  End;


Function WsComObj.GetRemoteAddr: String;
  Begin
  GetRemoteAddr := Inner^.GetRemoteAddr;
  End;


Procedure WsComObj.SetRemoteAddr(Addr: String);
  Begin
  Inner^.SetRemoteAddr(Addr);
  End;


Function WsComObj.GetWindowSize(Var C, R: Word): Boolean;
  Begin
  GetWindowSize := Inner^.GetWindowSize(C, R);
  End;


Function WsComObj.WindowVersion: Word;
  Begin
  WindowVersion := Inner^.WindowVersion;
  End;


End.
