Program MKBbsSsh;

{$I MKB.Def}

{
     mkbbsssh: the shell of the SSH account of the BBS (the account "bbs": ssh bbs@host).  The SSH daemon (OpenSSH or Dropbear, see SSH.md) does the
     encryption and lets the account in without a password; this program is what the account runs: it connects to the Telnet port of mklisten on this
     machine and passes the terminal through.  The caller then logs on to the BBS as for any other connection.

        mkbbsssh [-p port] [-h host] [-f conf]        (a login shell is also started as  mkbbsssh -c command: the command is ignored)

     What it does for the BBS: it sends a PROXY header first (the address of the caller from SSH_CONNECTION, so that the limits, the log and mkmon of mklisten
     see the real address; the port of mklisten has "proxy": true and "bind": "127.0.0.1"), then speaks Telnet to mklisten as a terminal: the terminal type
     (TERM) and the window size, and a new size when the window changes, are told by the Telnet options mk already understands.  The terminal of the SSH
     session is made raw: what the caller types goes through as it is, and the BBS does the echo.

     Settings: /etc/mkbbs/mkbbsssh.conf (MKBBSSSH_CONF names another file): lines  host 127.0.0.1  and  port 2327.  The command line overrides them.
}

Uses
  BaseUnix, termio, SysUtils, MKComAbs, MKComFd, MKComTelnet, MKComClient;

Var
  Host: String;
  Port: Word;
  ConfName: String;
  S: AbsComPtr;
  Tel: TelnetComPtr;
  Err: String;
  Saved, Raw: Termios;
  IsTty: Boolean;
  Winch: Boolean;
  Cols, Rows: Word;
  i: Integer;
  A: String;
  Buf: Array[0..4095] Of Byte;
  Out: Array[0..4095] Of Char;
  N, k: LongInt;
  P: Array[0..1] Of TPollFd;
  SockFd: LongInt;
  Done: Boolean;


Procedure OnWinch(Sig: cInt); cdecl;
  Begin
  Winch := True;
  End;


Procedure ReadConf(Name: String);
  Var
    T: Text;
    L, K: String;
    p, Code: Integer;
    V: LongInt;

  Begin
  Assign(T, Name);
  {$I-}
  Reset(T);
  {$I+}
  If IOResult <> 0 Then
    Exit;
  While Not Eof(T) Do
    Begin
    ReadLn(T, L);
    L := Trim(L);
    If (L = '') Or (L[1] = '#') Or (L[1] = ';') Then
      Continue;
    p := Pos(' ', L);
    If p = 0 Then
      Continue;
    K := LowerCase(Copy(L, 1, p - 1));
    L := Trim(Copy(L, p + 1, 200));
    If K = 'host' Then
      Host := L
    Else If K = 'port' Then
      Begin
      Val(L, V, Code);
      If (Code = 0) And (V > 0) And (V < 65536) Then
        Port := V;
      End;
    End;
  Close(T);
  End;


Function Preamble: String;
  {PROXY TCP4 <caller> <server> <caller port> <server port>, from SSH_CONNECTION ("caller cport server sport")}
  Var
    C, W: String;
    Parts: Array[1..4] Of String;
    n, p: Integer;
    Fam: String;

  Begin
  C := GetEnvironmentVariable('SSH_CONNECTION');
  n := 0;
  While (C <> '') And (n < 4) Do
    Begin
    p := Pos(' ', C);
    If p = 0 Then
      p := Length(C) + 1;
    W := Copy(C, 1, p - 1);
    Delete(C, 1, p);
    Inc(n);
    Parts[n] := W;
    End;
  If n < 4 Then
    Begin
    Preamble := 'PROXY UNKNOWN'#13#10;
    Exit;
    End;
  If Pos(':', Parts[1]) > 0 Then
    Fam := 'TCP6'
  Else
    Fam := 'TCP4';
  Preamble := 'PROXY ' + Fam + ' ' + Parts[1] + ' ' + Parts[3] + ' ' + Parts[2] + ' ' + Parts[4] + #13#10;
  End;


