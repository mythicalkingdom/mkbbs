Unit MKProxy;   {PROXY protocol header (HAProxy v1 and v2), as sent by stunnel}

{$I MKB.Def}

{
     A TLS front end such as stunnel hides the caller's address: the BBS would
     see 127.0.0.1.  With "protocol = proxy" stunnel puts one header in front of
     the data, telling the real address:

        v1 (text):    PROXY TCP4 192.0.2.7 127.0.0.1 51234 2325 CRLF
        v2 (binary):  12 byte signature, version/command, family/protocol,
                      length, addresses

     ReadProxyHeader reads exactly that header from a session (before anything
     else is read from it) and returns the source address.  Only switch this on
     for a port that nobody but the front end can reach (bind 127.0.0.1): anyone
     who can connect could otherwise claim any address.
}

Interface

Uses MKComAbs;

Function ReadProxyHeader(S: AbsComPtr; Var Addr: String; TimeoutMs: LongInt): Boolean;
  {False: no valid header within the time.  Addr is left alone for UNKNOWN / LOCAL}

Function ParseProxyV1(Line: String; Var Addr: String): Boolean;
  {Line without the CRLF; False when it is not a PROXY line}

Function ProxyAddrFromBuf(Var Buf; N: LongInt; Var Addr: String): Integer;
  {The start of a connection (peeked, not read): 1 = a whole valid header, Addr is the caller's address (left alone for UNKNOWN / LOCAL);
   0 = more bytes are needed; -1 = it is not a PROXY header.  The listener uses it to know the address before it starts a node.}

Implementation

Uses MKPlat, MKNet;

Const
  Sig2: String[12] = #13#10#13#10#0#13#10'QUIT'#10;


Function ParseProxyV1(Line: String; Var Addr: String): Boolean;
  Var
    Fam, Src: String;
    p: Word;

  Begin
  ParseProxyV1 := False;
  If Copy(Line, 1, 6) <> 'PROXY ' Then
    Exit;
  Delete(Line, 1, 6);
  p := Pos(' ', Line);
  If p = 0 Then
    Begin
    ParseProxyV1 := Line = 'UNKNOWN';
    Exit;
    End;
  Fam := Copy(Line, 1, p - 1);
  Delete(Line, 1, p);
  If Fam = 'UNKNOWN' Then
    Begin
    ParseProxyV1 := True;
    Exit;
    End;
  If (Fam <> 'TCP4') And (Fam <> 'TCP6') Then
    Exit;
  p := Pos(' ', Line);
  If p < 2 Then
    Exit;
  Src := Copy(Line, 1, p - 1);
  For p := 1 To Length(Src) Do
    If Not (Src[p] In ['0'..'9', 'a'..'f', 'A'..'F', '.', ':']) Then
      Exit;
  Addr := NetNormalise(Src);               {2001:DB8:0::7 is 2001:db8::7, ::ffff:192.0.2.7 is 192.0.2.7}
  ParseProxyV1 := True;
  End;


Function GetByte(S: AbsComPtr; Var B: Byte; Start: Int64; TimeoutMs: LongInt): Boolean;
  Var
    Left: Int64;

  Begin
  GetByte := False;
  Left := TimeoutMs - (MKTicks - Start);
  If Left <= 0 Then
    Exit;
  If Left > 60000 Then
    Left := 60000;
  If S^.InEmpty Then
    If Not S^.WaitForChar(Left) Then
      Exit;
  B := Ord(S^.GetChar);
  GetByte := True;
  End;


Function HexWord(W: Word): String;
  Const
    D: String[16] = '0123456789abcdef';
  Var
    R: String;
    i: Byte;

  Begin
  R := '';
  For i := 3 Downto 0 Do
    R := R + D[((W Shr (i * 4)) And 15) + 1];
  While (Length(R) > 1) And (R[1] = '0') Do
    Delete(R, 1, 1);
  HexWord := R;
  End;


Function ProxyV2Addr(Fam: Byte; Var Body; Len: Word; Var Addr: String): Boolean;
  {the address of a version 2 header: Fam is the family / protocol byte, Body the address block}
  Var
    B: Array[0..235] Of Byte Absolute Body;
    i: Word;
    Tmp: String;

  Begin
  ProxyV2Addr := False;
  If (Fam = $11) And (Len >= 12) Then
    Begin                                {TCP over IPv4}
    Str(B[0], Addr);
    For i := 1 To 3 Do
      Begin
      Str(B[i], Tmp);
      Addr := Addr + '.' + Tmp;
      End;
    ProxyV2Addr := True;
    End
  Else If (Fam = $21) And (Len >= 36) Then
    Begin                                {TCP over IPv6}
    Addr := '';
    For i := 0 To 7 Do
      Begin
      If i > 0 Then
        Addr := Addr + ':';
      Addr := Addr + HexWord(B[i * 2] * 256 + B[i * 2 + 1]);
      End;
    Addr := NetNormalise(Addr);
    ProxyV2Addr := True;
    End;
  End;


