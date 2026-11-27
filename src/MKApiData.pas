{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKApiData;   {The answers of the JSON API (read only): built from the files and sockets the BBS already has}

{$mode objfpc}{$H+}

Interface

Uses SysUtils, Classes, fpjson;

Function QueryParam(Const Query, Name: String): String;                  {a parameter of the query string, decoded; '' when it is not there}
Function UrlDecode(Const S: String): String;
Function Cp437Str(S: ShortString): String;
Function IsoFromUnix(U: Int64): String;

Function ApiNodes(Const RunDir, BbsDir: String): TJSONObject;
Function ApiEvents(Const RunDir: String): TJSONObject;
Function ApiMailer(Const RunDir: String): TJSONObject;
Function ApiStats(Const StatDir, Query: String; Var Err: String): TJSONObject;
Function ApiCalls(Const StatDir, Query: String; Var Err: String): TJSONObject;
Function ApiMsgAreas: TJSONObject;
Function ApiFileAreas: TJSONObject;
Function ApiFileList(Area: Integer; Const Query: String): TJSONObject;     {Nil: no such file area}
Function ApiMsgList(Area: Integer; Const Query: String; Private_: Boolean; Var Err: String): TJSONObject;   {Nil: Err says why}
Function ApiMsg(Area, Num: Integer; Private_: Boolean; Var Err: String): TJSONObject;                   {Nil: Err says why}
Function ApiUsers(Const Query: String): TJSONObject;
Function ApiUser(Const Name, Query: String): TJSONObject;                 {Nil: there is no such user}

Implementation

Uses BaseUnix, Unix, Sockets, DateUtils, StrUtils,
  MKGlobT, MKCfgAbs, MKMsgAbs, MKOpen, MKName, MKCp437, MKFile;

Type
  UserOnRec = Packed Record            {as UserOnType in Struct.MK}
    Name: String[35];
    Handle: String[35];
    Node: Byte;
    Baud: Word;
    City: String[25];
    Status: Byte;
    End;

Const
  DayNames: Array[0..6] Of String = ('sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat');


Function UrlDecode(Const S: String): String;
  Var
    i: Integer;
    H: Integer;

  Begin
  Result := '';
  i := 1;
  While i <= Length(S) Do
    Begin
    If (S[i] = '%') And (i + 2 <= Length(S)) Then
      Begin
      H := StrToIntDef('$' + Copy(S, i + 1, 2), -1);
      If H >= 0 Then
        Begin
        Result := Result + Chr(H);
        Inc(i, 3);
        Continue;
        End;
      End;
    If S[i] = '+' Then
      Result := Result + ' '
    Else
      Result := Result + S[i];
    Inc(i);
    End;
  End;


Function QueryParam(Const Query, Name: String): String;
  Var
    L: TStringList;
    i, p: Integer;

  Begin
  Result := '';
  L := TStringList.Create;
  Try
    L.Delimiter := '&';
    L.StrictDelimiter := True;
    L.DelimitedText := Query;
    For i := 0 To L.Count - 1 Do
      Begin
      p := Pos('=', L[i]);
      If (p > 0) And (UrlDecode(Copy(L[i], 1, p - 1)) = Name) Then
        Result := UrlDecode(Copy(L[i], p + 1, 500));
      End;
  Finally
    L.Free;
  End;
  End;


Function IntParam(Const Query, Name: String; Def, Min, Max: Int64): Int64;
  Begin
  Result := StrToInt64Def(QueryParam(Query, Name), Def);
  If Result < Min Then Result := Min;
  If Result > Max Then Result := Max;
  End;


Function Cp437Str(S: ShortString): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(S) Do
    If S[i] = #0 Then
      {not text}
    Else If Ord(S[i]) < 128 Then
      Result := Result + S[i]
    Else
      Result := Result + Cp437ToUtf8(Ord(S[i]));
  End;


Function IsoFromUnix(U: Int64): String;
  Var
    D: TDateTime;
    Off: Integer;

  Begin
  D := UniversalTimeToLocal(UnixToDateTime(U));
  Off := -GetLocalTimeOffset;
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', D) + Format('%s%.2d:%.2d', [Copy('-+', 1 + Ord(Off >= 0), 1), Abs(Off) Div 60, Abs(Off) Mod 60]);
  End;


Function IsoDate(S: String): String;
  {MM-DD-YY (the user file) as yyyy-mm-dd; '' when it is not a date}
  Var
    M, D, Y: Integer;

  Begin
  Result := '';
  If (Length(S) < 8) Or (S[3] <> '-') Or (S[6] <> '-') Then
    Exit;
  M := StrToIntDef(Copy(S, 1, 2), 0);
  D := StrToIntDef(Copy(S, 4, 2), 0);
  Y := StrToIntDef(Copy(S, 7, 2), -1);
  If (M < 1) Or (M > 12) Or (D < 1) Or (D > 31) Or (Y < 0) Then
    Exit;
  If Y < 70 Then Inc(Y, 2000) Else Inc(Y, 1900);
  Result := Format('%.4d-%.2d-%.2d', [Y, M, D]);
  End;


Function Field(Const S: String; N: Integer): String;
  {the N-th (from 0) tab separated field}
  Var
    L: TStringList;

  Begin
  L := TStringList.Create;
  Try
    L.Delimiter := #9;
    L.StrictDelimiter := True;
    L.DelimitedText := S;
    If N < L.Count Then
      Result := L[N]
    Else
      Result := '';
  Finally
    L.Free;
  End;
  End;


Function ActivityName(St: Byte): String;
  Begin
  Case St Of
    uoBrowse: Result := 'browsing';
    uoXfer: Result := 'file transfer';
    uoMsg: Result := 'messages';
    uoDoor: Result := 'door';
    uoChat: Result := 'chat';
    uoQuest: Result := 'questionnaire';
    uoReady: Result := 'ready';
    uoMail: Result := 'offline mail';
    uoWait: Result := 'connecting';
    uoLogIn: Result := 'logging in';
    Else
      Result := 'unknown';
    End;
  End;


{------------------------------------------------------------ nodes}

Function ApiNodes(Const RunDir, BbsDir: String): TJSONObject;
  Var
    Arr: TJSONArray;
    O: TJSONObject;
    SR: TSearchRec;
    L: TStringList;
    U: UserOnRec;
    Node, Pid: Integer;
    Items: TStringList;
    i: Integer;
    Name, Act: String;

  Begin
  Result := TJSONObject.Create;
  Arr := TJSONArray.Create;
  Result.Add('nodes', Arr);
  Items := TStringList.Create;
  Items.Sorted := False;
  If (RunDir <> '') And (FindFirst(RunDir + '/node*.info', faAnyFile, SR) = 0) Then
    Begin
    Repeat
      L := TStringList.Create;
      Try
        L.LoadFromFile(RunDir + '/' + SR.Name);
        Node := StrToIntDef(L.Values['node'], 0);
        Pid := StrToIntDef(L.Values['pid'], 0);
        If (Node > 0) And (Pid > 0) And ((fpKill(Pid, 0) = 0) Or (fpGetErrno = ESysEPERM)) Then
          Begin
          O := TJSONObject.Create;
          O.Add('node', Node);
          Name := '';
          Act := 'connecting';
          If LoadFilePos(BbsDir + 'useron.bbs', U, SizeOf(U), LongInt(Node - 1) * SizeOf(U)) = 0 Then
            Begin
            Name := Cp437Str(U.Name);
            Act := ActivityName(U.Status);
            If U.Handle <> '' Then
              O.Add('handle', Cp437Str(U.Handle));
            End;
          O.Add('user', Name);
          O.Add('activity', Act);
          O.Add('port', StrToIntDef(L.Values['port'], 0));
          O.Add('type', L.Values['type']);
          O.Add('baud', StrToIntDef(L.Values['baud'], 0));
          O.Add('address', L.Values['addr']);
          O.Add('since', IsoFromUnix(StrToInt64Def(L.Values['start'], 0)));
          Items.AddObject(Format('%.5d', [Node]), O);
          End;
      Except
        Node := 0;
      End;
      L.Free;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Items.Sort;
  For i := 0 To Items.Count - 1 Do
    Arr.Add(TJSONObject(Items.Objects[i]));
  Result.Add('count', Items.Count);
  Items.Free;
  End;


{------------------------------------------------------------ events}

Function ApiEvents(Const RunDir: String): TJSONObject;
  Var
    L: TStringList;
    Arr, Days: TJSONArray;
    O: TJSONObject;
    i, k, Mn, Dm, Nx, Lr, Res: Integer;
    Line: String;
    St: Stat;
    Have: Boolean;

  Begin
  Result := TJSONObject.Create;
  Arr := TJSONArray.Create;
  L := TStringList.Create;
  Have := (RunDir <> '') And FileExists(RunDir + '/events.info');
  Result.Add('available', Have);
  Result.Add('blocked', False);
  If Have Then
    Begin
    L.LoadFromFile(RunDir + '/events.info');
    For i := 0 To L.Count - 1 Do
      Begin
      Line := L[i];
      If Copy(Line, 1, 8) = 'blocked=' Then
        Result.Add('new_logons_refused', Copy(Line, 9, 5) = '1')
      Else If Copy(Line, 1, 8) = 'callers=' Then
        Result.Add('callers', StrToIntDef(Copy(Line, 9, 5), 0))
      Else If Copy(Line, 1, 6) = 'queue=' Then
        Result.Add('queued', StrToIntDef(Copy(Line, 7, 5), 0))
      Else If Copy(Line, 1, 8) = 'running=' Then
        Result.Add('running', StrToIntDef(Copy(Line, 9, 5), 0))
      Else If Copy(Line, 1, 2) = 'E' + #9 Then
        Begin
        O := TJSONObject.Create;
        O.Add('number', StrToIntDef(Field(Line, 1), 0));
        O.Add('enabled', Field(Line, 2) = '1');
        Mn := StrToIntDef(Field(Line, 3), 0);
        O.Add('time', Format('%.2d:%.2d', [Mn Div 60, Mn Mod 60]));
        Dm := StrToIntDef(Field(Line, 4), 0);
        Days := TJSONArray.Create;
        For k := 0 To 6 Do
          If (Dm And (1 Shl k)) <> 0 Then
            Days.Add(DayNames[k]);
        O.Add('days', Days);
        O.Add('state', Field(Line, 5));
        O.Add('exclusive', Field(Line, 6) = '1');
        Nx := StrToIntDef(Field(Line, 7), -1);
        If Nx >= 0 Then O.Add('next_in_minutes', Nx) Else O.Add('next_in_minutes', TJSONNull.Create);
        Lr := StrToIntDef(Field(Line, 8), 0);
        If Lr > 0 Then O.Add('last_run', IsoFromUnix(Lr)) Else O.Add('last_run', TJSONNull.Create);
        Res := StrToIntDef(Field(Line, 9), -1);
        If (Lr > 0) And (Res >= 0) Then O.Add('last_result', Res) Else O.Add('last_result', TJSONNull.Create);
        O.Add('errorlevel', StrToIntDef(Field(Line, 10), 0));
        O.Add('action', Field(Line, 11));
        Arr.Add(O);
        End;
      End;
    If fpStat(RunDir + '/events.info', St) = 0 Then
      Result.Add('stale', fpTime - St.st_mtime > 15);
    End;
  L.Free;
  Result.Add('events', Arr);
  End;


{------------------------------------------------------------ the mailer}

Function ApiMailer(Const RunDir: String): TJSONObject;
  {the frame the mailer sends on its control socket (STATE .. END); nothing is sent to it}
  Var
    Sock: LongInt;
    A: TUnixSockAddr;
    Path, Buf, Line: String;
    Raw: Array[0..4095] Of Char;
    N, p: Integer;
    Fds: TPollFd;
    Start: TDateTime;
    Frame: TStringList;
    InFrame, Done: Boolean;
    Links, Sess: TJSONArray;
    O, Me, St: TJSONObject;
    i: Integer;
    L: String;

  Begin
  Result := TJSONObject.Create;
  Path := RunDir + '/mailer.sock';
  Sock := -1;
  If (RunDir <> '') And (Length(Path) <= 100) Then
    Begin
    Sock := fpSocket(AF_UNIX, SOCK_STREAM, 0);
    If Sock >= 0 Then
      Begin
      FillChar(A, SizeOf(A), 0);
      A.family := AF_UNIX;
      Move(Path[1], A.path, Length(Path));
      If fpConnect(Sock, @A, SizeOf(A)) <> 0 Then
        Begin
        fpClose(Sock);
        Sock := -1;
        End;
      End;
    End;
  If Sock < 0 Then
    Begin
    Result.Add('running', False);
    Exit;
    End;
  Frame := TStringList.Create;
  Buf := '';
  InFrame := False;
  Done := False;
  Start := Now;
  While (Not Done) And ((Now - Start) * 86400 < 4) Do
    Begin
    Fds.fd := Sock;
    Fds.events := POLLIN;
    Fds.revents := 0;
    If fpPoll(@Fds, 1, 300) <= 0 Then
      Continue;
    N := fpRecv(Sock, @Raw[0], SizeOf(Raw), MSG_NOSIGNAL);
    If N <= 0 Then
      Break;
    SetLength(L, N);
    Move(Raw[0], L[1], N);
    Buf := Buf + L;
    Repeat
      p := Pos(#10, Buf);
      If p > 0 Then
        Begin
        Line := Copy(Buf, 1, p - 1);
        Delete(Buf, 1, p);
        If Copy(Line, 1, 6) = 'STATE ' Then
          Begin
          InFrame := True;
          Frame.Clear;
          End;
        If InFrame Then
          Begin
          Frame.Add(Line);
          If Line = 'END' Then
            Begin
            Done := True;
            InFrame := False;
            End;
          End;
        End;
    Until (p = 0) Or Done;
    End;
  fpClose(Sock);
  Result.Add('running', True);
  If Not Done Then
    Begin
    Result.Add('available', False);
    Frame.Free;
    Exit;
    End;
  Result.Add('available', True);
  Links := TJSONArray.Create;
  Sess := TJSONArray.Create;
  For i := 0 To Frame.Count - 1 Do
    Begin
    Line := Frame[i];
    If Copy(Line, 1, 3) = 'ME ' Then
      Begin
      L := Copy(Line, 4, 2000);
      Me := TJSONObject.Create;
      Me.Add('address', Field(L, 0));
      Me.Add('name', Field(L, 1));
      Me.Add('sysop', Field(L, 2));
      Me.Add('started', IsoFromUnix(StrToInt64Def(Field(L, 3), 0)));
      Me.Add('port', StrToIntDef(Field(L, 4), 0));
      Me.Add('version', Field(L, 5));
      Result.Add('me', Me);
      End
    Else If Copy(Line, 1, 5) = 'STAT ' Then
      Begin
      L := Copy(Line, 6, 2000);
      St := TJSONObject.Create;
      St.Add('calls', StrToIntDef(Field(L, 0), 0));
      St.Add('ok', StrToIntDef(Field(L, 1), 0));
      St.Add('failed', StrToIntDef(Field(L, 2), 0));
      St.Add('answered', StrToIntDef(Field(L, 3), 0));
      St.Add('bytes_sent', StrToInt64Def(Field(L, 4), 0));
      St.Add('bytes_received', StrToInt64Def(Field(L, 5), 0));
      St.Add('files_sent', StrToIntDef(Field(L, 6), 0));
      St.Add('files_received', StrToIntDef(Field(L, 7), 0));
      Result.Add('statistics', St);
      End
    Else If Copy(Line, 1, 5) = 'LINK ' Then
      Begin
      L := Copy(Line, 6, 2000);
      O := TJSONObject.Create;
      O.Add('address', Field(L, 0));
      O.Add('name', Field(L, 1));
      O.Add('host', Field(L, 2));
      O.Add('flags', Field(L, 3));
      O.Add('poll_minutes', StrToIntDef(Field(L, 4), 0));
      O.Add('state', Field(L, 5));
      O.Add('failures', StrToIntDef(Field(L, 6), 0));
      If StrToInt64Def(Field(L, 7), 0) > 0 Then O.Add('next_call', IsoFromUnix(StrToInt64Def(Field(L, 7), 0))) Else O.Add('next_call', TJSONNull.Create);
      O.Add('last_result', Field(L, 8));
      O.Add('waiting_files', StrToIntDef(Field(L, 9), 0));
      O.Add('waiting_bytes', StrToInt64Def(Field(L, 10), 0));
      If StrToInt64Def(Field(L, 11), 0) > 0 Then O.Add('last_call', IsoFromUnix(StrToInt64Def(Field(L, 11), 0))) Else O.Add('last_call', TJSONNull.Create);
      Links.Add(O);
      End
    Else If Copy(Line, 1, 5) = 'SESS ' Then
      Begin
      L := Copy(Line, 6, 2000);
      O := TJSONObject.Create;
      O.Add('id', StrToIntDef(Field(L, 0), 0));
      If Field(L, 1) = 'O' Then O.Add('direction', 'out') Else O.Add('direction', 'in');
      O.Add('remote', Field(L, 2));
      O.Add('system', Field(L, 3));
      O.Add('sysop', Field(L, 4));
      O.Add('location', Field(L, 5));
      O.Add('started', IsoFromUnix(StrToInt64Def(Field(L, 6), 0)));
      O.Add('state', Field(L, 7));
      O.Add('bytes_sent', StrToInt64Def(Field(L, 9), 0));
      O.Add('bytes_received', StrToInt64Def(Field(L, 10), 0));
      O.Add('files_sent', StrToIntDef(Field(L, 11), 0));
      O.Add('files_received', StrToIntDef(Field(L, 12), 0));
      Sess.Add(O);
      End;
    End;
  Result.Add('links', Links);
  Result.Add('sessions', Sess);
  Frame.Free;
  End;


{------------------------------------------------------------ statistics and calls}

Function ValidDate(Const S: String): Boolean;
  Var
    D: TDateTime;
    FS: TFormatSettings;

  Begin
  FS := DefaultFormatSettings;
  FS.DateSeparator := '-';
  FS.ShortDateFormat := 'yyyy-mm-dd';
  Result := (Length(S) = 10) And TryStrToDate(S, D, FS);
  End;


Function StatFiles(Const StatDir, From_, To_: String): TStringList;
  {the names of the monthly files that can hold calls between the two days, oldest first}
  Var
    SR: TSearchRec;
    M: String;

  Begin
  Result := TStringList.Create;
  If FindFirst(StatDir + '/*.tsv', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      M := Copy(SR.Name, 1, 7);
      If (Length(SR.Name) = 11) And (M >= Copy(From_, 1, 7)) And (M <= Copy(To_, 1, 7)) Then
        Result.Add(SR.Name);
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Result.Sort;
  End;


Type
  TAgg = Class
    Calls, Ok, Failed, NoLogon: LongInt;
    Secs, SecsOk, Ul, Dl, Ulk, Dlk, Msgs: Int64;
    End;


Procedure AggAdd(A: TAgg; Const Res: String; Secs, ul, dl, ulk, dlk, msgs: Int64);
  Begin
  Inc(A.Calls);
  If Res = 'ok' Then
    Begin
    Inc(A.Ok);
    Inc(A.SecsOk, Secs);
    End
  Else If Res = 'failed' Then
    Inc(A.Failed)
  Else
    Inc(A.NoLogon);
  Inc(A.Secs, Secs);
  Inc(A.Ul, ul);
  Inc(A.Dl, dl);
  Inc(A.Ulk, ulk);
  Inc(A.Dlk, dlk);
  Inc(A.Msgs, msgs);
  End;


Function AggJson(A: TAgg; Target: TJSONObject = Nil): TJSONObject;
  Begin
  If Target = Nil Then
    Target := TJSONObject.Create;
  Result := Target;
  Result.Add('calls', A.Calls);
  Result.Add('logons', A.Ok);
  Result.Add('failed', A.Failed);
  Result.Add('no_logon', A.NoLogon);
  Result.Add('minutes', Round(A.Secs / 6) / 10);
  Result.Add('upload_files', A.Ul);
  Result.Add('upload_k', A.Ulk);
  Result.Add('download_files', A.Dl);
  Result.Add('download_k', A.Dlk);
  Result.Add('messages', A.Msgs);
  End;


Function ApiStats(Const StatDir, Query: String; Var Err: String): TJSONObject;
  Var
    From_, To_, By, Line, Date_, Res, Key, U, BestDay: String;
    Names, Table, Users, Days: TStringList;
    Total, B: TAgg;
    Hours: Array[0..23] Of LongInt;
    i, k, H, Best, BestN: Integer;
    T: Text;
    Secs, Longest, Bn: LongInt;
    Start: Int64;
    Rows: TJSONArray;
    O, Tot: TJSONObject;

  Begin
  Result := Nil;
  From_ := QueryParam(Query, 'from');
  To_ := QueryParam(Query, 'to');
  By := LowerCase(QueryParam(Query, 'by'));
  If From_ = '' Then From_ := FormatDateTime('yyyy-mm', Now) + '-01';
  If To_ = '' Then To_ := FormatDateTime('yyyy-mm-dd', Now);
  If Not (ValidDate(From_) And ValidDate(To_)) Then
    Begin
    Err := 'from and to are dates as yyyy-mm-dd';
    Exit;
    End;
  If (By <> '') And (Pos(' ' + By + ' ', ' day hour node label port user result type ') = 0) Then
    Begin
    Err := 'by is day, hour, node, label, port, user, result or type';
    Exit;
    End;
  Names := StatFiles(StatDir, From_, To_);
  Total := TAgg.Create;
  Table := TStringList.Create;
  Table.CaseSensitive := True;
  Users := TStringList.Create;
  Users.CaseSensitive := True;
  Days := TStringList.Create;
  FillChar(Hours, SizeOf(Hours), 0);
  Longest := 0;
  For i := 0 To Names.Count - 1 Do
    Begin
    Assign(T, StatDir + '/' + Names[i]);
    {$I-}
    Reset(T);
    {$I+}
    If IOResult <> 0 Then
      Continue;
    While Not Eof(T) Do
      Begin
      ReadLn(T, Line);
      If (Line = '') Or (Line[1] = '#') Then
        Continue;
      Date_ := Field(Line, 2);
      If (Date_ < From_) Or (Date_ > To_) Then
        Continue;
      Res := Field(Line, 9);
      Secs := StrToIntDef(Field(Line, 10), 0);
      Start := StrToInt64Def(Field(Line, 0), 0);
      AggAdd(Total, Res, Secs, StrToIntDef(Field(Line, 11), 0), StrToIntDef(Field(Line, 12), 0), StrToIntDef(Field(Line, 13), 0), StrToIntDef(Field(Line, 14), 0), StrToIntDef(Field(Line, 15), 0));
      If (Res = 'ok') And (Secs > Longest) Then
        Longest := Secs;
      H := HourOf(UniversalTimeToLocal(UnixToDateTime(Start)));
      Inc(Hours[H]);
      k := Days.IndexOf(Date_);
      If k < 0 Then
        Days.AddObject(Date_, TObject(PtrInt(1)))
      Else
        Days.Objects[k] := TObject(PtrInt(PtrInt(Days.Objects[k]) + 1));
      U := Field(Line, 8);
      If (Res = 'ok') And (U <> '') And (Users.IndexOf(U) < 0) Then
        Users.Add(U);
      If By <> '' Then
        Begin
        Key := '';
        If By = 'day' Then Key := Date_
        Else If By = 'hour' Then Key := Format('%.2d', [H])
        Else If By = 'node' Then Key := Format('%.2d', [StrToIntDef(Field(Line, 3), 0)])
        Else If By = 'label' Then Key := Field(Line, 5)
        Else If By = 'port' Then Key := Field(Line, 6)
        Else If By = 'type' Then Key := Field(Line, 4)
        Else If By = 'result' Then Key := Res
        Else If By = 'user' Then
          Begin
          Key := U;
          If Key = '' Then Key := '(nobody)';
          End;
        k := Table.IndexOf(Key);
        If k < 0 Then
          Begin
          B := TAgg.Create;
          Table.AddObject(Key, B);
          End
        Else
          B := TAgg(Table.Objects[k]);
        AggAdd(B, Res, Secs, StrToIntDef(Field(Line, 11), 0), StrToIntDef(Field(Line, 12), 0), StrToIntDef(Field(Line, 13), 0), StrToIntDef(Field(Line, 14), 0), StrToIntDef(Field(Line, 15), 0));
        End;
      End;
    Close(T);
    End;
  Result := TJSONObject.Create;
  Result.Add('from', From_);
  Result.Add('to', To_);
  Result.Add('files', Names.Count);
  Tot := AggJson(Total);
  Tot.Add('callers', Users.Count);
  Tot.Add('longest_minutes', Round(Longest / 6) / 10);
  Best := -1;
  BestN := 0;
  For i := 0 To 23 Do
    If Hours[i] > BestN Then
      Begin
      BestN := Hours[i];
      Best := i;
      End;
  If Best >= 0 Then
    Tot.Add('busiest_hour', Best)
  Else
    Tot.Add('busiest_hour', TJSONNull.Create);
  BestDay := '';
  Bn := 0;
  For i := 0 To Days.Count - 1 Do
    If PtrInt(Days.Objects[i]) > Bn Then
      Begin
      Bn := PtrInt(Days.Objects[i]);
      BestDay := Days[i];
      End;
  If BestDay <> '' Then
    Tot.Add('busiest_day', BestDay)
  Else
    Tot.Add('busiest_day', TJSONNull.Create);
  Result.Add('totals', Tot);
  If By <> '' Then
    Begin
    Table.Sort;
    Rows := TJSONArray.Create;
    For i := 0 To Table.Count - 1 Do
      Begin
      O := TJSONObject.Create;
      O.Add(By, Table[i]);
      AggJson(TAgg(Table.Objects[i]), O);
      Rows.Add(O);
      End;
    Result.Add('by', By);
    Result.Add('rows', Rows);
    End;
  Names.Free;
  End;


Function ApiCalls(Const StatDir, Query: String; Var Err: String): TJSONObject;
  Var
    Limit: Integer;
    Since: Int64;
    S: String;
    Names, L: TStringList;
    Arr: TJSONArray;
    O: TJSONObject;
    i, j: Integer;
    D: TDateTime;
    FS: TFormatSettings;
    Line: String;
    Rec: Array Of String;
    n: Integer;
    SR: TSearchRec;

  Begin
  Result := Nil;
  Limit := IntParam(Query, 'limit', 50, 1, 500);
  Since := 0;
  S := QueryParam(Query, 'since');
  If S <> '' Then
    Begin
    If ValidDate(S) Then
      Begin
      FS := DefaultFormatSettings;
      FS.DateSeparator := '-';
      FS.ShortDateFormat := 'yyyy-mm-dd';
      D := StrToDate(S, FS);
      Since := DateTimeToUnix(LocalTimeToUniversal(D));
      End
    Else If StrToInt64Def(S, -1) >= 0 Then
      Since := StrToInt64(S)
    Else
      Begin
      Err := 'since is a day (yyyy-mm-dd) or a unix time';
      Exit;
      End;
    End;
  Names := TStringList.Create;
  If FindFirst(StatDir + '/*.tsv', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If Length(SR.Name) = 11 Then
        Names.Add(SR.Name);
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Names.Sort;
  SetLength(Rec, 0);
  n := 0;
  For i := Names.Count - 1 DownTo 0 Do
    Begin
    If n >= Limit Then
      Break;
    L := TStringList.Create;
    Try
      L.LoadFromFile(StatDir + '/' + Names[i]);
    Except
      L.Clear;
    End;
    For j := L.Count - 1 DownTo 0 Do
      Begin
      Line := L[j];
      If (Line = '') Or (Line[1] = '#') Then
        Continue;
      If StrToInt64Def(Field(Line, 0), 0) < Since Then
        Continue;
      SetLength(Rec, n + 1);
      Rec[n] := Line;
      Inc(n);
      If n >= Limit Then
        Break;
      End;
    L.Free;
    End;
  Names.Free;
  Result := TJSONObject.Create;
  Arr := TJSONArray.Create;
  For i := 0 To n - 1 Do
    Begin
    Line := Rec[i];
    O := TJSONObject.Create;
    O.Add('start', IsoFromUnix(StrToInt64Def(Field(Line, 0), 0)));
    O.Add('end', IsoFromUnix(StrToInt64Def(Field(Line, 1), 0)));
    O.Add('node', StrToIntDef(Field(Line, 3), 0));
    O.Add('type', Field(Line, 4));
    O.Add('label', Field(Line, 5));
    O.Add('port', StrToIntDef(Field(Line, 6), 0));
    O.Add('address', Field(Line, 7));
    O.Add('user', Field(Line, 8));
    O.Add('result', Field(Line, 9));
    O.Add('seconds', StrToIntDef(Field(Line, 10), 0));
    O.Add('upload_files', StrToIntDef(Field(Line, 11), 0));
    O.Add('download_files', StrToIntDef(Field(Line, 12), 0));
    O.Add('upload_k', StrToIntDef(Field(Line, 13), 0));
    O.Add('download_k', StrToIntDef(Field(Line, 14), 0));
    O.Add('messages', StrToIntDef(Field(Line, 15), 0));
    If Field(Line, 16) <> '' Then
      O.Add('reason', Field(Line, 16));
    Arr.Add(O);
    End;
  Result.Add('calls', Arr);
  Result.Add('count', n);
  End;


{------------------------------------------------------------ areas}

Function ApiMsgAreas: TJSONObject;
  Var
    Arr: TJSONArray;
    O: TJSONObject;
    i: Integer;
    M: AbsMsgPtr;
    Id, Kind: String;

  Begin
  Result := TJSONObject.Create;
  Arr := TJSONArray.Create;
  For i := 1 To Config^.GetMaxMsgAreas Do
    If Config^.GetMsgName(i) <> '' Then
      Begin
      O := TJSONObject.Create;
      O.Add('number', i);
      O.Add('name', Cp437Str(Config^.GetMsgName(i)));
      Case Config^.GetMsgType(i) Of
        EchoMail: Kind := 'echomail';
        NetMail: Kind := 'netmail';
        Else
          Kind := 'local';
        End;
      O.Add('type', Kind);
      Id := Config^.GetMsgAreaId(i);
      O.Add('base', Copy(Id + '?', 1, 1));
      M := Nil;
      If (Id <> '') And OpenMsgArea(M, Id) Then
        Begin
        O.Add('messages', M^.NumberOfMsgs);
        O.Add('highest', M^.GetHighMsgNum);
        End
      Else
        Begin
        O.Add('messages', TJSONNull.Create);
        O.Add('highest', TJSONNull.Create);
        End;
      If M <> Nil Then
        If CloseMsgArea(M) Then;
      Arr.Add(O);
      End;
  Result.Add('areas', Arr);
  End;


Function CompareNamesNoCase(List: TStringList; I1, I2: Integer): Integer;
  Begin
  Result := CompareText(List[I1], List[I2]);
  If Result = 0 Then
    Result := CompareStr(List[I1], List[I2]);
  End;


Function CountListed(Const ListFile: String): Integer;
  Var
    L: TStringList;
    i: Integer;

  Begin
  Result := 0;
  If Not FileExists(ListFile) Then
    Exit;
  L := TStringList.Create;
  Try
    L.LoadFromFile(ListFile);
    For i := 0 To L.Count - 1 Do
      If (L[i] <> '') And (L[i][1] > ' ') And (L[i][1] <> ';') And (L[i][1] <> '/') Then
        Inc(Result);
  Finally
    L.Free;
  End;
  End;


Function ApiFileAreas: TJSONObject;
  Var
    Arr: TJSONArray;
    O: TJSONObject;
    i, Count: Integer;
    Dir, ListFile: String;
    SR: TSearchRec;
    Bytes, Newest: Int64;

  Begin
  Result := TJSONObject.Create;
  Arr := TJSONArray.Create;
  For i := 1 To Config^.GetMaxFileAreas Do
    If Config^.GetFileAreaName(i) <> '' Then
      Begin
      O := TJSONObject.Create;
      O.Add('number', i);
      O.Add('name', Cp437Str(Config^.GetFileAreaName(i)));
      Dir := Config^.GetFileAreaPath(i);
      ListFile := Config^.GetFileListPath(i);
      If (ListFile = '') Or DirectoryExists(ListFile) Then
        ListFile := IncludeTrailingPathDelimiter(Dir) + 'files.bbs';
      Count := 0;
      Bytes := 0;
      Newest := 0;
      If (Dir <> '') And DirectoryExists(Dir) Then
        Begin
        If FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 Then
          Begin
          Repeat
            If ((SR.Attr And faDirectory) = 0) And (SR.Name[1] <> '.') And (LowerCase(SR.Name) <> 'files.bbs') And (LowerCase(SR.Name) <> 'files.bbs.bak') Then
              Begin
              Inc(Count);
              Inc(Bytes, SR.Size);
              If SR.Time > Newest Then
                Newest := SR.Time;
              End;
          Until FindNext(SR) <> 0;
          FindClose(SR);
          End;
        O.Add('available', True);
        O.Add('files', Count);
        O.Add('listed', CountListed(ListFile));
        O.Add('bytes', Bytes);
        If Newest > 0 Then
          O.Add('newest', IsoFromUnix(DateTimeToUnix(LocalTimeToUniversal(FileDateToDateTime(Newest)))))
        Else
          O.Add('newest', TJSONNull.Create);
        End
      Else
        O.Add('available', False);
      Arr.Add(O);
      End;
  Result.Add('areas', Arr);
  End;


Function ApiFileList(Area: Integer; Const Query: String): TJSONObject;
  {the files of an area: name, description (from files.bbs, continuation lines joined with a line feed), size and date; a file the list does not name has no description}
  Var
    Dir, ListFile, Q, After, Name, D, T: String;
    Lines: TStringList;
    Desc, Names: TStringList;
    SR: TSearchRec;
    i, k, Limit, Got: Integer;
    Arr: TJSONArray;
    O: TJSONObject;
    Last: String;
    More: Boolean;

  Begin
  Result := Nil;
  If (Area < 1) Or (Area > Config^.GetMaxFileAreas) Or (Config^.GetFileAreaName(Area) = '') Then
    Exit;
  Limit := IntParam(Query, 'limit', 100, 1, 1000);
  After := QueryParam(Query, 'after');
  Q := LowerCase(QueryParam(Query, 'q'));
  Dir := Config^.GetFileAreaPath(Area);
  If (Dir <> '') Then
    Dir := IncludeTrailingPathDelimiter(Dir);
  ListFile := Config^.GetFileListPath(Area);
  If (ListFile = '') Or DirectoryExists(ListFile) Then
    ListFile := Dir + 'files.bbs';
  Result := TJSONObject.Create;
  Result.Add('area', Area);
  Result.Add('name', Cp437Str(Config^.GetFileAreaName(Area)));
  Arr := TJSONArray.Create;
  Result.Add('files', Arr);
  Desc := TStringList.Create;                   {listed name -> description}
  Desc.CaseSensitive := True;
  Names := TStringList.Create;                  {the files that are there}
  Names.CaseSensitive := True;
  If FileExists(ListFile) Then
    Begin
    Lines := TStringList.Create;
    Try
      Lines.LoadFromFile(ListFile);
    Except
      Lines.Clear;
    End;
    k := -1;
    For i := 0 To Lines.Count - 1 Do
      Begin
      T := Lines[i];
      If (T = '') Or (T[1] = ';') Or (T[1] = '/') Then
        Continue;
      If T[1] > ' ' Then
        Begin
        Name := T;
        D := '';
        k := Pos(' ', T);
        If k = 0 Then k := Pos(#9, T);
        If k > 0 Then
          Begin
          Name := Copy(T, 1, k - 1);
          D := Trim(Copy(T, k + 1, 2000));
          End;
        k := Desc.Add(Name + #1 + D);
        End
      Else If k >= 0 Then
        Desc[k] := Desc[k] + #10 + Trim(T);
      End;
    Lines.Free;
    End;
  If (Dir <> '') And DirectoryExists(Dir) Then
    If FindFirst(Dir + '*', faAnyFile, SR) = 0 Then
      Begin
      Repeat
        If ((SR.Attr And faDirectory) = 0) And (SR.Name[1] <> '.') And (LowerCase(SR.Name) <> 'files.bbs') And (LowerCase(SR.Name) <> 'files.bbs.bak') And (LowerCase(SR.Name) <> 'files.bbs.new') Then
          Names.AddObject(SR.Name, TObject(PtrInt(SR.Time)));
      Until FindNext(SR) <> 0;
      FindClose(SR);
      End;
  Names.CustomSort(@CompareNamesNoCase);
  Got := 0;
  Last := '';
  More := False;
  For i := 0 To Names.Count - 1 Do
    Begin
    Name := Names[i];
    If (After <> '') And (CompareText(Name, After) <= 0) Then
      Continue;
    D := '';
    For k := 0 To Desc.Count - 1 Do
      If Copy(Desc[k], 1, Length(Name) + 1) = Name + #1 Then
        D := Copy(Desc[k], Length(Name) + 2, 4000);
    If (Q <> '') And (Pos(Q, LowerCase(Name)) = 0) And (Pos(Q, LowerCase(D)) = 0) Then
      Continue;
    If Got >= Limit Then
      Begin
      More := True;
      Break;
      End;
    O := TJSONObject.Create;
    O.Add('name', Name);
    If D <> '' Then
      O.Add('description', Cp437Str(D))
    Else
      O.Add('description', TJSONNull.Create);
    If FindFirst(Dir + Name, faAnyFile, SR) = 0 Then
      Begin
      O.Add('size', SR.Size);
      O.Add('date', FormatDateTime('yyyy-mm-dd', FileDateToDateTime(SR.Time)));
      FindClose(SR);
      End;
    Arr.Add(O);
    Last := Name;
    Inc(Got);
    End;
  Result.Add('count', Got);
  If More Then
    Result.Add('next', Last)
  Else
    Result.Add('next', TJSONNull.Create);
  Desc.Free;
  Names.Free;
  End;


{------------------------------------------------------------ messages}

Function AddrStr(Var A: AddrType): String;
  Begin
  Result := IntToStr(A.Zone) + ':' + IntToStr(A.Net) + '/' + IntToStr(A.Node);
  If A.Point <> 0 Then
    Result := Result + '.' + IntToStr(A.Point);
  End;


Function OpenArea(Area: Integer; Var M: AbsMsgPtr; Var Err: String): Boolean;
  Var
    Id: String;

  Begin
  Result := False;
  M := Nil;
  If (Area < 1) Or (Area > Config^.GetMaxMsgAreas) Or (Config^.GetMsgName(Area) = '') Then
    Begin
    Err := 'no such message area';
    Exit;
    End;
  Id := Config^.GetMsgAreaId(Area);
  If (Id = '') Or Not OpenMsgArea(M, Id) Then
    Begin
    Err := 'the message base cannot be opened';
    Exit;
    End;
  Result := True;
  End;


Function HeaderJson(M: AbsMsgPtr): TJSONObject;
  {the header of the current message; MsgStartUp has been done}
  Var
    D: String;

  Begin
  Result := TJSONObject.Create;
  Result.Add('number', M^.GetMsgNum);
  Result.Add('from', Cp437Str(M^.GetFrom));
  Result.Add('to', Cp437Str(M^.GetTo));
  Result.Add('subject', Cp437Str(M^.GetSubj));
  D := IsoDate(M^.GetDate);
  If D <> '' Then
    Result.Add('date', D)
  Else
    Result.Add('date', TJSONNull.Create);
  Result.Add('time', M^.GetTime);
  Result.Add('private', M^.IsPriv);
  Result.Add('received', M^.IsRcvd);
  Result.Add('local', M^.IsLocal);
  If M^.GetRefer > 0 Then
    Result.Add('reply_to', M^.GetRefer)
  Else
    Result.Add('reply_to', TJSONNull.Create);
  End;


Function ApiMsgList(Area: Integer; Const Query: String; Private_: Boolean; Var Err: String): TJSONObject;
  {the headers of an area: public messages, not deleted (private ones with the scope messages:private), from the number after "after", at most "limit"}
  Var
    M: AbsMsgPtr;
    Arr: TJSONArray;
    After, Limit, Got, Last: Int64;
    Q: String;
    More: Boolean;

  Begin
  Result := Nil;
  If Not OpenArea(Area, M, Err) Then
    Exit;
  Limit := IntParam(Query, 'limit', 100, 1, 500);
  After := IntParam(Query, 'after', 0, 0, 2147483646);
  Q := LowerCase(QueryParam(Query, 'q'));
  Result := TJSONObject.Create;
  Result.Add('area', Area);
  Result.Add('name', Cp437Str(Config^.GetMsgName(Area)));
  Arr := TJSONArray.Create;
  Result.Add('messages', Arr);
  Got := 0;
  Last := 0;
  More := False;
  M^.SeekFirst(After + 1);
  While M^.SeekFound Do
    Begin
    M^.MsgStartUp;
    If (Not M^.IsDeleted) And (Private_ Or Not M^.IsPriv) Then
      Begin
      If (Q = '') Or (Pos(Q, LowerCase(Cp437Str(M^.GetSubj))) > 0) Or (Pos(Q, LowerCase(Cp437Str(M^.GetFrom))) > 0) Or (Pos(Q, LowerCase(Cp437Str(M^.GetTo))) > 0) Then
        Begin
        If Got >= Limit Then
          Begin
          More := True;
          Break;
          End;
        Arr.Add(HeaderJson(M));
        Last := M^.GetMsgNum;
        Inc(Got);
        End;
      End;
    M^.SeekNext;
    End;
  Result.Add('count', Got);
  If More Then
    Result.Add('next', Last)
  Else
    Result.Add('next', TJSONNull.Create);
  If CloseMsgArea(M) Then;
  End;


Function ApiMsg(Area, Num: Integer; Private_: Boolean; Var Err: String): TJSONObject;
  {one message: the header, the addresses, the kludge lines and the text (CP437 as UTF-8, lines joined with a line feed, at most 200000 characters)}
  Const
    MaxText = 200000;

  Var
    M: AbsMsgPtr;
    O: TJSONObject;
    A: AddrType;
    Kl: TJSONArray;
    Text, S, Line: String;
    Wrapped, Cut: Boolean;

  Begin
  Result := Nil;
  If Not OpenArea(Area, M, Err) Then
    Exit;
  M^.SeekFirst(Num);
  If (Not M^.SeekFound) Or (M^.GetMsgNum <> Num) Then
    Begin
    Err := 'no such message';
    If CloseMsgArea(M) Then;
    Exit;
    End;
  M^.MsgStartUp;
  If M^.IsDeleted Or (M^.IsPriv And Not Private_) Then
    Begin
    Err := 'no such message';
    If CloseMsgArea(M) Then;
    Exit;
    End;
  O := HeaderJson(M);
  O.Add('area', Area);
  If M^.GetSeeAlso > 0 Then
    O.Add('see_also', M^.GetSeeAlso)
  Else
    O.Add('see_also', TJSONNull.Create);
  M^.GetOrig(A);
  If (A.Zone <> 0) Or (A.Net <> 0) Or (A.Node <> 0) Then
    O.Add('origin_address', AddrStr(A))
  Else
    O.Add('origin_address', TJSONNull.Create);
  M^.GetDest(A);
  If (A.Zone <> 0) Or (A.Net <> 0) Or (A.Node <> 0) Then
    O.Add('destination_address', AddrStr(A))
  Else
    O.Add('destination_address', TJSONNull.Create);
  Kl := TJSONArray.Create;
  Text := '';
  Cut := False;
  Wrapped := False;
  M^.MsgTxtStartUp;
  While (Not M^.EOM) And (Not Cut) Do
    Begin
    S := M^.GetString(250);
    If (S <> '') And (S[1] = #1) Then
      Begin
      Kl.Add(Cp437Str(Copy(S, 2, 250)));
      Continue;
      End;
    Line := Cp437Str(S);
    If (Text <> '') And Not Wrapped Then
      Text := Text + #10;
    Text := Text + Line;
    Wrapped := M^.WasWrap;
    If Length(Text) > MaxText Then
      Cut := True;
    End;
  O.Add('kludges', Kl);
  O.Add('text', Text);
  O.Add('truncated', Cut);
  If CloseMsgArea(M) Then;
  Result := O;
  End;


{------------------------------------------------------------ users}

Function UserJson(Pos_: Integer): TJSONObject;
  Var
    Sec: SecType;

  Begin
  Result := TJSONObject.Create;
  NameSearch.GoToPosition(Pos_);
  NameSearch.GetSec(Sec);
  Result.Add('number', Pos_);
  Result.Add('name', Cp437Str(NameSearch.GetName));
  If NameSearch.GetHandle <> '' Then
    Result.Add('handle', Cp437Str(NameSearch.GetHandle))
  Else
    Result.Add('handle', TJSONNull.Create);
  Result.Add('city', Cp437Str(NameSearch.GetLocation));
  Result.Add('level', Sec.Level);
  Result.Add('calls', NameSearch.GetTimesCalled);
  If IsoDate(NameSearch.GetFirstDate) <> '' Then Result.Add('first_call', IsoDate(NameSearch.GetFirstDate)) Else Result.Add('first_call', TJSONNull.Create);
  If IsoDate(NameSearch.GetLastDate) <> '' Then Result.Add('last_call', IsoDate(NameSearch.GetLastDate)) Else Result.Add('last_call', TJSONNull.Create);
  Result.Add('upload_files', NameSearch.GetULFiles);
  Result.Add('download_files', NameSearch.GetDLFiles);
  Result.Add('upload_k', NameSearch.GetULK);
  Result.Add('download_k', NameSearch.GetDLK);
  Result.Add('messages', NameSearch.GetMsgsEntered);
  Result.Add('deleted', NameSearch.IsDeleted);
  Result.Add('qwk_node', NameSearch.IsQwkNode);
  End;


Procedure OpenUsers;
  Var
    BbsType: Word;

  Begin
  BbsType := DetectBbsType;
  NameSearch.Init;
  NameSearch.SetBbsType(BbsType);
  NameSearch.SetCreate(False);
  NameSearch.GoToPosition(0);
  End;


Function ApiUsers(Const Query: String): TJSONObject;
  Var
    Arr: TJSONArray;
    Limit, After, N, i, Got: Integer;
    Q, Name, Hd: String;
    WithDeleted, More: Boolean;
    LastNum: Integer;

  Begin
  LastNum := -1;
  Limit := IntParam(Query, 'limit', 100, 1, 1000);
  After := IntParam(Query, 'after', -1, -1, 1000000);
  Q := LowerCase(QueryParam(Query, 'q'));
  WithDeleted := QueryParam(Query, 'deleted') = '1';
  OpenUsers;
  N := NameSearch.GetNumUsers;
  Result := TJSONObject.Create;
  Arr := TJSONArray.Create;
  Got := 0;
  i := After + 1;
  While (i < N) And (Got < Limit) Do
    Begin
    NameSearch.GoToPosition(i);
    Name := Cp437Str(NameSearch.GetName);
    If (Name <> '') And (WithDeleted Or Not NameSearch.IsDeleted) Then
      Begin
      Hd := '';
      If Q <> '' Then
        Hd := Cp437Str(NameSearch.GetHandle);
      If (Q = '') Or (Pos(Q, LowerCase(Name)) > 0) Or (Pos(Q, LowerCase(Hd)) > 0) Then
        Begin
        Arr.Add(UserJson(i));
        LastNum := i;
        Inc(Got);
        End;
      End;
    Inc(i);
    End;
  Result.Add('users', Arr);
  Result.Add('count', Got);
  { next: the number to give as "after" (the last one of this page) when there are more }
  More := False;
  While (i < N) And (Not More) Do
    Begin
    NameSearch.GoToPosition(i);
    Name := Cp437Str(NameSearch.GetName);
    If (Name <> '') And (WithDeleted Or Not NameSearch.IsDeleted) Then
      Begin
      Hd := '';
      If Q <> '' Then
        Hd := Cp437Str(NameSearch.GetHandle);
      If (Q = '') Or (Pos(Q, LowerCase(Name)) > 0) Or (Pos(Q, LowerCase(Hd)) > 0) Then
        More := True;
      End;
    Inc(i);
    End;
  If More Then
    Result.Add('next', LastNum)
  Else
    Result.Add('next', TJSONNull.Create);
  End;


Function ApiUser(Const Name, Query: String): TJSONObject;
  Var
    N, i: Integer;
    Want: String;
    WithDeleted: Boolean;

  Begin
  Result := Nil;
  Want := LowerCase(Name);
  WithDeleted := QueryParam(Query, 'deleted') = '1';
  OpenUsers;
  N := NameSearch.GetNumUsers;
  For i := 0 To N - 1 Do
    Begin
    NameSearch.GoToPosition(i);
    If LowerCase(Cp437Str(NameSearch.GetName)) = Want Then
      If WithDeleted Or Not NameSearch.IsDeleted Then
        Begin
        Result := UserJson(i);
        Exit;
        End;
    End;
  End;

End.
