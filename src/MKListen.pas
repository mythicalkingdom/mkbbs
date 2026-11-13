Program MKListen;

{$MODE OBJFPC}
{$H+}
{$WARN SYMBOL_DEPRECATED OFF}

(*
     mklisten - accepts callers on TCP ports and starts one "mk" per caller.

        mklisten [-f] [-d] [-t] [-c configfile]

          -c file   JSON configuration (default /etc/mkbbs/mklisten.json)
          -f        stay in the foreground and also log to the terminal (default)
          -d        become a daemon (fork, setsid, stdio to /dev/null)
          -t        check the configuration and exit

     The caller's connection becomes standard input and output of mk, which is
     started as

        mk -N<node> -S<type> [-B<baud>] [-H] -A<address> [extra words from "args"]

     with the environment of the listener plus the "env" lines of the port (the
     BBS configuration directory is "config", i.e. env MK=...).  One process per
     caller: nothing is shared between callers except the files on disk.

     Configuration file: one JSON object (no comments; keys starting with "_"
     are ignored, handy for notes).  Top level keys are global, "ports" is a list
     of port objects that start from the global "nodes" and "maxperip":

        {
          "mk":       "/usr/local/bin/mk",     program to start
          "user":     "mkbbs",                 drop to this user after binding
          "group":    "mkbbs",                 ... and this group
          "logfile":  "/var/log/mkbbs/listen.log",
          "pidfile":  "/var/run/mklisten.pid",
          "workdir":  "/bbs",                  current directory of mk
          "nodes":    "1-8",                   node numbers handed out (N, "N-M" or [N, M])
          "maxperip": 3,                       callers per address on a port (0 = any)
          "busy":     "All lines are busy.",   sent when no node is free
          "ports": [
            { "port": 2323,                    required
              "type": "telnet",                "telnet" | "raw" | "ws"
              "baud": 2400,                    emulated speed, 0 = full speed
              "bind": "0.0.0.0",               address to listen on (IPv4)
              "nodes": "1-4",                  nodes for this port
              "maxperip": 2,
              "config": "/bbs/mk",             same as "env": {"MK": "/bbs/mk"}
              "env":  { "NAME": "value" },     more environment
              "args": ["-L", "-X"],            extra words for the command line
              "proxy": true }                  PROXY header from stunnel comes
                                               first; needs "bind": "127.0.0.1"
          ]
        }

     "stype" is accepted for "type" (the name the JavaScript BBS used).

     Sysop monitor: a port of "type": "sysop" is not a caller.  Whoever connects
     (Telnet, localhost only: use ssh port forwarding to reach it from outside)
     gets mkmon, which asks for the "password" of the port, shows the nodes
     with their user, activity, address and start time and lets the sysop watch,
     type into, disconnect or give or take time from
     (snoop) a node.  "mkmon" names the program (default: next to mk).

          { "port": 2330, "type": "sysop", "bind": "127.0.0.1",
            "password": "secret", "config": "/bbs/mk" }

     "password" is the text itself, or "sha1:" and the lower case hex digest of
     it.  To let mkmon see the nodes, the listener keeps a directory "rundir"
     (default /tmp/mklisten-<uid>, mode 0700) with node<N>.info (written here)
     and node<N>.snoop (the Unix socket mk opens; environment MKRUN tells mk).

     TLS (telnets, wss): let stunnel terminate it and connect to a local port of
     this program, with "protocol = proxy" in the stunnel service and
     "bind": "127.0.0.1" / "proxy": true on the port, e.g.

        stunnel:   [mkbbs-wss]  accept = 443  connect = 127.0.0.1:2325
                                cert = ...  key = ...  protocol = proxy
        mklisten:  { "port": 2325, "type": "ws", "bind": "127.0.0.1", "proxy": true }

     SIGTERM / SIGINT stop the listener; callers already connected keep running.
*)

Uses
  BaseUnix, Sockets, Users, SysUtils, Classes, fpjson, jsonparser;


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
    Sysop: Boolean;
    Password: String;
    Fd: LongInt;
    End;

  TChild = Record
    Pid: TPid;
    Node: Integer;
    PortNo: Integer;
    Addr: String;
    Started: LongInt;
    End;


