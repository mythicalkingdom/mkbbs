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
          "localnode": 9,                      node number for the L key of mkmon (mk -L; not one of the
                                               nodes of a port; 0 or left out: no L key)
          "nodes":    "1-8",                   node numbers handed out (N, "N-M" or [N, M])
          "maxperip": 3,                       callers per address on a port (0 = any)
          "busy":     "All lines are busy.",   sent when no node is free
          "ports": [
            { "port": 2323,                    required
              "type": "telnet",                "telnet" | "raw" | "ws" | "qwk" (telnet, mk -Q)
              "qwk": true,                     any type: the callers get the QWK login (mk -Q)
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

     QWK port: "type": "qwk" (or "qwk": true on a telnet, raw or ws port) starts mk with -Q: the login for QWK
     network systems and scripts (Login:, Password:, then QWK: with D, U, B, Q; see MKQwkLog).  Only users with the
     QWK Node flag come in, the other ports are not affected.

          { "port": 2327, "type": "qwk", "config": "/bbs/mk" }

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

     Local BBS from the monitor: with "localnode" set, the L key in mkmon runs
     "mk -L -N<localnode>" on the sysop's connection (a pseudo terminal; mk asks
     for its login as usual) and returns to the node list when mk ends.  Give it
     a node number that is not one of the nodes of any port (mklisten refuses to
     start otherwise) and put it at the top level, next to "nodes":

          { "mk": "/usr/local/bin/mk", "nodes": "1-8", "localnode": 9, ... }

     0 or no "localnode": no L key.  The path of mk is handed to mkmon in the
     environment (MKMON_MK, and MKMON_NODE for the node number).

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
                      "mktoss": "/usr/local/bin/mktoss",       (default: next to mk)
                      "scan": 300,                     seconds between runs of "mktoss -s" (messages the BBS wrote are
                                                       packed and given to the mailer); 0 = never.  mktoss does
                                                       nothing unless the tosser is switched on (Mailer > Tosser)
                      "interval": 30,                  seconds between looks for a changed configuration
                      "restart": 5 }                   seconds before a mailer that died is started again
                                                       (doubled while it keeps dying, at most 300)

     The listener runs mkbinkcfg at the start and whenever config.mk, echocfg.mk, mailer.mk or bbsconfig.json changed (or
     SIGHUP arrives).  When the mailer is switched on in the configuration it starts mkbink (run -f settings);
     when the settings changed it sends mkbink SIGHUP (it reads them again, no call is cut off); when the
     mailer is switched off, or the listener stops, mkbink is stopped.  A mailer that dies is started again.
     mkbink is started with MK = the BBS configuration in its environment, so the command it runs after mail
     arrives (mkbinkcfg makes it "mktoss" when Mailer > Tosser is on) finds the configuration.
     Whatever happens to the listener (even SIGKILL) takes mkbink with it.

     Events: the events of the BBS configuration (mkconfig: Events; Config.Mk and Events.Mk, see EVENTS-PLAN.md) are run
     by the listener at their times: a command, or POLL / HOLD / FREE of the mailer's links, and when the errorlevel of
     an event is not 0 the script events.sh of the BBS directory (arguments: errorlevel, event number, result of the
     action).  An exclusive event keeps new callers out (they get "closed"), waits for the callers to leave (a forced
     one disconnects them) and runs alone.  What the listener remembers goes to events.run in the BBS directory.

          "events": { "config": "/bbs/ra",               the BBS configuration directory (default: the mailer's)
                      "mkevents": "/usr/local/bin/mkevents",   (default: next to mk)
                      "parallel": 4,                     events that may run at once (default 4)
                      "interval": 30,                    seconds between looks for a changed configuration
                      "closed": "Closed for maintenance." }   shown to a caller refused for an exclusive event

     SIGTERM / SIGINT stop the listener (and the mailer); callers already connected keep running.
     SIGHUP makes the mailer read its settings again.
*)

Uses
  BaseUnix, Sockets, Users, SysUtils, Classes, DateUtils, fpjson, jsonparser, MKEvent;


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

Const
  MaxEv = 30;

Type
  TEvDef = Record                      {one event: what mkevents prints, and what the daemon remembers}
    Defined: Boolean;
    Status, Minutes, Days, EL, Forced, Action, Flags, Late, LateMin, LateMax, Timeout: Integer;
    Cmd: String;
    MapFile: String;                   {a hub pass: the map file of the hub (mkevents)}
    Seen: Boolean;                     {LastDue is valid}
    LastDue: Int64;                    {local seconds: the last occurrence dealt with}
    LastRun: Int64;                    {UNIX time of the last start}
    LastResult: Integer;
    End;

  TEvJob = Record                      {an occurrence that waits to start}
    N: Integer;
    Due, Expires, Kicked: Int64;
    NotBefore: Int64;                  {a hub pass that failed waits until then (real time)}
    Attempt: Integer;                  {0 = the first try}
    Termed: Boolean;
    End;

  TEvRun = Record                      {a running event: its program (phase 1) or events.sh (phase 2)}
    N: Integer;
    Pid: TPid;
    Phase: Integer;
    Started, Deadline, TermAt: Int64;
    Result: Integer;
    Attempt: Integer;
    End;


Function c_setgroups(N: PtrUInt; List: Pointer): cInt; cdecl; external 'c' name 'setgroups';
Function c_prctl(Option: cInt): cInt; cdecl; varargs; external 'c' name 'prctl';


Var
  CfgFile: String = '/etc/mkbbs/mklisten.json';
  Foreground: Boolean = True;
  TestOnly: Boolean = False;
  MkPath: String = 'mk';
  MonPath: String = '';
  LocalNode: Integer = 0;              {node number of the local MK that the L key of mkmon runs, 0 = no L key}
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
  MailBink, MailCfgTool, MailConfig, MailSettings, MailLogPath, MailToss: String;
  MailScan: Integer = 0;               {seconds between runs of mktoss -s (scan and pack local mail), 0 = not}
  ScanPid: TPid = 0;
  NextScan: LongInt = 0;
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
  { the events }
  EvOn: Boolean = False;               {an "events" section is in the configuration}
  EvConfig, EvTool, EvBbsDir: String;
  EvParallel: Integer = 4;
  EvInterval: Integer = 30;
  EvOffset: Int64 = 0;                 {added to the clock (tests: "clock")}
  EvClosedMsg: String = 'The BBS is closed for maintenance. Please try again later.';
  EvDefs: Array[1..MaxEv] Of TEvDef;
  EvQueue: Array Of TEvJob;
  EvRuns: Array Of TEvRun;
  EvLoaded: Boolean = False;
  EvLoadFailed: Boolean = False;
  EvLastSig: String = '#';
  EvNextLoad: Int64 = 0;
  EvStateDirty: Boolean = False;
  EvScriptWarned: Boolean = False;


