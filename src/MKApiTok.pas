Unit MKApiTok;   {The token file of the JSON API: apitokens.json in the BBS directory}

{$mode objfpc}{$H+}

// { "tokens": [ { "id": "dash", "hash": "sha256:<hex>", "scopes": ["status", "nodes"], "created": "2026-11-24T10:00:00-05:00",
// "expires": "2027-11-24", "from": ["127.0.0.1", "10.0.0.0/8"], "note": "the dashboard", "user": "" } ] }
//
// A token is mkapi_ and 43 random base64url characters (256 bits); only its SHA-256 is kept.  The file is mode 600 and is written whole (a new file replaces the old one).  Who uses a token last is
// kept in apitokens.use (id, time, address), a separate file, so the token file is not rewritten for every request.  The scopes: status nodes events mailer stats calls areas files messages messages:private users, users:private
// (reserved), * (all) and, for tokens that name a user, self:... (reserved: version 1 gives such a token no endpoint).
//

Interface

Uses SysUtils, Classes;

Type
  TApiToken = Record
    Id, Hash, Created, Expires, Note, User: String;
    Scopes, From_: TStringList;
    End;

  TApiTokens = Array Of TApiToken;

Const
  TokenPrefix = 'mkapi_';

Function TokenFileName(Dir: String): String;
Function LoadTokens(FN: String; Var T: TApiTokens; Var Err: String): Boolean;
Function SaveTokens(FN: String; Const T: TApiTokens; Var Err: String): Boolean;
Procedure FreeTokens(Var T: TApiTokens);
Function NewTokenText: String;
Function HashToken(Const Tok: String): String;
Function ScopeKnown(Const S: String): Boolean;
Function ValidId(Const S: String): Boolean;
Function AddrAllowed(Const Addr: String; L: TStringList): Boolean;
Function FindByToken(Const T: TApiTokens; Const Tok: String): Integer;       {-1: none (the comparison takes the same time for every entry)}
Function TokenExpired(Const Tk: TApiToken; Today: TDateTime): Boolean;
Function HasScope(Const Tk: TApiToken; Const Scope: String): Boolean;
Procedure NoteUse(Const UseFile, Id, Addr: String);
Function LastUse(Const UseFile, Id: String; Var When_, Addr: String): Boolean;

Implementation

Uses BaseUnix, Unix, DateUtils, fpjson, jsonparser, MKPwd;

Const
  B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  Known: Array[0..12] Of String = ('status', 'nodes', 'events', 'mailer', 'stats', 'calls', 'areas', 'files', 'messages', 'messages:private', 'users', 'users:private', '*');


Function TokenFileName(Dir: String): String;
  Begin
  If (Dir <> '') And (Dir[Length(Dir)] <> '/') Then
    Dir := Dir + '/';
  Result := Dir + 'apitokens.json';
  End;


Function ScopeKnown(Const S: String): Boolean;
  Var
    i: Integer;

  Begin
  Result := Copy(S, 1, 5) = 'self:';
  For i := 0 To High(Known) Do
    If Known[i] = S Then
      Result := True;
  If Result And (Copy(S, 1, 5) = 'self:') And (Length(S) = 5) Then
    Result := False;
  End;


