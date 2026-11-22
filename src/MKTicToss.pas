Unit MKTicToss;   {Tossing TIC files (file echoes): the files that came in with a TIC go to their file area.  See TIC-PLAN.md}

{
  For each *.tic in the (secure) inbound:

     1. the TIC is read and has what it needs (File, Area, Size, Crc);
     2. its file is in the inbound (found without regard to case).  When it is not there yet the TIC waits for the next run, up to a day;
     3. the system named in From is one of the echo systems, and its TIC password (File Echo Systems) is the Pw of the TIC (a system with
        no password set is not asked for one);
     4. Area is a file echo, and this system may send it (it is the hub, or the echo goes to it);
     5. the size and the CRC are those of the file, our own address is not in the Path (a loop), and the file was not tossed before
        (the same echo, name and CRC: kept in ticdupe.dat in the inbound for 30 days);
     6. the check command of File Echo Options accepts the file (unless the echo says not to run it).

  What is not right goes, with its file, to badtic/ in the inbound and the log says why.  What is right goes to the file area of the echo:
  a file with that name that is there (another CRC: a new file) is replaced, the files that Replaces names too when the echo allows it, the
  file gets the date of the TIC, and a line (and the long description) is added to files.bbs of the area.  A pass-through echo (no file
  area) is left alone in this version (passing on is the next step).
}

{$I MKB.Def}

Interface

Var
  TicLog: Procedure(S: String);         {the log of the tosser}
  TicIsOurs: Function(A: String): Boolean;  {an address of ours}
  TicNow: LongInt;                      {seconds since 1970; 0 = the clock}

Type
  TicTossResult = Record
    Tossed, Bad, Dupes, Waiting, Passthru: Word;
    End;

Procedure TicTossInbound(InDir: String; Var R: TicTossResult);
  {all the TICs of the directory (with the slash at the end)}

Implementation

Uses BaseUnix, Unix, Dos, MKString, MKGlobT, MKFile, MKCfgAbs, MKTic;

Const
  DupeDays = 30;
  WaitSecs = 86400;                     {a TIC whose file has not come waits a day}

Var
  FE: ^FileEchoCfgType;


Procedure Say(S: String);
  Begin
  If @TicLog <> Nil Then
    TicLog(S);
  End;


Function Now_: LongInt;
  Begin
  If TicNow <> 0 Then
    Now_ := TicNow
  Else
    Now_ := fpTime;
  End;