Type
  TPCharArr = Array Of PChar;


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
    Qwk: Boolean;

  Begin
  Qwk := False;
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
      If P.SType = 'qwk' Then
        Begin
        Qwk := True;                   {a telnet port for QWK network systems and scripts: mk -Q}
        P.SType := 'telnet';
        End
      Else If P.SType = 'sysop' Then
        Begin
        P.Sysop := True;
        P.SType := 'telnet';
        End
      Else If (P.SType <> 'telnet') And (P.SType <> 'raw') And (P.SType <> 'ws') Then
        Die(Where + '.type must be "telnet", "raw", "ws", "qwk" or "sysop" (TLS: put stunnel in front)');
      End
    Else If Key = 'qwk' Then
      Qwk := JBool(V, Where + '.qwk')
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
  If Qwk Then
    P.Args := P.Args + ' -Q';
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
    Else If Key = 'mktoss' Then MailToss := JStr(V, 'mailer.mktoss')
    Else If Key = 'scan' Then MailScan := JInt(V, 'mailer.scan', 0, 86400)
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


Procedure LoadEvents(O: TJSONObject);
  Var
    i: Integer;
    Key: String;
    V: TJSONData;

  Begin
  EvOn := True;
  For i := 0 To O.Count - 1 Do
    Begin
    Key := LowerCase(O.Names[i]);
    V := O.Items[i];
    If Key = 'config' Then EvConfig := JStr(V, 'events.config')
    Else If Key = 'mkevents' Then EvTool := JStr(V, 'events.mkevents')
    Else If Key = 'parallel' Then EvParallel := JInt(V, 'events.parallel', 1, 16)
    Else If Key = 'interval' Then EvInterval := JInt(V, 'events.interval', 1, 86400)
    Else If Key = 'clock' Then EvOffset := JInt(V, 'events.clock', 100000, MaxLongint)    {tests: the time the clock shows at the start}
    Else If Key = 'closed' Then EvClosedMsg := JStr(V, 'events.closed')
    Else If Key = 'enabled' Then EvOn := JBool(V, 'events.enabled')
    Else If Copy(Key, 1, 1) <> '_' Then
      Die('events: unknown key "' + O.Names[i] + '"');
    End;
  If O.Find('clock') <> Nil Then
    EvOffset := EvOffset - Int64(fpTime);
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
    Else If Key = 'localnode' Then LocalNode := JInt(V, 'localnode', 0, 255)
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
    Else If Key = 'events' Then
      Begin
      If V.JSONType <> jtObject Then
        Die('"events" must be an object');
      LoadEvents(TJSONObject(V));
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
  If LocalNode > 0 Then
    For i := 0 To High(Ports) Do
      If (Not Ports[i].Sysop) And (LocalNode >= Ports[i].First) And (LocalNode <= Ports[i].Last) Then
        Die(CfgFile + ': "localnode" ' + IntToStr(LocalNode) + ' is one of the nodes of port ' + IntToStr(Ports[i].Port));
  MkPath := ResolveProg(MkPath);
  If MonPath = '' Then
    Begin
    If Pos('/', MkPath) > 0 Then
      MonPath := ExtractFilePath(MkPath) + 'mkmon'    {installed next to mk}
    Else
      MonPath := 'mkmon';
    End;
  MonPath := ResolveProg(MonPath);
  If EvOn Then
    Begin
    If EvConfig = '' Then
      EvConfig := MailConfig;
    If EvConfig = '' Then
      Die('events: "config" (the BBS configuration directory) is needed');
    If EvTool = '' Then
      EvTool := NextToMk('mkevents');
    EvTool := ResolveProg(EvTool);
    End;
  If MailerOn Then
    Begin
    If MailBink = '' Then
      MailBink := NextToMk('mkbink');
    If MailCfgTool = '' Then
      MailCfgTool := NextToMk('mkbinkcfg');
    MailBink := ResolveProg(MailBink);
    MailCfgTool := ResolveProg(MailCfgTool);
    If MailToss = '' Then
      MailToss := NextToMk('mktoss');
    MailToss := ResolveProg(MailToss);
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
      If (N = 'config.mk') Or (N = 'echocfg.mk') Or (N = 'mailer.mk') Or (N = 'bbsconfig.json') Then
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


Procedure BuildMailEnv(Var EnvS: TStringList; Var Envv: TPCharArr);
  {the environment of what the listener starts for the mailer: its own, with MK = the BBS configuration (mkbink's hook
   and mktoss need it)}
  Var
    i: Integer;
    W: String;

  Begin
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
  End;


Procedure StartMailer;
  Var
    Pid: TPid;
    Argv: Array Of PChar;
    Envv: TPCharArr;
    ArgS, EnvS: TStringList;
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
  BuildMailEnv(EnvS, Envv);
  fpExecve(MailBink, PPChar(@Argv[0]), PPChar(@Envv[0]));
  W := 'mklisten: cannot start ' + MailBink + ' (error ' + IntToStr(fpGetErrno) + ')' + #10;
  fpWrite(2, W[1], Length(W));
  fpExit(127);
  End;


Procedure StartScan;
  {mktoss -s -q in the background: the messages the BBS wrote since the last time are packed and given to the mailer.
   It does nothing (exit status 3) when the tosser is not switched on in the configuration.}
  Var
    Pid: TPid;
    Argv: Array Of PChar;
    Envv: TPCharArr;
    ArgS, EnvS: TStringList;
    i: Integer;
    W: String;

  Begin
  Pid := fpFork;
  If Pid < 0 Then
    Begin
    Log('mailer: fork failed for the scan, error ' + IntToStr(fpGetErrno));
    Exit;
    End;
  If Pid > 0 Then
    Begin
    ScanPid := Pid;
    Exit;
    End;
  c_prctl(1, SIGTERM);
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
  ArgS := TStringList.Create;
  ArgS.Add(MailToss);
  ArgS.Add('-s');
  ArgS.Add('-q');
  SetLength(Argv, ArgS.Count + 1);
  For i := 0 To ArgS.Count - 1 Do
    Argv[i] := PChar(ArgS[i]);
  Argv[ArgS.Count] := Nil;
  BuildMailEnv(EnvS, Envv);
  fpExecve(MailToss, PPChar(@Argv[0]), PPChar(@Envv[0]));
  W := 'mklisten: cannot start ' + MailToss + ' (error ' + IntToStr(fpGetErrno) + ')' + #10;
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
  If (MailScan > 0) And MailerWanted And (MailerPid > 0) And (ScanPid = 0) And (T >= NextScan) Then
    Begin
    NextScan := T + MailScan;
    StartScan;
    End;
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