Function c_setgroups(N: PtrUInt; List: Pointer): cInt; cdecl; external 'c' name 'setgroups';


Var
  CfgFile: String = '/etc/mkbbs/mklisten.json';
  Foreground: Boolean = True;
  TestOnly: Boolean = False;
  MkPath: String = 'mk';
  MonPath: String = '';
  RunDir: String = '';
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


Procedure ParseNodes(D: TJSONData; Var F, L: Integer; Where: String);
  {"nodes": 3   or   "nodes": "1-4"   or   "nodes": [1, 4]}
  Var
    S: String;
    p: Integer;

  Begin
  F := -1;
  L := -1;
  If D.JSONType = jtNumber Then
    Begin
    F := D.AsInteger;
    L := F;
    End
  Else If D.JSONType = jtString Then
    Begin
    S := D.AsString;
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
    End
  Else If (D.JSONType = jtArray) And (D.Count = 2) Then
    Begin
    F := D.Items[0].AsInteger;
    L := D.Items[1].AsInteger;
    End;
  If (F < 1) Or (L < F) Or (L > 255) Then
    Die(Where + ': "nodes" must be N, "N-M" or [N, M] within 1..255');
  End;


Function JStr(D: TJSONData; Where: String): String;
  Begin
  If D.JSONType <> jtString Then
    Die(Where + ' must be a string');
  JStr := D.AsString;
  End;


Function JInt(D: TJSONData; Where: String; Min, Max: LongInt): LongInt;
  Begin
  If D.JSONType <> jtNumber Then
    Die(Where + ' must be a number');
  JInt := D.AsInteger;
  If (JInt < Min) Or (JInt > Max) Then
    Die(Where + ' must be between ' + IntToStr(Min) + ' and ' + IntToStr(Max));
  End;


Function JBool(D: TJSONData; Where: String): Boolean;
  Begin
  If D.JSONType <> jtBoolean Then
    Die(Where + ' must be true or false');
  JBool := D.AsBoolean;
  End;


Procedure LoadPort(O: TJSONObject; Idx: Integer);
  Var
    P: TPort;
    i, j: Integer;
    Key, Where: String;
    V: TJSONData;
    E: TJSONObject;

  Begin
  Where := 'ports[' + IntToStr(Idx) + ']';
  P.Port := 0;
  P.SType := 'telnet';
  P.Baud := 0;
  P.Bind := '0.0.0.0';
  P.First := GFirst;
  P.Last := GLast;
  P.MaxPerIp := GMaxPerIp;
  P.Env := TStringList.Create;
  P.Args := '';
  P.Proxy := False;
  P.Sysop := False;
  P.Password := '';
  P.Fd := -1;
  For i := 0 To O.Count - 1 Do
    Begin
    Key := LowerCase(O.Names[i]);
    V := O.Items[i];
    If Key = 'port' Then
      P.Port := JInt(V, Where + '.port', 1, 65535)
    Else If (Key = 'type') Or (Key = 'stype') Then
      Begin
      P.SType := LowerCase(JStr(V, Where + '.type'));
      If P.SType = 'sysop' Then
        Begin
        P.Sysop := True;
        P.SType := 'telnet';
        End
      Else If (P.SType <> 'telnet') And (P.SType <> 'raw') And (P.SType <> 'ws') Then
        Die(Where + '.type must be "telnet", "raw", "ws" or "sysop" (TLS: put stunnel in front)');
      End
    Else If Key = 'baud' Then
      P.Baud := JInt(V, Where + '.baud', 0, 1000000)
    Else If Key = 'bind' Then
      P.Bind := JStr(V, Where + '.bind')
    Else If Key = 'nodes' Then
      ParseNodes(V, P.First, P.Last, Where)
    Else If Key = 'maxperip' Then
      P.MaxPerIp := JInt(V, Where + '.maxperip', 0, 1000)
    Else If Key = 'config' Then
      P.Env.Add('MK=' + JStr(V, Where + '.config'))
    Else If Key = 'proxy' Then
      P.Proxy := JBool(V, Where + '.proxy')
    Else If Key = 'password' Then
      P.Password := JStr(V, Where + '.password')
    Else If Key = 'env' Then
      Begin
      If V.JSONType <> jtObject Then
        Die(Where + '.env must be an object {"NAME": "value"}');
      E := TJSONObject(V);
      For j := 0 To E.Count - 1 Do
        P.Env.Add(E.Names[j] + '=' + JStr(E.Items[j], Where + '.env.' + E.Names[j]));
      End
    Else If Key = 'args' Then
      Begin
      If V.JSONType = jtString Then
        P.Args := V.AsString
      Else If V.JSONType = jtArray Then
        Begin
        P.Args := '';
        For j := 0 To V.Count - 1 Do
          P.Args := P.Args + ' ' + JStr(V.Items[j], Where + '.args');
        End
      Else
        Die(Where + '.args must be a string or an array of strings');
      End
    Else If Copy(Key, 1, 1) <> '_' Then
      Die(Where + ': unknown key "' + O.Names[i] + '"');
    End;
  If P.Port = 0 Then
    Die(Where + ' has no "port"');
  If P.Proxy And (P.Bind <> '127.0.0.1') Then
    Die('port ' + IntToStr(P.Port) +
      ': "proxy": true needs "bind": "127.0.0.1" (anyone able to connect could fake an address)');
  If P.Sysop Then
    Begin
    If P.Bind <> '127.0.0.1' Then
      Die('port ' + IntToStr(P.Port) +
        ': a sysop port must have "bind": "127.0.0.1" (reach it with ssh port forwarding)');
    If P.Password = '' Then
      Die('port ' + IntToStr(P.Port) + ': a sysop port needs a "password"');
    If P.MaxPerIp = 0 Then
      P.MaxPerIp := 2;
    End;
  SetLength(Ports, Length(Ports) + 1);
  Ports[High(Ports)] := P;
  End;


