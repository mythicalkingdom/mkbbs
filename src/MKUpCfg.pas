Unit MKUpCfg;   {uploads.cfg: what happens to a file a caller has uploaded (UPLOAD-PLAN.md)}

{$MODE OBJFPC}
{$H+}

{
     uploads.cfg is a plain text file in the BBS directory, in the style of doors.cfg: blocks in brackets, name = value, a # starts a comment (at the start of a line or after a space).
     Without the file (or without a setting) nothing is tested or scanned and the caller describes each file.

       [global]
       quarantine = /opt/bbs/quarantine   where a file that failed a test goes, with a .why note (default: quarantine in the BBS directory; empty: it is deleted)
       sandbox    = on                    the tests and the scanner run in bubblewrap (no network, a private /tmp, the file read only); off: they run as the BBS user does
       timeout    = 120                   seconds for each command (the command is killed and the file refused; a scanner that is too slow counts as failed: see scanfail)
       minfree    = 50                    MB that must stay free on the disk of the area (an upload is refused before it starts when less is free); 0: no check
       maxsize    = 0                     KB, the largest file (0: no limit)
       scan       = clamscan --no-summary %f      every file is scanned (empty: none).  Exit 0: clean, 1: found, any other: the scanner failed
       scanfail   = refuse                refuse | accept: what a scanner that failed (not found, timed out, an error) means for the file
       ask        = dizfirst              the description: dizfirst (FILE_ID.DIZ, else ask the caller) | always (ask, an empty answer takes the DIZ) | never (the DIZ, else "(no description)")
       bind       = /var/lib/clamav       more directories the sandbox shows, writable (any number of lines)
       robind     = /var/lib/clamav       ... read only

       [type zip jar]                     the files of these extensions (lower case)
       test = unzip -tqq %f               exit 0: the file is good, else it is refused (the first line of what it printed goes to the caller)
       diz  = unzip -p -C %f FILE_ID.DIZ  prints FILE_ID.DIZ on its standard output

       [area 3]                           a file area (its number): scan, maxsize, minfree, ask, quarantine as above, for this area only
       scan =
       maxsize = 4096

     %f is the file's name (in the directory the command runs in, with a clean name), %d the directory.  A command is a program and its arguments, not a shell line.
}

Interface

Uses Classes;

Type
  TUpType = Record
    Exts: String;                       {' zip jar '}
    Test, Diz: String;
  End;

  TUpArea = Record
    Num: Integer;
    Scan, Ask, Quarantine: String;
    ScanSet, AskSet, QuarSet, MaxSet, FreeSet: Boolean;
    MaxSize, MinFree: LongInt;
  End;

  TUpCfg = Class
    Quarantine, Scan, ScanFail, Ask: String;
    QuarSet: Boolean;
    Sandbox: Boolean;
    Timeout, MinFree, MaxSize: LongInt;
    Binds, ROBinds: TStringList;
    Types: Array Of TUpType;
    Areas: Array Of TUpArea;
    Problems: TStringList;
    Constructor Create;
    Destructor Destroy; Override;
    Procedure Load(Const Path: String);
    Function TypeFor(Const FileName: String): Integer;       {index in Types, -1 when none}
    Function AreaIndex(Num: Integer): Integer;
    Function ScanOf(Num: Integer): String;
    Function AskOf(Num: Integer): String;
    Function MaxSizeOf(Num: Integer): LongInt;                {KB}
    Function MinFreeOf(Num: Integer): LongInt;                {MB}
    Function QuarantineOf(Num: Integer): String;              {'' = delete}
  End;

Function SplitCommand(Const Cmd, FileName, Dir: String; Args: TStrings): Boolean;
  {the command line as a program and arguments (blanks separate, " " and ' ' group), %f and %d put in; False when it is empty}


Implementation

Uses SysUtils;


Constructor TUpCfg.Create;
  Begin
  Binds := TStringList.Create;
  ROBinds := TStringList.Create;
  Problems := TStringList.Create;
  Sandbox := True;
  Timeout := 120;
  ScanFail := 'refuse';
  Ask := 'dizfirst';
  QuarSet := False;
  End;


Destructor TUpCfg.Destroy;
  Begin
  Binds.Free;
  ROBinds.Free;
  Problems.Free;
  Inherited Destroy;
  End;


Function YesNo(Const S: String; Var Ok: Boolean): Boolean;
  Begin
  Ok := True;
  YesNo := False;
  If (LowerCase(S) = 'yes') Or (LowerCase(S) = 'on') Or (S = '1') Or (LowerCase(S) = 'true') Then
    YesNo := True
  Else If Not ((LowerCase(S) = 'no') Or (LowerCase(S) = 'off') Or (S = '0') Or (LowerCase(S) = 'false')) Then
    Ok := False;
  End;


