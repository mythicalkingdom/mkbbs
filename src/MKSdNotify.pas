Unit MKSdNotify;   {systemd's sd_notify: READY=1, WATCHDOG=1, STATUS=..., STOPPING=1 on the socket named by NOTIFY_SOCKET}

{$mode objfpc}{$H+}

{
  Nothing happens when NOTIFY_SOCKET is not set (mklisten started by hand, or by a unit of Type=simple).  The watchdog interval is WATCHDOG_USEC (set by systemd when the unit has
  WatchdogSec=; ignored when WATCHDOG_PID names another process).  The caller sends the heartbeat at half of that time or more often.
}

Interface

Function SdNotify(Const Msg: String): Boolean;           {False: no socket, or it did not take the message}
Function SdActive: Boolean;                              {NOTIFY_SOCKET is set}
Function SdWatchdogMs: Int64;                            {the watchdog interval in milliseconds; 0: none}

Implementation

Uses SysUtils, BaseUnix, Sockets;


Function SdActive: Boolean;
  Begin
  Result := GetEnvironmentVariable('NOTIFY_SOCKET') <> '';
  End;


Function SdNotify(Const Msg: String): Boolean;
  Var
    Path: String;
    A: TUnixSockAddr;
    S: LongInt;
    Len: Integer;

  Begin
  Result := False;
  Path := GetEnvironmentVariable('NOTIFY_SOCKET');
  If (Path = '') Or (Length(Path) >= SizeOf(A.path)) Or ((Path[1] <> '/') And (Path[1] <> '@')) Then
    Exit;
  FillChar(A, SizeOf(A), 0);
  A.family := AF_UNIX;
  Move(Path[1], A.path, Length(Path));
  If Path[1] = '@' Then
    A.path[0] := #0;                      {an abstract socket}
  Len := SizeOf(A.family) + Length(Path);
  S := fpSocket(AF_UNIX, SOCK_DGRAM, 0);
  If S < 0 Then
    Exit;
  Result := fpSendTo(S, @Msg[1], Length(Msg), MSG_NOSIGNAL, @A, Len) = Length(Msg);
  fpClose(S);
  End;


Function SdWatchdogMs: Int64;
  Var
    Us: Int64;
    P: String;

  Begin
  Result := 0;
  Us := StrToInt64Def(GetEnvironmentVariable('WATCHDOG_USEC'), 0);
  If Us <= 0 Then
    Exit;
  P := GetEnvironmentVariable('WATCHDOG_PID');
  If (P <> '') And (StrToInt64Def(P, -1) <> fpGetPid) Then
    Exit;
  Result := Us Div 1000;
  End;


End.
