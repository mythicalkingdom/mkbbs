Program MKListen;

{$MODE OBJFPC}
{$H+}

{
     mklisten - accepts callers on TCP ports and starts one "mk" per caller.

        mklisten [-f] [-d] [-t] [-c configfile]

          -c file   configuration (default /etc/mkbbs/mklisten.cfg)
          -f        stay in the foreground and also log to the terminal (default)
          -d        become a daemon (fork, setsid, stdio to /dev/null)
          -t        check the configuration and exit

     The caller's connection becomes standard input and output of mk, which is
     started as

        mk -N<node> -S<type> [-B<baud>] [-H] -A<address> [extra words from "args"]

     with the environment of the listener plus the "env" lines of the port (the
     BBS configuration directory is "config", i.e. env MK=...).  One process per
     caller: nothing is shared between callers except the files on disk.

     Configuration file (blank lines and # ; comments ignored; keys before the
     first "port" line are global, the ones after it belong to that port):

        mk        /usr/local/bin/mk       program to start (global)
        user      mkbbs                   drop to this user after binding (global)
        group     mkbbs                   ... and this group (global)
        logfile   /var/log/mkbbs/listen.log
        pidfile   /var/run/mklisten.pid
        workdir   /bbs                    current directory of mk (global)
        nodes     1-8                     node numbers handed out (global default)
        maxperip  3                       simultaneous callers per address on a port (0 = any)
        busy      All lines are busy.     sent to a caller when no node is free

        port      2323                    start of a port block
        type      telnet                  telnet | raw | ws   (TLS: stunnel in front)
        baud      2400                    emulated speed, 0 = full speed
        bind      0.0.0.0                 address to listen on (IPv4)
        proxy     yes                     a PROXY protocol header (stunnel) comes
                                          first and gives the caller's address;
                                          needs "bind 127.0.0.1" on the same port
        nodes     1-4                     nodes for this port
        maxperip  2
        config    /bbs/mk                 same as  env MK=/bbs/mk
        env       NAME=VALUE              more environment (repeat)
        args      -L -X                   extra words for the command line

     TLS (telnets, wss): let stunnel terminate it and connect to a local port of
     this program, with "protocol = proxy" in the stunnel service and
     "bind 127.0.0.1" / "proxy yes" on the port, e.g.

        stunnel:   [mkbbs-wss]  accept = 443  connect = 127.0.0.1:2325
                                cert = ...  key = ...  protocol = proxy
        mklisten:  port 2325  /  type ws  /  bind 127.0.0.1  /  proxy yes

     SIGTERM / SIGINT stop the listener; callers already connected keep running.
}

Uses
  BaseUnix, Sockets, Users, SysUtils, Classes;


Type
  TPort = Record
    Port: Word;
    SType: String;
    Baud: LongInt;
    Bind: String;
    First, Last: Integer;
    MaxPerIp: Integer;
    Env: TStringList;
    Args: String;
    Proxy: Boolean;
    Fd: LongInt;
    End;

  TChild = Record
    Pid: TPid;
    Node: Integer;
    PortNo: Integer;
    Addr: String;
    End;


Function c_setgroups(N: PtrUInt; List: Pointer): cInt; cdecl; external 'c' name 'setgroups';


Var
  CfgFile: String = '/etc/mkbbs/mklisten.cfg';
  Foreground: Boolean = True;
  TestOnly: Boolean = False;
  MkPath: String = 'mk';
  RunUser, RunGroup: String;
  LogPath, PidPath, WorkDir: String;
  BusyMsg: String = 'Sorry, all lines are busy. Please try again later.';
  GFirst: Integer = 1;
  GLast: Integer = 8;
  GMaxPerIp: Integer = 0;
  Ports: Array Of TPort;
  Children: Array Of TChild;
  LogFd: LongInt = -1;
  Stopping: Boolean = False;


Procedure Log(Msg: String);
  Var
    Line: String;

  Begin
  Line := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + Msg + #10;
  If LogFd >= 0 Then
    fpWrite(LogFd, Line[1], Length(Line));
  If Foreground Then
    Write(Line);
  End;


Procedure Die(Msg: String);
  Begin
  WriteLn(StdErr, 'mklisten: ' + Msg);
  Halt(2);
  End;