Procedure TUpCfg.Load(Const Path: String);
  Var
    L: TStringList;
    i, p, Cur, Kind: Integer;
    S, K, V, N: String;
    Ok, B: Boolean;

  Procedure Bad(Const Why: String);
    Begin
    Problems.Add('line ' + IntToStr(i + 1) + ': ' + Why);
    End;

  Function Ask_(Const X: String): Boolean;
    Begin
    Ask_ := (X = 'dizfirst') Or (X = 'always') Or (X = 'never');
    If Not Ask_ Then
      Bad('ask is dizfirst, always or never');
    End;

  Begin
  L := TStringList.Create;
  Try
    Try
      L.LoadFromFile(Path);
    Except
      Exit;
    End;
    Kind := 0;                                   {0 nothing yet, 1 global, 2 type, 3 area}
    Cur := -1;
    For i := 0 To L.Count - 1 Do
      Begin
      S := Trim(L[i]);
      p := Pos(' #', S);
      If p > 0 Then
        S := Trim(Copy(S, 1, p - 1));
      If (S = '') Or (S[1] = '#') Or (S[1] = ';') Then
        Continue;
      If S[1] = '[' Then
        Begin
        If S[Length(S)] <> ']' Then
          Begin
          Bad('a block name starts with [ and ends with ]');
          Kind := 0;
          Continue;
          End;
        S := Trim(Copy(S, 2, Length(S) - 2));
        If LowerCase(S) = 'global' Then
          Kind := 1
        Else If LowerCase(Copy(S, 1, 5)) = 'type ' Then
          Begin
          Kind := 2;
          SetLength(Types, Length(Types) + 1);
          Cur := High(Types);
          Types[Cur].Test := '';
          Types[Cur].Diz := '';
          Types[Cur].Exts := ' ' + LowerCase(Trim(Copy(S, 6, 200))) + ' ';
          If Trim(Types[Cur].Exts) = '' Then
            Bad('a type needs extensions: [type zip jar]');
          End
        Else If LowerCase(Copy(S, 1, 5)) = 'area ' Then
          Begin
          Kind := 3;
          SetLength(Areas, Length(Areas) + 1);
          Cur := High(Areas);
          FillChar(Areas[Cur], SizeOf(TUpArea), 0);
          Areas[Cur].Num := StrToIntDef(Trim(Copy(S, 6, 20)), 0);
          If Areas[Cur].Num <= 0 Then
            Bad('an area is [area 3]: its number');
          End
        Else
          Begin
          Bad('unknown block [' + S + ']');
          Kind := 0;
          End;
        Continue;
        End;
      p := Pos('=', S);
      If p = 0 Then
        Begin
        Bad('a setting is  name = value');
        Continue;
        End;
      K := LowerCase(Trim(Copy(S, 1, p - 1)));
      V := Trim(Copy(S, p + 1, Length(S)));
      Case Kind Of
        1: If K = 'quarantine' Then
             Begin
             Quarantine := V;
             QuarSet := True;
             End
           Else If K = 'sandbox' Then
             Begin
             B := YesNo(V, Ok);
             If Ok Then Sandbox := B Else Bad('sandbox is on or off');
             End
           Else If K = 'timeout' Then
             Begin
             Timeout := StrToIntDef(V, -1);
             If Timeout <= 0 Then
               Begin
               Bad('timeout is a number of seconds');
               Timeout := 120;
               End;
             End
           Else If K = 'minfree' Then
             MinFree := StrToIntDef(V, 0)
           Else If K = 'maxsize' Then
             MaxSize := StrToIntDef(V, 0)
           Else If K = 'scan' Then
             Scan := V
           Else If K = 'scanfail' Then
             Begin
             ScanFail := LowerCase(V);
             If (ScanFail <> 'refuse') And (ScanFail <> 'accept') Then
               Begin
               Bad('scanfail is refuse or accept');
               ScanFail := 'refuse';
               End;
             End
           Else If K = 'ask' Then
             Begin
             If Ask_(LowerCase(V)) Then Ask := LowerCase(V);
             End
           Else If K = 'bind' Then
             Binds.Add(V)
           Else If K = 'robind' Then
             ROBinds.Add(V)
           Else
             Bad('unknown setting ' + K + ' in [global]');
        2: If K = 'test' Then
             Types[Cur].Test := V
           Else If K = 'diz' Then
             Types[Cur].Diz := V
           Else
             Bad('unknown setting ' + K + ' in a type block');
        3: If K = 'scan' Then
             Begin
             Areas[Cur].Scan := V;
             Areas[Cur].ScanSet := True;
             End
           Else If K = 'maxsize' Then
             Begin
             Areas[Cur].MaxSize := StrToIntDef(V, 0);
             Areas[Cur].MaxSet := True;
             End
           Else If K = 'minfree' Then
             Begin
             Areas[Cur].MinFree := StrToIntDef(V, 0);
             Areas[Cur].FreeSet := True;
             End
           Else If K = 'ask' Then
             Begin
             If Ask_(LowerCase(V)) Then
               Begin
               Areas[Cur].Ask := LowerCase(V);
               Areas[Cur].AskSet := True;
               End;
             End
           Else If K = 'quarantine' Then
             Begin
             Areas[Cur].Quarantine := V;
             Areas[Cur].QuarSet := True;
             End
           Else
             Bad('unknown setting ' + K + ' in an area block');
        Else
          Bad('a setting outside a block');
        End;
      End;
  Finally
    L.Free;
  End;
  End;