Procedure LoadConfig;
  Var
    Src: TFileStream;
    Parser: TJSONParser;
    Root: TJSONData;
    O: TJSONObject;
    i: Integer;
    Key: String;
    V: TJSONData;

  Begin
  If Not FileExists(CfgFile) Then
    Die('cannot read ' + CfgFile);
  Src := TFileStream.Create(CfgFile, fmOpenRead Or fmShareDenyNone);
  Parser := TJSONParser.Create(Src, True);
  Try
    Try
      Root := Parser.Parse;
    Except
      On E: Exception Do
        Die(CfgFile + ': not valid JSON (' + E.Message + ')');
    End;
  Finally
    Parser.Free;
    Src.Free;
  End;
  If (Root = Nil) Or (Root.JSONType <> jtObject) Then
    Die(CfgFile + ': the top level must be a JSON object');
  O := TJSONObject(Root);
  { global settings first: ports take their defaults from them }
  For i := 0 To O.Count - 1 Do
    Begin
    Key := LowerCase(O.Names[i]);
    V := O.Items[i];
    If Key = 'mk' Then MkPath := JStr(V, 'mk')
    Else If Key = 'mkmon' Then MonPath := JStr(V, 'mkmon')
    Else If Key = 'rundir' Then RunDir := JStr(V, 'rundir')
    Else If Key = 'user' Then RunUser := JStr(V, 'user')
    Else If Key = 'group' Then RunGroup := JStr(V, 'group')
    Else If Key = 'logfile' Then LogPath := JStr(V, 'logfile')
    Else If Key = 'pidfile' Then PidPath := JStr(V, 'pidfile')
    Else If Key = 'workdir' Then WorkDir := JStr(V, 'workdir')
    Else If Key = 'busy' Then BusyMsg := JStr(V, 'busy')
    Else If Key = 'nodes' Then ParseNodes(V, GFirst, GLast, 'nodes')
    Else If Key = 'maxperip' Then GMaxPerIp := JInt(V, 'maxperip', 0, 1000)
    Else If Key = 'ports' Then
      Begin
      If V.JSONType <> jtArray Then
        Die('"ports" must be an array');
      End
    Else If Copy(Key, 1, 1) <> '_' Then
      Die(CfgFile + ': unknown key "' + O.Names[i] + '"');
    End;
  V := O.Find('ports');
  If (V = Nil) Or (V.Count = 0) Then
    Die(CfgFile + ': no ports defined ("ports": [ ... ])');
  For i := 0 To V.Count - 1 Do
    Begin
    If V.Items[i].JSONType <> jtObject Then
      Die('ports[' + IntToStr(i) + '] must be an object');
    LoadPort(TJSONObject(V.Items[i]), i);
    End;
  Root.Free;
  If MonPath = '' Then
    MonPath := ExtractFilePath(MkPath) + 'mkmon';
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
    If Ports[i].Sysop Then
      Log('listening on ' + Ports[i].Bind + ':' + IntToStr(Ports[i].Port) + ' sysop monitor')
    Else
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


