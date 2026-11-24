Program MKFileCheck;

{$mode objfpc}{$H+}

{
     mkfilecheck: checks the file areas against their lists (files.bbs): a file that is listed and not there, a file that is there and not listed, a file listed twice.

       mkfilecheck [-c config dir] [-a area] [-f] [-l] [-v] [-q]

         -a AREA   only this file area (its number)
         -f        fix: the lines (and the description lines under them) of the files that are not there are taken out of the list, and names in the wrong case are written as the files are
         -l        list: a line "NAME   (not described)" is added to the list for each file that is there and not listed
         -v        every file that is named
         -q        only the areas that have something

     The list of an area is files.bbs in the directory that mkconfig gives for the list (the file area path when it has none); the files are the ones of the file area path.  A name that differs
     only in upper and lower case counts as the same file but is a fault ("case"): the BBS uses names exactly as they are written, so the list must write a name the way the file is on the disk; -f changes it in the list.  Hidden files (a leading dot), the list itself, its .bak and
     directories are not files of the area.  Several areas that share a directory are checked once.  The list is changed by writing a whole new file that replaces it, and the old one is kept
     as files.bbs.bak.
     The exit code: 0 nothing wrong (or everything that was wrong has been fixed), 1 not usable, 2 something is wrong and was left (no -f / -l).
}

Uses SysUtils, Classes, BaseUnix, Unix,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB;

Var
  Fix, AddList, Verbose, Quiet: Boolean;
  OnlyArea: Integer;
  Seen: TStringList;
  Left, Fixed, Areas: Integer;


Procedure Die(Code: Integer; S: String);
  Begin
  WriteLn(StdErr, 'mkfilecheck: ', S);
  Halt(Code);
  End;


Function Dir_(P: String): String;
  Begin
  Result := P;
  If (Result <> '') And (Result[Length(Result)] <> '/') Then
    Result := Result + '/';
  End;