{------------------------------------------------------------------ events}
{ The events of the BBS configuration (Config.Mk and Events.Mk, see EVENTS-PLAN.md), read by "mkevents", run here.
  Times are local seconds (MKEvent.pas): the wall clock as a number. }

Function EvLocal(U: Int64): Int64;
  Begin
  EvLocal := DateTimeToUnix(UniversalTimeToLocal(UnixToDateTime(U)));
  End;


Function EvReal(L: Int64): Int64;
  Begin
  EvReal := DateTimeToUnix(LocalTimeToUniversal(UnixToDateTime(L)));
  End;


Function EvNowLocal: Int64;
  Begin
  EvNowLocal := EvLocal(Int64(fpTime) + EvOffset);
  End;


Function EvNowReal: Int64;
  Begin
  EvNowReal := Int64(fpTime) + EvOffset;
  End;


Procedure BuildEnvFor(Var EnvS: TStringList; Var Envv: TPCharArr; Const Dir: String; Const Extra: Array Of String);
  {the environment of the listener with MK = Dir (the BBS configuration), and the extra NAME=value lines}
  Var
    i: Integer;
    W: String;

  Begin
  EnvS := TStringList.Create;
  i := 0;
  While envp[i] <> Nil Do
    Begin
    W := StrPas(envp[i]);
    If Copy(W, 1, 3) <> 'MK=' Then
      EnvS.Add(W);
    Inc(i);
    End;
  EnvS.Add('MK=' + Dir);
  For i := 0 To High(Extra) Do
    EnvS.Add(Extra[i]);
  SetLength(Envv, EnvS.Count + 1);
  For i := 0 To EnvS.Count - 1 Do
    Envv[i] := PChar(EnvS[i]);
  Envv[EnvS.Count] := Nil;
  End;


