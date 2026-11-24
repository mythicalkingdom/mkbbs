Program MKApi;

{$mode objfpc}{$H+}

{
     mkapi: one request of the JSON API.  mklisten starts it for each connection of a port of the type "api" (the connection is on standard input and output, as for mk), with
       -A<address>   the caller's address       -H   a PROXY header comes first       -Y   TLS: the handshake is done first (MK_TLS_CERT, MK_TLS_KEY)
     and MK = the BBS configuration directory.  HTTP/1.1, one request, then the connection is closed; JSON only; GET and HEAD only (version 1 is read only).

     The token (Authorization: Bearer mkapi_...) is looked up in apitokens.json in the BBS directory (mkapitoken makes them).  No token, a token that is not known, expired, not for this address:
     401 and the exit code 88, which mklisten counts as a failed log-on of the address (the login guard); a token without the scope of the endpoint: 403 and 88 too.  Every request is one line on
     standard error (mklisten's log): the id of the token, the address, the request, the answer; never the token.

       GET /v1                  the paths and the scopes of the token
       GET /v1/status           scope status      GET /v1/nodes     scope nodes     GET /v1/events   scope events     GET /v1/mailer  scope mailer
       GET /v1/stats?from=&to=&by=   scope stats  GET /v1/calls?limit=&since=   scope calls
       GET /v1/areas/messages, /v1/areas/files   scope areas      GET /v1/areas/files/<area>?q=&limit=&after=   scope files (name, description, size, date)
       GET /v1/users?q=&limit=&after=&deleted=1, /v1/users/<name>   scope users
     The answers are built in MKApiData from the files and the socket the BBS has (node files, useron.bbs, events.info, the mailer's control socket, stats/*.tsv, the bases, the user file).
}

Uses SysUtils, Classes, BaseUnix, DateUtils, fpjson,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKComAbs, MKSess, MKApiTok, MKApiData;

Const
  Paths: Array[0..10] Of String = ('/v1', '/v1/status', '/v1/nodes', '/v1/events', '/v1/mailer', '/v1/stats', '/v1/calls', '/v1/areas/messages', '/v1/areas/files', '/v1/areas/files/{area}', '/v1/users');
  MaxHead = 8192;
  MaxLine = 2048;
  ReadSecs = 10;

Var
  Com: AbsComPtr;
  Addr, Method, Target, Path, Query, Auth, TokenId: String;
  Proxy: Boolean;
  Tokens: TApiTokens;
  TokIdx: Integer;
  TokFile, UseFile: String;
  Sent: Boolean;


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
    200: Result := 'OK';
    400: Result := 'Bad Request';
    401: Result := 'Unauthorized';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    414: Result := 'URI Too Long';
    431: Result := 'Request Header Fields Too Large';
    Else
      Result := 'Error';
    End;
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
  Log(Copy('-' + TokenId, 1 + Ord(TokenId <> ''), 40) + ' ' + Addr + ' ' + Method + ' ' + Copy(Target, 1, 100) + ' ' + IntToStr(Code));
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


Procedure Finish(Code: Integer);
  Begin
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


Procedure Route;
  Var
    O, N: TJSONObject;
    A: TJSONArray;
    i: Integer;
    Err, RunDir, BbsDir, P, Name: String;

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
If (Method <> 'GET') And (Method <> 'HEAD') Then
  Begin
  ErrorAnswer(405, 'this API is read only (GET)', 'Allow: GET, HEAD'#13#10);
  Finish(0);
  End;
T := HeaderValue(Head, 'Content-Length');
If (T <> '') And (T <> '0') Then
  Begin
  ErrorAnswer(400, 'a GET has no body');
  Finish(0);
  End;
Auth := HeaderValue(Head, 'Authorization');
Authenticate;
Route;
Finish(0);
End.
