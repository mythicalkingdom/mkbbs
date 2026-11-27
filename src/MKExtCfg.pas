{ SPDX-License-Identifier: GPL-3.0-or-later }
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

     A block [hooks] says which extensions run when something happens in a call (names of extensions of this file, in this order):

       [hooks]
       logon   = greeter tally        after a caller has logged on, before the first menu
       logoff  = tally                at the end of the call (the caller may be gone already)
       newuser = onboarding           a new user has registered
       upload  = scan                 a file was accepted (area, file name, size)
       newmsg  = notify               a message was posted (area, number)
       menu    = banner               a menu was entered (its name);  menu.main = ad  only for the menu main

     A hook runs with the capabilities, the level and the timeout of its entry, with the event's data as its arguments (arg 1 is the event, then the user, then what the event says: see EXTENSIONS.md).
     A hook that fails, is too slow or is not allowed to this caller is logged and skipped: it never stops the caller.

     Capabilities: users:read msgs:read msgs:private files:read nodes:read events:read stats:read chat:read log:write, and the writes msgs:post users:write files:add node:send node:kick node:time chat:say chat:moderate (a script that is in no entry does not get them: -C or an entry), and in the BBS session:read (the current caller, the node) and session:control (show a text file, press-enter pause, hang up); * = all.
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
    Hooks: TStringList;                {event=names of extensions}
    Problems: TStringList;
    BbsDir: String;
    Constructor Create(Const ABbsDir: String);
    Destructor Destroy; Override;
    Procedure Load;
    Function Find(Const Name: String): Integer;                 {by name, -1: none}
    Function FindFile(Const Path: String): Integer;             {the entry whose file is this path, -1: none}
    Function FullPath(Const E: TExtEntry): String;
    Function HookNames(Const Event: String): String;           {the extensions of a hook, '' = none}
  End;

Function ExtKnownCap(Const Cap: String): Boolean;
Function ExtKnownEvent(Const Ev: String): Boolean;      {logon logoff newuser upload newmsg menu menu.<name>}

Implementation

Uses SysUtils;

Const
  KnownCaps = ' users:read msgs:read msgs:private files:read nodes:read events:read stats:read chat:read log:write session:read session:control msgs:post users:write files:add node:send node:kick node:time chat:say chat:moderate * ';


Function ExtKnownCap(Const Cap: String): Boolean;
  Begin
  Result := Pos(' ' + LowerCase(Cap) + ' ', KnownCaps) > 0;
  End;


Function ExtKnownEvent(Const Ev: String): Boolean;
  Begin
  Result := (Pos(' ' + LowerCase(Ev) + ' ', ' logon logoff newuser upload newmsg menu ') > 0) Or ((Copy(LowerCase(Ev), 1, 5) = 'menu.') And (Length(Ev) > 5));
  End;


Function TExtCfg.HookNames(Const Event: String): String;
  Begin
  Result := Hooks.Values[LowerCase(Event)];
  End;


Constructor TExtCfg.Create(Const ABbsDir: String);
  Begin
  Hooks := TStringList.Create;
  BbsDir := ABbsDir;
  If (BbsDir <> '') And (BbsDir[Length(BbsDir)] <> '/') Then
    BbsDir := BbsDir + '/';
  Problems := TStringList.Create;
  End;


Destructor TExtCfg.Destroy;
  Begin
  Hooks.Free;
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
    InHooks: Boolean;

  Procedure Why(Const T: String);
    Begin
    Problems.Add('line ' + IntToStr(i + 1) + ': ' + T);
    End;

  Begin
  SetLength(Entries, 0);
  Problems.Clear;
  Hooks.Clear;
  InHooks := False;
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
        InHooks := LowerCase(Cur) = 'hooks';
        If InHooks Then
          Begin
          Cur := '';
          Continue;
          End;
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
      If InHooks And (p > 0) Then
        Begin
        Key := LowerCase(Trim(Copy(S, 1, p - 1)));
        Val := Trim(Copy(S, p + 1, Length(S)));
        If Not ExtKnownEvent(Key) Then
          Why('unknown hook ' + Key + ' (logon logoff newuser upload newmsg menu menu.<name>)')
        Else
          Hooks.Values[Key] := Val;
        Continue;
        End;
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
    For i := 0 To Hooks.Count - 1 Do
      Begin
      Val := Hooks.ValueFromIndex[i];
      Cap := '';
      For k := 1 To Length(Val) + 1 Do
        If (k > Length(Val)) Or (Val[k] In [' ', ',', #9]) Then
          Begin
          If (Cap <> '') And (Find(Cap) < 0) Then
            Problems.Add('the hook ' + Hooks.Names[i] + ' names the extension ' + Cap + ', which is not in this file');
          Cap := '';
          End
        Else
          Cap := Cap + Val[k];
      End;
  Finally
    L.Free;
  End;
  End;


End.
