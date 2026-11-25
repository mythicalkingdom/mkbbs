Unit MKComClient;    {a session that is a connection to another system: a TCP client with Telnet}

{$I MKB.Def}

{
     ConnectTcp makes this program the caller: it connects to Host:Port (a name, an IPv4 or an IPv6 address; the addresses of a name are tried in turn)
     and returns a session (MKComAbs) that is ready to use: with Telnet = True a Telnet filter in client mode (see
     MKComTelnet: SGA and binary offered, the server's options answered, terminal type and window size told), else the
     bytes as they are.  The session is the owner of the connection: Hangup / Dispose close it.  Nil is returned with
     Err set when the host is not known, the connection is refused or does not come up within TimeoutMs.

       Var S: AbsComPtr;  Err: String;
       S := ConnectTcp('bbs.example.com', 23, 15000, True, Err);
       If S = Nil Then WriteLn(Err);

     The file transfer routines (MKProt) and the rest of MK work with the global ComSession: a caller of this unit that
     wants them to talk to the hub sets ComSession to the session and puts the old one back afterwards.
     ClientTerm, ClientCols and ClientRows are what Telnet servers are told (default ansi, 80 x 24).
}

Interface

Uses MKComAbs;


Var
  ClientTerm: String[40];
  ClientCols, ClientRows: Word;
  ClientPreamble: String;              {sent first, before any Telnet negotiation (a PROXY header for a listener behind a front end); '' = none}


Function ConnectTcp(Host: String; Port: Word; TimeoutMs: LongInt; Telnet: Boolean; Var Err: String): AbsComPtr;


Implementation


Uses BaseUnix, SysUtils, MKComFd, MKComTelnet, MKNet;


Function ConnectTcp(Host: String; Port: Word; TimeoutMs: LongInt; Telnet: Boolean; Var Err: String): AbsComPtr;
  Var
    Fd: LongInt;
    Raw: FdComPtr;
    Tel: TelnetComPtr;
    E: AnsiString;

  Begin
  ConnectTcp := Nil;
  Err := '';
  If Not NetConnect(Host, Port, TimeoutMs, Fd, E) Then       {IPv4 and IPv6: every address of the name in turn}
    Begin
    Err := E;
    Exit;
    End;
  New(Raw, InitFd(Fd, Fd));
  Raw^.SetRemoteAddr(NetJoinHostPort(Host, Port));
  If ClientPreamble <> '' Then
    Begin
    Raw^.OpenSession;
    Raw^.SendStr(ClientPreamble);
    Raw^.FlushOut;
    End;
  If Telnet Then
    Begin
    New(Tel, Init(Raw, True));
    Tel^.SetClient(ClientTerm, ClientCols, ClientRows);
    If Not Tel^.OpenSession Then
      Begin
      Dispose(Tel, Done);
      Err := 'The session did not open';
      Exit;
      End;
    ConnectTcp := Tel;
    End
  Else
    Begin
    If Not Raw^.OpenSession Then
      Begin
      Dispose(Raw, Done);
      Err := 'The session did not open';
      Exit;
      End;
    ConnectTcp := Raw;
    End;
  End;


Begin
ClientTerm := 'ansi';
ClientCols := 80;
ClientRows := 24;
ClientPreamble := '';
End.
