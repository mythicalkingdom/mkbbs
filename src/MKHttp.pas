Unit MKHttp;         {a small HTTP/1.1 client: one request on its own connection, plain or TLS, bodies from and to files}

{$mode objfpc}{$H+}

{
     For a QWK hub that is an MK system with the JSON API (map file: hub https://host:2341, QWK-API-PLAN.md phase 4).  One request, one connection (Connection: close): the request goes out with
     an Authorization: Bearer token and, for PUT and POST, a body that is a file; the answer is read to the end: a body of a 200 answer goes to a file when one is wanted (a QWK packet), every other
     body is kept as text (the JSON of an error, of an acknowledgement).  No redirects, no chunked answers beyond Content-Length or the end of the connection.

     TLS is the OpenSSL of the system, loaded when it is wanted (MKTlsLib; without libssl only plain http works): the certificate is checked against the CA file given or the ones of the system and
     its name must match the host (Verify = False turns all of it off).  A read or a write that waits longer than Secs seconds fails.

       HttpDo('hub.example.org', 2341, True, '', True, 60, 'GET', '/v1/qwk/packet', Token, '', '', '/tmp/x.qwk', R)
       R.Status = 200, HttpHeader(R, 'x-qwk-packet') = the id, ... the packet is in /tmp/x.qwk
}

Interface

Uses SysUtils, Classes;

Type
  THttpResult = Record
    Status: Integer;                   {the status of the answer; 0 when there was none}
    Headers: TStringList;              {"name: value", the names in lower case}
    Body: AnsiString;                  {the body when it was not written to a file (at most 2 MB)}
    BodyBytes: Int64;                  {the length of the body, wherever it went}
    Err: String;                       {why there was no answer}
    Trace: String;                     {the request line and the answer, without the token}
    End;

Function HttpDo(Const Host: String; Port: Word; Tls: Boolean; Const Ca: String; Verify: Boolean; Secs: LongInt; Const Method, Path, Token, ReqFile, ReqType, RespFile: String; Var R: THttpResult): Boolean;
  {True when an answer came (any status); False: R.Err says what went wrong.  RespFile: where the body of a 200 answer goes ('' = into R.Body)}
Function HttpHeader(Const R: THttpResult; Const Name: String): String;
Procedure HttpFree(Var R: THttpResult);
Function HttpFileSha256(Const FN: String): String;                  {hex}
Function JsonValue(Const Text, Key: String): String;                {the value of "Key" in a JSON text (a string without its quotes, a number, true, false), '' when it is not there}

Implementation

Uses BaseUnix, Sockets, ctypes, openssl, MKTlsLib, MKPwd, MKNet;

Const
  MaxText = 2 * 1024 * 1024;


Function TcpConnect(Const H: String; Port: Word; Secs: LongInt; Var Err: String): LongInt;
  Var
    Fd: LongInt;
    TV: TTimeVal;

  Begin
  Result := -1;
  If Not NetConnect(H, Port, Secs * 1000, Fd, Err) Then       {IPv4 and IPv6: every address of the name in turn}
    Exit;
  TV.tv_sec := Secs;                      {a read or a write that waits longer than this fails: also for the TLS reads}
  TV.tv_usec := 0;
  fpSetSockOpt(Fd, SOL_SOCKET, SO_RCVTIMEO, @TV, SizeOf(TV));
  fpSetSockOpt(Fd, SOL_SOCKET, SO_SNDTIMEO, @TV, SizeOf(TV));
  Result := Fd;
  End;


Type
  TConn = Record
    Fd: LongInt;
    Ctx, Ssl: Pointer;
    End;


Function SendAll(Var C: TConn; Const P: Pointer; Len: LongInt): Boolean;
  Var
    Done, N: LongInt;

  Begin
  Result := False;
  Done := 0;
  While Done < Len Do
    Begin
    If C.Ssl <> Nil Then
      N := SslWrite(PSSL(C.Ssl), PByte(P) + Done, Len - Done)
    Else
      N := fpSend(C.Fd, PByte(P) + Done, Len - Done, MSG_NOSIGNAL);
    If N <= 0 Then
      Exit;
    Inc(Done, N);
    End;
  Result := True;
  End;


Function RecvSome(Var C: TConn; Buf: Pointer; Len: LongInt): LongInt;
  Begin
  If C.Ssl <> Nil Then
    Result := SslRead(PSSL(C.Ssl), Buf, Len)
  Else
    Result := fpRecv(C.Fd, Buf, Len, 0);
  End;


Function StartTls(Var C: TConn; Const Host, Ca: String; Verify: Boolean; Var Err: String): Boolean;
  Var
    S: PSSL;
    Cert: Pointer;
    NameOk: Boolean;
    HostZ: String;

  Begin
  Result := False;
  If Not LoadTls Then
    Begin
    Err := 'https needs the OpenSSL libraries (libssl) and they could not be loaded';
    Exit;
    End;
  If Assigned(pTlsMethod) Then
    C.Ctx := SslCtxNew(PSSL_METHOD(pTlsMethod()))
  Else
    C.Ctx := SslCtxNew(SslMethodV23);
  If C.Ctx = Nil Then
    Begin
    Err := 'TLS: no context';
    Exit;
    End;
  If Verify Then
    Begin
    SslCtxSetVerify(PSSL_CTX(C.Ctx), SSL_VERIFY_PEER, Nil);
    If Ca <> '' Then
      SslCtxLoadVerifyLocations(PSSL_CTX(C.Ctx), Ca, '')
    Else
      SslCtxLoadVerifyLocations(PSSL_CTX(C.Ctx), '/etc/ssl/certs/ca-certificates.crt', '/etc/ssl/certs');
    End;
  S := SslNew(PSSL_CTX(C.Ctx));
  If S = Nil Then
    Begin
    Err := 'TLS: no session';
    Exit;
    End;
  SslSetFd(S, C.Fd);
  HostZ := Host;
  SslCtrl(S, SSL_CTRL_SET_TLSEXT_HOSTNAME, 0, PChar(HostZ));
  If SslConnect(S) <> 1 Then
    Begin
    Err := 'TLS handshake failed' + Copy(' (the certificate of the server was not accepted?)', 1, 60 * Ord(Verify));
    SslFree(S);
    Exit;
    End;
  If Verify Then
    Begin
    Cert := Nil;
    If Assigned(pPeerCert) Then
      Cert := pPeerCert(S);
    If Cert = Nil Then
      Begin
      Err := 'TLS: the server has no certificate';
      SslFree(S);
      Exit;
      End;
    NameOk := Assigned(pCheckHost) And (pCheckHost(Cert, PChar(HostZ), Length(HostZ), 0, Nil) = 1);
    If Assigned(pFreeX509) Then
      pFreeX509(Cert);
    If Not NameOk Then
      Begin
      If Assigned(pCheckHost) Then
        Err := 'TLS: the certificate of the server is not for ' + Host
      Else
        Err := 'TLS: this OpenSSL cannot check the name in the certificate';
      SslFree(S);
      Exit;
      End;
    End;
  C.Ssl := S;
  Result := True;
  End;


Procedure CloseConn(Var C: TConn);
  Begin
  If C.Ssl <> Nil Then
    Begin
    SslShutdown(PSSL(C.Ssl));
    SslFree(PSSL(C.Ssl));
    C.Ssl := Nil;
    End;
  If C.Ctx <> Nil Then
    Begin
    SslCtxFree(PSSL_CTX(C.Ctx));
    C.Ctx := Nil;
    End;
  If C.Fd >= 0 Then
    fpClose(C.Fd);
  C.Fd := -1;
  End;


Function HttpHeader(Const R: THttpResult; Const Name: String): String;
  Var
    i: Integer;
    N: String;

  Begin
  Result := '';
  If R.Headers = Nil Then
    Exit;
  N := LowerCase(Name) + ':';
  For i := 0 To R.Headers.Count - 1 Do
    If Copy(R.Headers[i], 1, Length(N)) = N Then
      Result := Trim(Copy(R.Headers[i], Length(N) + 1, 2000));
  End;


Procedure HttpFree(Var R: THttpResult);
  Begin
  If R.Headers <> Nil Then
    FreeAndNil(R.Headers);
  End;


Function HttpFileSha256(Const FN: String): String;
  Var
    Fs: TFileStream;
    S: AnsiString;
    D: Sha256Digest;
    i: Integer;

  Begin
  Fs := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
  Try
    SetLength(S, Fs.Size);
    If Fs.Size > 0 Then
      Fs.ReadBuffer(S[1], Fs.Size);
  Finally
    Fs.Free;
  End;
  If S = '' Then
    Sha256Buf(@D, 0, D)
  Else
    Sha256Buf(@S[1], Length(S), D);
  Result := '';
  For i := 0 To 31 Do
    Result := Result + LowerCase(IntToHex(D[i], 2));
  End;


Function JsonValue(Const Text, Key: String): String;
  Var
    p, q: Integer;

  Begin
  Result := '';
  p := Pos('"' + Key + '"', Text);
  If p = 0 Then
    Exit;
  Inc(p, Length(Key) + 2);
  While (p <= Length(Text)) And (Text[p] In [' ', ':', #9, #10, #13]) Do
    Inc(p);
  If (p <= Length(Text)) And (Text[p] = '"') Then
    Begin
    Inc(p);
    q := p;
    While (q <= Length(Text)) And (Text[q] <> '"') Do
      Begin
      If (Text[q] = '\') Then
        Inc(q);
      Inc(q);
      End;
    Result := Copy(Text, p, q - p);
    End
  Else
    Begin
    q := p;
    While (q <= Length(Text)) And Not (Text[q] In [',', '}', ']', ' ', #10, #13]) Do
      Inc(q);
    Result := Copy(Text, p, q - p);
    End;
  End;


Function HttpDo(Const Host: String; Port: Word; Tls: Boolean; Const Ca: String; Verify: Boolean; Secs: LongInt; Const Method, Path, Token, ReqFile, ReqType, RespFile: String; Var R: THttpResult): Boolean;
  Var
    C: TConn;
    Hd, Line: AnsiString;
    Buf: Array[0..16383] Of Byte;
    N, p, i: LongInt;
    Fs, Out_: TFileStream;
    ReqLen, Want, Got, Total: Int64;
    Err: String;
    HeadDone: Boolean;
    Pending: AnsiString;
    ToFile: Boolean;

  Begin
  Result := False;
  R.Status := 0;
  R.Headers := TStringList.Create;
  R.Body := '';
  R.BodyBytes := 0;
  R.Err := '';
  R.Trace := '';
  C.Fd := -1;
  C.Ctx := Nil;
  C.Ssl := Nil;
  Fs := Nil;
  Out_ := Nil;
  Err := '';
  C.Fd := TcpConnect(Host, Port, Secs, Err);
  If C.Fd < 0 Then
    Begin
    R.Err := Err;
    Exit;
    End;
  Try
    If Tls And Not StartTls(C, Host, Ca, Verify, Err) Then
      Begin
      R.Err := Err;
      Exit;
      End;
    ReqLen := -1;
    If ReqFile <> '' Then
      Begin
      Fs := TFileStream.Create(ReqFile, fmOpenRead Or fmShareDenyNone);
      ReqLen := Fs.Size;
      End;
    Hd := Method + ' ' + Path + ' HTTP/1.1'#13#10 + 'Host: ' + NetJoinHostPort(Host, Port) + #13#10 + 'User-Agent: mk (MK BBS)'#13#10 + 'Accept: */*'#13#10 + 'Connection: close'#13#10;
    If Token <> '' Then
      Hd := Hd + 'Authorization: Bearer ' + Token + #13#10;
    If ReqLen >= 0 Then
      Hd := Hd + 'Content-Length: ' + IntToStr(ReqLen) + #13#10 + 'Content-Type: ' + ReqType + #13#10
    Else If (Method = 'POST') Or (Method = 'PUT') Then
      Hd := Hd + 'Content-Length: 0'#13#10;
    Hd := Hd + #13#10;
    R.Trace := '>> ' + Method + ' ' + Path + Copy(' (body ' + IntToStr(ReqLen) + ' bytes)', 1, 30 * Ord(ReqLen >= 0)) + #10;
    If Not SendAll(C, @Hd[1], Length(Hd)) Then
      Begin
      R.Err := 'Could not send to the server';
      Exit;
      End;
    If Fs <> Nil Then
      Begin
      Repeat
        N := Fs.Read(Buf, SizeOf(Buf));
        If N > 0 Then
          If Not SendAll(C, @Buf[0], N) Then
            Begin
            R.Err := 'Could not send the body to the server';
            Exit;
            End;
      Until N <= 0;
      End;
    { the answer: the head first }
    Pending := '';
    HeadDone := False;
    While Not HeadDone Do
      Begin
      N := RecvSome(C, @Buf[0], SizeOf(Buf));
      If N <= 0 Then
        Begin
        R.Err := 'The server did not answer (or closed the connection)';
        Exit;
        End;
      SetLength(Line, N);
      Move(Buf[0], Line[1], N);
      Pending := Pending + Line;
      p := Pos(#13#10#13#10, Pending);
      If p > 0 Then
        HeadDone := True
      Else If Length(Pending) > 65536 Then
        Begin
        R.Err := 'The answer has no end of its header';
        Exit;
        End;
      End;
    Hd := Copy(Pending, 1, p - 1);
    Delete(Pending, 1, p + 3);
    Line := Copy(Hd, 1, Pos(#13#10, Hd + #13#10) - 1);
    If Copy(Line, 1, 5) <> 'HTTP/' Then
      Begin
      R.Err := 'Not an HTTP answer: ' + Copy(Line, 1, 60);
      Exit;
      End;
    R.Status := StrToIntDef(Copy(Line, 10, 3), 0);
    Delete(Hd, 1, Length(Line) + 2);
    While Hd <> '' Do
      Begin
      p := Pos(#13#10, Hd);
      If p = 0 Then
        p := Length(Hd) + 1;
      Line := Copy(Hd, 1, p - 1);
      Delete(Hd, 1, p + 1);
      i := Pos(':', Line);
      If i > 1 Then
        R.Headers.Add(LowerCase(Trim(Copy(Line, 1, i - 1))) + ': ' + Trim(Copy(Line, i + 1, 4000)));
      End;
    Want := StrToInt64Def(HttpHeader(R, 'content-length'), -1);
    ToFile := (RespFile <> '') And (R.Status = 200);
    If ToFile Then
      Out_ := TFileStream.Create(RespFile, fmCreate);
    Total := 0;
    { the body: what came with the head, then the rest, to Content-Length or the end of the connection }
    Repeat
      If Length(Pending) > 0 Then
        Begin
        If (Want >= 0) And (Total + Length(Pending) > Want) Then
          SetLength(Pending, Want - Total);
        If ToFile Then
          Out_.WriteBuffer(Pending[1], Length(Pending))
        Else If Total + Length(Pending) <= MaxText Then
          R.Body := R.Body + Pending;
        Inc(Total, Length(Pending));
        Pending := '';
        End;
      If (Want >= 0) And (Total >= Want) Then
        Break;
      N := RecvSome(C, @Buf[0], SizeOf(Buf));
      If N <= 0 Then
        Begin
        If Want >= 0 Then
          Begin
          R.Err := 'The answer was cut off (' + IntToStr(Total) + ' of ' + IntToStr(Want) + ' bytes)';
          R.BodyBytes := Total;
          Exit;
          End;
        Break;
        End;
      SetLength(Pending, N);
      Move(Buf[0], Pending[1], N);
    Until False;
    R.BodyBytes := Total;
    R.Trace := R.Trace + '<< ' + IntToStr(R.Status) + ' (' + IntToStr(Total) + ' bytes)' + #10;
    Result := True;
  Finally
    If Fs <> Nil Then
      Fs.Free;
    If Out_ <> Nil Then
      Out_.Free;
    CloseConn(C);
    If (Not Result) And (R.Err <> '') Then
      R.Trace := R.Trace + '<< ' + R.Err + #10;
  End;
  End;

End.
