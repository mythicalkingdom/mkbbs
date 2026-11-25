Program MKApi;

{$mode objfpc}{$H+}

{
     mkapi: one request of the JSON API.  mklisten starts it for each connection of a port of the type "api" (the connection is on standard input and output, as for mk), with
       -A<address>   the caller's address       -H   a PROXY header comes first       -Y   TLS: the handshake is done first (MK_TLS_CERT, MK_TLS_KEY)
     and MK = the BBS configuration directory.  HTTP/1.1, one request, then the connection is closed.  Every path says which methods it takes (GET and HEAD, or POST / PUT for the ones that change
     something) and how big a body may be; the body is read to a spool file after the token has been checked (Content-Length only, no chunked requests; "Expect: 100-continue" is answered; 413 when it
     is over the limit, 408 when it stops coming), the answers are JSON or a file that is streamed (a packet).  The paths that read are GET and HEAD only.

     The token (Authorization: Bearer mkapi_...) is looked up in apitokens.json in the BBS directory (mkapitoken makes them).  No token, a token that is not known, expired, not for this address:
     401 and the exit code 88, which mklisten counts as a failed log-on of the address (the login guard); a token without the scope of the endpoint: 403 and 88 too.  Every request is one line on
     standard error (mklisten's log): the id of the token, the address, the request, the answer; never the token.

       GET /v1                  the paths and the scopes of the token
       GET /v1/status           scope status      GET /v1/nodes     scope nodes     GET /v1/events   scope events     GET /v1/mailer  scope mailer
       GET /v1/stats?from=&to=&by=   scope stats  GET /v1/calls?limit=&since=   scope calls
       GET /v1/messages/<area>?q=&limit=&after=, /v1/messages/<area>/<number>   scope messages (headers; one message with its text; private ones need messages:private)
       GET /v1/areas/messages, /v1/areas/files   scope areas      GET /v1/areas/files/<area>?q=&limit=&after=   scope files (name, description, size, date)
       GET /v1/users?q=&limit=&after=&deleted=1, /v1/users/<name>   scope users
     The answers are built in MKApiData from the files and the socket the BBS has (node files, useron.bbs, events.info, the mailer's control socket, stats/*.tsv, the bases, the user file).
}

Uses SysUtils, Classes, BaseUnix, DateUtils, fpjson, MKPwd,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKComAbs, MKSess, MKApiTok, MKApiData, MKQwkApi;

Const
  Paths: Array[0..16] Of String = ('/v1', '/v1/status', '/v1/nodes', '/v1/events', '/v1/mailer', '/v1/stats', '/v1/calls', '/v1/areas/messages', '/v1/areas/files', '/v1/areas/files/{area}', '/v1/messages/{area}', '/v1/messages/{area}/{number}', '/v1/qwk', '/v1/qwk/packet', '/v1/qwk/packet/{id}/ack', '/v1/qwk/reply', '/v1/users');
  MaxHead = 8192;
  MaxLine = 2048;
  ReadSecs = 10;
  BodyTotalSecs = 600;                {the whole body}

Var
  Com: AbsComPtr;
  Addr, Method, Target, Path, Query, Auth, TokenId, Head_: String;
  Proxy: Boolean;
  Tokens: TApiTokens;
  TokIdx: Integer;
  TokFile, UseFile: String;
  BodyIdleSecs: Integer;              {no byte of a body for this long: 408 (60; MKAPI_BODY_IDLE says another number, for the tests)}
  Sent: Boolean;
  ContentLen: Int64;                  {Content-Length of the request, -1 when there is none}
  BodyFile: String;                   {the spool file of the body ('' when there is none)}
  ReqIn, RespOut: Int64;              {bytes of the body in, bytes of the answer out (the log line)}
  TestPaths: Boolean;                 {MKAPI_TEST=1: the paths /v1/test/... of the tests of the machinery}


Procedure Log(S: String);
  Begin
  S := 'api: ' + S + #10;
  fpWrite(2, S[1], Length(S));
  End;


Procedure SendAll(S: String);
  Var
    Done, N: LongInt;

  Begin
  Done := 0;
  While Done < Length(S) Do
    Begin
    N := Length(S) - Done;
    If N > 8000 Then
      N := 8000;
    If Com^.SendBlock(S[Done + 1], N) = 0 Then
      Exit;
    Inc(Done, N);
    End;
  End;


Function Reason(Code: Integer): String;
  Begin
  Case Code Of
    100: Result := 'Continue';
    200: Result := 'OK';
    204: Result := 'No Content';
    400: Result := 'Bad Request';
    401: Result := 'Unauthorized';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    408: Result := 'Request Timeout';
    409: Result := 'Conflict';
    410: Result := 'Gone';
    411: Result := 'Length Required';
    413: Result := 'Payload Too Large';
    414: Result := 'URI Too Long';
    415: Result := 'Unsupported Media Type';
    423: Result := 'Locked';
    431: Result := 'Request Header Fields Too Large';
    Else
      Result := 'Error';
    End;
  End;


Procedure LogRequest(Code: Integer);
  {the one line of every request: who, from where, what, the answer, the bytes of the body that came and of the answer that went}
  Var
    S: String;

  Begin
  S := Copy('-' + TokenId, 1 + Ord(TokenId <> ''), 40) + ' ' + Addr + ' ' + Method + ' ' + Copy(Target, 1, 100) + ' ' + IntToStr(Code);
  If ReqIn > 0 Then
    S := S + ' in=' + IntToStr(ReqIn);
  S := S + ' out=' + IntToStr(RespOut);
  Log(S);
  End;


Procedure Answer(Code: Integer; Body: String; Extra: String = '');
  {the whole answer; HEAD gets the headers and the length of the body, not the body}
  Var
    H: String;

  Begin
  Sent := True;
  H := 'HTTP/1.1 ' + IntToStr(Code) + ' ' + Reason(Code) + #13#10 +
    'Content-Type: application/json; charset=utf-8'#13#10 +
    'Content-Length: ' + IntToStr(Length(Body)) + #13#10 +
    'Cache-Control: no-store'#13#10 +
    'X-Content-Type-Options: nosniff'#13#10 +
    'Connection: close'#13#10 + Extra + #13#10;
  If Method <> 'HEAD' Then
    H := H + Body;
  SendAll(H);
  Com^.FlushOut;
  RespOut := Length(Body);
  LogRequest(Code);
  End;


Procedure ErrorAnswer(Code: Integer; Msg: String; Extra: String = '');
  Var
    O: TJSONObject;

  Begin
  O := TJSONObject.Create;
  O.Add('error', Msg);
  Answer(Code, O.AsJSON + #10, Extra);
  O.Free;
  End;


Procedure CleanupBody;
  Begin
  If BodyFile <> '' Then
    DeleteFile(BodyFile);
  BodyFile := '';
  End;


Procedure Finish(Code: Integer);
  Begin
  CleanupBody;
  Com^.Hangup;
  Halt(Code);
  End;


Function ReadRequest(Var Head: String): Boolean;
  {up to the empty line; False: nothing came in time, too long or the caller left}
  Var
    Start: TDateTime;
    Ch: Char;

  Begin
  Result := False;
  Head := '';
  Start := Now;
  While Pos(#13#10#13#10, Head) = 0 Do
    Begin
    If Length(Head) > MaxHead Then
      Exit;
    If (Now - Start) * 86400 > ReadSecs Then
      Exit;
    If Not Com^.WaitForChar(500) Then
      Begin
      If Not Com^.GetCarrier Then
        Exit;
      Continue;
      End;
    Ch := Com^.GetChar;
    Head := Head + Ch;
    If (Length(Head) >= 2) And (Copy(Head, Length(Head) - 1, 2) = #10#10) Then
      Exit;                                {bare line feeds: not HTTP}
    End;
  Result := True;
  End;


Function HeaderValue(Const Head, Name: String): String;
  Var
    L: TStringList;
    i, p: Integer;

  Begin
  Result := '';
  L := TStringList.Create;
  L.Text := Head;
  For i := 1 To L.Count - 1 Do
    Begin
    p := Pos(':', L[i]);
    If (p > 1) And (LowerCase(Trim(Copy(L[i], 1, p - 1))) = LowerCase(Name)) Then
      Result := Trim(Copy(L[i], p + 1, 2000));
    End;
  L.Free;
  End;


Function UtcOffset: String;
  Var
    Off: Integer;

  Begin
  Off := -GetLocalTimeOffset;
  Result := Format('%s%.2d:%.2d', [Copy('-+', 1 + Ord(Off >= 0), 1), Abs(Off) Div 60, Abs(Off) Mod 60]);
  End;


Function IsoNow: String;
  Begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now) + UtcOffset;
  End;


Function CountNodes: Integer;
  {the nodes that are in use: node<N>.info files of the run directory whose process is there}
  Var
    SR: TSearchRec;
    Dir, Pid: String;
    L: TStringList;
    i: Integer;

  Begin
  Result := 0;
  Dir := GetEnvironmentVariable('MKRUN');
  If Dir = '' Then
    Exit;
  If FindFirst(Dir + '/node*.info', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      L := TStringList.Create;
      Try
        L.LoadFromFile(Dir + '/' + SR.Name);
        Pid := L.Values['pid'];
        If (StrToIntDef(Pid, 0) > 0) And ((fpKill(StrToInt(Pid), 0) = 0) Or (fpGetErrno = ESysEPERM)) Then
          Inc(Result);
      Except
        i := 0;
      End;
      L.Free;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  End;


Procedure Need(Const Scope: String);
  Begin
  If Not HasScope(Tokens[TokIdx], Scope) Then
    Begin
    ErrorAnswer(403, 'not allowed');
    Finish(88);
    End;
  End;


Procedure Send(O: TJSONObject);
  Begin
  Answer(200, O.AsJSON + #10);
  O.Free;
  End;



Procedure NoContent(Extra: String = '');
  {204: no body, no Content-Length}
  Begin
  Sent := True;
  SendAll('HTTP/1.1 204 No Content'#13#10'Cache-Control: no-store'#13#10'X-Content-Type-Options: nosniff'#13#10'Connection: close'#13#10 + Extra + #13#10);
  Com^.FlushOut;
  RespOut := 0;
  LogRequest(204);
  End;


Procedure AnswerFile(Code: Integer; ContentType, FN: String; Extra: String = '');
  {a file as the body, streamed (HEAD: the headers and the length only)}
  Var
    Fs: TFileStream;
    Buf: Array[0..7999] Of Byte;
    N: LongInt;
    Size: Int64;
    H: String;

  Begin
  Fs := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
  Try
    Size := Fs.Size;
    Sent := True;
    H := 'HTTP/1.1 ' + IntToStr(Code) + ' ' + Reason(Code) + #13#10 +
      'Content-Type: ' + ContentType + #13#10 +
      'Content-Length: ' + IntToStr(Size) + #13#10 +
      'Cache-Control: no-store'#13#10 +
      'X-Content-Type-Options: nosniff'#13#10 +
      'Connection: close'#13#10 + Extra + #13#10;
    SendAll(H);
    RespOut := 0;
    If Method <> 'HEAD' Then
      Repeat
        N := Fs.Read(Buf, SizeOf(Buf));
        If N > 0 Then
          Begin
          If Com^.SendBlock(Buf, N) = 0 Then
            Break;
          Inc(RespOut, N);
          If Not Com^.GetCarrier Then
            Break;
          End;
      Until N <= 0;
    Com^.FlushOut;
  Finally
    Fs.Free;
  End;
  LogRequest(Code);
  End;


{------------------------------------------------------------ what a path takes}

Type
  TRule = Record
    Methods: String;                  {GET HEAD POST PUT, separated by blanks}
    MaxBody: Int64;                   {0: no body}
    End;


Function RuleFor(Const P: String; Var R: TRule): Boolean;
  {the methods and the body limit of a path; False for a path that is not one (the route says 404)}
  Var
    MaxP, MaxR, Keep: Int64;

  Begin
  Result := True;
  R.Methods := 'GET HEAD';
  R.MaxBody := 0;
  If (P = '/v1') Or (P = '/v1/status') Or (P = '/v1/nodes') Or (P = '/v1/events') Or (P = '/v1/mailer') Or (P = '/v1/stats') Or (P = '/v1/calls') Or (P = '/v1/areas/messages') Or (P = '/v1/areas/files') Or
     (P = '/v1/users') Or (Copy(P, 1, 16) = '/v1/areas/files/') Or (Copy(P, 1, 13) = '/v1/messages/') Or (Copy(P, 1, 10) = '/v1/users/') Then
    Exit;
  If (P = '/v1/qwk') Or (P = '/v1/qwk/packet') Then
    Exit;
  If P = '/v1/qwk/reply' Then
    Begin
    QwkLimits(MaxP, MaxR, Keep);
    R.Methods := 'PUT';
    R.MaxBody := MaxR;
    Exit;
    End;
  If (Copy(P, 1, 15) = '/v1/qwk/packet/') And (Copy(P, Length(P) - 3, 4) = '/ack') Then
    Begin
    R.Methods := 'POST';
    Exit;
    End;
  If TestPaths Then
    Begin
    If P = '/v1/test/echo' Then
      Begin
      R.Methods := 'POST PUT';
      R.MaxBody := 100000;
      Exit;
      End;
    If P = '/v1/test/blob' Then
      Exit;
    End;
  Result := False;
  End;


Function AllowHeader(Const Methods: String): String;
  Begin
  Result := 'Allow: ' + StringReplace(Trim(Methods), ' ', ', ', [rfReplaceAll]) + #13#10;
  End;


Function SpoolName(Const Kind: String): String;
  {a file in the temporary folder of the BBS (the folder of the configuration, else tmp/ in the BBS folder, else the system's)}
  Var
    D: String;

  Begin
  D := Config^.GetTempPath;
  If (D = '') Or Not DirectoryExists(D) Then
    D := Config^.GetBbsPath + 'tmp/';
  If Not DirectoryExists(D) Then
    D := GetTempDir;
  Result := IncludeTrailingPathDelimiter(D) + 'api' + IntToStr(fpGetPid) + '.' + Kind;
  End;


Procedure ReadBody(Len: Int64);
  {the body to a spool file: up to Len bytes, no byte for BodyIdleSecs or more than BodyTotalSecs altogether = 408; a caller who goes = the request is dropped without an answer}
  Var
    Fs: TFileStream;
    Buf: Array[0..4095] Of Byte;
    Got: Int64;
    N: Word;
    LastByte, Start: TDateTime;

  Begin
  BodyFile := SpoolName('body');
  Fs := TFileStream.Create(BodyFile, fmCreate);
  fpChmod(PChar(BodyFile), &600);
  Got := 0;
  Start := Now;
  LastByte := Now;
  Try
    While Got < Len Do
      Begin
      If Not Com^.WaitForChar(1000) Then
        Begin
        If Not Com^.GetCarrier Then
          Begin
          ReqIn := Got;
          Log(Copy('-' + TokenId, 1 + Ord(TokenId <> ''), 40) + ' ' + Addr + ' ' + Method + ' ' + Copy(Target, 1, 100) + ' the caller went after ' + IntToStr(Got) + ' of ' + IntToStr(Len) + ' bytes');
          Fs.Free;
          Fs := Nil;
          CleanupBody;
          Halt(0);
          End;
        If ((Now - LastByte) * 86400 > BodyIdleSecs) Or ((Now - Start) * 86400 > BodyTotalSecs) Then
          Begin
          Fs.Free;
          Fs := Nil;
          ReqIn := Got;
          ErrorAnswer(408, 'the body did not come in time');
          Finish(0);
          End;
        Continue;
        End;
      N := SizeOf(Buf);
      If Len - Got < N Then
        N := Len - Got;
      N := Com^.GetBlock(Buf, N);
      If N > 0 Then
        Begin
        Fs.WriteBuffer(Buf, N);
        Inc(Got, N);
        LastByte := Now;
        If (Now - Start) * 86400 > BodyTotalSecs Then
          Begin
          Fs.Free;
          Fs := Nil;
          ReqIn := Got;
          ErrorAnswer(408, 'the body did not come in time');
          Finish(0);
          End;
        End;
      End;
  Finally
    Fs.Free;
  End;
  ReqIn := Got;
  End;


Procedure PrepareBody(Const P: String);
  {after the token: what the path takes (the method; a body or not), then the body is read to the spool file.  Nothing for a path that is not one: the route answers 404}
  Var
    R: TRule;
    T: String;
    Chunked: Boolean;

  Begin
  If Not RuleFor(P, R) Then
    Exit;
  If Pos(' ' + Method + ' ', ' ' + R.Methods + ' ') = 0 Then
    Begin
    ErrorAnswer(405, 'this path does not take ' + Method, AllowHeader(R.Methods));
    Finish(0);
    End;
  T := HeaderValue(Head_, 'Transfer-Encoding');
  Chunked := (T <> '') And (LowerCase(T) <> 'identity');
  If Chunked Then
    Begin
    ErrorAnswer(400, 'a chunked body is not supported: send Content-Length');
    Finish(0);
    End;
  If R.MaxBody = 0 Then
    Begin
    If (ContentLen > 0) Then
      Begin
      ErrorAnswer(400, 'this path has no body');
      Finish(0);
      End;
    Exit;
    End;
  If ContentLen < 0 Then
    Begin
    ErrorAnswer(411, 'Content-Length is needed');
    Finish(0);
    End;
  If ContentLen > R.MaxBody Then
    Begin
    ErrorAnswer(413, 'the body is over the limit of ' + IntToStr(R.MaxBody) + ' bytes');
    Finish(0);
    End;
  If LowerCase(HeaderValue(Head_, 'Expect')) = '100-continue' Then
    Begin
    SendAll('HTTP/1.1 100 Continue'#13#10#13#10);
    Com^.FlushOut;
    End;
  If ContentLen > 0 Then
    ReadBody(ContentLen);
  End;


Procedure Route;
  Var
    O, N: TJSONObject;
    A: TJSONArray;
    i: Integer;
    Err, RunDir, BbsDir, P, Name, BlobName: String;
    Fs: TFileStream;
    Blob: Int64;
    Bt: Byte;
    Node: String;
    Code: Integer;
    MaxP, MaxR, Keep: Int64;
    QRes: TQwkRes;
    Ans: TJSONObject;

  Begin
  RunDir := GetEnvironmentVariable('MKRUN');
  BbsDir := Config^.GetBbsPath;
  If (BbsDir <> '') And (BbsDir[Length(BbsDir)] <> '/') Then
    BbsDir := BbsDir + '/';
  P := Path;
  If (Length(P) > 1) And (P[Length(P)] = '/') Then
    Delete(P, Length(P), 1);
  Err := '';
  If P = '/v1' Then
    Begin
    O := TJSONObject.Create;
    O.Add('api', 'mkapi');
    O.Add('version', 1);
    O.Add('bbs', Cp437Str(Config^.GetBbsName));
    O.Add('token', Tokens[TokIdx].Id);
    A := TJSONArray.Create;
    For i := 0 To Tokens[TokIdx].Scopes.Count - 1 Do
      A.Add(Tokens[TokIdx].Scopes[i]);
    O.Add('scopes', A);
    A := TJSONArray.Create;
    For i := 0 To High(Paths) Do
      A.Add(Paths[i]);
    O.Add('paths', A);
    Send(O);
    End
  Else If P = '/v1/status' Then
    Begin
    Need('status');
    O := TJSONObject.Create;
    O.Add('bbs', Cp437Str(Config^.GetBbsName));
    O.Add('software', Cp437Str(BbsVersion));
    O.Add('time', IsoNow);
    N := TJSONObject.Create;
    N.Add('in_use', CountNodes);
    O.Add('nodes', N);
    Send(O);
    End
  Else If P = '/v1/nodes' Then
    Begin
    Need('nodes');
    Send(ApiNodes(RunDir, BbsDir));
    End
  Else If P = '/v1/events' Then
    Begin
    Need('events');
    Send(ApiEvents(RunDir));
    End
  Else If P = '/v1/mailer' Then
    Begin
    Need('mailer');
    Send(ApiMailer(RunDir));
    End
  Else If P = '/v1/stats' Then
    Begin
    Need('stats');
    O := ApiStats(BbsDir + 'stats', Query, Err);
    If O = Nil Then
      ErrorAnswer(400, Err)
    Else
      Send(O);
    End
  Else If P = '/v1/calls' Then
    Begin
    Need('calls');
    O := ApiCalls(BbsDir + 'stats', Query, Err);
    If O = Nil Then
      ErrorAnswer(400, Err)
    Else
      Send(O);
    End
  Else If P = '/v1/areas/messages' Then
    Begin
    Need('areas');
    Send(ApiMsgAreas);
    End
  Else If P = '/v1/areas/files' Then
    Begin
    Need('areas');
    Send(ApiFileAreas);
    End
  Else If Copy(P, 1, 16) = '/v1/areas/files/' Then
    Begin
    Need('files');
    O := ApiFileList(StrToIntDef(Copy(P, 17, 10), 0), Query);
    If O = Nil Then
      ErrorAnswer(404, 'no such file area')
    Else
      Send(O);
    End
  Else If Copy(P, 1, 13) = '/v1/messages/' Then
    Begin
    Need('messages');
    Name := Copy(P, 14, 40);                {<area> or <area>/<number>}
    i := Pos('/', Name);
    If i = 0 Then
      O := ApiMsgList(StrToIntDef(Name, 0), Query, HasScope(Tokens[TokIdx], 'messages:private'), Err)
    Else
      O := ApiMsg(StrToIntDef(Copy(Name, 1, i - 1), 0), StrToIntDef(Copy(Name, i + 1, 12), 0), HasScope(Tokens[TokIdx], 'messages:private'), Err);
    If O = Nil Then
      ErrorAnswer(404, Err)
    Else
      Send(O);
    End
  Else If TestPaths And (P = '/v1/test/echo') Then
    Begin
    Need('*');
    O := TJSONObject.Create;
    O.Add('bytes', ReqIn);
    If (BodyFile <> '') And (ReqIn > 0) Then
      Begin
      Fs := TFileStream.Create(BodyFile, fmOpenRead);
      SetLength(Name, Fs.Size);
      Fs.ReadBuffer(Name[1], Fs.Size);
      Fs.Free;
      O.Add('sha256', HashToken(Name));
      End
    Else
      O.Add('sha256', HashToken(''));
    O.Add('content_type', HeaderValue(Head_, 'Content-Type'));
    Send(O);
    End
  Else If TestPaths And (P = '/v1/test/blob') Then
    Begin
    Need('*');
    Blob := StrToInt64Def(QueryParam(Query, 'size'), 1000);
    If (Blob < 0) Or (Blob > 5000000) Then
      ErrorAnswer(400, 'size is 0 to 5000000')
    Else
      Begin
      BlobName := SpoolName('blob');
      Fs := TFileStream.Create(BlobName, fmCreate);
      For i := 0 To Blob - 1 Do
        Begin
        Bt := (i * 7 + 3) Mod 251;
        Fs.WriteBuffer(Bt, 1);
        End;
      Fs.Free;
      AnswerFile(200, 'application/octet-stream', BlobName);
      DeleteFile(BlobName);
      End;
    End
  Else If Copy(P, 1, 7) = '/v1/qwk' Then
    Begin
    If P = '/v1/qwk/reply' Then
      Need('qwk:reply')
    Else
      Need('qwk');
    Node := Tokens[TokIdx].User;
    If Not QwkNodeLoad(Node, Code, Err) Then
      Begin
      ErrorAnswer(Code, Err);
      Finish(88);
      End;
    QwkLimits(MaxP, MaxR, Keep);
    If P = '/v1/qwk' Then
      Send(QwkInfo(Node, MaxP, MaxR, Keep))
    Else If P = '/v1/qwk/packet' Then
      Begin
      QwkPacket(Node, QueryParam(Query, 'rebuild') = '1', MaxP, Keep, QRes);
      If QRes.Code = 200 Then
        AnswerFile(200, 'application/zip', QRes.FilePath, 'X-QWK-Packet: ' + QRes.Id + #13#10 + 'X-QWK-Messages: ' + IntToStr(QRes.Messages) + #13#10 + 'X-QWK-SHA256: ' + QRes.Sha + #13#10 +
          'Content-Disposition: attachment; filename="' + Config^.GetBBSID + '.QWK"'#13#10)
      Else If QRes.Code = 204 Then
        NoContent('X-QWK-Packet: none'#13#10)
      Else
        ErrorAnswer(QRes.Code, QRes.Err);
      End
    Else If P = '/v1/qwk/reply' Then
      Begin
      Name := LowerCase(HeaderValue(Head_, 'Content-Type'));
      If (Name <> '') And (Pos('zip', Name) = 0) And (Pos('octet-stream', Name) = 0) Then
        ErrorAnswer(415, 'send the reply packet as application/zip (or application/octet-stream)')
      Else If (BodyFile = '') Or (ReqIn = 0) Then
        ErrorAnswer(400, 'the body is empty: send the reply packet (<BBSID>.REP)')
      Else If QwkReply(Node, BodyFile, Keep, TestPaths And (GetEnvironmentVariable('MKAPI_TEST_CRASH') = '1'), QRes, Ans) Then
        Send(Ans)
      Else
        ErrorAnswer(QRes.Code, QRes.Err);
      End
    Else If (Copy(P, 1, 15) = '/v1/qwk/packet/') And (Copy(P, Length(P) - 3, 4) = '/ack') Then
      Begin
      Name := Copy(P, 16, Length(P) - 19);
      QwkAck(Node, Name, Keep, QRes);
      If QRes.Code = 200 Then
        Begin
        O := TJSONObject.Create;
        O.Add('acknowledged', True);
        O.Add('packet', QRes.Id);
        O.Add('messages', QRes.Messages);
        If QRes.Already Then
          O.Add('already', True);
        Send(O);
        End
      Else
        ErrorAnswer(QRes.Code, QRes.Err);
      End
    Else
      ErrorAnswer(404, 'not found');
    End
  Else If P = '/v1/users' Then
    Begin
    Need('users');
    Send(ApiUsers(Query));
    End
  Else If Copy(P, 1, 10) = '/v1/users/' Then
    Begin
    Need('users');
    Name := UrlDecode(Copy(P, 11, 200));
    O := ApiUser(Name, Query);
    If O = Nil Then
      ErrorAnswer(404, 'no such user')
    Else
      Send(O);
    End
  Else
    ErrorAnswer(404, 'not found');
  End;


Procedure Authenticate;
  {the token of the request: the index in Tokens, or the answer 401 / 403 and the exit 88}
  Var
    Tok: String;
    Tk: TApiToken;

  Begin
  Tok := '';
  If LowerCase(Copy(Auth, 1, 7)) = 'bearer ' Then
    Tok := Trim(Copy(Auth, 8, 400));
  TokIdx := FindByToken(Tokens, Tok);
  If TokIdx < 0 Then
    Begin
    ErrorAnswer(401, 'a valid token is needed', 'WWW-Authenticate: Bearer'#13#10);
    Finish(88);
    End;
  Tk := Tokens[TokIdx];
  TokenId := Tk.Id;
  If TokenExpired(Tk, Now) Or (Not AddrAllowed(Addr, Tk.From_)) Then
    Begin
    ErrorAnswer(401, 'a valid token is needed', 'WWW-Authenticate: Bearer'#13#10);
    Finish(88);
    End;
  NoteUse(UseFile, Tk.Id, Addr);
  End;


Procedure Setup;
  Var
    i: Integer;
    A, Err: String;
    BbsType: Word;

  Begin
  Addr := '';
  Proxy := False;
  For i := 1 To ParamCount Do
    Begin
    A := ParamStr(i);
    If Copy(A, 1, 2) = '-A' Then
      Addr := Copy(A, 3, 100)
    Else If A = '-H' Then
      Proxy := True
    Else If A = '-Y' Then
      SessTls := True;
    End;
  Com := CreateSession('STD', 0, Addr, Proxy);
  If Com = Nil Then
    Begin
    Log(Addr + ' no session: ' + SessionError);
    Halt(1);
    End;
  Addr := Com^.GetRemoteAddr;
  Com^.SetBinary(True);
  BbsType := DetectBbsType;
  Config := Nil;
  Case BbsType Of
    1: Config := NewMKConfig(True);
    2: Config := New(RARCfgObjPtr, Init);
    3: Config := New(QBCfgObjPtr, Init);
    4: Config := New(SBCfgObjPtr, Init);
    End;
  If Config = Nil Then
    Begin
    ErrorAnswer(500, 'the BBS is not configured');
    Finish(1);
    End;
  Config^.Load;
  If Config^.GetError <> 0 Then
    Begin
    ErrorAnswer(500, 'the BBS configuration cannot be loaded');
    Finish(1);
    End;
  TokFile := TokenFileName(Config^.GetBbsPath);
  UseFile := ChangeFileExt(TokFile, '.use');
  If Not LoadTokens(TokFile, Tokens, Err) Then
    Begin
    Log('the token file cannot be read: ' + Err);
    ErrorAnswer(500, 'the token file cannot be read');
    Finish(1);
    End;
  End;


Var
  Head, Line, T: String;
  Lines: TStringList;
  p, q: Integer;

Begin
Sent := False;
BodyFile := '';
ReqIn := 0;
RespOut := 0;
ContentLen := -1;
TestPaths := GetEnvironmentVariable('MKAPI_TEST') = '1';
BodyIdleSecs := StrToIntDef(GetEnvironmentVariable('MKAPI_BODY_IDLE'), 60);
AddExitProc(@CleanupBody);
Method := '';
Target := '';
TokenId := '';
Setup;
If Not ReadRequest(Head) Then
  Begin
  If Pos(#13#10#13#10, Head) = 0 Then
    Begin
    If Length(Head) > MaxHead Then
      ErrorAnswer(431, 'the request header is too long')
    Else If Head <> '' Then
      ErrorAnswer(400, 'the request is not complete');
    End
  Else
    ErrorAnswer(400, 'not a valid request');
  Finish(0);
  End;
Lines := TStringList.Create;
Lines.Text := Head;
Line := Lines[0];
Lines.Free;
If Length(Line) > MaxLine Then
  Begin
  ErrorAnswer(414, 'the request line is too long');
  Finish(0);
  End;
p := Pos(' ', Line);
q := p + Pos(' ', Copy(Line, p + 1, 5000));
If (p = 0) Or (q = p) Or (Copy(Line, q + 1, 5) <> 'HTTP/') Then
  Begin
  ErrorAnswer(400, 'not a valid request line');
  Finish(0);
  End;
Method := Copy(Line, 1, p - 1);
Target := Copy(Line, p + 1, q - p - 1);
Path := Target;
Query := '';
p := Pos('?', Target);
If p > 0 Then
  Begin
  Path := Copy(Target, 1, p - 1);
  Query := Copy(Target, p + 1, 2000);
  End;
If (Method <> 'GET') And (Method <> 'HEAD') And (Method <> 'POST') And (Method <> 'PUT') Then
  Begin
  ErrorAnswer(405, 'this API takes GET, HEAD, POST and PUT', 'Allow: GET, HEAD'#13#10);
  Finish(0);
  End;
Head_ := Head;
T := HeaderValue(Head, 'Content-Length');
ContentLen := -1;
If T <> '' Then
  Begin
  ContentLen := StrToInt64Def(T, -2);
  If ContentLen < 0 Then
    Begin
    ErrorAnswer(400, 'Content-Length is not a number');
    Finish(0);
    End;
  End;
Auth := HeaderValue(Head, 'Authorization');
Authenticate;
T := Path;
If (Length(T) > 1) And (T[Length(T)] = '/') Then
  Delete(T, Length(T), 1);
PrepareBody(T);
Route;
Finish(0);
End.
