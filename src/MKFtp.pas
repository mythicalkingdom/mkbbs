Unit MKFtp;          {a small FTP client: plain or FTPS (explicit TLS), passive mode, one file at a time}

{$mode objfpc}{$H+}

{
     For a QWK hub that is reached by FTP (map file: transport ftp / ftps).  It does what the exchange needs and no more: log in, fetch one file,
     send one file, delete one file.  Passive mode only (EPSV, then PASV), binary type, IPv4.  The data connection always goes to the address of the control
     connection (a server behind NAT names its own, private address).

     FTPS is explicit TLS (AUTH TLS, PBSZ 0, PROT P) with the OpenSSL libraries of the system, loaded when it is wanted (nothing is linked: without libssl
     only plain FTP works).  The data connection reuses the TLS session of the control connection (servers such as vsftpd ask for it).  The certificate of the
     server is checked against the CA file given, or the ones of the system, and its name must match the host (Verify = False turns all of it off).

       F := FtpOpen('ftp.example.com', 21, True, Ca, True, 60, Err);   {TLS, verify, 60 s without a byte is a failure}
       If F <> Nil Then If F.Login(User, Pass) Then Code := F.Retr('qwk/hub.qwk', '/tmp/hub.qwk');
       F.Free;
}

Interface

Type
  TFtp = class
    private
      Fd: LongInt;
      Ctx, Ssl: Pointer;
      Buf: AnsiString;
      Host, Ca: String;
      Verify, UseTls: Boolean;
      Secs: LongInt;
      Session: Pointer;
      function  Send(const S: AnsiString): Boolean;
      function  RecvByte(var C: Char): Boolean;
      function  ReadLine(var L: AnsiString): Boolean;
      function  StartTls(Sock: LongInt; var Conn: Pointer; Resume: Boolean): Boolean;
      function  DataOpen(var DFd: LongInt; var DSsl: Pointer): Boolean;
      procedure DataClose(DFd: LongInt; DSsl: Pointer);
    public
      Code: Integer;                     {the number of the last reply}
      Reply: AnsiString;                 {the text of the last reply (all its lines)}
      Err: String;
      Opened: Boolean;
      Trace: AnsiString;                 {the commands (the password as stars) and the replies, as ">> " and "<< " lines}
      function  Cmd(const Line: String): Integer;
      function  GetReply: Integer;
      function  Login(const User, Pass: String): Boolean;
      function  Retr(const Remote, Local: String): Integer;   {0 got it, 1 it is not there (550 / 450), 2 failed}
      function  Stor(const Local, Remote: String): Boolean;
      function  Dele(const Remote: String): Boolean;
      procedure Quit;
      destructor Destroy; override;
    end;


function FtpOpen(const AHost: String; Port: Word; Tls: Boolean; const ACa: String; AVerify: Boolean; ASecs: LongInt; var Err: ShortString): TFtp;


Implementation

Uses SysUtils, Classes, BaseUnix, Sockets, NetDB, DynLibs, ctypes, openssl, MKTlsLib;

Const
  CrLf = #13#10;

function Resolve(const H: String; var Addr: TInAddr): Boolean;
  Var
    HE: THostEntry;

  Begin
  Resolve := True;
  Addr := StrToNetAddr(H);
  If Addr.s_addr <> 0 Then
    Exit;
  If ResolveHostByName(H, HE) Then
    Begin
    Addr := HE.Addr;                     {network byte order already}
    Exit;
    End;
  Resolve := False;
  End;


