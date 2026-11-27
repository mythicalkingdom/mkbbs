{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKHost;   {The BBS as a script sees it: one dispatcher, a command in, text out (MHOST-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
  A script (BASIC: HOST$("..."), Pascal: HostCall('...')) asks the BBS with one string and gets one string back.  The protocol (a command returns the number of lines of its
  answer; line, field, meta and = read it; arg, argc, help, host.list) is that of HostReg (../mkhostreg-fpc): this unit is the default provider of the registry, the BBS's own
  commands; other providers can be added to Registry under their own prefix (Registry.Add).

  Results that are a table have a first line of field names; the text of a message (msg.text) has no field names and is cut into lines of at most 250 characters.
  A value never has a TAB or a line end in it (they become blanks).  A boolean is 1 or 0, nothing (JSON null) is empty, a list in a value is joined with commas.
  Text is UTF-8 as the BBS API gives it.

  What a script may call depends on the capabilities it has (users:read, msgs:read, msgs:private, files:read, nodes:read, events:read, stats:read, chat:read, log:write): a call outside
  them is an error and a line in the log.  The data comes from the same functions as the JSON API (MKApiData), so a script and the API see the same BBS.
}

Interface

Uses Classes, SysUtils, HostReg;

Type
  THost = Class
    Caps: TStringList;                 {the capabilities; '*' = all}
    Who: String;                       {the name of the script, for the log}
    Quiet: Boolean;                    {no log lines (tests)}
    DryRun: Boolean;                   {writes are only logged ("dry run: would ..."), nothing is changed}
    DefaultFrom: String;               {the name a message is from when the script names none}
    OwnNode: Integer;                  {the node this program runs on: it cannot hang itself up or give itself time through the snoop socket (it would wait for itself)}
    ScriptDir: String;                 {the folder of the script: file.add takes its files from there}
    RunPath: String;                   {the run directory of the listener ('' = the environment MKRUN)}
    Cp437: Boolean;                    {in the BBS (a caller's terminal): the script's strings are CP437, the answers are turned into it; mk -x keeps UTF-8}
    Registry: THostRegistry;           {the commands of the script: the BBS is the default provider; others are added with Registry.Add}
    Constructor Create(Const AWho: String; ACaps: TStrings);
    Destructor Destroy; Override;
    Function Call(Const Cmd: String; Out Err: String): String;     {Err <> '': the call failed}
    Procedure SetScriptArgs(Args: TStrings);                      {arg 0 is the name of the script, then what followed it on the command line}
    Function Handle(Const Verb: String; Args: TStrings; Res: THostResult; Out Err: String): Boolean;
    Function Allowed(Const Cap: String): Boolean;
    Procedure WriteLog(Const What: String);       {a line of the log for a change a script made (or would make)}
    Private
    Draft: TStringList;                {the lines of the message being written (msg.new, msg.line, msg.post)}
    DraftOn, DraftPriv: Boolean;
    DraftArea: Integer;
    DraftFrom, DraftTo, DraftSubj: String;
    Procedure FromJson(Res: THostResult; Root: TObject; Const ListKey: String);
    End;

Function HostToCp437(Const S: String): String;      {UTF-8 text as CP437 (a letter that is not in CP437 becomes ?)}
Function HostFromCp437(Const S: String): String;    {CP437 text as UTF-8}

Function HostCaps(Const List: String): TStringList;
  {a list of capabilities as written in extensions.cfg or on the command line (separated by commas or blanks); the caller frees it}

Const
  HostAllReads = 'users:read msgs:read files:read nodes:read events:read stats:read chat:read log:write session:read';
  HostCommands =
    'system.info node.list events.list stats.total stats.by calls.list msg.areas msg.list msg.read msg.text file.areas file.list user.list user.get chat.who chat.log log.write ' +
    'msg.new msg.line msg.post msg.cancel file.add user.set node.send node.kick node.time chat.say chat.mute chat.unmute chat.kick';

Implementation

Uses fpjson, DateUtils, BaseUnix, MKCp437, MKApiData, MKChatCore, MKLogEnt, MKGlobT, MKCfgAbs, MKHostW;


Function HostCaps(Const List: String): TStringList;
  Var
    S: String;
    i: Integer;

  Begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  S := '';
  For i := 1 To Length(List) + 1 Do
    If (i > Length(List)) Or (List[i] In [',', ' ', #9]) Then
      Begin
      If S <> '' Then
        Result.Add(LowerCase(S));
      S := '';
      End
    Else
      S := S + List[i];
  End;


Constructor THost.Create(Const AWho: String; ACaps: TStrings);
  Begin
  Who := AWho;
  Caps := TStringList.Create;
  Caps.CaseSensitive := False;
  Caps.AddStrings(ACaps);
  Draft := TStringList.Create;
  Registry := THostRegistry.Create;
  Registry.SetDefault('the BBS', HostCommands, @Self.Handle);
  End;


Destructor THost.Destroy;
  Begin
  Caps.Free;
  Draft.Free;
  Registry.Free;
  Inherited Destroy;
  End;


Procedure THost.SetScriptArgs(Args: TStrings);
  Begin
  Registry.ScriptArgs.Clear;
  If Args <> Nil Then
    Registry.ScriptArgs.AddStrings(Args);
  End;


Function HostFromCp437(Const S: String): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(S) Do
    If S[i] < #128 Then
      Result := Result + S[i]
    Else
      Result := Result + Cp437ToUtf8(Ord(S[i]));
  End;


Function HostToCp437(Const S: String): String;
  Var
    i, Need: Integer;
    U: LongInt;
    B: Byte;

  Begin
  Result := '';
  i := 1;
  While i <= Length(S) Do
    Begin
    If S[i] < #128 Then
      Begin
      Result := Result + S[i];
      Inc(i);
      Continue;
      End;
    If S[i] >= #240 Then Need := 3
    Else If S[i] >= #224 Then Need := 2
    Else If S[i] >= #192 Then Need := 1
    Else Need := 0;
    If Need = 0 Then
      Begin
      Result := Result + '?';
      Inc(i);
      Continue;
      End;
    U := Ord(S[i]) And ($3F Shr Need);
    Inc(i);
    While (Need > 0) And (i <= Length(S)) And (S[i] >= #128) And (S[i] < #192) Do
      Begin
      U := (U Shl 6) Or (Ord(S[i]) And $3F);
      Inc(i);
      Dec(Need);
      End;
    B := 0;
    If U < 65536 Then
      B := Utf8ToCp437(U);
    If B = 0 Then
      Result := Result + '?'
    Else
      Result := Result + Chr(B);
    End;
  End;


Function THost.Call(Const Cmd: String; Out Err: String): String;
  Var
    E: AnsiString;

  Begin
  If Cp437 Then
    Result := Registry.Call(HostFromCp437(Cmd), E)
  Else
    Result := Registry.Call(Cmd, E);
  If Cp437 Then
    Result := Copy(HostToCp437(Result), 1, 255);
  Err := E;
  End;


Procedure THost.WriteLog(Const What: String);
  Begin
  If Not Quiet Then
    LogEntry.WriteEntry('Ext ' + Who + ': ' + Copy(Copy('dry run: would ', 1, 15 * Ord(DryRun)) + What, 1, 220));
  End;


Function THost.Allowed(Const Cap: String): Boolean;
  Begin
  Result := (Caps.IndexOf('*') >= 0) Or (Caps.IndexOf(Cap) >= 0);
  End;


Function Scalar(D: TJSONData): String;
  Var
    i: Integer;

  Begin
  Result := '';
  If D = Nil Then
    Exit;
  Case D.JSONType Of
    jtNull: Result := '';
    jtBoolean: If D.AsBoolean Then Result := '1' Else Result := '0';
    jtNumber: Result := D.AsString;
    jtString: Result := HostPlain(D.AsString);
    jtArray:
      Begin
      For i := 0 To D.Count - 1 Do
        Begin
        If i > 0 Then
          Result := Result + ',';
        Result := Result + Scalar(D.Items[i]);
        End;
      End;
    Else
      Result := HostPlain(D.AsJSON);
    End;
  End;


Procedure Flatten(O: TJSONObject; Const Prefix: String; Names, Values: TStringList);
  {the fields of a record: a field that is a record again becomes name.field}
  Var
    i: Integer;
    D: TJSONData;

  Begin
  For i := 0 To O.Count - 1 Do
    Begin
    D := O.Items[i];
    If D.JSONType = jtObject Then
      Flatten(TJSONObject(D), Prefix + O.Names[i] + '.', Names, Values)
    Else
      Begin
      Names.Add(Prefix + O.Names[i]);
      Values.Add(Scalar(D));
      End;
    End;
  End;


Function JoinTab(L: TStringList): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 0 To L.Count - 1 Do
    Result := Result + Copy(#9, 1, Ord(i > 0)) + L[i];
  End;


Procedure THost.FromJson(Res: THostResult; Root: TObject; Const ListKey: String);
  {a list in ListKey (a table with a record in each line), or the record itself (a table of one line); the other fields of the answer are the meta values}
  Var
    O: TJSONObject;
    Arr: TJSONArray;
    i, k, n: Integer;
    Names, Values, H: TStringList;
    D: TJSONData;
    Row: String;

  Begin
  Res.Clear;
  O := TJSONObject(Root);
  Arr := Nil;
  If ListKey <> '' Then
    Begin
    D := O.Find(ListKey);
    If (D <> Nil) And (D.JSONType = jtArray) Then
      Arr := TJSONArray(D);
    End;
  Names := TStringList.Create;
  Values := TStringList.Create;
  H := TStringList.Create;
  Try
    If Arr = Nil Then
      Begin
      Flatten(O, '', Names, Values);
      Res.TableTab(JoinTab(Names));
      Res.RowTab(JoinTab(Values));
      Exit;
      End;
    For i := 0 To O.Count - 1 Do                {the meta values: what is not the list}
      If O.Items[i] <> Arr Then
        Begin
        If O.Items[i].JSONType = jtObject Then
          Begin
          Names.Clear;
          Values.Clear;
          Flatten(TJSONObject(O.Items[i]), O.Names[i] + '.', Names, Values);
          For k := 0 To Names.Count - 1 Do
            Res.SetMeta(Names[k], Values[k]);
          End
        Else
          Res.SetMeta(O.Names[i], Scalar(O.Items[i]));
        End;
    { the names of the fields: those of the first record (the API gives every record the same fields) }
    Names.Clear;
    Values.Clear;
    If Arr.Count > 0 Then
      Flatten(TJSONObject(Arr[0]), '', Names, Values);
    H.Assign(Names);
    Res.TableTab(JoinTab(H));
    For i := 0 To Arr.Count - 1 Do
      Begin
      Names.Clear;
      Values.Clear;
      Flatten(TJSONObject(Arr[i]), '', Names, Values);
      Row := '';
      For k := 0 To H.Count - 1 Do
        Begin
        n := Names.IndexOf(H[k]);
        If n >= 0 Then
          Row := Row + Copy(#9, 1, Ord(k > 0)) + Values[n]
        Else
          Row := Row + Copy(#9, 1, Ord(k > 0));
        End;
      Res.RowTab(Row);
      End;
  Finally
    Names.Free;
    Values.Free;
    H.Free;
  End;
  End;


Function Arg(Args: TStrings; i: Integer): String;
  Begin
  If i < Args.Count Then
    Result := Args[i]
  Else
    Result := '';
  End;


Function EncodeQ(Const S: String): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(S) Do
    If S[i] In ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.'] Then
      Result := Result + S[i]
    Else
      Result := Result + '%' + IntToHex(Ord(S[i]), 2);
  End;


Function PageQuery(Args: TStrings; From: Integer): String;
  {limit, after and a search text, as the query string of the API functions}
  Var
    i: Integer;
    Q: String;

  Begin
  Result := '';
  If StrToIntDef(Arg(Args, From), -1) >= 0 Then
    Result := 'limit=' + Arg(Args, From);
  If StrToIntDef(Arg(Args, From + 1), -1) >= 0 Then
    Result := Result + Copy('&', 1, Ord(Result <> '')) + 'after=' + Arg(Args, From + 1);
  Q := '';
  For i := From + 2 To Args.Count - 1 Do
    Q := Q + Copy(' ', 1, Ord(Q <> '')) + Args[i];
  If Q <> '' Then
    Result := Result + Copy('&', 1, Ord(Result <> '')) + 'q=' + EncodeQ(Q);
  End;


Function RestOf(Args: TStrings; From: Integer): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := From To Args.Count - 1 Do
    Result := Result + Copy(' ', 1, Ord(Result <> '')) + Args[i];
  End;


Function OnLineNames(Const RunDir, BbsDir: String): TStringList;
  {the names (CP437, lower case) of the users on a node now}
  Var
    O: TJSONObject;
    A: TJSONArray;
    i: Integer;

  Begin
  Result := TStringList.Create;
  O := ApiNodes(RunDir, BbsDir);
  Try
    A := TJSONArray(O.Find('nodes'));
    If A <> Nil Then
      For i := 0 To A.Count - 1 Do
        Result.Add(LowerCase(HostToCp437(TJSONObject(A[i]).Get('user', ''))));
  Finally
    O.Free;
  End;
  End;


Function NodeIsUp(Const RunDir: String; Node: Integer): Boolean;
  Var
    L: TStringList;
    Pid: Integer;

  Begin
  Result := False;
  If (RunDir = '') Or (Node < 1) Or (Not FileExists(RunDir + '/node' + IntToStr(Node) + '.info')) Then
    Exit;
  L := TStringList.Create;
  Try
    Try
      L.LoadFromFile(RunDir + '/node' + IntToStr(Node) + '.info');
      Pid := StrToIntDef(L.Values['pid'], 0);
      Result := (Pid > 0) And ((fpKill(Pid, 0) = 0) Or (fpGetErrno = ESysEPERM));
    Except
      Result := False;
    End;
  Finally
    L.Free;
  End;
  End;


Function THost.Handle(Const Verb: String; Args: TStrings; Res: THostResult; Out Err: String): Boolean;
  Var
    O: TJSONObject;
    RunDir, BbsDir, Q: String;
    L: TStringList;
    n, k: Integer;
    Cc: ChatCfgType;
    Room: TChatRoom;
    Shown, Real: String;
    Num: LongInt;
    W1, W2, W3, W4: String;
    Lst: TStringList;

  Procedure Need(Const Cap: String);
    Begin
    If Err = '' Then
      If Not Allowed(Cap) Then
        Begin
        Err := 'not allowed: ' + Verb + ' needs ' + Cap;
        If Not Quiet Then
          LogEntry.WriteEntry('Ext ' + Who + ': refused: ' + Err);
        End;
    End;

  Begin
  Err := '';
  Result := False;
  RunDir := RunPath;
  If RunDir = '' Then
    RunDir := GetEnvironmentVariable('MKRUN');
  BbsDir := Config^.GetBbsPath;
  If (BbsDir <> '') And (BbsDir[Length(BbsDir)] <> '/') Then
    BbsDir := BbsDir + '/';
  O := Nil;
  If Verb = 'system.info' Then
    Begin
    O := TJSONObject.Create;
    O.Add('bbs', Cp437Str(Config^.GetBbsName));
    O.Add('software', Cp437Str(BbsVersion));
    O.Add('time', IsoFromUnix(DateTimeToUnix(Now, False)));
    O.Add('bbs_path', BbsDir);
    O.Add('run_path', RunDir);
    FromJson(Res, O, '');
    End
  Else If Verb = 'node.list' Then
    Begin
    Need('nodes:read');
    If Err = '' Then
      Begin
      O := ApiNodes(RunDir, BbsDir);
      FromJson(Res, O, 'nodes');
      End;
    End
  Else If Verb = 'events.list' Then
    Begin
    Need('events:read');
    If Err = '' Then
      Begin
      O := ApiEvents(RunDir);
      FromJson(Res, O, 'events');
      End;
    End
  Else If (Verb = 'stats.total') Or (Verb = 'stats.by') Then
    Begin
    Need('stats:read');
    If Err = '' Then
      Begin
      If Verb = 'stats.total' Then
        Q := 'from=' + Arg(Args, 0) + '&to=' + Arg(Args, 1)
      Else
        Q := 'by=' + Arg(Args, 0) + '&from=' + Arg(Args, 1) + '&to=' + Arg(Args, 2);
      O := ApiStats(BbsDir + 'stats', Q, Err);
      If O <> Nil Then
        Begin
        If Verb = 'stats.total' Then
          Begin
          { the totals as one record }
          FromJson(Res, TJSONObject(O.Find('totals')), '');
          Res.SetMeta('from', Scalar(O.Find('from')));
          Res.SetMeta('to', Scalar(O.Find('to')));
          End
        Else
          FromJson(Res, O, 'rows');
        End;
      End;
    End
  Else If Verb = 'calls.list' Then
    Begin
    Need('stats:read');
    If Err = '' Then
      Begin
      Q := '';
      If StrToIntDef(Arg(Args, 0), -1) >= 0 Then
        Q := 'limit=' + Arg(Args, 0);
      If Arg(Args, 1) <> '' Then
        Q := Q + Copy('&', 1, Ord(Q <> '')) + 'since=' + EncodeQ(Arg(Args, 1));
      O := ApiCalls(BbsDir + 'stats', Q, Err);
      If O <> Nil Then
        FromJson(Res, O, 'calls');
      End;
    End
  Else If Verb = 'msg.areas' Then
    Begin
    Need('msgs:read');
    If Err = '' Then
      Begin
      O := ApiMsgAreas;
      FromJson(Res, O, 'areas');
      End;
    End
  Else If Verb = 'msg.list' Then
    Begin
    Need('msgs:read');
    If Err = '' Then
      Begin
      O := ApiMsgList(StrToIntDef(Arg(Args, 0), 0), PageQuery(Args, 1), Allowed('msgs:private'), Err);
      If O <> Nil Then
        FromJson(Res, O, 'messages');
      End;
    End
  Else If (Verb = 'msg.read') Or (Verb = 'msg.text') Then
    Begin
    Need('msgs:read');
    If Err = '' Then
      Begin
      O := ApiMsg(StrToIntDef(Arg(Args, 0), 0), StrToIntDef(Arg(Args, 1), 0), Allowed('msgs:private'), Err);
      If O <> Nil Then
        Begin
        If Verb = 'msg.text' Then
          Res.Text(Scalar(O.Find('text')))
        Else
          Begin
          O.Delete('text');
          FromJson(Res, O, '');
          End;
        End;
      End;
    End
  Else If Verb = 'file.areas' Then
    Begin
    Need('files:read');
    If Err = '' Then
      Begin
      O := ApiFileAreas;
      FromJson(Res, O, 'areas');
      End;
    End
  Else If Verb = 'file.list' Then
    Begin
    Need('files:read');
    If Err = '' Then
      Begin
      O := ApiFileList(StrToIntDef(Arg(Args, 0), 0), PageQuery(Args, 1));
      If O = Nil Then
        Err := 'no such file area'
      Else
        FromJson(Res, O, 'files');
      End;
    End
  Else If Verb = 'user.list' Then
    Begin
    Need('users:read');
    If Err = '' Then
      Begin
      O := ApiUsers(PageQuery(Args, 0));
      FromJson(Res, O, 'users');
      End;
    End
  Else If Verb = 'user.get' Then
    Begin
    Need('users:read');
    If Err = '' Then
      Begin
      n := StrToIntDef(Arg(Args, 0), -1);
      If n >= 0 Then
        Begin
        If n = 0 Then
          Q := 'limit=1&deleted=1'
        Else
          Q := 'limit=1&deleted=1&after=' + IntToStr(n - 1);
        O := ApiUsers(Q);
        FromJson(Res, O, 'users');
        If (Res.Count < 1) Or (StrToIntDef(Res.Field(1, 'number', Q), -1) <> n) Then
          Begin
          Err := 'no such user';
          Res.Clear;
          End;
        End
      Else
        Begin
        O := ApiUser(Arg(Args, 0), '');
        If O = Nil Then
          Err := 'no such user'
        Else
          FromJson(Res, O, '');
        End;
      End;
    End
  Else If Verb = 'chat.who' Then
    Begin
    Need('chat:read');
    If Err = '' Then
      Begin
      L := TStringList.Create;
      ChatDefaults(Cc);
      Room := TChatRoom.Create(RunDir, '', '', Cc, 0);
      Room.Who(L);
      Room.Free;
      Res.Table(['node', 'name', 'real_name']);
      For n := 0 To L.Count - 1 Do
        Begin
        k := StrToIntDef(Copy(L[n], 6, Pos(':', L[n]) - 6), 0);
        If ChatPresence(RunDir, k, Shown, Real) Then
          Res.Row([IntToStr(k), Shown, Real]);
        End;
      L.Free;
      End;
    End
  Else If Verb = 'chat.log' Then
    Begin
    Need('chat:read');
    If Err = '' Then
      Begin
      L := TStringList.Create;
      ChatDefaults(Cc);
      Room := TChatRoom.Create(RunDir, '', '', Cc, 0);
      Room.Tail(L, StrToIntDef(Arg(Args, 0), 20));
      Room.Free;
      Res.Text(L.Text);
      L.Free;
      End;
    End
  Else If Verb = 'log.write' Then
    Begin
    Need('log:write');
    If Err = '' Then
      Begin
      Q := '';
      For n := 0 To Args.Count - 1 Do
        Q := Q + Copy(' ', 1, Ord(Q <> '')) + Args[n];
      LogEntry.WriteEntry('Ext ' + Who + ': ' + Copy(HostPlain(Q), 1, 200));
      Res.Clear;
      End;
    End
  Else If Verb = 'msg.new' Then
    Begin
    Need('msgs:post');
    If Err = '' Then
      Begin
      n := StrToIntDef(Arg(Args, 0), 0);
      If (n < 1) Or (n > Config^.GetMaxMsgAreas) Or (Config^.GetMsgName(n) = '') Then
        Err := 'no such message area'
      Else If Config^.GetMsgType(n) = NetMail Then
        Err := 'netmail areas need an address: not supported yet'
      Else If (Arg(Args, 1) = '') Or (Arg(Args, 2) = '') Then
        Err := 'msg.new <area> "<to>" "<subject>" [private] [from "<name>"]'
      Else
        Begin
        Draft.Clear;
        DraftOn := True;
        DraftArea := n;
        DraftTo := Arg(Args, 1);
        DraftSubj := Arg(Args, 2);
        DraftFrom := DefaultFrom;
        DraftPriv := False;
        For k := 3 To Args.Count - 1 Do
          If LowerCase(Args[k]) = 'private' Then
            DraftPriv := True
          Else If (LowerCase(Args[k]) = 'from') And (k + 1 < Args.Count) Then
            DraftFrom := Args[k + 1];
        If DraftFrom = '' Then
          DraftFrom := Config^.GetSysopName;
        Res.Clear;
        End;
      End;
    End
  Else If Verb = 'msg.line' Then
    Begin
    Need('msgs:post');
    If Err = '' Then
      Begin
      If Not DraftOn Then
        Err := 'no message was started (msg.new)'
      Else If Draft.Count >= 200 Then
        Err := 'a message has at most 200 lines'
      Else
        Draft.Add(Copy(RestOf(Args, 0), 1, 250));
      Res.Clear;
      End;
    End
  Else If Verb = 'msg.cancel' Then
    Begin
    Need('msgs:post');
    DraftOn := False;
    Draft.Clear;
    Res.Clear;
    End
  Else If Verb = 'msg.post' Then
    Begin
    Need('msgs:post');
    If Err = '' Then
      Begin
      If Not DraftOn Then
        Err := 'no message was started (msg.new)'
      Else
        Begin
        W1 := 'post a message in area ' + IntToStr(DraftArea) + ' from "' + DraftFrom + '" to "' + DraftTo + '": ' + DraftSubj + ' (' + IntToStr(Draft.Count) + ' lines)';
        Num := 0;
        If DryRun Then
          WriteLog(W1)
        Else If HwPostMsg(DraftArea, DraftFrom, DraftTo, DraftSubj, DraftPriv, Draft, Num, Err) Then
          WriteLog('posted message ' + IntToStr(Num) + ' in area ' + IntToStr(DraftArea) + ' from "' + DraftFrom + '" to "' + DraftTo + '": ' + DraftSubj);
        If Err = '' Then
          Begin
          Res.Table(['number']);
          Res.Row([IntToStr(Num)]);
          DraftOn := False;
          Draft.Clear;
          End;
        End;
      End;
    End
  Else If Verb = 'file.add' Then
    Begin
    Need('files:add');
    If Err = '' Then
      Begin
      n := StrToIntDef(Arg(Args, 0), 0);
      W1 := Arg(Args, 1);
      W2 := RestOf(Args, 2);
      If DryRun Then
        Begin
        WriteLog('add the file ' + W1 + ' to file area ' + IntToStr(n) + ' (' + W2 + ')');
        Res.Table(['name']);
        Res.Row([W1]);
        End
      Else If HwAddFile(n, ScriptDir, W1, W2, W3, Err) Then
        Begin
        WriteLog('added the file ' + W3 + ' to file area ' + IntToStr(n) + ' (' + W2 + ')');
        Res.Table(['name']);
        Res.Row([W3]);
        End;
      End;
    End
  Else If Verb = 'user.set' Then
    Begin
    Need('users:write');
    If Err = '' Then
      Begin
      W1 := Arg(Args, 0);
      W2 := Arg(Args, 1);
      W3 := RestOf(Args, 2);
      If (W1 = '') Or (W2 = '') Or (W3 = '') Then
        Err := 'user.set <number or "name"> <field> <value>'
      Else If DryRun Then
        Begin
        WriteLog('set ' + W2 + ' of user ' + W1 + ' to ' + W3);
        Res.Clear;
        End
      Else
        Begin
        Lst := OnLineNames(RunDir, BbsDir);
        If HwUserSet(W1, W2, W3, Lst, W4, Err) Then
          Begin
          WriteLog('set ' + W2 + ' of user ' + W4 + ' to ' + W3);
          Res.Clear;
          End;
        Lst.Free;
        End;
      End;
    End
  Else If (Verb = 'node.send') Or (Verb = 'node.kick') Or (Verb = 'node.time') Then
    Begin
    If Verb = 'node.send' Then Need('node:send') Else If Verb = 'node.kick' Then Need('node:kick') Else Need('node:time');
    If Err = '' Then
      Begin
      n := StrToIntDef(Arg(Args, 0), -1);
      If (n < 0) Or ((n = 0) And (Verb <> 'node.send')) Then
        Err := Verb + ' needs a node number'
      Else If (n > 0) And Not NodeIsUp(RunDir, n) Then
        Err := 'node ' + IntToStr(n) + ' is not in use'
      Else If (n > 0) And (n = OwnNode) And (Verb <> 'node.send') Then
        Err := 'that is the node this program runs on (in a session: bbs.hangup, bbs.addtime)'
      Else If Verb = 'node.send' Then
        Begin
        W1 := RestOf(Args, 1);
        If W1 = '' Then
          Err := 'node.send <node, 0 = all> <text>'
        Else If DryRun Then
          WriteLog('send "' + W1 + '" to node ' + IntToStr(n))
        Else
          Begin
          SysMsgSend(RunDir, W1, n);
          WriteLog('sent "' + W1 + '" to node ' + IntToStr(n));
          End;
        End
      Else If Verb = 'node.kick' Then
        Begin
        If DryRun Then
          WriteLog('hang up node ' + IntToStr(n))
        Else If HwNodeCommand(RunDir, n, 'K', 0, W1) Then
          Begin
          WriteLog('hung up node ' + IntToStr(n));
          Res.Table(['reply']);
          Res.Row([W1]);
          End
        Else
          Err := W1;
        End
      Else
        Begin
        k := StrToIntDef(Arg(Args, 1), 0);
        If (k = 0) Or (Abs(k) > 255) Then
          Err := 'node.time <node> <minutes, -255..255 and not 0>'
        Else If DryRun Then
          WriteLog('give node ' + IntToStr(n) + ' ' + IntToStr(k) + ' minutes')
        Else If HwNodeCommand(RunDir, n, Chr(Ord('+') + 2 * Ord(k < 0)), Abs(k), W1) Then
          Begin
          WriteLog('gave node ' + IntToStr(n) + ' ' + IntToStr(k) + ' minutes');
          Res.Table(['reply']);
          Res.Row([W1]);
          End
        Else
          Err := W1;
        End;
      End;
    End
  Else If (Verb = 'chat.say') Or (Verb = 'chat.mute') Or (Verb = 'chat.unmute') Or (Verb = 'chat.kick') Then
    Begin
    If Verb = 'chat.say' Then Need('chat:say') Else Need('chat:moderate');
    If Err = '' Then
      Begin
      If Verb = 'chat.say' Then
        Begin
        W1 := RestOf(Args, 0);
        If W1 = '' Then
          Err := 'chat.say <text>'
        Else If DryRun Then
          WriteLog('say in the chat room: ' + W1)
        Else
          Begin
          ChatSysopLine(RunDir, 'X', W1);
          WriteLog('said in the chat room: ' + W1);
          End;
        End
      Else
        Begin
        n := StrToIntDef(Arg(Args, 0), 0);
        k := StrToIntDef(Arg(Args, 1), 5);
        If (n < 1) Or Not ChatPresence(RunDir, n, Shown, Real) Then
          Err := 'node ' + IntToStr(n) + ' is not in the chat room'
        Else If DryRun Then
          WriteLog(Verb + ' node ' + IntToStr(n))
        Else
          Begin
          If Verb = 'chat.kick' Then
            Begin
            ChatCtl(RunDir, 'kick', n, 0);
            ChatSysopLine(RunDir, 'N', Shown + ' was removed from the room by the sysop');
            End
          Else If Verb = 'chat.mute' Then
            Begin
            ChatCtl(RunDir, 'mute', n, k);
            ChatSysopLine(RunDir, 'N', Shown + ' was muted by the sysop for ' + IntToStr(k) + ' minute(s)');
            End
          Else
            Begin
            ChatCtl(RunDir, 'mute', n, 0);
            ChatSysopLine(RunDir, 'N', Shown + ' may speak again');
            End;
          WriteLog(Verb + ' node ' + IntToStr(n) + ' (' + Shown + ')');
          End;
        End;
      Res.Clear;
      End;
    End
  Else
    Err := 'unknown command ' + Verb;
  If O <> Nil Then
    O.Free;
  Result := Err = '';
  End;



End.
