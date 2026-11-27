Unit MKTls;          {TLS on the connection, in the server role: the program itself speaks TLS to the caller (the libraries of OpenSSL, if they are there)}

{$mode objfpc}{$H+}

{
     The alternative to a TLS front end such as stunnel.  mklisten checks at its start (TlsCheckServer) that the libraries load and the certificate and the
     key can be read and belong together, by the user it runs as; each mk then does the handshake on its connection (TlsAccept) and reads and writes through
     TlsRead / TlsWrite (MKComFd calls them).  The files are read again by each connection, so a renewed certificate is used by the next caller, with
     no reload.  TLS 1.2 and up.  Without libssl everything returns False and says why; nothing else of MK is affected.
}

Interface

Function TlsAvailable(var Why: String): Boolean;
Function TlsCheckServer(const Cert, Key: String; var Why: String): Boolean;
Function TlsAccept(Fd: LongInt; const Cert, Key: String; Secs: LongInt; var Conn: Pointer; var Err: String): Boolean;
{ the client role (mkconnect): the handshake on a connected socket; the certificate of the system is NOT checked (a BBS most often has a self-signed one): what is gained is that the line cannot be read on the way; SNI is sent for a name }
Function TlsConnect(Fd: LongInt; const Host: String; Secs: LongInt; var Conn: Pointer; var Err: String): Boolean;
Function TlsRead(Conn: Pointer; Buf: Pointer; N: LongInt): LongInt;     {n bytes; 0 closed; -1 failed; -2 try again}
Function TlsWrite(Conn: Pointer; Buf: Pointer; N: LongInt): LongInt;    {n bytes; -1 failed}
Function TlsPending(Conn: Pointer): LongInt;                            {bytes already decrypted and waiting}
Procedure TlsClose(Conn: Pointer);


Implementation

Uses SysUtils, BaseUnix, Sockets, ctypes, openssl, MKTlsLib;

Var
  Ctx: Pointer;
  CtxCert, CtxKey: String;
  CliCtx: Pointer;


Function TlsAvailable(var Why: String): Boolean;
  Begin
  TlsAvailable := False;
  If Not LoadTls Then
    Begin
    Why := 'the OpenSSL libraries (libssl) were not found';
    Exit;
    End;
  If Not Assigned(pTlsServerMethod) Then
    Begin
    Why := 'this OpenSSL has no TLS_server_method (too old: needs 1.1 or 3)';
    Exit;
    End;
  TlsAvailable := True;
  End;


Function MakeCtx(const Cert, Key: String; var Why: String): Pointer;
  Var
    C: PSSL_CTX;

  Begin
  MakeCtx := Nil;
  If Not TlsAvailable(Why) Then
    Exit;
  C := SslCtxNew(PSSL_METHOD(pTlsServerMethod()));
  If C = Nil Then
    Begin
    Why := 'no TLS context';
    Exit;
    End;
  If Assigned(pCtxCtrl) Then
    pCtxCtrl(C, SSL_CTRL_SET_MIN_PROTO_VERSION, TLS1_2_VERSION, Nil);
  If SslCtxUseCertificateChainFile(C, Cert) <> 1 Then
    Begin
    Why := 'the certificate ' + Cert + ' cannot be read (or is not a PEM certificate chain)';
    SslCtxFree(C);
    Exit;
    End;
  If SslCtxUsePrivateKeyFile(C, Key, 1) <> 1 Then
    Begin
    Why := 'the key ' + Key + ' cannot be read (or is not a PEM key without a pass phrase)';
    SslCtxFree(C);
    Exit;
    End;
  If SslCtxCheckPrivateKeyFile(C) <> 1 Then
    Begin
    Why := 'the key ' + Key + ' does not belong to the certificate ' + Cert;
    SslCtxFree(C);
    Exit;
    End;
  MakeCtx := C;
  End;


Function TlsCheckServer(const Cert, Key: String; var Why: String): Boolean;
  Var
    C: Pointer;

  Begin
  C := MakeCtx(Cert, Key, Why);
  TlsCheckServer := C <> Nil;
  If C <> Nil Then
    SslCtxFree(PSSL_CTX(C));
  End;


Function TlsAccept(Fd: LongInt; const Cert, Key: String; Secs: LongInt; var Conn: Pointer; var Err: String): Boolean;
  Var
    S: PSSL;
    TV: TTimeVal;
    R: LongInt;

  Begin
  TlsAccept := False;
  Conn := Nil;
  If (Ctx = Nil) Or (CtxCert <> Cert) Or (CtxKey <> Key) Then
    Begin
    Ctx := MakeCtx(Cert, Key, Err);
    If Ctx = Nil Then
      Exit;
    CtxCert := Cert;
    CtxKey := Key;
    End;
  S := SslNew(PSSL_CTX(Ctx));
  If S = Nil Then
    Begin
    Err := 'no TLS session';
    Exit;
    End;
  SslSetFd(S, Fd);
  TV.tv_sec := Secs;                     {a caller that does not finish the handshake is let go}
  TV.tv_usec := 0;
  fpSetSockOpt(Fd, SOL_SOCKET, SO_RCVTIMEO, @TV, SizeOf(TV));
  fpSetSockOpt(Fd, SOL_SOCKET, SO_SNDTIMEO, @TV, SizeOf(TV));
  R := SslAccept(S);
  TV.tv_sec := 0;
  fpSetSockOpt(Fd, SOL_SOCKET, SO_RCVTIMEO, @TV, SizeOf(TV));
  fpSetSockOpt(Fd, SOL_SOCKET, SO_SNDTIMEO, @TV, SizeOf(TV));
  If R <> 1 Then
    Begin
    Err := 'the TLS handshake with the caller failed (a caller that does not speak TLS?)';
    SslFree(S);
    Exit;
    End;
  Conn := S;
  TlsAccept := True;
  End;