Procedure SplitCmd(Const S: String; L: TStringList);
  {Words of a command line; ' and " keep blanks together; no shell, no expansion}
  Var
    i: Integer;
    W: String;
    Q: Char;
    Have: Boolean;

  Begin
  W := '';
  Q := #0;
  Have := False;
  For i := 1 To Length(S) Do
    Begin
    If Q <> #0 Then
      Begin
      If S[i] = Q Then Q := #0 Else W := W + S[i];
      End
    Else If (S[i] = '''') Or (S[i] = '"') Then
      Begin
      Q := S[i];
      Have := True;
      End
    Else If (S[i] = ' ') Or (S[i] = #9) Then
      Begin
      If Have Or (W <> '') Then L.Add(W);
      W := '';
      Have := False;
      End
    Else
      W := W + S[i];
    End;
  If Have Or (W <> '') Then
    L.Add(W);
  End;


Function SpawnEvent(Const Prog: String; Parm: TStringList; Const Extra: Array Of String; LogOut: Boolean): TPid;
  {Starts a program of an event (no shell) in its own session; it does not outlive the listener}
  Var
    Pid: TPid;
    Argv: Array Of PChar;
    Envv: TPCharArr;
    ArgS, EnvS: TStringList;
    i, Nul: Integer;
    W: String;

  Begin
  SpawnEvent := -1;
  Pid := fpFork;
  If Pid < 0 Then
    Begin
    Log('events: fork failed, error ' + IntToStr(fpGetErrno));
    Exit;
    End;
  If Pid > 0 Then
    Begin
    SpawnEvent := Pid;
    Exit;
    End;
  c_prctl(1, SIGTERM);
  If fpGetPPid = 1 Then
    fpExit(1);
  For i := 0 To High(Ports) Do
    If Ports[i].Fd >= 0 Then
      fpClose(Ports[i].Fd);
  fpSetsid;
  Nul := fpOpen('/dev/null', O_RDWR);
  If Nul >= 0 Then
    fpDup2(Nul, 0);
  If LogOut And (LogFd >= 0) Then
    Begin
    fpDup2(LogFd, 1);
    fpDup2(LogFd, 2);
    End
  Else If Nul >= 0 Then
    Begin
    fpDup2(Nul, 1);
    If LogFd >= 0 Then fpDup2(LogFd, 2) Else fpDup2(Nul, 2);
    End;
  If WorkDir <> '' Then
    fpChdir(WorkDir);
  fpSignal(SIGTERM, SignalHandler(SIG_DFL));
  fpSignal(SIGINT, SignalHandler(SIG_DFL));
  fpSignal(SIGHUP, SignalHandler(SIG_DFL));
  fpSignal(SIGCHLD, SignalHandler(SIG_DFL));
  fpSignal(SIGPIPE, SignalHandler(SIG_DFL));
  ArgS := TStringList.Create;
  ArgS.Add(Prog);
  For i := 0 To Parm.Count - 1 Do
    ArgS.Add(Parm[i]);
  SetLength(Argv, ArgS.Count + 1);
  For i := 0 To ArgS.Count - 1 Do
    Argv[i] := PChar(ArgS[i]);
  Argv[ArgS.Count] := Nil;
  BuildEnvFor(EnvS, Envv, EvConfig, Extra);
  fpExecve(Prog, PPChar(@Argv[0]), PPChar(@Envv[0]));
  W := 'mklisten: cannot start ' + Prog + ' (error ' + IntToStr(fpGetErrno) + ')' + #10;
  fpWrite(2, W[1], Length(W));
  fpExit(127);
  End;


Function RunCapture(Const Prog: String; Parm: Array Of String; Secs: Integer; Var Output: String): Integer;
  {Runs a tool of the BBS and collects what it prints; -1 = could not run / took too long}
  Var
    Fds: TFilDes;
    Pid, R: TPid;
    Status: cInt;
    Argv: Array Of PChar;
    Envv: TPCharArr;
    ArgS, EnvS: TStringList;
    i, N: Integer;
    Buf: Array[0..4095] Of Char;
    P: TPollFd;
    T: LongInt;
    W: String;

  Begin
  RunCapture := -1;
  Output := '';
  If fpPipe(Fds) <> 0 Then
    Exit;
  Pid := fpFork;
  If Pid < 0 Then
    Begin
    fpClose(Fds[0]);
    fpClose(Fds[1]);
    Exit;
    End;
  If Pid = 0 Then
    Begin
    fpClose(Fds[0]);
    fpDup2(Fds[1], 1);
    If Fds[1] > 2 Then
      fpClose(Fds[1]);
    If LogFd >= 0 Then
      fpDup2(LogFd, 2);
    For i := 0 To High(Ports) Do
      If Ports[i].Fd >= 0 Then
        fpClose(Ports[i].Fd);
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
    BuildEnvFor(EnvS, Envv, EvConfig, []);
    fpExecve(Prog, PPChar(@Argv[0]), PPChar(@Envv[0]));
    W := 'mklisten: cannot start ' + Prog + ' (error ' + IntToStr(fpGetErrno) + ')' + #10;
    fpWrite(2, W[1], Length(W));
    fpExit(127);
    End;
  fpClose(Fds[1]);
  T := Now_ + Secs;
  Repeat
    P.fd := Fds[0];
    P.events := POLLIN;
    P.revents := 0;
    If fpPoll(@P, 1, 200) > 0 Then
      Begin
      N := fpRead(Fds[0], Buf, SizeOf(Buf));
      If N <= 0 Then
        Break;
      SetLength(W, N);
      Move(Buf[0], W[1], N);
      Output := Output + W;
      End;
  Until Now_ > T;
  fpClose(Fds[0]);
  R := fpWaitPid(Pid, @Status, WNOHANG);
  If R = 0 Then
    Begin
    If Now_ > T Then
      Begin
      fpKill(Pid, SIGKILL);
      Log('events: ' + Prog + ' took more than ' + IntToStr(Secs) + ' seconds and was stopped');
      End;
    fpWaitPid(Pid, @Status, 0);
    End;
  If Now_ > T Then
    Exit;
  If wifexited(Status) Then
    RunCapture := wexitstatus(Status)
  Else
    RunCapture := 128 + wtermsig(Status);
  End;


Function EvSock(Const Path: String): LongInt;
  {A connected Unix socket, -1 when there is none}
  Var
    S: LongInt;
    A: TUnixSockAddr;

  Begin
  EvSock := -1;
  If Length(Path) > 100 Then
    Exit;
  S := fpSocket(AF_UNIX, SOCK_STREAM, 0);
  If S < 0 Then
    Exit;
  FillChar(A, SizeOf(A), 0);
  A.family := AF_UNIX;
  Move(Path[1], A.path, Length(Path));
  If fpConnect(S, @A, SizeOf(A)) <> 0 Then
    Begin
    fpClose(S);
    Exit;
    End;
  EvSock := S;
  End;


Function SockLine(S: LongInt; Var Buf: String; Secs: Integer; Var Line: String): Boolean;
  {The next line from a socket; Buf holds what was read ahead}
  Var
    P: TPollFd;
    N, K: Integer;
    Tmp: Array[0..1023] Of Char;
    W: String;
    T: LongInt;

  Begin
  SockLine := False;
  T := Now_ + Secs;
  Repeat
    K := Pos(#10, Buf);
    If K > 0 Then
      Begin
      Line := Copy(Buf, 1, K - 1);
      Delete(Buf, 1, K);
      SockLine := True;
      Exit;
      End;
    P.fd := S;
    P.events := POLLIN;
    P.revents := 0;
    If fpPoll(@P, 1, 200) > 0 Then
      Begin
      N := fpRead(S, Tmp, SizeOf(Tmp));
      If N <= 0 Then
        Exit;
      SetLength(W, N);
      Move(Tmp[0], W[1], N);
      Buf := Buf + W;
      End;
  Until Now_ > T;
  End;


Function MailerDo(Const Verb, Arg: String; Var Msg: String): Integer;
  {POLL / HOLD / FREE through the control socket of the mailer.  Arg * is every link for HOLD and FREE (POLL * is the
   mailer's own).  0 = the mailer said ACK, 1 = ERR or no mailer}
  Var
    S: LongInt;
    Buf, Line, Reply: String;
    Addrs: TStringList;
    i, K: Integer;
    C: String;

  Begin
  MailerDo := 1;
  Msg := 'the mailer is not running (no ' + RunDir + '/mailer.sock)';
  S := EvSock(RunDir + '/mailer.sock');
  If S < 0 Then
    Exit;
  Buf := '';
  Addrs := TStringList.Create;
  Try
    If (Arg = '*') And (Verb <> 'POLL') Then
      Begin
      {the links are in the first state frame: LINK <address><TAB>...}
      While SockLine(S, Buf, 5, Line) Do
        Begin
        If Copy(Line, 1, 5) = 'LINK ' Then
          Begin
          K := Pos(#9, Line);
          If K = 0 Then K := Length(Line) + 1;
          Addrs.Add(Copy(Line, 6, K - 6));
          End
        Else If Line = 'END' Then
          Break;
        End;
      End
    Else
      Addrs.Add(Arg);
    MailerDo := 0;
    Msg := '';
    For i := 0 To Addrs.Count - 1 Do
      Begin
      C := Verb + ' ' + Addrs[i] + #10;
      fpSend(S, @C[1], Length(C), MSG_NOSIGNAL);
      Reply := '';
      While SockLine(S, Buf, 5, Line) Do
        If (Copy(Line, 1, 3) = 'ACK') Or (Copy(Line, 1, 3) = 'ERR') Then
          Begin
          Reply := Line;
          Break;
          End;
      If Copy(Reply, 1, 3) <> 'ACK' Then
        Begin
        MailerDo := 1;
        If Reply = '' Then Reply := 'no answer from the mailer';
        End;
      If Msg <> '' Then Msg := Msg + '; ';
      Msg := Msg + Reply;
      End;
    If Addrs.Count = 0 Then
      Msg := 'no links';
  Finally
    Addrs.Free;
    fpClose(S);
  End;
  End;


Function EvField(L: TStringList; K: Integer): Integer;
  Begin
  If K < L.Count Then
    EvField := StrToIntDef(L[K], 0)
  Else
    EvField := 0;
  End;


Procedure EvWriteState;
  {events.run in the BBS directory: what the daemon remembers (UNIX times); read by mkmon, never by mkconfig}
  Var
    L: TStringList;
    i: Integer;
    D: Int64;

  Begin
  EvStateDirty := False;
  If EvBbsDir = '' Then
    Exit;
  L := TStringList.Create;
  Try
    L.Add('# written by mklisten: event, last occurrence dealt with, last start, last result (UNIX times)');
    For i := 1 To MaxEv Do
      If EvDefs[i].Defined And EvDefs[i].Seen Then
        Begin
        D := EvReal(EvDefs[i].LastDue);
        L.Add(IntToStr(i) + #9 + IntToStr(D) + #9 + IntToStr(EvDefs[i].LastRun) + #9 + IntToStr(EvDefs[i].LastResult));
        End;
    Try
      L.SaveToFile(EvBbsDir + 'events.run.new');
      RenameFile(EvBbsDir + 'events.run.new', EvBbsDir + 'events.run');
    Except
      Log('events: cannot write ' + EvBbsDir + 'events.run');
    End;
  Finally
    L.Free;
  End;
  End;


Procedure EvReadState;
  Var
    L, F: TStringList;
    i, N: Integer;

  Begin
  If (EvBbsDir = '') Or (Not FileExists(EvBbsDir + 'events.run')) Then
    Exit;
  L := TStringList.Create;
  F := TStringList.Create;
  Try
    F.Delimiter := #9;
    F.StrictDelimiter := True;
    Try
      L.LoadFromFile(EvBbsDir + 'events.run');
    Except
      Exit;
    End;
    For i := 0 To L.Count - 1 Do
      If (L[i] <> '') And (L[i][1] <> '#') Then
        Begin
        F.DelimitedText := L[i];
        N := EvField(F, 0);
        If (N >= 1) And (N <= MaxEv) And (F.Count >= 4) Then
          Begin
          EvDefs[N].LastDue := EvLocal(StrToInt64Def(F[1], 0));
          EvDefs[N].LastRun := StrToInt64Def(F[2], 0);
          EvDefs[N].LastResult := EvField(F, 3);
          EvDefs[N].Seen := EvDefs[N].LastDue > 86400;
          End;
        End;
  Finally
    L.Free;
    F.Free;
  End;
  End;


Procedure EvLoad;
  {Run mkevents and take the definitions; what the daemon remembers (LastDue ...) stays}
  Var
    Out_, Line: String;
    Rc, i, N, K: Integer;
    L, F: TStringList;
    Seen: Array[1..MaxEv] Of Boolean;

  Begin
  Rc := RunCapture(EvTool, [], 20, Out_);
  If Rc <> 0 Then
    Begin
    If Not EvLoadFailed Then
      Log('events: mkevents failed (' + IntToStr(Rc) + '); keeping the events as they were');
    EvLoadFailed := True;
    Exit;
    End;
  EvLoadFailed := False;
  FillChar(Seen, SizeOf(Seen), 0);
  L := TStringList.Create;
  F := TStringList.Create;
  Try
    F.Delimiter := #9;
    F.StrictDelimiter := True;
    L.Text := Out_;
    For i := 0 To L.Count - 1 Do
      Begin
      Line := L[i];
      F.DelimitedText := Line;
      If (F.Count >= 2) And (F[0] = 'BBS') Then
        Begin
        If EvBbsDir = '' Then
          Begin
          EvBbsDir := F[1];
          EvReadState;
          End
        Else
          EvBbsDir := F[1];
        End
      Else If (F.Count >= 3) And (F[0] = 'MAP') Then
        Begin
        N := EvField(F, 1);
        If (N >= 1) And (N <= MaxEv) Then
          Begin
          EvDefs[N].MapFile := F[2];
          For K := 3 To F.Count - 1 Do
            EvDefs[N].MapFile := EvDefs[N].MapFile + #9 + F[K];
          End;
        End
      Else If (F.Count >= 13) And (F[0] = 'EVENT') Then
        Begin
        N := EvField(F, 1);
        If (N >= 1) And (N <= MaxEv) Then
          Begin
          Seen[N] := True;
          EvDefs[N].Defined := True;
          EvDefs[N].Status := EvField(F, 2);
          EvDefs[N].Minutes := EvField(F, 3);
          EvDefs[N].Days := EvField(F, 4);
          EvDefs[N].EL := EvField(F, 5);
          EvDefs[N].Forced := EvField(F, 6);
          EvDefs[N].Action := EvField(F, 7);
          EvDefs[N].Flags := EvField(F, 8);
          EvDefs[N].Late := EvField(F, 9);
          EvDefs[N].LateMin := EvField(F, 10);
          EvDefs[N].LateMax := EvField(F, 11);
          EvDefs[N].Timeout := EvField(F, 12);
          If F.Count > 13 Then
            Begin
            EvDefs[N].Cmd := F[13];
            For K := 14 To F.Count - 1 Do
              EvDefs[N].Cmd := EvDefs[N].Cmd + #9 + F[K];
            End
          Else
            EvDefs[N].Cmd := '';
          End;
        End;
      End;
  Finally
    L.Free;
    F.Free;
  End;
  For i := 1 To MaxEv Do
    If Not Seen[i] Then
      EvDefs[i].Defined := False;
  End;


Function EvSig: String;
  Var
    SR: TSearchRec;
    N: String;

  Begin
  EvSig := '';
  If FindFirst(WithSlash(EvConfig) + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      N := SR.Name;
      If (N = 'config.mk') Or (N = 'events.mk') Or (N = 'bbsconfig.json') Then
        EvSig := EvSig + N + ':' + IntToStr(SR.Size) + ':' + IntToStr(SR.Time) + ' ';
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  End;


Function CallerCount: Integer;
  Var
    i: Integer;

  Begin
  CallerCount := 0;
  For i := 0 To High(Children) Do
    If Children[i].Node > 0 Then
      Inc(CallerCount);
  End;


Function EvTimeout(N: Integer): Integer;
  Begin
  EvTimeout := EvDefs[N].Timeout;
  If EvTimeout <= 0 Then
    EvTimeout := 60;
  End;


Function EvIsExclusive(N: Integer): Boolean;
  Begin
  EvIsExclusive := (EvDefs[N].Flags And 1) <> 0;
  End;


Function EventsBlockLogins: Boolean;
  {An exclusive event is waiting or running: no one logs on}
  Var
    i: Integer;

  Begin
  EventsBlockLogins := False;
  If Not EvOn Then
    Exit;
  For i := 0 To High(EvQueue) Do
    If EvIsExclusive(EvQueue[i].N) Then
      EventsBlockLogins := True;
  For i := 0 To High(EvRuns) Do
    If EvIsExclusive(EvRuns[i].N) Then
      EventsBlockLogins := True;
  End;


Function EvRunning(N: Integer): Boolean;
  Var
    i: Integer;

  Begin
  EvRunning := False;
  For i := 0 To High(EvRuns) Do
    If EvRuns[i].N = N Then
      EvRunning := True;
  End;


Function EvName(N: Integer): String;
  Begin
  EvName := 'event ' + IntToStr(N);
  Case EvDefs[N].Action Of
    1: EvName := EvName + ' (' + EvDefs[N].Cmd + ')';
    3: EvName := EvName + ' (hub ' + EvDefs[N].Cmd + ')';
    4: EvName := EvName + ' (poll ' + EvDefs[N].Cmd + ')';
    5: EvName := EvName + ' (hold ' + EvDefs[N].Cmd + ')';
    6: EvName := EvName + ' (free ' + EvDefs[N].Cmd + ')';
  End;
  End;


Function HubSetting(N: Integer; Const Key, Default: String): String;
  {A word or line of the map file of the hub of event N: "retry 300", "onfail /path/command" ...}
  Var
    L: TStringList;
    i, P: Integer;
    Line, K: String;

  Begin
  HubSetting := Default;
  If (EvDefs[N].MapFile = '') Or (Not FileExists(EvDefs[N].MapFile)) Then
    Exit;
  L := TStringList.Create;
  Try
    Try
      L.LoadFromFile(EvDefs[N].MapFile);
    Except
      Exit;
    End;
    For i := 0 To L.Count - 1 Do
      Begin
      Line := L[i];
      P := Pos(';', Line);
      If P > 0 Then Line := Copy(Line, 1, P - 1);
      P := Pos('#', Line);
      If P > 0 Then Line := Copy(Line, 1, P - 1);
      Line := Trim(Line);
      P := Pos(' ', Line);
      If P = 0 Then P := Pos(#9, Line);
      If P > 0 Then
        Begin
        K := LowerCase(Copy(Line, 1, P - 1));
        If K = Key Then
          Begin
          HubSetting := Trim(Copy(Line, P + 1, MaxInt));
          Exit;
          End;
        End;
      End;
  Finally
    L.Free;
  End;
  End;


Procedure EvEndRun(Idx: Integer);
  Var
    N: Integer;

  Begin
  N := EvRuns[Idx].N;
  EvDefs[N].LastRun := EvRuns[Idx].Started;
  EvDefs[N].LastResult := EvRuns[Idx].Result;
  Log('events: ' + EvName(N) + ' ended (' + IntToStr(EvRuns[Idx].Result) + ')');
  Delete(EvRuns, Idx, 1);
  EvStateDirty := True;
  End;


Procedure EvStartScript(Idx: Integer);
  {After the action of an event with an errorlevel: events.sh in the BBS directory, with the errorlevel, the event
   number and the result of the action}
  Var
    N: Integer;
    Path: String;
    P: TStringList;
    Pid: TPid;

  Begin
  N := EvRuns[Idx].N;
  Path := EvBbsDir + 'events.sh';
  If fpAccess(Path, X_OK) <> 0 Then
    Begin
    If Not EvScriptWarned Then
      Log('events: ' + Path + ' is missing or not executable: the errorlevel of ' + EvName(N) + ' (and any other) is ignored');
    EvScriptWarned := True;
    EvEndRun(Idx);
    Exit;
    End;
  P := TStringList.Create;
  Try
    P.Add(IntToStr(EvDefs[N].EL));
    P.Add(IntToStr(N));
    P.Add(IntToStr(EvRuns[Idx].Result));
    Pid := SpawnEvent(Path, P, ['MKEVENT=' + IntToStr(N), 'MKERRORLEVEL=' + IntToStr(EvDefs[N].EL),
      'MKRESULT=' + IntToStr(EvRuns[Idx].Result)], True);
  Finally
    P.Free;
  End;
  If Pid <= 0 Then
    Begin
    EvEndRun(Idx);
    Exit;
    End;
  Log('events: ' + EvName(N) + ': events.sh ' + IntToStr(EvDefs[N].EL) + ' ' + IntToStr(N) + ' ' + IntToStr(EvRuns[Idx].Result));
  EvRuns[Idx].Pid := Pid;
  EvRuns[Idx].Phase := 2;
  EvRuns[Idx].Deadline := Now_ + Int64(EvTimeout(N)) * 60;
  EvRuns[Idx].TermAt := 0;
  End;


Function HubFailed(Idx: Integer; Rc: Integer): Boolean;
  {A hub pass (mk -G<id>) failed.  Codes 5 (hub not reached), 6 (login or transfer) and 7 (reply packet refused) are tried
   again after "retry" seconds (default 300, doubled each time, at most "retry-max", default 3600), up to "retries" times
   (default 3); then, or for another code, the "onfail" command of the map file runs with the id, the result and the number
   of tries.  True when a new try is waiting.}
  Var
    N, Retries, Wait, RetryMax, Retry, K: Integer;
    Job: Integer;
    Cmd: String;
    P: TStringList;
    Pid: TPid;
    Prog: String;

  Begin
  HubFailed := False;
  N := EvRuns[Idx].N;
  Retries := StrToIntDef(HubSetting(N, 'retries', '3'), 3);
  Retry := StrToIntDef(HubSetting(N, 'retry', '300'), 300);
  RetryMax := StrToIntDef(HubSetting(N, 'retry-max', '3600'), 3600);
  If (Rc >= 5) And (Rc <= 7) And (EvRuns[Idx].Attempt < Retries) Then
    Begin
    Wait := Retry;
    For K := 1 To EvRuns[Idx].Attempt Do
      Wait := Wait * 2;
    If (Wait > RetryMax) Or (Wait < 1) Then
      Wait := RetryMax;
    Job := Length(EvQueue);
    SetLength(EvQueue, Job + 1);
    EvQueue[Job].N := N;
    EvQueue[Job].Due := EvNowLocal;
    EvQueue[Job].Expires := 0;
    EvQueue[Job].Kicked := 0;
    EvQueue[Job].Termed := False;
    EvQueue[Job].NotBefore := Now_ + Wait;
    EvQueue[Job].Attempt := EvRuns[Idx].Attempt + 1;
    Log('events: ' + EvName(N) + ' failed (' + IntToStr(Rc) + '), trying again in ' + IntToStr(Wait) + ' seconds (try ' +
      IntToStr(EvRuns[Idx].Attempt + 2) + ' of ' + IntToStr(Retries + 1) + ')');
    HubFailed := True;
    Exit;
    End;
  Log('events: ' + EvName(N) + ' failed (' + IntToStr(Rc) + ') after ' + IntToStr(EvRuns[Idx].Attempt + 1) + ' tr' +
    Copy('ies', 1, 3 * Ord(EvRuns[Idx].Attempt > 0)) + Copy('y', 1, Ord(EvRuns[Idx].Attempt = 0)));
  Cmd := HubSetting(N, 'onfail', '');
  If Cmd <> '' Then
    Begin
    P := TStringList.Create;
    Try
      SplitCmd(Cmd, P);
      If P.Count > 0 Then
        Begin
        Prog := P[0];
        P.Delete(0);
        If (Pos('/', Prog) = 0) And (EvBbsDir <> '') And FileExists(EvBbsDir + Prog) Then
          Prog := EvBbsDir + Prog
        Else If Pos('/', Prog) = 0 Then
          Prog := ResolveProg(Prog);
        P.Add(Trim(EvDefs[N].Cmd));
        P.Add(IntToStr(Rc));
        P.Add(IntToStr(EvRuns[Idx].Attempt + 1));
        Pid := SpawnEvent(Prog, P, ['MKEVENT=' + IntToStr(N), 'MKRESULT=' + IntToStr(Rc)], True);
        Log('events: ' + EvName(N) + ': onfail ' + Prog + ' ' + Trim(EvDefs[N].Cmd) + ' ' + IntToStr(Rc));
        End;
    Finally
      P.Free;
    End;
    End;
  End;


Procedure EvActionDone(Idx: Integer; Rc: Integer);
  Begin
  EvRuns[Idx].Result := Rc;
  EvRuns[Idx].Pid := 0;
  If (EvDefs[EvRuns[Idx].N].Action = 3) And (Rc <> 0) And (EvRuns[Idx].Phase = 1) Then
    If HubFailed(Idx, Rc) Then
      Begin
      EvEndRun(Idx);                     {a new try is queued: no events.sh yet}
      Exit;
      End;
  If (EvDefs[EvRuns[Idx].N].EL > 0) And (EvRuns[Idx].Phase = 1) Then
    EvStartScript(Idx)
  Else
    EvEndRun(Idx);
  End;


Procedure EvStart(N: Integer; Attempt: Integer);
  Var
    Idx: Integer;
    P: TStringList;
    Prog, Msg: String;
    Pid: TPid;
    Rc: Integer;

  Begin
  Idx := Length(EvRuns);
  SetLength(EvRuns, Idx + 1);
  EvRuns[Idx].N := N;
  EvRuns[Idx].Pid := 0;
  EvRuns[Idx].Phase := 1;
  EvRuns[Idx].Started := EvNowReal;
  EvRuns[Idx].Deadline := Now_ + Int64(EvTimeout(N)) * 60;
  EvRuns[Idx].TermAt := 0;
  EvRuns[Idx].Result := 0;
  EvRuns[Idx].Attempt := Attempt;
  Log('events: starting ' + EvName(N) + Copy(' (exclusive: the BBS is closed)', 1, 32 * Ord(EvIsExclusive(N))));
  Case EvDefs[N].Action Of
    1: Begin
       P := TStringList.Create;
       Try
         SplitCmd(EvDefs[N].Cmd, P);
         If P.Count = 0 Then
           Begin
           Log('events: ' + EvName(N) + ' has no command');
           EvActionDone(Idx, 1);
           Exit;
           End;
         Prog := P[0];
         P.Delete(0);
         If Pos('/', Prog) = 0 Then
           Begin
           If (Pos('/', MkPath) > 0) And FileExists(ExtractFilePath(MkPath) + Prog) Then
             Prog := ExtractFilePath(MkPath) + Prog
           Else
             Prog := ResolveProg(Prog);
           End;
         Pid := SpawnEvent(Prog, P, ['MKEVENT=' + IntToStr(N), 'MKERRORLEVEL=' + IntToStr(EvDefs[N].EL)],
           (EvDefs[N].Flags And 2) <> 0);
       Finally
         P.Free;
       End;
       If Pid <= 0 Then
         EvActionDone(Idx, 127)
       Else
         EvRuns[Idx].Pid := Pid;
       End;
    4, 5, 6:
       Begin
       Rc := MailerDo(Copy('POLL HOLD FREE', 1 + 5 * (EvDefs[N].Action - 4), 4), Trim(EvDefs[N].Cmd), Msg);
       If Msg <> '' Then
         Log('events: ' + EvName(N) + ': ' + Msg);
       EvActionDone(Idx, Rc);
       End;
    3: Begin
       If Trim(EvDefs[N].Cmd) = '' Then
         Begin
         Log('events: ' + EvName(N) + ' has no hub (the id of its map file)');
         EvActionDone(Idx, 1);
         Exit;
         End;
       P := TStringList.Create;
       Try
         P.Add('-G' + Trim(EvDefs[N].Cmd));
         Pid := SpawnEvent(MkPath, P, ['MKEVENT=' + IntToStr(N)], True);
       Finally
         P.Free;
       End;
       If Pid <= 0 Then
         EvActionDone(Idx, 127)
       Else
         EvRuns[Idx].Pid := Pid;
       End;
    Else
      EvActionDone(Idx, 0);
  End;
  End;


Function EventPidEnded(Pid: TPid; Status: cInt): Boolean;
  {ReapChildren asks: was it the program of an event?}
  Var
    i, Rc: Integer;

  Begin
  EventPidEnded := False;
  For i := 0 To High(EvRuns) Do
    If (EvRuns[i].Pid = Pid) And (Pid > 0) Then
      Begin
      EventPidEnded := True;
      If wifexited(Status) Then
        Rc := wexitstatus(Status)
      Else
        Rc := -1;
      If (EvRuns[i].TermAt > 0) And (Rc <> 0) Then
        Rc := -1;
      If EvRuns[i].Phase = 2 Then
        Begin
        Log('events: ' + EvName(EvRuns[i].N) + ': events.sh ended (' + IntToStr(Rc) + ')');
        EvRuns[i].Pid := 0;
        EvEndRun(i);
        End
      Else
        EvActionDone(i, Rc);
      Exit;
      End;
  End;


Procedure KickNode(Node: Integer);
  {The sysop's K of mkmon: the caller is disconnected}
  Var
    S: LongInt;
    C: Char;

  Begin
  S := EvSock(RunDir + '/node' + IntToStr(Node) + '.snoop');
  If S < 0 Then
    Exit;
  C := 'K';
  fpSend(S, @C, 1, MSG_NOSIGNAL);
  fpClose(S);
  End;


Procedure EventsTick;
  Var
    T, RealNow: Int64;
    i, n, k: Integer;
    Runs: Word;
    NewDue, Latest: Int64;
    Sig: String;
    Idx: Integer;
    Stop: Boolean;
    Msg: String;

  Begin
  If Not EvOn Then
    Exit;
  RealNow := Now_;
  If (RealNow >= EvNextLoad) Or SyncNow Then
    Begin
    EvNextLoad := RealNow + EvInterval;
    Sig := EvSig;
    If (Sig <> EvLastSig) Or EvLoadFailed Or (Not EvLoaded) Then
      Begin
      EvLastSig := Sig;
      EvLoad;
      If Not EvLoadFailed Then
        EvLoaded := True;
      End;
    End;
  If Not EvLoaded Then
    Exit;
  T := EvNowLocal;
  { new occurrences }
  For n := 1 To MaxEv Do
    If EvDefs[n].Defined Then
      Begin
      If (EvDefs[n].Status <> 1) Or (Not EvDefs[n].Seen) Then
        Begin
        EvDefs[n].LastDue := T;               {nothing counts as missed before it was seen enabled}
        EvDefs[n].Seen := EvDefs[n].Status = 1;
        If EvDefs[n].Status = 1 Then EvStateDirty := True;
        Continue;
        End;
      MKEvent.Decide(EvDefs[n].Late, EvDefs[n].LateMin, EvDefs[n].LateMax, EvDefs[n].Minutes, EvDefs[n].Days,
        EvDefs[n].LastDue, T, Runs, NewDue, Latest);
      If NewDue <> EvDefs[n].LastDue Then
        Begin
        EvDefs[n].LastDue := NewDue;
        EvStateDirty := True;
        End;
      If Runs > 0 Then
        Begin
        Msg := 'events: ' + EvName(n) + ' is due';
        If T - Latest > MKEvent.OnTimeSecs Then
          Msg := Msg + ' (late)';
        If Runs > 1 Then
          Msg := Msg + ', ' + IntToStr(Runs) + ' runs for the missed times';
        Log(Msg);
        For k := 1 To Runs Do
          Begin
          SetLength(EvQueue, Length(EvQueue) + 1);
          EvQueue[High(EvQueue)].N := n;
          EvQueue[High(EvQueue)].Due := Latest;
          EvQueue[High(EvQueue)].Expires := MKEvent.ExpiresAt(EvDefs[n].Late, EvDefs[n].LateMin, Latest);
          EvQueue[High(EvQueue)].Kicked := 0;
          EvQueue[High(EvQueue)].Termed := False;
          EvQueue[High(EvQueue)].NotBefore := 0;
          EvQueue[High(EvQueue)].Attempt := 0;
          End;
        End;
      End;
  { runs that took too long }
  For i := High(EvRuns) DownTo 0 Do
    If (EvRuns[i].Pid > 0) And (RealNow > EvRuns[i].Deadline) Then
      Begin
      If EvRuns[i].TermAt = 0 Then
        Begin
        Log('events: ' + EvName(EvRuns[i].N) + ' took more than ' + IntToStr(EvTimeout(EvRuns[i].N)) + ' minutes, stopping it');
        fpKill(EvRuns[i].Pid, SIGTERM);
        EvRuns[i].TermAt := RealNow;
        End
      Else If RealNow - EvRuns[i].TermAt > 10 Then
        Begin
        fpKill(EvRuns[i].Pid, SIGKILL);
        EvRuns[i].TermAt := RealNow;
        End;
      End;
  { what has waited too long is dropped }
  For i := High(EvQueue) DownTo 0 Do
    If (EvQueue[i].Expires > 0) And (T > EvQueue[i].Expires) Then
      Begin
      Log('events: ' + EvName(EvQueue[i].N) + ' could not start in time and is skipped');
      Delete(EvQueue, i, 1);
      End;
  { start what can start, in order }
  i := 0;
  Stop := False;
  While (i <= High(EvQueue)) And (Not Stop) Do
    Begin
    n := EvQueue[i].N;
    If EvQueue[i].NotBefore > RealNow Then
      Inc(i)                                   {a hub pass waiting to try again}
    Else If EvIsExclusive(n) Then
      Begin
      If (Length(EvRuns) > 0) Then
        Stop := True                           {it waits for the others; nothing behind it starts}
      Else If CallerCount > 0 Then
        Begin
        If EvDefs[n].Forced = 1 Then
          Begin
          If EvQueue[i].Kicked = 0 Then
            Begin
            Log('events: ' + EvName(n) + ' is forced: disconnecting the callers');
            For k := 0 To High(Children) Do
              If Children[k].Node > 0 Then
                KickNode(Children[k].Node);
            EvQueue[i].Kicked := RealNow;
            End
          Else If (Not EvQueue[i].Termed) And (RealNow - EvQueue[i].Kicked > 15) Then
            Begin
            For k := 0 To High(Children) Do
              If Children[k].Node > 0 Then
                fpKill(Children[k].Pid, SIGTERM);
            EvQueue[i].Termed := True;
            End;
          End;
        Stop := True;
        End
      Else If EvRunning(n) Then
        Stop := True
      Else
        Begin
        Idx := EvQueue[i].Attempt;
        Delete(EvQueue, i, 1);
        EvStart(n, Idx);
        Stop := True;
        End;
      End
    Else
      Begin
      If EvRunning(n) Then
        Inc(i)                                 {an event never overlaps itself}
      Else If (Length(EvRuns) >= EvParallel) Then
        Stop := True
      Else
        Begin
        k := 0;
        Idx := 0;
        While Idx <= High(EvRuns) Do
          Begin
          If EvIsExclusive(EvRuns[Idx].N) Then k := 1;
          Inc(Idx);
          End;
        If k = 1 Then
          Stop := True
        Else
          Begin
          Idx := EvQueue[i].Attempt;
          Delete(EvQueue, i, 1);
          EvStart(n, Idx);
          End;
        End;
      End;
    End;
  If EvStateDirty Then
    EvWriteState;
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
    If (Pid = ScanPid) And (ScanPid > 0) Then
      Begin
      ScanPid := 0;
      Continue;
      End;
    If EventPidEnded(Pid, Status) Then
      Continue;
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
    Begin
    EnvS.Add('MKMON_PASSWORD=' + P.Password);
    EnvS.Add('MKMON_MK=' + MkPath);                {for the L key: mk -L on this node}
    If LocalNode > 0 Then
      EnvS.Add('MKMON_NODE=' + IntToStr(LocalNode));
    End;
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


Procedure Refuse(Client: LongInt; Const Why: String; Const Addr: String; Const Msg: String = '');
  Var
    M: String;

  Begin
  Log('refused ' + Addr + ': ' + Why);
  If Msg <> '' Then
    M := #13#10 + Msg + #13#10
  Else
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
  If (Not Ports[PortNo].Sysop) And EventsBlockLogins Then
    Begin
    Refuse(C, 'closed for an event', Addr, EvClosedMsg);
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
    EventsTick;
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
      If MailScan > 0 Then
        WriteLn('          tosser scan every ', MailScan, ' s: ', MailToss, ' ', Copy('(NOT FOUND)', 1 + 11 * Ord(FileExists(MailToss)), 11));
      End;
    If EvOn Then
      Begin
      WriteLn('  events: ', EvTool, ' ', Copy('(NOT FOUND)', 1 + 11 * Ord(FileExists(EvTool)), 11));
      WriteLn('          configuration ', EvConfig, ', at most ', EvParallel, ' at once');
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
