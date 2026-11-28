{ SPDX-License-Identifier: GPL-3.0-or-later }
Unit MKFileIdx;   {The files of the file areas: read from the lists and the folders, or from the index (a flat binary file)}

{$MODE OBJFPC}
{$H+}

{
     ScanArea reads an area the slow way: its list (files.bbs, or a PCBoard DIR file) for the descriptions and its folder for the files that are there.  The index holds the
     result for every area, so that a search, a new files list or a list of all files reads one file and does not parse every list and look at every file.

     The index is a cache: the lists stay what they are.  The block of an area carries a stamp (the folder and the list file it was made from, the time and size of the list file
     and the time of the folder); a block whose stamp is not the one of the area now is made again.  That finds what the BBS itself changed (an upload, a TIC, a hatch, a script) and what
     the sysop changed (an edited list, a file put into the folder).  Not seen: a file in the folder that was changed in place (same name, new content): the time of the folder does
     not move; mkfilelist -I makes the index again.  Where the index cannot be written (no rights) the areas are read the slow way each time.

     Layout (as the machine writes it): 'MKFX', version (Word), number of blocks (LongInt); each block: area (LongInt), the length of the rest (LongInt), the folder and the list file
     (a Word and the bytes each), the time and size of the list file and the time of the folder (Int64 each), the number of files (LongInt) and the files by name, without regard to case:
     name (Word + bytes), size (Int64), date (LongInt, the Time of the file), listed (Byte), description (Word + bytes, the lines joined with a line feed).  The file is replaced as a whole (a new file, then
     renamed), so a reader never sees half of it.
}

Interface

