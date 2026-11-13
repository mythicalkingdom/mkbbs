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

     CreateSession returns the session (Nil for an unknown type) so MK.pas and
     the test programs build it the same way.
}

Interface

Uses MKComAbs;

Var
  SessionError: String;                {Why CreateSession returned Nil}

Function CreateSession(SType: String; Rate: LongInt; Addr: String;
  Proxy: Boolean): AbsComPtr;
  {SType is case-insensitive; Rate > 0 turns on the emulated speed; Proxy reads
   the PROXY header first (and replaces Addr with the address in it)}

Implementation

Uses MKComFd, MKComStd, MKComTelnet, MKComWS, MKProxy;

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

End.