Function FirstWord(S: String): String;
  Var
    p: Integer;

  Begin
  p := 1;
  While (p <= Length(S)) And (S[p] <> ' ') And (S[p] <> #9) Do
    Inc(p);
  Result := Copy(S, 1, p - 1);
  End;


Procedure CheckArea(A: Integer);
  Var
    Name, FilesDir, ListFile, L, W, Key: String;
    Lines: TStringList;
    Listed, Disk: TStringList;               {name (as written) -> original case in the other list}
    SR: TSearchRec;
    i, j, k, Missing, Unlisted, Dupes, Case_: Integer;
    Skipping: Boolean;
    Out_: TStringList;
    DiskNames: TStringList;
    Say: Boolean;
    Msg: String;
    T: Text;

  Procedure Note(S: String);
    Begin
    Msg := Msg + '  ' + S + LineEnding;
    End;

  Begin
  Name := Config^.GetFileAreaName(A);
  FilesDir := Dir_(Config^.GetFileAreaPath(A));
  ListFile := Config^.GetFileListPath(A);                 {the name of the list (the whole path); some configurations name a directory}
  If (ListFile = '') Or DirectoryExists(ListFile) Then
    ListFile := Dir_(ListFile + Copy('/', 1, 1)) + 'files.bbs';
  If ListFile = 'files.bbs' Then
    ListFile := FilesDir + 'files.bbs';
  If (FilesDir = '') Or Not DirectoryExists(FilesDir) Then
    Begin
    If Not Quiet Then
      WriteLn('area ', A, ' ', Name, ': the directory ', FilesDir, ' is not there');
    Exit;
    End;
  Key := ListFile + '|' + FilesDir;
  If Seen.IndexOf(Key) >= 0 Then
    Exit;
  Seen.Add(Key);
  Inc(Areas);
  Msg := '';
  Lines := TStringList.Create;
  Listed := TStringList.Create;
  Listed.CaseSensitive := False;
  Listed.Sorted := False;
  Disk := TStringList.Create;
  Disk.CaseSensitive := False;
  DiskNames := TStringList.Create;
  If FileExists(ListFile) Then
    Lines.LoadFromFile(ListFile);
  For i := 0 To Lines.Count - 1 Do
    Begin
    L := Lines[i];
    If (L <> '') And (L[1] > ' ') And (L[1] <> ';') And (L[1] <> '/') Then
      Listed.Add(FirstWord(L));
    End;
  If FindFirst(FilesDir + '*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If ((SR.Attr And faDirectory) = 0) And (SR.Name[1] <> '.') And (LowerCase(SR.Name) <> 'files.bbs') And (LowerCase(SR.Name) <> 'files.bbs.bak') And (LowerCase(SR.Name) <> 'files.bbs.new') Then
        Begin
        Disk.Add(SR.Name);
        DiskNames.Add(SR.Name);
        End;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  Missing := 0;
  Unlisted := 0;
  Dupes := 0;
  Case_ := 0;
  { listed and not there; listed twice; the case }
  For i := 0 To Listed.Count - 1 Do
    Begin
    If Listed.IndexOf(Listed[i]) < i Then
      Begin
      Inc(Dupes);
      If Verbose Then
        Note('listed twice: ' + Listed[i]);
      Continue;
      End;
    k := Disk.IndexOf(Listed[i]);
    If k < 0 Then
      Begin
      Inc(Missing);
      If Verbose Or True Then
        Note('listed, not there: ' + Listed[i]);
      End
    Else If Disk[k] <> Listed[i] Then
      Begin
      Inc(Case_);
      If Verbose Then
        Note('case: listed as ' + Listed[i] + ', the file is ' + Disk[k]);
      End;
    End;
  { there and not listed }
  For i := 0 To DiskNames.Count - 1 Do
    If Listed.IndexOf(DiskNames[i]) < 0 Then
      Begin
      Inc(Unlisted);
      Note('there, not listed: ' + DiskNames[i]);
      End;
  { fix }
  If (Fix And (Missing + Case_ > 0)) Or (AddList And (Unlisted > 0)) Then
    Begin
    Out_ := TStringList.Create;
    Skipping := False;
    For i := 0 To Lines.Count - 1 Do
      Begin
      L := Lines[i];
      If (L <> '') And (L[1] > ' ') And (L[1] <> ';') And (L[1] <> '/') Then
        Begin
        W := FirstWord(L);
        Skipping := Fix And (Disk.IndexOf(W) < 0);
        If Fix And (Not Skipping) Then
          Begin                          {the name as the file is written on the disk}
          k := Disk.IndexOf(W);
          If (k >= 0) And (Disk[k] <> W) Then
            L := Disk[k] + Copy(L, Length(W) + 1, Length(L));
          End;
        End
      Else If (L = '') Or (L[1] > ' ') Then
        Skipping := False;
      If Not Skipping Then
        Out_.Add(L);
      End;
    If AddList Then
      For i := 0 To DiskNames.Count - 1 Do
        If Listed.IndexOf(DiskNames[i]) < 0 Then
          Out_.Add(Copy(DiskNames[i] + '                ', 1, 12) + ' (not described)');
    If FileExists(ListFile) Then
      Begin
      Lines.SaveToFile(ListFile + '.bak');
      End;
    Out_.SaveToFile(ListFile + '.new');
    fpRename(ListFile + '.new', ListFile);
    Out_.Free;
    If Fix Then
      Inc(Fixed, Missing + Case_);
    If AddList Then
      Inc(Fixed, Unlisted);
    End;
  If Fix Then
    Inc(Left, 0)
  Else
    Inc(Left, Missing + Case_);
  If Not AddList Then
    Inc(Left, Unlisted);
  Say := (Not Quiet) Or (Msg <> '');
  If Say Then
    Begin
    Write('area ', A, ' ', Name, ' (', FilesDir, '): ', Listed.Count, ' listed, ', Disk.Count, ' file(s)');
    If Missing + Unlisted + Dupes + Case_ > 0 Then
      Write(': ', Missing, ' missing, ', Unlisted, ' not listed, ', Dupes, ' listed twice, ', Case_, ' in another case');
    If (Fix And (Missing + Case_ > 0)) Or (AddList And (Unlisted > 0)) Then
      Write(' (fixed)');
    WriteLn;
    If Msg <> '' Then
      Write(Msg);
    End;
  Lines.Free;
  Listed.Free;
  Disk.Free;
  DiskNames.Free;
  End;


Var
  i, k: Integer;
  A, S, ConfDir: String;
  BbsType: Word;
  Argv: TStringList;
  PArgv, EnvP: Array Of PChar;
  EnvS: Array Of String;

Begin
Fix := False;
AddList := False;
Verbose := False;
Quiet := False;
OnlyArea := 0;
ConfDir := '';
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-f' Then Fix := True
  Else If A = '-l' Then AddList := True
  Else If A = '-v' Then Verbose := True
  Else If A = '-q' Then Quiet := True
  Else If A = '-a' Then
    Begin
    Inc(i);
    OnlyArea := StrToIntDef(ParamStr(i), 0);
    If OnlyArea <= 0 Then
      Die(1, '-a needs an area number');
    End
  Else If A = '-c' Then
    Begin
    Inc(i);
    ConfDir := ExpandFileName(ParamStr(i));
    End
  Else
    Begin
    WriteLn('usage: mkfilecheck [-c config dir] [-a area] [-f] [-l] [-v] [-q]     -f take the lines of missing files out  -l list the files that are not listed  -v every name  -q only areas with something');
    Halt(1);
    End;
  Inc(i);
  End;
If (ConfDir <> '') And (GetEnvironmentVariable('MK') <> ConfDir) Then
  Begin
  Argv := TStringList.Create;
  Argv.Add(ParamStr(0));
  i := 1;
  While i <= ParamCount Do
    Begin
    If ParamStr(i) = '-c' Then
      Inc(i)
    Else
      Argv.Add(ParamStr(i));
    Inc(i);
    End;
  SetLength(PArgv, Argv.Count + 1);
  For i := 0 To Argv.Count - 1 Do
    PArgv[i] := PChar(Argv[i]);
  PArgv[Argv.Count] := Nil;
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
  Die(1, 'cannot start again with MK set');
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
  Die(1, 'No configuration: set MK (or RA, QUICK, SBBS) to the BBS config directory');
Config^.Load;
If Config^.GetError <> 0 Then
  Die(1, IntToStr(Config^.GetError) + ': Error loading config files');
Seen := TStringList.Create;
Seen.CaseSensitive := True;
If OnlyArea > 0 Then
  Begin
  If Config^.GetFileAreaName(OnlyArea) = '' Then
    Die(1, 'no file area ' + IntToStr(OnlyArea));
  CheckArea(OnlyArea);
  End
Else
  For i := 1 To Config^.GetMaxFileAreas Do
    If Config^.GetFileAreaName(i) <> '' Then
      CheckArea(i);
WriteLn(Areas, ' file area(s) checked', Copy(', ' + IntToStr(Fixed) + ' line(s) fixed', 1, 40 * Ord(Fixed > 0)), Copy(', ' + IntToStr(Left) + ' thing(s) left to look at', 1, 40 * Ord(Left > 0)));
Dispose(Config, Done);
If Left > 0 Then
  Halt(2);
End.
