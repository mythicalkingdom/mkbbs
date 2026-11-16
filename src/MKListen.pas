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
          "mk":       "/usr/local/bin/mk",     program to start (a name without a
                                               slash is looked up in PATH)
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
              "charset": "auto",               text for the caller: "auto" (CP437 DOS characters as UTF-8
                                               for terminals that show UTF-8: by the Telnet terminal
                                               type; web sockets are UTF-8), "cp437" (as sent) or "utf8"
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

     Mailer: the binkp mailer (mkbink, a separate project) can be run and watched by the listener.  Its
     settings are made from the BBS configuration (Mailer, Mailer Links, EchoMail Options in mkconfig) by
     mkbinkcfg, so there is nothing else to set up:

          "mailer": { "config": "/bbs/ra",             the BBS configuration directory (as "config" of a port)
                      "mkbink": "/usr/local/bin/mkbink",       (default: next to mk)
                      "mkbinkcfg": "/usr/local/bin/mkbinkcfg", (default: next to mk)
                      "settings": "/bbs/ra/mkbink.conf",       (default: mkbink.conf in "config")
                      "logfile": "/var/log/mkbbs/mkbink.log",  (default: the listener's log)
                      "interval": 30,                  seconds between looks for a changed configuration
                      "restart": 5 }                   seconds before a mailer that died is started again
                                                       (doubled while it keeps dying, at most 300)

     The listener runs mkbinkcfg at the start and whenever config.mk, echocfg.mk or mailer.mk changed (or
     SIGHUP arrives).  When the mailer is switched on in the configuration it starts mkbink (run -f settings);
     when the settings changed it sends mkbink SIGHUP (it reads them again, no call is cut off); when the
     mailer is switched off, or the listener stops, mkbink is stopped.  A mailer that dies is started again.
     Whatever happens to the listener (even SIGKILL) takes mkbink with it.

     SIGTERM / SIGINT stop the listener (and the mailer); callers already connected keep running.
     SIGHUP makes the mailer read its settings again.
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
    Charset: String;                   {auto, cp437 or utf8}
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
Function c_prctl(Option: cInt): cInt; cdecl; varargs; external 'c' name 'prctl';


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
  { the mailer }
  MailerOn: Boolean = False;           {a "mailer" section is in the configuration}
  MailBink, MailCfgTool, MailConfig, MailSettings, MailLogPath: String;
  MailInterval: Integer = 30;
  MailRestart: Integer = 5;
  MailLogFd: LongInt = -1;
  MailerPid: TPid = 0;
  MailerStart: LongInt = 0;
  MailerRestartAt: LongInt = 0;
  MailerDelay: Integer = 0;
  MailerTermAt: LongInt = 0;           {SIGTERM sent at this time, 0 = not asked to stop}
  MailerWanted: Boolean = False;       {the configuration says the mailer is on}
  MailerNote: String = '';
  MailerSig: String = '#';
  NextSync: LongInt = 0;
  SyncNow: Boolean = True;             {SIGHUP, and the start}


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
  P.Charset := 'auto';
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
    Else If Key = 'charset' Then
      Begin
      P.Charset := LowerCase(JStr(V, Where + '.charset'));
      If P.Charset = 'utf-8' Then
        P.Charset := 'utf8';
      If (P.Charset <> 'auto') And (P.Charset <> 'cp437') And (P.Charset <> 'utf8') Then
        Die(Where + '.charset must be "auto", "cp437" or "utf8"');
      End
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
    If P.Password = 'change-me' Then
      Die('port ' + IntToStr(P.Port) + ': set a real sysop "password" (still the example one)');
    If P.MaxPerIp = 0 Then
      P.MaxPerIp := 2;
    End;
  SetLength(Ports, Length(Ports) + 1);
  Ports[High(Ports)] := P;
  End;


Function ResolveProg(Const Name: String): String;
  {A name without a slash is looked up in PATH (execve does not do that)}
  Begin
  ResolveProg := Name;
  If (Name <> '') And (Pos('/', Name) = 0) Then
    Begin
    ResolveProg := ExeSearch(Name, GetEnvironmentVariable('PATH'));
    If ResolveProg = '' Then
      ResolveProg := Name;
    End;
  End;


Function WithSlash(Const P: String): String;
  Begin
  If (P <> '') And (P[Length(P)] <> '/') Then
    WithSlash := P + '/'
  Else
    WithSlash := P;
  End;


Function NextToMk(Const Name: String): String;
  {The program of that name in the directory of mk, else wherever PATH has it}
  Begin
  NextToMk := Name;
  If (Pos('/', MkPath) > 0) And FileExists(ExtractFilePath(MkPath) + Name) Then
    NextToMk := ExtractFilePath(MkPath) + Name;
  End;


Procedure LoadMailer(O: TJSONObject);
  Var
    i: Integer;
    Key: String;
    V: TJSONData;
    On_: Boolean;

  Begin
  On_ := True;
  For i := 0 To O.Count - 1 Do
    Begin
    Key := LowerCase(O.Names[i]);
    V := O.Items[i];
    If Key = 'config' Then MailConfig := JStr(V, 'mailer.config')
    Else If Key = 'mkbink' Then MailBink := JStr(V, 'mailer.mkbink')
    Else If Key = 'mkbinkcfg' Then MailCfgTool := JStr(V, 'mailer.mkbinkcfg')
    Else If Key = 'settings' Then MailSettings := JStr(V, 'mailer.settings')
    Else If Key = 'logfile' Then MailLogPath := JStr(V, 'mailer.logfile')
    Else If Key = 'interval' Then MailInterval := JInt(V, 'mailer.interval', 1, 86400)
    Else If Key = 'restart' Then MailRestart := JInt(V, 'mailer.restart', 1, 300)
    Else If Key = 'enabled' Then On_ := JBool(V, 'mailer.enabled')
    Else If Copy(Key, 1, 1) <> '_' Then
      Die('mailer: unknown key "' + O.Names[i] + '"');
    End;
  If MailConfig = '' Then
    Die('mailer: "config" (the BBS configuration directory) is needed');
  MailerOn := On_;
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
    Else If Key = 'mailer' Then
      Begin
      If V.JSONType <> jtObject Then
        Die('"mailer" must be an object');
      LoadMailer(TJSONObject(V));
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
  MkPath := ResolveProg(MkPath);
  If MonPath = '' Then
    Begin
    If Pos('/', MkPath) > 0 Then
      MonPath := ExtractFilePath(MkPath) + 'mkmon'    {installed next to mk}
    Else
      MonPath := 'mkmon';
    End;
  MonPath := ResolveProg(MonPath);
  If MailerOn Then
    Begin
    If MailBink = '' Then
      MailBink := NextToMk('mkbink');
    If MailCfgTool = '' Then
      MailCfgTool := NextToMk('mkbinkcfg');
    MailBink := ResolveProg(MailBink);
    MailCfgTool := ResolveProg(MailCfgTool);
    If MailSettings = '' Then
      MailSettings := WithSlash(MailConfig) + 'mkbink.conf';
    End;
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



{------------------------------------------------------------ the mailer}

Function Now_: LongInt;
  Begin
  Now_ := fpTime;
  End;


Function FileStamp(Const Path: String): String;
  {Changes whenever the file is replaced or written}
  Var
    St: Stat;

  Begin
  If fpStat(Path, St) = 0 Then
    FileStamp := IntToStr(St.st_ino) + ':' + IntToStr(St.st_size) + ':' + IntToStr(St.st_mtime)
  Else
    FileStamp := '-';
  End;


Function ConfigSig: String;
  {The files of the BBS configuration the mailer settings are made from }
  Var
    SR: TSearchRec;
    N: String;

  Begin
  ConfigSig := '';
  If FindFirst(WithSlash(MailConfig) + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      N := SR.Name;
      If (N = 'config.mk') Or (N = 'echocfg.mk') Or (N = 'mailer.mk') Then
        ConfigSig := ConfigSig + N + ':' + IntToStr(SR.Size) + ':' + IntToStr(SR.Time) + ' ';
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  {a new nodelist changes the hosts mkbinkcfg finds: look again every hour (it leaves an unchanged file alone)}
  ConfigSig := ConfigSig + 'h' + IntToStr(Trunc(Now * 24));
  End;


Function RunTool(Const Prog: String; Parm: Array Of String; Secs: Integer): Integer;
  {Runs a program of the BBS (stdout and stderr in the log) and waits; -1 = could not start / took too long}
  Var
    Pid, R: TPid;
    Status: cInt;
    Argv, Envv: Array Of PChar;
    ArgS, EnvS: TStringList;
    i: Integer;
    W: String;
    T: LongInt;

  Begin
  RunTool := -1;
  Pid := fpFork;
  If Pid < 0 Then
    Begin
    Log('fork failed, error ' + IntToStr(fpGetErrno));
    Exit;
    End;
  If Pid = 0 Then
    Begin
    For i := 0 To High(Ports) Do
      If Ports[i].Fd >= 0 Then
        fpClose(Ports[i].Fd);
    If LogFd >= 0 Then
      Begin
      fpDup2(LogFd, 1);
      fpDup2(LogFd, 2);
      End;
    If WorkDir <> '' Then
      fpChdir(WorkDir);
    ArgS := TStringList.Create;
    ArgS.Add(Prog);
    For i := 0 To High(Parm) Do
      ArgS.Add(Parm[i]);
    SetLength(Argv, ArgS.Count + 1);
    For i := 0 To ArgS.Count - 1 Do
      Argv[i] := PChar(ArgS[i]);
    Argv[ArgS.Count] := Nil;
    EnvS := TStringList.Create;
    i := 0;
    While envp[i] <> Nil Do
      Begin
      W := StrPas(envp[i]);
      If Copy(W, 1, 3) <> 'MK=' Then
        EnvS.Add(W);
      Inc(i);
      End;
    EnvS.Add('MK=' + MailConfig);
    SetLength(Envv, EnvS.Count + 1);
    For i := 0 To EnvS.Count - 1 Do
      Envv[i] := PChar(EnvS[i]);
    Envv[EnvS.Count] := Nil;
    fpExecve(Prog, PPChar(@Argv[0]), PPChar(@Envv[0]));
    W := 'mklisten: cannot start ' + Prog + ' (error ' + IntToStr(fpGetErrno) + ')' + #10;
    fpWrite(2, W[1], Length(W));
    fpExit(127);
    End;
  T := Now_ + Secs;
  Repeat
    R := fpWaitPid(Pid, @Status, WNOHANG);
    If R = Pid Then
      Begin
      If wifexited(Status) Then
        RunTool := wexitstatus(Status)
      Else
        RunTool := 128 + wtermsig(Status);
      Exit;
      End;
    If R < 0 Then
      Exit;
    fpSelect(0, Nil, Nil, Nil, 50);
  Until Now_ > T;
  fpKill(Pid, SIGKILL);
  fpWaitPid(Pid, @Status, 0);
  Log('mailer: ' + Prog + ' took more than ' + IntToStr(Secs) + ' seconds and was stopped');
  End;


Procedure StartMailer;
  Var
    Pid: TPid;
    Argv: Array Of PChar;
    ArgS: TStringList;
    i: Integer;
    W: String;

  Begin
  Pid := fpFork;
  If Pid < 0 Then
    Begin
    Log('mailer: fork failed, error ' + IntToStr(fpGetErrno));
    MailerRestartAt := Now_ + 10;
    Exit;
    End;
  If Pid > 0 Then
    Begin
    MailerPid := Pid;
    MailerStart := Now_;
    MailerTermAt := 0;
    Log('mailer started: ' + MailBink + ' run -f ' + MailSettings + ' pid ' + IntToStr(Pid));
    Exit;
    End;
  { ---- the mailer }
  c_prctl(1, SIGTERM);                       {PR_SET_PDEATHSIG: it does not outlive the listener}
  If fpGetPPid = 1 Then
    fpExit(1);
  For i := 0 To High(Ports) Do
    If Ports[i].Fd >= 0 Then
      fpClose(Ports[i].Fd);
  fpSetsid;
  If MailLogFd >= 0 Then
    Begin
    fpDup2(MailLogFd, 1);
    fpDup2(MailLogFd, 2);
    End
  Else If LogFd >= 0 Then
    Begin
    fpDup2(LogFd, 1);
    fpDup2(LogFd, 2);
    End;
  If WorkDir <> '' Then
    fpChdir(WorkDir);
  fpSignal(SIGTERM, SignalHandler(SIG_DFL));
  fpSignal(SIGINT, SignalHandler(SIG_DFL));
  fpSignal(SIGHUP, SignalHandler(SIG_DFL));
  fpSignal(SIGCHLD, SignalHandler(SIG_DFL));
  fpSignal(SIGPIPE, SignalHandler(SIG_IGN));
  ArgS := TStringList.Create;
  ArgS.Add(MailBink);
  ArgS.Add('run');
  ArgS.Add('-f');
  ArgS.Add(MailSettings);
  ArgS.Add('-S');                            {the monitor (mkmon) finds it in the run directory}
  ArgS.Add(RunDir + '/mailer.sock');
  SetLength(Argv, ArgS.Count + 1);
  For i := 0 To ArgS.Count - 1 Do
    Argv[i] := PChar(ArgS[i]);
  Argv[ArgS.Count] := Nil;
  fpExecve(MailBink, PPChar(@Argv[0]), PPChar(envp));
  W := 'mklisten: cannot start ' + MailBink + ' (error ' + IntToStr(fpGetErrno) + ')' + #10;
  fpWrite(2, W[1], Length(W));
  fpExit(127);
  End;


Procedure MailerEnded(Const How: String);
  Begin
  Log('mailer ended (' + How + ')');
  MailerPid := 0;
  MailerTermAt := 0;
  If Now_ - MailerStart >= 60 Then
    MailerDelay := MailRestart               {it ran for a while: the first delay again}
  Else If MailerDelay = 0 Then
    MailerDelay := MailRestart
  Else If MailerDelay < 300 Then
    MailerDelay := MailerDelay * 2;
  If MailerDelay > 300 Then
    MailerDelay := 300;
  If MailerWanted Then
    Begin
    MailerRestartAt := Now_ + MailerDelay;
    Log('mailer: starting it again in ' + IntToStr(MailerDelay) + ' seconds');
    End;
  End;


Procedure Note(Const S: String);
  {A reason the mailer is not running: logged when it changes}
  Begin
  If S <> MailerNote Then
    Begin
    MailerNote := S;
    If S <> '' Then
      Log('mailer: ' + S);
    End;
  End;


Procedure SyncMailer(Force: Boolean);
  {Run mkbinkcfg when the BBS configuration changed (or Force); the answer decides whether the mailer is wanted}
  Var
    Sig, Before, After: String;
    Rc: Integer;

  Begin
  Sig := ConfigSig;
  If (Not Force) And (Sig = MailerSig) Then
    Exit;
  MailerSig := Sig;
  Before := FileStamp(MailSettings);
  Rc := RunTool(MailCfgTool, ['-q', '-o', MailSettings], 20);
  After := FileStamp(MailSettings);
  Case Rc Of
    0: Begin
       MailerWanted := True;
       Note('');
       If (MailerPid > 0) And ((Before <> After) Or Force) Then
         Begin
         Log('mailer: settings ' + Copy('changed', 1, 7 * Ord(Before <> After)) +
           Copy('reread', 1, 6 * Ord(Before = After)) + ', telling mkbink');
         fpKill(MailerPid, SIGHUP);
         End;
       End;
    3: Begin
       MailerWanted := False;
       Note('not enabled in the BBS configuration (EchoMail > Mailer)');
       End;
    Else
      Begin
      Log('mailer: mkbinkcfg failed (' + IntToStr(Rc) + '); ' +
        Copy('mkbink keeps its old settings', 1, 29 * Ord(MailerPid > 0)) +
        Copy('the mailer is not started', 1, 25 * Ord(MailerPid = 0)));
      MailerWanted := MailerPid > 0;
      End;
    End;
  End;


Procedure MailerTick;
  Var
    T: LongInt;

  Begin
  If Not MailerOn Then
    Exit;
  T := Now_;
  If SyncNow Or (T >= NextSync) Then
    Begin
    NextSync := T + MailInterval;
    If SyncNow Then
      Begin
      SyncNow := False;
      SyncMailer(True);
      End
    Else
      SyncMailer(False);
    End;
  If MailerWanted And (MailerPid = 0) And (T >= MailerRestartAt) Then
    StartMailer;
  If (Not MailerWanted) And (MailerPid > 0) Then
    Begin
    If MailerTermAt = 0 Then
      Begin
      Log('mailer: switched off, stopping mkbink');
      fpKill(MailerPid, SIGTERM);
      MailerTermAt := T;
      End
    Else If T - MailerTermAt > 20 Then
      Begin
      Log('mailer: mkbink did not stop, killing it');
      fpKill(MailerPid, SIGKILL);
      MailerTermAt := T;
      End;
    End;
  End;


Procedure StopMailer;
  {The listener is stopping: so is the mailer (it cancels its calls, which takes a moment)}
  Var
    Status: cInt;
    T: LongInt;

  Begin
  If MailerPid <= 0 Then
    Exit;
  Log('stopping the mailer');
  MailerWanted := False;
  fpKill(MailerPid, SIGTERM);
  T := Now_ + 15;
  While Now_ <= T Do
    Begin
    If fpWaitPid(MailerPid, @Status, WNOHANG) = MailerPid Then
      Begin
      MailerPid := 0;
      Exit;
      End;
    fpSelect(0, Nil, Nil, Nil, 100);
    End;
  fpKill(MailerPid, SIGKILL);
  fpWaitPid(MailerPid, @Status, 0);
  MailerPid := 0;
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
    If (Pid = MailerPid) And (MailerPid > 0) Then
      Begin
      If wifexited(Status) Then
        MailerEnded('exit ' + IntToStr(wexitstatus(Status)))
      Else
        MailerEnded('signal ' + IntToStr(wtermsig(Status)));
      Continue;
      End;
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
  If (Not P.Sysop) And (P.Charset <> 'auto') Then
    ArgS.Add('-U' + UpperCase(P.Charset));
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


Procedure OnHup(Sig: cInt); cdecl;
  Begin
  SyncNow := True;
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
  fpSignal(SIGHUP, @OnHup);
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
    MailerTick;
    If R > 0 Then
      For i := 0 To High(Ports) Do
        If (Fds[i].revents And POLLIN) <> 0 Then
          Accept(i);
    End;
  StopMailer;
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
    WriteLn('  mk:    ', MkPath, ' ', Copy('(NOT FOUND)', 1 + 11 * Ord(FileExists(MkPath)), 11));
    For i := 0 To High(Ports) Do
      If Ports[i].Sysop Then
        Begin
        WriteLn('  mkmon: ', MonPath, ' ', Copy('(NOT FOUND)', 1 + 11 * Ord(FileExists(MonPath)), 11));
        Break;
        End;
    If MailerOn Then
      Begin
      WriteLn('  mailer: ', MailBink, ' ', Copy('(NOT FOUND)', 1 + 11 * Ord(FileExists(MailBink)), 11));
      WriteLn('          ', MailCfgTool, ' ', Copy('(NOT FOUND)', 1 + 11 * Ord(FileExists(MailCfgTool)), 11));
      WriteLn('          settings ', MailSettings, ' (made from ', MailConfig, ')');
      End;
    Halt(0);
    End;
  If MailLogPath <> '' Then
    Begin
    MailLogFd := fpOpen(MailLogPath, O_WRONLY Or O_CREAT Or O_APPEND, &640);
    If MailLogFd < 0 Then
      Die('cannot open log file ' + MailLogPath);
    If (fpGetUid = 0) And (RunUser <> '') Then
      fpChown(MailLogPath, GetUserID(RunUser), TGid(-1));
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