Type
  TFileEnt = Record
    Name: String;
    Size: Int64;
    Time: LongInt;                    {the date of the file as SysUtils has it (UNIX seconds on this system; FileDateToDateTime turns it into a date)}
    Desc: String;                     {the lines of the description joined with #10; '' = not described}
    Listed: Boolean;                  {the list names the file (with or without a description)}
    End;
  TFileEnts = Array Of TFileEnt;

Function DosTimeOf(T: LongInt): LongInt;
  {a date of a file (the Time of a file) as a packed DOS date and time, as the Dos unit has it}

Function IndexPath: String;
  {MKFILEIDX, else filelist.idx in the BBS directory}

Procedure ScanArea(Area: Integer; Var Ents: TFileEnts);
  {the files of an area from its folder and its list (no index); empty when the area has no folder}

Function AreaFiles(Area: Integer; Var Ents: TFileEnts; UseIndex: Boolean): Boolean;
  {the files of an area, by name; the index when it is there and its block is the one of the area now, else the slow way (and the block is made again; see IndexFlush).  True: from the index}

Procedure IndexFlush;
  {writes the blocks that AreaFiles made again; False is not reported: an index that cannot be written is only slower}

Procedure IndexRebuild(Var Areas, Files: Integer);
  {the slow way for every file area that has a folder, then one new index}

Function IndexSummary(Var Areas, Files: Integer; Var Bytes: Int64; Var Made: Int64): Boolean;
  {what the index holds: blocks, files, the size of the file, the time it was written; False when there is none}

Implementation

Uses SysUtils, Classes, BaseUnix, contnrs, MKGlobT, MKCfgAbs, MKFileList;

Type
  TStamp = Record
    Dir, List: String;
    LMtime, LSize, DMtime: Int64;
    End;

  TPend = Record
    Area: Integer;
    Stamp: TStamp;
    Ents: TFileEnts;
    End;

Var
  Pend: Array Of TPend;


Function DosTimeOf(T: LongInt): LongInt;
  Var
    Y, M, D, H, N, S, Ms: Word;

  Begin
  DecodeDate(FileDateToDateTime(T), Y, M, D);
  DecodeTime(FileDateToDateTime(T), H, N, S, Ms);
  If Y < 1980 Then
    Exit(0);
  Result := LongInt((LongWord(Y - 1980) Shl 25) Or (LongWord(M) Shl 21) Or (LongWord(D) Shl 16) Or (LongWord(H) Shl 11) Or (LongWord(N) Shl 5) Or LongWord(S Div 2));
  End;


Function IndexPath: String;
  Begin
  Result := GetEnvironmentVariable('MKFILEIDX');
  If Result = '' Then
    Result := IncludeTrailingPathDelimiter(Config^.GetBbsPath) + 'filelist.idx';
  End;


Function Slash(Const P: String): String;
  Begin
  Result := P;
  If (Result <> '') And (Result[Length(Result)] <> '/') Then
    Result := Result + '/';
  End;


Function ListOfArea(Area: Integer): String;
  Var
    Dir: String;

  Begin
  Dir := Slash(Config^.GetFileAreaPath(Area));
  Result := Config^.GetFileListPath(Area);
  If (Result = '') Or DirectoryExists(Result) Then
    Result := Dir + 'files.bbs';
  If Not FileExists(Result) Then                    {no files.bbs: a PCBoard DIR file, when there is one}
    If FindDirFile(Dir, Config^.GetFileListPath(Area)) <> '' Then
      Result := FindDirFile(Dir, Config^.GetFileListPath(Area));
  End;


Procedure StampOf(Area: Integer; Var S: TStamp);
  Var
    St: Stat;

  Begin
  S.Dir := Slash(Config^.GetFileAreaPath(Area));
  S.List := ListOfArea(Area);
  S.LMtime := 0;
  S.LSize := 0;
  S.DMtime := 0;
  If fpStat(S.List, St) = 0 Then
    Begin
    S.LMtime := St.st_mtime;
    S.LSize := St.st_size;
    End;
  If fpStat(S.Dir, St) = 0 Then
    S.DMtime := St.st_mtime;
  End;


Function SameStamp(Const A, B: TStamp): Boolean;
  Begin
  Result := (A.Dir = B.Dir) And (A.List = B.List) And (A.LMtime = B.LMtime) And (A.LSize = B.LSize) And (A.DMtime = B.DMtime);
  End;


{------------------------------------------------------------ the slow way}

Procedure ScanArea(Area: Integer; Var Ents: TFileEnts);
  Var
    Dir, ListFile, Name, D, T, ListBase: String;
    PName, PDesc, PText: ShortString;
    PSize, PTime: LongInt;
    Lines: TStringList;
    Descs: TFPStringHashTable;
    Names: TStringList;
    SR: TSearchRec;
    i, k, n: Integer;
    Cur: String;
    Have: Boolean;
    Tmp: TFileEnts;

  Begin
  SetLength(Ents, 0);
  Dir := Slash(Config^.GetFileAreaPath(Area));
  If (Dir = '') Or Not DirectoryExists(Dir) Then
    Exit;
  ListFile := ListOfArea(Area);
  ListBase := LowerCase(ExtractFileName(ListFile));
  Descs := TFPStringHashTable.Create;
  Names := TStringList.Create;
  Names.CaseSensitive := False;
  Lines := TStringList.Create;
  Try
    If FileExists(ListFile) Then
      Begin
      Try
        Lines.LoadFromFile(ListFile);
      Except
        Lines.Clear;
      End;
      Cur := '';
      Have := False;
      For i := 0 To Lines.Count - 1 Do
        Begin
        T := Lines[i];
        If (T = '') Or (T[1] = ';') Or (T[1] = '/') Then
          Continue;
        If PcbPrimary(T, PName, PSize, PTime, PDesc) Then
          Begin
          If Have Then
            Descs.Items[Cur] := D;
          Cur := PName;
          D := PcbStripCodes(PDesc);
          Have := True;
          End
        Else If T[1] > ' ' Then
          Begin
          If Have Then
            Descs.Items[Cur] := D;
          Name := T;
          D := '';
          k := Pos(' ', T);
          If k = 0 Then
            k := Pos(#9, T);
          If k > 0 Then
            Begin
            Name := Copy(T, 1, k - 1);
            D := Trim(Copy(T, k + 1, 2000));
            End;
          Cur := Name;
          Have := True;
          End
        Else If Have Then
          Begin
          If PcbSecondary(T, PText) Then
            T := PcbStripCodes(PText);
          D := D + #10 + Trim(T);
          End;
        End;
      If Have Then
        Descs.Items[Cur] := D;
      End;
    SetLength(Tmp, 0);
    n := 0;
    If FindFirst(Dir + '*', faAnyFile, SR) = 0 Then
      Begin
      Repeat
        If ((SR.Attr And faDirectory) = 0) And (SR.Name[1] <> '.') And (LowerCase(SR.Name) <> 'files.bbs') And (LowerCase(SR.Name) <> 'files.bbs.bak')
           And (LowerCase(SR.Name) <> 'files.bbs.new') And (LowerCase(SR.Name) <> ListBase) Then
          Begin
          If n >= Length(Tmp) Then
            SetLength(Tmp, Length(Tmp) * 2 + 64);
          Tmp[n].Name := SR.Name;
          Tmp[n].Size := SR.Size;
          Tmp[n].Time := SR.Time;
          Tmp[n].Desc := Descs.Items[SR.Name];
          Tmp[n].Listed := Descs.Find(SR.Name) <> Nil;
          Names.AddObject(SR.Name, TObject(PtrInt(n)));
          Inc(n);
          End;
      Until FindNext(SR) <> 0;
      FindClose(SR);
      End;
    Names.Sort;
    SetLength(Ents, n);
    For i := 0 To n - 1 Do
      Ents[i] := Tmp[PtrInt(Names.Objects[i])];
  Finally
    Lines.Free;
    Names.Free;
    Descs.Free;
  End;
  End;


{------------------------------------------------------------ the index}

Procedure PutW(S: TStream; Const T: String);
  Var
    L: Word;

  Begin
  If Length(T) > 65535 Then
    L := 65535
  Else
    L := Length(T);
  S.WriteBuffer(L, 2);
  If L > 0 Then
    S.WriteBuffer(T[1], L);
  End;


Function GetW(S: TStream): String;
  Var
    L: Word;

  Begin
  S.ReadBuffer(L, 2);
  SetLength(Result, L);
  If L > 0 Then
    S.ReadBuffer(Result[1], L);
  End;


Procedure WriteBlock(S: TStream; Area: Integer; Const St: TStamp; Const Ents: TFileEnts);
  Var
    M: TMemoryStream;
    i, N, L: LongInt;
    Lf: Byte;

  Begin
  M := TMemoryStream.Create;
  Try
    PutW(M, St.Dir);
    PutW(M, St.List);
    M.WriteBuffer(St.LMtime, 8);
    M.WriteBuffer(St.LSize, 8);
    M.WriteBuffer(St.DMtime, 8);
    N := Length(Ents);
    M.WriteBuffer(N, 4);
    For i := 0 To N - 1 Do
      Begin
      PutW(M, Ents[i].Name);
      M.WriteBuffer(Ents[i].Size, 8);
      M.WriteBuffer(Ents[i].Time, 4);
      Lf := Ord(Ents[i].Listed);
      M.WriteBuffer(Lf, 1);
      PutW(M, Ents[i].Desc);
      End;
    N := Area;
    S.WriteBuffer(N, 4);
    L := M.Size;
    S.WriteBuffer(L, 4);
    S.WriteBuffer(M.Memory^, M.Size);
  Finally
    M.Free;
  End;
  End;


Function OpenIndex(Var F: TFileStream; Var Blocks: LongInt): Boolean;
  Var
    Magic: Array[0..3] Of Char;
    V: Word;

  Begin
  Result := False;
  F := Nil;
  If Not FileExists(IndexPath) Then
    Exit;
  Try
    F := TFileStream.Create(IndexPath, fmOpenRead Or fmShareDenyNone);
    F.ReadBuffer(Magic, 4);
    F.ReadBuffer(V, 2);
    F.ReadBuffer(Blocks, 4);
    If (Magic <> 'MKFX') Or (V <> 1) Then
      Raise Exception.Create('index');
    Result := True;
  Except
    F.Free;
    F := Nil;
  End;
  End;


Function ReadBlock(F: TStream; Var St: TStamp; Var Ents: TFileEnts): Boolean;
  {the block at the position of F, after its area and length}
  Var
    N, i: LongInt;
    Lf: Byte;

  Begin
  Result := False;
  Try
    St.Dir := GetW(F);
    St.List := GetW(F);
    F.ReadBuffer(St.LMtime, 8);
    F.ReadBuffer(St.LSize, 8);
    F.ReadBuffer(St.DMtime, 8);
    F.ReadBuffer(N, 4);
    If (N < 0) Or (N > 20000000) Then
      Exit;
    SetLength(Ents, N);
    For i := 0 To N - 1 Do
      Begin
      Ents[i].Name := GetW(F);
      F.ReadBuffer(Ents[i].Size, 8);
      F.ReadBuffer(Ents[i].Time, 4);
      F.ReadBuffer(Lf, 1);
      Ents[i].Listed := Lf <> 0;
      Ents[i].Desc := GetW(F);
      End;
    Result := True;
  Except
    SetLength(Ents, 0);
  End;
  End;


Function FindPending(Area: Integer): Integer;
  Var
    i: Integer;

  Begin
  Result := -1;
  For i := 0 To High(Pend) Do
    If Pend[i].Area = Area Then
      Result := i;
  End;


Function IndexRead(Area: Integer; Var St: TStamp; Var Ents: TFileEnts): Boolean;
  {the block of an area as the index has it}
  Var
    F: TFileStream;
    Blocks, k, A, L: LongInt;
    P: Int64;

  Begin
  Result := False;
  If Not OpenIndex(F, Blocks) Then
    Exit;
  Try
    Try
      For k := 1 To Blocks Do
        Begin
        F.ReadBuffer(A, 4);
        F.ReadBuffer(L, 4);
        P := F.Position;
        If A = Area Then
          Begin
          Result := ReadBlock(F, St, Ents);
          Exit;
          End;
        F.Position := P + L;
        End;
    Except
      Result := False;
    End;
  Finally
    F.Free;
  End;
  End;


Function AreaFiles(Area: Integer; Var Ents: TFileEnts; UseIndex: Boolean): Boolean;
  Var
    Now_, Old: TStamp;
    j: Integer;

  Begin
  Result := False;
  StampOf(Area, Now_);
  If UseIndex Then
    Begin
    j := FindPending(Area);
    If j >= 0 Then
      Begin
      Ents := Pend[j].Ents;
      Result := True;
      Exit;
      End;
    If IndexRead(Area, Old, Ents) And SameStamp(Old, Now_) Then
      Begin
      Result := True;
      Exit;
      End;
    End;
  ScanArea(Area, Ents);
  If UseIndex Then
    Begin
    j := Length(Pend);
    SetLength(Pend, j + 1);
    Pend[j].Area := Area;
    Pend[j].Stamp := Now_;
    Pend[j].Ents := Ents;
    End;
  End;


Procedure WriteIndex(Const AreasNow: Array Of TPend; Keep: Boolean);
  {a new index: the blocks of AreasNow, and (Keep) the other blocks of the old one as they are}
  Var
    Old: TFileStream;
    OB, k, A, L, i, Total: LongInt;
    NewF: TFileStream;
    Tmp: String;
    V: Word;
    Magic: Array[0..3] Of Char;
    Hit: Boolean;
    Buf: TMemoryStream;
    Mark: Int64;
    Mark2: LongInt;

  Begin
  Tmp := IndexPath + '.' + IntToStr(fpGetPid) + '.tmp';
  Old := Nil;
  OB := 0;
  If Keep Then
    If Not OpenIndex(Old, OB) Then
      OB := 0;
  Buf := TMemoryStream.Create;
  Try
    Try
      Total := 0;
      For i := 0 To High(AreasNow) Do
        Begin
        WriteBlock(Buf, AreasNow[i].Area, AreasNow[i].Stamp, AreasNow[i].Ents);
        Inc(Total);
        End;
      Mark := Buf.Size;
      Mark2 := Total;
      If Old <> Nil Then
        Try
        For k := 1 To OB Do
          Begin
          Old.ReadBuffer(A, 4);
          Old.ReadBuffer(L, 4);
          Hit := False;
          For i := 0 To High(AreasNow) Do
            If AreasNow[i].Area = A Then
              Hit := True;
          If Hit Then
            Old.Seek(L, soCurrent)
          Else
            Begin
            Buf.WriteBuffer(A, 4);
            Buf.WriteBuffer(L, 4);
            Buf.CopyFrom(Old, L);
            Inc(Total);
            End;
          End;
        Except                                     {the old index is damaged: only the new blocks}
          Buf.Size := Mark;
          Buf.Position := Mark;
          Total := Mark2;
        End;
      NewF := TFileStream.Create(Tmp, fmCreate);
      Try
        Magic := 'MKFX';
        V := 1;
        NewF.WriteBuffer(Magic, 4);
        NewF.WriteBuffer(V, 2);
        NewF.WriteBuffer(Total, 4);
        NewF.WriteBuffer(Buf.Memory^, Buf.Size);        
      Finally
        NewF.Free;
      End;
      If Not RenameFile(Tmp, IndexPath) Then
        DeleteFile(Tmp);
    Except
      DeleteFile(Tmp);
    End;
  Finally
    Old.Free;
    Buf.Free;
  End;
  End;


Procedure IndexFlush;
  Var
    Pn: Array Of TPend;
    i: Integer;

  Begin
  If Length(Pend) = 0 Then
    Exit;
  SetLength(Pn, Length(Pend));
  For i := 0 To High(Pend) Do
    Pn[i] := Pend[i];
  SetLength(Pend, 0);
  WriteIndex(Pn, True);
  End;


Procedure IndexRebuild(Var Areas, Files: Integer);
  Var
    A: Integer;
    N: Array Of TPend;
    k: Integer;

  Begin
  Areas := 0;
  Files := 0;
  SetLength(Pend, 0);
  SetLength(N, 0);
  For A := 1 To Config^.GetMaxFileAreas Do
    If (Config^.GetFileAreaName(A) <> '') And (Config^.GetFileAreaPath(A) <> '') And DirectoryExists(Config^.GetFileAreaPath(A)) Then
      Begin
      k := Length(N);
      SetLength(N, k + 1);
      N[k].Area := A;
      StampOf(A, N[k].Stamp);
      ScanArea(A, N[k].Ents);
      Inc(Areas);
      Files := Files + Length(N[k].Ents);
      End;
  WriteIndex(N, False);
  End;


Function IndexSummary(Var Areas, Files: Integer; Var Bytes: Int64; Var Made: Int64): Boolean;
  Var
    F: TFileStream;
    Blocks, k, A, L, N: LongInt;
    St: Stat;
    S: TStamp;
    E: TFileEnts;

  Begin
  Result := False;
  Areas := 0;
  Files := 0;
  Bytes := 0;
  Made := 0;
  If Not OpenIndex(F, Blocks) Then
    Exit;
  Try
    Try
      For k := 1 To Blocks Do
        Begin
        F.ReadBuffer(A, 4);
        F.ReadBuffer(L, 4);
        If ReadBlock(F, S, E) Then
          Begin
          Inc(Areas);
          N := Length(E);
          Files := Files + N;
          End
        Else
          Exit;
        End;
      Result := True;
    Except
      Result := False;
    End;
  Finally
    F.Free;
  End;
  If fpStat(IndexPath, St) = 0 Then
    Begin
    Bytes := St.st_size;
    Made := St.st_mtime;
    End;
  End;


End.