Function TlsConnect(Fd: LongInt; const Host: String; Secs: LongInt; var Conn: Pointer; var Err: String): Boolean;
  Var
    S: PSSL;
    TV: TTimeVal;
    R: LongInt;
    H: AnsiString;
    IsIp: Boolean;
    i: Integer;

  Begin
  TlsConnect := False;
  Conn := Nil;
  If Not TlsAvailable(Err) Then
    Exit;
  If Not Assigned(pTlsMethod) Then
    Begin
    Err := 'this OpenSSL has no TLS_client_method';
    Exit;
    End;
  If CliCtx = Nil Then
    Begin
    CliCtx := SslCtxNew(PSSL_METHOD(pTlsMethod()));
    If CliCtx = Nil Then
      Begin
      Err := 'no TLS context';
      Exit;
      End;
    If Assigned(pCtxCtrl) Then
      pCtxCtrl(CliCtx, SSL_CTRL_SET_MIN_PROTO_VERSION, TLS1_2_VERSION, Nil);
    End;
  S := SslNew(PSSL_CTX(CliCtx));
  If S = Nil Then
    Begin
    Err := 'no TLS session';
    Exit;
    End;
  IsIp := Host <> '';
  For i := 1 To Length(Host) Do
    If Not (Host[i] In ['0'..'9', '.', ':', 'a'..'f', 'A'..'F']) Then
      IsIp := False;
  If (Host <> '') And Not IsIp Then
    Begin
    H := Host;
    SslCtrl(S, 55, 0, PChar(H));         {SSL_CTRL_SET_TLSEXT_HOSTNAME, host_name: SNI}
    End;
  SslSetFd(S, Fd);
  TV.tv_sec := Secs;
  TV.tv_usec := 0;
  fpSetSockOpt(Fd, SOL_SOCKET, SO_RCVTIMEO, @TV, SizeOf(TV));
  fpSetSockOpt(Fd, SOL_SOCKET, SO_SNDTIMEO, @TV, SizeOf(TV));
  R := SslConnect(S);
  TV.tv_sec := 0;
  fpSetSockOpt(Fd, SOL_SOCKET, SO_RCVTIMEO, @TV, SizeOf(TV));
  fpSetSockOpt(Fd, SOL_SOCKET, SO_SNDTIMEO, @TV, SizeOf(TV));
  If R <> 1 Then
    Begin
    Err := 'the TLS handshake failed (does the system speak TLS on this port?)';
    SslFree(S);
    Exit;
    End;
  Conn := S;
  TlsConnect := True;
  End;


Function TlsRead(Conn: Pointer; Buf: Pointer; N: LongInt): LongInt;
  Var
    R, E: LongInt;

  Begin
  R := SslRead(PSSL(Conn), Buf, N);
  If R > 0 Then
    Begin
    TlsRead := R;
    Exit;
    End;
  E := SslGetError(PSSL(Conn), R);
  If (E = 2) Or (E = 3) Then
    TlsRead := -2                        {SSL_ERROR_WANT_READ / WANT_WRITE}
  Else If E = 6 Then
    TlsRead := 0                         {SSL_ERROR_ZERO_RETURN: the caller closed}
  Else If (E = 5) And (fpGetErrno = 0) Then
    TlsRead := 0                         {the connection ended without the TLS close}
  Else
    TlsRead := -1;
  End;


Function TlsWrite(Conn: Pointer; Buf: Pointer; N: LongInt): LongInt;
  Var
    R, E: LongInt;

  Begin
  R := SslWrite(PSSL(Conn), Buf, N);
  If R > 0 Then
    Begin
    TlsWrite := R;
    Exit;
    End;
  E := SslGetError(PSSL(Conn), R);
  If (E = 2) Or (E = 3) Then
    TlsWrite := -2
  Else
    TlsWrite := -1;
  End;


Function TlsPending(Conn: Pointer): LongInt;
  Begin
  TlsPending := SslPending(PSSL(Conn));
  End;


Procedure TlsClose(Conn: Pointer);
  Begin
  If Conn <> Nil Then
    Begin
    SslShutdown(PSSL(Conn));
    SslFree(PSSL(Conn));
    End;
  End;


Initialization
  Ctx := Nil;
End.