Procedure GetSize;
  Var
    W: TWinSize;

  Begin
  Cols := 80;
  Rows := 24;
  If IsTty Then
    If fpIoctl(0, TIOCGWINSZ, @W) = 0 Then
      If (W.ws_col > 0) And (W.ws_row > 0) Then
        Begin
        Cols := W.ws_col;
        Rows := W.ws_row;
        End;
  End;


Procedure Restore;
  Begin
  If IsTty Then
    TCSetAttr(0, TCSANOW, Saved);
  End;


Begin
Host := '127.0.0.1';
Port := 2327;
ConfName := GetEnvironmentVariable('MKBBSSSH_CONF');
If ConfName = '' Then
  ConfName := '/etc/mkbbs/mkbbsssh.conf';
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-f' Then
    Begin
    Inc(i);
    ConfName := ParamStr(i);
    End;
  Inc(i);
  End;
ReadConf(ConfName);
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-c' Then
    Inc(i)                              {the command the SSH daemon was given: ignored}
  Else If (A = '-p') And (i < ParamCount) Then
    Begin
    Inc(i);
    Port := StrToIntDef(ParamStr(i), Port);
    End
  Else If (A = '-h') And (i < ParamCount) Then
    Begin
    Inc(i);
    Host := ParamStr(i);
    End;
  Inc(i);
  End;
IsTty := TCGetAttr(0, Saved) = 0;
Winch := False;
GetSize;
ClientTerm := GetEnvironmentVariable('TERM');
If ClientTerm = '' Then
  ClientTerm := 'ansi';
ClientCols := Cols;
ClientRows := Rows;
ClientPreamble := Preamble;
S := ConnectTcp(Host, Port, 5000, True, Err);
If S = Nil Then
  Begin
  WriteLn('The BBS is not available now. Please try again later.');
  Halt(1);
  End;
Tel := TelnetComPtr(S);
SockFd := FdComPtr(Tel^.Inner)^.InFd;
If IsTty Then
  Begin
  Raw := Saved;
  CFMakeRaw(Raw);
  TCSetAttr(0, TCSANOW, Raw);
  fpSignal(SIGWINCH, SignalHandler(OnWinch));
  End;
fpSignal(SIGPIPE, SignalHandler(SIG_IGN));
Done := False;
While Not Done Do
  Begin
  If Winch Then
    Begin
    Winch := False;
    GetSize;
    Tel^.Resize(Cols, Rows);
    End;
  { what the BBS says }
  k := 0;
  While (Not S^.InEmpty) And (k < SizeOf(Out)) Do
    Begin
    Out[k] := S^.GetChar;
    Inc(k);
    End;
  If k > 0 Then
    fpWrite(1, Out, k);
  If Not S^.GetCarrier Then
    Break;
  If Not S^.InEmpty Then
    Continue;
  P[0].fd := 0;
  P[0].events := POLLIN;
  P[0].revents := 0;
  P[1].fd := SockFd;
  P[1].events := POLLIN;
  P[1].revents := 0;
  N := fpPoll(@P, 2, 1000);
  If N < 0 Then
    Continue;                           {a signal: the window changed}
  If (P[0].revents And (POLLIN Or POLLHUP Or POLLERR)) <> 0 Then
    Begin
    N := fpRead(0, Buf, SizeOf(Buf));
    If N <= 0 Then
      Done := True
    Else
      Begin
      For k := 0 To N - 1 Do
        S^.SendChar(Chr(Buf[k]));
      S^.FlushOut;
      End;
    End;
  If (P[1].revents And (POLLERR Or POLLHUP)) <> 0 Then
    Begin
    If S^.InEmpty Then
      Done := True;
    End;
  End;
Restore;
Dispose(S, Done);
End.