function Connect(const H: String; Port: Word; Secs: LongInt; var Err: String): LongInt;
  Var
    Fd, Flags, Res, SoErr, L: LongInt;
    A: TInetSockAddr;
    Addr: TInAddr;
    FS: TFDSet;
    TV: TTimeVal;

  Begin
  Connect := -1;
  If Not Resolve(H, Addr) Then
    Begin
    Err := 'Unknown host ' + H;
    Exit;
    End;
  Fd := fpSocket(AF_INET, SOCK_STREAM, 0);
  If Fd < 0 Then
    Begin
    Err := 'No socket';
    Exit;
    End;
  Flags := fpFcntl(Fd, F_GETFL);
  fpFcntl(Fd, F_SETFL, Flags Or O_NONBLOCK);
  FillChar(A, SizeOf(A), 0);
  A.sin_family := AF_INET;
  A.sin_port := htons(Port);
  A.sin_addr := Addr;
  Res := fpConnect(Fd, @A, SizeOf(A));
  If (Res < 0) And (fpGetErrno = ESysEINPROGRESS) Then
    Begin
    fpFD_ZERO(FS);
    fpFD_SET(Fd, FS);
    TV.tv_sec := Secs;
    TV.tv_usec := 0;
    If fpSelect(Fd + 1, nil, @FS, nil, @TV) <= 0 Then
      Begin
      Err := 'No answer from ' + H + ':' + IntToStr(Port);
      fpClose(Fd);
      Exit;
      End;
    SoErr := 0;
    L := SizeOf(SoErr);
    fpGetSockOpt(Fd, SOL_SOCKET, SO_ERROR, @SoErr, @L);
    If SoErr <> 0 Then
      Begin
      Err := 'Cannot connect to ' + H + ':' + IntToStr(Port) + ' (error ' + IntToStr(SoErr) + ')';
      fpClose(Fd);
      Exit;
      End;
    End
  Else If Res < 0 Then
    Begin
    Err := 'Cannot connect to ' + H + ':' + IntToStr(Port);
    fpClose(Fd);
    Exit;
    End;
  fpFcntl(Fd, F_SETFL, Flags);
  TV.tv_sec := Secs;                      {a read or a write that waits longer than this fails: also for the TLS reads}
  TV.tv_usec := 0;
  fpSetSockOpt(Fd, SOL_SOCKET, SO_RCVTIMEO, @TV, SizeOf(TV));
  fpSetSockOpt(Fd, SOL_SOCKET, SO_SNDTIMEO, @TV, SizeOf(TV));
  Connect := Fd;
  End;


{ ---- TFtp }

function TFtp.Send(const S: AnsiString): Boolean;
  Var
    N, Done: LongInt;

  Begin
  Send := False;
  Done := 0;
  While Done < Length(S) Do
    Begin
    If Ssl <> Nil Then
      N := SslWrite(Ssl, @S[Done + 1], Length(S) - Done)
    Else
      N := fpSend(Fd, @S[Done + 1], Length(S) - Done, MSG_NOSIGNAL);
    If N <= 0 Then
      Exit;
    Inc(Done, N);
    End;
  Send := True;
  End;


function TFtp.RecvByte(var C: Char): Boolean;
  Var
    N: LongInt;

  Begin
  If Ssl <> Nil Then
    N := SslRead(Ssl, @C, 1)
  Else
    N := fpRecv(Fd, @C, 1, 0);
  RecvByte := N = 1;
  End;


function TFtp.ReadLine(var L: AnsiString): Boolean;
  Var
    C: Char;

  Begin
  ReadLine := False;
  L := '';
  While RecvByte(C) Do
    Begin
    If C = #10 Then
      Begin
      ReadLine := True;
      Exit;
      End;
    If C <> #13 Then
      L := L + C;
    If Length(L) > 4000 Then
      Exit;
    End;
  End;