Procedure ParseNodes(S: String; Var F, L: Integer; Where: String);
  Var
    p: Integer;

  Begin
  p := Pos('-', S);
  If p = 0 Then
    Begin
    F := StrToIntDef(S, -1);
    L := F;
    End
  Else
    Begin
    F := StrToIntDef(Copy(S, 1, p - 1), -1);
    L := StrToIntDef(Copy(S, p + 1, 20), -1);
    End;
  If (F < 1) Or (L < F) Or (L > 255) Then
    Die(Where + ': nodes must be N or N-M within 1..255');
  End;


Procedure LoadConfig;
  Var
    T: TStringList;
    i, p, Cur: Integer;
    Line, Key, Val, Where: String;

  Begin
  If Not FileExists(CfgFile) Then
    Die('cannot read ' + CfgFile);
  T := TStringList.Create;
  T.LoadFromFile(CfgFile);
  Cur := -1;
  For i := 0 To T.Count - 1 Do
    Begin
    Line := T[i];
    p := Pos('#', Line);
    If p > 0 Then
      Line := Copy(Line, 1, p - 1);
    p := Pos(';', Line);
    If p > 0 Then
      Line := Copy(Line, 1, p - 1);
    Line := Trim(Line);
    If Line = '' Then
      Continue;
    Where := CfgFile + ' line ' + IntToStr(i + 1);
    p := Pos(' ', Line);
    If p = 0 Then
      p := Pos(#9, Line);
    If p = 0 Then
      Begin
      Key := LowerCase(Line);
      Val := '';
      End
    Else
      Begin
      Key := LowerCase(Copy(Line, 1, p - 1));
      Val := Trim(Copy(Line, p + 1, 1000));
      End;
    If Key = 'port' Then
      Begin
      If (StrToIntDef(Val, 0) < 1) Or (StrToIntDef(Val, 0) > 65535) Then
        Die(Where + ': bad port number');
      Cur := Length(Ports);
      SetLength(Ports, Cur + 1);
      Ports[Cur].Port := StrToInt(Val);
      Ports[Cur].SType := 'telnet';
      Ports[Cur].Baud := 0;
      Ports[Cur].Bind := '0.0.0.0';
      Ports[Cur].First := GFirst;
      Ports[Cur].Last := GLast;
      Ports[Cur].MaxPerIp := GMaxPerIp;
      Ports[Cur].Env := TStringList.Create;
      Ports[Cur].Args := '';
      Ports[Cur].Proxy := False;
      Ports[Cur].Fd := -1;
      End
    Else If Cur < 0 Then
      Begin                              {global keys}
      If Key = 'mk' Then MkPath := Val
      Else If Key = 'user' Then RunUser := Val
      Else If Key = 'group' Then RunGroup := Val
      Else If Key = 'logfile' Then LogPath := Val
      Else If Key = 'pidfile' Then PidPath := Val
      Else If Key = 'workdir' Then WorkDir := Val
      Else If Key = 'busy' Then BusyMsg := Val
      Else If Key = 'nodes' Then ParseNodes(Val, GFirst, GLast, Where)
      Else If Key = 'maxperip' Then GMaxPerIp := StrToIntDef(Val, 0)
      Else Die(Where + ': unknown global key "' + Key + '"');
      End
    Else
      Begin                              {port keys}
      If Key = 'type' Then
        Begin
        Ports[Cur].SType := LowerCase(Val);
        If (Ports[Cur].SType <> 'telnet') And (Ports[Cur].SType <> 'raw') And
           (Ports[Cur].SType <> 'ws') Then
          Die(Where + ': type must be telnet, raw or ws (TLS: put stunnel in front)');
        End
      Else If Key = 'baud' Then
        Begin
        Ports[Cur].Baud := StrToIntDef(Val, -1);
        If Ports[Cur].Baud < 0 Then
          Die(Where + ': bad baud');
        End
      Else If Key = 'bind' Then Ports[Cur].Bind := Val
      Else If Key = 'nodes' Then ParseNodes(Val, Ports[Cur].First, Ports[Cur].Last, Where)
      Else If Key = 'maxperip' Then Ports[Cur].MaxPerIp := StrToIntDef(Val, 0)
      Else If Key = 'config' Then Ports[Cur].Env.Add('MK=' + Val)
      Else If Key = 'env' Then
        Begin
        If Pos('=', Val) < 2 Then
          Die(Where + ': env needs NAME=VALUE');
        Ports[Cur].Env.Add(Val);
        End
      Else If Key = 'proxy' Then
        Begin
        Ports[Cur].Proxy := (LowerCase(Val) = 'yes') Or (LowerCase(Val) = 'on') Or (Val = '1');
        End
      Else If Key = 'args' Then Ports[Cur].Args := Val
      Else Die(Where + ': unknown port key "' + Key + '"');
      End;
    End;
  T.Free;
  If Length(Ports) = 0 Then
    Die(CfgFile + ': no port defined');
  For i := 0 To High(Ports) Do
    If Ports[i].Proxy And (Ports[i].Bind <> '127.0.0.1') Then
      Die('port ' + IntToStr(Ports[i].Port) +
        ': proxy yes needs bind 127.0.0.1 (anyone able to connect could fake an address)');
  End;


Procedure OpenListeners;
  Var
    i: Integer;
    S: LongInt;
    A: TInetSockAddr;
    One: LongInt;

  Begin
  For i := 0 To High(Ports) Do
    Begin
    S := fpSocket(AF_INET, SOCK_STREAM, 0);
    If S < 0 Then
      Die('socket: error ' + IntToStr(fpGetErrno));
    One := 1;
    fpSetSockOpt(S, SOL_SOCKET, SO_REUSEADDR, @One, SizeOf(One));
    FillChar(A, SizeOf(A), 0);
    A.sin_family := AF_INET;
    A.sin_port := htons(Ports[i].Port);
    A.sin_addr := StrToNetAddr(Ports[i].Bind);
    If (A.sin_addr.s_addr = 0) And (Ports[i].Bind <> '0.0.0.0') Then
      Die('bad bind address ' + Ports[i].Bind);
    If fpBind(S, @A, SizeOf(A)) <> 0 Then
      Die('cannot bind ' + Ports[i].Bind + ':' + IntToStr(Ports[i].Port) + ' (error ' +
        IntToStr(fpGetErrno) + ')');
    If fpListen(S, 16) <> 0 Then
      Die('listen: error ' + IntToStr(fpGetErrno));
    Ports[i].Fd := S;
    Log('listening on ' + Ports[i].Bind + ':' + IntToStr(Ports[i].Port) + ' ' +
      Ports[i].SType + ' baud ' + IntToStr(Ports[i].Baud) + ' nodes ' +
      IntToStr(Ports[i].First) + '-' + IntToStr(Ports[i].Last));
    End;
  End;


Procedure DropPrivileges;
  Var
    Uid: TUid;
    Gid: TGid;

  Begin
  If (RunUser = '') And (RunGroup = '') Then
    Exit;
  If fpGetUid <> 0 Then
    Begin
    Log('not root: cannot switch to user/group, continuing as uid ' + IntToStr(fpGetUid));
    Exit;
    End;
  If RunGroup <> '' Then
    Begin
    Gid := GetGroupID(RunGroup);
    If Gid = TGid(-1) Then
      Die('unknown group ' + RunGroup);
    If (fpSetGid(Gid) <> 0) Then
      Die('setgid failed');
    End;
  If RunUser <> '' Then
    Begin
    Uid := GetUserID(RunUser);
    If Uid = TUid(-1) Then
      Die('unknown user ' + RunUser);
    If RunGroup = '' Then
      Begin                              {no group given: the group named like the user}
      Gid := GetGroupID(RunUser);
      If Gid <> TGid(-1) Then
        fpSetGid(Gid);
      End;
    c_setgroups(0, Nil);                 {no supplementary groups of root}
    If fpSetUid(Uid) <> 0 Then
      Die('setuid failed');
    End;
  Log('running as uid ' + IntToStr(fpGetUid) + ' gid ' + IntToStr(fpGetGid));
  End;


Procedure Daemonize;
  Var
    Pid: TPid;
    Null: LongInt;

  Begin
  Pid := fpFork;
  If Pid < 0 Then
    Die('fork failed');
  If Pid > 0 Then
    fpExit(0);
  fpSetsid;
  Null := fpOpen('/dev/null', O_RDWR);
  If Null >= 0 Then
    Begin
    fpDup2(Null, 0);
    fpDup2(Null, 1);
    fpDup2(Null, 2);
    If Null > 2 Then
      fpClose(Null);
    End;
  End;


Function NodeInUse(N: Integer): Boolean;
  Var
    i: Integer;

  Begin
  NodeInUse := False;
  For i := 0 To High(Children) Do
    If Children[i].Node = N Then
      NodeInUse := True;
  End;


Function FreeNode(Const P: TPort): Integer;
  Var
    N: Integer;

  Begin
  FreeNode := 0;
  For N := P.First To P.Last Do
    If Not NodeInUse(N) Then
      Begin
      FreeNode := N;
      Exit;
      End;
  End;


Function CountFrom(PortNo: Integer; Const Addr: String): Integer;
  Var
    i: Integer;

  Begin
  CountFrom := 0;
  For i := 0 To High(Children) Do
    If (Children[i].Addr = Addr) And (Children[i].PortNo = PortNo) Then
      Inc(CountFrom);
  End;


Procedure ReapChildren;
  Var
    Pid: TPid;
    Status: cInt;
    i, j: Integer;
    How: String;

  Begin
  Repeat
    Pid := fpWaitPid(-1, @Status, WNOHANG);
    If Pid <= 0 Then
      Exit;
    For i := 0 To High(Children) Do
      If Children[i].Pid = Pid Then
        Begin
        If wifexited(Status) Then
          How := 'exit ' + IntToStr(wexitstatus(Status))
        Else
          How := 'signal ' + IntToStr(wtermsig(Status));
        Log('node ' + IntToStr(Children[i].Node) + ' ended (' + How + ') ' +
          Children[i].Addr);
        For j := i To High(Children) - 1 Do
          Children[j] := Children[j + 1];
        SetLength(Children, Length(Children) - 1);
        Break;
        End;
  Until False;
  End;


Procedure StartChild(Client: LongInt; PortNo, Node: Integer; Const Addr: String);
  Var
    Pid: TPid;
    P: TPort;
    Argv, Envv: Array Of PChar;
    ArgS, EnvS: TStringList;
    i, j, k: Integer;
    Name: String;
    W: String;
    Over: Boolean;
    Ch: Integer;

  Begin
  P := Ports[PortNo];
  Pid := fpFork;
  If Pid < 0 Then
    Begin
    Log('fork failed, error ' + IntToStr(fpGetErrno));
    fpClose(Client);
    Exit;
    End;
  If Pid > 0 Then
    Begin
    fpClose(Client);
    SetLength(Children, Length(Children) + 1);
    Children[High(Children)].Pid := Pid;
    Children[High(Children)].Node := Node;
    Children[High(Children)].PortNo := PortNo;
    Children[High(Children)].Addr := Addr;
    Log('node ' + IntToStr(Node) + ' ' + P.SType + ':' + IntToStr(P.Port) + ' from ' +
      Addr + ' pid ' + IntToStr(Pid));
    Exit;
    End;
  { ---- the child ---- }
  For i := 0 To High(Ports) Do
    If Ports[i].Fd >= 0 Then
      fpClose(Ports[i].Fd);
  fpSetsid;
  fpDup2(Client, 0);
  fpDup2(Client, 1);
  If LogFd >= 0 Then
    fpDup2(LogFd, 2);
  If Client > 2 Then
    fpClose(Client);
  If (LogFd > 2) Then
    fpClose(LogFd);
  If WorkDir <> '' Then
    fpChdir(WorkDir);
  ArgS := TStringList.Create;
  ArgS.Add(MkPath);
  ArgS.Add('-N' + IntToStr(Node));
  ArgS.Add('-S' + UpperCase(P.SType));
  If P.Baud > 0 Then
    ArgS.Add('-B' + IntToStr(P.Baud));
  If P.Proxy Then
    ArgS.Add('-H');
  ArgS.Add('-A' + Addr);
  W := Trim(P.Args);
  While W <> '' Do
    Begin
    k := Pos(' ', W);
    If k = 0 Then
      k := Length(W) + 1;
    ArgS.Add(Copy(W, 1, k - 1));
    W := Trim(Copy(W, k + 1, 1000));
    End;
  SetLength(Argv, ArgS.Count + 1);
  For i := 0 To ArgS.Count - 1 Do
    Argv[i] := PChar(ArgS[i]);
  Argv[ArgS.Count] := Nil;
  EnvS := TStringList.Create;               {our environment, overridden by the port's}
  i := 0;
  While envp[i] <> Nil Do
    Begin
    W := StrPas(envp[i]);
    Over := False;
    Name := Copy(W, 1, Pos('=', W));
    For j := 0 To P.Env.Count - 1 Do
      If Copy(P.Env[j], 1, Length(Name)) = Name Then
        Over := True;
    If Not Over Then
      EnvS.Add(W);
    Inc(i);
    End;
  For j := 0 To P.Env.Count - 1 Do
    EnvS.Add(P.Env[j]);
  SetLength(Envv, EnvS.Count + 1);
  For i := 0 To EnvS.Count - 1 Do
    Envv[i] := PChar(EnvS[i]);
  Envv[EnvS.Count] := Nil;
  fpExecve(MkPath, PPChar(@Argv[0]), PPChar(@Envv[0]));
  Ch := fpGetErrno;
  W := 'mklisten: cannot start ' + MkPath + ' (error ' + IntToStr(Ch) + ')' + #10;
  fpWrite(2, W[1], Length(W));
  fpExit(127);
  End;


Procedure Refuse(Client: LongInt; Const Why: String; Const Addr: String);
  Var
    M: String;

  Begin
  Log('refused ' + Addr + ': ' + Why);
  M := #13#10 + BusyMsg + #13#10;
  fpWrite(Client, M[1], Length(M));
  fpShutdown(Client, 2);
  fpClose(Client);
  End;


Procedure Accept(PortNo: Integer);
  Var
    A: TInetSockAddr;
    L: TSockLen;
    C: LongInt;
    Addr: String;
    Node: Integer;

  Begin
  L := SizeOf(A);
  C := fpAccept(Ports[PortNo].Fd, @A, @L);
  If C < 0 Then
    Exit;
  Addr := NetAddrToStr(A.sin_addr);
  If (Ports[PortNo].MaxPerIp > 0) And (CountFrom(PortNo, Addr) >= Ports[PortNo].MaxPerIp) Then
    Begin
    Refuse(C, 'too many callers from this address', Addr);
    Exit;
    End;
  Node := FreeNode(Ports[PortNo]);
  If Node = 0 Then
    Begin
    Refuse(C, 'no free node on port ' + IntToStr(Ports[PortNo].Port), Addr);
    Exit;
    End;
  StartChild(C, PortNo, Node, Addr);
  End;


Procedure OnStop(Sig: cInt); cdecl;
  Begin
  Stopping := True;
  End;


Procedure OnChild(Sig: cInt); cdecl;
  Begin
  End;


Procedure MainLoop;
  Var
    Fds: Array Of TPollFd;
    i: Integer;
    R: cInt;

  Begin
  SetLength(Fds, Length(Ports));
  fpSignal(SIGTERM, @OnStop);
  fpSignal(SIGINT, @OnStop);
  fpSignal(SIGHUP, SignalHandler(SIG_IGN));
  fpSignal(SIGPIPE, SignalHandler(SIG_IGN));
  fpSignal(SIGCHLD, @OnChild);
  While Not Stopping Do
    Begin
    For i := 0 To High(Ports) Do
      Begin
      Fds[i].fd := Ports[i].Fd;
      Fds[i].events := POLLIN;
      Fds[i].revents := 0;
      End;
    R := fpPoll(@Fds[0], Length(Fds), 1000);
    ReapChildren;
    If R > 0 Then
      For i := 0 To High(Ports) Do
        If (Fds[i].revents And POLLIN) <> 0 Then
          Accept(i);
    End;
  Log('stopping (' + IntToStr(Length(Children)) + ' callers stay connected)');
  For i := 0 To High(Ports) Do
    fpClose(Ports[i].Fd);
  End;


Var
  i: Integer;
  S: String;
  F: Text;

Begin
  i := 1;
  While i <= ParamCount Do
    Begin
    S := ParamStr(i);
    If S = '-c' Then
      Begin
      Inc(i);
      If i > ParamCount Then
        Die('-c needs a file name');
      CfgFile := ParamStr(i);
      End
    Else If S = '-f' Then Foreground := True
    Else If S = '-d' Then Foreground := False
    Else If S = '-t' Then TestOnly := True
    Else
      Begin
      WriteLn('usage: mklisten [-f] [-d] [-t] [-c configfile]');
      Halt(2);
      End;
    Inc(i);
    End;
  LoadConfig;
  If TestOnly Then
    Begin
    WriteLn('mklisten: ', CfgFile, ' ok, ', Length(Ports), ' port(s)');
    Halt(0);
    End;
  If LogPath <> '' Then
    Begin
    LogFd := fpOpen(LogPath, O_WRONLY Or O_CREAT Or O_APPEND, &640);
    If LogFd < 0 Then
      Die('cannot open log file ' + LogPath);
    If (fpGetUid = 0) And (RunUser <> '') Then
      fpChown(LogPath, GetUserID(RunUser), TGid(-1));
    End;
  OpenListeners;
  If Not Foreground Then
    Daemonize;
  If PidPath <> '' Then
    Begin
    Assign(F, PidPath);
    {$I-}
    Rewrite(F);
    WriteLn(F, fpGetPid);
    Close(F);
    {$I+}
    If IOResult <> 0 Then ;
    End;
  DropPrivileges;
  MainLoop;
  If PidPath <> '' Then
    DeleteFile(PidPath);
End.
