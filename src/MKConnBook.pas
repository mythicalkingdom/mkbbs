{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKConnBook;   {the phone book of mkconnect: the systems, one file, sealed with the start password (MKCONNECT-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
  ~/.config/mkconnect/phonebook is text in UTF-8: a block for each system,

      [entry]
      name = Mythical Kingdom
      host = bbs.example.org
      port = 23
      kind = telnet            telnet | telnets | raw | ssh
      charset = cp437          cp437 | utf8   (what the system sends)
      protocol = zmodem        zmodem | ymodem | ymodemg | xmodem | xmodem1k   (the one the transfer prompt offers first)
      login = Mark May         the name sent by the key for the login name (and the script's variable login)
      password = secret        sent by its own key (and the script's variable password)
      script = login.scr       an MKHubScr script run after the connect
      sshuser = mark           ssh: the user name (when it is not the login name)
      note = free text
      calls = 12
      last = 1790000000        the time of the last call (UNIX seconds)

  A value is what follows "= " up to the end of the line, kept as it is (a password may have blanks in it).  The file is a sealed file (MKConnCrypt) when it was saved with a password.
}

Interface

Uses MKConnCrypt;

Type
  TConnKind = (ckTelnet, ckTelnets, ckRaw, ckSsh);

  TConnEntry = Record
    Name, Host, Login, Password, Script, SshUser, Note: String;
    Port: Word;
    Kind: TConnKind;
    Utf8: Boolean;                      {the system sends UTF-8 (False: CP437)}
    Proto: Char;                        {the protocol offered first: Z Zmodem, Y Ymodem, G Ymodem-G, X Xmodem, 1 Xmodem-1K}
    Calls: LongInt;
    Last: Int64;
  End;

  TConnBook = Class
    Items: Array Of TConnEntry;
    Sealed: Boolean;                    {the file on disk is sealed}
    FileName: String;
    SealKeys: TSealKeys;                {the keys of the start password (derived once)}
    Constructor Create(Const AFile: String);
    Function Exists: Boolean;
    Function Load(Const Password: String; Out Why: String): Integer;   {0 done, 1 the file is sealed (a password is needed), 2 a wrong password, 3 it cannot be read}
    Function IsSealedOnDisk: Boolean;
    Function Save(Const Password: String; Sealed_: Boolean; Out Why: String): Boolean;
    Function Count: Integer;
    Function Add(Const E: TConnEntry): Integer;
    Procedure Delete(i: Integer);
    Function Find(Const Name: String): Integer;       {by name, not case sensitive, -1: none}
    Procedure SortByName;
    Procedure SortByLast;
  End;

Function ConnConfigDir: String;                       {~/.config/mkconnect (XDG_CONFIG_HOME when it is set); not made}
Function ConnDefaultPort(K: TConnKind): Word;
Function ConnKindName(K: TConnKind): String;
Function ConnKindFrom(Const S: String; Out K: TConnKind): Boolean;
Procedure ConnNewEntry(Out E: TConnEntry);
Function ConnProtoName(C: Char): String;
Function ConnProtoFrom(Const S: String): Char;      {#0 when it is none}

Implementation

Uses SysUtils, Classes, BaseUnix;


Function ConnConfigDir: String;
  Var
    X, H: String;

  Begin
  X := GetEnvironmentVariable('XDG_CONFIG_HOME');
  H := GetEnvironmentVariable('HOME');
  If X <> '' Then
    Result := IncludeTrailingPathDelimiter(X) + 'mkconnect'
  Else If H <> '' Then
    Result := IncludeTrailingPathDelimiter(H) + '.config/mkconnect'
  Else
    Result := '.mkconnect';
  End;


Function ConnDefaultPort(K: TConnKind): Word;
  Begin
  Case K Of
    ckTelnets: Result := 992;
    ckSsh: Result := 22;
    Else
      Result := 23;
    End;
  End;


Function ConnKindName(K: TConnKind): String;
  Begin
  Case K Of
    ckTelnet: Result := 'telnet';
    ckTelnets: Result := 'telnets';
    ckRaw: Result := 'raw';
    Else
      Result := 'ssh';
    End;
  End;


Function ConnKindFrom(Const S: String; Out K: TConnKind): Boolean;
  Var
    T: String;

  Begin
  T := LowerCase(Trim(S));
  Result := True;
  If T = 'telnet' Then K := ckTelnet
  Else If T = 'telnets' Then K := ckTelnets
  Else If T = 'raw' Then K := ckRaw
  Else If T = 'ssh' Then K := ckSsh
  Else Result := False;
  End;


Function ConnProtoName(C: Char): String;
  Begin
  Case C Of
    'Y': Result := 'ymodem';
    'G': Result := 'ymodemg';
    'X': Result := 'xmodem';
    '1': Result := 'xmodem1k';
    Else
      Result := 'zmodem';
    End;
  End;


Function ConnProtoFrom(Const S: String): Char;
  Var
    T: String;

  Begin
  T := LowerCase(Trim(S));
  Result := #0;
  If T = 'zmodem' Then Result := 'Z'
  Else If T = 'ymodem' Then Result := 'Y'
  Else If T = 'ymodemg' Then Result := 'G'
  Else If T = 'xmodem' Then Result := 'X'
  Else If T = 'xmodem1k' Then Result := '1';
  End;


Procedure ConnNewEntry(Out E: TConnEntry);
  Begin
  E.Proto := 'Z';
  E.Name := '';
  E.Host := '';
  E.Login := '';
  E.Password := '';
  E.Script := '';
  E.SshUser := '';
  E.Note := '';
  E.Port := 23;
  E.Kind := ckTelnet;
  E.Utf8 := False;
  E.Calls := 0;
  E.Last := 0;
  End;


Constructor TConnBook.Create(Const AFile: String);
  Begin
  FileName := AFile;
  End;


Function TConnBook.Exists: Boolean;
  Begin
  Result := FileExists(FileName);
  End;


Function ReadFile(Const FN: String; Out S: RawByteString): Boolean;
  Var
    F: TFileStream;

  Begin
  Result := False;
  S := '';
  Try
    F := TFileStream.Create(FN, fmOpenRead Or fmShareDenyNone);
    Try
      SetLength(S, F.Size);
      If F.Size > 0 Then
        F.ReadBuffer(S[1], F.Size);
      Result := True;
    Finally
      F.Free;
    End;
  Except
    Result := False;
  End;
  End;


Function TConnBook.IsSealedOnDisk: Boolean;
  Var
    S: RawByteString;

  Begin
  Result := ReadFile(FileName, S) And ConnIsSealed(S);
  End;


Function Value(Const Line: String; p: Integer): String;
  {what follows the = (one blank after it is not part of the value)}
  Begin
  Result := Copy(Line, p + 1, Length(Line));
  If (Result <> '') And (Result[1] = ' ') Then
    Delete(Result, 1, 1);
  End;


Function TConnBook.Load(Const Password: String; Out Why: String): Integer;
  Var
    S, T: RawByteString;
    L: TStringList;
    i, p, n: Integer;
    Line, Key, Val: String;
    E: TConnEntry;
    Open_: Boolean;
    K: TConnKind;

  Begin
  Why := '';
  SetLength(Items, 0);
  Sealed := False;
  If Not FileExists(FileName) Then
    Exit(0);
  If Not ReadFile(FileName, S) Then
    Begin
    Why := 'the phone book cannot be read: ' + FileName;
    Exit(3);
    End;
  If ConnIsSealed(S) Then
    Begin
    Sealed := True;
    If Not ConnOpen(S, Password, T) Then
      Begin
      If Password = '' Then
        Result := 1
      Else
        Result := 2;
      Why := 'a wrong password, or the phone book is damaged';
      Exit;
      End;
    S := T;
    End;
  L := TStringList.Create;
  Try
    L.Text := S;
    Open_ := False;
    ConnNewEntry(E);
    For i := 0 To L.Count - 1 Do
      Begin
      Line := L[i];
      If (Line = '') Or (Line[1] = '#') Then
        Continue;
      If Line = '[entry]' Then
        Begin
        If Open_ Then
          Begin
          n := Length(Items);
          SetLength(Items, n + 1);
          Items[n] := E;
          End;
        ConnNewEntry(E);
        Open_ := True;
        Continue;
        End;
      p := Pos('=', Line);
      If (p = 0) Or Not Open_ Then
        Continue;
      Key := LowerCase(Trim(Copy(Line, 1, p - 1)));
      Val := Value(Line, p);
      If Key = 'name' Then E.Name := Val
      Else If Key = 'host' Then E.Host := Val
      Else If Key = 'port' Then E.Port := StrToIntDef(Trim(Val), 23)
      Else If Key = 'kind' Then
        Begin
        If ConnKindFrom(Val, K) Then E.Kind := K;
        End
      Else If Key = 'charset' Then E.Utf8 := LowerCase(Trim(Val)) = 'utf8'
      Else If Key = 'protocol' Then
        Begin
        If ConnProtoFrom(Val) <> #0 Then E.Proto := ConnProtoFrom(Val);
        End
      Else If Key = 'login' Then E.Login := Val
      Else If Key = 'password' Then E.Password := Val
      Else If Key = 'script' Then E.Script := Val
      Else If Key = 'sshuser' Then E.SshUser := Val
      Else If Key = 'note' Then E.Note := Val
      Else If Key = 'calls' Then E.Calls := StrToIntDef(Trim(Val), 0)
      Else If Key = 'last' Then E.Last := StrToInt64Def(Trim(Val), 0);
      End;
    If Open_ Then
      Begin
      n := Length(Items);
      SetLength(Items, n + 1);
      Items[n] := E;
      End;
  Finally
    L.Free;
  End;
  Result := 0;
  End;


Function Clean(Const S: String): String;
  {a value has no line end}
  Var
    i: Integer;

  Begin
  Result := S;
  For i := 1 To Length(Result) Do
    If Result[i] In [#10, #13] Then
      Result[i] := ' ';
  End;


Function TConnBook.Save(Const Password: String; Sealed_: Boolean; Out Why: String): Boolean;
  Var
    L: TStringList;
    i: Integer;
    S: RawByteString;
    F: TFileStream;
    Tmp, Dir: String;

  Begin
  Result := False;
  Why := '';
  L := TStringList.Create;
  Try
    L.Add('# the phone book of mkconnect');
    For i := 0 To High(Items) Do
      With Items[i] Do
        Begin
        L.Add('[entry]');
        L.Add('name = ' + Clean(Name));
        L.Add('host = ' + Clean(Host));
        L.Add('port = ' + IntToStr(Port));
        L.Add('kind = ' + ConnKindName(Kind));
        If Utf8 Then L.Add('charset = utf8') Else L.Add('charset = cp437');
        L.Add('protocol = ' + ConnProtoName(Proto));
        If Login <> '' Then L.Add('login = ' + Clean(Login));
        If Items[i].Password <> '' Then L.Add('password = ' + Clean(Items[i].Password));
        If Script <> '' Then L.Add('script = ' + Clean(Script));
        If SshUser <> '' Then L.Add('sshuser = ' + Clean(SshUser));
        If Note <> '' Then L.Add('note = ' + Clean(Note));
        L.Add('calls = ' + IntToStr(Calls));
        L.Add('last = ' + IntToStr(Last));
        L.Add('');
        End;
    S := L.Text;
  Finally
    L.Free;
  End;
  If Sealed_ Then
    Begin
    If (Not SealKeys.Valid) Or (SealKeys.Password <> Password) Then
      If Not ConnNewKeys(Password, ConnIterations, SealKeys) Then
        Begin
        Why := 'no random numbers for the seal';
        Exit;
        End;
    S := ConnSealWith(S, SealKeys);
    If S = '' Then
      Begin
      Why := 'no random numbers for the seal';
      Exit;
      End;
    End;
  Dir := ExtractFileDir(FileName);
  If (Dir <> '') And Not DirectoryExists(Dir) Then
    If Not ForceDirectories(Dir) Then
      Begin
      Why := 'the folder cannot be made: ' + Dir;
      Exit;
      End;
  If Dir <> '' Then
    fpChmod(Dir, &700);
  Tmp := FileName + '.new';
  Try
    F := TFileStream.Create(Tmp, fmCreate);
    Try
      If Length(S) > 0 Then
        F.WriteBuffer(S[1], Length(S));
    Finally
      F.Free;
    End;
    fpChmod(Tmp, &600);
    If Not RenameFile(Tmp, FileName) Then
      Begin
      DeleteFile(Tmp);
      Why := 'the phone book cannot be written';
      Exit;
      End;
  Except
    DeleteFile(Tmp);
    Why := 'the phone book cannot be written';
    Exit;
  End;
  Sealed := Sealed_;
  Result := True;
  End;


Function TConnBook.Count: Integer;
  Begin
  Result := Length(Items);
  End;


Function TConnBook.Add(Const E: TConnEntry): Integer;
  Begin
  Result := Length(Items);
  SetLength(Items, Result + 1);
  Items[Result] := E;
  End;


Procedure TConnBook.Delete(i: Integer);
  Var
    k: Integer;

  Begin
  If (i < 0) Or (i > High(Items)) Then
    Exit;
  For k := i To High(Items) - 1 Do
    Items[k] := Items[k + 1];
  SetLength(Items, Length(Items) - 1);
  End;


Function TConnBook.Find(Const Name: String): Integer;
  Var
    i: Integer;

  Begin
  Result := -1;
  For i := 0 To High(Items) Do
    If CompareText(Items[i].Name, Name) = 0 Then
      Exit(i);
  End;


Procedure TConnBook.SortByName;
  Var
    i, k: Integer;
    T: TConnEntry;

  Begin
  For i := 1 To High(Items) Do
    Begin
    T := Items[i];
    k := i - 1;
    While (k >= 0) And (CompareText(Items[k].Name, T.Name) > 0) Do
      Begin
      Items[k + 1] := Items[k];
      Dec(k);
      End;
    Items[k + 1] := T;
    End;
  End;


Procedure TConnBook.SortByLast;
  Var
    i, k: Integer;
    T: TConnEntry;

  Begin
  For i := 1 To High(Items) Do
    Begin
    T := Items[i];
    k := i - 1;
    While (k >= 0) And (Items[k].Last < T.Last) Do
      Begin
      Items[k + 1] := Items[k];
      Dec(k);
      End;
    Items[k + 1] := T;
    End;
  End;


End.