Function Quote(S: String): String;
  Var
    i: Word;
    R: String;

  Begin
  R := '''';
  For i := 1 To Length(S) Do
    If S[i] = '''' Then
      R := R + '''\'''''
    Else
      R := R + S[i];
  Quote := R + '''';
  End;


Function Low(S: String): String;
  Var
    i: Word;

  Begin
  For i := 1 To Length(S) Do
    If S[i] In ['A'..'Z'] Then
      S[i] := Chr(Ord(S[i]) + 32);
  Low := S;
  End;


Function FindNoCase(D, Name: String): String;
  {the name of a file in D that is Name whatever the case, '' = none}
  Var
    SR: SearchRec;
    L: String;

  Begin
  FindNoCase := '';
  L := Low(Name);
  FindFirst(D + '*', AnyFile, SR);
  While DosError = 0 Do
    Begin
    If ((SR.Attr And Directory) = 0) And (Low(SR.Name) = L) Then
      FindNoCase := SR.Name;
    FindNext(SR);
    End;
  FindClose(SR);
  End;


Function FileTime(Path: String): LongInt;
  Var
    St: Stat;

  Begin
  FileTime := 0;
  If fpStat(Path, St) = 0 Then
    FileTime := St.st_mtime;
  End;


Procedure SetFileTime(Path: String; Secs: LongInt);
  Var
    U: UtimBuf;

  Begin
  U.actime := Secs;
  U.modtime := Secs;
  fpUtime(Path, @U);
  End;


Function MoveFile(Src, Dst: String): Boolean;
  {rename, or copy and delete when the directories are on different disks}
  Begin
  If fpRename(Src, Dst) = 0 Then
    MoveFile := True
  Else If CopyFile(Src, Dst) Then
    Begin
    fpUnlink(Src);
    MoveFile := True;
    End
  Else
    MoveFile := False;
  End;


{---------------------------------------------------------------- the duplicates}

Function DupeKey(Var T: TicType): String;
  Begin
  DupeKey := Low(T.Area) + '|' + T.FileName + '|' + TicCrcStr(T.Crc);
  End;


Function IsDupe(D: String; Var T: TicType): Boolean;
  Var
    F: Text;
    L, K: String;

  Begin
  IsDupe := False;
  Assign(F, D + 'ticdupe.dat');
  FileMode := 0;
  Reset(F);
  If IoResult <> 0 Then
    Exit;
  K := DupeKey(T);
  While Not Eof(F) Do
    Begin
    ReadLn(F, L);
    If Copy(L, 1, Length(K) + 1) = K + '|' Then
      IsDupe := True;
    End;
  Close(F);
  If IoResult <> 0 Then;
  End;


Procedure AddDupe(D: String; Var T: TicType);
  {the key and the day; what is older than DupeDays is dropped when the file is written}
  Var
    F, G: Text;
    L: String;
    p: Word;
    N, Limit: LongInt;
    Ok: Boolean;

  Begin
  Limit := Now_ - DupeDays * 86400;
  Assign(G, D + 'ticdupe.dat.new');
  Rewrite(G);
  If IoResult <> 0 Then
    Exit;
  Assign(F, D + 'ticdupe.dat');
  FileMode := 0;
  Reset(F);
  If IoResult = 0 Then
    Begin
    While Not Eof(F) Do
      Begin
      ReadLn(F, L);
      p := Length(L);
      While (p > 0) And (L[p] <> '|') Do
        Dec(p);
      Ok := False;
      If p > 0 Then
        Begin
        N := 0;
        Ok := True;
        If Copy(L, p + 1, 12) <> '' Then
          N := Str2Long(Copy(L, p + 1, 12));
        If N < Limit Then
          Ok := False;
        End;
      If Ok Then
        WriteLn(G, L);
      End;
    Close(F);
    End;
  WriteLn(G, DupeKey(T), '|', Now_);
  Close(G);
  If IoResult <> 0 Then
    Exit;
  fpRename(D + 'ticdupe.dat.new', D + 'ticdupe.dat');
  End;


{---------------------------------------------------------------- files.bbs}

Function FirstWord(S: String): String;
  Var
    p: Word;

  Begin
  p := 1;
  While (p <= Length(S)) And (S[p] <> ' ') And (S[p] <> #9) Do
    Inc(p);
  FirstWord := Copy(S, 1, p - 1);
  End;


Procedure ListUpdate(ListName: String; Drop: String; Pattern: Boolean; Name: String; Var T: TicType; Add: Boolean);
  {files.bbs: the lines (and their continuation lines) of the files that are gone are taken out (Drop = a name, or a pattern when
   Pattern), the new file's line is added at the end; the file is written whole and renamed, since the BBS reads it at any time}
  Var
    F, G: Text;
    L, W: String;
    Skipping: Boolean;
    i: Word;
    Pad: String;

  Begin
  Assign(G, ListName + '.new');
  Rewrite(G);
  If IoResult <> 0 Then
    Exit;
  Assign(F, ListName);
  FileMode := 0;
  Reset(F);
  If IoResult = 0 Then
    Begin
    Skipping := False;
    While Not Eof(F) Do
      Begin
      ReadLn(F, L);
      While (L <> '') And (L[Length(L)] In [#13, #10]) Do
        Delete(L, Length(L), 1);
      If (L <> '') And (L[1] > ' ') And (L[1] <> ';') And (L[1] <> '/') Then
        Begin                          {a line of a file}
        Skipping := False;
        W := FirstWord(L);
        If Drop <> '' Then
          If Pattern Then
            Skipping := TicMatchName(Drop, W)
          Else
            Skipping := Low(Drop) = Low(W);
        End
      Else If (L = '') Or (L[1] > ' ') Then
        Skipping := False;             {a blank or a comment ends the description of a dropped file}
      If Not Skipping Then
        WriteLn(G, L);
      End;
    Close(F);
    End;
  If Add Then
    Begin
    Pad := Name;
    While Length(Pad) < 12 Do
      Pad := Pad + ' ';
    WriteLn(G, Pad, ' ', T.Desc);
    For i := 1 To T.NumLdesc Do
      WriteLn(G, '             ', T.Ldesc[i]);
    End;
  Close(G);
  If IoResult <> 0 Then
    Exit;
  fpRename(ListName + '.new', ListName);
  End;


{---------------------------------------------------------------- bad TICs}

Procedure ToBad(InDir, TicName, FileName: String; Why: String);
  Var
    B, N: String;

  Procedure Put(Name: String);
    Begin
    If Name = '' Then
      Exit;
    N := Name;
    If FileExist(B + N) Then
      N := N + '.' + Long2Str(Now_);
    MoveFile(InDir + Name, B + N);
    End;

  Begin
  B := InDir + 'badtic/';
  If Not DirExist(B) Then
    MkDir(Copy(B, 1, Length(B) - 1));
  If IoResult <> 0 Then;
  Say('bad TIC ' + TicName + ': ' + Why);
  Put(TicName);
  Put(FileName);
  End;


{---------------------------------------------------------------- one TIC}

Function SystemOf(Addr: String): Word;
  Var
    i: Word;
    A: AddrType;

  Begin
  SystemOf := 0;
  If Addr = '' Then
    Exit;
  For i := 1 To 32 Do
    Begin
    Config^.GetEchoToAddr(i, A);
    If (A.Zone <> 0) And TicSameAddr(AddrStr(A), Addr) Then
      Begin
      SystemOf := i;
      Exit;
      End;
    End;
  End;


Function EchoOf(Tag: String): Word;
  Var
    i: Word;

  Begin
  EchoOf := 0;
  For i := 1 To MaxFileEchoes Do
    If (FE^.Area[i].Tag <> '') And (Low(FE^.Area[i].Tag) = Low(Tag)) Then
      Begin
      EchoOf := i;
      Exit;
      End;
  End;


Function CheckFile(Cmd: String; Secs: Word; FileP, TicP: String; Var Status: LongInt): Boolean;
  {the check command: %F is the file, %T the TIC; not 0, or too slow, is a refusal}
  Var
    C: String;
    p: Word;

  Begin
  C := Cmd;
  p := Pos('%F', C);
  While p > 0 Do
    Begin
    C := Copy(C, 1, p - 1) + Quote(FileP) + Copy(C, p + 2, 255);
    p := Pos('%F', C);
    End;
  p := Pos('%T', C);
  While p > 0 Do
    Begin
    C := Copy(C, 1, p - 1) + Quote(TicP) + Copy(C, p + 2, 255);
    p := Pos('%T', C);
    End;
  If Secs = 0 Then
    Secs := 60;
  Status := fpSystem('timeout ' + Long2Str(Secs) + ' sh -c ' + Quote(C) + ' >/dev/null 2>&1');
  If (Status And $7F) = 0 Then
    Status := (Status Shr 8) And $FF;     {the exit status, not the wait status}
  CheckFile := Status = 0;
  End;


Procedure DropOld(D: String; Pattern: String; Keep: String; ListName: String; Var T: TicType);
  {the files of the area that Pattern names go (and their lines in files.bbs), the one just stored (Keep) stays}
  Var
    SR: SearchRec;
    Names: Array[1..200] Of String[80];
    n, i: Word;

  Begin
  n := 0;
  FindFirst(D + '*', AnyFile, SR);
  While (DosError = 0) And (n < 200) Do
    Begin
    If ((SR.Attr And Directory) = 0) And TicMatchName(Pattern, SR.Name) And (Low(SR.Name) <> Low(Keep)) Then
      Begin
      Inc(n);
      Names[n] := SR.Name;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  For i := 1 To n Do
    Begin
    fpUnlink(D + Names[i]);
    Say('  replaced: ' + Names[i] + ' is gone');
    End;
  End;


Procedure OneTic(InDir, TicName: String; Var R: TicTossResult);
  Var
    T: TicType;
    FileName, Path, Why, ListName, D, Old: String;
    Rc, Sys, Echo, AreaNo: Word;
    Crc, Size, Status: LongInt;
    i: Word;
    A: AddrType;

  Begin
  Rc := TicParse(InDir + TicName, T);
  If Rc <> ticOk Then
    Begin
    ToBad(InDir, TicName, '', 'cannot be read');
    Inc(R.Bad);
    Exit;
    End;
  Rc := TicCheck(T);
  FileName := FindNoCase(InDir, T.FileName);
  Case Rc Of
    ticNoName: Why := 'no File line';
    ticNoArea: Why := 'no Area line';
    ticBadSize: Why := 'the Size is not a number';
    ticBadCrc: Why := 'no usable Crc line';
    Else Why := '';
    End;
  If Why <> '' Then
    Begin
    ToBad(InDir, TicName, FileName, Why);
    Inc(R.Bad);
    Exit;
    End;
  If FileName = '' Then
    Begin                              {not here yet: the next run, for up to a day}
    If Now_ - FileTime(InDir + TicName) > WaitSecs Then
      Begin
      ToBad(InDir, TicName, '', 'its file ' + T.FileName + ' did not come');
      Inc(R.Bad);
      End
    Else
      Begin
      Say('TIC ' + TicName + ': the file ' + T.FileName + ' has not come yet, waiting');
      Inc(R.Waiting);
      End;
    Exit;
    End;
  Path := InDir + FileName;
  Sys := SystemOf(T.From);
  If Sys = 0 Then
    Begin
    ToBad(InDir, TicName, FileName, 'from ' + T.From + ' that is not one of the echo systems');
    Inc(R.Bad);
    Exit;
    End;
  If (FE^.Sys[Sys].TicPwd <> '') And (Low(FE^.Sys[Sys].TicPwd) <> Low(T.Pw)) Then
    Begin
    ToBad(InDir, TicName, FileName, 'wrong password from ' + T.From);
    Inc(R.Bad);
    Exit;
    End;
  Echo := EchoOf(T.Area);
  If Echo = 0 Then
    Begin
    ToBad(InDir, TicName, FileName, 'the file echo ' + T.Area + ' is not one of ours');
    Inc(R.Bad);
    Exit;
    End;
  If (FE^.Area[Echo].Hub <> Sys) And ((FE^.Area[Echo].EchoTo And (LongInt(1) Shl (Sys - 1))) = 0) Then
    Begin
    ToBad(InDir, TicName, FileName, T.From + ' may not send ' + T.Area + ' (not its hub, the echo does not go to it)');
    Inc(R.Bad);
    Exit;
    End;
  For i := 1 To T.NumPath Do
    If (@TicIsOurs <> Nil) And TicIsOurs(Copy(T.Path[i], 1, Pos(' ', T.Path[i] + ' ') - 1)) Then
      Begin
      ToBad(InDir, TicName, FileName, 'we are in the Path already (a loop)');
      Inc(R.Bad);
      Exit;
      End;
  If Not TicFileCrc(Path, Crc, Size) Then
    Begin
    ToBad(InDir, TicName, FileName, 'the file cannot be read');
    Inc(R.Bad);
    Exit;
    End;
  If (T.HasSize) And (Size <> T.Size) Then
    Begin
    ToBad(InDir, TicName, FileName, 'the size is ' + Long2Str(Size) + ', the TIC says ' + Long2Str(T.Size));
    Inc(R.Bad);
    Exit;
    End;
  If Crc <> T.Crc Then
    Begin
    ToBad(InDir, TicName, FileName, 'the CRC is ' + TicCrcStr(Crc) + ', the TIC says ' + TicCrcStr(T.Crc));
    Inc(R.Bad);
    Exit;
    End;
  If IsDupe(InDir, T) Then
    Begin
    Say('TIC ' + TicName + ': ' + T.FileName + ' in ' + T.Area + ' was tossed before: a duplicate');
    fpUnlink(InDir + TicName);
    fpUnlink(Path);
    Inc(R.Dupes);
    Exit;
    End;
  If (FE^.CheckCmd <> '') And ((FE^.Area[Echo].Attr And feNoCheck) = 0) Then
    If Not CheckFile(FE^.CheckCmd, FE^.CheckTimeout, Path, InDir + TicName, Status) Then
      Begin
      ToBad(InDir, TicName, FileName, 'refused by the check command (status ' + Long2Str(Status) + ')');
      Inc(R.Bad);
      Exit;
      End;
  AreaNo := FE^.Area[Echo].FileArea;
  If AreaNo = 0 Then
    Begin
    Say('TIC ' + TicName + ': ' + T.FileName + ' for the pass-through echo ' + T.Area + ' is left in the inbound (passing on comes later)');
    Inc(R.Passthru);
    Exit;
    End;
  If AreaNo > Config^.GetMaxFileAreas Then
    Begin
    ToBad(InDir, TicName, FileName, 'the echo has file area ' + Long2Str(AreaNo) + ', which there is not');
    Inc(R.Bad);
    Exit;
    End;
  ListName := Config^.GetFileListPath(AreaNo);
  D := Copy(ListName, 1, Length(ListName) - Length('files.bbs'));
  If (D = '') Or (D = '/') Then
    Begin
    ToBad(InDir, TicName, FileName, 'the echo has file area ' + Long2Str(AreaNo) + ', which is not defined (no directory)');
    Inc(R.Bad);
    Exit;
    End;
  If Not DirExist(D) Then
    Begin
    Say('TIC ' + TicName + ': the directory of file area ' + Long2Str(AreaNo) + ' (' + D + ') is not there: the file waits');
    Inc(R.Waiting);
    Exit;
    End;
  {a file of that name is there (another CRC, or it would be a duplicate): this one is new and replaces it}
  Old := FindNoCase(D, T.FileName);
  If Old <> '' Then
    Begin
    fpUnlink(D + Old);
    Say('  ' + Old + ' was there: replaced by the new one');
    End;
  If (T.Replaces <> '') And ((FE^.Area[Echo].Attr And feReplaces) <> 0) Then
    DropOld(D, T.Replaces, T.FileName, ListName, T);
  If Not MoveFile(Path, D + T.FileName) Then
    Begin
    Say('TIC ' + TicName + ': ' + T.FileName + ' cannot be moved to ' + D + ': it waits');
    Inc(R.Waiting);
    Exit;
    End;
  If T.Date > 0 Then
    SetFileTime(D + T.FileName, T.Date);
  If (T.Replaces <> '') And ((FE^.Area[Echo].Attr And feReplaces) <> 0) Then
    ListUpdate(ListName, T.Replaces, True, T.FileName, T, False);
  If Old <> '' Then
    ListUpdate(ListName, Old, False, T.FileName, T, False);
  ListUpdate(ListName, T.FileName, False, T.FileName, T, True);
  AddDupe(InDir, T);
  fpUnlink(InDir + TicName);
  Config^.GetEchoToAddr(Sys, A);
  Say('tossed ' + T.FileName + ' (' + Long2Str(Size) + ' bytes) into file area ' + Long2Str(AreaNo) + ' from ' + T.Area + ' (from ' + AddrStr(A) + ')');
  Inc(R.Tossed);
  End;


Procedure TicTossInbound(InDir: String; Var R: TicTossResult);
  Var
    SR: SearchRec;
    Names: Array[1..300] Of String[80];
    n, i: Word;

  Begin
  FillChar(R, SizeOf(R), 0);
  If Not Config^.HasFileEcho Then
    Exit;
  New(FE);
  Config^.GetFileEcho(FE^);
  n := 0;
  FindFirst(InDir + '*', AnyFile, SR);
  While (DosError = 0) And (n < 300) Do
    Begin
    If ((SR.Attr And Directory) = 0) And (Low(Copy(SR.Name, Length(SR.Name) - 3, 4)) = '.tic') Then
      Begin
      Inc(n);
      Names[n] := SR.Name;
      End;
    FindNext(SR);
    End;
  FindClose(SR);
  For i := 1 To n Do
    OneTic(InDir, Names[i], R);
  Dispose(FE);
  FE := Nil;
  End;


End.
