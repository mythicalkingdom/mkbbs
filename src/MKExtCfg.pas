Unit MKExtCfg;   {extensions.cfg: the scripts the sysop gave the BBS, and what each may do (MHOST-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
     extensions.cfg is a plain text file in the BBS directory, in the style of uploads.cfg: blocks in brackets, name = value, a # starts a comment.

       [who]                          the name of the extension (letters, digits, - and _)
       file    = scripts/who.bas      the program (.bas = BASIC, .pas = Pascal); relative to the BBS directory
       caps    = users:read nodes:read       what the program may ask the BBS (blanks or commas); none: nothing
       level   = 100                  menu command and hooks: the lowest security level that runs it (default 0)
       timeout = 30                   seconds the program may run (default 60; 0: none)
       desc    = who is on line       shown by mkcheck

     Capabilities: users:read msgs:read msgs:private files:read nodes:read events:read stats:read chat:read log:write  (writes come later); * = all.
     mk -x script uses the entry whose file is that script; a script that is in no entry gets every read capability (the sysop ran it by hand: -C narrows it).
}

Interface

Uses Classes;

Type
  TExtEntry = Record
    Name, FileName, Caps, Desc: String;
    Level, Timeout: LongInt;
  End;

  TExtCfg = Class
    Entries: Array Of TExtEntry;
    Problems: TStringList;
    BbsDir: String;
    Constructor Create(Const ABbsDir: String);
    Destructor Destroy; Override;
    Procedure Load;
    Function Find(Const Name: String): Integer;                 {by name, -1: none}
    Function FindFile(Const Path: String): Integer;             {the entry whose file is this path, -1: none}
    Function FullPath(Const E: TExtEntry): String;
  End;

Function ExtKnownCap(Const Cap: String): Boolean;

Implementation

Uses SysUtils;

Const
  KnownCaps = ' users:read msgs:read msgs:private files:read nodes:read events:read stats:read chat:read log:write * ';


Function ExtKnownCap(Const Cap: String): Boolean;
  Begin
  Result := Pos(' ' + LowerCase(Cap) + ' ', KnownCaps) > 0;
  End;


Constructor TExtCfg.Create(Const ABbsDir: String);
  Begin
  BbsDir := ABbsDir;
  If (BbsDir <> '') And (BbsDir[Length(BbsDir)] <> '/') Then
    BbsDir := BbsDir + '/';
  Problems := TStringList.Create;
  End;


Destructor TExtCfg.Destroy;
  Begin
  Problems.Free;
  Inherited Destroy;
  End;


Function TExtCfg.Find(Const Name: String): Integer;
  Var
    i: Integer;

  Begin
  Result := -1;
  For i := 0 To High(Entries) Do
    If CompareText(Entries[i].Name, Name) = 0 Then
      Exit(i);
  End;


Function TExtCfg.FullPath(Const E: TExtEntry): String;
  Begin
  If (E.FileName <> '') And (E.FileName[1] = '/') Then
    Result := E.FileName
  Else
    Result := BbsDir + E.FileName;
  End;


Function TExtCfg.FindFile(Const Path: String): Integer;
  Var
    i: Integer;
    P: String;

  Begin
  Result := -1;
  P := ExpandFileName(Path);
  For i := 0 To High(Entries) Do
    If ExpandFileName(FullPath(Entries[i])) = P Then
      Exit(i);
  End;


Procedure TExtCfg.Load;
  Var
    L: TStringList;
    i, p, k: Integer;
    S, Key, Val, Cur: String;
    Cap: String;

  Procedure Why(Const T: String);
    Begin
    Problems.Add('line ' + IntToStr(i + 1) + ': ' + T);
    End;

  Begin
  SetLength(Entries, 0);
  Problems.Clear;
  If Not FileExists(BbsDir + 'extensions.cfg') Then
    Exit;
  L := TStringList.Create;
  Try
    L.LoadFromFile(BbsDir + 'extensions.cfg');
    Cur := '';
    For i := 0 To L.Count - 1 Do
      Begin
      S := Trim(L[i]);
      If (S = '') Or (S[1] = '#') Then
        Continue;
      If S[1] = '[' Then
        Begin
        If S[Length(S)] <> ']' Then
          Begin
          Why('a block starts with [name]');
          Cur := '';
          Continue;
          End;
        Cur := Trim(Copy(S, 2, Length(S) - 2));
        For k := 1 To Length(Cur) Do
          If Not (Cur[k] In ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']) Then
            Begin
            Why('the name of an extension is letters, digits, - and _');
            Cur := '';
            Break;
            End;
        If Cur = '' Then
          Continue;
        If Find(Cur) >= 0 Then
          Begin
          Why('the extension ' + Cur + ' is there already');
          Cur := '';
          Continue;
          End;
        SetLength(Entries, Length(Entries) + 1);
        With Entries[High(Entries)] Do
          Begin
          Name := Cur;
          FileName := '';
          Caps := '';
          Desc := '';
          Level := 0;
          Timeout := 60;
          End;
        Continue;
        End;
      p := Pos('=', S);
      If (p = 0) Or (Cur = '') Then
        Begin
        Why('not a setting of a block: ' + Copy(S, 1, 40));
        Continue;
        End;
      Key := LowerCase(Trim(Copy(S, 1, p - 1)));
      Val := Trim(Copy(S, p + 1, Length(S)));
      With Entries[High(Entries)] Do
        If Key = 'file' Then FileName := Val
        Else If Key = 'caps' Then
          Begin
          Caps := '';
          For k := 1 To Length(Val) + 1 Do
            If (k > Length(Val)) Or (Val[k] In [' ', ',', #9]) Then
              Begin
              If Cap <> '' Then
                Begin
                If Not ExtKnownCap(Cap) Then
                  Why('unknown capability ' + Cap);
                Caps := Caps + Copy(' ', 1, Ord(Caps <> '')) + LowerCase(Cap);
                End;
              Cap := '';
              End
            Else
              Cap := Cap + Val[k];
          End
        Else If Key = 'level' Then
          Begin
          If StrToIntDef(Val, -1) < 0 Then Why('level is a number') Else Level := StrToInt(Val);
          End
        Else If Key = 'timeout' Then
          Begin
          If StrToIntDef(Val, -1) < 0 Then Why('timeout is a number of seconds') Else Timeout := StrToInt(Val);
          End
        Else If Key = 'desc' Then Desc := Val
        Else
          Why('unknown setting ' + Key);
      End;
    For i := 0 To High(Entries) Do
      If Entries[i].FileName = '' Then
        Problems.Add('the extension ' + Entries[i].Name + ' has no file');
  Finally
    L.Free;
  End;
  End;


End.
