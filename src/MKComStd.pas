Unit MKComStd;   {Comm session on standard input / output}

{$I MKB.Def}

{
     A caller whose connection is the standard input and output of this
     process:
       - inetd / xinetd / systemd socket activation (raw TCP),
       - telnetd or sshd running the BBS as the login command or a forced
         command (stdin/stdout is then the pty of the session),
       - a sysop running the BBS by hand in a terminal (local mode).

     If standard input is a terminal it is put in raw mode while the session is
     open (no echo, no line editing, no CR/LF translation) and restored when it
     is closed.  Nothing here speaks the Telnet protocol: behind telnetd the
     pty has already done that; for raw telnet wrap this session in the Telnet
     filter (MKComTelnet).

     The stream handling itself lives in MKComFd; this unit adds the terminal
     handling and the address from the environment.
}

Interface

Uses MKComAbs, MKComFd;


Type StdComObj = Object(FdComObj)
  IsTty: Boolean;                      {Input is a terminal}
  RawOn: Boolean;                      {Terminal is in raw mode}
  Constructor Init;
  Function  OpenSession: Boolean; Virtual;
  Procedure CloseSession; Virtual;
  Procedure Hangup; Virtual;
  Function  GetCommInfo: String; Virtual;
  Function  GetRemoteAddr: String; Virtual;
  Procedure RestoreTty;                {Internal}
  End;


Type StdComPtr = ^StdComObj;


Implementation


{$IFDEF UNIX}

Uses BaseUnix, Termio, Dos;

Var
  SaveTio: Termios;


Constructor StdComObj.Init;
  Begin
  InitFd(0, 1);
  IsTty := False;
  RawOn := False;
  CloseFds := False;
  End;


Function StdComObj.OpenSession: Boolean;
  Var
    Tio: Termios;

  Begin
  Up := True;
  HavePeek := False;
  IsTty := (TCGetAttr(0, SaveTio) = 0);
  CloseFds := Not IsTty;                 {a socket: closing it drops the caller}
  If IsTty And (Not RawOn) Then
    Begin
    Tio := SaveTio;
    CFMakeRaw(Tio);
    Tio.c_cc[VMIN] := 0;
    Tio.c_cc[VTIME] := 0;
    If TCSetAttr(0, TCSANOW, Tio) = 0 Then
      RawOn := True;
    End;
  OpenSession := True;
  End;


Procedure StdComObj.RestoreTty;
  Begin
  If RawOn Then
    Begin
    TCSetAttr(0, TCSANOW, SaveTio);
    RawOn := False;
    End;
  End;


Procedure StdComObj.CloseSession;
  Begin
  FlushOut;
  RestoreTty;
  End;


Procedure StdComObj.Hangup;
  Begin
  RestoreTty;
  Inherited Hangup;
  End;


Function StdComObj.GetCommInfo: String;
  Begin
  If IsTty Then
    GetCommInfo := 'Terminal (standard input/output)'
  Else
    GetCommInfo := 'Standard input/output (socket or pipe)';
  End;


Function StdComObj.GetRemoteAddr: String;
  {Where the caller comes from, as far as the environment says}
  Var
    S: String;
    i: Word;

  Begin
  S := RemoteAddr;
  If S = '' Then S := GetEnv('SSH_CLIENT');
  If S = '' Then S := GetEnv('SSH_CONNECTION');
  If S = '' Then S := GetEnv('REMOTE_HOST');
  If S = '' Then S := GetEnv('REMOTE_ADDR');
  If S = '' Then S := GetEnv('TCPREMOTEIP');
  If S = '' Then S := GetEnv('SOCAT_PEERADDR');
  i := Pos(' ', S);
  If i > 0 Then
    S := Copy(S, 1, i - 1);              {SSH_CLIENT: "addr port port"}
  GetRemoteAddr := S;
  End;

{$ELSE}
{$ERROR MKComStd needs Unix standard input/output}
{$ENDIF}


End.