Function ValidId(Const S: String): Boolean;
  Var
    i: Integer;

  Begin
  Result := (Length(S) >= 1) And (Length(S) <= 32);
  For i := 1 To Length(S) Do
    If Not (S[i] In ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.']) Then
      Result := False;
  End;


Function HashToken(Const Tok: String): String;
  Var
    D: Sha256Digest;
    i: Integer;

  Begin
  If Tok = '' Then
    Sha256Buf(@D, 0, D)
  Else
    Sha256Buf(@Tok[1], Length(Tok), D);
  Result := 'sha256:';
  For i := 0 To 31 Do
    Result := Result + LowerCase(IntToHex(D[i], 2));
  End;


Function NewTokenText: String;
  Var
    Fs: TFileStream;
    B: Array[0..31] Of Byte;
    i, Acc, Bits: Integer;
    S: String;

  Begin
  Fs := TFileStream.Create('/dev/urandom', fmOpenRead);
  Try
    Fs.ReadBuffer(B, SizeOf(B));
  Finally
    Fs.Free;
  End;
  S := '';
  Acc := 0;
  Bits := 0;
  For i := 0 To 31 Do
    Begin
    Acc := (Acc Shl 8) Or B[i];
    Inc(Bits, 8);
    While Bits >= 6 Do
      Begin
      Dec(Bits, 6);
      S := S + B64[((Acc Shr Bits) And 63) + 1];
      End;
    Acc := Acc And ((1 Shl Bits) - 1);
    End;
  If Bits > 0 Then
    S := S + B64[((Acc Shl (6 - Bits)) And 63) + 1];
  Result := TokenPrefix + S;
  FillChar(B, SizeOf(B), 0);
  End;


Function IPv4(Const S: String; Var V: LongWord): Boolean;
  Var
    P: Array[0..3] Of Integer;
    i, n, k: Integer;
    Cur: String;

  Begin
  Result := False;
  n := 0;
  Cur := '';
  For i := 1 To Length(S) + 1 Do
    Begin
    If (i > Length(S)) Or (S[i] = '.') Then
      Begin
      If (n > 3) Or (Cur = '') Then
        Exit;
      k := StrToIntDef(Cur, -1);
      If (k < 0) Or (k > 255) Then
        Exit;
      P[n] := k;
      Inc(n);
      Cur := '';
      End
    Else If S[i] In ['0'..'9'] Then
      Cur := Cur + S[i]
    Else
      Exit;
    End;
  If n <> 4 Then
    Exit;
  V := (LongWord(P[0]) Shl 24) Or (LongWord(P[1]) Shl 16) Or (LongWord(P[2]) Shl 8) Or LongWord(P[3]);
  Result := True;
  End;


Function AddrAllowed(Const Addr: String; L: TStringList): Boolean;
  Var
    i, p, Bits: Integer;
    E: String;
    A, N, Mask: LongWord;

  Begin
  If (L = Nil) Or (L.Count = 0) Then
    Exit(True);
  Result := False;
  For i := 0 To L.Count - 1 Do
    Begin
    E := L[i];
    p := Pos('/', E);
    If p = 0 Then
      Begin
      If E = Addr Then
        Result := True;
      End
    Else If IPv4(Copy(E, 1, p - 1), N) And IPv4(Addr, A) Then
      Begin
      Bits := StrToIntDef(Copy(E, p + 1, 5), -1);
      If (Bits >= 0) And (Bits <= 32) Then
        Begin
        If Bits = 0 Then
          Mask := 0
        Else
          Mask := LongWord($FFFFFFFF) Shl (32 - Bits);
        If (A And Mask) = (N And Mask) Then
          Result := True;
        End;
      End;
    End;
  End;


Procedure FreeTokens(Var T: TApiTokens);
  Var
    i: Integer;

  Begin
  For i := 0 To High(T) Do
    Begin
    T[i].Scopes.Free;
    T[i].From_.Free;
    End;
  SetLength(T, 0);
  End;


Function StrList(O: TJSONObject; Const Key: String): TStringList;
  Var
    A: TJSONData;
    i: Integer;

  Begin
  Result := TStringList.Create;
  A := O.Find(Key);
  If (A <> Nil) And (A.JSONType = jtArray) Then
    For i := 0 To A.Count - 1 Do
      Result.Add(A.Items[i].AsString);
  End;


Function LoadTokens(FN: String; Var T: TApiTokens; Var Err: String): Boolean;
  Var
    Fs: TFileStream;
    D: TJSONData;
    Root, O: TJSONObject;
    A: TJSONData;
    i: Integer;
    Tk: TApiToken;

  Begin
  SetLength(T, 0);
  Err := '';
  Result := True;
  If Not FileExists(FN) Then
    Exit;
  Result := False;
  Try
    Fs := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
    Try
      D := GetJSON(Fs);
    Finally
      Fs.Free;
    End;
  Except
    On E: Exception Do
      Begin
      Err := FN + ': ' + E.Message;
      Exit;
      End;
  End;
  Try
    If D.JSONType <> jtObject Then
      Begin
      Err := FN + ': not an object';
      Exit;
      End;
    Root := TJSONObject(D);
    A := Root.Find('tokens');
    If (A = Nil) Or (A.JSONType <> jtArray) Then
      Begin
      Err := FN + ': no "tokens" list';
      Exit;
      End;
    For i := 0 To A.Count - 1 Do
      Begin
      If A.Items[i].JSONType <> jtObject Then
        Begin
        Err := FN + ': a token entry is not an object';
        Exit;
        End;
      O := TJSONObject(A.Items[i]);
      Tk.Id := O.Get('id', '');
      Tk.Hash := O.Get('hash', '');
      Tk.Created := O.Get('created', '');
      Tk.Expires := O.Get('expires', '');
      Tk.Note := O.Get('note', '');
      Tk.User := O.Get('user', '');
      Tk.Scopes := StrList(O, 'scopes');
      Tk.From_ := StrList(O, 'from');
      SetLength(T, Length(T) + 1);
      T[High(T)] := Tk;
      End;
    Result := True;
  Finally
    D.Free;
  End;
  End;


Function SaveTokens(FN: String; Const T: TApiTokens; Var Err: String): Boolean;
  Var
    Root, O: TJSONObject;
    Arr, S: TJSONArray;
    i, j, Fd: Integer;
    Txt: String;

  Begin
  Result := False;
  Err := '';
  Root := TJSONObject.Create;
  Arr := TJSONArray.Create;
  Root.Add('tokens', Arr);
  For i := 0 To High(T) Do
    Begin
    O := TJSONObject.Create;
    O.Add('id', T[i].Id);
    O.Add('hash', T[i].Hash);
    S := TJSONArray.Create;
    For j := 0 To T[i].Scopes.Count - 1 Do
      S.Add(T[i].Scopes[j]);
    O.Add('scopes', S);
    O.Add('created', T[i].Created);
    O.Add('expires', T[i].Expires);
    S := TJSONArray.Create;
    For j := 0 To T[i].From_.Count - 1 Do
      S.Add(T[i].From_[j]);
    O.Add('from', S);
    O.Add('note', T[i].Note);
    O.Add('user', T[i].User);
    Arr.Add(O);
    End;
  Txt := Root.FormatJSON([foSingleLineArray, foSkipWhiteSpaceOnlyLeading], 2) + LineEnding;
  Root.Free;
  Fd := fpOpen(PChar(FN + '.new'), O_WRONLY Or O_CREAT Or O_TRUNC, &600);
  If Fd < 0 Then
    Begin
    Err := 'cannot write ' + FN + '.new';
    Exit;
    End;
  If (Txt <> '') And (fpWrite(Fd, Txt[1], Length(Txt)) <> Length(Txt)) Then
    Begin
    fpClose(Fd);
    Err := 'cannot write ' + FN + '.new';
    Exit;
    End;
  fpClose(Fd);
  fpChmod(PChar(FN + '.new'), &600);
  If fpRename(PChar(FN + '.new'), PChar(FN)) <> 0 Then
    Begin
    Err := 'cannot replace ' + FN;
    Exit;
    End;
  Result := True;
  End;


Function SameText_(Const A, B: String): Boolean;
  {the same time for a different byte as for a different last byte}
  Var
    i, D: Integer;

  Begin
  D := Length(A) Xor Length(B);
  For i := 1 To Length(A) Do
    If i <= Length(B) Then
      D := D Or (Ord(A[i]) Xor Ord(B[i]));
  Result := D = 0;
  End;


Function FindByToken(Const T: TApiTokens; Const Tok: String): Integer;
  Var
    H: String;
    i: Integer;

  Begin
  Result := -1;
  If (Copy(Tok, 1, Length(TokenPrefix)) <> TokenPrefix) Or (Length(Tok) > 200) Then
    Exit;
  H := HashToken(Tok);
  For i := 0 To High(T) Do
    If SameText_(H, T[i].Hash) And (Result < 0) Then
      Result := i;
  End;


Function TokenExpired(Const Tk: TApiToken; Today: TDateTime): Boolean;
  Var
    D: TDateTime;
    FS: TFormatSettings;

  Begin
  Result := False;
  If Tk.Expires = '' Then
    Exit;
  FS := DefaultFormatSettings;
  FS.DateSeparator := '-';
  FS.ShortDateFormat := 'yyyy-mm-dd';
  If Not TryStrToDate(Copy(Tk.Expires, 1, 10), D, FS) Then
    Exit(True);                          {a date that cannot be read: not valid}
  Result := Trunc(Today) > Trunc(D);     {valid through the day named}
  End;


Function HasScope(Const Tk: TApiToken; Const Scope: String): Boolean;
  Begin
  Result := (Tk.Scopes.IndexOf(Scope) >= 0) Or (Tk.Scopes.IndexOf('*') >= 0);
  End;


Procedure NoteUse(Const UseFile, Id, Addr: String);
  {one line for each token: id TAB unix time TAB address; the file is rewritten under a lock}
  Var
    Fd, N, i: Integer;
    Buf: String;
    L: TStringList;
    Done: Boolean;

  Begin
  Fd := fpOpen(PChar(UseFile), O_RDWR Or O_CREAT, &600);
  If Fd < 0 Then
    Exit;
  If fpFlock(Fd, LOCK_EX) <> 0 Then
    Begin
    fpClose(Fd);
    Exit;
  End;
  SetLength(Buf, 65536);
  N := fpRead(Fd, Buf[1], Length(Buf));
  If N < 0 Then
    N := 0;
  SetLength(Buf, N);
  L := TStringList.Create;
  L.Text := Buf;
  Done := False;
  For i := 0 To L.Count - 1 Do
    If Copy(L[i], 1, Length(Id) + 1) = Id + #9 Then
      Begin
      L[i] := Id + #9 + IntToStr(DateTimeToUnix(LocalTimeToUniversal(Now))) + #9 + Addr;
      Done := True;
      End;
  If Not Done Then
    L.Add(Id + #9 + IntToStr(DateTimeToUnix(LocalTimeToUniversal(Now))) + #9 + Addr);
  Buf := L.Text;
  L.Free;
  fpLseek(Fd, 0, SEEK_SET);
  fpFtruncate(Fd, 0);
  If Buf <> '' Then
    fpWrite(Fd, Buf[1], Length(Buf));
  fpFlock(Fd, LOCK_UN);
  fpClose(Fd);
  End;


Function LastUse(Const UseFile, Id: String; Var When_, Addr: String): Boolean;
  Var
    L: TStringList;
    i, p, q: Integer;
    U: Int64;

  Begin
  Result := False;
  If Not FileExists(UseFile) Then
    Exit;
  L := TStringList.Create;
  Try
    L.LoadFromFile(UseFile);
    For i := 0 To L.Count - 1 Do
      If Copy(L[i], 1, Length(Id) + 1) = Id + #9 Then
        Begin
        p := Length(Id) + 1;
        q := Pos(#9, Copy(L[i], p + 1, 100));
        U := StrToInt64Def(Copy(L[i], p + 1, q - 1), 0);
        When_ := FormatDateTime('yyyy-mm-dd hh:nn:ss', UniversalTimeToLocal(UnixToDateTime(U)));
        Addr := Copy(L[i], p + q + 1, 100);
        Result := True;
        End;
  Finally
    L.Free;
  End;
  End;

End.
