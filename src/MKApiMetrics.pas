{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKApiMetrics;   {GET /v1/metrics: the numbers of the BBS in the text format of Prometheus (version 0.0.4)}

{$mode objfpc}{$H+}

{
  Built from the answers the JSON API already has (MKApiData): the nodes in use, the calls of the statistics files, the events, the mailer.  Nothing here reads a file of its own.
  The counters (..._total) are sums over all the monthly statistics files, so they only go up as long as the files stay (a pruned month looks like a restart of the counter to Prometheus,
  which it handles).  A part that is not there (no mailer running, no events file) is reported by its own "up" gauge and has no other lines.
}

Interface

Function ApiMetrics(Const RunDir, BbsDir, Version, BbsName: String): String;

Implementation

Uses SysUtils, Classes, fpjson, MKApiData;


Function Esc(Const S: String): String;
  {a label value: backslash, double quote and line feed escaped}
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(S) Do
    Case S[i] Of
      '\': Result := Result + '\\';
      '"': Result := Result + '\"';
      #10: Result := Result + '\n';
      #13: ;
      Else
        Result := Result + S[i];
      End;
  End;


Var
  Out_: String;


Procedure Head(Const Name, Kind, Help: String);
  Begin
  Out_ := Out_ + '# HELP ' + Name + ' ' + Help + #10 + '# TYPE ' + Name + ' ' + Kind + #10;
  End;


Procedure Line(Const Name, Labels: String; Value: Int64);
  Begin
  If Labels = '' Then
    Out_ := Out_ + Name + ' ' + IntToStr(Value) + #10
  Else
    Out_ := Out_ + Name + '{' + Labels + '} ' + IntToStr(Value) + #10;
  End;


Function Lab(Const Name, Value: String): String;
  Begin
  Result := Name + '="' + Esc(Value) + '"';
  End;


Function IntOf(O: TJSONObject; Const Key: String; Def: Int64 = 0): Int64;
  Var
    D: TJSONData;

  Begin
  Result := Def;
  If O = Nil Then
    Exit;
  D := O.Find(Key);
  If (D <> Nil) And (D.JSONType = jtNumber) Then
    Result := D.AsInt64;
  End;


Function FloatOf(O: TJSONObject; Const Key: String): String;
  {a number with one decimal and a point, whatever the locale}
  Var
    D: TJSONData;
    FS: TFormatSettings;

  Begin
  Result := '0';
  If O = Nil Then
    Exit;
  D := O.Find(Key);
  If (D <> Nil) And (D.JSONType = jtNumber) Then
    Begin
    FS := DefaultFormatSettings;
    FS.DecimalSeparator := '.';
    Result := FormatFloat('0.0', D.AsFloat, FS);
    End;
  End;


Function StrOf(O: TJSONObject; Const Key: String): String;
  Var
    D: TJSONData;

  Begin
  Result := '';
  If O = Nil Then
    Exit;
  D := O.Find(Key);
  If (D <> Nil) And (D.JSONType = jtString) Then
    Result := D.AsString;
  End;


Function BoolOf(O: TJSONObject; Const Key: String): Int64;
  Var
    D: TJSONData;

  Begin
  Result := 0;
  If O = Nil Then
    Exit;
  D := O.Find(Key);
  If (D <> Nil) And (D.JSONType = jtBoolean) And D.AsBoolean Then
    Result := 1;
  End;


Function ObjOf(O: TJSONObject; Const Key: String): TJSONObject;
  Var
    D: TJSONData;

  Begin
  Result := Nil;
  If O = Nil Then
    Exit;
  D := O.Find(Key);
  If (D <> Nil) And (D.JSONType = jtObject) Then
    Result := TJSONObject(D);
  End;


Function ArrOf(O: TJSONObject; Const Key: String): TJSONArray;
  Var
    D: TJSONData;

  Begin
  Result := Nil;
  If O = Nil Then
    Exit;
  D := O.Find(Key);
  If (D <> Nil) And (D.JSONType = jtArray) Then
    Result := TJSONArray(D);
  End;


Procedure Nodes(Const RunDir, BbsDir: String);
  Var
    O: TJSONObject;
    A: TJSONArray;
    i, k: Integer;
    Acts: TStringList;
    N: TJSONObject;

  Begin
  O := ApiNodes(RunDir, BbsDir);
  Head('mkbbs_nodes_in_use', 'gauge', 'Nodes with a caller or a connection now.');
  Line('mkbbs_nodes_in_use', '', IntOf(O, 'count'));
  Acts := TStringList.Create;
  Acts.CaseSensitive := True;
  A := ArrOf(O, 'nodes');
  If A <> Nil Then
    For i := 0 To A.Count - 1 Do
      Begin
      N := TJSONObject(A[i]);
      k := Acts.IndexOf(StrOf(N, 'activity'));
      If k < 0 Then
        Acts.AddObject(StrOf(N, 'activity'), TObject(PtrInt(1)))
      Else
        Acts.Objects[k] := TObject(PtrInt(PtrInt(Acts.Objects[k]) + 1));
      End;
  Head('mkbbs_nodes_activity', 'gauge', 'Nodes in use by what the caller is doing.');
  Acts.Sort;
  For i := 0 To Acts.Count - 1 Do
    Line('mkbbs_nodes_activity', Lab('activity', Acts[i]), PtrInt(Acts.Objects[i]));
  Acts.Free;
  O.Free;
  End;


Procedure Stats(Const BbsDir: String);
  Var
    O, T: TJSONObject;
    Err, Day: String;

  Begin
  Err := '';
  O := ApiStats(BbsDir + 'stats', 'from=1970-01-01&to=9999-12-31', Err);
  If O = Nil Then
    Exit;
  T := ObjOf(O, 'totals');
  Head('mkbbs_calls_total', 'counter', 'Calls by how they ended (logons, failed log-ons, hang-ups before a log-on).');
  Line('mkbbs_calls_total', Lab('result', 'ok'), IntOf(T, 'logons'));
  Line('mkbbs_calls_total', Lab('result', 'failed'), IntOf(T, 'failed'));
  Line('mkbbs_calls_total', Lab('result', 'no_logon'), IntOf(T, 'no_logon'));
  Head('mkbbs_call_minutes_total', 'counter', 'Minutes callers were on line.');
  Out_ := Out_ + 'mkbbs_call_minutes_total ' + FloatOf(T, 'minutes') + #10;
  Head('mkbbs_upload_files_total', 'counter', 'Files uploaded by callers.');
  Line('mkbbs_upload_files_total', '', IntOf(T, 'upload_files'));
  Head('mkbbs_upload_kbytes_total', 'counter', 'Kilobytes uploaded by callers.');
  Line('mkbbs_upload_kbytes_total', '', IntOf(T, 'upload_k'));
  Head('mkbbs_download_files_total', 'counter', 'Files downloaded by callers.');
  Line('mkbbs_download_files_total', '', IntOf(T, 'download_files'));
  Head('mkbbs_download_kbytes_total', 'counter', 'Kilobytes downloaded by callers.');
  Line('mkbbs_download_kbytes_total', '', IntOf(T, 'download_k'));
  Head('mkbbs_messages_total', 'counter', 'Messages written by callers.');
  Line('mkbbs_messages_total', '', IntOf(T, 'messages'));
  O.Free;
  Day := FormatDateTime('yyyy-mm-dd', Now);
  O := ApiStats(BbsDir + 'stats', 'from=' + Day + '&to=' + Day, Err);
  If O <> Nil Then
    Begin
    T := ObjOf(O, 'totals');
    Head('mkbbs_calls_today', 'gauge', 'Calls since midnight.');
    Line('mkbbs_calls_today', '', IntOf(T, 'calls'));
    Head('mkbbs_failed_logons_today', 'gauge', 'Failed log-ons since midnight.');
    Line('mkbbs_failed_logons_today', '', IntOf(T, 'failed'));
    Head('mkbbs_callers_today', 'gauge', 'Different callers since midnight.');
    Line('mkbbs_callers_today', '', IntOf(T, 'callers'));
    O.Free;
    End;
  End;


Procedure Events(Const RunDir: String);
  Var
    O, E: TJSONObject;
    A: TJSONArray;
    i: Integer;
    D: TJSONData;

  Begin
  O := ApiEvents(RunDir);
  Head('mkbbs_events_up', 'gauge', '1 when the listener writes its events file (events.info), 0 when there is none.');
  Line('mkbbs_events_up', '', IntOf(O, 'available'));
  If IntOf(O, 'available') = 1 Then
    Begin
    Head('mkbbs_events_stale', 'gauge', '1 when the events file is older than 15 seconds (the listener is not running).');
    Line('mkbbs_events_stale', '', BoolOf(O, 'stale'));
    Head('mkbbs_new_logons_refused', 'gauge', '1 while an event keeps new callers out.');
    Line('mkbbs_new_logons_refused', '', BoolOf(O, 'new_logons_refused'));
    Head('mkbbs_event_callers', 'gauge', 'Callers the events see on line.');
    Line('mkbbs_event_callers', '', IntOf(O, 'callers'));
    Head('mkbbs_events_queued', 'gauge', 'Events waiting for the callers to leave.');
    Line('mkbbs_events_queued', '', IntOf(O, 'queued'));
    Head('mkbbs_events_running', 'gauge', 'Events running now.');
    Line('mkbbs_events_running', '', IntOf(O, 'running'));
    A := ArrOf(O, 'events');
    If (A <> Nil) And (A.Count > 0) Then
      Begin
      Head('mkbbs_event_enabled', 'gauge', 'An event is enabled (1) or not (0).');
      For i := 0 To A.Count - 1 Do
        Line('mkbbs_event_enabled', Lab('event', IntToStr(IntOf(TJSONObject(A[i]), 'number'))), BoolOf(TJSONObject(A[i]), 'enabled'));
      Head('mkbbs_event_last_result', 'gauge', 'The exit code of the last run of an event (not there: it has not run).');
      For i := 0 To A.Count - 1 Do
        Begin
        E := TJSONObject(A[i]);
        D := E.Find('last_result');
        If (D <> Nil) And (D.JSONType = jtNumber) Then
          Line('mkbbs_event_last_result', Lab('event', IntToStr(IntOf(E, 'number'))), D.AsInt64);
        End;
      Head('mkbbs_event_next_minutes', 'gauge', 'Minutes until an event is due (not there: not scheduled).');
      For i := 0 To A.Count - 1 Do
        Begin
        E := TJSONObject(A[i]);
        D := E.Find('next_in_minutes');
        If (D <> Nil) And (D.JSONType = jtNumber) Then
          Line('mkbbs_event_next_minutes', Lab('event', IntToStr(IntOf(E, 'number'))), D.AsInt64);
        End;
      End;
    End;
  O.Free;
  End;


Procedure Mailer(Const RunDir: String);
  Var
    O, S, L: TJSONObject;
    A: TJSONArray;
    i: Integer;
    nIn, nOut: Integer;

  Begin
  O := ApiMailer(RunDir);
  Head('mkbbs_mailer_up', 'gauge', '1 when the mailer (mkbink) runs under the listener and answers.');
  Line('mkbbs_mailer_up', '', IntOf(O, 'running') * IntOf(O, 'available', 0));
  If (IntOf(O, 'running') = 1) And (IntOf(O, 'available') = 1) Then
    Begin
    S := ObjOf(O, 'statistics');
    Head('mkbbs_mailer_calls_total', 'counter', 'Mailer calls by result (ok, failed) and answered ones.');
    Line('mkbbs_mailer_calls_total', Lab('result', 'ok'), IntOf(S, 'ok'));
    Line('mkbbs_mailer_calls_total', Lab('result', 'failed'), IntOf(S, 'failed'));
    Line('mkbbs_mailer_calls_total', Lab('result', 'answered'), IntOf(S, 'answered'));
    Head('mkbbs_mailer_bytes_total', 'counter', 'Bytes the mailer sent and received.');
    Line('mkbbs_mailer_bytes_total', Lab('direction', 'sent'), IntOf(S, 'bytes_sent'));
    Line('mkbbs_mailer_bytes_total', Lab('direction', 'received'), IntOf(S, 'bytes_received'));
    Head('mkbbs_mailer_files_total', 'counter', 'Files the mailer sent and received.');
    Line('mkbbs_mailer_files_total', Lab('direction', 'sent'), IntOf(S, 'files_sent'));
    Line('mkbbs_mailer_files_total', Lab('direction', 'received'), IntOf(S, 'files_received'));
    A := ArrOf(O, 'sessions');
    Head('mkbbs_mailer_sessions', 'gauge', 'Mailer sessions now.');
    nIn := 0;
    nOut := 0;
    If A <> Nil Then
      For i := 0 To A.Count - 1 Do
        If StrOf(TJSONObject(A[i]), 'direction') = 'out' Then Inc(nOut) Else Inc(nIn);
    Line('mkbbs_mailer_sessions', Lab('direction', 'out'), nOut);
    Line('mkbbs_mailer_sessions', Lab('direction', 'in'), nIn);
    A := ArrOf(O, 'links');
    If (A <> Nil) And (A.Count > 0) Then
      Begin
      Head('mkbbs_mailer_link_failures', 'gauge', 'Failed calls in a row to a link.');
      For i := 0 To A.Count - 1 Do
        Line('mkbbs_mailer_link_failures', Lab('link', StrOf(TJSONObject(A[i]), 'address')), IntOf(TJSONObject(A[i]), 'failures'));
      Head('mkbbs_mailer_link_waiting_files', 'gauge', 'Files waiting for a link.');
      For i := 0 To A.Count - 1 Do
        Line('mkbbs_mailer_link_waiting_files', Lab('link', StrOf(TJSONObject(A[i]), 'address')), IntOf(TJSONObject(A[i]), 'waiting_files'));
      Head('mkbbs_mailer_link_waiting_bytes', 'gauge', 'Bytes waiting for a link.');
      For i := 0 To A.Count - 1 Do
        Begin
        L := TJSONObject(A[i]);
        Line('mkbbs_mailer_link_waiting_bytes', Lab('link', StrOf(L, 'address')), IntOf(L, 'waiting_bytes'));
        End;
      End;
    End;
  O.Free;
  End;


Function ApiMetrics(Const RunDir, BbsDir, Version, BbsName: String): String;
  Begin
  Out_ := '';
  Head('mkbbs_info', 'gauge', 'The BBS and its software version.');
  Line('mkbbs_info', Lab('version', Version) + ',' + Lab('bbs', BbsName), 1);
  Nodes(RunDir, BbsDir);
  Stats(BbsDir);
  Events(RunDir);
  Mailer(RunDir);
  Result := Out_;
  End;


End.
