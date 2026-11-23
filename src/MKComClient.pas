Unit MKComClient;    {a session that is a connection to another system: a TCP client with Telnet}

{$I MKB.Def}

{
     ConnectTcp makes this program the caller: it connects to Host:Port (a name or a dotted IPv4 address; no IPv6)
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


Uses BaseUnix, Sockets, NetDB, SysUtils, MKComFd, MKComTelnet;


Function Resolve(Host: String; Var Addr: TInAddr): Boolean;
  Var
    H: THostEntry;

  Begin
  Resolve := True;
  Addr := StrToNetAddr(Host);
  If Addr.s_addr <> 0 Then
    Exit;
  If (Host = '0.0.0.0') Then
    Exit;
  If ResolveHostByName(Host, H) Then
    Begin
    Addr := H.Addr;                      {ResolveHostByName gives the address in network byte order}
    Exit;
    End;
  Resolve := False;
  End;


Function ConnectTcp(Host: String; Port: Word; TimeoutMs: LongInt; Telnet: Boolean; Var Err: String): AbsComPtr;
  Var
    Fd, Flags, Res: LongInt;
    A: TInetSockAddr;
    Addr: TInAddr;
    FS: TFDSet;
    TV: TTimeVal;
    SoErr, L: LongInt;
    Raw: FdComPtr;
    Tel: TelnetComPtr;

  Begin
  ConnectTcp := Nil;
  Err := '';
  If Not Resolve(Host, Addr) Then
    Begin
    Err := 'Unknown host ' + Host;
    Exit;
    End;
  Fd := fpSocket(AF_INET, SOCK_STREAM, 0);
  If Fd < 0 Then
    Begin
    Err := 'Cannot make a socket';
    Exit;
    End;
  Flags := fpFcntl(Fd, F_GETFL);
  fpFcntl(Fd, F_SETFL, Flags Or O_NONBLOCK);
  FillChar(A, SizeOf(A), 0);
  A.sin_family := AF_INET;
  A.sin_port := htons(Port);
  A.sin_addr := Addr;
  Res := fpConnect(Fd, @A, SizeOf(A));
  If (Res < 0) And (fpGetErrno <> ESysEINPROGRESS) Then
    Begin
    Err := 'Cannot connect to ' + Host + ':' + IntToStr(Port);
    fpClose(Fd);
    Exit;
    End;
  If Res < 0 Then
    Begin
    fpFD_ZERO(FS);
    fpFD_SET(Fd, FS);
    TV.tv_sec := TimeoutMs Div 1000;
    TV.tv_usec := (TimeoutMs Mod 1000) * 1000;
    Res := fpSelect(Fd + 1, Nil, @FS, Nil, @TV);
    If Res <= 0 Then
      Begin
      Err := 'No answer from ' + Host + ':' + IntToStr(Port);
      fpClose(Fd);
      Exit;
      End;
    SoErr := 0;
    L := SizeOf(SoErr);
    fpGetSockOpt(Fd, SOL_SOCKET, SO_ERROR, @SoErr, @L);
    If SoErr <> 0 Then
      Begin
      If SoErr = ESysECONNREFUSED Then
        Err := 'Connection refused by ' + Host + ':' + IntToStr(Port)
      Else
        Err := 'Cannot connect to ' + Host + ':' + IntToStr(Port) + ' (error ' + IntToStr(SoErr) + ')';
      fpClose(Fd);
      Exit;
      End;
    End;
  fpFcntl(Fd, F_SETFL, Flags);                  {blocking again: the session waits with select}
  New(Raw, InitFd(Fd, Fd));
  Raw^.SetRemoteAddr(Host + ':' + IntToStr(Port));
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
