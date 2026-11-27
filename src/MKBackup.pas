{ SPDX-License-Identifier: GPL-3.0-or-later }
Program MKBackup;

{$mode objfpc}{$H+}

{
     mkbackup: a backup of a BBS in one file (name.tar.gz), made while the BBS runs, and its restore.

       mkbackup [-o directory] [-k N] [-a] [-q]       make a backup (MK names the configuration directory, as for mk)
       mkbackup -l archive                            list what an archive holds
       mkbackup -t archive                            test it: every file is read and compared with the checksum in the manifest
       mkbackup -r archive [-n] [-f] [-C root]        restore it: -n only says what would happen, -f replaces files that differ (the old one is kept
                                                      as name.pre-restore), -C puts everything below root instead of in the places it came from

     What a backup holds: the configuration directory with everything below it (the .mk files, the user files, the network maps and ledgers, the language files, the
     BBS's own message base files when they are there), the menu and screen directories, the message bases of the areas (Hudson, Squish, JAM, Fido *.msg, Synchronet), and the files.bbs of
     the file areas; with -a the file areas themselves.  Not held: the logs, the spool and inbound / outbound directories, the node directories, temporary files.  Each message base is locked
     while it is copied, so a caller or the tosser cannot write in the middle of it.  The names in the archive are the full paths of the files (without the leading slash); the last entry,
     MKBACKUP.MANIFEST, has the size and the checksum of each file.

     -o names the directory for the archive (default: backup below the configuration directory); the archive is mkbbs-<name>-<date>-<time>.tar.gz, readable only by its owner.  -k keeps the
     N newest archives of that name and removes the others.

     The exit code: 0 done, 1 not usable (options, no configuration), 2 the archive could not be written, 3 the test found something wrong, 4 the restore was refused.
}

Uses SysUtils, Classes, BaseUnix, Unix, StrUtils, DateUtils, sha1,
  MKGlobT, MKCfgAbs, MKRCfgMK, MKCfgNew, MKRCfgRA, MKCfgQB, MKCfgSB, MKMsgAbs, MKOpen, MKTarGz;

Const
  ManifestName = 'MKBACKUP.MANIFEST';

Type
  TItem = Record
    Disk: String;                      {the file on the disk}
    Group: String;                     {files of one message base are copied under one lock; '' = no lock}
    AreaId: String;                    {the message area id to open for the lock}
    End;

Var
  Items: Array Of TItem;
  NumItems: Integer = 0;
  Seen: TStringList;
  OutDir: String = '';
  KeepN: Integer = 0;
  WithFiles: Boolean = False;
  Quiet: Boolean = False;
  CfgDir: String;
  SkipDir: String = '';


Procedure Say(S: String);
  Begin
  If Not Quiet Then
    WriteLn(S);
  End;


Procedure Die(Code: Integer; S: String);
  Begin
  WriteLn(StdErr, 'mkbackup: ', S);
  Halt(Code);
  End;


Function Absolute(P: String): String;
  Begin
  If P = '' Then
    Exit('');
  Result := ExpandFileName(P);
  While (Length(Result) > 1) And (Result[Length(Result)] = '/') Do
    Delete(Result, Length(Result), 1);
  End;


Procedure Add(Disk, Group, AreaId: String);
  Begin
  Disk := Absolute(Disk);
  If (Disk = '') Or (Seen.IndexOf(Disk) >= 0) Then
    Exit;
  Seen.Add(Disk);
  If NumItems >= Length(Items) Then
    SetLength(Items, Length(Items) + 4096);
  Items[NumItems].Disk := Disk;
  Items[NumItems].Group := Group;
  Items[NumItems].AreaId := AreaId;
  Inc(NumItems);
  End;


Function SkipName(N: String; IsDir: Boolean): Boolean;
  Var
    L: String;

  Begin
  L := LowerCase(N);
  If IsDir Then
    Exit((L = 'backup') Or (L = 'temp') Or (L = 'tmp') Or ((Copy(L, 1, 4) = 'node') And (Length(L) > 4) And (L[5] In ['0'..'9'])));
  Result := (RightStr(L, 5) = '.lock') Or (RightStr(L, 4) = '.tmp') Or (RightStr(L, 4) = '.swp') Or (RightStr(L, 4) = '.pid') Or
    (RightStr(L, 15) = '.mkbackup.tmp') Or (RightStr(L, 12) = '.pre-restore');
  End;


Procedure AddTree(Dir, Group, AreaId: String);
  {every file below Dir (not the ones that are left out)}
  Var
    SR: TSearchRec;
    P: String;

  Begin
  Dir := Absolute(Dir);
  If (Dir = '') Or (Dir = SkipDir) Or Not DirectoryExists(Dir) Then
    Exit;
  If FindFirst(Dir + '/*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If (SR.Name <> '.') And (SR.Name <> '..') Then
        Begin
        P := Dir + '/' + SR.Name;
        If (SR.Attr And faSymLink) <> 0 Then
          Continue;
        If (SR.Attr And faDirectory) <> 0 Then
          Begin
          If Not SkipName(SR.Name, True) Then
            AddTree(P, Group, AreaId);
          End
        Else If Not SkipName(SR.Name, False) Then
          Add(P, Group, AreaId);
        End;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  End;


Procedure AddByMask(Dir, Mask, Group, AreaId: String);
  Var
    SR: TSearchRec;

  Begin
  Dir := Absolute(Dir);
  If Not DirectoryExists(Dir) Then
    Exit;
  If FindFirst(Dir + '/*', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      If ((SR.Attr And faDirectory) = 0) And IsWild(LowerCase(SR.Name), Mask, False) Then
        Add(Dir + '/' + SR.Name, Group, AreaId);
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  End;


Procedure AddBase(AreaId: String);
  {the files of one message base, by the kind of base the area id names}
  Var
    T: Char;
    P, Base, Dir: String;

  Begin
  If AreaId = '' Then
    Exit;
  T := UpCase(AreaId[1]);
  Case T Of
    'H': Begin                                       {Hudson: 3 digits for the board, then the directory}
         Dir := Copy(AreaId, 5, 200);
         AddByMask(Dir, 'msg*.bbs', 'H' + Absolute(Dir), AreaId);
         AddByMask(Dir, 'lastread.bbs', 'H' + Absolute(Dir), AreaId);
         End;
    'S': Begin
         Base := Absolute(Copy(AreaId, 2, 200));
         Dir := ExtractFilePath(Base);
         AddByMask(Dir, LowerCase(ExtractFileName(Base)) + '.sq*', 'S' + Base, AreaId);
         End;
    'J': Begin
         Base := Absolute(Copy(AreaId, 2, 200));
         Dir := ExtractFilePath(Base);
         AddByMask(Dir, LowerCase(ExtractFileName(Base)) + '.j*', 'J' + Base, AreaId);
         End;
    'Y': Begin
         Base := Absolute(Copy(AreaId, 2, 200));
         Dir := ExtractFilePath(Base);
         AddByMask(Dir, LowerCase(ExtractFileName(Base)) + '.s*', 'Y' + Base, AreaId);
         End;
    'F': Begin
         Dir := Copy(AreaId, 2, 200);
         AddByMask(Dir, '*.msg', 'F' + Absolute(Dir), AreaId);
         AddByMask(Dir, 'lastread', 'F' + Absolute(Dir), AreaId);
         End;
    'M': AddTree(Copy(AreaId, 2, 200), '', '');       {MK-Merlin: a directory of files}
    Else
      Say('message base kind ' + T + ' of area ' + AreaId + ' is not held by the backup');
    End;
  End;


Procedure Gather;
  Var
    i: Integer;
    P: String;
    SR: TSearchRec;

  Begin
  For i := 1 To Config^.GetMaxMsgAreas Do                  {the message bases first: they are copied under their locks, whatever directory they are in}
    If Config^.GetMsgName(i) <> '' Then
      AddBase(Config^.GetMsgAreaId(i));
  AddTree(CfgDir, '', '');
  For i := 1 To 20 Do
    Begin
    P := Config^.GetMnuPath(i);
    If P <> '' Then
      AddTree(P, '', '');
    P := Config^.GetTxtPath(i);
    If P <> '' Then
      AddTree(P, '', '');
    End;
  For i := 1 To Config^.GetMaxFileAreas Do
    If Config^.GetFileAreaName(i) <> '' Then
      Begin
      P := Config^.GetFileListPath(i);          {the name of the list (MK), or its directory}
      If P <> '' Then
        Begin
        If DirectoryExists(P) Then
          AddByMask(P, 'files.bbs', '', '')
        Else If FileExists(P) Then
          Add(P, '', '');
        End;
      If WithFiles Then
        Begin
        P := Config^.GetFileAreaPath(i);
        If P <> '' Then
          AddTree(P, '', '');
        End;
      End;
  End;


Function Stamp: String;
  Begin
  Result := FormatDateTime('yyyymmdd"-"hhnnss', Now);
  End;


Function SafeName(S: String): String;
  Var
    i: Integer;

  Begin
  Result := '';
  For i := 1 To Length(S) Do
    If S[i] In ['A'..'Z', 'a'..'z', '0'..'9', '-', '_'] Then
      Result := Result + S[i];
  If Result = '' Then
    Result := 'bbs';
  End;


Procedure Retention(Dir, Prefix: String);
  {keep the newest KeepN archives with this prefix}
  Var
    SR: TSearchRec;
    L: TStringList;
    i: Integer;

  Begin
  If KeepN <= 0 Then
    Exit;
  L := TStringList.Create;
  If FindFirst(Dir + '/' + Prefix + '*.tar.gz', faAnyFile, SR) = 0 Then
    Begin
    Repeat
      L.Add(SR.Name);
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  L.Sort;                                 {the names have the date and the time: the oldest first}
  For i := 0 To L.Count - KeepN - 1 Do
    Begin
    If DeleteFile(Dir + '/' + L[i]) Then
      Say('removed the old backup ' + L[i]);
    End;
  L.Free;
  End;


Function DoBackup: Integer;
  Var
    Arc, Name, Manifest, Sha, Cur, Arcname: String;
    W: TTarWriter;
    i, j, Ok, Bad, K: Integer;
    Size, Total: Int64;
    Msg: AbsMsgPtr;
    Locked: Boolean;
    Names: TStringList;

  Begin
  Result := 0;
  If OutDir = '' Then
    OutDir := CfgDir + '/backup';
  SkipDir := Absolute(OutDir);
  Seen := TStringList.Create;
  Seen.CaseSensitive := True;
  Seen.Sorted := True;
  Gather;
  If NumItems = 0 Then
    Die(1, 'nothing to back up: no configuration directory ' + CfgDir);
  ForceDirectories(OutDir);
  Name := SafeName(Config^.GetBbsName);
  Arc := OutDir + '/mkbbs-' + Name + '-' + Stamp + '.tar.gz';
  W := TTarWriter.Create(Arc);
  If W.Err <> '' Then
    Die(2, W.Err);
  fpChmod(Arc, &600);
  Manifest := 'MKBACKUP 1' + LineEnding + 'created ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + LineEnding + 'bbs ' + Config^.GetBbsName + LineEnding +
    'config ' + CfgDir + LineEnding;
  Ok := 0;
  Bad := 0;
  Total := 0;
  i := 0;
  While i < NumItems Do
    Begin
    If Items[i].Group = '' Then
      Begin
      If W.AddFile(Items[i].Disk, Items[i].Disk, Sha, Size) Then
        Begin
        Manifest := Manifest + IntToStr(Size) + '|' + Sha + '|' + Items[i].Disk + LineEnding;
        Inc(Ok);
        Inc(Total, Size);
        End
      Else
        Begin
        Say('not saved: ' + Items[i].Disk + ' (' + W.Err + ')');
        Inc(Bad);
        End;
      Inc(i);
      End
    Else
      Begin
      Cur := Items[i].Group;                  {all the files of this base, together, under its lock}
      Msg := Nil;
      Locked := False;
      If OpenMsgArea(Msg, Items[i].AreaId) Then
        Locked := Msg^.LockMsgBase;
      j := i;
      While (j < NumItems) And (Items[j].Group = Cur) Do
        Begin
        If W.AddFile(Items[j].Disk, Items[j].Disk, Sha, Size) Then
          Begin
          Manifest := Manifest + IntToStr(Size) + '|' + Sha + '|' + Items[j].Disk + LineEnding;
          Inc(Ok);
          Inc(Total, Size);
          End
        Else
          Begin
          Say('not saved: ' + Items[j].Disk + ' (' + W.Err + ')');
          Inc(Bad);
          End;
        Inc(j);
        End;
      If Msg <> Nil Then
        Begin
        If Locked Then
          Msg^.UnLockMsgBase;
        DoneMsgPtr(Msg);
        End;
      i := j;
      End;
    End;
  Manifest := Manifest + 'files ' + IntToStr(Ok) + LineEnding;
  W.AddText(ManifestName, Manifest);
  If Not W.Close Then
    Begin
    WriteLn(StdErr, 'mkbackup: ', W.Err);
    DeleteFile(Arc);
    Exit(2);
    End;
  W.Free;
  Say(IntToStr(Ok) + ' file(s), ' + IntToStr(Total) + ' bytes, in ' + Arc);
  If Bad > 0 Then
    Begin
    WriteLn(StdErr, 'mkbackup: ', Bad, ' file(s) could not be saved');
    Result := 2;
    End;
  Retention(OutDir, 'mkbbs-' + Name + '-');
  End;


{ ---- list, test, restore }

Type
  TInfo = Class                        {what the manifest says of a file}
    Size: Int64;
    Sum: String;
    Seen: Boolean;
    End;

Var
  Manifest: TStringList;               {name -> TInfo (as an object)}
  ManifestText: String;


Function ParseManifest: Boolean;
  Var
    L: TStringList;
    i, p1, p2: Integer;
    S: String;
    Inf: TInfo;

  Begin
  Manifest.Clear;
  L := TStringList.Create;
  L.Text := ManifestText;
  Result := (L.Count > 0) And (L[0] = 'MKBACKUP 1');
  For i := 1 To L.Count - 1 Do
    Begin
    S := L[i];
    p1 := Pos('|', S);
    If p1 = 0 Then
      Continue;
    p2 := PosEx('|', S, p1 + 1);
    If p2 = 0 Then
      Continue;
    Inf := TInfo.Create;
    Inf.Size := StrToInt64Def(Copy(S, 1, p1 - 1), -1);
    Inf.Sum := Copy(S, p1 + 1, p2 - p1 - 1);
    Inf.Seen := False;
    Manifest.AddObject(Copy(S, p2 + 1, 2000), Inf);
    End;
  L.Free;
  End;


Function Strip(N: String): String;
  Begin
  Result := N;
  While (Result <> '') And (Result[1] = '/') Do
    Delete(Result, 1, 1);
  End;


Function DoList(Arc: String): Integer;
  Var
    R: TTarReader;
    Count: Integer;
    Total: Int64;

  Begin
  Result := 0;
  R := TTarReader.Create(Arc);
  If R.Err <> '' Then
    Die(1, R.Err);
  Count := 0;
  Total := 0;
  While R.Next Do
    Begin
    If R.Name <> ManifestName Then
      Begin
      WriteLn(R.Size:12, '  ', FormatDateTime('yyyy-mm-dd hh:nn', UnixToDateTime(R.MTime)), '  /', R.Name);
      Inc(Count);
      Inc(Total, R.Size);
      End;
    R.Skip;
    End;
  If R.Err <> '' Then
    Begin
    WriteLn(StdErr, 'mkbackup: ', R.Err);
    Result := 3;
    End;
  WriteLn(Count, ' file(s), ', Total, ' bytes');
  R.Free;
  End;


Function Test(Arc: String; Verbose: Boolean): Integer;
  {reads the whole archive and compares each file with the manifest (it is the last entry); 0 good, 3 not good}
  Var
    R: TTarReader;
    Buf: Array[0..65535] Of Byte;
    N: LongInt;
    Ctx: TSHA1Context;
    D: TSHA1Digest;
    Hex: String;
    Count, Bad, Idx, i: Integer;
    Got: TStringList;
    Inf: TInfo;

  Begin
  Result := 0;
  R := TTarReader.Create(Arc);
  If R.Err <> '' Then
    Die(1, R.Err);
  Got := TStringList.Create;
  Got.CaseSensitive := True;
  ManifestText := '';
  Count := 0;
  Bad := 0;
  While R.Next Do
    Begin
    If R.Name = ManifestName Then
      Begin
      SetLength(ManifestText, R.Size);
      If R.Size > 0 Then
        R.ReadData(ManifestText[1], R.Size);
      Continue;
      End;
    SHA1Init(Ctx);
    Repeat
      N := R.ReadData(Buf, SizeOf(Buf));
      If N > 0 Then
        SHA1Update(Ctx, Buf, N);
    Until N <= 0;
    SHA1Final(Ctx, D);
    Hex := LowerCase(SHA1Print(D));
    Inf := TInfo.Create;
    Inf.Sum := Hex;
    Inf.Size := R.Size;
    Got.AddObject('/' + R.Name, Inf);
    Inc(Count);
    End;
  If R.Err <> '' Then
    Begin
    WriteLn(StdErr, 'mkbackup: ', R.Err);
    Inc(Bad);
    End;
  R.Free;
  If (ManifestText = '') Or Not ParseManifest Then
    Begin
    WriteLn(StdErr, 'mkbackup: the archive has no manifest (it was not finished, or it is not a backup of this program)');
    Inc(Bad);
    End
  Else
    Begin
    For i := 0 To Manifest.Count - 1 Do
      Begin
      Idx := Got.IndexOf(Manifest[i]);
      If Idx < 0 Then
        Begin
        WriteLn(StdErr, 'mkbackup: missing from the archive: ', Manifest[i]);
        Inc(Bad);
        End
      Else If (TInfo(Got.Objects[Idx]).Sum <> TInfo(Manifest.Objects[i]).Sum) Or (TInfo(Got.Objects[Idx]).Size <> TInfo(Manifest.Objects[i]).Size) Then
        Begin
        WriteLn(StdErr, 'mkbackup: does not match its checksum: ', Manifest[i]);
        Inc(Bad);
        End;
      End;
    For i := 0 To Got.Count - 1 Do
      If Manifest.IndexOf(Got[i]) < 0 Then
        Begin
        WriteLn(StdErr, 'mkbackup: not in the manifest: ', Got[i]);
        Inc(Bad);
        End;
    End;
  Got.Free;
  If Bad = 0 Then
    Begin
    If Verbose Then
      WriteLn('the archive is good: ', Count, ' file(s), every checksum matches');
    End
  Else
    Result := 3;
  End;


Function Running(Dir: String): Boolean;
  {a mklisten or mk of this user is running in the directory (or has it as MK): a restore into the directory should not happen under it.  Only the processes that can be looked at
   count: the ones of other users are not visible (run it as root, or as the user of the BBS, to see them all)}
  Var
    SR: TSearchRec;
    F: Text;
    L, Cwd, Env: String;
    Fs: TFileStream;
    Buf: Array[0..32767] Of Char;
    N: LongInt;

  Begin
  Result := False;
  If Dir = '' Then
    Exit;
  If FindFirst('/proc/*', faDirectory, SR) = 0 Then
    Begin
    Repeat
      If (SR.Name[1] In ['0'..'9']) And (StrToIntDef(SR.Name, 0) <> fpGetPid) Then
        Begin
        Assign(F, '/proc/' + SR.Name + '/comm');
        {$I-}
        Reset(F);
        {$I+}
        If IOResult = 0 Then
          Begin
          ReadLn(F, L);
          Close(F);
          If (L = 'mklisten') Or (L = 'mk') Then
            Begin
            Cwd := fpReadLink('/proc/' + SR.Name + '/cwd');
            Env := '';
            Try
              Fs := TFileStream.Create('/proc/' + SR.Name + '/environ', fmOpenRead Or fmShareDenyNone);
              N := Fs.Read(Buf, SizeOf(Buf));
              If N > 0 Then
                SetString(Env, PChar(@Buf[0]), N);
              Fs.Free;
            Except
              Env := '';
            End;
            If ((Cwd <> '') And ((Cwd = Dir) Or (Copy(Cwd, 1, Length(Dir) + 1) = Dir + '/'))) Or (Pos('MK=' + Dir + #0, #0 + Env) > 0) Or (Pos(#0 + 'MK=' + Dir + #0, Env) > 0) Then
              Result := True;
            End;
          End;
        End;
    Until FindNext(SR) <> 0;
    FindClose(SR);
    End;
  End;


Function RestoreDir(Arc: String): String;
  {the configuration directory the backup was made from, named in its manifest}
  Var
    R: TTarReader;
    T: String;
    L: TStringList;
    i: Integer;

  Begin
  Result := '';
  R := TTarReader.Create(Arc);
  While R.Next Do
    Begin
    If R.Name = ManifestName Then
      Begin
      SetLength(T, R.Size);
      If R.Size > 0 Then
        R.ReadData(T[1], R.Size);
      L := TStringList.Create;
      L.Text := T;
      For i := 0 To L.Count - 1 Do
        If Copy(L[i], 1, 7) = 'config ' Then
          Result := Copy(L[i], 8, 500);
      L.Free;
      Break;
      End;
    R.Skip;
    End;
  R.Free;
  End;


Function DoRestore(Arc, Root: String; Dry, Force: Boolean): Integer;
  Var
    R: TTarReader;
    Buf: Array[0..65535] Of Byte;
    N: LongInt;
    Ctx: TSHA1Context;
    D: TSHA1Digest;
    Dest, Tmp, Have: String;
    F: TFileStream;
    Idx: Integer;
    New_, Same_, Replaced_, Kept_: Integer;
    Inf: TInfo;
    Skip: Boolean;

  Begin
  Result := 0;
  If (Not Dry) And (Not Force) And (Root = '') And Running(RestoreDir(Arc)) Then
    Begin
    WriteLn(StdErr, 'mkbackup: mklisten or mk is running on this BBS: stop it first (or use -f to restore under it)');
    Exit(4);
    End;
  If Test(Arc, False) <> 0 Then
    Begin
    WriteLn(StdErr, 'mkbackup: the archive is not good (mkbackup -t says what): nothing is restored');
    Exit(4);
    End;
  R := TTarReader.Create(Arc);
  New_ := 0;
  Same_ := 0;
  Replaced_ := 0;
  Kept_ := 0;
  While R.Next Do
    Begin
    If R.Name = ManifestName Then
      Begin
      R.Skip;
      Continue;
      End;
    Dest := Root + '/' + Strip(R.Name);
    Idx := Manifest.IndexOf('/' + R.Name);
    Inf := TInfo(Manifest.Objects[Idx]);
    If FileExists(Dest) Then
      Begin
      If Not Sha1OfFile(Dest, Have) Then
        Have := '';
      If Have = Inf.Sum Then
        Begin
        Inc(Same_);
        R.Skip;
        Continue;
        End;
      If Not Force Then
        Begin
        WriteLn('kept (differs; -f replaces it): ', Dest);
        Inc(Kept_);
        R.Skip;
        Continue;
        End;
      If Dry Then
        Begin
        WriteLn('would replace: ', Dest);
        Inc(Replaced_);
        R.Skip;
        Continue;
        End;
      End
    Else
      Begin
      If Dry Then
        Begin
        WriteLn('would restore: ', Dest);
        Inc(New_);
        R.Skip;
        Continue;
        End;
      End;
    ForceDirectories(ExtractFilePath(Dest));
    Tmp := Dest + '.mkbackup.tmp';
    F := TFileStream.Create(Tmp, fmCreate);
    Repeat
      N := R.ReadData(Buf, SizeOf(Buf));
      If N > 0 Then
        F.WriteBuffer(Buf, N);
    Until N <= 0;
    F.Free;
    fpChmod(Tmp, R.Mode And 4095);
    If FileExists(Dest) Then
      Begin
      RenameFile(Dest, Dest + '.pre-restore');
      Inc(Replaced_);
      WriteLn('replaced (the old one is ', Dest, '.pre-restore): ', Dest);
      End
    Else
      Inc(New_);
    RenameFile(Tmp, Dest);
    FileSetDate(Dest, DateTimeToFileDate(UnixToDateTime(R.MTime)));
    End;
  R.Free;
  WriteLn(New_, ' restored, ', Replaced_, ' replaced, ', Same_, ' already as in the archive, ', Kept_, ' kept as they are', Copy(' (a dry run: nothing was written)', 1, 33 * Ord(Dry)));
  End;


Var
  i: Integer;
  A, Mode, Arc, Root, ConfDir: String;
  Dry, Force: Boolean;
  BbsType: Word;
  Argv: TStringList;
  PArgv, EnvP: Array Of PChar;
  EnvS: Array Of String;
  k: Integer;

Begin
ConfDir := '';
Mode := 'B';
Arc := '';
Root := '';
Dry := False;
Force := False;
i := 1;
While i <= ParamCount Do
  Begin
  A := ParamStr(i);
  If A = '-o' Then
    Begin
    Inc(i);
    OutDir := ParamStr(i);
    End
  Else If A = '-k' Then
    Begin
    Inc(i);
    KeepN := StrToIntDef(ParamStr(i), 0);
    End
  Else If A = '-a' Then WithFiles := True
  Else If A = '-q' Then Quiet := True
  Else If A = '-n' Then Dry := True
  Else If A = '-f' Then Force := True
  Else If A = '-c' Then
    Begin
    Inc(i);
    ConfDir := Absolute(ParamStr(i));
    End
  Else If A = '-C' Then
    Begin
    Inc(i);
    Root := Absolute(ParamStr(i));
    End
  Else If (A = '-l') Or (A = '-t') Or (A = '-r') Then
    Begin
    Mode := UpCase(A[2]);
    Inc(i);
    Arc := ParamStr(i);
    End
  Else
    Begin
    WriteLn('usage: mkbackup [-c config dir] [-o dir] [-k N] [-a] [-q]    a backup (-c, or MK, names the configuration directory)');
    WriteLn('       mkbackup -l archive                    list');
    WriteLn('       mkbackup -t archive                    test');
    WriteLn('       mkbackup -r archive [-n] [-f] [-C root]  restore (-n a dry run, -f replace what differs)');
    Halt(1);
    End;
  Inc(i);
  End;
If (ConfDir <> '') And (GetEnvironmentVariable('MK') <> ConfDir) Then
  Begin                                                    {-c names the configuration directory: this program starts again with MK set to it}
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
Manifest := TStringList.Create;
Manifest.CaseSensitive := True;
If Mode = 'L' Then
  Halt(DoList(Arc));
If Mode = 'T' Then
  Halt(Test(Arc, True));
If Mode = 'R' Then
  Halt(DoRestore(Arc, Root, Dry, Force));
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
CfgDir := Absolute(Config^.GetBbsPath);
Halt(DoBackup);
End.