Function ProxyAddrFromBuf(Var Buf; N: LongInt; Var Addr: String): Integer;
  Var
    B: Array[0..255] Of Byte Absolute Buf;
    i, Len: LongInt;
    Line: String;

  Begin
  ProxyAddrFromBuf := 0;
  If N <= 0 Then
    Exit;
  If B[0] = Ord('P') Then
    Begin                                {version 1: one text line}
    Line := '';
    For i := 0 To N - 1 Do
      Begin
      If i > 107 Then
        Begin
        ProxyAddrFromBuf := -1;
        Exit;
        End;
      If B[i] = 10 Then
        Begin
        If (Line <> '') And (Line[Length(Line)] = #13) Then
          Dec(Line[0]);
        If ParseProxyV1(Line, Addr) Then
          ProxyAddrFromBuf := 1
        Else
          ProxyAddrFromBuf := -1;
        Exit;
        End;
      Line := Line + Chr(B[i]);
      End;
    Exit;                                {no end of line yet}
    End;
  If B[0] <> Ord(Sig2[1]) Then
    Begin
    ProxyAddrFromBuf := -1;
    Exit;
    End;
  For i := 0 To 11 Do
    If i < N Then
      If B[i] <> Ord(Sig2[i + 1]) Then
        Begin
        ProxyAddrFromBuf := -1;
        Exit;
        End;
  If N < 16 Then
    Exit;
  If (B[12] And $F0) <> $20 Then
    Begin
    ProxyAddrFromBuf := -1;
    Exit;
    End;
  Len := B[14] * 256 + B[15];
  If Len > 236 Then
    Begin
    ProxyAddrFromBuf := -1;
    Exit;
    End;
  If N < 16 + Len Then
    Exit;
  ProxyAddrFromBuf := 1;
  If (B[12] And $0F) <> 0 Then
    If N >= 16 + Len Then
      Begin
      If Not ProxyV2Addr(B[13], B[16], Len, Addr) Then;
      End;
  End;


Function ReadProxyHeader(S: AbsComPtr; Var Addr: String; TimeoutMs: LongInt): Boolean;
  Var
    Start: Int64;
    B: Byte;
    Line: String;
    i, Len, Got: Word;
    Hdr: Array[0..15] Of Byte;
    Body: Array[0..235] Of Byte;
    Tmp: String;

  Begin
  ReadProxyHeader := False;
  Start := MKTicks;
  If Not GetByte(S, B, Start, TimeoutMs) Then
    Exit;
  If B = Ord('P') Then
    Begin                                {version 1: one text line}
    Line := 'P';
    Repeat
      If Not GetByte(S, B, Start, TimeoutMs) Then
        Exit;
      If B = 10 Then
        Break;
      If Length(Line) >= 107 Then
        Exit;
      Line := Line + Chr(B);
    Until False;
    If (Line <> '') And (Line[Length(Line)] = #13) Then
      Dec(Line[0]);
    ReadProxyHeader := ParseProxyV1(Line, Addr);
    Exit;
    End;
  If B <> Ord(Sig2[1]) Then
    Exit;
  Hdr[0] := B;
  For i := 1 To 15 Do
    If Not GetByte(S, Hdr[i], Start, TimeoutMs) Then
      Exit;
  For i := 0 To 11 Do
    If Hdr[i] <> Ord(Sig2[i + 1]) Then
      Exit;
  If (Hdr[12] And $F0) <> $20 Then
    Exit;
  Len := Hdr[14] * 256 + Hdr[15];
  If Len > SizeOf(Body) Then
    Exit;                                {too many TLVs for us: refuse}
  Got := 0;
  While Got < Len Do
    Begin
    If Not GetByte(S, Body[Got], Start, TimeoutMs) Then
      Exit;
    Inc(Got);
    End;
  ReadProxyHeader := True;
  If (Hdr[12] And $0F) = 0 Then
    Exit;                                {LOCAL: the front end itself, no address}
  If (Hdr[13] = $11) And (Len >= 12) Then
    Begin                                {TCP over IPv4}
    Str(Body[0], Addr);
    For i := 1 To 3 Do
      Begin
      Str(Body[i], Tmp);
      Addr := Addr + '.' + Tmp;
      End;
    End
  Else If (Hdr[13] = $21) And (Len >= 36) Then
    Begin                                {TCP over IPv6}
    Addr := '';
    For i := 0 To 7 Do
      Begin
      If i > 0 Then
        Addr := Addr + ':';
      Addr := Addr + HexWord(Body[i * 2] * 256 + Body[i * 2 + 1]);
      End;
    End;
  End;


End.
