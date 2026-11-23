Unit MKSess;   {Builds the caller's session from the command line options}

{$I MKB.Def}

{
     mk is started by mklisten (or by hand, inetd, sshd ...) with the caller on
     standard input/output and says what kind of caller it is:

        -S<type>    STD (default): bytes as they are (terminal, inetd, a pty)
                    RAW:           same, a plain TCP connection
                    TELNET:        Telnet protocol on the connection
                    WS:            WebSocket on the connection (TLS: stunnel)
        -B<rate>    emulated line speed in bits per second (0 = full speed)
        -A<addr>    the caller's address (for the log and the user record)
        -H          a PROXY protocol header (stunnel "protocol = proxy") comes
                    first on the connection and tells the real address

        -Y          the connection is TLS and this program is the server (no
                    stunnel): the handshake is done first, with the certificate
                    and key named by the environment MK_TLS_CERT and MK_TLS_KEY
                    (mklisten sets them); TLS goes under Telnet or WebSocket (wss)

     CreateSession returns the session (Nil for an unknown type) so MK.pas and
     the test programs build it the same way.
}

Interface

Uses MKComAbs;

Var
  SessTls: Boolean;                    {-Y: do the TLS handshake first}
  SessionError: String;                {Why CreateSession returned Nil}

Function CreateSession(SType: String; Rate: LongInt; Addr: String;
  Proxy: Boolean): AbsComPtr;
  {SType is case-insensitive; Rate > 0 turns on the emulated speed; Proxy reads
   the PROXY header first (and replaces Addr with the address in it)}

Implementation

Uses SysUtils, MKComFd, MKComStd, MKComTelnet, MKComWS, MKProxy, MKTls;

Function TlsAttach(Std: StdComPtr): Boolean;
  {the handshake on the connection (stdin / stdout are the socket), then the descriptors read and write through TLS}
  Var
    Conn: Pointer;
    Err: AnsiString;
    Cert, Key: String;

  Begin
  TlsAttach := False;
  Cert := GetEnvironmentVariable('MK_TLS_CERT');
  Key := GetEnvironmentVariable('MK_TLS_KEY');
  If (Cert = '') Or (Key = '') Then
    Begin
    SessionError := 'TLS (-Y) needs MK_TLS_CERT and MK_TLS_KEY';
    Exit;
    End;
  If Not TlsAccept(Std^.InFd, Cert, Key, 20, Conn, Err) Then
    Begin
    SessionError := Err;
    Exit;
    End;
  Std^.Tls := Conn;
  Std^.TlsRd := TlsReadFn(@TlsRead);
  Std^.TlsWr := TlsWriteFn(@TlsWrite);
  Std^.TlsPend := TlsPendFn(@TlsPending);
  Std^.TlsFree := TlsFreeFn(@TlsClose);
  TlsAttach := True;
  End;


Function CreateSession(SType: String; Rate: LongInt; Addr: String;
  Proxy: Boolean): AbsComPtr;
  Var
    Std: StdComPtr;
    Tel: TelnetComPtr;
    Ws: WsComPtr;
    i: Word;

  Begin
  For i := 1 To Length(SType) Do
    SType[i] := UpCase(SType[i]);
  CreateSession := Nil;
  SessionError := '';
  If Length(Addr) > 64 Then
    Addr[0] := #64;
  If (SType = '') Or (SType = 'STD') Or (SType = 'RAW') Or (SType = 'TELNET') Or
     (SType = 'WS') Then
    Begin
    Std := New(StdComPtr, Init);
    If SessTls Then
      Begin
      If Not TlsAttach(Std) Then
        Begin
        Dispose(Std, Done);
        Exit;
        End;
      End;
    If Proxy Then
      Begin
      If Not ReadProxyHeader(Std, Addr, 5000) Then
        Begin
        SessionError := 'no valid PROXY header from the front end';
        Dispose(Std, Done);
        Exit;
        End;
      End;
    Std^.RemoteAddr := Addr;
    If SType = 'TELNET' Then
      CreateSession := New(TelnetComPtr, Init(Std, True))
    Else If SType = 'WS' Then
      CreateSession := New(WsComPtr, Init(Std, True))
    Else
      CreateSession := Std;
    If Rate > 0 Then
      CreateSession^.SetBPS(Rate);
    End
  Else
    SessionError := 'unknown session type -S' + SType + ' (STD, RAW, TELNET or WS)';
  End;

Begin
SessTls := False;
End.