Procedure PrepareRunDir;
  {Own directory for the node files; whatever a previous run left is stale}
  Var
    SR: TSearchRec;

  Begin
  If RunDir = '' Then
    RunDir := '/tmp/mklisten-' + IntToStr(fpGetUid);
  If (Length(RunDir) > 1) And (RunDir[Length(RunDir)] = '/') Then
    SetLength(RunDir, Length(RunDir) - 1);
  fpMkdir(RunDir, &700);
  fpChmod(RunDir, &700);
  If FindFirst(RunDir + '/node*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      DeleteFile(RunDir + '/' + SR.Name);
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Log('node files in ' + RunDir);
  End;


Procedure WriteNodeInfo(Const C: TChild);
  Var
    L: TStringList;

  Begin
  L := TStringList.Create;
  Try
    L.Add('node=' + IntToStr(C.Node));
    L.Add('pid=' + IntToStr(C.Pid));
    L.Add('port=' + IntToStr(Ports[C.PortNo].Port));
    L.Add('type=' + Ports[C.PortNo].SType);
    L.Add('baud=' + IntToStr(Ports[C.PortNo].Baud));
    L.Add('addr=' + C.Addr);
    L.Add('start=' + IntToStr(C.Started));
    Try
      L.SaveToFile(RunDir + '/node' + IntToStr(C.Node) + '.info');
    Except
      Log('cannot write the node file in ' + RunDir);
    End;
  Finally
    L.Free;
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
        If Children[i].Node > 0 Then
          Begin
          Log('node ' + IntToStr(Children[i].Node) + ' ended (' + How + ') ' +
            Children[i].Addr);
          DeleteFile(RunDir + '/node' + IntToStr(Children[i].Node) + '.info');
          DeleteFile(RunDir + '/node' + IntToStr(Children[i].Node) + '.snoop');
          End
        Else
          Log('sysop monitor ended (' + How + ') ' + Children[i].Addr);
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
    Children[High(Children)].Started := fpTime;
    If Node > 0 Then
      WriteNodeInfo(Children[High(Children)]);
    If P.Sysop Then
      Log('sysop monitor on port ' + IntToStr(P.Port) + ' from ' + Addr + ' pid ' + IntToStr(Pid))
    Else
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
  If P.Sysop Then
    ArgS.Add(MonPath)
  Else
    Begin
    ArgS.Add(MkPath);
    ArgS.Add('-N' + IntToStr(Node));
    End;
  ArgS.Add('-S' + UpperCase(P.SType));
  If (P.Baud > 0) And (Not P.Sysop) Then
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
  EnvS.Add('MKRUN=' + RunDir);
  If P.Sysop Then
    EnvS.Add('MKMON_PASSWORD=' + P.Password);
  SetLength(Envv, EnvS.Count + 1);
  For i := 0 To EnvS.Count - 1 Do
    Envv[i] := PChar(EnvS[i]);
  Envv[EnvS.Count] := Nil;
  If P.Sysop Then
    fpExecve(MonPath, PPChar(@Argv[0]), PPChar(@Envv[0]))
  Else
    fpExecve(MkPath, PPChar(@Argv[0]), PPChar(@Envv[0]));
  Ch := fpGetErrno;
  W := 'mklisten: cannot start ' + Argv[0] + ' (error ' + IntToStr(Ch) + ')' + #10;
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
  If Ports[PortNo].Sysop Then
    Node := 0
  Else
    Node := FreeNode(Ports[PortNo]);
  If (Node = 0) And (Not Ports[PortNo].Sysop) Then
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
  PrepareRunDir;
  MainLoop;
  If PidPath <> '' Then
    DeleteFile(PidPath);
End.
