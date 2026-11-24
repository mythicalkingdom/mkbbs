Program MKApiTokenTool;

{$mode objfpc}{$H+}

{
     mkapitoken: the tokens of the JSON API (apitokens.json in the BBS directory, mode 600).

       mkapitoken [-c config dir] add ID -s scope,scope [-e yyyy-mm-dd] [-f address,net] [-u "User Name"] [-n note] [-q]
       mkapitoken [-c config dir] list
       mkapitoken [-c config dir] revoke ID
       mkapitoken [-c config dir] rotate ID [-q]

     add and rotate print the token ONCE (-q: only the token, for scripts); only its SHA-256 is kept, so it cannot be shown again.  A token is valid up to and including the day of -e
     (none: no end), only from the addresses of -f (none: from anywhere; a.b.c.d/n nets are understood).  -u names a BBS user (by name): such a token acts for that user (version 1: no endpoint
     takes it yet).  Scopes: status nodes events mailer stats calls areas users users:private *   (self:... only with -u).  mkapi reads the file at every request: no restart.
     The exit code: 0 done, 1 not usable.
}

Uses SysUtils, Classes, BaseUnix, Unix,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKApiTok;

Var
  Tokens: TApiTokens;
  Cmd, Id, Scopes, Expires, From_, User, Note, FN, UseFn, Err, ConfDir: String;
  Quiet: Boolean;


Procedure Die(S: String);
  Begin
  WriteLn(StdErr, 'mkapitoken: ', S);
  Halt(1);
  End;


Function Find(Const Id: String): Integer;
  Var
    i: Integer;

  Begin
  Result := -1;
  For i := 0 To High(Tokens) Do
    If Tokens[i].Id = Id Then
      Result := i;
  End;


Function Stamp: String;
  Var
    Off: Integer;

  Begin
  Off := -GetLocalTimeOffset;
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now) + Format('%s%.2d:%.2d', [Copy('-+', 1 + Ord(Off >= 0), 1), Abs(Off) Div 60, Abs(Off) Mod 60]);
  End;


Procedure Split(Const S: String; L: TStringList);
  Var
    i: Integer;
    Cur: String;

  Begin
  Cur := '';
  For i := 1 To Length(S) + 1 Do
    If (i > Length(S)) Or (S[i] = ',') Then
      Begin
      If Trim(Cur) <> '' Then
        L.Add(Trim(Cur));
      Cur := '';
      End
    Else
      Cur := Cur + S[i];
  End;


Procedure Save;
  Begin
  If Not SaveTokens(FN, Tokens, Err) Then
    Die(Err);
  End;


Procedure Show(Const Id, Tok: String);
  Begin
  If Quiet Then
    WriteLn(Tok)
  Else
    Begin
    WriteLn('token ', Id, ' (shown only now: it cannot be shown again):');
    WriteLn;
    WriteLn('  ', Tok);
    WriteLn;
    WriteLn('use it as   Authorization: Bearer <token>');
    End;
  End;


Procedure DoAdd;
  Var
    Tk: TApiToken;
    S: TStringList;
    i, k: Integer;
    D: TDateTime;
    FS: TFormatSettings;
    Tok: String;

  Begin
  If Not ValidId(Id) Then
    Die('the id must be 1 to 32 letters, digits, - _ .');
  If Find(Id) >= 0 Then
    Die('a token with the id ' + Id + ' is there already (rotate or revoke it)');
  Tk.Scopes := TStringList.Create;
  Tk.From_ := TStringList.Create;
  Split(Scopes, Tk.Scopes);
  If Tk.Scopes.Count = 0 Then
    Die('-s: name the scopes (status nodes events mailer stats calls areas users users:private *)');
  For i := 0 To Tk.Scopes.Count - 1 Do
    Begin
    If Not ScopeKnown(Tk.Scopes[i]) Then
      Die('unknown scope ' + Tk.Scopes[i]);
    If (Copy(Tk.Scopes[i], 1, 5) = 'self:') And (User = '') Then
      Die('the scope ' + Tk.Scopes[i] + ' is for a token that names a user (-u)');
    End;
  If Expires <> '' Then
    Begin
    FS := DefaultFormatSettings;
    FS.DateSeparator := '-';
    FS.ShortDateFormat := 'yyyy-mm-dd';
    If (Length(Expires) <> 10) Or (Not TryStrToDate(Expires, D, FS)) Then
      Die('-e: a date as yyyy-mm-dd');
    End;
  S := TStringList.Create;
  Split(From_, S);
  For i := 0 To S.Count - 1 Do
    Begin
    For k := 1 To Length(S[i]) Do
      If Not (S[i][k] In ['0'..'9', '.', '/', ':', 'a'..'f', 'A'..'F']) Then
        Die('-f: ' + S[i] + ' is no address or net');
    Tk.From_.Add(S[i]);
    End;
  S.Free;
  Tok := NewTokenText;
  Tk.Id := Id;
  Tk.Hash := HashToken(Tok);
  Tk.Created := Stamp;
  Tk.Expires := Expires;
  Tk.Note := Note;
  Tk.User := User;
  SetLength(Tokens, Length(Tokens) + 1);
  Tokens[High(Tokens)] := Tk;
  Save;
  Show(Id, Tok);
  End;