function TFtp.GetReply: Integer;
  {a reply: one line "NNN text", or "NNN-text" ... up to a line that begins with "NNN "}
  Var
    L: AnsiString;
    N: Integer;
    Num: String;

  Begin
  GetReply := 0;
  Code := 0;
  Reply := '';
  If Not ReadLine(L) Then
    Begin
    Err := 'The server did not answer (or closed the connection)';
    Exit;
    End;
  Reply := L;
  Num := Copy(L, 1, 3);
  N := StrToIntDef(Num, 0);
  If (N = 0) Or (Length(L) < 4) Then
    Begin
    Err := 'Not an FTP reply: ' + Copy(L, 1, 60);
    Exit;
    End;
  If L[4] = '-' Then
    Repeat
      If Not ReadLine(L) Then
        Begin
        Err := 'The reply was cut off';
        Exit;
        End;
      Reply := Reply + #10 + L;
    Until (Copy(L, 1, 3) = Num) And (Length(L) >= 4) And (L[4] = ' ');
  Code := N;
  GetReply := N;
  Trace := Trace + '<< ' + StringReplace(Reply, #10, #10 + '<< ', [rfReplaceAll]) + #10;
  End;


function TFtp.Cmd(const Line: String): Integer;
  Begin
  If Copy(Line, 1, 5) = 'PASS ' Then
    Trace := Trace + '>> PASS ********' + #10
  Else
    Trace := Trace + '>> ' + Line + #10;
  If Not Send(Line + CrLf) Then
    Begin
    Err := 'Could not send to the server';
    Code := 0;
    Cmd := 0;
    Exit;
    End;
  Cmd := GetReply;
  End;


function TFtp.StartTls(Sock: LongInt; var Conn: Pointer; Resume: Boolean): Boolean;
  Var
    S: PSSL;
    Cert: Pointer;
    NameOk: Boolean;
    HostZ: String;

  Begin
  StartTls := False;
  S := SslNew(PSSL_CTX(Ctx));
  If S = Nil Then
    Begin
    Err := 'TLS: no session';
    Exit;
    End;
  SslSetFd(S, Sock);
  HostZ := Host;
  SslCtrl(S, SSL_CTRL_SET_TLSEXT_HOSTNAME, 0, PChar(HostZ));
  If Resume Then
    Begin                                {the session of the control connection (its tickets have arrived by now)}
    If (Session = Nil) And (Ssl <> Nil) And Assigned(pGetSession) Then
      Session := pGetSession(Ssl);
    If (Session <> Nil) And Assigned(pSetSession) Then
      pSetSession(S, Session);
    End;
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
  Conn := S;
  StartTls := True;
  End;


function TFtp.DataOpen(var DFd: LongInt; var DSsl: Pointer): Boolean;
  {EPSV, else PASV; the connection goes to the address of the control connection}
  Var
    P, Q, Port, V, i: LongInt;
    Nums: Array[1..6] Of LongInt;
    S, T: String;
    E: String;

  Begin
  DataOpen := False;
  DSsl := Nil;
  DFd := -1;
  Port := 0;
  If Cmd('EPSV') = 229 Then
    Begin
    P := Pos('(', Reply);
    Q := Pos(')', Reply);
    If (P > 0) And (Q > P) Then
      Begin
      S := Copy(Reply, P + 1, Q - P - 1);            {|||port|}
      Port := StrToIntDef(StringReplace(S, '|', '', [rfReplaceAll]), 0);
      End;
    End;
  If Port = 0 Then
    Begin
    If Cmd('PASV') <> 227 Then
      Begin
      Err := 'The server does not do passive mode: ' + Copy(Reply, 1, 80);
      Exit;
      End;
    P := Pos('(', Reply);
    Q := Pos(')', Reply);
    If (P = 0) Or (Q <= P) Then
      Begin
      Err := 'Not understood: ' + Copy(Reply, 1, 80);
      Exit;
      End;
    S := Copy(Reply, P + 1, Q - P - 1) + ',';
    i := 0;
    While (S <> '') And (i < 6) Do
      Begin
      P := Pos(',', S);
      T := Copy(S, 1, P - 1);
      Delete(S, 1, P);
      Inc(i);
      Nums[i] := StrToIntDef(Trim(T), -1);
      End;
    If i < 6 Then
      Begin
      Err := 'Not understood: ' + Copy(Reply, 1, 80);
      Exit;
      End;
    Port := Nums[5] * 256 + Nums[6];
    End;
  DFd := Connect(Host, Port, Secs, E);
  If DFd < 0 Then
    Begin
    Err := 'Data connection: ' + E;
    Exit;
    End;
  DataOpen := True;
  End;


procedure TFtp.DataClose(DFd: LongInt; DSsl: Pointer);
  Begin
  If DSsl <> Nil Then
    Begin
    SslShutdown(PSSL(DSsl));
    SslFree(PSSL(DSsl));
    End;
  If DFd >= 0 Then
    fpClose(DFd);
  End;


function FtpOpen(const AHost: String; Port: Word; Tls: Boolean; const ACa: String; AVerify: Boolean; ASecs: LongInt; var Err: ShortString): TFtp;
  Var
    F: TFtp;
    E: String;

  Begin
  FtpOpen := Nil;
  If Tls And Not LoadTls Then
    Begin
    Err := 'FTPS needs the OpenSSL libraries (libssl) and they could not be loaded';
    Exit;
    End;
  F := TFtp.Create;
  F.Host := AHost;
  F.Ca := ACa;
  F.Verify := AVerify;
  F.UseTls := Tls;
  F.Secs := ASecs;
  F.Fd := Connect(AHost, Port, ASecs, E);
  If F.Fd < 0 Then
    Begin
    Err := E;
    F.Free;
    Exit;
    End;
  F.Opened := True;
  If F.GetReply <> 220 Then
    Begin
    Err := 'The server did not say hello: ' + Copy(F.Reply + F.Err, 1, 100);
    F.Free;
    Exit;
    End;
  If Tls Then
    Begin
    If Assigned(pTlsMethod) Then
      F.Ctx := SslCtxNew(PSSL_METHOD(pTlsMethod()))      {OpenSSL 1.1 and 3: TLS_client_method}
    Else
      F.Ctx := SslCtxNew(SslMethodV23);
    If F.Ctx = Nil Then
      Begin
      Err := 'TLS: no context';
      F.Free;
      Exit;
      End;
    If AVerify Then
      Begin
      SslCtxSetVerify(PSSL_CTX(F.Ctx), SSL_VERIFY_PEER, Nil);
      If ACa <> '' Then
        SslCtxLoadVerifyLocations(PSSL_CTX(F.Ctx), ACa, '')
      Else
        SslCtxLoadVerifyLocations(PSSL_CTX(F.Ctx), '/etc/ssl/certs/ca-certificates.crt', '/etc/ssl/certs');
      End;
    If F.Cmd('AUTH TLS') <> 234 Then
      Begin
      Err := 'The server does not do FTPS (AUTH TLS): ' + Copy(F.Reply, 1, 80);
      F.Free;
      Exit;
      End;
    If Not F.StartTls(F.Fd, F.Ssl, False) Then
      Begin
      Err := F.Err;
      F.Free;
      Exit;
      End;
    F.Cmd('PBSZ 0');
    If F.Cmd('PROT P') <> 200 Then
      Begin
      Err := 'The server does not encrypt the data (PROT P): ' + Copy(F.Reply, 1, 80);
      F.Free;
      Exit;
      End;
    End;
  FtpOpen := F;
  End;


function TFtp.Login(const User, Pass: String): Boolean;
  Var
    C: Integer;

  Begin
  Login := False;
  C := Cmd('USER ' + User);
  If C = 331 Then
    C := Cmd('PASS ' + Pass);
  If (C <> 230) And (C <> 202) Then
    Begin
    Err := 'Login refused: ' + Copy(Reply, 1, 80);
    Exit;
    End;
  Cmd('TYPE I');
  Login := True;
  End;


function TFtp.Retr(const Remote, Local: String): Integer;
  Var
    DFd: LongInt;
    DSsl: Pointer;
    Out: File;
    Buf2: Array[0..32767] Of Byte;
    N: LongInt;
    C: Integer;
    Ok: Boolean;

  Begin
  Retr := 2;
  If Not DataOpen(DFd, DSsl) Then
    Exit;
  C := Cmd('RETR ' + Remote);
  If (C <> 150) And (C <> 125) Then
    Begin
    DataClose(DFd, Nil);
    If (C = 550) Or (C = 450) Then
      Retr := 1
    Else
      Err := 'RETR was refused: ' + Copy(Reply, 1, 80);
    Exit;
    End;
  If UseTls Then
    If Not StartTls(DFd, DSsl, True) Then
      Begin
      DataClose(DFd, Nil);
      Exit;
      End;
  Assign(Out, Local);
  {$I-}
  Rewrite(Out, 1);
  {$I+}
  If IOResult <> 0 Then
    Begin
    Err := 'Cannot write ' + Local;
    DataClose(DFd, DSsl);
    Exit;
    End;
  Ok := True;
  Repeat
    If DSsl <> Nil Then
      N := SslRead(PSSL(DSsl), @Buf2, SizeOf(Buf2))
    Else
      N := fpRecv(DFd, @Buf2, SizeOf(Buf2), 0);
    If N > 0 Then
      BlockWrite(Out, Buf2, N);
  Until N <= 0;
  Close(Out);
  DataClose(DFd, DSsl);
  C := GetReply;
  If C <> 226 Then
    Begin
    Err := 'The transfer did not end well: ' + Copy(Reply, 1, 80);
    Ok := False;
    End;
  If Ok Then
    Retr := 0
  Else
    DeleteFile(Local);
  End;


function TFtp.Stor(const Local, Remote: String): Boolean;
  Var
    DFd: LongInt;
    DSsl: Pointer;
    Inp: File;
    Buf2: Array[0..32767] Of Byte;
    N, Done, W: LongInt;
    C: Integer;
    Good: Boolean;

  Begin
  Stor := False;
  Assign(Inp, Local);
  {$I-}
  Reset(Inp, 1);
  {$I+}
  If IOResult <> 0 Then
    Begin
    Err := 'Cannot read ' + Local;
    Exit;
    End;
  If Not DataOpen(DFd, DSsl) Then
    Begin
    Close(Inp);
    Exit;
    End;
  C := Cmd('STOR ' + Remote);
  If (C <> 150) And (C <> 125) Then
    Begin
    DataClose(DFd, Nil);
    Close(Inp);
    Err := 'STOR was refused: ' + Copy(Reply, 1, 80);
    Exit;
    End;
  If UseTls Then
    If Not StartTls(DFd, DSsl, True) Then
      Begin
      DataClose(DFd, Nil);
      Close(Inp);
      Exit;
      End;
  Good := True;
  Repeat
    BlockRead(Inp, Buf2, SizeOf(Buf2), N);
    Done := 0;
    While Good And (Done < N) Do
      Begin
      If DSsl <> Nil Then
        W := SslWrite(PSSL(DSsl), @Buf2[Done], N - Done)
      Else
        W := fpSend(DFd, @Buf2[Done], N - Done, MSG_NOSIGNAL);
      If W <= 0 Then
        Good := False
      Else
        Inc(Done, W);
      End;
  Until (N = 0) Or Not Good;
  Close(Inp);
  DataClose(DFd, DSsl);
  C := GetReply;
  If Good And (C = 226) Then
    Stor := True
  Else
    Err := 'The transfer did not end well: ' + Copy(Reply + Err, 1, 100);
  End;


function TFtp.Dele(const Remote: String): Boolean;
  Begin
  Dele := Cmd('DELE ' + Remote) = 250;
  End;


procedure TFtp.Quit;
  Begin
  If Opened And (Fd >= 0) Then
    Cmd('QUIT');
  End;


destructor TFtp.Destroy;
  Begin
  If Ssl <> Nil Then
    Begin
    SslShutdown(PSSL(Ssl));
    SslFree(PSSL(Ssl));
    End;
  If Session <> Nil Then
    If Assigned(pFreeSession) Then
      pFreeSession(Session);
  If Ctx <> Nil Then
    SslCtxFree(PSSL_CTX(Ctx));
  If Fd >= 0 Then
    fpClose(Fd);
  Inherited Destroy;
  End;


End.