Function TUpCfg.TypeFor(Const FileName: String): Integer;
  Var
    E: String;
    i: Integer;

  Begin
  TypeFor := -1;
  E := LowerCase(ExtractFileExt(FileName));
  If E = '' Then
    Exit;
  Delete(E, 1, 1);
  For i := 0 To High(Types) Do
    If Pos(' ' + E + ' ', Types[i].Exts) > 0 Then
      Begin
      TypeFor := i;
      Exit;
      End;
  End;


Function TUpCfg.AreaIndex(Num: Integer): Integer;
  Var
    i: Integer;

  Begin
  AreaIndex := -1;
  For i := 0 To High(Areas) Do
    If Areas[i].Num = Num Then
      AreaIndex := i;
  End;


Function TUpCfg.ScanOf(Num: Integer): String;
  Var
    i: Integer;

  Begin
  ScanOf := Scan;
  i := AreaIndex(Num);
  If (i >= 0) And Areas[i].ScanSet Then
    ScanOf := Areas[i].Scan;
  End;


Function TUpCfg.AskOf(Num: Integer): String;
  Var
    i: Integer;

  Begin
  AskOf := Ask;
  i := AreaIndex(Num);
  If (i >= 0) And Areas[i].AskSet Then
    AskOf := Areas[i].Ask;
  End;


Function TUpCfg.MaxSizeOf(Num: Integer): LongInt;
  Var
    i: Integer;

  Begin
  MaxSizeOf := MaxSize;
  i := AreaIndex(Num);
  If (i >= 0) And Areas[i].MaxSet Then
    MaxSizeOf := Areas[i].MaxSize;
  End;


Function TUpCfg.MinFreeOf(Num: Integer): LongInt;
  Var
    i: Integer;

  Begin
  MinFreeOf := MinFree;
  i := AreaIndex(Num);
  If (i >= 0) And Areas[i].FreeSet Then
    MinFreeOf := Areas[i].MinFree;
  End;


Function TUpCfg.QuarantineOf(Num: Integer): String;
  Var
    i: Integer;

  Begin
  QuarantineOf := Quarantine;
  i := AreaIndex(Num);
  If (i >= 0) And Areas[i].QuarSet Then
    QuarantineOf := Areas[i].Quarantine;
  End;


Function SplitCommand(Const Cmd, FileName, Dir: String; Args: TStrings): Boolean;
  Var
    i: Integer;
    Cur, Q: String;
    InArg: Boolean;
    C: Char;

  Procedure Flush;
    Begin
    If InArg Then
      Begin
      Args.Add(Cur);
      Cur := '';
      InArg := False;
      End;
    End;

  Begin
  Args.Clear;
  Cur := '';
  Q := '';
  InArg := False;
  i := 1;
  While i <= Length(Cmd) Do
    Begin
    C := Cmd[i];
    If (Q = '') And (C In [' ', #9]) Then
      Flush
    Else If (Q = '') And (C In ['"', '''']) Then
      Begin
      Q := C;
      InArg := True;
      End
    Else If (Q <> '') And (C = Q[1]) Then
      Q := ''
    Else If (C = '%') And (i < Length(Cmd)) And (Cmd[i + 1] = 'f') Then
      Begin
      Cur := Cur + FileName;
      InArg := True;
      Inc(i);
      End
    Else If (C = '%') And (i < Length(Cmd)) And (Cmd[i + 1] = 'd') Then
      Begin
      Cur := Cur + Dir;
      InArg := True;
      Inc(i);
      End
    Else If (C = '%') And (i < Length(Cmd)) And (Cmd[i + 1] = '%') Then
      Begin
      Cur := Cur + '%';
      InArg := True;
      Inc(i);
      End
    Else
      Begin
      Cur := Cur + C;
      InArg := True;
      End;
    Inc(i);
    End;
  Flush;
  SplitCommand := Args.Count > 0;
  End;


End.