Procedure DoList;
  Var
    i: Integer;
    W, A, E: String;

  Begin
  If Length(Tokens) = 0 Then
    Begin
    WriteLn('no tokens (', FN, ')');
    Exit;
    End;
  For i := 0 To High(Tokens) Do
    Begin
    E := Tokens[i].Expires;
    If E = '' Then
      E := 'no end'
    Else If TokenExpired(Tokens[i], Now) Then
      E := E + ' (EXPIRED)';
    Write(Tokens[i].Id, ': scopes ', StringReplace(Trim(Tokens[i].Scopes.Text), LineEnding, ',', [rfReplaceAll]));
    WriteLn(' expires ', E);
    If Tokens[i].From_.Count > 0 Then
      WriteLn('    from ', StringReplace(Trim(Tokens[i].From_.Text), LineEnding, ', ', [rfReplaceAll]));
    If Tokens[i].User <> '' Then
      WriteLn('    acts for the user ', Tokens[i].User);
    If Tokens[i].Note <> '' Then
      WriteLn('    ', Tokens[i].Note);
    If LastUse(UseFn, Tokens[i].Id, W, A) Then
      WriteLn('    last used ', W, ' from ', A)
    Else
      WriteLn('    never used');
    End;
  End;


Procedure DoRevoke;
  Var
    i, k: Integer;

  Begin
  k := Find(Id);
  If k < 0 Then
    Die('no token ' + Id);
  Tokens[k].Scopes.Free;
  Tokens[k].From_.Free;
  For i := k To High(Tokens) - 1 Do
    Tokens[i] := Tokens[i + 1];
  SetLength(Tokens, Length(Tokens) - 1);
  Save;
  WriteLn('token ', Id, ' revoked');
  End;


Procedure DoRotate;
  Var
    k: Integer;
    Tok: String;

  Begin
  k := Find(Id);
  If k < 0 Then
    Die('no token ' + Id);
  Tok := NewTokenText;
  Tokens[k].Hash := HashToken(Tok);
  Tokens[k].Created := Stamp;
  Save;
  Show(Id, Tok);
  End;


Var
  i, k: Integer;
  A: String;
  BbsType: Word;
  Rest: TStringList;
  PArgv, EnvP: Array Of PChar;
  EnvS, ArgS: Array Of String;

Begin
Quiet := False;
Rest := TStringList.Create;
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-c' Then
    Begin
    Inc(i);
    ConfDir := ExpandFileName(ParamStr(i));
    End
  Else If A = '-s' Then
    Begin
    Inc(i);
    Scopes := ParamStr(i);
    End
  Else If A = '-e' Then
    Begin
    Inc(i);
    Expires := ParamStr(i);
    End
  Else If A = '-f' Then
    Begin
    Inc(i);
    From_ := ParamStr(i);
    End
  Else If A = '-u' Then
    Begin
    Inc(i);
    User := ParamStr(i);
    End
  Else If A = '-n' Then
    Begin
    Inc(i);
    Note := ParamStr(i);
    End
  Else If A = '-q' Then
    Quiet := True
  Else
    Rest.Add(A);
  Inc(i);
  End;
If Rest.Count = 0 Then
  Begin
  WriteLn('usage: mkapitoken [-c config dir] add ID -s scopes [-e yyyy-mm-dd] [-f addr,net] [-u "User"] [-n note] [-q] | list | revoke ID | rotate ID [-q]');
  Halt(1);
  End;
Cmd := LowerCase(Rest[0]);
If Rest.Count > 1 Then
  Id := Rest[1];
If ((Cmd = 'add') Or (Cmd = 'revoke') Or (Cmd = 'rotate')) And (Id = '') Then
  Die(Cmd + ' needs the id of the token');
If (Cmd <> 'add') And (Cmd <> 'list') And (Cmd <> 'revoke') And (Cmd <> 'rotate') Then
  Die('unknown command ' + Cmd + ' (add, list, revoke, rotate)');
If (ConfDir <> '') And (GetEnvironmentVariable('MK') <> ConfDir) Then
  Begin                                    {started again with MK set: the environment of this process is read once}
  SetLength(PArgv, ParamCount + 2);
  SetLength(ArgS, ParamCount + 2);
  ArgS[0] := ParamStr(0);
  PArgv[0] := PChar(ArgS[0]);
  k := 1;
  i := 1;
  While i <= ParamCount Do
    Begin
    If ParamStr(i) = '-c' Then
      Inc(i)
    Else
      Begin
      ArgS[k] := ParamStr(i);
      PArgv[k] := PChar(ArgS[k]);
      Inc(k);
      End;
    Inc(i);
    End;
  PArgv[k] := Nil;
  SetLength(EnvP, GetEnvironmentVariableCount + 2);
  SetLength(EnvS, GetEnvironmentVariableCount + 2);
  k := 0;
  For i := 1 To GetEnvironmentVariableCount Do
    If Copy(GetEnvironmentString(i), 1, 3) <> 'MK=' Then
      Begin
      EnvS[k] := GetEnvironmentString(i);
      Inc(k);
      End;
  EnvS[k] := 'MK=' + ConfDir;
  Inc(k);
  For i := 0 To k - 1 Do
    EnvP[i] := PChar(EnvS[i]);
  EnvP[k] := Nil;
  fpExecve(ParamStr(0), PPChar(@PArgv[0]), PPChar(@EnvP[0]));
  Die('cannot start again with MK set');
  End;
BbsType := DetectBbsType;
Config := Nil;
Case BbsType Of
  1: Config := NewMKConfig(True);
  2: Config := New(RARCfgObjPtr, Init);
  3: Config := New(QBCfgObjPtr, Init);
  4: Config := New(SBCfgObjPtr, Init);
  End;
If Config = Nil Then
  Die('No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory, or use -c');
Config^.Load;
If Config^.GetError <> 0 Then
  Die(IntToStr(Config^.GetError) + ': Error loading config files');
FN := TokenFileName(Config^.GetBbsPath);
UseFn := ChangeFileExt(FN, '.use');
If Not LoadTokens(FN, Tokens, Err) Then
  Die(Err);
If Cmd = 'add' Then DoAdd
Else If Cmd = 'list' Then DoList
Else If Cmd = 'revoke' Then DoRevoke
Else DoRotate;
End.
