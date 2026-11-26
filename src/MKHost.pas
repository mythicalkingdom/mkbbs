Unit MKHost;   {The BBS as a script sees it: one dispatcher, a command in, text out (MHOST-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
  A script (BASIC: HOST$("..."), Pascal: HostCall('...')) asks the BBS with one string and gets one string back.  Because both languages keep a string to 255 characters,
  a command does not return its result: it stores it in the host and returns **the number of lines** it has; the script then asks for the lines:

     n = Call('msg.list 3 20')       the number of messages (a negative or an error is a run-time error with the text of Err)
     Call('line 0')                  the first line of the last result: the names of the fields, separated by TAB (a table)
     Call('line 1')                  the first record: the values, separated by TAB, in the same order
     Call('field 1 from')            the value of one field of record 1 (no splitting needed)
     Call('meta next')               a value of the whole answer (the number to start the next page at)
     Call('=user.get "Mark May"')    a command with = in front returns line 1 directly (for a single value or record)

  Results that are a table have a first line of field names; the text of a message (msg.text) has no field names and is cut into lines of at most 250 characters.
  A value never has a TAB or a line end in it (they become blanks).  A boolean is 1 or 0, nothing (JSON null) is empty, a list in a value is joined with commas.
  Text is UTF-8 as the BBS API gives it.

  What a script may call depends on the capabilities it has (users:read, msgs:read, msgs:private, files:read, nodes:read, events:read, stats:read, chat:read, log:write): a call outside
  them is an error and a line in the log.  The data comes from the same functions as the JSON API (MKApiData), so a script and the API see the same BBS.
}

Interface

Uses Classes, SysUtils;

Type
  THost = Class
    Caps: TStringList;                 {the capabilities; '*' = all}
    Who: String;                       {the name of the script, for the log}
    Quiet: Boolean;                    {no log lines (tests)}
    ScriptArgs: TStringList;           {arg 0 is the name of the script, then what followed it on the command line (nil: none)}
    Constructor Create(Const AWho: String; ACaps: TStrings);
    Destructor Destroy; Override;
    Function Call(Const Cmd: String; Out Err: String): String;     {Err <> '': the call failed}
    Private
    Lines: TStringList;                {the result: line 0 the names of the fields (a table), or empty for text}
    Meta: TStringList;                 {name=value of the whole answer}
    Table: Boolean;
    Function ResultCount: Integer;
    Function Allowed(Const Cap: String): Boolean;
    Procedure Clear;
    Procedure FromJson(Root: TObject; Const ListKey: String);
    Procedure FromText(Const S: String);
    Function Run(Const Verb: String; Args: TStringList; Out Err: String): Boolean;
    End;

Function HostCaps(Const List: String): TStringList;
  {a list of capabilities as written in extensions.cfg or on the command line (separated by commas or blanks); the caller frees it}

Const
  HostAllReads = 'users:read msgs:read files:read nodes:read events:read stats:read chat:read log:write';
  HostCommands =
    'system.info node.list events.list stats.total stats.by calls.list msg.areas msg.list msg.read msg.text file.areas file.list user.list user.get chat.who chat.log log.write ' +
    'line field meta count arg argc help';

Implementation

Uses fpjson, DateUtils, MKApiData, MKChatCore, MKLogEnt, MKGlobT, MKCfgAbs;


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
  Lines := TStringList.Create;
  Meta := TStringList.Create;
  End;


Destructor THost.Destroy;
  Begin
  Caps.Free;
  Lines.Free;
  Meta.Free;
  Inherited Destroy;
  End;


Function THost.Allowed(Const Cap: String): Boolean;
  Begin
  Result := (Caps.IndexOf('*') >= 0) Or (Caps.IndexOf(Cap) >= 0);
  End;


Procedure THost.Clear;
  Begin
  Lines.Clear;
  Meta.Clear;
  Table := False;
  End;


Function Plain(Const S: String): String;
  {a value for the result: no TAB, no line end}
  Var
    i: Integer;

  Begin
  Result := S;
  For i := 1 To Length(Result) Do
    If Result[i] In [#9, #10, #13] Then
      Result[i] := ' ';
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
    jtString: Result := Plain(D.AsString);
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
      Result := Plain(D.AsJSON);
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


Procedure THost.FromJson(Root: TObject; Const ListKey: String);
  {a list in ListKey (a table with a record in each line), or the record itself (a table of one line); the other fields of the answer are the meta values}
  Var
    O: TJSONObject;
    Arr: TJSONArray;
    i, k, n: Integer;
    Names, Values, H: TStringList;
    D: TJSONData;

  Begin
  Clear;
  Table := True;
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
      Lines.Add(JoinTab(Names));
      Lines.Add(JoinTab(Values));
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
            Meta.Add(Names[k] + '=' + Values[k]);
          End
        Else
          Meta.Add(O.Names[i] + '=' + Scalar(O.Items[i]));
        End;
    { the names of the fields: those of the first record (the API gives every record the same fields) }
    Names.Clear;
    Values.Clear;
    If Arr.Count > 0 Then
      Flatten(TJSONObject(Arr[0]), '', Names, Values);
    H.Assign(Names);
    Lines.Add('');
    For k := 0 To H.Count - 1 Do
      Lines[0] := Lines[0] + Copy(#9, 1, Ord(k > 0)) + H[k];
    For i := 0 To Arr.Count - 1 Do
      Begin
      Names.Clear;
      Values.Clear;
      Flatten(TJSONObject(Arr[i]), '', Names, Values);
      Lines.Add('');
      For k := 0 To H.Count - 1 Do
        Begin
        n := Names.IndexOf(H[k]);
        If n >= 0 Then
          Lines[Lines.Count - 1] := Lines[Lines.Count - 1] + Copy(#9, 1, Ord(k > 0)) + Values[n]
        Else
          Lines[Lines.Count - 1] := Lines[Lines.Count - 1] + Copy(#9, 1, Ord(k > 0));
        End;
      End;
  Finally
    Names.Free;
    Values.Free;
    H.Free;
  End;
  End;


Procedure THost.FromText(Const S: String);
  Var
    p, q: Integer;
    One: String;

  Begin
  Clear;
  Table := False;
  Lines.Add('');
  p := 1;
  While p <= Length(S) Do
    Begin
    q := Pos(#10, Copy(S, p, Length(S)));
    If q = 0 Then
      q := Length(S) - p + 2;
    One := Copy(S, p, q - 1);
    Inc(p, q);
    One := Plain(One);
    Repeat
      Lines.Add(Copy(One, 1, 250));
      Delete(One, 1, 250);
    Until One = '';
    End;
  End;


Function Arg(Args: TStringList; i: Integer): String;
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


Function PageQuery(Args: TStringList; From: Integer): String;
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


Procedure SplitTab(Const S: String; L: TStringList);
  Var
    i: Integer;
    W: String;

  Begin
  L.Clear;
  W := '';
  For i := 1 To Length(S) Do
    If S[i] = #9 Then
      Begin
      L.Add(W);
      W := '';
      End
    Else
      W := W + S[i];
  L.Add(W);
  End;


Function FieldOf(Const Head, Row, Name: String; Out Err: String): String;
  {the value in the column that has this name (any case)}
  Var
    H, R: TStringList;
    i: Integer;

  Begin
  Result := '';
  Err := '';
  H := TStringList.Create;
  R := TStringList.Create;
  Try
    SplitTab(Head, H);
    SplitTab(Row, R);
    For i := 0 To H.Count - 1 Do
      If CompareText(H[i], Name) = 0 Then
        Begin
        If i < R.Count Then
          Result := Copy(R[i], 1, 255);
        Exit;
        End;
    Err := 'no such field ' + Name;
  Finally
    H.Free;
    R.Free;
  End;
  End;


Function WordCount(Const S: String): Integer; Forward;
Function ExtractWord(Const S: String; N: Integer): String; Forward;

Function THost.Run(Const Verb: String; Args: TStringList; Out Err: String): Boolean;
  Var
    O: TJSONObject;
    RunDir, BbsDir, Q: String;
    L: TStringList;
    n, k: Integer;
    Cc: ChatCfgType;
    Room: TChatRoom;
    Shown, Real: String;

  Procedure Need(Const Cap: String);
    Begin
    If Err = '' Then
      If Not Allowed(Cap) Then
        Err := 'not allowed: ' + Verb + ' needs ' + Cap;
    End;

  Begin
  Err := '';
  Result := False;
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
    FromJson(O, '');
    End
  Else If Verb = 'node.list' Then
    Begin
    Need('nodes:read');
    If Err = '' Then
      Begin
      O := ApiNodes(RunDir, BbsDir);
      FromJson(O, 'nodes');
      End;
    End
  Else If Verb = 'events.list' Then
    Begin
    Need('events:read');
    If Err = '' Then
      Begin
      O := ApiEvents(RunDir);
      FromJson(O, 'events');
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
          FromJson(TJSONObject(O.Find('totals')), '');
          Meta.Add('from=' + Scalar(O.Find('from')));
          Meta.Add('to=' + Scalar(O.Find('to')));
          End
        Else
          FromJson(O, 'rows');
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
        FromJson(O, 'calls');
      End;
    End
  Else If Verb = 'msg.areas' Then
    Begin
    Need('msgs:read');
    If Err = '' Then
      Begin
      O := ApiMsgAreas;
      FromJson(O, 'areas');
      End;
    End
  Else If Verb = 'msg.list' Then
    Begin
    Need('msgs:read');
    If Err = '' Then
      Begin
      O := ApiMsgList(StrToIntDef(Arg(Args, 0), 0), PageQuery(Args, 1), Allowed('msgs:private'), Err);
      If O <> Nil Then
        FromJson(O, 'messages');
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
          FromText(Scalar(O.Find('text')) + '')
        Else
          Begin
          O.Delete('text');
          FromJson(O, '');
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
      FromJson(O, 'areas');
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
        FromJson(O, 'files');
      End;
    End
  Else If Verb = 'user.list' Then
    Begin
    Need('users:read');
    If Err = '' Then
      Begin
      O := ApiUsers(PageQuery(Args, 0));
      FromJson(O, 'users');
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
        FromJson(O, 'users');
        If (Lines.Count < 2) Or (StrToIntDef(Copy(Lines[1], 1, Pos(#9, Lines[1]) - 1), -1) <> n) Then
          Begin
          Err := 'no such user';
          Clear;
          End;
        End
      Else
        Begin
        O := ApiUser(Arg(Args, 0), '');
        If O = Nil Then
          Err := 'no such user'
        Else
          FromJson(O, '');
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
      Clear;
      Table := True;
      Lines.Add('node' + #9 + 'name' + #9 + 'real_name');
      For n := 0 To L.Count - 1 Do
        Begin
        k := StrToIntDef(Copy(L[n], 6, Pos(':', L[n]) - 6), 0);
        If ChatPresence(RunDir, k, Shown, Real) Then
          Lines.Add(IntToStr(k) + #9 + Plain(Shown) + #9 + Plain(Real));
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
      Clear;
      Lines.Add('');
      Lines.AddStrings(L);
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
      LogEntry.WriteEntry('Ext ' + Who + ': ' + Copy(Plain(Q), 1, 200));
      Clear;
      End;
    End
  Else If Verb = 'help' Then
    Begin
    Clear;
    Lines.Add('');
    For n := 1 To WordCount(HostCommands) Do
      Lines.Add(ExtractWord(HostCommands, n));
    End
  Else
    Err := 'unknown command ' + Verb;
  If O <> Nil Then
    O.Free;
  Result := Err = '';
  End;


Function WordCount(Const S: String): Integer;
  Var
    i: Integer;
    In_: Boolean;

  Begin
  Result := 0;
  In_ := False;
  For i := 1 To Length(S) Do
    If S[i] = ' ' Then
      In_ := False
    Else If Not In_ Then
      Begin
      In_ := True;
      Inc(Result);
      End;
  End;


Function ExtractWord(Const S: String; N: Integer): String;
  Var
    i, k: Integer;
    In_: Boolean;

  Begin
  Result := '';
  k := 0;
  In_ := False;
  For i := 1 To Length(S) Do
    If S[i] = ' ' Then
      In_ := False
    Else
      Begin
      If Not In_ Then
        Begin
        In_ := True;
        Inc(k);
        End;
      If k = N Then
        Result := Result + S[i];
      End;
  End;


Procedure SplitArgs(Const S: String; Out Verb: String; Args: TStringList);
  {words separated by blanks; "a b" is one word}
  Var
    i: Integer;
    W: String;
    Quoted, Have: Boolean;

  Begin
  Verb := '';
  Args.Clear;
  W := '';
  Quoted := False;
  Have := False;
  For i := 1 To Length(S) + 1 Do
    Begin
    If (i > Length(S)) Or ((S[i] = ' ') And Not Quoted) Then
      Begin
      If Have Then
        Begin
        If Verb = '' Then
          Verb := LowerCase(W)
        Else
          Args.Add(W);
        End;
      W := '';
      Have := False;
      End
    Else If S[i] = '"' Then
      Begin
      Quoted := Not Quoted;
      Have := True;
      End
    Else
      Begin
      W := W + S[i];
      Have := True;
      End;
    End;
  End;


Function THost.ResultCount: Integer;
  Begin
  Result := Lines.Count - 1;
  If Result < 0 Then
    Result := 0;
  End;


Function THost.Call(Const Cmd: String; Out Err: String): String;
  Var
    C, Verb: String;
    Args: TStringList;
    n: Integer;
    Direct: Boolean;

  Begin
  Result := '';
  Err := '';
  C := Trim(Cmd);
  Direct := (C <> '') And (C[1] = '=');
  If Direct Then
    C := Trim(Copy(C, 2, Length(C)));
  Args := TStringList.Create;
  Try
    SplitArgs(C, Verb, Args);
    If Verb = 'line' Then
      Begin
      n := StrToIntDef(Arg(Args, 0), -1);
      If (n < 0) Or (n >= Lines.Count) Then
        Err := 'no such line'
      Else
        Result := Copy(Lines[n], 1, 255);
      End
    Else If Verb = 'count' Then
      Result := IntToStr(ResultCount)
    Else If Verb = 'field' Then
      Begin
      n := StrToIntDef(Arg(Args, 0), -1);
      If (n < 1) Or (n >= Lines.Count) Or (Not Table) Then
        Err := 'no such line'
      Else
        Result := FieldOf(Lines[0], Lines[n], Arg(Args, 1), Err);
      End
    Else If Verb = 'argc' Then
      Begin
      If ScriptArgs = Nil Then Result := '0' Else Result := IntToStr(ScriptArgs.Count - 1);
      End
    Else If Verb = 'arg' Then
      Begin
      n := StrToIntDef(Arg(Args, 0), -1);
      If (ScriptArgs <> Nil) And (n >= 0) And (n < ScriptArgs.Count) Then
        Result := Copy(ScriptArgs[n], 1, 255);
      End
    Else If Verb = 'meta' Then
      Result := Meta.Values[Arg(Args, 0)]
    Else If Verb = '' Then
      Err := 'empty command'
    Else
      Begin
      If Not Run(Verb, Args, Err) Then
        Begin
        If (Not Quiet) And (Copy(Err, 1, 11) = 'not allowed') Then
          LogEntry.WriteEntry('Ext ' + Who + ': refused: ' + Err);
        Clear;
        End
      Else If Direct Then
        Begin
        If Lines.Count > 1 Then
          Result := Copy(Lines[1], 1, 255)
        Else
          Result := '';
        End
      Else
        Result := IntToStr(ResultCount);
      End;
  Finally
    Args.Free;
  End;
  End;


End.
